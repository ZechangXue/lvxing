import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { TripListView() }.tabItem { Label("旅行",systemImage:"airplane") }
            NavigationStack { CalendarView() }.tabItem { Label("日历",systemImage:"calendar") }
            NavigationStack { FavoritesView() }.tabItem { Label("收藏",systemImage:"heart.fill") }
            NavigationStack { ProfileView() }.tabItem { Label("我的",systemImage:"person.crop.circle") }
        }
        .toolbarBackground(.white,for:.tabBar).toolbarBackground(.visible,for:.tabBar)
    }
}

