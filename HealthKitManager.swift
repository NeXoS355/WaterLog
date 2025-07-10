import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater)!
        
        healthStore.requestAuthorization(toShare: [waterType], read: []) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit Authorization Error: \(error.localizedDescription)")
                }
                completion(success)
            }
        }
    }

    func saveWater(amountInMl: Int, date: Date = Date()) {
        requestAuthorization { authorized in
            guard authorized else {
                print("Failed to save to HealthKit: Authorization is not granted")
                return
            }

            let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
            let quantity = HKQuantity(unit: .liter(), doubleValue: Double(amountInMl) / 1000.0)
            let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
            
            self.healthStore.save(sample) { success, error in
                if let error = error {
                    print("Error saving to HealthKit: \(error.localizedDescription)")
                } else {
                    print("Saved \(amountInMl)ml to HealthKit.")
                }
            }
        }
    }
}
