//
//  MultiDownloadFileManager.m
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//


#import "ThreadSafeMutableDictionary.h"
#import "ThreadSafeForMutableArray.h"
#import "MultiDownloadFileManager.h"
#import <UIKit/UIKit.h>

@interface MultiDownloadFileManager () <NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic) ThreadSafeMutableDictionary* currentActiveDownloadItems;
@property (nonatomic) ThreadSafeForMutableArray* pendingDownloadItems;
@property (nonatomic) ThreadSafeForMutableArray* resumeDownloadItems;
@property (nonatomic) dispatch_queue_t createDirectoryQueue;
@property (nonatomic) dispatch_queue_t removeItemQueue;
@property (nonatomic) NSURLSession* downloadSession;

@end

@implementation MultiDownloadFileManager

#pragma mark - sharedDefaultManager...

+ (instancetype)sharedDefaultManager {
    
    static id sharedManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        sharedManager = [[self alloc] initDefaultSession];
    });
    
    return sharedManager;
}

#pragma mark - sharedBackgroundManager...

+ (instancetype)sharedBackgroundManager {
    
    static id sharedManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        sharedManager = [[self alloc] initBackgroundSession];
    });
    
    return sharedManager;
}

#pragma mark - setup...

- (void)setup {

    // Get old tasks and cancel
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_downloadSession getTasksWithCompletionHandler:^(NSArray* tasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        
        for (NSURLSessionDownloadTask* downloadTask in downloadTasks) {
            
            [downloadTask cancel];
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    _currentActiveDownloadItems = [[ThreadSafeMutableDictionary alloc] init];
    _pendingDownloadItems = [[ThreadSafeForMutableArray alloc] init];
    _resumeDownloadItems = [[ThreadSafeForMutableArray alloc] init];
    _removeItemQueue = dispatch_queue_create("REMOVEITEM_QUEUE", DISPATCH_QUEUE_SERIAL);
    _createDirectoryQueue = dispatch_queue_create("CREATE_DIRECTORY_QUEUE", DISPATCH_QUEUE_SERIAL);
    _currentDownloadMaximum = 1;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminalApp) name:UIApplicationWillTerminateNotification object:nil];
    
    [self createDownloadTempDirectory];
}

#pragma mark - initDefaultSession...

- (instancetype)initDefaultSession {
    
    self = [super init];
    
    NSURLSessionConfiguration* configurationDefault = [NSURLSessionConfiguration defaultSessionConfiguration];
    configurationDefault.timeoutIntervalForRequest = 12;
    configurationDefault.HTTPMaximumConnectionsPerHost = 5;
    _downloadSession = [NSURLSession sessionWithConfiguration:configurationDefault delegate:self delegateQueue:nil];
    [self setup];
    return self;
}

#pragma mark - initBackgroundSession...

- (instancetype)initBackgroundSession {
    
    self = [super init];
    
    NSURLSessionConfiguration* configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"abs.com.DownloadApp"];
    configuration.HTTPMaximumConnectionsPerHost = 5;
    _downloadSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    [self setup];
    return self;
}

#pragma mark - terminalApp

