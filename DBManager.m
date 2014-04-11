//
//  DBManager.m
//  Alacarta
//
//  Created by Oscar Andrés Granada on 25/01/14.
//  Copyright (c) 2014 Tecmovin. All rights reserved.
//

#import "DBManager.h"
#import <sqlite3.h>
#import "NSMutableArray+NSMutableArray_QueueAdditions.h"
#import "GeoHelper.h"
#import <MapKit/MapKit.h>


static NSMutableArray *selectores;
static DBManager *single;
static NSOperationQueue *sqlOperationQueue;
static NSMutableArray *tables;
static NSString *databasePath;

@implementation DBManager

- (id)init
{
    self = [super init];
    if (self) {
        if (!tables) {
            tables = [[NSMutableArray alloc] init];
            NSString *docsDir;
            NSArray *dirPaths;
            dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            docsDir = dirPaths[0];
            databasePath = [[NSString alloc]
                            initWithString: [docsDir stringByAppendingPathComponent:
                                             @"dbname.db"]];
        }
    }
    return self;
}


+(void) addTable:(NSDictionary*)table
{
    if (!tables) {
        tables = [[NSMutableArray alloc] init];
    }
    [tables addObject:table];
}

-(void) createTables
{
    NSFileManager *filemgr = [NSFileManager defaultManager];
    if ([filemgr fileExistsAtPath: databasePath ] == NO)
    {
        const char *dbpath = [databasePath UTF8String];
        
        if (sqlite3_open(dbpath, &_database) == SQLITE_OK)
        {
            char *errMsg;
            for (NSDictionary *tabla in tables) {
                NSMutableString *cols = [[NSMutableString alloc] init];
                BOOL first = YES;
                for (NSDictionary *col in [tabla objectForKey:@"columns"]) {
                    if (!first) {
                        [cols appendString:@", "];
                    } else {
                        first = NO;
                    }
                    [cols appendFormat:@"%@ %@ %@",[col objectForKey:@"name"],[col objectForKey:@"type"],[col objectForKey:@"restrictions"]];
                }
                if ([[tabla objectForKey:@"keys"] count]>0) {
                    // TODO: poner la llave primaria compuesta
                    NSMutableString *kys = [[NSMutableString alloc] init];
                    first = YES;
                    for (NSString *ky in [tabla objectForKey:@"keys"]) {
                        if (!first) {
                            [kys appendString:@", "];
                        } else {
                            first = NO;
                        }
                        [kys appendFormat:@"%@", ky];
                    }
                    [cols appendFormat:@", PRIMARY KEY(%@)", kys];
                }
                NSString * ctsql = [@"CREATE TABLE IF NOT EXISTS " stringByAppendingFormat:@"%@(%@)",[tabla objectForKey:@"name"], cols];
                // NSLog(@"Query: %@", ctsql);
                const char *sql_stmt = [ctsql UTF8String];
                // if(1==2)
                {
                    if (sqlite3_exec(_database, sql_stmt, NULL, NULL, &errMsg) != SQLITE_OK)
                    {
                        self._status = [NSString stringWithFormat:@"Failed to create table %@", [tabla objectForKey:@"name"]];
                    } else {
                        self._status = @"OK";
                        NSLog(@"%@ TABLE CREATED",[tabla objectForKey:@"name"]);
                    }
                }
            }
            sqlite3_close(_database);
        } else {
            self._status = @"Failed to open/create database";
        }
    } else {
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"logueado"]) {
            NSError *error;
            [filemgr removeItemAtPath:databasePath error:&error];
            if (error) {
                NSLog(@"Error :%@", error);
            } else {
                [self createTables];
            }
        }
    }
}

-(void) asyncUpdateTable:(NSString*)table withContent:(NSArray *)rows
{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    [data setObject:table forKey:@"tablename"];
    [data setObject:rows forKey:@"rows"];
    [DBManager addToQueue:@selector(updateTable:) withParam:data andCallback:^(NSObject *data) {
        NSLog(@"--> %lu Updated",(unsigned long)[((NSArray*)data) count]);
    }];
}


