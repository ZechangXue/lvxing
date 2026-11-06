import Foundation
import UIKit
import MapKit

enum ImageStore {
    static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TravelBuddyImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func save(_ data: Data) throws -> String {
        let name = UUID().uuidString + ".jpg", url = directory.appendingPathComponent(name)
        guard let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.86) else { throw CocoaError(.fileReadCorruptFile) }
        try jpeg.write(to: url, options: .atomic); return name
    }
    static func image(named path: String?) -> UIImage? { guard let path else { return nil }; return UIImage(contentsOfFile: directory.appendingPathComponent(path).path) }
    static func remove(named path: String?) { guard let path else { return }; try? FileManager.default.removeItem(at: directory.appendingPathComponent(path)) }
}

struct UnsplashPhoto: Decodable, Identifiable {
    struct URLs: Decodable { let small: String; let regular: String }
    struct User: Decodable { let name: String; let links: UserLinks }
    struct UserLinks: Decodable { let html: String }
    struct PhotoLinks: Decodable {
        let downloadLocation: String
        enum CodingKeys: String, CodingKey { case downloadLocation = "download_location" }
    }
    let id: String; let urls: URLs; let user: User; let links: PhotoLinks
}
private struct UnsplashResponse: Decodable { let results: [UnsplashPhoto] }

struct PhotoSearchService {
    var accessKey: String { Bundle.main.object(forInfoDictionaryKey: "UNSPLASH_ACCESS_KEY") as? String ?? "" }
    func search(_ query: String, page: Int = 1) async throws -> [UnsplashPhoto] {
        guard !accessKey.isEmpty else { throw PhotoSearchError.missingKey }
        var components = URLComponents(string: "https://api.unsplash.com/search/photos")!
        components.queryItems = [.init(name:"query",value:query),.init(name:"page",value:String(page)),.init(name:"per_page",value:"20"),.init(name:"order_by",value:"relevant"),.init(name:"orientation",value:"landscape"),.init(name:"content_filter",value:"high")]
        var request = URLRequest(url: components.url!); request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw PhotoSearchError.server }
        return try JSONDecoder().decode(UnsplashResponse.self, from: data).results
    }
    func registerDownload(for photo: UnsplashPhoto) async throws {
        guard var components = URLComponents(string: photo.links.downloadLocation) else { return }
        var items = components.queryItems ?? []; items.append(.init(name: "client_id", value: accessKey)); components.queryItems = items
        guard let url = components.url else { return }
        _ = try await URLSession.shared.data(from: url)
    }
}
enum PhotoSearchError: LocalizedError { case missingKey, server; var errorDescription: String? { self == .missingKey ? "未配置 Unsplash Key，仍可使用本地照片。" : "图片服务暂时不可用。" } }

struct DestinationPhoto: Identifiable, Sendable {
    let id: String
    let previewURL: URL
    let fullURL: URL
    let attributionName: String
    let attributionURL: URL
    let sourceName: String
    let downloadTrackingURL: URL?
}

private struct WikipediaSearchResponse: Decodable {
    struct Query: Decodable { let pages: [Page] }
    struct Page: Decodable {
        struct Picture: Decodable { let source: URL }
        let pageid: Int; let title: String; let thumbnail: Picture?; let original: Picture?
    }
    let query: Query?
}

struct DestinationPhotoService {
    func search(_ query: String) async throws -> [DestinationPhoto] {
        let unsplash = PhotoSearchService()
        if !unsplash.accessKey.isEmpty, let photos = try? await unsplash.search(query), !photos.isEmpty {
            return photos.map { photo in
                DestinationPhoto(
                    id: "unsplash-\(photo.id)", previewURL: URL(string: photo.urls.small)!, fullURL: URL(string: photo.urls.regular)!,
                    attributionName: "\(photo.user.name) / Unsplash", attributionURL: URL(string: photo.user.links.html + "?utm_source=travelbuddy&utm_medium=referral")!, sourceName: "Unsplash",
                    downloadTrackingURL: URL(string: photo.links.downloadLocation)
                )
            }
        }
        return try await searchWikipedia(query)
    }

