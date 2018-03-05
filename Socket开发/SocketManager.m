//
//  SocketManager.m
//  Socket开发
//
//  Created by baina on 2018/3/2.
//  Copyright © 2018年 ACE. All rights reserved.
//

#import "SocketManager.h"
@interface SocketManager ()<GCDAsyncSocketDelegate>


@property (nonatomic, copy) NSString *socketHost;
@property (nonatomic, assign) UInt16 socketPort;
@property (nonatomic, weak) NSTimer *connectTimer;
@property (nonatomic, assign) NSInteger dataTag;
@property (nonatomic, assign) NSInteger reconnectCount;
@property (nonatomic, weak) NSTimer *reconnectTimer;
@property (nonatomic, strong) NSDictionary *currentPacketHead;
@end

@implementation SocketManager

+ (instancetype)sharedInstance {
    static SocketManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SocketManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if(self = [super init]) {
        self.reconnectCount = 0;
    }
    return self;
}

- (void)socketConnectHost:(NSString *)host port:(int)port {
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.socketHost = host;
    self.socketPort = port;
    NSError *error = nil;
    [self.socket connectToHost:host onPort:port error:&error];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    self.socket.userData = SocketOfflineByServer;
    
    [self readData];
    // 每隔30s像服务器发送心跳包
    _connectTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(longConnectToSocket) userInfo:nil repeats:YES];// 在longConnectToSocket方法中进行长连接需要向服务器发送的讯息
    [_connectTimer fire];
    
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    NSLog(@"服务器断开连接 socket.userData = %@",sock.userData);
    if ([sock.userData isEqualToString:SocketOfflineByUser]) {
        return;
    }else if([sock.userData isEqualToString:SocketOfflineByServer]){
        [self reconnectSocket];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    //先读取到当前数据包头部信息
    if (!self.currentPacketHead) {
        self.currentPacketHead = [NSJSONSerialization
                             JSONObjectWithData:data
                             options:NSJSONReadingMutableContainers
                             error:nil];
        
        
        if (!self.currentPacketHead) {
            NSLog(@"error：当前数据包的头为空");
            //断开这个socket连接或者丢弃这个包的数据进行下一个包的读取
            //....
            return;
        }
        
        NSUInteger packetLength = [self.currentPacketHead[@"size"] integerValue];
        
        //读到数据包的大小
        [sock readDataToLength:packetLength withTimeout:-1 tag:110];
        
        return;
    }
    //正式的包处理
    NSUInteger packetLength = [self.currentPacketHead[@"size"] integerValue];
    //说明数据有问题
    if (packetLength <= 0 || data.length != packetLength) {
        NSLog(@"error：当前数据包数据大小不正确");
        return;
    }
    NSString *type = self.currentPacketHead[@"type"];
    if ([type isEqualToString:@"img"]) {
        NSLog(@"图片设置成功");
    }else{
        NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"收到消息:%@",msg);
    }
    self.currentPacketHead = nil;
    
    [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:110];
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    NSLog(@"socket 写入数据成功");
}

- (void)longConnectToSocket {
    // 根据服务器要求发送固定格式的数据，假设为指令@"."，但是一般不会是这么简单的指令
    NSString *longConnect = @".\n";
    NSData   *dataStream  = [longConnect dataUsingEncoding:NSUTF8StringEncoding];
    [self writeData:dataStream type:@"text"];
}

//断线重连 通知UI
- (void)reconnectSocket {
    [self.reconnectTimer invalidate];
    self.reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:6 target:self selector:@selector(reconnect) userInfo:nil repeats:true];
    
}

- (void)reconnect {
    if(self.reconnectCount == 5) {
        //连接失败。通知UI
        [[NSNotificationCenter defaultCenter] postNotificationName:@"lianjieshibai" object:nil];
        [self.reconnectTimer invalidate];
        self.reconnectTimer = nil;
        return;
    }
    self.reconnectCount ++;
    self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    [self.socket connectToHost:self.socketHost onPort:self.socketPort error:&error];
}

//断开连接
- (void)cutOffSocket {
    self.socket.userData = SocketOfflineByUser;
    self.socket.delegate = nil;
    [self.connectTimer invalidate];
    [self.socket disconnect];
    
}

- (void)readData {
    self.dataTag += 1;
    [self.socket readDataWithTimeout:-1 tag:self.dataTag];
}

- (void)writeData:(NSData *)data type:(NSString *)type{
    self.dataTag += 1;
    NSUInteger size = data.length;
    
    NSMutableDictionary *headDic = [NSMutableDictionary dictionary];
    [headDic setObject:type forKey:@"type"];
    [headDic setObject:[NSString stringWithFormat:@"%ld",size] forKey:@"size"];
    NSString *jsonStr = [self dictionaryToJson:headDic];
    NSData *lengthData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mData = [NSMutableData dataWithData:lengthData];
    //分界
    [mData appendData:[GCDAsyncSocket CRLFData]];
    [mData appendData:data];
    //第二个参数，请求超时时间
    [self.socket writeData:mData withTimeout:-1 tag:110];
}

- (NSString *)dictionaryToJson:(NSDictionary *)dic
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}
@end