-(NSArray*) updateTable:(NSDictionary*)data
{
    NSString* table = [data objectForKey:@"tablename"];
    NSArray *pknames = [[NSArray alloc] init];
    NSArray *rows = [data objectForKey:@"rows"];
    BOOL table_exists = NO;
    int table_index = -1;
    NSDictionary *tabla;
    for (NSDictionary* row in tables) {
        table_index++;
        if ([[row objectForKey:@"name"] isEqualToString:table]) {
            table_exists = YES;
            tabla = row;
            pknames = [tabla objectForKey:@"keys"];
            break;
        }
    }
    // @synchronized(self)
    if(table_exists)
    {
        NSDictionary *tabla = [tables objectAtIndex:table_index];
        const char *dbpath = [databasePath UTF8String];
        if(_database){
            sqlite3_close(_database);
        }
        if (sqlite3_open(dbpath, &_database) == SQLITE_OK)
        {
            sqlite3_stmt *statement;
            sqlite3_stmt *statement2;
            for (int i=0; i<[rows count]; i++)
            {
                NSDictionary *fila = (NSDictionary*) [rows objectAtIndex:i];
                NSMutableString *pkdata = [[NSMutableString alloc] init];
                BOOL first = YES;
                for (NSString *ky in pknames) {
                    if (!first) {
                        [pkdata appendString:@" AND "];
                    } else {
                        first = NO;
                    }
                    [pkdata appendFormat:@"%@='%@'",ky,[fila objectForKey:ky]];
                }
                NSString *querySQL = [NSString stringWithFormat:
                                      @"SELECT count(*) FROM %@ WHERE %@",
                                      table, pkdata];
                const char *query_stmt = [querySQL UTF8String];
                if (sqlite3_prepare_v2(_database,
                                       query_stmt, -1, &statement, NULL) == SQLITE_OK)
                {
                    if (sqlite3_step(statement) == SQLITE_ROW)
                    {
                        int cantidad = sqlite3_column_int(statement, 0);
                        NSString *ins_upd;
                        if(cantidad==0)
                        {
                            NSMutableString *colnames = [[NSMutableString alloc] init];
                            BOOL first;
                            first = YES;
                            for (NSDictionary *col in [tabla objectForKey:@"columns"]) {
                                if (!first) {
                                    [colnames appendString:@", "];
                                } else {
                                    first = NO;
                                }
                                [colnames appendFormat:@"%@",[col objectForKey:@"name"]];
                            }
                            
                            NSMutableString *colvalues = [[NSMutableString alloc] init];
                            first = YES;
                            for (NSDictionary *col in [tabla objectForKey:@"columns"]) {
                                if (!first) {
                                    [colvalues appendString:@", "];
                                } else {
                                    first = NO;
                                }
                                [colvalues appendFormat:@"'%@'", [ [NSString stringWithFormat:@"%@",[fila objectForKey:[col objectForKey:@"name"]]] stringByReplacingOccurrencesOfString: @"'" withString:@"''" ]  ];
                            }
                            ins_upd = [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES(%@)", table, colnames, colvalues];
                            // NSLog(@"%@",ins_upd);
                        } else {
                            BOOL coma = NO;
                            NSMutableString * cols = [[NSMutableString alloc] init];
                            for (id key in fila) {
                                if ([pknames indexOfObject:key] == NSNotFound) {
                                    if (coma) {
                                        [cols appendString:@", "];
                                    } else {
                                        coma = YES;
                                    }
                                    NSString * val = [NSString stringWithFormat:@"%@", [fila objectForKey:key]];
                                    val = [val stringByReplacingOccurrencesOfString: @"'" withString:@"''"];
                                    [cols appendString:[NSString stringWithFormat:@"%@='%@'",key,val]];
                                }
                            }
                            ins_upd = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE %@", table, cols, pkdata];
                        }
                        //NSLog(@"Query: %@",ins_upd);
                        
                        const char *insert_stmt = [ins_upd UTF8String];
                        sqlite3_prepare_v2(_database, insert_stmt,
                                           -1, &statement2, NULL);
                        if (sqlite3_step(statement2) == SQLITE_DONE)
                        {
                            // NSLog(@"Inserted or updated id=%@ in table %@",[fila objectForKey:@"id"], table);
                            self._status =  [NSString stringWithFormat:@"%@ added or updated", table];
                        } else {
                            self._status = [NSString stringWithFormat:@"Failed to add %@", table];
                            NSLog( @"\n\n- Failed from sqlite3_step.\nError is: %s \nQuery is: %s", sqlite3_errmsg(_database), insert_stmt);
                        }
                    }
                }
                else {
                    NSLog( @"\n\n* Failed from sqlite3_step. Error is:  %s", sqlite3_errmsg(_database) );
                }
                sqlite3_finalize(statement);
                statement = nil;
            }
            sqlite3_close(_database);
            _database = nil;
        }
    }
    return rows;

}

-(void) asyncExecuteQuery:(NSString*)query withCallback:(void (^)(NSArray *rows))onfinish
{
    [DBManager addToQueue:@selector(executeQuery:) withParam:query andCallback:^(NSObject *data) {
        onfinish((NSArray*)data);
    }];
}

-(NSArray*) executeQuery:(NSString*)query
{
    NSMutableArray *r = [[NSMutableArray alloc] init];
    const char *dbpath = [databasePath UTF8String];
    if(_database){
        sqlite3_close(_database);
    }
    if (sqlite3_open(dbpath, &_database) == SQLITE_OK)
    {
        sqlite3_stmt *statement;
        const char *query_stmt = [query UTF8String];
        if (sqlite3_prepare_v2(_database,
                               query_stmt, -1, &statement, NULL) == SQLITE_OK)
        {
            NSString *name;
            char *value;
            while (sqlite3_step(statement) == SQLITE_ROW)
            {
                NSMutableDictionary *row = [[NSMutableDictionary alloc] init];
                for (int i=0; i<sqlite3_column_count(statement); i++)
                {
                    value = nil;
                    @try {
                        name = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, i)];
                        value = (char*)sqlite3_column_text(statement, i);
                        if(value!=nil){
                            NSString *Value =  [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
                            row[name] = Value;
                        }
                    }
                    @catch (NSException *exception) {
                        NSLog(@"Error on prepeardb for (%@, %s): %@",name, value, exception);
                    }
                }
                [r addObject:row];
            }
        }
    }
    return r;
}

