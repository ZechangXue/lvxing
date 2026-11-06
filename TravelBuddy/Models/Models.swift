import Foundation
import SwiftData
import CoreLocation

enum ActivityPeriod: String, Codable, CaseIterable, Identifiable {
    case morning = "上午", afternoon = "下午", evening = "晚上", meal = "饮食"
    var id: String { rawValue }
    var icon: String {
        switch self { case .morning: "sun.max.fill"; case .afternoon: "sun.haze.fill"; case .evening: "moon.stars.fill"; case .meal: "fork.knife" }
    }
}

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case sightseeing = "景点", transport = "交通", hotel = "住宿", food = "餐饮", shopping = "购物", other = "其他"
    var id: String { rawValue }
    var icon: String {
        switch self { case .sightseeing: "camera.fill"; case .transport: "tram.fill"; case .hotel: "bed.double.fill"; case .food: "fork.knife"; case .shopping: "bag.fill"; case .other: "sparkles" }
    }
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "早餐", lunch = "午餐", dinner = "晚餐", snack = "加餐"
    var id: String { rawValue }
    var icon: String { self == .breakfast ? "cup.and.saucer.fill" : "fork.knife" }
}

@Model
final class Trip {
    var id: UUID = UUID()
    var title: String = ""
    var destination: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    var tripDescription: String = ""
    var companions: String = ""
    var themeHex: String = "#FFBE98"
    var coverAsset: String = "generic"
    var coverImagePath: String?
    var coverAttributionName: String?
    var coverAttributionURL: String?
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade) var days: [TravelDay] = []

    init(title: String, destination: String, startDate: Date, endDate: Date, tripDescription: String = "", companions: String = "", themeHex: String = "#FFBE98", coverAsset: String = "generic") {
        self.title = title; self.destination = destination; self.startDate = startDate; self.endDate = endDate
        self.tripDescription = tripDescription; self.companions = companions; self.themeHex = themeHex; self.coverAsset = coverAsset
    }

    var dayCount: Int { max(1, Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day! + 1) }
    var sortedDays: [TravelDay] { days.sorted { $0.date < $1.date } }
}

@Model
final class TravelDay {
    var id: UUID = UUID()
    var date: Date = Date.now
    var dayNumber: Int = 1
    var title: String = ""
    var notes: String = ""
    var coverImagePath: String?
    var trip: Trip?
    @Relationship(deleteRule: .cascade) var activities: [ItineraryActivity] = []
    @Relationship(deleteRule: .cascade) var meals: [Meal] = []

    init(date: Date, dayNumber: Int, title: String = "") { self.date = date; self.dayNumber = dayNumber; self.title = title }
    var sortedActivities: [ItineraryActivity] { activities.sorted { $0.orderIndex == $1.orderIndex ? $0.startTime < $1.startTime : $0.orderIndex < $1.orderIndex } }
}

@Model
final class ItineraryActivity {
    var id: UUID = UUID()
    var title: String = ""
    var startTime: Date = Date.now
    var endTime: Date = Date.now
    var periodRaw: String = ActivityPeriod.morning.rawValue
    var kindRaw: String = ActivityKind.sightseeing.rawValue
    var locationName: String = ""
    var address: String = ""
    var activityDescription: String = ""
    var notes: String = ""
    var website: String = ""
    var bookingReference: String = ""
    var estimatedCost: Double = 0
    var latitude: Double?
    var longitude: Double?
    var isCompleted: Bool = false
    var orderIndex: Int = 0
    var day: TravelDay?

    init(title: String, startTime: Date, endTime: Date, period: ActivityPeriod, kind: ActivityKind = .sightseeing, locationName: String = "", orderIndex: Int = 0) {
        self.title = title; self.startTime = startTime; self.endTime = endTime; self.periodRaw = period.rawValue
        self.kindRaw = kind.rawValue; self.locationName = locationName; self.orderIndex = orderIndex
    }
    var period: ActivityPeriod { get { ActivityPeriod(rawValue: periodRaw) ?? .morning } set { periodRaw = newValue.rawValue } }
    var kind: ActivityKind { get { ActivityKind(rawValue: kindRaw) ?? .other } set { kindRaw = newValue.rawValue } }
    var coordinate: CLLocationCoordinate2D? { guard let latitude, let longitude else { return nil }; return .init(latitude: latitude, longitude: longitude) }
}

@Model
final class Meal {
    var id: UUID = UUID()
    var typeRaw: String = MealType.lunch.rawValue
    var restaurantName: String = ""
    var cuisine: String = ""
    var locationName: String = ""
    var plannedTime: Date = Date.now
    var notes: String = ""
    var reservationDetails: String = ""
    var estimatedCost: Double = 0
    var website: String = ""
    var day: TravelDay?
    init(type: MealType, restaurantName: String, plannedTime: Date) { self.typeRaw = type.rawValue; self.restaurantName = restaurantName; self.plannedTime = plannedTime }
    var type: MealType { get { MealType(rawValue: typeRaw) ?? .lunch } set { typeRaw = newValue.rawValue } }
}

@Model
final class PhotoAsset {
    var id: UUID = UUID()
    var localPath: String?
    var remoteURL: String?
    var thumbnailURL: String?
    var attributionName: String?
    var attributionURL: String?
    var tripID: UUID?
    var dayID: UUID?
    var activityID: UUID?
    var createdAt: Date = Date.now
    init(localPath: String? = nil, remoteURL: String? = nil, thumbnailURL: String? = nil, attributionName: String? = nil, attributionURL: String? = nil, tripID: UUID? = nil) {
        self.localPath = localPath; self.remoteURL = remoteURL; self.thumbnailURL = thumbnailURL; self.attributionName = attributionName; self.attributionURL = attributionURL; self.tripID = tripID
    }
}

@Model
final class FavoritePlace {
    var id: UUID = UUID()
    var name: String = ""
    var category: String = "景点"
    var city: String = ""
    var notes: String = ""
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date = Date.now
    init(name: String, category: String, city: String, notes: String = "") { self.name = name; self.category = category; self.city = city; self.notes = notes }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    func setting(hour: Int, minute: Int) -> Date { Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: self) ?? self }
    var chineseWeekday: String { formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "zh_CN"))) }
}

