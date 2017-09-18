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

@property (nonatomic) ThreadSafeForMutableArray* downloadFileItems;
@property (nonatomic) dispatch_queue_t createDirectoryQueue;
@property (nonatomic) dispatch_queue_t removeItemQueue;
@property (nonatomic) NSURLSession* downloadSession;

@property (nonatomic) int currentActiveDownloadTasks;
@property (nonatomic) int pendingDownloadTasks;
@property (nonatomic) int resumeDownloadTasks;

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
    
    _downloadFileItems = [[ThreadSafeForMutableArray alloc] init];
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
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", identifier];
    
    if ([[_downloadFileItems filteredArrayUsingPredicate:predicate] count] <= 0) {
        
        return;
    }
    DownloadFileItem* downloadFileItem = [_downloadFileItems filteredArrayUsingPredicate:predicate][0];
    
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
            _currentActiveDownloadTasks -= 1;
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
                [_downloadFileItems removeObject:downloadFileItem];
            });
        }
        
        if (_pendingDownloadTasks > 0 && _currentActiveDownloadTasks < _currentDownloadMaximum) {
            
            __block DownloadFileItem* nextDownloadFileItem;
            
            [_downloadFileItems enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL* stop) {
                
                DownloadFileItem* downloadFileItem = object;
                
                if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
                    
                    nextDownloadFileItem = downloadFileItem;
                    return;
                }
            }];
            
            [nextDownloadFileItem.downloadTask resume];
            _currentActiveDownloadTasks += 1;
            _pendingDownloadTasks -= 1;
        }
    }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
 
    NSString* identifier = [NSString stringWithFormat:@"%lud",(unsigned long)[downloadTask taskIdentifier]];
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", identifier];
   
    if ([[_downloadFileItems filteredArrayUsingPredicate:predicate] count] <= 0) {
        
        return;
    }
    DownloadFileItem* downloadFileItem = [_downloadFileItems filteredArrayUsingPredicate:predicate][0];
    
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
    
    NSLog(@"c: %d, p: %d, r: %d",_currentActiveDownloadTasks, _pendingDownloadTasks, _resumeDownloadTasks);
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)downloadTask didCompleteWithError:(NSError *)error {

    if (!error) {
        
        return;
    }
    
    NSString* identifier = [NSString stringWithFormat:@"%lud",(unsigned long)[downloadTask taskIdentifier]];
    
    if (identifier) {
        
        NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", identifier];
        
        if ([[_downloadFileItems filteredArrayUsingPredicate:predicate] count] <= 0) {
            
            return;
        }
        
        DownloadFileItem* downloadFileItem = [_downloadFileItems filteredArrayUsingPredicate:predicate][0];
        
        if (downloadFileItem.downloadItemStatus == DownloadItemStatusPaused) {
            
            [_downloadFileItems removeObject:downloadFileItem];
            _resumeDownloadTasks -= 1;
        } else {
            
            [_downloadFileItems removeObject:downloadFileItem];
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
    
    if ([self fileExistsForUrl:url]) {
        
        NSLog(@"File Exits");
    } else if ([self fileDownloadCompletedForUrl: sourceURL]) {
        
        NSLog(@"File is Downloading.......");
    } else {
        
        NSURLRequest* request = [NSURLRequest requestWithURL:url];
        NSURLSessionDownloadTask* downloadTask = [_downloadSession downloadTaskWithRequest:request];
        
        DownloadFileItem* downloadFileItem = [[DownloadFileItem alloc] initWithActiveDownloadTask:downloadTask info:infoFileDownloadBlock callbackQueue:queue];
        
        downloadFileItem.startDate = [NSDate date];
        downloadFileItem.sourceURL = sourceURL;
        downloadFileItem.fileName = [sourceURL lastPathComponent];
        downloadFileItem.downloadItemStatus = DownloadItemStatusPending;
        
        if (_currentActiveDownloadTasks >= _currentDownloadMaximum) {
            
            _pendingDownloadTasks += 1;
        } else {
            
            _currentActiveDownloadTasks += 1;
            [downloadFileItem.downloadTask resume];
        }
        
        [_downloadFileItems addObject:downloadFileItem];
        
        // callback to update UI
        if (downloadFileItem.infoFileDownloadBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
            });
        }
    }
}

#pragma mark - cancelDownloadForUrl

- (void)cancelDownloadForUrl:(NSString *)fileIdentifier {
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
    DownloadFileItem* downloadFileItem = [_downloadFileItems filteredArrayUsingPredicate:predicate][0];
    
    if (downloadFileItem) {
        
        // cancel activeList
        if (downloadFileItem.downloadItemStatus == DownloadItemStatusPaused) {
            
            _resumeDownloadTasks -= 1;
        } else  if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
            
            _pendingDownloadTasks -= 1;
        } else if (downloadFileItem.downloadItemStatus == DownloadItemStatusStarted) {
            
            _currentActiveDownloadTasks -= 1;
        }
        
        downloadFileItem.downloadItemStatus = DownloadItemStatusCancelled;
        [downloadFileItem.downloadTask cancel];
        
        // callback to update UI
        if (downloadFileItem.infoFileDownloadBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
                [_downloadFileItems removeObject:downloadFileItem];
            });
        }
        
        if (_pendingDownloadTasks > 0 && _currentActiveDownloadTasks < _currentDownloadMaximum) {
            
            __block DownloadFileItem* nextDownloadFileItem;
            
            [_downloadFileItems enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL* stop) {
                
                DownloadFileItem* downloadFileItem = object;
                
                if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
                    
                    nextDownloadFileItem = downloadFileItem;
                    return;
                }
            }];
            
            [nextDownloadFileItem.downloadTask resume];
            _currentActiveDownloadTasks += 1;
            _pendingDownloadTasks -= 1;
        }
    }
}

