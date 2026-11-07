import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort:\Trip.startDate) private var trips:[Trip]
    @State private var showingEditor=false
    @State private var filter=0
    @State private var deleting:Trip?
    var filtered:[Trip] { let today=Date.now.startOfDay;return trips.filter { filter == 0 || (filter == 1 ? $0.startDate.startOfDay >= today : $0.endDate.startOfDay < today) } }
    var body: some View {
        ZStack(alignment:.bottomTrailing) {
            Pastel.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment:.leading,spacing:18) {
                    HStack { VStack(alignment:.leading,spacing:2) { Text("我的旅行").font(.largeTitle.bold()).foregroundStyle(Pastel.text); Text("和小新新一起，把期待装进行李箱").font(.subheadline).foregroundStyle(Pastel.secondary) }; Spacer(); Image("pigMap").resizable().scaledToFit().frame(width:76,height:76) }
                    TripFilterBar(selection:$filter)
                    if filtered.isEmpty { EmptyStateView(title:"还没有旅行",message:"先选一个想去的地方，小新新会陪你慢慢计划。",buttonTitle:"创建旅行",action:{showingEditor=true}) }
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:320,maximum:480),spacing:18)],spacing:18) {
                        ForEach(filtered) { trip in NavigationLink { TripOverviewView(trip:trip) } label:{ TravelCard(trip:trip) }.buttonStyle(.plain).contextMenu { Button(role:.destructive) { deleting=trip } label:{ Label("删除",systemImage:"trash") } } }
                    }
                }.frame(maxWidth:1180).frame(maxWidth:.infinity).padding(18).padding(.bottom,70)
            }
            RoundedIconButton(icon:"plus",color:Pastel.yellow) { showingEditor=true }.padding(22)
        }.toolbar(.hidden,for:.navigationBar).sheet(isPresented:$showingEditor) { NavigationStack { TripEditorView() } }.confirmationDialog("要删除“\(deleting?.title ?? "这趟旅行")”吗？",isPresented:Binding(get:{deleting != nil},set:{if !$0{deleting=nil}}),titleVisibility:.visible){Button("删除旅行",role:.destructive){if let deleting{context.delete(deleting);try? context.save()};deleting=nil};Button("取消",role:.cancel){deleting=nil}}message:{Text("相关日程、餐食和本地记录也会被删除，此操作无法撤销。")}
    }
}

private struct TripFilterBar:View{
    @Binding var selection:Int
    private let titles=["全部","待出发","回忆"]
    var body:some View{HStack(spacing:0){ForEach(titles.indices,id:\.self){index in Button{selection=index}label:{Text(titles[index]).font(.subheadline.weight(.semibold)).foregroundStyle(Pastel.text).frame(maxWidth:.infinity).padding(.vertical,10).background(selection==index ? Color.white:Color.clear).clipShape(RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain)}}.padding(3).background(Pastel.secondary.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius:14)).contentShape(Rectangle()).zIndex(2)}
}

