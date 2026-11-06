import SwiftUI
import UIKit

struct StoredOrAssetImage: View {
    let path: String?; let asset: String
    var body: some View {
        Group {
            if let image = ImageStore.image(named: path) { Image(uiImage:image).resizable() }
            else if asset == "generic" {
                ZStack {
                    LinearGradient(colors:[Pastel.blue.opacity(0.75),Pastel.mint.opacity(0.5),Pastel.yellow.opacity(0.65)],startPoint:.topLeading,endPoint:.bottomTrailing)
                    Image("pigMap").resizable().scaledToFit().padding(18)
                }
            } else { Image(asset).resizable() }
        }
    }
}

struct TravelCard: View {
    let trip: Trip
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            StoredOrAssetImage(path:trip.coverImagePath,asset:trip.coverAsset).scaledToFill().frame(height:142).clipped()
            HStack(alignment:.center,spacing:12) {
                VStack(alignment:.leading,spacing:5) {
                    Text(trip.title).font(.title3.bold()).foregroundStyle(Pastel.text)
                    Text("\(trip.startDate.formatted(.dateTime.month().day())) – \(trip.endDate.formatted(.dateTime.month().day())) · \(trip.dayCount)天")
                        .font(.subheadline).foregroundStyle(Pastel.secondary)
                    Label(trip.destination,systemImage:"mappin.and.ellipse").font(.caption).foregroundStyle(Pastel.peachStrong)
                    if let source=trip.coverAttributionName { Text("图片：\(source)").font(.caption2).foregroundStyle(Pastel.secondary) }
                }
                Spacer(); Image(systemName:"chevron.right").foregroundStyle(Pastel.secondary)
            }.padding(16)
        }.pastelCard()
    }
}

struct ActivityCard: View {
    let activity: ItineraryActivity; var onToggle: (() -> Void)? = nil
    var body: some View {
        HStack(alignment:.top,spacing:12) {
            if let onToggle { Button(action:onToggle) { Image(systemName:activity.isCompleted ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(activity.isCompleted ? Pastel.mint : Pastel.peachStrong) }.buttonStyle(.plain) }
            else { Image(systemName:activity.isCompleted ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(activity.isCompleted ? Pastel.mint : Pastel.peachStrong) }
            VStack(alignment:.leading,spacing:5) {
                Text("\(activity.startTime.formatted(date:.omitted,time:.shortened))–\(activity.endTime.formatted(date:.omitted,time:.shortened))").font(.caption.weight(.semibold)).foregroundStyle(Pastel.peachStrong)
                Text(activity.title).font(.headline).foregroundStyle(Pastel.text).strikethrough(activity.isCompleted)
                if !activity.locationName.isEmpty { Label(activity.locationName,systemImage:"mappin").font(.caption).foregroundStyle(Pastel.secondary) }
            }
            Spacer(); Image(systemName:activity.kind.icon).foregroundStyle(Pastel.text).frame(width:38,height:38).background(periodColor(activity.period).opacity(0.65)).clipShape(RoundedRectangle(cornerRadius:12))
        }.padding(14).pastelCard()
    }
    private func periodColor(_ value: ActivityPeriod) -> Color { switch value { case .morning:Pastel.yellow;case .afternoon:Pastel.blue;case .evening:Pastel.lavender;case .meal:Pastel.peach } }
}

struct MealCard: View {
    let meal: Meal
    var body: some View { HStack(spacing:12) { Image(systemName:meal.type.icon).foregroundStyle(Pastel.peachStrong).frame(width:44,height:44).background(Pastel.yellow.opacity(0.45)).clipShape(Circle()); VStack(alignment:.leading,spacing:4) { HStack { Text(meal.type.rawValue).font(.caption.weight(.bold)).foregroundStyle(Pastel.peachStrong); Text(meal.plannedTime.formatted(date:.omitted,time:.shortened)).font(.caption).foregroundStyle(Pastel.secondary) }; Text(meal.restaurantName).font(.headline).foregroundStyle(Pastel.text); if !meal.cuisine.isEmpty { Text(meal.cuisine).font(.caption).foregroundStyle(Pastel.secondary) } }; Spacer(); Image(systemName:"chevron.right").foregroundStyle(Pastel.secondary) }.padding(14).pastelCard() }
}

