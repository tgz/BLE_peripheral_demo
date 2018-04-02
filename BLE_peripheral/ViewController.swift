//
//  ViewController.swift
//  BLE_peripheral
//
//  Created by qsc on 2018/3/29.
//  Copyright © 2018年 zerozero. All rights reserved.
//

import UIKit
import CoreBluetooth

private let SerivceUUID: String = "7C40"
private let CharacteristicUUID: String = "7c4003e7-e889-46db-a124-e1ac994f8113"

class ViewController: UIViewController {

    private var peripheralManager: CBPeripheralManager?
    private var characteristic: CBMutableCharacteristic?
    
    private var service: CBMutableService?
    
    private var central: CBCentral?
    
    @IBOutlet weak var ssid_textField: UITextField!
    @IBOutlet weak var password_textField: UITextField!
    
    @IBOutlet weak var logView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        title = "BLE Peripheral"
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func clearLog(_ sender: Any) {
        self.logView.text.removeAll()
    }
    
    func log(_ items: Any...) {
        self.logView.text.append("\n")
        self.logView.text.append(String(describing: items))
    }
}

extension ViewController: CBPeripheralManagerDelegate {
    func setupService() {
        log("start setupService")
        let serviceID = CBUUID(string: SerivceUUID)
        let service = CBMutableService(type: serviceID, primary: true)
        let characteristicID = CBUUID(string: CharacteristicUUID)
        
        let characteristic = CBMutableCharacteristic(type: characteristicID,
                                                     properties: [.read, .write, .notify],
                                                     value: nil,
                                                     permissions: [.readable, .writeable])
        
        service.characteristics = [characteristic]
        self.service = service
        self.peripheralManager?.add(service)
        self.characteristic = characteristic
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let log_perfix = "state changed: "
        
        var state = ""
        
        switch peripheral.state {
        case .unknown:
            state = "unknown"
        case .poweredOff:
            state = "poweredOff"
            peripheralManager?.stopAdvertising()
        case .poweredOn:
            setupService()
            guard let manager = peripheralManager else {
                log("peripheral manager is not exist, break")
                break
            }
            manager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey : [self.service!.uuid]
                ])
            state = "poweredOn"
        case .resetting:
            state = "resetting"
        case .unauthorized:
            state = "unauthorized"
        case .unsupported:
            state = "unsupported"
        }
        
        log("\(log_perfix)\(state)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        let request = requests.last!
        log("receive write value: 0x\(request.value?.hexString ?? ""))")
        peripheral.respond(to: request, withResult: .success)
        if let d = request.value {
            response(to: d)
        }
        
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let str = "response\(arc4random()%10)"
        log("response value: \(str)")
        request.value = str.data(using: .utf8)
        peripheral.respond(to: request, withResult: .success)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        self.central = central
        log("subscribe successed")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        self.central = nil
        log("unsubscribe successed")
    }
}

extension ViewController {
    
    func response(to command: Data) {
        
        func errorResponse() {
            sendResponse(content: Data(bytes: [0x00, 0x00]))
        }
        
        let bytes = [UInt8](command)
        guard bytes.count == 2 else {
            errorResponse()
            return
        }
        
        if bytes[0] == 0xff && bytes[1] == 0xf0 {
            log("send response for 0xfff0")
            sendResponse(content: ssid_textField.text?.data(using: .utf8) ?? Data())
        } else if bytes[0] == 0xff && bytes[1] == 0xf1 {
            log("send response for 0xfff1")
            sendResponse(content: password_textField.text?.data(using: .utf8) ?? Data())
        } else {
            errorResponse()
        }
    }
    
    func sendResponse(content: Data) {
        guard let ch = characteristic, let ce = central else {
            log("central or characteristic is nil!")
            return
        }
        peripheralManager?.updateValue(content, for: ch, onSubscribedCentrals: [ce])
    }
    
}

extension Data {
    var hexString: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}

