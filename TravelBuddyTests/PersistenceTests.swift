import XCTest
import SwiftData
@testable import TravelBuddy

@MainActor
final class PersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Trip.self, TravelDay.self, ItineraryActivity.self, Meal.self, PhotoAsset.self, FavoritePlace.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    func testActivityEditAndDeletion() throws {
        let container = try makeContainer(), context = container.mainContext
        let day = TravelDay(date: .now, dayNumber: 1)
        let activity = ItineraryActivity(title: "旧名称", startTime: .now, endTime: .now.addingTimeInterval(3600), period: .morning)
        activity.day = day; day.activities.append(activity); context.insert(day); try context.save()
        activity.title = "新名称"; try context.save()
        XCTAssertEqual(day.activities.first?.title, "新名称")
        day.activities.removeAll { $0.id == activity.id }; context.delete(activity); try context.save()
        XCTAssertTrue(day.activities.isEmpty)
    }

    func testMealPersistence() throws {
        let container = try makeContainer(), context = container.mainContext
        let day = TravelDay(date: .now, dayNumber: 1)
        let meal = Meal(type: .dinner, restaurantName: "小酒馆", plannedTime: .now)
        meal.day = day; day.meals.append(meal); context.insert(day); try context.save()
        let fetched = try context.fetch(FetchDescriptor<Meal>())
        XCTAssertEqual(fetched.first?.restaurantName, "小酒馆")
        XCTAssertEqual(fetched.first?.type, .dinner)
    }

    func testPhotoMetadataAndOfflineTripRetrieval() throws {
        let container = try makeContainer(), context = container.mainContext
        let trip = Trip(title: "离线旅行", destination: "京都", startDate: .now, endDate: .now)
        let photo = PhotoAsset(localPath: "sample.jpg", attributionName: "作者", tripID: trip.id)
        context.insert(trip); context.insert(photo); try context.save()
        let trips = try context.fetch(FetchDescriptor<Trip>())
        let photos = try context.fetch(FetchDescriptor<PhotoAsset>())
        XCTAssertEqual(trips.first?.title, "离线旅行")
        XCTAssertEqual(photos.first?.localPath, "sample.jpg")
        XCTAssertEqual(photos.first?.tripID, trip.id)
    }
}
