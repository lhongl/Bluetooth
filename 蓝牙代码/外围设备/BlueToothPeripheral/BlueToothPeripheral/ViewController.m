//
//  ViewController.m
//  BlueToothPeripheral
//
//  Created by caizheyong on 16/1/20.
//  Copyright © 2016年 xiaocaicai111. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#define DeviceName @"CZYIphone"
#define kServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE" //服务的UUID
#define kCharacteristicUUID @"6A3E4B28-522D-4B3B-82A9-D5E2004534FC" //特征的UUID
@interface ViewController ()<CBPeripheralManagerDelegate>
@property (nonatomic, strong)CBPeripheralManager *pm; //存储外围设备

@property (nonatomic, strong)NSMutableArray *charaters; //声明数组用来存储中心设备订阅的特征
//@property (nonatomic, strong)CBMutableCharacteristic *charater; //存储特征
@property (nonatomic, strong)NSMutableArray *centerA; //存储发现的中心设备

@property (strong, nonatomic) IBOutlet UITextView *contentText;

@end

@implementation ViewController
- (NSMutableArray *)centerA {
    if (_centerA == nil) {
        self.centerA = [NSMutableArray arrayWithCapacity:0];
    }
    return _centerA;
}
- (NSMutableArray *)charaters {
    if (_charaters == nil) {
        self.charaters = [NSMutableArray arrayWithCapacity:0];
    }
    return _charaters;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)startSend:(id)sender {
    //1:创建外围设备并指定代理人
    self.pm = [[CBPeripheralManager alloc]initWithDelegate:self queue:nil];
}
- (IBAction)updateAction:(id)sender {
    //执行特征值更新（注意特征值未来即指的是我们想要传输的数据，因此在传输数据的时候，需要将数据设置成特征值来传输）
    [self startUpdataDate];
}

#pragma mark CBPeripheralManagerDelegate
//当外围设备状态发生变化后调用
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            [self writeToLog:@"BLE打开成功，准备添加服务"];
            //添加服务
            [self setUpServer];
            break;
        default:
            [self writeToLog:@"BLE打开失败"];
            break;
    }
}
//创建特征和服务并开始添加服务到外围设备
- (void)setUpServer {
   //1:创建特征
    CBUUID *uuid = [CBUUID UUIDWithString:kCharacteristicUUID]; //创建特征的UUID对象
    
    //设置特征的特征值
//    NSString *charaName = DeviceName;
//    NSData *data = [charaName dataUsingEncoding:NSUTF8StringEncoding];
    
    /** 参数
     * uuid:特征标识
     * properties:特征的属性，例如：可通知、可写、可读等
     * value:特征值
     * permissions:特征的权限
     * 注意如果特征值不为空时特征的属性只能是只读属性
     */
    CBMutableCharacteristic *characteristic = [[CBMutableCharacteristic alloc]initWithType:uuid properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable]; //创建特征
    //存储该特征
    [self.charaters addObject:characteristic];
    
    //2:创建服务并且添加对应的特征
    //创建服务的UUID
    CBUUID *serverUUID = [CBUUID UUIDWithString:kServiceUUID];
    //创建服务对象
    CBMutableService *server = [[CBMutableService alloc]initWithType:serverUUID primary:YES];
    //设置服务特征(可哟添加多个特征)
    [server setCharacteristics:@[characteristic]];
    
    //将服务添加到外围设备
    [self.pm addService:server];
}
//添加外围设备的服务后会执行下面的代理方法
//当外围设备添加服务之后调用
- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    if (error) {
        UIAlertController *alterAC = [UIAlertController alertControllerWithTitle:@"提示" message:@"服务添加失败" preferredStyle:UIAlertControllerStyleAlert];
        //添加取消按钮
        UIAlertAction *alterC = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alterAC addAction:alterC];
        //添加重置按钮
        __block ViewController *vc = self;
        UIAlertAction *alterR = [UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [vc setUpServer];
        }];
        [alterAC addAction:alterR];
        //显示提示按钮
        [self presentViewController:alterAC animated:YES completion:nil];
        return;
    }
    
    //服务添加成功之后开始进行广播
    [self.pm startAdvertising:@{CBAdvertisementDataLocalNameKey : DeviceName}];
    [self writeToLog:@"服务添加成功"];
}
//当外部设备开始广播之后调用
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    [self writeToLog:@"开始广播"];
}
//中心设备订阅特征的时候调用
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    //存储发现的中心设备
    if (![self.centerA containsObject:central]) {
        [self.centerA addObject:central];
    }
    [self writeToLog:@"订阅成功"];
}
//中心设备取消订阅特征的时候调用
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    [self writeToLog:@"订阅失败"];
}
#pragma mark update data
//该过程执行数据传输
- (void)startUpdataDate {
    NSString *str = [NSString stringWithFormat:@"%@", [NSDate new]];
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    //开始更新数据
    BOOL result = [self.pm updateValue:data forCharacteristic:self.charaters.firstObject onSubscribedCentrals:nil];
    if (result == NO) {
        [self writeToLog:@"特征值更新失败"];
    }else {
        [self writeToLog:@"特征值更新成功"];
    }

}
#pragma mark - 私有方法
/**
 *  记录日志
 *
 *  @param info 日志信息
 */
-(void)writeToLog:(NSString *)info{
    self.contentText.text=[NSString stringWithFormat:@"%@\r\n%@",self.contentText.text,info];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
