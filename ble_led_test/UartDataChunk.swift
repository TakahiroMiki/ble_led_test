//
//  File.swift
//  ble_led_test
//
//  Created by 三木隆裕 on 2016/10/17.
//  Copyright © 2016年 tmtakahiro. All rights reserved.
//

import Foundation

class UartDataChunk {      // A chunk of data received or sent
    var timestamp : CFAbsoluteTime
    enum TransferMode {
        case TX
        case RX
    }
    var mode : TransferMode
    var data : NSData
    
    init(timestamp: CFAbsoluteTime, mode: TransferMode, data: NSData) {
        self.timestamp = timestamp
        self.mode = mode
        self.data = data
    }
}
