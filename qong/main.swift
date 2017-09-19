//
//  main.swift
//  qong
//
//  Created by Glenn R. Martin on 9/10/17.
//  Copyright © 2017 Glenn R. Martin. All rights reserved.
//

import Foundation

import IOKit.pwr_mgt
import IOKit.usb
import IOKit

typealias KVP = (name:String, value:NSObject)

/* Settings */
let findDevice: [KVP] = [
    (name:"USB Serial Number", value: "0000000000"      as NSString), // fill-in
    (name:"USB Product Name",  value: "Keyboard/RawHID" as NSString),
    (name:"idVendor",          value: 5824              as NSNumber),
    (name:"idProduct",         value: 1158              as NSNumber)
]

let checkUntilKilled = false /* false = run once, true = loop with break between checkruns untill forcefully killed */
let sleepBetweenChecks = 1 /* mins */
let sleepBetweenTerminations = 9 /* mins */
let printUsbData = false

/* Program Code */
let SECS_PER_MIN = 60
let REASON_FOR_ACTIVITY = "Sleep suspended because user identifying device found." as CFString

var term = false

func usbMatching(pairs: [KVP]) -> Bool {
    let ioRoot = IORegistryGetRootEntry(kIOMasterPortDefault)
    var iterator : io_iterator_t = 0
    
    defer {
        IOObjectRelease(ioRoot)
        IOObjectRelease(iterator)
    }
    
    if IORegistryEntryCreateIterator(ioRoot, kIOUSBPlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS {
        var entry: io_object_t = 0
        
        repeat {
            entry = IOIteratorNext(iterator)
            
            var dict: Unmanaged<CFMutableDictionary>?
            
            IORegistryEntryCreateCFProperties(entry, &dict, nil, 0)
            
            let unretained = dict?.takeUnretainedValue()
            
            if let props: NSDictionary = unretained {
                if printUsbData {
                    print(" ")
                    print("*************************************")
                    print("\(props)")
                    print(" ")
                }
                
                let ret = pairs.filter({ kvp in
                    guard let val = props.value(forKey: kvp.name) as? NSObject else { return false }
                    return val == kvp.value
                }).count == pairs.count
                
                if ret {
                    return true
                }
                
            }
        } while entry != 0
        
    }
    
    return false
}

signal(SIGUSR2, { _ in
    print("G")
    term = true
})

let primarySubroutine = {
    term = false
    var assertionID: IOPMAssertionID = 0
    var success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                              IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                              REASON_FOR_ACTIVITY,
                                              &assertionID)
    
    let suspendLoop = { (msg: String) -> Bool in
        print(msg)
        if usbMatching(pairs: findDevice) == false {
            print("U")
            term = true
            return true
        }
        return false
    }
    
    if (success == kIOReturnSuccess) {
        print("R")
        while term == false {
            if suspendLoop("s") { break }
            sleep(UInt32(sleepBetweenChecks * SECS_PER_MIN))
            if suspendLoop("c") { break }
            
        }
        
        print("T")
        
        _ = IOPMAssertionRelease(assertionID)
    }
}

if checkUntilKilled == false {
    print("1")
    primarySubroutine()
} else {
    print("*")
    while true {
        primarySubroutine()
        sleep(UInt32(sleepBetweenTerminations * SECS_PER_MIN))
        print("@")
    }
}
