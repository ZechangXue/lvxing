import SwiftUI
import SwiftData
import PhotosUI

struct PhotoLibraryView:View{
    @Environment(\.modelContext)private var context;@Query(sort:\PhotoAsset.createdAt,order:.reverse)private var allPhotos:[PhotoAsset]
    let trip:Trip;@State private var selectedItems:[PhotosPickerItem]=[];@State private var query="";@State private var results:[UnsplashPhoto]=[];@State private var loading=false;@State private var message:String?
    var photos:[PhotoAsset]{allPhotos.filter{$0.tripID==trip.id}}
    let columns=[GridItem(.flexible(),spacing:8),GridItem(.flexible(),spacing:8)]
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:16){
        HStack{TextField("搜索目的地或景点",text:$query).textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit{Task{await search()}};Button{Task{await search()}}label:{Image(systemName:"magnifyingglass")}}
        HStack{PhotosPicker(selection:$selectedItems,maxSelectionCount:12,matching:.images){Label("从照片图库添加",systemImage:"photo.badge.plus").font(.subheadline.weight(.semibold)).padding(12).frame(maxWidth:.infinity).background(Pastel.yellow).clipShape(RoundedRectangle(cornerRadius:14))};if loading{ProgressView().padding(.horizontal)}}
        if let message{Text(message).font(.caption).foregroundStyle(Pastel.secondary)}
        if !results.isEmpty{SectionHeader(title:"在线图片",subtitle:"图片来自 Unsplash");LazyVGrid(columns:columns,spacing:8){ForEach(results){photo in Button{Task{await saveRemote(photo)}}label:{AsyncImage(url:URL(string:photo.urls.small)){phase in if let image=phase.image{image.resizable().scaledToFill()}else{Rectangle().fill(Pastel.blue.opacity(0.3)).overlay{ProgressView()}}}.frame(height:130).clipShape(RoundedRectangle(cornerRadius:16)).overlay(alignment:.bottomLeading){Text(photo.user.name).font(.caption2).foregroundStyle(.white).padding(6).background(.black.opacity(0.4)).clipShape(Capsule()).padding(6)}}.buttonStyle(.plain)}}}
        SectionHeader(title:"旅行相册",subtitle:"\(photos.count) 张");if photos.isEmpty{EmptyStateView(image:"pigCamera",title:"相册还是空的",message:"可以从手机选择照片；配置 Unsplash Key 后也能在线搜索。") }else{LazyVGrid(columns:columns,spacing:8){ForEach(photos){photo in PhotoTile(photo:photo).contextMenu{Button(role:.destructive){ImageStore.remove(named:photo.localPath);context.delete(photo);try? context.save()}label:{Label("移除",systemImage:"trash")}}}}}
    }.padding(18)}.background(Pastel.background).navigationTitle("旅行相册").navigationBarTitleDisplayMode(.inline).task(id:selectedItems){await importItems()}}
    @MainActor private func importItems()async{for item in selectedItems{if let data=try? await item.loadTransferable(type:Data.self),let path=try? ImageStore.save(data){context.insert(PhotoAsset(localPath:path,tripID:trip.id))}};try? context.save();selectedItems=[]}
    @MainActor private func search()async{guard !query.isEmpty else{return};loading=true;defer{loading=false};do{results=try await PhotoSearchService().search(query);message=nil}catch{message=error.localizedDescription;results=[]}}
    @MainActor private func saveRemote(_ p:UnsplashPhoto)async{loading=true;defer{loading=false};var localPath:String?;if let url=URL(string:p.urls.regular),let (data,_)=try? await URLSession.shared.data(from:url){localPath=try? ImageStore.save(data)};try? await PhotoSearchService().registerDownload(for:p);context.insert(PhotoAsset(localPath:localPath,remoteURL:p.urls.regular,thumbnailURL:p.urls.small,attributionName:p.user.name,attributionURL:p.user.links.html,tripID:trip.id));try? context.save();message=localPath == nil ? "已添加；联网时可查看原图" : "已下载并保存，可离线查看"}
}
struct PhotoTile:View{let photo:PhotoAsset;var body:some View{Group{if let image=ImageStore.image(named:photo.localPath){Image(uiImage:image).resizable().scaledToFill()}else if let value=photo.thumbnailURL,let url=URL(string:value){AsyncImage(url:url){phase in if let image=phase.image{image.resizable().scaledToFill()}else{Image(systemName:"photo").resizable().scaledToFit().padding(30)}}}else{Image(systemName:"photo").resizable().scaledToFit().padding(30)}}.frame(height:140).frame(maxWidth:.infinity).background(Pastel.blue.opacity(0.25)).clipShape(RoundedRectangle(cornerRadius:16))}}

