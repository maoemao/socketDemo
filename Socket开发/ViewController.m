//
//  ViewController.m
//  Socket开发
//
//  Created by baina on 2018/3/2.
//  Copyright © 2018年 ACE. All rights reserved.
//

#import "ViewController.h"
#import "SocketManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self connectSocket];
}


- (void)connectSocket {
    
    //连接前先断开
    [SocketManager sharedInstance].socket.userData = SocketOfflineByUser;
    [[SocketManager sharedInstance] cutOffSocket];
    //开始连接
    [[SocketManager sharedInstance] socketConnectHost:@"127.0.0.1" port:1234];
    [SocketManager sharedInstance].socket.userData = SocketOfflineByServer;
}

@end
