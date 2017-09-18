//
//  MultiDownloadFileViewController.m
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//


#import <SystemConfiguration/SystemConfiguration.h>
#import "MultiDownlodFileCellActionDelegate.h"
#import "MultiDownloadFileViewController.h"
#import "DownloadFileTableCellObject.h"
#import "ThreadSafeForMutableArray.h"
#import "DownloadFileTableViewCell.h"
#import "NIMutableTableViewModel.h"
#import "MultiDownloadFileManager.h"
#import "DownloadFileStatus.h"
#import "ViewController.h"
#import "Masonry.h"

@interface MultiDownloadFileViewController () <NITableViewModelDelegate, MultiDownlodFileCellActionDelegate, UITableViewDelegate>

@property (nonatomic) dispatch_queue_t multiDownloadItemsQueue;
@property (nonatomic) MultiDownloadFileManager* downloadTasks;
@property (nonatomic) NSMutableArray* validDownloadLinks;
@property (nonatomic) ConnectionType connectionType;
@property (nonatomic) int maxCurrentDownloadTasks;
@property (nonatomic) NSDictionary* cellObjects;
@property (nonatomic) NITableViewModel* model;
@property (nonatomic) UITableView* tableView;
@property (nonatomic) NSArray* downloadLinks;

@end

@implementation MultiDownloadFileViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    [self connection];
    
    _tableView = [[UITableView alloc]init];
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _multiDownloadItemsQueue = dispatch_queue_create("MULTIDOWNLOADITEMS_QUEUE", DISPATCH_QUEUE_SERIAL);
    [_tableView setBackgroundColor:[UIColor colorWithRed:48/255.f green:22/255.f blue:49/255.f alpha:1.0f]];
    [self.view addSubview:_tableView];
    
    [_tableView mas_makeConstraints:^(MASConstraintMaker* make) {
        
        make.edges.equalTo(self.view);
    }];
    
    [self setupData];
}

#pragma mark - setupData

- (void)setupData {
    
    dispatch_async(_multiDownloadItemsQueue, ^ {
        
        _downloadLinks = @[FILE_URL,FILE_URL1,FILE_URL2,FILE_URL3,FILE_URL4,FILE_URL5,FILE_URL7];
        _validDownloadLinks = [NSMutableArray array];
        _downloadTasks = [MultiDownloadFileManager sharedBackgroundManager];
        
        NSMutableArray* objects = [NSMutableArray array];
        NSMutableDictionary* objectsDict = [[NSMutableDictionary alloc] init];
        
        for (int i = 0; i < _downloadLinks.count; i++) {
            
            DownloadFileTableCellObject* cellObject = [[DownloadFileTableCellObject alloc] init];
            NSURL* url = [NSURL URLWithString:_downloadLinks[i]];
            cellObject.taskName = [url lastPathComponent];
            cellObject.sourceURL = _downloadLinks[i];
            cellObject.taskStatus = DownloadItemStatusNotStarted;
            cellObject.delegate = self;
            cellObject.identifier = @"";
            [objects addObject:cellObject];
            objectsDict[cellObject.sourceURL] = cellObject;
        }
        
        _model = [[NITableViewModel alloc] initWithListArray:objects delegate:self];
        _tableView.dataSource = _model;
        _cellObjects = objectsDict;
        
        dispatch_async(dispatch_get_main_queue(), ^ {
            
            [_tableView reloadData];
        });
    });
}

#pragma mark - NITableViewModelDelegate

- (UITableViewCell *)tableViewModel:(NITableViewModel *)tableViewModel cellForTableView:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath withObject:(id)object {
    
    return [NICellFactory tableViewModel:tableViewModel cellForTableView:tableView atIndexPath:indexPath withObject:object];
}

#pragma mark - tableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 140;
}

#pragma mark - tableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [UIView animateWithDuration:0.05 animations: ^ {
        
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }];
}


#pragma mark - connection

- (void)connection {
    
    _connectionType = [MultiDownloadFileViewController checkConnectionNetWork];
    
    switch (_connectionType) {
            
        case ConnectionTypeUnknown:
            
            break;
        case ConnectionType3G:
            
            _maxCurrentDownloadTasks = 1;
            break;
        case ConnectionTypeWiFi:
            
            _maxCurrentDownloadTasks = 2;
            break;
        case ConnectionTypeNone:
            
            _maxCurrentDownloadTasks = 0;
            [ViewController showConnectInternetAlert:self withTitle:@"DISCONNECTED" andMessage:@"Please check The internet and try again!"];
            break;
        default:
            break;
    }
}

#pragma mark - cancelDownloadWithItemID

- (void)startDownloadFromURL:(NSString *)sourceURL {

    NSLog(@"link: %@", sourceURL);
    
    [_downloadTasks startDownloadFileFromURL:sourceURL infoFileDownloadBlock:^(DownloadFileItem* downloadFileItem) {
        
        [self updateCell: downloadFileItem];
    } callbackQueue:nil];
}

