import SwiftUI
import SwiftData

struct CalendarView:View{
    @Query(sort:\Trip.startDate)private var trips:[Trip]
    @State private var month=Date.now;@State private var selected=Date.now.startOfDay
    private let calendar=Calendar.current
    var cells:[Date?]{
        guard let interval=calendar.dateInterval(of:.month,for:month),let range=calendar.range(of:.day,in:.month,for:month)else{return[]}
        let first=interval.start;let offset=(calendar.component(.weekday,from:first)+5)%7
        return Array(repeating:nil,count:offset)+range.map{calendar.date(byAdding:.day,value:$0-1,to:first)}
    }
    var selectedDay:TravelDay?{trips.flatMap(\.days).first{calendar.isDate($0.date,inSameDayAs:selected)}}
    func inTrip(_ date:Date)->Bool{trips.contains{date.startOfDay >= $0.startDate.startOfDay && date.startOfDay <= $0.endDate.startOfDay}}
    var body:some View{ScrollView{VStack(spacing:20){
        HStack{Button{change(-1)}label:{Image(systemName:"chevron.left")};Spacer();Text(month.formatted(.dateTime.year().month(.wide).locale(Locale(identifier:"zh_CN")))).font(.title2.bold()).foregroundStyle(Pastel.text);Spacer();Button{change(1)}label:{Image(systemName:"chevron.right")}}
        VStack(spacing:12){HStack{ForEach(["一","二","三","四","五","六","日"],id:\.self){Text($0).font(.caption.weight(.bold)).foregroundStyle(Pastel.secondary).frame(maxWidth:.infinity)}};LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:7),spacing:9){ForEach(Array(cells.enumerated()),id:\.offset){_,date in if let date{Button{selected=date.startOfDay}{ZStack{Circle().fill(calendar.isDate(date,inSameDayAs:selected) ? Pastel.peach : (inTrip(date) ? Pastel.yellow.opacity(0.55):.clear));Text("\(calendar.component(.day,from:date))").font(.subheadline.weight(calendar.isDate(date,inSameDayAs:selected) ? .bold:.regular)).foregroundStyle(Pastel.text);if let d=trips.flatMap(\.days).first(where:{calendar.isDate($0.date,inSameDayAs:date)}),!d.activities.isEmpty{Circle().fill(Pastel.peachStrong).frame(width:5,height:5).offset(y:16)}}.frame(height:42)}else{Color.clear.frame(height:42)}}}}.padding(16).pastelCard()
        VStack(alignment:.leading,spacing:12){SectionHeader(title:selected.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier:"zh_CN"))),subtitle:selectedDay.map{"D\($0.dayNumber)"});if let day=selectedDay{if day.activities.isEmpty{Text("这一天还没有安排").font(.subheadline).foregroundStyle(Pastel.secondary).padding()}else{ForEach(day.sortedActivities){a in NavigationLink{DayDetailView(day:day)}label:{ActivityCard(activity:a)}.buttonStyle(.plain)}}}else{EmptyStateView(image:"pigEmpty",title:"没有行程",message:"选择有颜色标记的日期查看安排。")}}
    }.padding(18)}.background(Pastel.background).navigationTitle("行程日历").navigationBarTitleDisplayMode(.inline)}
    }
    private func change(_ value:Int){month=calendar.date(byAdding:.month,value:value,to:month)!}
}

