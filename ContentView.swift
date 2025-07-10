import SwiftUI
import UIKit
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: "notificationPermissions")
                if granted {
                    self.scheduleDailyNotifications(notificationPermissions: true)
                }
                completion(granted)
            }
        }
    }


    func scheduleDailyNotifications(notificationPermissions: Bool) {
        guard notificationPermissions else { return }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let notificationTimes = [
            (hour: 12, minute: 0, fraction: 0.25),
            (hour: 16, minute: 0, fraction: 0.5),
            (hour: 20, minute: 0, fraction: 0.75)
        ]
        
        let currentAmount = UserDefaults.standard.integer(forKey: "currentAmount")
        let targetAmount = UserDefaults.standard.integer(forKey: "targetAmount")
        let todo = targetAmount-currentAmount
        
        for time in notificationTimes {
            let requiredAmount = Double(targetAmount) * time.fraction
            if Double(currentAmount) >= requiredAmount {
                continue // überspringe diese Benachrichtigung
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Wasser trinken"
            let messages = [
                "Zeit für ein Glas Wasser 💧",
                "Schon genug getrunken heute?",
                "Trinkpause! 🚰"
            ]
            let messagesNight = [
                "Nur noch " + String(todo) + "ml bis zum Tagesziel - du schaffst das!",
                "Fast geschafft! Gönn dir die letzten " + String(todo) + "ml für heute",
                "Ein kleiner Schluck für dich, ein großer Schritt für dein Wohlbefinden - noch " + String(todo) + "ml"
            ]
            content.body = messages.randomElement() ?? "Denk daran, genug zu trinken!"
            content.sound = UNNotificationSound.default

            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            if (time.hour == 20) {
                content.body = messagesNight.randomElement() ?? "Endspurt! Du musst noch " + String(todo) + "ml trinken"
            }
            let request = UNNotificationRequest(identifier: "water-\(time.hour)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Fehler beim Planen der Benachrichtigung: \(error.localizedDescription)")
                } else {
                    print("Benachrichtigung geplant für \(time.hour):\(time.minute).")
                }
            }
        }
    }
}

struct ContentView: View {
    @AppStorage("notificationPermissions") private var notificationPermissions = false
    
    @StateObject var dailyStatsManager = DailyStatsManager()
    @StateObject private var drinkManager = DrinkManager.shared
    
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var showShare = false
    
    @State private var editingEntryID: UUID? = nil
    
    @State private var activeSheet: ActiveSheet? = nil
    
    @State private var selectedEntry: DrinkEntry?
    @State private var editedTimestamp: Date = Date()
    @State private var showingTimeEditor = false
    
    @State private var shareImage: UIImage?
    @State private var isSharing = false
    @State private var shareTargetID = UUID() // Zum Triggern des Screenshots

    
    @Environment(\.scenePhase) private var scenePhase

    enum ActiveSheet: Identifiable {
        case settings, history, editTime, share

        var id: Int {
            hashValue
        }
    }
    
    // 💡 Reversed nur einmal berechnet
    var reversedDrinkEntries: [DrinkEntry] {
        drinkManager.drinkEntries.reversed()
    }

    // 💡 Fortschritt sauber berechnet
    var progress: Double {
        Double(drinkManager.currentAmount) / Double(drinkManager.targetAmount)
    }