    private func searchWikipedia(_ query: String) async throws -> [DestinationPhoto] {
        var components = URLComponents(string: "https://zh.wikipedia.org/w/api.php")!
        components.queryItems = [
            .init(name:"action",value:"query"),.init(name:"format",value:"json"),.init(name:"formatversion",value:"2"),
            .init(name:"generator",value:"search"),.init(name:"gsrsearch",value:query),.init(name:"gsrnamespace",value:"0"),.init(name:"gsrlimit",value:"18"),
            .init(name:"prop",value:"pageimages"),.init(name:"piprop",value:"thumbnail|original"),.init(name:"pithumbsize",value:"900"),.init(name:"pilicense",value:"free"),.init(name:"origin",value:"*")
        ]
        var request = URLRequest(url: components.url!); request.setValue("TravelBuddy/1.0 (iOS travel planner)", forHTTPHeaderField: "User-Agent")
        let (data,response) = try await URLSession.shared.data(for: request)
        guard let http=response as? HTTPURLResponse,200..<300 ~= http.statusCode else { throw PhotoSearchError.server }
        let pages = try JSONDecoder().decode(WikipediaSearchResponse.self,from:data).query?.pages ?? []
        return pages.compactMap { page in
            guard let preview=page.thumbnail?.source ?? page.original?.source,let full=page.original?.source ?? page.thumbnail?.source,
                  let attribution=URL(string:"https://zh.wikipedia.org/?curid=\(page.pageid)") else { return nil }
            return DestinationPhoto(id:"wikipedia-\(page.pageid)",previewURL:preview,fullURL:full,attributionName:"维基百科 · \(page.title)",attributionURL:attribution,sourceName:"维基百科",downloadTrackingURL:nil)
        }
    }

    func download(_ photo: DestinationPhoto) async throws -> Data {
        if let tracking=photo.downloadTrackingURL,!PhotoSearchService().accessKey.isEmpty {
            var components=URLComponents(url:tracking,resolvingAgainstBaseURL:false)!;var items=components.queryItems ?? [];items.append(.init(name:"client_id",value:PhotoSearchService().accessKey));components.queryItems=items
            if let url=components.url { _ = try? await URLSession.shared.data(from:url) }
        }
        let (data,response)=try await URLSession.shared.data(from:photo.fullURL)
        guard let http=response as? HTTPURLResponse,200..<300 ~= http.statusCode else { throw PhotoSearchError.server }
        return data
    }
}

struct PlaceResult: Identifiable { let id = UUID(); let name: String; let subtitle: String; let coordinate: CLLocationCoordinate2D; let provider: String; let providerPlaceID: String? }

enum GooglePlacesError: LocalizedError {
    case missingKey, invalidResponse, api(Int,String)
    var errorDescription:String? {
        switch self {
        case .missingKey: "尚未配置 Google Maps API Key"
        case .invalidResponse: "Google Maps 返回了无效响应"
        case .api(let status,let message): "Google Maps（\(status)）：\(message)"
        }
    }
}

struct GooglePlacesService {
    private struct SearchResponse:Decodable {
        struct Place:Decodable {
            struct DisplayName:Decodable { let text:String }
            struct Location:Decodable { let latitude:Double;let longitude:Double }
            let id:String;let displayName:DisplayName;let formattedAddress:String?;let location:Location
        }
        let places:[Place]?
    }
    private struct ErrorResponse:Decodable { struct Detail:Decodable { let message:String };let error:Detail }

    func search(_ query:String,near destination:String?,categoryHint:String)async throws->[PlaceResult] {
        guard let key=SecureStore.googleMapsKey(),!key.isEmpty else{throw GooglePlacesError.missingKey}
        let destination=(destination ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
        let keyword=query.trimmingCharacters(in:.whitespacesAndNewlines)
        let textQuery:String
        if keyword.isEmpty { textQuery=destination.isEmpty ? categoryHint:"\(destination) \(categoryHint)" }
        else { textQuery=destination.isEmpty ? keyword:"\(destination) \(keyword)" }
        var request=URLRequest(url:URL(string:"https://places.googleapis.com/v1/places:searchText")!)
        request.httpMethod="POST"
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.setValue(key,forHTTPHeaderField:"X-Goog-Api-Key")
        request.setValue("places.id,places.displayName,places.formattedAddress,places.location",forHTTPHeaderField:"X-Goog-FieldMask")
        if let bundleID=Bundle.main.bundleIdentifier{request.setValue(bundleID,forHTTPHeaderField:"X-Ios-Bundle-Identifier")}
        request.httpBody=try JSONSerialization.data(withJSONObject:["textQuery":textQuery,"languageCode":"zh-CN","maxResultCount":15])
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else{throw GooglePlacesError.invalidResponse}
        guard 200..<300 ~= http.statusCode else{
            let message=(try? JSONDecoder().decode(ErrorResponse.self,from:data).error.message) ?? String(data:data,encoding:.utf8) ?? "请求失败"
            throw GooglePlacesError.api(http.statusCode,message)
        }
        let places=try JSONDecoder().decode(SearchResponse.self,from:data).places ?? []
        return places.map{place in PlaceResult(name:place.displayName.text,subtitle:place.formattedAddress ?? "",coordinate:.init(latitude:place.location.latitude,longitude:place.location.longitude),provider:"Google Maps",providerPlaceID:place.id)}
    }

    func validate()async throws->String {
        _=try await search("故宫博物院",near:"北京",categoryHint:"景点")
        return "连接成功，之后地点搜索将完全使用 Google Maps。"
    }
}

struct LocationSearchService {
    func search(_ query: String, near destination: String? = nil, categoryHint: String = "景点") async throws -> [PlaceResult] {
        try await GooglePlacesService().search(query,near:destination,categoryHint:categoryHint)
    }
}

