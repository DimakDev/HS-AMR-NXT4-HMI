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
        writeValue(data: writeModePause)
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
                self.makeButton()
            })
            .disposed(by: bag)
        
        DetailsController.distance.asObservable()
            .subscribe(onNext: { value in
                self.pathAnimation()
                self.robotAnimation()
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
    
    var slotButton: UIButton!
    var robotLayer = CALayer()

    var toggled = false
    
    var openInputStream: [UInt8] = [0x09, 0x00]
    var closeInputStream: [UInt8] = [0x08, 0x00]
    
    var modeParking:[UInt8] = [0x00, 0x01]
    var modeScout:[UInt8] = [0x00, 0x00]
    var modePause:[UInt8] = [0x00, 0x03]

    lazy var writeOpenStream =  Data(bytes: openInputStream)
    lazy var writeCloseStream =  Data(bytes: closeInputStream)

    lazy var writeModeParking =  Data(bytes: modeParking)
    lazy var writeModeScout =  Data(bytes: modeScout)
    lazy var writeModePause = Data(bytes: modePause)
    
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
        writeValue(data: writeModeParking)
        }
        UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.15)}, completion: {finish in UIButton.animate(withDuration: 0.1, animations: {sender.transform = CGAffineTransform.identity})})
    }
    
    @IBAction func run(_ sender: UIButton) {
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
    
    
    @IBAction func detailsButton(_ sender: Any) {
        performSegue(withIdentifier: "detailsSegue", sender: self)
        if myCharasteristic != nil {
            //writeValue(data: writeOpenStream)
        }
    }
    
    /*
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! DetailsController
        vc.printBuffer = GlobalVariable.inputBuffer
    }
    */
 
    @IBAction func unwindToGlobal(segue: UIStoryboardSegue) {
        if myCharasteristic != nil {
            //writeValue(data: writeCloseStream)
        }
    }
    
    func createObjects() {
        //let screenSize: CGRect = UIScreen.main.bounds
        
        // get screen width.
        // let screenWidth = screenSize.width
        
        // get screen height.
        // let screenHeight = screenSize.height
        
        // Create a CGRect object which is used to render a rectangle.
        let leftArea: CGRect = CGRect(x: 15, y: 135, width: 77, height: 344)
        let rightArea: CGRect = CGRect(x: 228, y: 218, width: 82, height: 181)
        let buttomArea: CGRect = CGRect(x: 125, y: 549, width: 138, height: 73)
        
        // Create a UIView object which use above CGRect object.
        let leftParking = UIView(frame: leftArea)
        let rightParking = UIView(frame: rightArea)
        let buttomParking = UIView(frame: buttomArea)
        
        // Set UIView background color.
        leftParking.backgroundColor = UIColor.lightGray
        rightParking.backgroundColor = UIColor.lightGray
        buttomParking.backgroundColor = UIColor.lightGray
        
        // Add above UIView object as the main view's subview.
        self.view.addSubview(leftParking)
        self.view.addSubview(rightParking)
        self.view.addSubview(buttomParking)
        
        //design the path
        let road = UIBezierPath()
        road.move(to: CGPoint(x: 124, y: 494))
        road.addLine(to: CGPoint(x: 263, y: 494))
        road.addLine(to: CGPoint(x: 263, y: 426))
        road.addLine(to: CGPoint(x: 194, y: 426))
        road.addLine(to: CGPoint(x: 194, y: 162))
        road.addLine(to: CGPoint(x: 263, y: 162))
        road.addLine(to: CGPoint(x: 263, y: 95))
        road.addLine(to: CGPoint(x: 124, y: 95))
        road.close()
        
        //design path in layer
        let roadLayer = CAShapeLayer()
        roadLayer.path = road.cgPath
        roadLayer.fillColor = UIColor.clear.cgColor
        roadLayer.strokeColor = UIColor.lightGray.cgColor
        roadLayer.lineWidth = 40.0
        
        let pathLayer = CAShapeLayer()
        pathLayer.path = road.cgPath
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.strokeColor = UIColor.darkGray.cgColor
        pathLayer.lineWidth = 8.0
        
        view.layer.addSublayer(roadLayer)
        view.layer.addSublayer(pathLayer)
        
        robotLayer.frame = CGRect(x: 124-32, y: 95-34, width: 70, height: 70)
        //robotLayer.backgroundColor = UIColor.black.cgColor
        robotLayer.contentsGravity = CALayerContentsGravity.resizeAspect
        robotLayer.contents = UIImage(named: "Robot")?.cgImage
        robotLayer.zPosition = 1
        view.layer.addSublayer(robotLayer)
    }
    
    func makeButton() {
        //if DetailsController.slotIndex.value != 0 {
        slotButton = UIButton(type: .system)
        slotButton.tag = DetailsController.slotIndex.value
        // bad size and position of parking slot
        //slotButton.bounds = CGRect(x: DetailsController.frontSlot.x, y: DetailsController.frontSlot.y, width: 30, height: 30)
        slotButton.frame = CGRect(x: 25, y: 150, width: 60, height: 60)
        slotButton.layer.cornerRadius = 10
        slotButton.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
        if DetailsController.slotStatus == 0 {
            slotButton.setTitle("P", for: .normal)
            slotButton.setTitleColor(UIColor.black, for: .normal)
            slotButton.titleLabel!.font = UIFont.boldSystemFont(ofSize: 30)
            slotButton.addTarget(self, action: #selector(parkThis), for: UIControlEvents.touchUpInside)
        } else {
            slotButton.setTitle("X", for: .normal)
            slotButton.setTitleColor(UIColor.black, for: .normal)
            slotButton.titleLabel!.font = UIFont.boldSystemFont(ofSize: 30)
            slotButton.addTarget(self, action: #selector(alert), for: UIControlEvents.touchUpInside)
        }
        // if the parking slot isnt suitable, than set the color to darkGray
        
        self.view.addSubview(slotButton)
        //}
    }
    
    func pathAnimation() {
        let path = UIBezierPath()
        path.move(to: DetailsController.from)
        //path.addLine(to: DetailsController.to)
        path.addLine(to: CGPoint(x: DetailsController.to.x, y: DetailsController.to.y + CGFloat(200)))

        let pathLayer = CAShapeLayer()
        pathLayer.path = path.cgPath
        pathLayer.fillColor = UIColor.clear.cgColor
        pathLayer.strokeColor = UIColor.black.cgColor
        pathLayer.lineDashPattern = [2, 4]
        pathLayer.lineWidth = 8.0
        
        view.layer.addSublayer(pathLayer)
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.duration = 6
        pathLayer.add(animation, forKey: "Driving Path Animation")
    }
    
    func robotAnimation() {
//        let imageLayer = CALayer()
//        imageLayer.frame = CGRect(x: 124-32, y: 95-34, width: 70, height: 70)
//        imageLayer.contentsGravity = CALayerContentsGravity.resizeAspect
//        imageLayer.contents = UIImage(named: "Robot")?.cgImage
//        view.layer.addSublayer(imageLayer)
        //var animations = [CABasicAnimation]()
        
        let moveAnimation = CABasicAnimation(keyPath: "position")
        moveAnimation.fromValue = CGPoint(x: DetailsController.from.x + CGFloat(3), y: DetailsController.from.y + CGFloat(1))
        moveAnimation.toValue = CGPoint(x: DetailsController.to.x + CGFloat(3), y: DetailsController.to.y + CGFloat(1) + CGFloat(200))
        moveAnimation.duration = 6
        moveAnimation.fillMode = .forwards
        moveAnimation.isRemovedOnCompletion = false
        //robotLayer.add(moveAnimation, forKey: "Robot moveAnimation")
        //animations.append(moveAnimation)

        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0.0
        rotateAnimation.toValue = CGFloat(Double.pi * Double(DetailsController.heading))
        //rotateAnimation.toValue = CGFloat(Double.pi * (-1))
        rotateAnimation.duration = 2
        rotateAnimation.beginTime = 6
        //rotateAnimation.fillMode = .forwards
        //rotateAnimation.isRemovedOnCompletion = false
        //robotLayer.add(rotateAnimation, forKey: "Robot rotational animation")
        //animations.append(rotateAnimation)
        
        let group = CAAnimationGroup()
        group.animations = [moveAnimation, rotateAnimation]
        group.duration = 8
        //group.repeatCount = Float.greatestFiniteMagnitude
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        //group.animations = animations
        
        robotLayer.add(group, forKey: nil)
        
        
    }
    
    @objc func parkThis(sender: UIButton) {
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
