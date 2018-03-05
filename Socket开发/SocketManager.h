//
//  SocketManager.h
//  Socket开发
//
//  Created by baina on 2018/3/2.
//  Copyright © 2018年 ACE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

#define SocketOfflineByUser @"SocketOfflineByUser"
#define SocketOfflineByServer @"SocketOfflineByServer"

@interface SocketManager : NSObject

@property (nonatomic, strong) GCDAsyncSocket *socket;

+ (instancetype)sharedInstance;

- (void)socketConnectHost:(NSString *)host port:(int)port;

- (void)cutOffSocket;

- (void)readData;

- (void)writeData:(NSData *)data type:(NSString *)type;
@end
