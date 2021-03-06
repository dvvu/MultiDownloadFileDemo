//
//  DownloadFileItem.m
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#import "DownloadFileItem.h"

@interface DownloadFileItem ()

@property (nonatomic)dispatch_queue_t callbackQueue;

@end

@implementation DownloadFileItem

#pragma mark - initWithDownloaderTask

- (instancetype)initWithActiveDownloadTask:(NSURLSessionDownloadTask *)downloadTask info:(InfoFileDownloadBlock)infoFileDownloadBlock callbackQueue:(dispatch_queue_t)queue{
    
    self = [super init];
    
    if (self) {
        
        _infoFileDownloadBlock = infoFileDownloadBlock;
        _downloadTask = downloadTask;
        _callbackQueue = queue;
        _identifier = [NSString stringWithFormat:@"%lud",(unsigned long)downloadTask.taskIdentifier];
    }
    
    return self;
}

@end
