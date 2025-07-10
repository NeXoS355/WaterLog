import Foundation
import Combine

class DailyStatsManager: ObservableObject {
    @Published var entries: [DailyWaterEntry] = []

    private let key = "dailyWaterEntries"
    
    init() {
        load()
    }
    
    func fullListWithTodayEntry() -> [DailyWaterEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        let list = entries + [DailyWaterEntry(date: today, amount: DrinkManager.shared.currentAmount)]
        return list.sorted(by: { $0.date > $1.date })
    }
    
    func addEntry(amount: Int) {
        // Lokales Mitternacht heute
        let todayStart = Calendar.current.startOfDay(for: Date())
        // Gestern um Mitternacht
        let yesterdayStart = Calendar.current.date(byAdding: .day, value: -1, to: todayStart)!
        let entry = DailyWaterEntry(date: yesterdayStart, amount: amount)
        entries.append(entry)
        save()
    }


    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([DailyWaterEntry].self, from: data) {
            self.entries = decoded
        }
    }
    
    func reload() {
        load()
    }

}