-(void) asyncGetDataFromTable:(NSString*)table withFilter:(NSString*)filter andCallback:(void (^)(NSArray *rows))onfinish
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:table forKey:@"tablename"];
    [data setObject:filter forKey:@"filter"];
    [DBManager addToQueue:@selector(getDataFromTableWithData:) withParam:data andCallback:^(NSObject *data) {
        @try {
            onfinish((NSArray*)data);
        }
        @catch (NSException *exception) {
            NSLog(@"Error [asyncGetDataFromTableWithData]: %@", exception);
        }
    }];
}

-(NSArray*) getDataFromTableWithData:(NSDictionary*)data
{
    // @synchronized(self)
    {
        NSString* table = [data objectForKey:@"tablename"];
        NSString* filter = [data objectForKey:@"filter"];
        // NSMutableArray* (^bloque)(NSMutableArray*) = [data objectForKey:@"bloque"];
        if (!filter) {
            filter = @"";
        }
        //NSLog(@"obteniendo sitios...");
        NSMutableArray *r = [[NSMutableArray alloc] init];
        sqlite3_stmt    *statement;
        const char *dbpath = [databasePath UTF8String];
        if(_database){
            sqlite3_close(_database);
        }
        if (sqlite3_open(dbpath, &_database) == SQLITE_OK)
        {
            @try{
                NSString *querySQL = [NSString stringWithFormat:@"SELECT * FROM %@ %@", table, filter];
                const char *query_stmt = [querySQL UTF8String];
                if (sqlite3_prepare_v2(_database,
                                       query_stmt, -1, &statement, NULL) == SQLITE_OK)
                {
                    NSString *name;
                    char *value;
                    while (sqlite3_step(statement) == SQLITE_ROW)
                    {
                        NSMutableDictionary *row = [[NSMutableDictionary alloc] init];
                        for (int i=0; i<sqlite3_column_count(statement); i++)
                        {
                            value = nil;
                            @try {
                                name = [[NSString alloc] initWithUTF8String:sqlite3_column_name(statement, i)];
                                value = (char*)sqlite3_column_text(statement, i);
                                if(value!=nil){
                                    // NSString *Value =  [NSString stringWithFormat:@"%s", value];
                                    NSString *Value =  [NSString stringWithCString:value encoding:NSUTF8StringEncoding];
                                    row[name] = Value;
                                }
                            }
                            @catch (NSException *exception) {
                                NSLog(@"Error on prepeardb for (%@, %s): %@",name, value, exception);
                            }
                        }
                        [r addObject:row];
                    }
                }
                sqlite3_finalize(statement);
                statement = nil;
            }@catch (NSException *ex) {
                NSLog(@"Error on prepeardb: %@",ex);
            }
            sqlite3_close(_database);
            _database = nil;
        }
        /*
        NSArray *processedArray;
        if (bloque) {
            processedArray = bloque(r);
        } else {
            processedArray = r;
        }
         */
        return r;
    }
}

