import SwiftUI

@main
struct JarvisIOSApp: App {
  var body: some Scene {
    WindowGroup {
      MissionControlView(viewModel: AppEnvironment.makeRootViewModel())
    }
  }
}
