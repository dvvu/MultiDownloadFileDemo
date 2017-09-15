//
//  MultiDownlodFileCellActionDelegate.h
//  MultiDownloadFileDemo
//
//  Created by Doan Van Vu on 9/14/17.
//  Copyright © 2017 Doan Van Vu. All rights reserved.
//

#ifndef MultiDownlodFileCellActionDelegate_h
#define MultiDownlodFileCellActionDelegate_h


#endif /* MultiDownlodFileCellActionDelegate_h */


#import <Foundation/Foundation.h>

@protocol MultiDownlodFileCellActionDelegate <NSObject>

#pragma mark - cancelDownloadWithItemID
- (void)startDownloadFromURL:(NSString *)sourceURL;

#pragma mark - cancelDownloadWithItemID
- (void)pauseDownloadWithItemID:(NSString *)identifier;

#pragma mark - cancelDownloadWithItemID
- (void)resumeDownloadWithItemID:(NSString *)identifier;

#pragma mark - cancelDownloadWithItemID
- (void)cancelDownloadWithItemID:(NSString *)identifier;

@end
