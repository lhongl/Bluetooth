//
//  ViewController.m
//  BlueToothCenter
//
//  Created by caizheyong on 16/1/20.
//  Copyright © 2016年 xiaocaicai111. All rights reserved.
//

#import "ViewController.h"
#import <CoreBluetooth/CoreBluetooth.h>
#define kServiceUUID @"C4FB2349-72FE-4CA2-94D6-1F3CB16331EE" //服务的UUID
#define kCharacteristicUUID @"6A3E4B28-522D-4B3B-82A9-D5E2004534FC" //特征的UUID
@interface ViewController ()<CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong, nonatomic) IBOutlet UITextView *contentText;

@property (nonatomic, strong)CBCentralManager *centerManager; //声明属性存储中心设备
@property (nonatomic, strong)NSMutableArray *peripherals; //声明属性存储查找到的外围设备
@end

@implementation ViewController
- (NSMutableArray *)peripherals {
    if (_peripherals == nil) {
        self.peripherals = [NSMutableArray arrayWithCapacity:0];
    }
    return _peripherals;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
- (IBAction)startSearchAction:(id)sender {
    //创建中心设备并且设置代理
    self.centerManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
}
#pragma mark CBCenterManagerDelegate
//当中心设备管理器状态发生改变的时候调用
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
            [self writeToLog:@"BLE打开成功"];
            //开始扫描外围设备(设置中心设备允许搜索所有的外部设备，并且可以搜索多个键)
            [central scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
            break;
            
        default:
            [self writeToLog:@"BLE打开失败"];
            break;
    }
}
//发现外围设备之后执行的操作
/**
 *
 *  @param central           中心设备
 *  @param peripheral        外围设备
 *  @param advertisementData 特征数据
 *  @param RSSI              信号质量（信号强度）
 */
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    [self writeToLog:@"发现外围设备"];
    //停止扫描
    [self.centerManager stopScan];
    //链接外围设备
    if (peripheral) {
        //添加外部设备，注意如果这里不保存外围设备（或者说peripheral没有一个强引用)无法执行到连接成功（或失败）的代理方法，因为在此方法调用完就会被销毁
        if (![self.peripherals containsObject:peripheral]) {
            [self.peripherals addObject:peripheral];
        }
        //开始链接外围设备
        [self.centerManager connectPeripheral:peripheral options:nil];
    }
}
//链接外围设备成功之后执行
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self writeToLog:@"外围设备链接成功"];
    //设置外围设备的代理为当前视图控制器，并开始搜索服务
    peripheral.delegate = self;
    //开始搜索服务
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kServiceUUID]]];
}
//链接外围设备失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"外围设备链接失败");
}
//当搜索到服务的时候执行
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    //遍历查找到的服务
    [self writeToLog:@"发现外围服务"];
    CBUUID *serverUDID = [CBUUID UUIDWithString:kServiceUUID];
    CBUUID *charaterUDID = [CBUUID UUIDWithString:kCharacteristicUUID];
    for (CBService *server in peripheral.services) {
        if ([server.UUID isEqual:serverUDID]) {
            //查找制定的服务的特征
            [peripheral discoverCharacteristics:@[charaterUDID] forService:server];
        }
    }
}
//当查找到指定的特征之后执行
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    [self writeToLog:@"查找到对应的特征"];
    //设置服务特征值的UUID
    CBUUID *serverUUID = [CBUUID UUIDWithString:kServiceUUID];
    if ([service.UUID isEqual:serverUUID]) {
        //遍历该服务中的特征
        for (CBCharacteristic *character in service.characteristics) {
            if ([character.UUID isEqual:[CBUUID UUIDWithString:kCharacteristicUUID]]) {
                //此时的特征既是我们要查找的特征
                //情景1：设置外围设备为已通知状态（订阅特征）
                [peripheral setNotifyValue:YES forCharacteristic:character];
                //情景2:读取特征中的特征值，用来进行操作
//                [peripheral readValueForCharacteristic:character];
//                if (character.value) {
//                    NSLog(@"读取到特征值");
//                }
            }
        }
    }
}
//情景1执行的操作(当特征值被更新后执行的操作)
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [self writeToLog:@"执行监听"];
    //判断当前的特征是否是我们要查找的特征
    CBUUID *charaterUUID = [CBUUID UUIDWithString:kCharacteristicUUID];
    if ([characteristic.UUID isEqual:charaterUUID]) {
        //判断当前是否正在订阅
        if (characteristic.isNotifying) {
           //判断当前特征处于何种状态
            if (characteristic.properties == CBCharacteristicPropertyNotify) {
                NSLog(@"已经订阅特征通知");
                [peripheral readValueForCharacteristic:characteristic];
            }else if(characteristic.properties == CBCharacteristicPropertyRead) {
                //读取相应的特征值
                [peripheral readValueForCharacteristic:characteristic];
            }
        }else {
            [self writeToLog:@"订阅已停止"];
        }
    }
}
//更新特征值后（调用readValueForCharacteristic:方法或者外围设备在订阅后更新特征值都会调用此代理方法）
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSLog(@"更新特征值");
    if (characteristic.value) {
        NSLog(@"%@", [[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding]);
        [self writeToLog:[[NSString alloc]initWithData:characteristic.value encoding:NSUTF8StringEncoding]];
    }else {
        NSLog(@"未发现特征值");
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
