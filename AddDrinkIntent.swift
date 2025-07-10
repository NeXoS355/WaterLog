import AppIntents
import Foundation

struct AddDrinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Wasser hinzufügen"
    static var description = IntentDescription("Fügt eine beliebige Menge Wasser zu deiner täglichen Wasseraufnahme hinzu.")
    static var openAppWhenRun = false

    @Parameter(title: "Menge in ml")
    var amount: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Füge \(\.$amount) ml Wasser hinzu")
    }

    func perform() async throws -> some IntentResult {
        var entries = getDrinkEntries()
        entries.append(DrinkEntry(amount: amount, timestamp: Date()))

        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "drinkEntries")
        }

        let currentAmount = UserDefaults.standard.integer(forKey: "currentAmount")
        UserDefaults.standard.set(currentAmount + amount, forKey: "currentAmount")

        return .result()
    }

    private func getDrinkEntries() -> [DrinkEntry] {
        if let data = UserDefaults.standard.data(forKey: "drinkEntries"),
           let entries = try? JSONDecoder().decode([DrinkEntry].self, from: data) {
            return entries
        }
        return []
    }
}

struct DrinkAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddDrinkIntent(),
            phrases: [
                "Füge Wasser in \(.applicationName) hinzu",
                "Füge Wasser zu \(.applicationName) hinzu",
            ],
            shortTitle: "Wasser trinken",
            systemImageName: "drop.fill"
        )
    }
}