struct TripEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var trip: Trip? = nil
    @State private var title = ""
    @State private var destination = ""
    @State private var start = Date.now
    @State private var end = Calendar.current.date(byAdding:.day,value:2,to:.now)!
    @State private var details = ""
    @State private var companions = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showingCoverSearch = false
    @State private var coverAttributionName: String?
    @State private var coverAttributionURL: String?
    @State private var isGenerating = false
    @State private var generationMessage: String?
    @State private var showingDateRangePicker = false

    var body: some View {
        Form {
            Section {
                TextField("例如：冰岛极光之旅",text:$title)
                TextField("任意目的地，例如：雷克雅未克",text:$destination)
                Button { showingDateRangePicker=true } label: {
                    HStack {
                        VStack(alignment:.leading,spacing:4){Text("出发").font(.caption).foregroundStyle(.secondary);Text(start.formatted(.dateTime.year().month().day())).foregroundStyle(Pastel.text)}
                        Spacer();Image(systemName:"arrow.right").foregroundStyle(Pastel.peachStrong);Spacer()
                        VStack(alignment:.trailing,spacing:4){Text("结束").font(.caption).foregroundStyle(.secondary);Text(end.formatted(.dateTime.year().month().day())).foregroundStyle(Pastel.text)}
                    }
                }.buttonStyle(.plain)
            } header: { Text("基本信息") }
            Section {
                ZStack {
                    coverPreview.frame(height:170).frame(maxWidth:.infinity)
                    if isGenerating {
                        Rectangle().fill(.black.opacity(0.36))
                        VStack(spacing:10){ProgressView().tint(.white).scaleEffect(1.2);Text("正在为“\(destination)”生成小新新旅行封面…").font(.subheadline.weight(.semibold)).foregroundStyle(.white).multilineTextAlignment(.center)}.padding()
                    }
                }.frame(height:170).clipShape(RoundedRectangle(cornerRadius:18)).listRowInsets(EdgeInsets())
                if SecureStore.openAIKey() != nil {
                    Button { Task { await generateCover() } } label: { Label("用 OpenAI 重新生成同款封面",systemImage:"wand.and.stars") }
                        .disabled(destination.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || isGenerating)
                } else {
                    Label("在“我的”中配置 OpenAI API Key 后可自动生成",systemImage:"key").font(.caption).foregroundStyle(Pastel.secondary)
                }
                Button { showingCoverSearch=true } label: { Label("搜索“\(destination.isEmpty ? "目的地" : destination)”的代表图片",systemImage:"globe.asia.australia.fill") }
                    .disabled(destination.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || isGenerating)
                PhotosPicker(selection:$pickerItem,matching:.images) { Label("从手机照片图库选择",systemImage:"photo.on.rectangle") }
                if let coverAttributionName { Text("图片来源：\(coverAttributionName)").font(.caption).foregroundStyle(Pastel.secondary) }
                if let generationMessage { Text(generationMessage).font(.caption).foregroundStyle(Pastel.secondary) }
            } header: { Text("旅行封面") } footer: { Text("有 OpenAI API Key 时，新建旅程会优先自动生成；不可用时直接使用默认封面。生成结果保存到本机，离线也能显示。") }
            Section {
                TextField("同行人（可选）",text:$companions)
                TextField("写下这趟旅行的期待…",text:$details,axis:.vertical).lineLimit(3...6)
            } header: { Text("让旅行更特别") }
        }
        .scrollContentBackground(.hidden).background(Pastel.background)
        .navigationTitle(trip == nil ? "新建旅行" : "编辑旅行").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("取消") { dismiss() }.disabled(isGenerating) }
            ToolbarItem(placement:.confirmationAction) { Button { Task { await save() } } label: { if isGenerating { ProgressView() } else { Text("保存") } }.disabled(title.trimmingCharacters(in:.whitespaces).isEmpty || destination.isEmpty || end < start || isGenerating) }
        }
        .task(id:pickerItem) {
            if let data=try? await pickerItem?.loadTransferable(type:Data.self) { imageData=data;coverAttributionName=nil;coverAttributionURL=nil }
        }
        .sheet(isPresented:$showingCoverSearch) {
            NavigationStack {
                DestinationCoverPicker(initialQuery:destination) { data,photo in
                    imageData=data;coverAttributionName=photo.attributionName;coverAttributionURL=photo.attributionURL.absoluteString
                }
            }
        }
        .sheet(isPresented:$showingDateRangePicker) {
            NavigationStack { TripDateRangePicker(start:$start,end:$end) }
                .presentationDetents([.large])
        }
        .onAppear {
            if let trip {
                title=trip.title;destination=trip.destination;start=trip.startDate;end=trip.endDate
                details=trip.tripDescription;companions=trip.companions
                coverAttributionName=trip.coverAttributionName;coverAttributionURL=trip.coverAttributionURL
            }
        }
    }

    @ViewBuilder private var coverPreview: some View {
        if let imageData,let image=UIImage(data:imageData) { Image(uiImage:image).resizable().scaledToFill() }
        else if let trip { StoredOrAssetImage(path:trip.coverImagePath,asset:trip.coverAsset).scaledToFill() }
        else { StoredOrAssetImage(path:nil,asset:"generic").scaledToFill() }
    }

    @MainActor private func generateCover() async {
        guard !destination.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        guard SecureStore.openAIKey() != nil else { generationMessage="未配置 API Key，将使用默认封面。";return }
        isGenerating=true;generationMessage=nil;defer{isGenerating=false}
        do {
            imageData=try await OpenAIImageService().generateTravelCover(destination:destination)
            coverAttributionName="OpenAI · 小新新原创生成";coverAttributionURL=nil
            generationMessage="生成完成，已设为旅行封面。"
        } catch {
            generationMessage="生成失败：\(error.localizedDescription)"
        }
    }

    @MainActor private func save() async {
        if trip == nil && imageData == nil && SecureStore.openAIKey() != nil { await generateCover() }
        let value = trip ?? Trip(title:title,destination:destination,startDate:start,endDate:end)
        let oldDays=value.days; value.title=title;value.destination=destination;value.startDate=start;value.endDate=end;value.tripDescription=details;value.companions=companions
        if let imageData { ImageStore.remove(named:value.coverImagePath); value.coverImagePath=try? ImageStore.save(imageData);value.coverAsset="generic" }
        value.coverAttributionName=coverAttributionName;value.coverAttributionURL=coverAttributionURL
        ItineraryFactory.synchronizeDays(for:value,oldDays:oldDays);if trip == nil { context.insert(value) };try? context.save();dismiss()
    }
}