+(void) addToQueue:(SEL)selector withParam:(NSObject*)param andCallback:(void(^)(NSObject *data))onfinish
{
    NSMutableDictionary *arr = [[NSMutableDictionary alloc] init];
    NSString *selectorAsString = NSStringFromSelector(selector);
    [arr setObject:selectorAsString forKey:@"selector"];
    [arr setObject:param forKey:@"param"];
    [arr setObject:onfinish forKey:@"onFinish"];
    [selectores enqueue:arr];
}


+(NSDictionary*) createColumn:(NSString*)name withType:(NSString*)type andRestrictions:(NSString*)restrictions
{
    NSMutableDictionary *column = [[NSMutableDictionary alloc] init];
    [column setObject:name forKey:@"name"];
    [column setObject:type forKey:@"type"];
    [column setObject:restrictions forKey:@"restrictions"];
    return column;
}

+(NSDictionary*) createTable:(NSString*)name withColumns:(NSArray*)columns
{
    NSMutableArray *cols = [[NSMutableArray alloc] init];
    NSMutableArray *pkcols = [[NSMutableArray alloc] init];
    for (NSDictionary* dict in columns) {
        NSMutableDictionary* mdict = [[NSMutableDictionary alloc] initWithDictionary:dict];
        if (!([[mdict objectForKey:@"restrictions"] rangeOfString:@"PRIMARY KEY"].location == NSNotFound)) {
            [mdict setObject:@"" forKey:@"restrictions"];
            [pkcols addObject:[mdict objectForKey:@"name"]];
        }
        [cols addObject:mdict];
    }
    NSMutableDictionary *table = [[NSMutableDictionary alloc] init];
    [table setObject:name forKey:@"name"];
    [table setObject:cols forKey:@"columns"];
    [table setObject:pkcols forKey:@"keys"];
    return table;
}

+(void) startDispatch
{
    if(!single){
        single = [[DBManager alloc] init];
        if(!sqlOperationQueue){
            sqlOperationQueue = [[NSOperationQueue alloc] init];
        }
        if(!selectores){
            selectores = [[NSMutableArray alloc] init];
        }
        [single performSelectorInBackground:@selector(dispatchAll) withObject:nil];
    }
}

-(void) dispatchAll
{
    while (YES) {;
        if ([selectores count]>0) {
            @try {
                NSMutableDictionary *queue = (NSMutableDictionary*)[selectores dequeue];
                SEL selector = NSSelectorFromString([queue objectForKey:@"selector"]);
                NSObject *param = [queue objectForKey:@"param"];
                void (^onfinish)(NSObject *data) = [queue objectForKey:@"onFinish"];
                IMP imp = [single methodForSelector:selector];
                NSObject* (*func)(id, SEL, NSObject *) = (void *)imp;
                NSObject *opRes = func(single, selector, param);
                dispatch_async(dispatch_get_main_queue(), ^{
                    onfinish(opRes);
                });
            }
            @catch (NSException *exception) {
                NSLog(@"Error: %@",exception);
            }
        }
    }
}


@end
