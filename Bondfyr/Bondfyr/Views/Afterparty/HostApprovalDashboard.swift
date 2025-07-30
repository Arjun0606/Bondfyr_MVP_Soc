import SwiftUI
import CoreLocation

/// SIMPLE HOST APPROVAL DASHBOARD - Replaces old complex version
struct HostApprovalDashboard: View {
    let party: Afterparty
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Guest Management")
                    .font(.title)
                    .padding()
                
                Text("This is the new simplified dashboard")
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Guest Management")
            .navigationBarItems(
                trailing: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
