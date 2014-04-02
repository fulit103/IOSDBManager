//
//  DBManager.h
//  Alacarta
//
//  Created by Oscar Andrés Granada on 25/01/14.
//  Copyright (c) 2014 Tecmovin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "NSMutableArray+NSMutableArray_QueueAdditions.h"
#import <MapKit/MapKit.h>

NSMutableDictionary* (^bloqueD)(NSMutableDictionary*);
NSMutableArray* (^bloqueA)(NSMutableArray*);

@interface DBManager : NSObject
-(id)init;
-(void) createTables;

-(void) asyncExecuteQuery:(NSString*)query withCallback:(void (^)(NSArray *rows))onfinish;
-(void) asyncUpdateTable:(NSString*)table withContent:(NSArray *)rows;
-(void) asyncGetDataFromTable:(NSString*)table withFilter:(NSString*)filter andCallback:(void (^)(NSArray *rows))onfinish;
-(NSArray*) getDataFromTableWithData:(NSDictionary*)data;
-(NSArray*) executeQuery:(NSString*)query;
-(NSArray*) updateTable:(NSDictionary*)data;

+(void) addTable:(NSDictionary*)table;
+(NSDictionary*) createTable:(NSString*)name withColumns:(NSArray*)columns;
+(NSDictionary*) createColumn:(NSString*)name withType:(NSString*)type andRestrictions:(NSString*)restrictions;
+(void) startDispatch;
+(void) addToQueue:(SEL)selector withParam:(NSObject*)param andCallback:(void(^)(NSObject *data))onfinish;

@property (strong, nonatomic) NSString *_status;
@property (atomic) sqlite3 *database;

@end