    // 💡 Kumulierte Schritte ausgelagert
    var cumulativeSteps: [(value: Int, time: Date)] {
        var total = 0
        return drinkManager.drinkEntries.map { entry in
            total += entry.amount
            return (value: total, time: entry.timestamp)
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                WaterGlassView(
                    progress: progress,
                    steps: reversedDrinkEntries,
                    cumulativeSteps: cumulativeSteps,
                    targetAmount: drinkManager.targetAmount,
                    currentAmount: drinkManager.currentAmount
                )
                
                DiscreteAmountPickerView()
                
                List {
                    ForEach(reversedDrinkEntries) { entry in
                        HStack {
                            Text("\(entry.amount) ml")
                            Spacer()

                            if editingEntryID == entry.id {
                                HStack {
                                    Button(action: {
                                        editingEntryID = nil
                                    }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { entry.timestamp },
                                            set: { newDate in
                                                drinkManager.updateDrinkEntry(id: entry.id, newTimestamp: newDate)
                                            }
                                        ),
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .fixedSize()
                                }
                            } else {
                                Text(formatTime(entry.timestamp))
                                    .foregroundColor(.blue)
                                    .font(.subheadline)
                                    .onTapGesture {
                                        withAnimation {
                                            editingEntryID = entry.id
                                        }
                                    }
                            }
                        }
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                drinkManager.deleteDrink(entry: entry)
                                if editingEntryID == entry.id {
                                    editingEntryID = nil
                                }
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
            .frame(maxWidth: 600)
            .padding()
            .navigationBarTitle("Trinkmenge", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { activeSheet = .history }) {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { activeSheet = .settings }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { activeSheet = .share }) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }

                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    drinkManager.resetIfNeeded()
                }
            }

            .sheet(item: $activeSheet) { item in
                switch item {
                case .share:
                    let message = "Ich habe heute schon \(drinkManager.currentAmount) ml Wasser getrunken! 💧"
                    ActivityView(activityItems: [message])
                case .settings:
                    SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .history:
                    HistoryView(dailyStatsManager: dailyStatsManager, currentAmount: drinkManager.currentAmount)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                case .editTime:
                    NavigationView {
                        VStack {
                            DatePicker("Uhrzeit ändern", selection: $editedTimestamp, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .padding()

                            Spacer()
                        }
                        .navigationTitle("Eintrag bearbeiten")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") {
                                    if let entry = selectedEntry {
                                        drinkManager.updateDrinkEntry(id: entry.id, newTimestamp: editedTimestamp)
                                    }
                                    activeSheet = nil
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Abbrechen") {
                                    activeSheet = nil
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                drinkManager.resetIfNeeded()
                NotificationManager.shared.requestAuthorization { granted in
                    notificationPermissions = granted
                }
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DiscreteAmountPickerView: View {
    let possibleAmounts = [50, 100, 150, 200, 250, 300, 330, 400, 500]
    @State private var selectedIndex = 4 // z. B. Start bei 200ml
    
    @StateObject private var drinkManager = DrinkManager.shared

    var body: some View {
        VStack() {

            // Horizontale Picker-Leiste
            Picker("Menge", selection: $selectedIndex) {
                ForEach(0..<possibleAmounts.count, id: \.self) { index in
                    Text("\(possibleAmounts[index]) ml")
                        .tag(index)
                }
            }
            .pickerStyle(.wheel) // auch: .segmented oder .menu
            .frame(height: 120)
            .clipped()
            .onChange(of: selectedIndex, initial: false) { _, newValue in
                let generator = UISelectionFeedbackGenerator()
                generator.prepare()
                generator.selectionChanged()
            }

            Button(action: {
                let amount = possibleAmounts[selectedIndex]
                drinkManager.addDrink(amount: amount)
            }) {
                Text("Hinzufügen")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
}

struct GlassShape: Shape {
    var progress: CGFloat // 0.0 bis 1.0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let inset: CGFloat = rect.width * 0.2

        let bottomLeft = CGPoint(x: rect.minX + inset, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX - inset, y: rect.maxY)
        let topRight = CGPoint(x: rect.maxX, y: rect.maxY - rect.height * progress)
        let topLeft = CGPoint(x: rect.minX, y: rect.maxY - rect.height * progress)

        path.move(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.addLine(to: topRight)
        path.addLine(to: topLeft)
        path.closeSubpath()

        return path
    }

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
}


struct WaterGlassView: View {
    var progress: Double
    var steps: [DrinkEntry]
    var cumulativeSteps: [(value: Int, time: Date)]
    var targetAmount: Int
    var currentAmount: Int

    @State private var reachedGoal = false
    @State private var animateGoal = false
    
    let glassWidth: CGFloat = 200
    let glassHeight: CGFloat = 280

    var body: some View {
        let displayTarget = CGFloat(targetAmount) * 1.2
        let progress = CGFloat(currentAmount) / displayTarget
        
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currentAmount) ml")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .offset(y: 30 + glassHeight * (1 - CGFloat(min(progress, 1.0))))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
                Spacer()
            }
            .padding(.leading, 8)
            .frame(maxWidth: .infinity)

            Text("Ziel: \(targetAmount) ml")
                .font(.caption)
                .fontWeight(reachedGoal ? .bold : .regular)
                .foregroundColor(reachedGoal ? .green : .gray)
                .scaleEffect(animateGoal ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: animateGoal)
                .onChange(of: currentAmount) {
                    if currentAmount >= targetAmount && !reachedGoal {
                        reachedGoal = true
                        animateGoal = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            animateGoal = false
                        }
                    } else if currentAmount < targetAmount && reachedGoal {
                        reachedGoal = false
                    }
                }

            ZStack(alignment: .bottom) {
                GlassShape(progress: 1.0)
                    .stroke(lineWidth: 4)
                    .frame(width: glassWidth, height: glassHeight)
                    .foregroundColor(.blue)

                GlassShape(progress: 1.0)
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: glassWidth, height: glassHeight)
                    .mask(
                        GlassShape(progress: min(progress, 1.0))
                            .frame(width: glassWidth, height: glassHeight)
                    )
                    .animation(.easeInOut(duration: 0.5), value: progress)

                ForEach(cumulativeSteps, id: \.value) { step in
                    let relativeHeight = CGFloat(step.value) / displayTarget
                    if relativeHeight <= 1.0 {
                        ZStack {
                            Capsule()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: glassWidth * 0.4, height: 2)
                                .offset(y: 5)
                            
                            Text(formatTime(step.time))
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .offset(x: glassWidth / 2 + 25, y: 5)
                        }
                        .offset(y: -glassHeight * relativeHeight + 1)
                    }
                }
            }
            // Zielmarkierung (grüner Strich)
            let goalRelativeHeight = CGFloat(targetAmount) / displayTarget

            Capsule()
                .fill(Color.green.opacity(reachedGoal ? 0.8 : 0.5))
                .frame(width: glassWidth * 0.6, height: 3)
                .scaleEffect(animateGoal ? 1.5 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: animateGoal)
                .offset(y: -glassHeight * goalRelativeHeight - 8)

        }
        .frame(maxWidth: .infinity)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}


struct DrinkEntry: Codable, Identifiable {
    let id: UUID
    let amount: Int
    let timestamp: Date

    init(id: UUID = UUID(), amount: Int, timestamp: Date) {
        self.id = id
        self.amount = amount
        self.timestamp = timestamp
    }
}


struct DailyWaterEntry: Codable, Identifiable, CustomStringConvertible {
    var id: UUID = UUID()
    var date: Date
    var amount: Int
    
    public var description: String { return "\(date) - \(amount)" }
}


extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
