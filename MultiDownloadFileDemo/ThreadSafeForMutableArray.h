//
//  ThreadSafeForMutableArray.h
//  MultiDownloaderDemo
//
//  Created by Doan Van Vu on 8/29/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ThreadSafeForMutableArray : NSObject

#pragma mark - filteredArrayUsingPredicate
- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)predicate;

#pragma mark - removeObjectAtIndex
- (void)removeObjectAtIndex:(NSUInteger)index;

#pragma mark - removeObject
- (void)removeObject:(NSObject *)object;

#pragma mark - objectAtIndex
- (id)objectAtIndex:(NSUInteger)index;

#pragma mark - addObject
- (void)addObject:(NSObject *)object;

#pragma mark - count
- (NSUInteger)count;

#pragma mark - init
- (instancetype)init;

#pragma mark - enumerateObjectsUsingBlock
- (void)enumerateObjectsUsingBlock:(void (^)(id object, NSUInteger idx, BOOL *stop))block;

@end
