//
//  DetailsViewController.swift
//  HS AMR
//
//  Created by Dmytro Kostiuk on 23.11.19.
//  Copyright © 2019 Dmytro Kostiuk. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class DetailsController: UIViewController {
    
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var slots: UILabel!
    

    static var input: [UInt8] = []
    static var statusIndex = BehaviorRelay<Int>(value: 2)
    static var slotIndex = BehaviorRelay<Int>(value: 0)
    static var distance = BehaviorRelay<Double>(value: 0)
    
    static var distanceSum: Double = 0
    static var slotStatus: Int = 0
    static var step: Double = 0
    static var heading: Double = 0
    static var from: CGPoint = CGPoint(x: 0,y: 0)
    static var to: CGPoint = CGPoint(x: 0,y: 0)
    // 0 for suitable, 1 for not suitable
    static var frontSlot: CGPoint = CGPoint(x: 0,y: 0)
    static var backSlot: CGPoint = CGPoint(x: 0,y: 0)
    
    let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.status.layer.cornerRadius  = 30
        
        DetailsController.statusIndex.asObservable()
            .subscribe(onNext: { value in
                switch DetailsController.statusIndex.value {
                case 0:
                    self.status.backgroundColor = UIColor.green
                case 1:
                    self.status.backgroundColor = UIColor.gray
                case 2:
                    self.status.backgroundColor = UIColor.black
                default:
                    self.status.backgroundColor = UIColor.red
                }
            })
            .disposed(by: bag)
        
        DetailsController.distance.asObservable()
            .subscribe(onNext: { value in
                self.distance.text = "\(String(format: "%.01f", DetailsController.distance.value)) cm"
            })
            .disposed(by: bag)
        
        DetailsController.slotIndex.asObservable()
            .subscribe(onNext: { value in
                if DetailsController.slotIndex.value == 1 {
                    self.slots.text = "\(DetailsController.slotIndex.value) slot"
                } else {
                    self.slots.text = "\(DetailsController.slotIndex.value) slots"
                }
            })
            .disposed(by: bag)

    }
    
    func prozessInput(array: [UInt8]) {
        switch Int(array[0]) {
        case 4:
            DetailsController.statusIndex.accept(Int(array[1]))
        case 3:
            DetailsController.slotStatus = Int(array[1])
            DetailsController.frontSlot.x = array[3] == 1 ? CGFloat(array[4]) * (-1) : CGFloat(array[4])
            DetailsController.frontSlot.y = CGFloat(array[5])
            DetailsController.backSlot.x = array[6] == 1 ? CGFloat(array[7]) * (-1) : CGFloat(array[7])
            DetailsController.backSlot.y = CGFloat(array[8])
            DetailsController.slotIndex.accept(Int(array[2]))
        case 2:
            DetailsController.to.x = array[1] == 1 ? CGFloat(array[2]) * (-1) : CGFloat(array[2])
            DetailsController.to.y = array[3] == 1 ? CGFloat(array[4]) * (-1) : CGFloat(array[4])
            DetailsController.heading = convertHeadingTo360(value: array[5] == 1 ? Double(array[6]) * (-1) : Double(array[6]))
            DetailsController.step = Double(CGPointDistance(from: DetailsController.from, to: DetailsController.to))
            DetailsController.distanceSum += DetailsController.step
            DetailsController.distance.accept(DetailsController.distanceSum)
            DetailsController.from = DetailsController.to
        default:
            print("Input index doen't match the input stream...")
        }
        
    }
    
    func convertHeadingTo360 (value: Double) -> Double {
        return value < 0 ? 360 + value : value
    }
    
    func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
        return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    }
    
    func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt(CGPointDistanceSquared(from: from, to: to))
    }
}
