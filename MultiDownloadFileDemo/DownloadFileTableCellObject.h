//
//  DownloadFileTableCellObject.h
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#import "MultiDownlodFileCellActionDelegate.h"
#import <Foundation/Foundation.h>
#import "DownloadFileStatus.h"
#import "NICellCatalog.h"
#import <UIKit/UIKit.h>

@protocol DownloadFileTableCellObjectProtocol <NSObject>

@property (nonatomic) id<MultiDownlodFileCellActionDelegate> delegate;
@property (readonly, nonatomic, copy) NSString* identifier;
@property (readonly, nonatomic, copy) NSString* taskDetail;
@property (readonly, nonatomic, copy) NSString* taskName;
@property (readonly, nonatomic, copy) NSString* sourceURL;
@property (nonatomic) DownloaderItemStatus taskStatus;
@property (readonly, nonatomic) CGFloat process;

@end

@interface DownloadFileTableCellObject : NITitleCellObject <DownloadFileTableCellObjectProtocol>

@property (nonatomic) id<MultiDownlodFileCellActionDelegate> delegate;
@property (nonatomic) DownloaderItemStatus taskStatus;
@property (nonatomic, copy) NSString* identifier;
@property (nonatomic, copy) NSString* taskDetail;
@property (nonatomic, copy) NSString* taskName;
@property (nonatomic, copy) NSString* sourceURL;
@property (nonatomic) CGFloat process;

@end