private struct TripDateRangePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var start: Date
    @Binding var end: Date
    @State private var selectingEnd = false

    private var activeDate: Binding<Date> {
        Binding(
            get: { selectingEnd ? end : start },
            set: { value in
                let day = value.startOfDay
                if selectingEnd {
                    end = max(day,start.startOfDay)
                } else {
                    start = day
                    if end < day { end = day }
                    selectingEnd = true
                }
            }
        )
    }

    var body: some View {
        VStack(spacing:18) {
            HStack(spacing:10) {
                dateButton(title:"出发",date:start,selected:!selectingEnd){selectingEnd=false}
                Image(systemName:"arrow.right").foregroundStyle(Pastel.peachStrong)
                dateButton(title:"结束",date:end,selected:selectingEnd){selectingEnd=true}
            }.padding(.horizontal)
            Text(selectingEnd ? "请选择结束日期":"请选择出发日期，选完可直接继续点结束日期")
                .font(.subheadline).foregroundStyle(Pastel.secondary)
            DatePicker(
                selectingEnd ? "结束日期":"出发日期",
                selection:activeDate,
                in: selectingEnd ? start.startOfDay... : Date.distantPast...,
                displayedComponents:.date
            ).datePickerStyle(.graphical).labelsHidden().tint(Pastel.peachStrong).padding(.horizontal)
            Spacer(minLength:0)
        }
        .padding(.top,12).background(Pastel.background.ignoresSafeArea())
        .navigationTitle("选择往返日期").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement:.confirmationAction){Button("完成"){dismiss()}} }
    }

    private func dateButton(title:String,date:Date,selected:Bool,action:@escaping()->Void)->some View {
        Button(action:action){VStack(alignment:.leading,spacing:3){Text(title).font(.caption);Text(date.formatted(.dateTime.year().month().day())).font(.subheadline.weight(.semibold))}.foregroundStyle(Pastel.text).frame(maxWidth:.infinity,alignment:.leading).padding(12).background(selected ? Pastel.yellow:.white).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(selected ? Pastel.peachStrong:.clear,lineWidth:1.5))}.buttonStyle(.plain)
    }
}

