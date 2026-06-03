import SwiftUI

/// The app entry point. Creates all three `ObservableObject` managers as
/// `@StateObject` instances and injects them into the SwiftUI environment so
/// that `ContentView` and its descendants can access them via
/// `@EnvironmentObject` (Requirements 14.1, 14.2, 14.3, 14.4).
@main
struct VibeSurveyorApp: App {

    @StateObject private var cameraManager   = CameraManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var motionManager   = MotionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraManager)
                .environmentObject(locationManager)
                .environmentObject(motionManager)
        }
    }
}