struct FavoritesView:View{
    @Environment(\.modelContext)private var context;@Query(sort:\FavoritePlace.createdAt,order:.reverse)private var favorites:[FavoritePlace];@State private var search="";@State private var adding=false
    var visible:[FavoritePlace]{search.isEmpty ? favorites:favorites.filter{$0.name.localizedCaseInsensitiveContains(search)||$0.city.localizedCaseInsensitiveContains(search)}}
    var body:some View{ZStack(alignment:.bottomTrailing){Pastel.background.ignoresSafeArea();ScrollView{VStack(spacing:14){HStack{Text("我的收藏").font(.largeTitle.bold()).foregroundStyle(Pastel.text);Spacer();Image("pigSuccess").resizable().scaledToFit().frame(width:78,height:78)};TextField("搜索收藏",text:$search).textFieldStyle(.roundedBorder);if visible.isEmpty{EmptyStateView(image:"pigEmpty",title:"还没有收藏",message:"把喜欢的景点、餐厅和灵感先放在这里。",buttonTitle:"添加收藏",action:{adding=true})}else{ForEach(visible){place in HStack{Image(systemName:place.category=="餐厅" ? "fork.knife":"mappin.and.ellipse").foregroundStyle(Pastel.peachStrong).frame(width:44,height:44).background(Pastel.yellow.opacity(0.55)).clipShape(Circle());VStack(alignment:.leading){Text(place.name).font(.headline).foregroundStyle(Pastel.text);Text("\(place.city) · \(place.category)").font(.caption).foregroundStyle(Pastel.secondary)};Spacer()}.padding(14).pastelCard().contextMenu{Button(role:.destructive){context.delete(place);try? context.save()}label:{Label("删除",systemImage:"trash")}}}}}.padding(18).padding(.bottom,70)};RoundedIconButton(icon:"plus",color:Pastel.yellow){adding=true}.padding(22)}.toolbar(.hidden,for:.navigationBar).sheet(isPresented:$adding){NavigationStack{FavoriteEditorView()}}}
}
struct FavoriteEditorView:View{@Environment(\.dismiss)private var dismiss;@Environment(\.modelContext)private var context;@State private var name="";@State private var category="景点";@State private var city="";@State private var notes="";var body:some View{Form{TextField("名称",text:$name);Picker("类型",selection:$category){ForEach(["景点","餐厅","活动","住宿","灵感"],id:\.self){Text($0)}};TextField("城市",text:$city);TextField("备注",text:$notes,axis:.vertical)}.navigationTitle("添加收藏").toolbar{ToolbarItem(placement:.cancellationAction){Button("取消"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("保存"){context.insert(FavoritePlace(name:name,category:category,city:city,notes:notes));try? context.save();dismiss()}.disabled(name.isEmpty)}}}}

struct ProfileView:View{
    @State private var showingOpenAI=false
    @State private var hasOpenAIKey=false
    var body:some View{ScrollView{VStack(spacing:20){
        Image("pigMap").resizable().scaledToFit().frame(height:200)
        VStack(spacing:6){Text("小桃的旅行手账").font(.title.bold()).foregroundStyle(Pastel.text);Text("把每一段期待，都好好收藏").foregroundStyle(Pastel.secondary)}
        VStack(spacing:0){
            Button{showingOpenAI=true}label:{HStack{ProfileRow(icon:"wand.and.stars",title:"OpenAI 旅行封面",subtitle:hasOpenAIKey ? "已配置 · 新旅程优先自动生成":"未配置 · 使用默认封面");Image(systemName:"chevron.right").foregroundStyle(Pastel.secondary).padding(.trailing,14)}}.buttonStyle(.plain)
            Divider().padding(.leading,62)
            ProfileRow(icon:"icloud.and.arrow.down",title:"离线优先",subtitle:"生成结果与核心行程保存在本机")
            Divider().padding(.leading,62)
            ProfileRow(icon:"lock.shield",title:"隐私",subtitle:"API Key 仅保存在本机钥匙串")
        }.pastelCard()
        Text("TravelBuddy 1.1").font(.caption).foregroundStyle(Pastel.secondary)
    }.padding(22)}.background(Pastel.background).navigationTitle("我的")
        .onAppear{hasOpenAIKey=SecureStore.openAIKey() != nil}
        .sheet(isPresented:$showingOpenAI,onDismiss:{hasOpenAIKey=SecureStore.openAIKey() != nil}){NavigationStack{OpenAISettingsView()}}
    }
}

struct OpenAISettingsView:View{
    @Environment(\.dismiss)private var dismiss
    @State private var apiKey=""
    @State private var hasSavedKey=false
    @State private var message:String?
    @State private var validating=false
    var body:some View{Form{
        Section{SecureField(hasSavedKey ? "输入新 Key 可替换现有 Key":"sk-…",text:$apiKey).textInputAutocapitalization(.never).autocorrectionDisabled();if hasSavedKey{Label("已在本机钥匙串中安全保存",systemImage:"checkmark.shield.fill").foregroundStyle(.green)}}header:{Text("OpenAI API Key")}footer:{Text("有可用 Key 时，新建旅程会优先生成同款小桃画风封面，并显示生成进度；没有 Key 或生成失败时自动使用默认封面。Key 不会提交到 GitHub。")}
        Section{Button{Task{await validate()}}label:{if validating{HStack{ProgressView();Text("正在验证图片模型权限…")}}else{Label("验证 API Key 与图片模型",systemImage:"checkmark.shield")}}.disabled(!hasSavedKey||validating);Link("打开 OpenAI API Keys 页面",destination:URL(string:"https://platform.openai.com/api-keys")!);if let message{Text(message).foregroundStyle(Pastel.secondary).textSelection(.enabled)}}
        if hasSavedKey{Section{Button("移除 API Key",role:.destructive){SecureStore.removeOpenAIKey();hasSavedKey=false;apiKey="";message="已移除，之后将使用默认封面。"}}}
    }.navigationTitle("OpenAI 图片生成").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("关闭"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("保存"){save()}.disabled(apiKey.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)}}.onAppear{hasSavedKey=SecureStore.openAIKey() != nil}}
    private func save(){do{try SecureStore.saveOpenAIKey(apiKey.trimmingCharacters(in:.whitespacesAndNewlines));hasSavedKey=true;apiKey="";message="保存成功。下次新建旅程时会自动生成封面。"}catch{message=error.localizedDescription}}
    @MainActor private func validate()async{validating=true;defer{validating=false};do{message=try await OpenAIImageService().validateImageAccess()}catch{message=error.localizedDescription}}
}
struct ProfileRow:View{let icon:String;let title:String;let subtitle:String;var body:some View{HStack(spacing:14){Image(systemName:icon).foregroundStyle(Pastel.peachStrong).frame(width:38,height:38).background(Pastel.yellow.opacity(0.55)).clipShape(Circle());VStack(alignment:.leading,spacing:3){Text(title).font(.headline).foregroundStyle(Pastel.text);Text(subtitle).font(.caption).foregroundStyle(Pastel.secondary)};Spacer()}.padding(14)}}

