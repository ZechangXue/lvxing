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

struct PlaceResult: Identifiable { let id = UUID(); let name: String; let subtitle: String; let coordinate: CLLocationCoordinate2D }
struct LocationSearchService {
    func search(_ query: String, near destination: String? = nil, categoryHint: String = "景点") async throws -> [PlaceResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var destinationCoordinate: CLLocationCoordinate2D?

        if !trimmedDestination.isEmpty {
            let destinationRequest = MKLocalSearch.Request()
            destinationRequest.naturalLanguageQuery = trimmedDestination
            destinationCoordinate = try? await MKLocalSearch(request: destinationRequest).start().mapItems.first?.placemark.coordinate
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedQuery.isEmpty ? categoryHint : trimmedQuery
        request.resultTypes = .pointOfInterest
        if let destinationCoordinate {
            request.region = MKCoordinateRegion(
                center: destinationCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 1.25, longitudeDelta: 1.25)
            )
        } else if !trimmedDestination.isEmpty {
            request.naturalLanguageQuery = "\(trimmedDestination) \(request.naturalLanguageQuery ?? "景点")"
        }

        var items = try await MKLocalSearch(request: request).start().mapItems.filter { item in
            item.pointOfInterestCategory != nil
        }
        if let destinationCoordinate {
            let destinationLocation = CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude)
            items.sort {
                let left = CLLocation(latitude: $0.placemark.coordinate.latitude, longitude: $0.placemark.coordinate.longitude)
                let right = CLLocation(latitude: $1.placemark.coordinate.latitude, longitude: $1.placemark.coordinate.longitude)
                return left.distance(from: destinationLocation) < right.distance(from: destinationLocation)
            }
        }
        return items.prefix(12).map { item in
            PlaceResult(name: item.name ?? query, subtitle: item.placemark.title ?? "", coordinate: item.placemark.coordinate)
        }
    }
}

