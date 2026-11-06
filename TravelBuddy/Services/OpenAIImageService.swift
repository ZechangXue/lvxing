import Foundation
import UIKit
import Security

enum SecureStore {
    private static let service = "com.example.TravelBuddy"
    private static let account = "openai-api-key"
    private static let googleMapsAccount = "google-maps-api-key"

    static func saveOpenAIKey(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw OpenAIImageError.keychain(status) }
    }

    static func openAIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func removeOpenAIKey() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
    }

    static func saveGoogleMapsKey(_ value: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: googleMapsAccount]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw OpenAIImageError.keychain(status) }
    }

    static func googleMapsKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: googleMapsAccount, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func removeGoogleMapsKey() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: googleMapsAccount]
        SecItemDelete(query as CFDictionary)
    }
}

enum OpenAIImageError: LocalizedError {
    case missingKey, missingReference, invalidResponse, api(Int, String), decode, keychain(OSStatus)
    var errorDescription: String? {
        switch self {
        case .missingKey: "尚未配置 OpenAI API Key"
        case .missingReference: "找不到内置画风参考图"
        case .invalidResponse: "OpenAI 返回了无效响应"
        case .api(let status, let message): "OpenAI（\(status)）：\(message)"
        case .decode: "生成图片解析失败"
        case .keychain: "API Key 无法保存到钥匙串"
        }
    }
}

struct OpenAIImageService {
    private struct ImagesResponse: Decodable {
        struct ImageResult: Decodable { let b64_json: String? }
        let data: [ImageResult]?
    }
    private struct APIErrorResponse: Decodable { struct Detail: Decodable { let message: String }; let error: Detail }

    func validateImageAccess() async throws -> String {
        guard let apiKey = SecureStore.openAIKey(), !apiKey.isEmpty else { throw OpenAIImageError.missingKey }
        var request = URLRequest(url: URL(string:"https://api.openai.com/v1/models/gpt-image-1.5")!)
        request.setValue("Bearer \(apiKey)",forHTTPHeaderField:"Authorization")
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else{throw OpenAIImageError.invalidResponse}
        guard 200..<300 ~= http.statusCode else{throw apiError(status:http.statusCode,data:data)}
        return "API Key 有效，图片模型可见；实际生成还需要账户有可用额度并满足组织验证要求。"
    }

    func generateTravelCover(destination: String) async throws -> Data {
        guard let apiKey = SecureStore.openAIKey(), !apiKey.isEmpty else { throw OpenAIImageError.missingKey }
        guard let reference = UIImage(named: "coverParis")?.pngData() else { throw OpenAIImageError.missingReference }

        let prompt = """
        Create a new wide travel-card cover for destination: \(destination).
        Use the supplied image only as the original TravelBuddy visual-style and mascot reference. Preserve the same original round pink pig traveler identity: soft-yellow bucket hat, sky-blue backpack, warm cocoa outlines, blush cheeks, simple friendly face. Replace the Paris scene with recognizable, geographically appropriate landmarks, landscape, architecture, weather, plants, and seasonal atmosphere from \(destination). The pig should be small, under 18 percent of the frame, naturally enjoying a destination-appropriate travel activity. Polished minimal kawaii travel-journal illustration, pastel cream, peach, mint, sky blue, soft yellow, clean rounded forms, wide 3:2 landscape composition, safe crop for an iOS rounded card. No text, no letters, no logos, no watermark, no border, no copyrighted character, no photorealism.
        """

        var failures:[String]=[]
        for model in ["gpt-image-2.5-sunburst","gpt-image-2.5-flare","gpt-image-1.5","gpt-image-1-mini"] {
            do { return try await edit(model:model,apiKey:apiKey,prompt:prompt,reference:reference) }
            catch let error as OpenAIImageError {
                if case .api(let status,_) = error,status == 401 || status == 403 || status == 429 { throw error }
                failures.append(error.localizedDescription)
            } catch { failures.append(error.localizedDescription) }
        }
        do { return try await generateWithoutReference(model:"gpt-image-1-mini",apiKey:apiKey,prompt:prompt) }
        catch { failures.append(error.localizedDescription) }
        throw OpenAIImageError.api(400,failures.last ?? "当前账户没有可用的图片模型")
    }

    private func edit(model:String,apiKey:String,prompt:String,reference:Data)async throws->Data{
        let boundary="TravelBuddy-\(UUID().uuidString)"
        var request=URLRequest(url:URL(string:"https://api.openai.com/v1/images/edits")!);request.httpMethod="POST";request.timeoutInterval=240
        request.setValue("Bearer \(apiKey)",forHTTPHeaderField:"Authorization");request.setValue("multipart/form-data; boundary=\(boundary)",forHTTPHeaderField:"Content-Type")
        request.httpBody=multipartBody(boundary:boundary,model:model,prompt:prompt,reference:reference)
        return try await executeImageRequest(request)
    }

    private func generateWithoutReference(model:String,apiKey:String,prompt:String)async throws->Data{
        var request=URLRequest(url:URL(string:"https://api.openai.com/v1/images/generations")!);request.httpMethod="POST";request.timeoutInterval=240
        request.setValue("Bearer \(apiKey)",forHTTPHeaderField:"Authorization");request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        request.httpBody=try JSONSerialization.data(withJSONObject:["model":model,"prompt":prompt,"size":"1536x1024","quality":"medium","output_format":"png","background":"opaque"])
        return try await executeImageRequest(request)
    }

    private func executeImageRequest(_ request:URLRequest)async throws->Data{
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let http=response as? HTTPURLResponse else{throw OpenAIImageError.invalidResponse}
        guard 200..<300 ~= http.statusCode else{throw apiError(status:http.statusCode,data:data)}
        let decoded=try JSONDecoder().decode(ImagesResponse.self,from:data)
        guard let encoded=decoded.data?.first?.b64_json,let imageData=Data(base64Encoded:encoded)else{throw OpenAIImageError.decode}
        return imageData
    }

    private func apiError(status:Int,data:Data)->OpenAIImageError{
        let message=(try? JSONDecoder().decode(APIErrorResponse.self,from:data).error.message) ?? "图片请求失败"
        return .api(status,message)
    }

    private func multipartBody(boundary: String, model:String, prompt: String, reference: Data) -> Data {
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("model", model)
        field("prompt", prompt)
        field("size", "1536x1024")
        field("quality", "medium")
        field("output_format", "png")
        field("background", "opaque")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"travelbuddy-style.png\"\r\nContent-Type: image/png\r\n\r\n".data(using: .utf8)!)
        body.append(reference)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
