//
//  UartManager.swift
//  ble_led_test
//
//  Created by 三木隆裕 on 2016/10/17.
//  Copyright © 2016年 tmtakahiro. All rights reserved.
//

import Foundation
import CoreBluetooth

class UartManager: NSObject {
    
    enum UartNotifications : String {
        case DidSendData = "didSendData"
        case DidReceiveData = "didReceiveData"
        case DidBecomeReady = "didBecomeReady"
    }
    
    // Manager
    static let sharedInstance = UartManager()
    
    //Constants
    //private
    static let UartServiceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"       // UART service UUID
    static let RxCharacteristicUUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    //private
    static let TxCharacteristicUUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    //private
    static let TxMaxCharacters = 20
    
    // Bluetooth Uart
     var uartService: CBService?
     var rxCharacteristic: CBCharacteristic?
     var txCharacteristic: CBCharacteristic?
     var txWriteType = CBCharacteristicWriteType.withResponse
    
    var blePeripheral: BlePeripheral? {
        didSet {
            if blePeripheral?.peripheral.identifier != oldValue?.peripheral.identifier {
                // Discover UART
                resetService()
                if let blePeripheral = blePeripheral {
                    DLog(message: "Uart: discover services")
                    blePeripheral.peripheral.discoverServices([CBUUID(string: UartManager.UartServiceUUID)])
                }
            }
        }
    }
    
    //Data
    var dataBuffer = [UartDataChunk]()
    var dataBufferEnabled = Config.uartShowAllUartCommunication
    
     func resetService() {
        uartService = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }
    
     func receivedData(data: NSData) {
        
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .RX, data: data)
        receivedChunk(dataChunk: dataChunk)
    }
    
     func receivedChunk(dataChunk: UartDataChunk) {
        if Config.uartLogReceive {
            DLog(message: "received: \(hexString(data: dataChunk.data))")
        }
        
        if dataBufferEnabled {
            blePeripheral?.uartData.receivedBytes += dataChunk.data.length
            dataBuffer.append(dataChunk)
        }
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: UartNotifications.DidReceiveData.rawValue), object: nil, userInfo:["dataChunk" : dataChunk]);
    }
    
    //誤り符号検出のためのメソッド
    func sendDataWithCrc(data : NSData) {
        
        let len = data.length
        var dataBytes = [UInt8](repeating: 0, count: len)   //0をdataの長さ分dataBytesに挿入(dataBytesの初期化)
        var crc: UInt8 = 0
        data.getBytes(&dataBytes, length: len)   //dataの中身をdataBytesにコピーする．
        
        for i in dataBytes {    //add all bytes
            crc = crc &+ i
        }
        crc = ~crc  //invert
        
        let dataWithChecksum = NSMutableData(data: data as Data)
        dataWithChecksum.append(&crc, length: 1)
        
        sendData(data: dataWithChecksum)
    }
    
    func sendData(data: NSData) {
        let dataChunk = UartDataChunk(timestamp: CFAbsoluteTimeGetCurrent(), mode: .TX, data: data)
        sendChunk(dataChunk: dataChunk)
    }
    
    func sendChunk(dataChunk: UartDataChunk) {
        
        if let txCharacteristic = txCharacteristic, let blePeripheral = blePeripheral {
            
            let data = dataChunk.data
            
            if dataBufferEnabled {
                blePeripheral.uartData.sentBytes += data.length
                dataBuffer.append(dataChunk)
            }
            
            // Split data  in txmaxcharacters bytes packets
            var offset = 0
            repeat {
                let chunkSize = min(data.length-offset, UartManager.TxMaxCharacters)
                let chunk = NSData(bytesNoCopy: UnsafeMutableRawPointer(mutating: data.bytes)+offset, length: chunkSize, freeWhenDone:false)
                
                if Config.uartLogSend {
                    DLog(message: "send: \(hexString(data: chunk))")
                }
                
                blePeripheral.peripheral.writeValue(chunk as Data, for: txCharacteristic, type: txWriteType)
                offset+=chunkSize
            }while(offset<data.length)
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: UartNotifications.DidSendData.rawValue), object: nil, userInfo:["dataChunk" : dataChunk]);
        } else {
            DLog(message: "Error: sendChunk with uart not ready")
        }
        
    }
}
// MARK: - CBPeripheralDelegate
extension UartManager: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog(message: "UartManager: resetService because didModifyServices")
        resetService()
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        
        guard blePeripheral != nil else {
            return
        }
        
        if uartService == nil {
            if let services = peripheral.services {
                var found = false
                var i = 0
                while (!found && i < services.count) {
                    let service = services[i]
                    if (service.uuid.uuidString .caseInsensitiveCompare(UartManager.UartServiceUUID) == .orderedSame) {
                        found = true
                        uartService = service
                        
                        peripheral.discoverCharacteristics([CBUUID(string: UartManager.RxCharacteristicUUID), CBUUID(string: UartManager.TxCharacteristicUUID)], for: service)
                    }
                    i += 1
                }
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        guard blePeripheral != nil else {
   
            return
        }
        
        
        //DLog("uart didDiscoverCharacteristicsForService")
        if let uartService = uartService , rxCharacteristic == nil || txCharacteristic == nil {
            if rxCharacteristic == nil || txCharacteristic == nil {
                if let characteristics = uartService.characteristics {
                    var found = false
                    var i = 0
                    while !found && i < characteristics.count {
                        let characteristic = characteristics[i]
                        if characteristic.uuid.uuidString .caseInsensitiveCompare(UartManager.RxCharacteristicUUID) == .orderedSame {
                            rxCharacteristic = characteristic
                        }
                        else if characteristic.uuid.uuidString .caseInsensitiveCompare(UartManager.TxCharacteristicUUID) == .orderedSame {
                            txCharacteristic = characteristic
                            txWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse:.withResponse
                            DLog(message: "Uart: detected txWriteType: \(txWriteType.rawValue)")
                        }
                        found = rxCharacteristic != nil && txCharacteristic != nil
                        i += 1
                    }
                }
            }
            
            // Check if characteristics are ready
            if (rxCharacteristic != nil && txCharacteristic != nil) {
                // Set rx enabled
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                
                // Send notification that uart is ready
           
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: UartNotifications.DidBecomeReady.rawValue), object: nil, userInfo:nil)
                
                DLog(message: "Uart: did become ready")
                
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        guard blePeripheral != nil else {
            return
        }
        
        DLog(message: "didUpdateNotificationStateForCharacteristic")
        /*
         if characteristic == rxCharacteristic {
         if error != nil {
         DLog("Uart RX isNotifying error: \(error)")
         }
         else {
         if characteristic.isNotifying {
         DLog("Uart RX isNotifying: true")
         
         // Send notification that uart is ready
         NSNotificationCenter.defaultCenter().postNotificationName(UartNotifications.DidBecomeReady.rawValue, object: nil, userInfo:nil)
         }
         else {
         DLog("Uart RX isNotifying: false")
         }
         }
         }
         */
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        guard blePeripheral != nil else {
            return
        }
        
        
        if characteristic == rxCharacteristic && characteristic.service == uartService {
            
            if let characteristicDataValue = characteristic.value {
                receivedData(data: characteristicDataValue as NSData)
            }
        }
    }
}

