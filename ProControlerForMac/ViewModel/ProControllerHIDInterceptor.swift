//
//  ProControllerHIDInterceptor.swift
//  ProControlerForMac
//
//  Capture ボタンのみ HID で取得し、GameController にないためアプリに渡す。
//

import Foundation
import IOKit
import IOKit.hid

private let kIOHIDManagerOptionNoneValue: IOOptionBits = 0
private let kIOHIDOptionsTypeSeizeDeviceValue: IOOptionBits = 4
private let kProControllerReportLength = 64
private let kHIDPage_GenericDesktop: Int = 0x01
private let kHIDUsage_GD_GamePad: Int = 0x05

final class ProControllerHIDInterceptor {
    static let shared = ProControllerHIDInterceptor()
    var onButtonEvent: ((String, Bool) -> Void)?

    private var hidManager: IOHIDManager?
    private var hidDevice: IOHIDDevice?
    private var reportBufferPointer: UnsafeMutablePointer<UInt8>?
    private var lastCapturePressed: Bool = false
    private let nintendoVendorId = 0x057E
    private let proControllerProductId = 0x2009

    private init() {}

    static func initializeEarly() {
        shared.setupHIDManager()
    }

    private func setupHIDManager() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNoneValue)
        self.hidManager = manager
        let proConCriteria: [String: Any] = [
            "DeviceUsagePage": NSNumber(value: kHIDPage_GenericDesktop),
            "DeviceUsage": NSNumber(value: kHIDUsage_GD_GamePad),
            "VendorID": NSNumber(value: nintendoVendorId),
            "ProductID": NSNumber(value: proControllerProductId)
        ]
        let criteriaArray = [proConCriteria] as CFArray
        IOHIDManagerSetDeviceMatchingMultiple(manager, criteriaArray)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDManagerOpen(manager, kIOHIDOptionsTypeSeizeDeviceValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context = context else { return }
            let interceptor = Unmanaged<ProControllerHIDInterceptor>.fromOpaque(context).takeUnretainedValue()
            interceptor.deviceAdded(device: device)
        }, selfPtr)
    }

    private func deviceAdded(device: IOHIDDevice) {
        hidDevice = device
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        _ = IOHIDDeviceOpen(device, kIOHIDOptionsTypeSeizeDeviceValue)
        reportBufferPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: kProControllerReportLength)
        reportBufferPointer?.initialize(repeating: 0, count: kProControllerReportLength)
        guard let ptr = reportBufferPointer else { return }
        IOHIDDeviceRegisterInputReportCallback(device, ptr, kProControllerReportLength, { context, _, _, _, _, report, reportLength in
            guard let context = context, reportLength >= 6 else { return }
            let interceptor = Unmanaged<ProControllerHIDInterceptor>.fromOpaque(context).takeUnretainedValue()
            interceptor.parseReport(report: report, length: reportLength)
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    private func parseReport(report: UnsafeMutablePointer<UInt8>, length: Int) {
        let offset = (report[0] == 0x30 && length >= 6) ? 3 : 2
        guard length >= offset + 2 else { return }
        let button2 = report[offset + 1]
        let capturePressed = (button2 & 0x20) != 0
        if lastCapturePressed != capturePressed {
            lastCapturePressed = capturePressed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) { [weak self] in
                self?.onButtonEvent?("buttonCapture", capturePressed)
            }
        }
    }
}
