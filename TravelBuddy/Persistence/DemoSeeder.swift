import Foundation
import SwiftData

enum ItineraryFactory {
    static func synchronizeDays(for trip: Trip, oldDays: [TravelDay] = []) {
        let calendar = Calendar.current
        let start = trip.startDate.startOfDay, end = trip.endDate.startOfDay
        guard start <= end else { return }
        let existing = Dictionary(uniqueKeysWithValues: oldDays.map { ($0.date.startOfDay, $0) })
        var result: [TravelDay] = []
        var date = start, index = 1
        while date <= end {
            let day = existing[date] ?? TravelDay(date: date, dayNumber: index)
            day.date = date; day.dayNumber = index; day.trip = trip; result.append(day)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
            index += 1
        }
        trip.days = result
    }
}

enum DemoSeeder {
    @MainActor static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Trip>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }
        let calendar = Calendar(identifier: .gregorian)
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
        let paris = Trip(title: "法国浪漫之旅", destination: "法国 · 巴黎", startDate: date(2026,4,1), endDate: date(2026,4,8), tripDescription: "在花香与塞纳河的晚风里，慢慢认识巴黎。", companions: "小新新", coverAsset: "coverParis")
        ItineraryFactory.synchronizeDays(for: paris)
        if let d3 = paris.sortedDays.dropFirst(2).first {
            d3.title = "埃菲尔铁塔与塞纳河"
            let items: [(String,Int,Int,Int,Int,ActivityPeriod,ActivityKind,String,Double,Double)] = [
                ("埃菲尔铁塔",8,30,11,30,.morning,.sightseeing,"Champ de Mars",48.8584,2.2945),
                ("Le Jules Verne 午餐",12,0,13,30,.meal,.food,"埃菲尔铁塔二层",48.8583,2.2945),
                ("塞纳河游船",14,0,16,30,.afternoon,.sightseeing,"Port de la Bourdonnais",48.8601,2.2930),
                ("法式小酒馆晚餐",18,30,20,0,.evening,.food,"Saint-Germain",48.8539,2.3335)
            ]
            for (i, item) in items.enumerated() {
                let activity = ItineraryActivity(title: item.0, startTime: d3.date.setting(hour:item.1,minute:item.2), endTime:d3.date.setting(hour:item.3,minute:item.4), period:item.5, kind:item.6, locationName:item.7, orderIndex:i)
                activity.latitude = item.8; activity.longitude = item.9; activity.day = d3; d3.activities.append(activity)
            }
            let meal = Meal(type:.lunch, restaurantName:"Le Jules Verne", plannedTime:d3.date.setting(hour:12,minute:0)); meal.cuisine="法餐"; meal.locationName="埃菲尔铁塔"; meal.day=d3; d3.meals.append(meal)
        }
        let japan = Trip(title: "日本关西之旅", destination: "日本 · 京都 / 大阪", startDate: date(2026,3,20), endDate: date(2026,3,28), tripDescription: "追一场樱花，也尝一碗热腾腾的拉面。", coverAsset: "coverKyoto")
        ItineraryFactory.synchronizeDays(for: japan)
        let italy = Trip(title: "意大利海岸之旅", destination: "意大利 · 阿马尔菲", startDate: date(2026,5,1), endDate: date(2026,5,10), tripDescription: "柠檬、海风和山城的暖阳。", coverAsset: "coverItaly")
        ItineraryFactory.synchronizeDays(for: italy)
        context.insert(paris); context.insert(japan); context.insert(italy)
        context.insert(FavoritePlace(name:"蒙马特高地",category:"景点",city:"巴黎",notes:"适合日落前去散步"))
        try? context.save()
    }
}

