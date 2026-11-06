import XCTest
@testable import TravelBuddy

final class ItineraryFactoryTests:XCTestCase{
    func testCreatesInclusiveDateRange(){
        let calendar=Calendar(identifier:.gregorian)
        let start=calendar.date(from:DateComponents(year:2026,month:4,day:1))!
        let end=calendar.date(from:DateComponents(year:2026,month:4,day:8))!
        let trip=Trip(title:"测试",destination:"巴黎",startDate:start,endDate:end)
        ItineraryFactory.synchronizeDays(for:trip)
        XCTAssertEqual(trip.days.count,8);XCTAssertEqual(trip.sortedDays.first?.dayNumber,1);XCTAssertEqual(trip.sortedDays.last?.dayNumber,8)
    }
    func testPreservesExistingDay(){
        let start=Date.now.startOfDay;let trip=Trip(title:"测试",destination:"伦敦",startDate:start,endDate:Calendar.current.date(byAdding:.day,value:1,to:start)!)
        ItineraryFactory.synchronizeDays(for:trip);let first=trip.sortedDays[0];first.notes="保留"
        trip.endDate=Calendar.current.date(byAdding:.day,value:2,to:start)!;ItineraryFactory.synchronizeDays(for:trip,oldDays:trip.days)
        XCTAssertEqual(trip.sortedDays[0].notes,"保留");XCTAssertEqual(trip.days.count,3)
    }
    func testActivityPeriodSuggestionBoundaries(){
        let date=Date.now.startOfDay
        XCTAssertLessThan(Calendar.current.component(.hour,from:date.setting(hour:11,minute:59)),12)
        XCTAssertGreaterThanOrEqual(Calendar.current.component(.hour,from:date.setting(hour:18,minute:0)),18)
    }
}

