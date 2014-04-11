//
//  NSMutableArray+NSMutableArray_QueueAdditions.h
//  AlacartaApp
//
//  Created by Oscar Andrés Granada on 14/02/14.
//  Copyright (c) 2014 MikoMovil. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (NSMutableArray_QueueAdditions)
- (id) dequeue;
- (void) enqueue:(id)obj;
@end
