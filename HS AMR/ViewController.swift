//
//  ViewController.swift
//  HS AMR
//
//  Created by Dmytro Kostiuk on 06.11.19.
//  Copyright © 2019 Dmytro Kostiuk. All rights reserved.
//

import UIKit
import CoreBluetooth

let svcBT05 = CBUUID.init(string: "FFE0")
let charBT05 = CBUUID.init(string: "FFE1")

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            if let pUUIDString = UserDefaults.standard.object(forKey: "PUUID") as? String {
                if let pUUID = UUID.init(uuidString: pUUIDString) {
                    let peripherals = centralManager.retrievePeripherals(withIdentifiers: [pUUID])
                    if let p = peripherals.first {
                        connect(toPeripheral: p)
                        return
                    }
                }
            }
            let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [CBUUID.init(string: "FFE0")])
            if let p = peripherals.first {
                connect(toPeripheral: p)
                return
            }
            central.scanForPeripherals(withServices: [CBUUID.init(string: "FFE0")], options: nil)
            print ("scanning...")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("BT05") == true {
            print (advertisementData)
            connect(toPeripheral: peripheral)
        }
    }
    
    func connect(toPeripheral: CBPeripheral) {
        print (toPeripheral.name ?? "no name")
        centralManager.stopScan()
        centralManager.connect(toPeripheral, options: nil)
        myPeripheral = toPeripheral
    }
    
    func disconnect() {
        if let p = myPeripheral {
            centralManager.cancelPeripheralConnection(p)
        } else if let p = myPeripheral {
            centralManager.cancelPeripheralConnection(p) //TODO: Test whether its neccesary to set p to nil
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        central.scanForPeripherals(withServices: [CBUUID.init(string: "FFE0")], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print ("disconnected \(peripheral.name!)")
        Disconnect.setOn(false, animated: true)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print ("connected \(peripheral.name!)")
        Disconnect.setOn(true, animated: true)
        peripheral.discoverServices(nil)
        peripheral.delegate = self
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "PUUID")
        UserDefaults.standard.synchronize()
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for svc in services {
                if svc.uuid == svcBT05 {
                    print (svc.uuid.uuidString)
                    peripheral.discoverCharacteristics(nil, for: svc)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let chars = service.characteristics {
            for char in chars {
                print (char.uuid.uuidString)
                if char.uuid == charBT05 {
                    myCharasteristic = char
                    peripheral.setNotifyValue(true, for: char)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let val = characteristic.value {
            if characteristic.uuid == charBT05 {
                print ("modeID: \([UInt8](val))")
            }
        }
    }
    
    func writeValue(data: Data) {
        if myCharasteristic!.properties.contains(CBCharacteristicProperties.writeWithoutResponse) {
            myPeripheral!.writeValue(data, for: myCharasteristic!, type: CBCharacteristicWriteType.withoutResponse)
        }
        else {
            myPeripheral!.writeValue(data, for: myCharasteristic!, type: CBCharacteristicWriteType.withResponse)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print ("wrote value")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        centralManager = CBCentralManager.init(delegate: self, queue: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    var centralManager : CBCentralManager!
    var myPeripheral : CBPeripheral?
    var myCharasteristic : CBCharacteristic?
    
    
    //Interactive section for communication between UI and Arduino UNO
    @IBOutlet weak var Disconnect: UISwitch!
    @IBOutlet weak var Parking: UIButton!
    @IBOutlet weak var Run: UIButton!
    
    var toggled = false
    
    let modeParking:[UInt8] = [0x00, 0x01]
    let modeScout:[UInt8] = [0x00, 0x00]
    let modePause:[UInt8] = [0x00, 0x03]

    lazy var writeModeParking =  Data(bytes: modeParking)
    lazy var writeModeScout =  Data(bytes: modeScout)
    lazy var writeModePause = Data(bytes: modePause)
    
    @IBAction func Disconnect(_ sender: UISwitch) {
        if sender.isOn {
            let alert = UIAlertController(title: "Connect?", message: "Set bluetooth connection to NXT", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {action in
                self.connect(toPeripheral: self.myPeripheral!)
                sender.setOn(false, animated: true)}))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: {action in
                sender.setOn(false, animated: true)}))
            self.present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: "Disconnect?", message: "Lose bluetooth connection to NXT", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: {action in
                self.disconnect()}))
            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: {action in
                sender.setOn(true, animated: true)}))
            self.present(alert, animated: true)
        }
    }
    
    // modeID [02] for Parking_THIS
    @IBAction func Parking(_ sender: UIButton) {
        UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.15)}, completion: {finish in UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform.identity})})
        if myCharasteristic != nil {
        writeValue(data: writeModeParking)
        }
    }
    
    @IBAction func Run(_ sender: UIButton) {
        if toggled == false {
            if myCharasteristic != nil {
            writeValue(data: writeModeScout)
            toggled = true
            }
        } else {
            if myCharasteristic != nil {
            writeValue(data: writeModePause)
            toggled = false
            }
        }
        UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.15)}, completion: {finish in UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform.identity})})
    }
    
    @IBAction func unwindToGlobal(segue: UIStoryboardSegue) {
    }
}
