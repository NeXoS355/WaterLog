import SwiftUI

struct SettingsView: View {
    @AppStorage("targetAmount") private var targetAmount = 2000
    @AppStorage("notificationPermissions") private var notificationPermissions = false
    @AppStorage("healthKitSyncEnabled") private var healthKitSyncEnabled = true
    
    @State private var originalNotificationPermissions: Bool = true
    @State private var originalHealthKitSyncEnabled: Bool = true
    @State private var originalTargetAmount: Int = 2000

    @Environment(\.presentationMode) var presentationMode
    
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: $notificationPermissions) {
                    Text("Benachrichtigungen")
                }.padding(.horizontal)
                
                Toggle(isOn: $healthKitSyncEnabled) {
                    Text("Mit Health-App synchronisieren")
                }
                .padding(.horizontal)
                
                
                Stepper(value: $targetAmount, in: 500...5000, step: 100) {
                    Text("Zielmenge: \(targetAmount) ml")
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Dynamisch ausgelesene Version
                Text("Version " + version)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                
            }
            .navigationBarTitle("Einstellungen", displayMode: .inline)
            .onAppear {
                        // Ursprungswerte merken
                        originalNotificationPermissions = notificationPermissions
                        originalHealthKitSyncEnabled = healthKitSyncEnabled
                        originalTargetAmount = targetAmount
                    }
            .onDisappear {
                let changed =
                                originalNotificationPermissions != notificationPermissions ||
                                originalHealthKitSyncEnabled != healthKitSyncEnabled ||
                                originalTargetAmount != targetAmount
                
                if changed {
                    if notificationPermissions {
                        NotificationManager.shared.requestAuthorization { granted in
                            notificationPermissions = granted
                        }
                    }
                } else {
                    print("Keine Änderungen.")
                }
                
            }
        }
    }
}