- (void)terminalApp {
    
    [_downloadSession invalidateAndCancel];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    NSString* identifier = [NSString stringWithFormat:@"%lud",(unsigned long)[downloadTask taskIdentifier]];
    DownloadFileItem* downloadFileItem = [_currentActiveDownloadItems getObjectForKey:identifier];
    
    if (downloadFileItem) {
        
        NSURL* destinationLocation;
        
        if (downloadFileItem.directoryName) {
            
            destinationLocation = [[[self cachesDirectoryUrlPath] URLByAppendingPathComponent:downloadFileItem.directoryName] URLByAppendingPathComponent:downloadFileItem.fileName];
        } else {
            
            destinationLocation = [[self cachesDirectoryUrlPath] URLByAppendingPathComponent:downloadFileItem.fileName];
        }
        
        dispatch_sync(_removeItemQueue, ^{
            
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationLocation error:nil];
            [self deleteFileWithName:downloadFileItem.fileName];
        });
        
        if (downloadFileItem.infoFileDownloadBlock) {
            
            downloadFileItem.downloadItemStatus = DownloadItemStatusCompleted;
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
            });
        }
        
        [_currentActiveDownloadItems removeObjectForkey:identifier];
        
        if(_pendingDownloadItems.count > 0) {
            
            DownloadFileItem* nextDownloadFileItem = [_pendingDownloadItems objectAtIndex:0];
            [nextDownloadFileItem.downloadTask resume];
            
            [_currentActiveDownloadItems setObject:nextDownloadFileItem forKey:nextDownloadFileItem.identifier];
            [_pendingDownloadItems removeObject:nextDownloadFileItem];
        }
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
 
    NSString* identifier = [NSString stringWithFormat:@"%lud",(unsigned long)[downloadTask taskIdentifier]];
    DownloadFileItem* downloadFileItem = [_currentActiveDownloadItems getObjectForKey:identifier];
    
    if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
        
        downloadFileItem.downloadItemStatus = DownloadItemStatusStarted;
    }
    
    downloadFileItem.byteRecives = bytesWritten;
    downloadFileItem.totalbyteRecives = totalBytesWritten;
    downloadFileItem.totalBytes = totalBytesExpectedToWrite;
    
    if (downloadFileItem.infoFileDownloadBlock) {
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            downloadFileItem.infoFileDownloadBlock(downloadFileItem);
        });
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)downloadTask didCompleteWithError:(NSError *)error {

    if (!error) {
        
        return;
    }
    
    NSString* identifier = [NSString stringWithFormat:@"%lud",(unsigned long)[downloadTask taskIdentifier]];
    
    if (identifier) {
        
        DownloadFileItem* downloaderItem = [_currentActiveDownloadItems getObjectForKey:identifier];
        
        if (!downloaderItem) {
            
            NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", identifier];
            
            if ([_resumeDownloadItems filteredArrayUsingPredicate:predicate].count > 0) {
                
                downloaderItem = [_resumeDownloadItems filteredArrayUsingPredicate:predicate][0];
                [_resumeDownloadItems removeObject:downloaderItem];
            }
        } else {
            
            [_currentActiveDownloadItems removeObjectForkey:identifier];
        }
        
        switch ([error code]) {
                
            case NSURLErrorCancelled:
                
                NSLog(@"NSURLErrorCancelled");
                break;
            case kCFHostErrorUnknown:
                
                // Could not found directory to save file
                NSLog(@"kCFHostErrorUnknown");
                break;
            case NSURLErrorNotConnectedToInternet:
                
                // Cannot connect to the internet
                NSLog(@"NSURLErrorNotConnectedToInternet");
                break;
            case NSURLErrorTimedOut:
                
                // Time out connection
                NSLog(@"NSURLErrorTimedOut");
                break;
            case NSURLErrorNetworkConnectionLost:
                
                // NSURLErrorNetworkConnectionLost
                NSLog(@"NSURLErrorNetworkConnectionLost");
                break;
            default:
                break;
        }
    }
}

#pragma mark - startDownloadFileFromURL

- (void)startDownloadFileFromURL:(NSString *)sourceURL infoFileDownloadBlock:(InfoFileDownloadBlock)infoFileDownloadBlock callbackQueue:(dispatch_queue_t)queue {
    
    NSURL* url = [NSURL URLWithString:sourceURL];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask* downloadTask = [_downloadSession downloadTaskWithRequest:request];
    
    DownloadFileItem* downloadFileItem = [[DownloadFileItem alloc] initWithActiveDownloadTask:downloadTask info:infoFileDownloadBlock callbackQueue:queue];
    
    downloadFileItem.startDate = [NSDate date];
    downloadFileItem.sourceURL = sourceURL;
    downloadFileItem.fileName = [sourceURL lastPathComponent];
    downloadFileItem.downloadItemStatus = DownloadItemStatusPending;
    
    if (_currentActiveDownloadItems.count >= _currentDownloadMaximum) {
        
        NSLog(@"pending..... %@",downloadFileItem.identifier);
        [_pendingDownloadItems addObject:downloadFileItem];
    } else {
        
        [downloadFileItem.downloadTask resume];
        [_currentActiveDownloadItems setObject:downloadFileItem forKey:downloadFileItem.identifier];
    }
    
    // callback to update UI
    if (downloadFileItem.infoFileDownloadBlock) {
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            
            downloadFileItem.infoFileDownloadBlock(downloadFileItem);
        });
    }
}

#pragma mark - cancelDownloadForUrl

