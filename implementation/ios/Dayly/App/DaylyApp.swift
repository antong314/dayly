import SwiftUI

@main
struct DaylyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// Temporary ContentView - will be replaced in later phases
struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "camera.circle.fill")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 80))
                    .padding()
                
                Text("Dayly")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Share one photo per day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
