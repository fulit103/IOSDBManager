//
//  NSMutableArray+NSMutableArray_QueueAdditions.m
//  AlacartaApp
//
//  Created by Oscar Andrés Granada on 14/02/14.
//  Copyright (c) 2014 MikoMovil. All rights reserved.
//

#import "NSMutableArray+NSMutableArray_QueueAdditions.h"

@implementation NSMutableArray (NSMutableArray_QueueAdditions)
- (id) dequeue {
    // if ([self count] == 0) return nil; // to avoid raising exception (Quinn)
    id headObject = [self objectAtIndex:0];
    if (headObject != nil) {
        [self removeObjectAtIndex:0];
    }
    return headObject;
}

// Add to the tail of the queue (no one likes it when people cut in line!)
- (void) enqueue:(id)anObject {
    [self addObject:anObject];
    //this method automatically adds to the end of the array
}
@end
