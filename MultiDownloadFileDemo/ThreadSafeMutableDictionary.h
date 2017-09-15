//
//  ThreadSafeMutableDictionary.h
//  PhoneBook
//
//  Created by chuonghm on 8/9/17.
//  Copyright © 2017 VNG Corp., Zalo Group. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ThreadSafeMutableDictionary : NSObject

#pragma mark - setObjectForKey
- (void)setObject:(id)object forKey:(id <NSCopying>)key;

#pragma mark - removeObjectForkey
- (void)removeObjectForkey:(id <NSCopying>)key;

#pragma mark - getObjectForKey
- (id)getObjectForKey:(id)key;

#pragma mark - removeAllObjects
- (void)removeAllObjects;

#pragma mark - getFristObject
- (id)getFristObject;

#pragma mark - count
- (NSUInteger)count;

@end
