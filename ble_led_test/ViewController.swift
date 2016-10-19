//
//  ViewController.swift
//  ble_led_test
//
//  Created by 三木隆裕 on 2016/10/13.
//  Copyright © 2016年 tmtakahiro. All rights reserved.
//

import UIKit
import CoreBluetooth
import Foundation

class ViewController: UIViewController,CBCentralManagerDelegate,CBPeripheralDelegate
{
        
    var centralManager:CBCentralManager!
    var BLEPeripheral:CBPeripheral!
    
    @IBOutlet weak var device: UILabel!
    
    private let uartManager = UartManager.sharedInstance

    static private let prefixes = ["!Q", "!A", "!G", "!M", "!L","!S"];     // same order that ControllerType
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //CBCentralManagerを初期化
        //centralManagerDidUpdateStateで状態変化が取得できます
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
    }
    
    //===========================================================================
    // MARK: -- BLE --
    //===========================================================================
    //セントラルマネージャーの状態変化を取得
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    {
        switch (central.state) {
            
        case .poweredOff:
            print("Bluetoothの電源がOff")
        case .poweredOn:
            print("Bluetoothの電源はOn")
            
            //ペリフェラルのスキャン開始
            centralManager.scanForPeripherals(withServices: nil, options:nil)
            
        case .resetting:
            print("レスティング状態")
        case .unauthorized:
            print("非認証状態")
        case .unknown:
            print("不明")
        case .unsupported:
            print("非対応")
        }
    }
    
    //スキャン結果を受け取る
    //スキャン結果を受け取る
    func centralManager(_ central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber)
    {
        if(peripheral.name == "Adafruit Bluefruit LE"){
            print("\(peripheral.name)に接続")
            BLEPeripheral = peripheral
            
            //BLE Nanoのスキャンに成功したら接続
            centralManager.connect(BLEPeripheral, options: nil)
            centralManager.stopScan()
        }
    }
    
    //ペリフェラルに接続完了
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    {
        BLEPeripheral.delegate = self
        //接続できたらサービスを探索
        BLEPeripheral.discoverServices(nil)
    }
    
    //ペリフェラルに接続失敗
    func centralManager(_ central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?)
    {
        print("接続失敗")
    }
    
    //サービスの探索結果を受け取る
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: NSError?)
    {
        if(error != nil){
            print("エラー：\(error)")
            return
        }
        
        if !((peripheral.services?.count)! > 0){
            print("サービスがありません")
        }
        
        let services = peripheral.services!
        print("\(services) サービスが見つかりました")
        
        //サービスが見つかったら、キャラクタリスティックを探索
        peripheral.discoverCharacteristics(nil, for: services[0])
    }
    
    //キャラクリスティックの探索結果を受け取る
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?)
    {
        if(error != nil){
            print("エラー：\(error)")
            return
        }
        
        if !((service.characteristics?.count)! > 0){
            print("キャラクタリスティックがありません")
            return
        }
        
        let characteristics = service.characteristics!
        _ = characteristics[0]
        print("\(characteristics) キャラクタリスティックが見つかりました")
        
        //キャラクタリスティックに値の書き込む
        setdata()
        /*
        let value = "T"
        let data: NSData! = value.data(using: String.Encoding.utf8,allowLossyConversion:true) as NSData!
        BLEPeripheral.writeValue(data as Data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
 */
    }
        
    func setdata(){
        //et hoge = NSMutableData()
        //let prefixData = ViewController.prefixes[5].data(using: String.Encoding.utf8)!
        //hoge.append(prefixData)
        
        //まず決め打ちで値をNSDataに代入
        let bytes:[UInt8] = [0x21,0x53,0x31]
        let hoge = NSData(bytes: bytes, length: bytes.count)
        
       /* var floatValue = Float(1)
        hoge.append(&floatValue, length: MemoryLayout<Float>.size)*/
        
        //誤り検出のための符号を追加するためのメソッドへ
        uartManager.sendDataWithCrc(data: hoge)
    }
    
    
    
        
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