#pragma mark - cancelDownloadWithItemID

- (void)pauseDownloadWithItemID:(NSString *)identifier {
    
    NSLog(@"pause");
    [_downloadTasks pauseDownLoadForUrl:identifier];
}

#pragma mark - cancelDownloadWithItemID

- (void)resumeDownloadWithItemID:(NSString *)identifier {
    
    NSLog(@"resume");
    [_downloadTasks resumeDownLoadForUrl:identifier];
}

#pragma mark - cancelDownloadWithItemID

- (void)cancelDownloadWithItemID:(NSString *)identifier {
    
    NSLog(@"cancel");
    [_downloadTasks cancelDownloadForUrl:identifier];
}

#pragma mark - updateCell

- (void)updateCell:(DownloadFileItem *)downloadFileItem {
    
    DownloadFileTableCellObject* cellObject = _cellObjects[downloadFileItem.sourceURL];
    NSIndexPath* indexPath = [_model indexPathForObject:cellObject];
    DownloadFileTableViewCell* cell = [_tableView cellForRowAtIndexPath:indexPath];
    cellObject.identifier = downloadFileItem.identifier;
    
    if (downloadFileItem.downloadItemStatus == DownloadItemStatusCompleted) {
        
        cellObject.taskStatus = DownloadItemStatusCompleted;
        dispatch_async(dispatch_get_main_queue(), ^ {
            
            [cell setModel:cellObject];
        });
    } else if (downloadFileItem.downloadItemStatus == DownloadItemStatusPaused) {
        
        cellObject.taskStatus = DownloadItemStatusPaused;
        dispatch_async(dispatch_get_main_queue(), ^ {
            
            [cell setModel:cellObject];
        });
    } else if (downloadFileItem.downloadItemStatus == DownloadItemStatusCancelled) {
        
        cellObject.process = 0.0;
        cellObject.taskStatus = DownloadItemStatusCancelled;
        cellObject.taskDetail = @"";
        [cell setModel:cellObject];
    } else if (downloadFileItem.downloadItemStatus == DownloadItemStatusPending) {
        
        cellObject.taskStatus = DownloadItemStatusPending;
        dispatch_async(dispatch_get_main_queue(), ^ {
            
            [cell setModel:cellObject];
        });
    } else {
        
        CGFloat progress = (CGFloat)downloadFileItem.totalbyteRecives / (CGFloat)downloadFileItem.totalBytes;
        CGFloat second = [self remainingTimeForDownload:downloadFileItem.startDate bytesTransferred:downloadFileItem.totalbyteRecives  totalBytesExpectedToWrite:downloadFileItem.totalBytes];
        
        NSString* formatByteWritten = [NSByteCountFormatter stringFromByteCount:downloadFileItem.totalbyteRecives countStyle:NSByteCountFormatterCountStyleFile];
        NSString* formatBytesExpected = [NSByteCountFormatter stringFromByteCount:downloadFileItem.totalBytes countStyle:NSByteCountFormatterCountStyleFile];
        NSString* detailInfo = [NSString stringWithFormat:@"%.0f%% - %@ / %@ - About: %@", progress * 100, formatByteWritten, formatBytesExpected, [self timeFormatted:second]];
        
        cellObject.process = progress;
        cellObject.taskStatus = DownloadItemStatusStarted;
        cellObject.taskDetail = detailInfo;
        dispatch_async(dispatch_get_main_queue(), ^ {
            
            [cell setModel:cellObject];
        });
    }
}

#pragma mark - checkConnectionNetWork

+ (ConnectionType)checkConnectionNetWork {
    
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "8.8.8.8");
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    
    if (!success) {
        
        return ConnectionTypeUnknown;
    }
    
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);
    
    if (!isNetworkReachable) {
        
        return ConnectionTypeNone;
    } else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        
        return ConnectionType3G;
    } else {
        
        return ConnectionTypeWiFi;
    }
}

#pragma mark - remainingTimeForDownload

- (CGFloat)remainingTimeForDownload:(NSDate *)startDate bytesTransferred:(int64_t)bytesTransferred totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:startDate];
    CGFloat speed = (CGFloat)bytesTransferred / (CGFloat)timeInterval;
    CGFloat remainingBytes = totalBytesExpectedToWrite - bytesTransferred;
    CGFloat remainingTime = remainingBytes / speed;
    
    return remainingTime;
}

#pragma mark - timeFormatted

- (NSString *)timeFormatted:(int)totalSeconds {
    
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    if (hours) {
        
        return [NSString stringWithFormat:@"%02dh:%02dm:%02ds",hours, minutes, seconds];
    } else if (minutes) {
        
        return [NSString stringWithFormat:@"%02dm:%02ds", minutes, seconds];
    } else {
        
        return [NSString stringWithFormat:@"%02ds", seconds];
    }
}

@end
