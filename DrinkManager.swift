import Foundation
import SwiftUI
import HealthKit


class DrinkManager: ObservableObject {
    static let shared = DrinkManager()
    private let healthStore = HKHealthStore()


    @Published var currentAmount: Int = 0
    @Published var targetAmount: Int = 2000
    @Published var drinkEntries: [DrinkEntry] = []

    private let currentAmountKey = "currentAmount"
    private let targetAmountKey = "targetAmount"
    private let lastResetDateKey = "lastResetDate"
    private let drinkEntriesKey = "drinkEntries"

    var lastResetDate: Date {
        get {
            UserDefaults.standard.object(forKey: lastResetDateKey) as? Date ?? Date.distantPast
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastResetDateKey)
        }
    }

    private init() {
        loadData()
    }

    func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater)!

        healthStore.requestAuthorization(toShare: [waterType], read: []) { success, error in
            if !success {
                print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    func addDrink(amount: Int) {
        resetIfNeeded()
        let entry = DrinkEntry(amount: amount, timestamp: Date())
        drinkEntries.append(entry)
        currentAmount += amount
        saveData()
        updateNotifications()
    }
    
    func deleteDrink(entry: DrinkEntry) {
        if let index = drinkEntries.firstIndex(where: { $0.id == entry.id }) {
            currentAmount -= drinkEntries[index].amount
            drinkEntries.remove(at: index)
            saveData()
            updateNotifications()
        }
    }

    
    func updateDrinkEntry(id: UUID, newTimestamp: Date) {
        if let index = drinkEntries.firstIndex(where: { $0.id == id }) {
            var updated = drinkEntries[index]
            updated = DrinkEntry(id: updated.id, amount: updated.amount, timestamp: newTimestamp)
            drinkEntries[index] = updated
            saveData()
            drinkEntries.sort { $0.timestamp < $1.timestamp }
            updateNotifications()
        }
    }

    func resetIfNeeded() {
        loadData()
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            if currentAmount > 0 {
                DailyStatsManager().addEntry(amount: currentAmount)
                let healthKitSyncEnabled = UserDefaults.standard.bool(forKey: "healthKitSyncEnabled")
                if healthKitSyncEnabled {
                    HealthKitManager.shared.saveWater(amountInMl: currentAmount, date: lastResetDate)
                }
            }
            currentAmount = 0
            drinkEntries = []
            lastResetDate = Date()
            saveData()
            print("Tagesmenge gespeichert und zurückgesetzt.")
        }
    }

    private func loadData() {
        currentAmount = UserDefaults.standard.integer(forKey: currentAmountKey)
        targetAmount = UserDefaults.standard.integer(forKey: targetAmountKey)

        if let data = UserDefaults.standard.data(forKey: drinkEntriesKey),
           let decoded = try? JSONDecoder().decode([DrinkEntry].self, from: data) {
            drinkEntries = decoded
        } else {
            drinkEntries = []
        }
    }

    private func saveData() {
        UserDefaults.standard.set(currentAmount, forKey: currentAmountKey)
        UserDefaults.standard.set(targetAmount, forKey: targetAmountKey)

        if let data = try? JSONEncoder().encode(drinkEntries) {
            UserDefaults.standard.set(data, forKey: drinkEntriesKey)
        }
    }
    
    private func saveToHealthKit(amount: Int, date: Date) {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(amount))
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)

        healthStore.save(sample) { success, error in
            if !success {
                print("Failed to save to HealthKit: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func updateNotifications() {
        let permissionGranted = UserDefaults.standard.bool(forKey: "notificationPermissions")
        NotificationManager.shared.scheduleDailyNotifications(notificationPermissions: permissionGranted)
    }

}
