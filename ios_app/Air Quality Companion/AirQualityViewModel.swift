//
//  AirQualityViewModel.swift
//  Air Quality Companion
//
//  Created by Ryan Carroll on 3/3/25.
//


import Foundation
import CoreBluetooth
import CoreData

class AirQualityViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Published properties to update the UI
    @Published var currentPM1_0: Int = 0
    @Published var currentPM2_5: Int = 0
    @Published var currentPM10: Int = 0

    // Bluetooth properties
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var airQualityCharacteristic: CBCharacteristic?

    private let serviceUUID = CBUUID(string: "12345678-1234-1234-1234-1234567890AB")
    private let characteristicUUID = CBUUID(string: "87654321-4321-4321-4321-210987654321")

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - CBCentralManagerDelegate Methods

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [serviceUUID], options: nil)
            print("Scanning for peripherals...")
        } else {
            print("Bluetooth is not powered on.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unnamed")")
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
        central.stopScan()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unnamed")")
        peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from peripheral: \(error?.localizedDescription ?? "No error")")
        // Attempt to reconnect
        central.connect(peripheral, options: nil)
    }

    // MARK: - CBPeripheralDelegate Methods

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error)")
            return
        }
        if let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error)")
            return
        }
        if let characteristic = service.characteristics?.first(where: { $0.uuid == characteristicUUID }) {
            airQualityCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
            print("Subscribed to air quality characteristic")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error receiving data: \(error)")
            return
        }
        if let data = characteristic.value, let str = String(data: data, encoding: .utf8) {
            // Assuming data format: "PM1.0,PM2.5,PM10" (e.g., "10,15,20")
            let values = str.split(separator: ",").compactMap { Int($0) }
            if values.count == 3 {
                DispatchQueue.main.async {
                    self.currentPM1_0 = values[0]
                    self.currentPM2_5 = values[1]
                    self.currentPM10 = values[2]
                }
                saveReading(pm1_0: values[0], pm2_5: values[1], pm10: values[2])
            }
        }
    }

    // MARK: - Data Persistence

    private func saveReading(pm1_0: Int, pm2_5: Int, pm10: Int) {
        let reading = AirQualityReading(context: context)
        //reading.timestamp = Date()
        //reading.pm10 = Int16(pm1_0)
        //reading.pm25 = Int16(pm2_5)
        //reading.pm10 = Int16(pm10)
        

        do {
            try context.save()
            print("Saved reading: PM1.0=\(pm1_0), PM2.5=\(pm2_5), PM10=\(pm10)")
        } catch {
            print("Failed to save reading: \(error)")
        }
    }
}