- (void)cancelDownloadForUrl:(NSString *)fileIdentifier {
    
    DownloadFileItem* downloadFileItem = [_currentActiveDownloadItems getObjectForKey:fileIdentifier];
    
    if (downloadFileItem) {
        
        // cancel activeList
        [_currentActiveDownloadItems removeObjectForkey:fileIdentifier];
        
        if (_pendingDownloadItems.count > 0) {
            
            DownloadFileItem* nextdDownloadFileItem = [_pendingDownloadItems objectAtIndex:0];
            
            nextdDownloadFileItem.downloadItemStatus = DownloadItemStatusStarted;
            [nextdDownloadFileItem.downloadTask resume];
            [_currentActiveDownloadItems setObject:nextdDownloadFileItem forKey:nextdDownloadFileItem.identifier];
            [_pendingDownloadItems removeObject:nextdDownloadFileItem];
        }
        
        downloadFileItem.downloadItemStatus = DownloadItemStatusCancelled;
        [downloadFileItem.downloadTask cancel];
        
        // callback to update UI
        if (downloadFileItem.infoFileDownloadBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
            });
        }
    } else {
        
        NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
        
        if ([_pendingDownloadItems filteredArrayUsingPredicate:predicate].count > 0) {
            
            // cancel pendingList
            downloadFileItem = [_pendingDownloadItems filteredArrayUsingPredicate:predicate][0];
            downloadFileItem.downloadItemStatus = DownloadItemStatusCancelled;
            [downloadFileItem.downloadTask cancel];
            
            // callback to update UI
            if (downloadFileItem.infoFileDownloadBlock) {
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                    downloadFileItem.infoFileDownloadBlock(downloadFileItem);
                });
            }
            
            [_pendingDownloadItems removeObject:downloadFileItem];
        } else {
            
            NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
            
            // cancel resumeList
            if ([_resumeDownloadItems filteredArrayUsingPredicate:predicate].count > 0) {
                
                downloadFileItem = [_resumeDownloadItems filteredArrayUsingPredicate:predicate][0];
                downloadFileItem.downloadItemStatus = DownloadItemStatusCancelled;
                [downloadFileItem.downloadTask cancel];
               
                // callback to update UI
                if (downloadFileItem.infoFileDownloadBlock) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        
                        downloadFileItem.infoFileDownloadBlock(downloadFileItem);
                    });
                }
                [_resumeDownloadItems removeObject:downloadFileItem];
            }
        }
    }
}

#pragma mark - stopDownLoadForUrl...

- (void)pauseDownLoadForUrl:(NSString *)fileIdentifier {
    
    DownloadFileItem* downloadFileItem = [_currentActiveDownloadItems getObjectForKey:fileIdentifier];
    NSLog(@"%ld",downloadFileItem.downloadTask.state);
    
    if (downloadFileItem) {
        
        // pause currentTask running
        [downloadFileItem.downloadTask suspend];
        downloadFileItem.downloadItemStatus = DownloadItemStatusPaused;
       
        // callback to update UI
        if (downloadFileItem.infoFileDownloadBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
            });
        }
        // add into resumeList
        [_resumeDownloadItems addObject:downloadFileItem];
        
        // remove out of activeList
        [_currentActiveDownloadItems removeObjectForkey:fileIdentifier];
        
        // check PendingList exits -> run next task.
        if (_pendingDownloadItems.count > 0) {
            
            DownloadFileItem* nextDownloadFileItem = [_pendingDownloadItems objectAtIndex:0];
            nextDownloadFileItem.downloadItemStatus = DownloadItemStatusStarted;
            [nextDownloadFileItem.downloadTask resume];
            [_currentActiveDownloadItems setObject:nextDownloadFileItem forKey:nextDownloadFileItem.identifier];
            
            //remove out of pendingList
            [_pendingDownloadItems removeObject:nextDownloadFileItem];
        }
    } else {
        
        // pause pending Task
        // get it and change status
        NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
        
        if ([_pendingDownloadItems filteredArrayUsingPredicate:predicate].count > 0) {
            
            DownloadFileItem* pendingDownloadFileItem = [_pendingDownloadItems filteredArrayUsingPredicate:predicate][0];
            [pendingDownloadFileItem.downloadTask suspend];
            pendingDownloadFileItem.downloadItemStatus = DownloadItemStatusPaused;
            // callback to update UI
            if (pendingDownloadFileItem.infoFileDownloadBlock) {
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                    pendingDownloadFileItem.infoFileDownloadBlock(pendingDownloadFileItem);
                });
            }
            // add into resumeList
            [_resumeDownloadItems addObject:pendingDownloadFileItem];
            
            //remove out of pendingList
            [_pendingDownloadItems removeObject:pendingDownloadFileItem];
        }
    }
}

#pragma mark - resumeDownLoadForUrl...

