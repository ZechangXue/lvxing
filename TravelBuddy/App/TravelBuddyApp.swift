import SwiftUI
import SwiftData

@main
struct TravelBuddyApp: App {
    private let container: ModelContainer = {
        let schema = Schema([
            Trip.self, TravelDay.self, ItineraryActivity.self,
            Meal.self, PhotoAsset.self, FavoritePlace.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do { return try ModelContainer(for: schema, configurations: [configuration]) }
        catch { fatalError("无法创建本地数据库：\(error.localizedDescription)") }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Pastel.peachStrong)
                .task { DemoSeeder.seedIfNeeded(in: container.mainContext) }
        }
        .modelContainer(container)
    }
}

