import Foundation

enum APIConfig {
    static let host = "http://35.236.77.209"
    static let streamHost = "http://35.236.77.209:8000"
    
    static var usersURL: String { "\(host)/users" }
    static var modelsURL: String { "\(host)/models" }
    static var friendsURL: String { "\(host)/friends" }
    static var shareURL: String { "\(host)/models/share" }
    static var receivedURL: String { "\(host)/models/received" }
    static var streamSessionURL: String { "\(streamHost)/stream/session" }
    static var streamCallURL: String { "\(streamHost)/stream/call" }
    static var streamIncomingURL: String { "\(streamHost)/stream/incoming" }
}
