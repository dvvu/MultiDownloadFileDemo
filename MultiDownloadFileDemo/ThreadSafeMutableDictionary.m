//
//  ThreadSafeMutableDictionary.m
//  PhoneBook
//
//  Created by chuonghm on 8/9/17.
//  Copyright © 2017 VNG Corp., Zalo Group. All rights reserved.
//

#import "ThreadSafeMutableDictionary.h"

@interface ThreadSafeMutableDictionary()

@property (nonatomic) NSMutableDictionary* threadSafeDictionary;
@property (nonatomic) dispatch_queue_t threadSafeDictionaryQueue;

@end

@implementation ThreadSafeMutableDictionary

#pragma mark - init

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        _threadSafeDictionary = [[NSMutableDictionary alloc]init];
        _threadSafeDictionaryQueue = dispatch_queue_create("threadSafeDictionar_Queue", DISPATCH_QUEUE_CONCURRENT);
    }

    return self;
}

#pragma mark - getObjectForKey

- (id)getObjectForKey:(id)key {
    
    NSObject* __block result;
    
    dispatch_sync(_threadSafeDictionaryQueue, ^{
        
        result = _threadSafeDictionary[key];
    });
    
    return result;
}

#pragma mark - setObjectForKey

- (void)setObject:(id)object forKey:(id<NSCopying>)key {
    
     dispatch_barrier_async(_threadSafeDictionaryQueue, ^{
        
        _threadSafeDictionary[key] = object;
    });
}

#pragma mark - removeObjectForkey

- (void)removeObjectForkey:(NSString *)key {
    
     dispatch_barrier_async(_threadSafeDictionaryQueue, ^{
        
        [_threadSafeDictionary removeObjectForKey:key];
    });
}

#pragma mark - removeAllObjects

- (void)removeAllObjects {
    
     dispatch_barrier_async(_threadSafeDictionaryQueue, ^{
        
        [_threadSafeDictionary removeAllObjects];
    });
}

#pragma mark - count

- (NSUInteger)count {
    
    NSUInteger __block count;
    
    dispatch_sync(_threadSafeDictionaryQueue, ^{
        
        count = [_threadSafeDictionary count];
    });
    
    return count;
}

#pragma mark - getFristObject

- (id)getFristObject {
    
    NSObject* __block result;
    
    dispatch_sync(_threadSafeDictionaryQueue, ^{
        
        result = [[_threadSafeDictionary allValues] firstObject];
    });
    
    return result;
}

@end
