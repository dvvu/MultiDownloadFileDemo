//
//  MultiDownloadFileManager.h
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>
#import "DownloadFileItem.h"

@interface MultiDownloadFileManager : NSObject

+ (instancetype)sharedDefaultManager;
+ (instancetype)sharedBackgroundManager;


@property (nonatomic) void(^backgroundTransferCompletionHandler)();

- (void)startDownloadFileFromURL:(NSString *)sourceURL infoFileDownloadBlock:(InfoFileDownloadBlock)infoFileDownloadBlock callbackQueue:(dispatch_queue_t)queue;

#pragma mark - cancelDownloadForUrl
- (void)cancelDownloadForUrl:(NSString *)fileIdentifier;

#pragma mark - stopDownLoadForUrl...
- (void)pauseDownLoadForUrl:(NSString *)fileIdentifier;

#pragma mark - resumeDownLoadForUrl...
- (void)resumeDownLoadForUrl:(NSString *)fileIdentifier;

#pragma mark - currentDownloadMaximum
@property (nonatomic) int currentDownloadMaximum;

@end
