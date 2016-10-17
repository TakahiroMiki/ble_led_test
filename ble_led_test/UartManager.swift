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
    private static let UartServiceUUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"       // UART service UUID
    static let RxCharacteristicUUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    private static let TxCharacteristicUUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    private static let TxMaxCharacters = 20
    
    //Data
    var dataBuffer = [UartDataChunk]()
    var dataBufferEnabled = Config.uartShowAllUartCommunication
    
    // Bluetooth Uart
    private var uartService: CBService?
    private var rxCharacteristic: CBCharacteristic?
    private var txCharacteristic: CBCharacteristic?
    private var txWriteType = CBCharacteristicWriteType.withResponse
    
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
    
    private func resetService() {
        uartService = nil
        rxCharacteristic = nil
        txCharacteristic = nil
    }
    func sendDataWithCrc(data : NSData) {
        
        let len = data.length
        var dataBytes = [UInt8](repeating: 0, count: len)
        var crc: UInt8 = 0
        data.getBytes(&dataBytes, length: len)
        
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