struct TripOverviewView: View {
    @Environment(\.modelContext) private var context; @Bindable var trip:Trip
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var mode=0;@State private var edit=false
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:20) {
            ZStack(alignment:.bottomLeading) { StoredOrAssetImage(path:trip.coverImagePath,asset:trip.coverAsset).scaledToFill().frame(height:horizontalSizeClass == .regular ? 330:235).clipped(); LinearGradient(colors:[.clear,.black.opacity(0.68)],startPoint:.center,endPoint:.bottom); VStack(alignment:.leading,spacing:5){Text(trip.title).font(.largeTitle.bold()).foregroundStyle(.white);Text("\(trip.startDate.formatted(date:.abbreviated,time:.omitted)) – \(trip.endDate.formatted(date:.abbreviated,time:.omitted)) · \(trip.dayCount)天").font(.subheadline).foregroundStyle(.white.opacity(0.92))}.padding(20) }.clipShape(RoundedRectangle(cornerRadius:26))
            if let name=trip.coverAttributionName,let value=trip.coverAttributionURL,let url=URL(string:value){Link(destination:url){Label("封面图片：\(name)",systemImage:"arrow.up.right.square").font(.caption).foregroundStyle(Pastel.secondary)}}
            HStack(spacing:10) { Shortcut(icon:"list.bullet",title:"总览",color:Pastel.yellow); NavigationLink { if let first=trip.sortedDays.first { DayDetailView(day:first) } } label:{Shortcut(icon:"calendar.day.timeline.left",title:"每日",color:Pastel.blue)}; NavigationLink { MealPlanView(trip:trip) } label:{Shortcut(icon:"fork.knife",title:"饮食",color:Pastel.peach)}; NavigationLink { PhotoLibraryView(trip:trip) } label:{Shortcut(icon:"photo.on.rectangle",title:"相册",color:Pastel.mint)} }.buttonStyle(.plain)
            Picker("显示方式",selection:$mode){Text("按天查看").tag(0);Text("完整时间线").tag(1)}.pickerStyle(.segmented)
            if mode == 0 { DayList(trip:trip) } else { TimelineOverview(trip:trip) }
        }.frame(maxWidth:1100).frame(maxWidth:.infinity).padding(16) }.background(Pastel.background).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement:.topBarTrailing){Button{edit=true}label:{Image(systemName:"pencil")}} }.sheet(isPresented:$edit){NavigationStack{TripEditorView(trip:trip)}}
    }
}

struct Shortcut: View { let icon:String;let title:String;let color:Color;var body:some View{VStack(spacing:7){Image(systemName:icon).font(.title3).frame(width:48,height:42).background(color.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius:14));Text(title).font(.caption.weight(.semibold))}.foregroundStyle(Pastel.text).frame(maxWidth:.infinity)}}
struct DayList: View { let trip:Trip;var body:some View{LazyVStack(spacing:12){ForEach(trip.sortedDays){day in NavigationLink{DayDetailView(day:day)}label:{HStack(spacing:12){Text("D\(day.dayNumber)").font(.headline).foregroundStyle(Pastel.text).frame(width:48,height:38).background(Pastel.yellow).clipShape(Capsule());VStack(alignment:.leading,spacing:3){Text(day.date.formatted(.dateTime.month().day().weekday(.wide).locale(Locale(identifier:"zh_CN")))).font(.subheadline.weight(.semibold)).foregroundStyle(Pastel.text);Text(day.title.isEmpty ? (day.activities.first?.title ?? "自由安排") : day.title).font(.caption).foregroundStyle(Pastel.secondary)};Spacer();Image(systemName:"chevron.right").foregroundStyle(Pastel.secondary)}.padding(14).pastelCard()}.buttonStyle(.plain)}}}}
struct TimelineOverview: View { let trip:Trip;var body:some View{LazyVStack(alignment:.leading,spacing:18){ForEach(trip.sortedDays){day in VStack(alignment:.leading,spacing:10){PastelTag(text:"D\(day.dayNumber) · \(day.date.formatted(.dateTime.month().day()))",color:Pastel.yellow);if day.sortedActivities.isEmpty{Text("暂无安排").font(.caption).foregroundStyle(Pastel.secondary).padding(.leading,12)}else{ForEach(day.sortedActivities){activity in HStack(alignment:.top){Circle().fill(Pastel.peachStrong).frame(width:8,height:8).padding(.top,5);VStack(alignment:.leading){Text(activity.startTime.formatted(date:.omitted,time:.shortened)).font(.caption).foregroundStyle(Pastel.secondary);Text(activity.title).font(.subheadline.weight(.semibold)).foregroundStyle(Pastel.text)}}}}}}}}}

