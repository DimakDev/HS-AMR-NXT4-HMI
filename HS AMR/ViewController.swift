//
//  ViewController.swift
//  HS AMR
//
//  Created by Dmytro Kostiuk on 06.11.19.
//  Copyright © 2019 Dmytro Kostiuk. All rights reserved.
//

import UIKit
import CoreBluetooth
import RxSwift
import RxCocoa

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
        ble.setOn(false, animated: true)
        writeValue(data: writePause)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print ("connected \(peripheral.name!)")
        ble.setOn(true, animated: true)
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
                DetailsController.input = [UInt8](val)
                detailsController.prozessArray(array: DetailsController.input)
                print ("Array size: \(DetailsController.input.count) Array: \(DetailsController.input)")
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
        
        createObjects()
        
        DetailsController.slotIndex.asObservable()
            .subscribe(onNext: { value in
                self.makeParkingSlot()
            })
            .disposed(by: bag)
        
        DetailsController.distance.asObservable()
            .subscribe(onNext: { value in
                self.animation()
            })
            .disposed(by: bag)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    let bag = DisposeBag()
    
    var centralManager : CBCentralManager!
    var myPeripheral : CBPeripheral?
    var myCharasteristic : CBCharacteristic?
    
    var detailsController = DetailsController()
    
    //UI interaction section
    @IBOutlet weak var ble: UISwitch!
    @IBOutlet weak var parking: UIButton!
    @IBOutlet weak var run: UIButton!
    
    var slot: UIButton!
    let robotLayer = CALayer()
    let pathLayer = CAShapeLayer()
    let pathM = UIBezierPath()
    let pathMLayer = CAShapeLayer()
    let start = CGPoint(x: 124, y: 95)
    var heading: Double = 0
    var mes: CGFloat = 400
    
    let parkThis:[UInt8] = [0x00, 0x01]
    let scout:[UInt8] = [0x00, 0x00]
    let pause:[UInt8] = [0x00, 0x03]
    
    lazy var writeParkThis =  Data(bytes: parkThis)
    lazy var writeScout =  Data(bytes: scout)
    lazy var writePause = Data(bytes: pause)
    
    @IBAction func ble(_ sender: UISwitch) {
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
    
    @IBAction func parking(_ sender: UIButton) {
        if myCharasteristic != nil {
            writeValue(data: writeParkThis)
        }
        UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.15)}, completion: {finish in UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform.identity})})
    }
    
    @IBAction func run(_ sender: UIButton) {
        if DetailsController.statusIndex.value == 0 {
            if myCharasteristic != nil {
                writeValue(data: writePause)
            }
        } else {
            if myCharasteristic != nil {
                writeValue(data: writeScout)
            }
        }
        UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.15)}, completion: {finish in UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform.identity})})
    }
    
    @IBAction func detailsButton(_ sender: Any) {
        performSegue(withIdentifier: "detailsSegue", sender: self)
    }
    
    @IBAction func unwindToGlobal(segue: UIStoryboardSegue) {
    }
    
    func createObjects() {
        let leftArea: CGRect = CGRect(x: start.x-mes*1.5/6, y: start.y+mes*0.5/6, width: mes/6, height: mes*5/6)
        let rightArea: CGRect = CGRect(x: start.x+mes*1.5/6, y: start.y+mes*1.5/6, width: mes/6, height: mes*3/6)
        let buttomArea: CGRect = CGRect(x: start.x, y: start.y+mes*6.5/6, width: mes/3, height: mes/6)
        
        let leftParking = UIView(frame: leftArea)
        let rightParking = UIView(frame: rightArea)
        let buttomParking = UIView(frame: buttomArea)
        
        leftParking.backgroundColor = UIColor.lightGray
        rightParking.backgroundColor = UIColor.lightGray
        buttomParking.backgroundColor = UIColor.lightGray
        
        self.view.addSubview(leftParking)
        self.view.addSubview(rightParking)
        self.view.addSubview(buttomParking)
        
        let road = UIBezierPath()
        
        road.move(to: start)
        road.addLine(to: CGPoint(x: start.x, y: start.y+mes))
        road.addLine(to: CGPoint(x: start.x+mes/3, y: start.y+mes))
        road.addLine(to: CGPoint(x: start.x+mes/3, y: start.y+mes*5/6))
        road.addLine(to: CGPoint(x: start.x+mes/6, y: start.y+mes*5/6))
        road.addLine(to: CGPoint(x: start.x+mes/6, y: start.y+mes/6))
        road.addLine(to: CGPoint(x: start.x+mes/3, y: start.y+mes/6))
        road.addLine(to: CGPoint(x: start.x+mes/3, y: start.y))
        road.close()
        
        let roadLayer = CAShapeLayer()
        roadLayer.path = road.cgPath
        roadLayer.fillColor = UIColor.clear.cgColor
        roadLayer.strokeColor = UIColor.lightGray.cgColor
        roadLayer.lineWidth = mes/10
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = road.cgPath
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.strokeColor = UIColor.darkGray.cgColor
        lineLayer.lineWidth = mes/45
        
        view.layer.addSublayer(roadLayer)
        view.layer.addSublayer(lineLayer)
        
        robotLayer.frame = CGRect(x: start.x-mes/14, y: start.y-mes/14, width: mes/7, height: mes/7)
        robotLayer.contentsGravity = CALayerContentsGravity.resizeAspect
        robotLayer.contents = UIImage(named: "Robot")?.cgImage
        robotLayer.zPosition = 1
        
        view.layer.addSublayer(robotLayer)
        
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.strokeColor = UIColor.black.cgColor
        pathLayer.lineCap = .round
        pathLayer.lineWidth = mes/45
        
        view.layer.addSublayer(pathLayer)
        
        pathM.move(to: CGPoint(x: start.x, y: start.y))

        pathMLayer.fillColor = UIColor.clear.cgColor
        pathMLayer.strokeColor = UIColor.black.cgColor
        pathMLayer.lineCap = .round
        pathMLayer.lineWidth = mes/45
        
        view.layer.addSublayer(pathMLayer)
    }
    
    func makeParkingSlot() {
        let mas = mes/180
//        let dmes = mes/16
        let frontSlot = CGPoint(x: DetailsController.frontSlot.x * mas + start.x, y: DetailsController.frontSlot.y * mas + start.y)
        let backSlot = CGPoint(x: DetailsController.backSlot.x * mas + start.x, y: DetailsController.backSlot.y * mas + start.y)
        let slotIndex = DetailsController.slotIndex.value
        let width: CGFloat = 50
        let height: CGFloat = 50

        print("x: \(frontSlot.x)")
        print("y: \(frontSlot.y)")

        
        if slotIndex != 0 {
            slot = UIButton(type: .system)
            slot.tag = slotIndex
            
            if(frontSlot.x < start.x) {
                slot.frame = CGRect(x: frontSlot.x-width, y: frontSlot.y, width: width, height: backSlot.y-frontSlot.y)
                makeAppearance(slot: slot)
            } else if (frontSlot.y > start.y+mes) {
                slot.frame = CGRect(x: frontSlot.x, y: frontSlot.y, width: backSlot.x-frontSlot.x, height: height)
                makeAppearance(slot: slot)
            } else if (frontSlot.x > start.x+mes/6 && frontSlot.y < start.y+mes*5/6) {
                slot.frame = CGRect(x: backSlot.x, y: backSlot.y, width: width, height: frontSlot.y-backSlot.y)
                makeAppearance(slot: slot)
            }
        }
    }
    
    func makeAppearance(slot: UIButton) {
        slot.layer.cornerRadius = 10
        slot.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
        
        if DetailsController.slotStatus == 0 {
            slot.setTitle("P", for: .normal)
            slot.setTitleColor(UIColor.black, for: .normal)
            slot.titleLabel!.font = UIFont.boldSystemFont(ofSize: 30)
            slot.addTarget(self, action: #selector(parkNow), for: UIControlEvents.touchUpInside)
        } else {
            slot.setTitle("–", for: .normal)
            slot.setTitleColor(UIColor.black, for: .normal)
            slot.titleLabel!.font = UIFont.boldSystemFont(ofSize: 30)
            slot.addTarget(self, action: #selector(alert), for: UIControlEvents.touchUpInside)
        }
        
        self.view.addSubview(slot)
    }

    func animation() {
        
        let mas = mes/180
        
        let to = CGPoint(x: DetailsController.to.x * mas + start.x, y: DetailsController.to.y * mas + start.y)
        let from = CGPoint(x: DetailsController.from.x * mas + start.x, y: DetailsController.from.y * mas + start.y)
        let durationMove = DetailsController.step/10
        
        let headingTo = -DetailsController.heading * .pi/180
        let headingFrom = -heading * .pi/180
        let durationRot = sqrt((headingTo-headingFrom)*(headingTo-headingFrom))/(2 * .pi) * 2

        if(DetailsController.from != DetailsController.to) {
            
            let moveAnimation = CABasicAnimation(keyPath: "position")
            moveAnimation.fromValue = from
            moveAnimation.toValue = to
            moveAnimation.duration = durationMove
            moveAnimation.fillMode = .forwards
            moveAnimation.isRemovedOnCompletion = false
            
            let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
            rotateAnimation.fromValue = headingFrom
            rotateAnimation.toValue = headingTo
            rotateAnimation.duration = durationRot
            rotateAnimation.beginTime = durationMove
            rotateAnimation.fillMode = .forwards
            rotateAnimation.isRemovedOnCompletion = false

            print("Heading: \(DetailsController.heading)")
            let group = CAAnimationGroup()
            group.animations = [moveAnimation, rotateAnimation]
            group.duration = durationMove + durationRot
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            robotLayer.add(group, forKey: nil)
            
            let path = UIBezierPath()
            path.move(to: from)
            path.addLine(to: to)
            
            pathLayer.path = path.cgPath
            
            pathM.addLine(to: from)
            pathMLayer.path = pathM.cgPath

            let pathAnimation = CABasicAnimation(keyPath: "strokeEnd")
            pathAnimation.fromValue = 0
            pathAnimation.toValue = 1
            pathAnimation.duration = DetailsController.step/10
            pathLayer.add(pathAnimation, forKey: nil)
            
            heading = DetailsController.heading
        }
    }
    
    @objc func parkNow(sender: UIButton) {
        if myCharasteristic != nil {
            writeValue(data: Data(bytes: [0x01, UInt8(sender.tag)]))
        }
        UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.15)}, completion: {finish in UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform.identity})})
    }
    
    @objc func alert(sender: UIButton) {
        let alert = UIAlertController(title: "", message: "This parking slot is to small", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
