import SwiftUI

struct DestinationCoverPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [DestinationPhoto] = []
    @State private var loading = false
    @State private var downloadingID: String?
    @State private var errorMessage: String?
    let onSelect: (Data, DestinationPhoto) -> Void
    private let columns = [GridItem(.flexible(),spacing:10),GridItem(.flexible(),spacing:10)]

    init(initialQuery: String, onSelect: @escaping (Data, DestinationPhoto) -> Void) {
        _query = State(initialValue: initialQuery)
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                HStack {
                    TextField("城市、国家或景点，例如：冰岛雷克雅未克",text:$query)
                        .textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit { Task { await search() } }
                    Button { Task { await search() } } label: { Image(systemName:"magnifyingglass").frame(width:42,height:42).background(Pastel.yellow).clipShape(Circle()) }
                        .disabled(query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || loading)
                }
                Text("搜索任意旅行地。配置 Unsplash Key 时优先显示旅行摄影；否则自动使用维基百科代表图。")
                    .font(.caption).foregroundStyle(Pastel.secondary)
                if loading { HStack { Spacer();ProgressView("正在寻找代表性图片…");Spacer() }.padding(.vertical,30) }
                if let errorMessage { ContentUnavailableView("没有找到合适图片",systemImage:"photo.badge.exclamationmark",description:Text(errorMessage)) }
                LazyVGrid(columns:columns,spacing:10) {
                    ForEach(results) { photo in
                        Button { Task { await choose(photo) } } label: {
                            ZStack(alignment:.bottomLeading) {
                                AsyncImage(url:photo.previewURL) { phase in
                                    if let image=phase.image { image.resizable().scaledToFill() }
                                    else { Rectangle().fill(Pastel.blue.opacity(0.3)).overlay { ProgressView() } }
                                }.frame(height:145).clipped()
                                LinearGradient(colors:[.clear,.black.opacity(0.65)],startPoint:.center,endPoint:.bottom)
                                VStack(alignment:.leading,spacing:2) {
                                    Text(photo.attributionName).lineLimit(1)
                                    Text(photo.sourceName).opacity(0.8)
                                }.font(.caption2).foregroundStyle(.white).padding(8)
                                if downloadingID == photo.id { Rectangle().fill(.black.opacity(0.25));ProgressView().tint(.white).frame(maxWidth:.infinity,maxHeight:.infinity) }
                            }.clipShape(RoundedRectangle(cornerRadius:18))
                        }.buttonStyle(.plain).disabled(downloadingID != nil)
                    }
                }
            }.padding(16)
        }.background(Pastel.background).navigationTitle("搜索旅行封面").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("关闭") { dismiss() } } }
            .task { if !query.isEmpty { await search() } }
    }

    @MainActor private func search() async {
        let value=query.trimmingCharacters(in:.whitespacesAndNewlines);guard !value.isEmpty else{return}
        loading=true;errorMessage=nil;defer{loading=false}
        do { results=try await DestinationPhotoService().search(value);if results.isEmpty{errorMessage="换一个更具体的城市、国家或景点名称试试。"} }
        catch { results=[];errorMessage="网络图片暂时不可用，但仍可从手机照片图库选择封面。" }
    }

    @MainActor private func choose(_ photo: DestinationPhoto) async {
        downloadingID=photo.id;defer{downloadingID=nil}
        do { let data=try await DestinationPhotoService().download(photo);onSelect(data,photo);dismiss() }
        catch { errorMessage="图片下载失败，请检查网络后重试。" }
    }
}