#pragma mark - stopDownLoadForUrl...

- (void)pauseDownLoadForUrl:(NSString *)fileIdentifier {
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
    DownloadFileItem* downloadFileItem = [_downloadFileItems filteredArrayUsingPredicate:predicate][0];
    
    if (downloadFileItem) {
        
        if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
            
            _pendingDownloadTasks -= 1;
        } else if (downloadFileItem.downloadItemStatus == DownloadItemStatusStarted) {
            
            _currentActiveDownloadTasks -= 1;
            [downloadFileItem.downloadTask suspend];
        }
        // pause currentTask running
        downloadFileItem.downloadItemStatus = DownloadItemStatusPaused;
        _resumeDownloadTasks += 1;
        
        // callback to update UI
        if (downloadFileItem.infoFileDownloadBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                
                downloadFileItem.infoFileDownloadBlock(downloadFileItem);
            });
        }
        
        if (_pendingDownloadTasks > 0 && _currentActiveDownloadTasks < _currentDownloadMaximum) {
            
            __block DownloadFileItem* nextDownloadFileItem;
            
            [_downloadFileItems enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL* stop) {
                
                DownloadFileItem* downloadFileItem = object;
                
                if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
                    
                    _pendingDownloadTasks -= 1;
                    nextDownloadFileItem = downloadFileItem;
                    return;
                }
            }];
            
            _currentActiveDownloadTasks += 1;
            [nextDownloadFileItem.downloadTask resume];
        }
    }
}

#pragma mark - resumeDownLoadForUrl...

- (void)resumeDownLoadForUrl:(NSString *)fileIdentifier {
    
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"identifier contains[cd] %@", fileIdentifier];
    DownloadFileItem* downloadFileItem = [_downloadFileItems filteredArrayUsingPredicate:predicate][0];

    if (downloadFileItem && _resumeDownloadTasks > 0) {
        
        // stop task when currentTaskDownload more max
        if (_currentActiveDownloadTasks >= _currentDownloadMaximum) {
            
            __block DownloadFileItem* pauseDownloadFileItem;
            
            [_downloadFileItems enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL* stop) {
                
                DownloadFileItem* downloadFileItem1 = object;
                
                if (downloadFileItem1.downloadItemStatus == DownloadItemStatusStarted) {
                    
                    _currentActiveDownloadTasks -= 1;
                    pauseDownloadFileItem = downloadFileItem1;
                    return;
                }
            }];
            
            pauseDownloadFileItem.downloadItemStatus = DownloadItemStatusPaused;
            [pauseDownloadFileItem.downloadTask suspend];
            _resumeDownloadTasks += 1;
            // callback to update UI
            if (pauseDownloadFileItem.infoFileDownloadBlock) {
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    
                    pauseDownloadFileItem.infoFileDownloadBlock(pauseDownloadFileItem);
                });
            }
        }
        
        // resume task
        downloadFileItem.downloadItemStatus = DownloadItemStatusStarted;
        [downloadFileItem.downloadTask resume];
        _currentActiveDownloadTasks += 1;
        _resumeDownloadTasks -= 1;
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

#pragma mark - fileDownloadCompletedForUrl...

- (BOOL)fileDownloadCompletedForUrl:(NSString *)sourceURL {
    
    __block BOOL retValue = NO;
    
    [_downloadFileItems enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL* stop) {
        
        DownloadFileItem* downloadFileItem = object;
        
        if ([downloadFileItem.sourceURL isEqualToString:sourceURL]) {
            
            retValue = YES;
            return;
        }
    }];
    
    return retValue;
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
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[[cachesDirectory stringByAppendingPathComponent:directoryName] stringByAppendingPathComponent:fileName]]) {
        
        exists = YES;
    }
    
    return exists;
}

#pragma mark - Background download

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    
    // Check if all download tasks have been finished.
    [session getTasksWithCompletionHandler:^(NSArray* dataTasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        
        if ([downloadTasks count] == 0) {
            
            if (_backgroundTransferCompletionHandler != nil) {
                
                // Copy locally the completion handler.
                void(^completionHandler)() = _backgroundTransferCompletionHandler;
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    
                    // Call the completion handler to tell the system that there are no other background transfers.
                    completionHandler();
                }];
                
                // Make nil the backgroundTransferCompletionHandler.
                _backgroundTransferCompletionHandler = nil;
            }
        }
    }];
}

@end
