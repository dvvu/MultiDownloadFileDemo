//
//  DownloadFileTableViewCell.h
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#import "MultiDownlodFileCellActionDelegate.h"
#import "DownloadFileStatus.h"
#import "DownloadFileStatus.h"
#import "NICellCatalog.h"
#import <UIKit/UIKit.h>

@interface DownloadFileTableViewCell : UITableViewCell <NICell>

@property (nonatomic) id<DownloadFileTableCellObjectProtocol> model;
@property (nonatomic) id<MultiDownlodFileCellActionDelegate> delegate;
@property (nonatomic) UIProgressView* progressView;
@property (nonatomic) UIButton* downloadButton;
@property (nonatomic) UILabel* taskStatusLabel;
@property (nonatomic) UILabel* taskDetailLabel;
@property (nonatomic) UIButton* cancelButton;
@property (nonatomic) UILabel* taskNameLabel;
@property (nonatomic) UILabel* taskLinkLabel;
@property (nonatomic) NSString* identifier;
@property (nonatomic) NSString* sourceURL;

@end
