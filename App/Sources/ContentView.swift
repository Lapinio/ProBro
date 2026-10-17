import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("ProBro")
                .font(.largeTitle.bold())
            Text(Platform.current.greeting)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}

enum Platform {
    case iOS, macOS

    static var current: Platform {
        #if os(macOS)
        .macOS
        #else
        .iOS
        #endif
    }

    var greeting: String {
        switch self {
        case .iOS: "Hello from iOS"
        case .macOS: "Hello from macOS (App Sandbox)"
        }
    }
}

#Preview {
    ContentView()
}