- (void)resumeDownLoadForUrl:(NSString *)fileIdentifier {
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
    
    if ([_resumeDownloadItems filteredArrayUsingPredicate:predicate].count > 0) {
        
        if (_currentActiveDownloadItems.count >= _currentDownloadMaximum) {
            
            // stop task frist and start new task.
            DownloadFileItem* currentActiveTask = [_currentActiveDownloadItems getFristObject];
            currentActiveTask.downloadItemStatus =  DownloadItemStatusPaused;
            [currentActiveTask.downloadTask suspend];
            
            // callback to update UI
            if (currentActiveTask.infoFileDownloadBlock) {
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                    currentActiveTask.infoFileDownloadBlock(currentActiveTask);
                });
            }
            [_currentActiveDownloadItems removeObjectForkey:currentActiveTask.identifier];
            
            // add into resumeList
            [_resumeDownloadItems addObject:currentActiveTask];
        }
        
        DownloadFileItem* downloadFileItem = [_resumeDownloadItems filteredArrayUsingPredicate:predicate][0];
        downloadFileItem.downloadItemStatus = DownloadItemStatusStarted;
        [downloadFileItem.downloadTask resume];
        [_currentActiveDownloadItems setObject:downloadFileItem forKey:downloadFileItem.identifier];
        [_resumeDownloadItems removeObject:downloadFileItem];
    }
}

#pragma mark - createDownloadTempDirectory

- (void)createDownloadTempDirectory {
    
    // Get Caches directory
    NSArray* cacheDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSAllDomainsMask, YES);
    NSString* path = [cacheDirectory firstObject];
    path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"com.apple.nsurlsessiond/Downloads/%@",[[NSBundle mainBundle] bundleIdentifier]]];
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        // Create new directory if not existed
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        }
    });
}

#pragma mark - cachesDirectoryUrlPath

- (NSURL *)cachesDirectoryUrlPath {
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cachesDirectory = [paths objectAtIndex:0];
    NSURL* cachesDirectoryUrl = [NSURL fileURLWithPath:cachesDirectory];
    
    return cachesDirectoryUrl;
}

#pragma mark - deleteFileWithName

- (BOOL)deleteFileWithName:(NSString *)fileName {
    
    return [self deleteFileWithName:fileName inDirectory:nil];
}

#pragma mark - deleteFileWithName

- (BOOL)deleteFileWithName:(NSString *)fileName inDirectory:(NSString *)directoryName {
    
    BOOL deleted = NO;
    NSError* error;
    NSURL* fileLocation;
    
    if (directoryName) {
        
        fileLocation = [[[self cachesDirectoryUrlPath] URLByAppendingPathComponent:directoryName] URLByAppendingPathComponent:fileName];
    } else {
        
        fileLocation = [[self cachesDirectoryUrlPath] URLByAppendingPathComponent:fileName];
    }
    
    if ([self fileExistsWithName:fileName inDirectory:directoryName]) {
        
        // Move downloaded item from tmp directory to te caches directory
        [[NSFileManager defaultManager] removeItemAtURL:fileLocation error:&error];
        
        if (error) {
            
            deleted = NO;
            NSLog(@"Error deleting file: %@", error);
        } else {
            
            deleted = YES;
        }
    }
    
    return deleted;
}

/* Condition to check file Exits */

#pragma mark - fileExistsForUrl

- (BOOL)fileExistsForUrl:(NSURL *)sourceURL {
    
    return [self fileExistsForUrl:sourceURL inDirectory:nil];
}

#pragma mark - fileExistsForUrl

- (BOOL)fileExistsForUrl:(NSURL *)sourceURL inDirectory:(NSString *)directoryName {
    
    return [self fileExistsWithName:[sourceURL lastPathComponent] inDirectory:directoryName];
}

#pragma mark - fileExistsWithName

- (BOOL)fileExistsWithName:(NSString *)fileName {
    
    return [self fileExistsWithName:fileName inDirectory:nil];
}

#pragma mark - fileExistsWithName...

- (BOOL)fileExistsWithName:(NSString *)fileName inDirectory:(NSString *)directoryName {
    
    BOOL exists = NO;
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString* cachesDirectory = [paths objectAtIndex:0];
    NSLog(@"%@",cachesDirectory);
    
    // if no directory was provided, we look by default in the base cached dir
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[cachesDirectory stringByAppendingPathComponent:directoryName] stringByAppendingPathComponent:fileName]]) {
        
        exists = YES;
    }
    
    return exists;
}

@end
