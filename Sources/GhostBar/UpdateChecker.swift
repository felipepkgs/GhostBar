import Foundation

/// Checks GitHub Releases for a newer tagged version than AppVersion.current.
/// No Sparkle, no self-replacing binary — this is a personal-use, ad-hoc-
/// signed app distributed via a GitHub Release zip and a Homebrew tap; a
/// version check that opens the release page (or points Homebrew users at
/// `brew upgrade`) is the minimum that actually helps, not a full silent
/// update pipeline.
enum UpdateChecker {
    struct Release: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    private static let repo = "felipepkgs/GhostBar"
    private static let checkInterval: TimeInterval = 24 * 60 * 60

    /// Called on every launch, but only actually hits the network once a day
    /// — no need to hammer the GitHub API for a menu bar utility that gets
    /// relaunched often during development.
    static func checkOnLaunch(completion: @escaping (Release?) -> Void) {
        let last = UserDefaults.standard.double(forKey: SettingsKey.lastUpdateCheck)
        guard Date().timeIntervalSince1970 - last >= checkInterval else {
            completion(nil)
            return
        }
        fetch(completion: completion)
    }

    /// "Check for Updates…" menu item — always hits the network.
    static func checkNow(completion: @escaping (Release?) -> Void) {
        fetch(completion: completion)
    }

    private static func fetch(completion: @escaping (Release?) -> Void) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: SettingsKey.lastUpdateCheck)

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data, error == nil,
                  let release = try? JSONDecoder().decode(Release.self, from: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let latest = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            let isNewer = latest.compareVersion(to: AppVersion.current) == .orderedDescending
            DispatchQueue.main.async { completion(isNewer ? release : nil) }
        }.resume()
    }
}

private extension String {
    /// Dot-separated numeric version comparison ("0.10.0" > "0.9.0") — a
    /// plain string comparison would get that backwards.
    func compareVersion(to other: String) -> ComparisonResult {
        let a = split(separator: ".").compactMap { Int($0) }
        let b = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
