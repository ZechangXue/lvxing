import SwiftUI

struct RootView: View {
    var body: some View {
        #if IPAD_EDITION
        IPadRootView()
        #else
        TabView {
            NavigationStack { TripListView() }.tabItem { Label("旅行",systemImage:"airplane") }
            NavigationStack { CalendarView() }.tabItem { Label("日历",systemImage:"calendar") }
            NavigationStack { FavoritesView() }.tabItem { Label("收藏",systemImage:"heart.fill") }
            NavigationStack { ProfileView() }.tabItem { Label("我的",systemImage:"person.crop.circle") }
        }
        .toolbarBackground(.white,for:.tabBar).toolbarBackground(.visible,for:.tabBar)
        #endif
    }
}

#if IPAD_EDITION
private enum IPadSection: String, CaseIterable, Identifiable {
    case trips = "我的旅行", calendar = "行程日历", favorites = "我的收藏", profile = "设置"
    var id: String { rawValue }
    var icon: String {
        switch self { case .trips: "airplane"; case .calendar: "calendar"; case .favorites: "heart.fill"; case .profile: "person.crop.circle" }
    }
}

private struct IPadRootView: View {
    @State private var selection: IPadSection? = .trips
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image("pigMap").resizable().scaledToFit().frame(height: 118)
                    Text("TravelBuddy").font(.title2.bold()).foregroundStyle(Pastel.text)
                    Text("小新新的旅行手账").font(.caption).foregroundStyle(Pastel.secondary)
                }.padding(.vertical, 26)
                List(IPadSection.allCases, selection: $selection) { section in
                    Label(section.rawValue, systemImage: section.icon).tag(section)
                        .font(.headline).padding(.vertical, 7)
                }.scrollContentBackground(.hidden)
            }
            .background(Pastel.background)
            .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 320)
        } detail: {
            NavigationStack {
                switch selection ?? .trips {
                case .trips: TripListView()
                case .calendar: CalendarView()
                case .favorites: FavoritesView()
                case .profile: ProfileView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
#endif

