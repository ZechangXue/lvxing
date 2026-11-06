import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var month = Date.now
    @State private var selected = Date.now.startOfDay
    private let calendar = Calendar.current
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = (calendar.component(.weekday, from: interval.start) + 5) % 7
        let dates = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }
        return Array(repeating: nil, count: offset) + dates.map(Optional.some)
    }

    private var allDays: [TravelDay] { trips.flatMap(\.days) }
    private var selectedDay: TravelDay? { allDays.first { calendar.isDate($0.date, inSameDayAs: selected) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                calendarCard
                selectedSchedule
            }
            .padding(18)
        }
        .background(Pastel.background)
        .navigationTitle("行程日历")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: "zh_CN"))))
                .font(.title2.bold()).foregroundStyle(Pastel.text)
            Spacer()
            Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 12) {
            HStack {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday).font(.caption.weight(.bold)).foregroundStyle(Pastel.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 9) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in dayCell(date) }
            }
        }
        .padding(16)
        .pastelCard()
    }

    @ViewBuilder private func dayCell(_ date: Date?) -> some View {
        if let date {
            let isSelected = calendar.isDate(date, inSameDayAs: selected)
            Button { selected = date.startOfDay } label: {
                ZStack {
                    Circle().fill(isSelected ? Pastel.peach : (isInsideTrip(date) ? Pastel.yellow.opacity(0.55) : Color.clear))
                    Text(String(calendar.component(.day, from: date)))
                        .font(.subheadline.weight(isSelected ? .bold : .regular)).foregroundStyle(Pastel.text)
                    if hasActivities(on: date) { Circle().fill(Pastel.peachStrong).frame(width: 5, height: 5).offset(y: 16) }
                }
                .frame(height: 42)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 42)
        }
    }

    @ViewBuilder private var selectedSchedule: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: selected.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN"))),
                subtitle: selectedDay.map { "D\($0.dayNumber)" }
            )
            if let day = selectedDay {
                if day.activities.isEmpty {
                    Text("这一天还没有安排").font(.subheadline).foregroundStyle(Pastel.secondary).padding()
                } else {
                    ForEach(day.sortedActivities) { activity in
                        NavigationLink { DayDetailView(day: day) } label: { ActivityCard(activity: activity) }
                            .buttonStyle(.plain)
                    }
                }
            } else {
                EmptyStateView(image: "pigEmpty", title: "没有行程", message: "选择有颜色标记的日期查看安排。")
            }
        }
    }

    private func isInsideTrip(_ date: Date) -> Bool {
        trips.contains { date.startOfDay >= $0.startDate.startOfDay && date.startOfDay <= $0.endDate.startOfDay }
    }

    private func hasActivities(on date: Date) -> Bool {
        allDays.first { calendar.isDate($0.date, inSameDayAs: date) }?.activities.isEmpty == false
    }

    private func changeMonth(_ value: Int) {
        month = calendar.date(byAdding: .month, value: value, to: month) ?? month
    }
}
