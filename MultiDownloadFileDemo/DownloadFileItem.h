//
//  DownloadFileItem.h
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DownloadFileStatus.h"

@interface DownloadFileItem : NSObject

typedef void(^InfoFileDownloadBlock)(DownloadFileItem* downloadFileItem);

#pragma mark - InfoFileDownloadBlock
@property (nonatomic, copy) InfoFileDownloadBlock infoFileDownloadBlock;

#pragma mark - downloadTask
@property (nonatomic) NSURLSessionDownloadTask* downloadTask;

#pragma mark - directoryName
@property (nonatomic, copy) NSString* directoryName;

#pragma mark - identifier
@property (nonatomic, copy) NSString* identifier;

#pragma mark - sourceURL
@property (nonatomic, copy) NSString* sourceURL;

#pragma mark - fileName
@property (nonatomic, copy) NSString* fileName;

#pragma mark - startDate
@property (nonatomic, copy) NSDate* startDate;

#pragma mark - byteRecives
@property (nonatomic, assign) int64_t byteRecives;

#pragma mark - totalbyteRecives
@property (nonatomic, assign) int64_t totalbyteRecives;

#pragma mark - totalBytes
@property (nonatomic, assign) int64_t totalBytes;

#pragma mark - isDownloading
@property (nonatomic) DownloaderItemStatus downloadItemStatus;

#pragma mark - initWithDownloaderTask
- (instancetype)initWithActiveDownloadTask:(NSURLSessionDownloadTask *)downloadTask info:(InfoFileDownloadBlock)infoFileDownloadBlock callbackQueue:(dispatch_queue_t)queue;

@end

