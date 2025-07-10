import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var dailyStatsManager: DailyStatsManager
    
    @Environment(\.presentationMode) var presentationMode
    
    var currentAmount: Int
    let targetAmount = UserDefaults.standard.integer(forKey: "targetAmount")
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    
    var fullList: [DailyWaterEntry] {
        dailyStatsManager.fullListWithTodayEntry()
    }
    
    var last7Days: [DailyWaterEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var map: [Date: Int] = [:]
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let day = calendar.startOfDay(for: date)
            let amount = fullList
                .first(where: { calendar.isDate($0.date, inSameDayAs: day) })?
                .amount ?? 0
            map[day] = amount
        }
        
        // Nach Datum sortieren (älteste zuerst)
        return map
            .map { DailyWaterEntry(date: $0.key, amount: $0.value) }
            .sorted(by: { $0.date < $1.date })
    }
    
    var body: some View {
        
        return NavigationView {
            VStack {
                // 📈 Diagramm
                Chart {
                    ForEach(last7Days) { entry in
                        // Linie (eine Farbe, z. B. grau)
                        LineMark(
                            x: .value("Datum", entry.date, unit: .day),
                            y: .value("Getrunken (ml)", entry.amount)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        // Punkt mit Farbe abhängig vom Ziel
                        PointMark(
                            x: .value("Datum", entry.date, unit: .day),
                            y: .value("Getrunken (ml)", entry.amount)
                        )
                        .foregroundStyle(entry.amount >= targetAmount ? .green : .red)
                        .symbol(Circle())
                    }

                    // Ziel-Linie
                    RuleMark(y: .value("Ziel", targetAmount))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.blue)
                        .annotation(position: .bottom, alignment: .leading) {
                            Text("Ziel: \(targetAmount) ml")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                }
                .chartYAxisLabel("ml")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 200)
                .padding(.top)
                
                // 📋 Liste darunter
                List(fullList) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            if entry.date.isToday {
                                Text(dateFormatter.string(from: entry.date))
                                    .font(.body) +
                                Text("    Heute")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text(dateFormatter.string(from: entry.date))
                                    .font(.body)
                                    .foregroundColor(entry.amount >= targetAmount ? .green : .red)
                                    .fontWeight(entry.amount >= targetAmount ? .bold : .regular)
                            }
                        }
                        
                        Spacer()
                        Text("\(entry.amount) ml")
                            .foregroundColor(.blue)
                            .bold()
                    }
                }
                .onAppear {
                    dailyStatsManager.reload()
                        }
            }
            .navigationBarTitle("Trinkverlauf", displayMode: .inline)
        }
    }
}
