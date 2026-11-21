import Foundation
import CalendrKit

/// The Google OAuth client this build uses (plan Q1: the owner of the Google Cloud project supplies it). Nil client ID: Google stays
/// off and "Connect Google account" explains why. The ID is not a secret (native clients have none), but it is never committed:
/// `scripts/build-app.sh` writes it into Info.plist from `CALENDR_GOOGLE_CLIENT_ID`, with its reversed-client-ID URL scheme.
struct GoogleConfig: Equatable {
    var clientID: String?

    static let infoKey = "CalendrGoogleClientID"
    static let envKey = "CALENDR_GOOGLE_CLIENT_ID"

    /// Info.plist first, then the environment (for `swift run`). Anything that is not a Google client ID counts as none.
    static func load(info: [String: Any]? = Bundle.main.infoDictionary, env: [String: String] = ProcessInfo.processInfo.environment) -> GoogleConfig {
        let raw = (info?[infoKey] as? String) ?? env[envKey]
        guard let id = raw?.trimmingCharacters(in: .whitespacesAndNewlines), GoogleOAuth.reversedClientID(id) != nil else { return GoogleConfig(clientID: nil) }
        return GoogleConfig(clientID: id)
    }

    /// The URL scheme Google redirects to after sign-in.
    var callbackScheme: String? { clientID.flatMap(GoogleOAuth.reversedClientID) }

    static let missingClientIDText = "Connecting Google needs an OAuth client ID, and this build has none. Build with CALENDR_GOOGLE_CLIENT_ID set to an iOS-type client ID from Google Cloud (it ends in .apps.googleusercontent.com). Until then Google calendars come through macOS Calendar."
}
