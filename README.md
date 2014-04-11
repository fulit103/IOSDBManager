IOSDBManager
============

Simple IOS SQLite3 queued execution helper

USAGE
=====

1. Create your tables.

```c
    
    DBManager *mgr = [[DBManager alloc] init];
    NSArray *columns = @[
                         [DBManager createColumn:@"id" withType:@"INTEGER" andRestrictions:@"PRIMARY KEY AUTOINCREMENT"],
                         [DBManager createColumn:@"name" withType:@"VARCHAR(100)" andRestrictions:@""],
                         [DBManager createColumn:@"author" withType:@"VARCHAR(100)" andRestrictions:@""]
                         ];
    [DBManager addTable:[DBManager createTable:@"BOOKS" withColumns:columns]];
    
```

2. Insert into your tables.

´´´c

    NSArray *data = @[@{@"name":@"El principito", @"name":@"Antoine de Saint-Exupéry"}];
    DBManager *mgr = [[DBManager alloc] init];
    [mgr asyncUpdateTable:@"BOOKS" withContent:arr];

´´´

3. Make your queries.

```c

    DBManager *mgr = [[DBManager alloc] init];
    [mgr asyncGetDataFromTable:@"BOOKS" withFilter:@" WHILE author like '%Saint%' " andCallback:^(NSArray *rows) {
        [self updateBooks:rows];
    }];

```
Or

```c

    DBManager *mgr = [[DBManager alloc] init];
    [mgr asyncExecuteQuery:@"SELECT name from BOOKS where id='1' " withCallback:^(NSArray *rows) {
         [self updateBooks:rows];
    }]

```
