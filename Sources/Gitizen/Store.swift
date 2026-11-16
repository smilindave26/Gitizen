import Foundation
import Observation
import ServiceManagement

struct Item: Hashable, Identifiable {
    let number: Int
    let title: String
    let url: URL
    let isPR: Bool

    var id: Int { number }
}

struct RepoState: Codable, Equatable {
    /// Highest issue/PR number the user has already seen. Issues and PRs
    /// share one number sequence, so anything numbered above this is new.
    var seenNumber: Int
    var seenStars: Int
    var stars: Int
    /// All open PRs plus new open issues, newest first. Rebuilt on every
    /// fetch, so it isn't persisted.
    var items: [Item] = []

    private enum CodingKeys: String, CodingKey {
        case seenNumber, seenStars, stars
    }

    var newStars: Int { max(0, stars - seenStars) }
    var newCount: Int { items.count(where: isNew) + newStars }

    func isNew(_ item: Item) -> Bool { item.number > seenNumber }

    /// Rebuilds the items from a fresh fetch, so closed and merged ones drop out.
    /// `openIssues` comes from the issues endpoint, which also returns PRs.
    mutating func update(stars: Int, openPulls: [IssueDTO], openIssues: [IssueDTO]) {
        self.stars = stars
        // Unstars lower the baseline so they don't mask later stars.
        seenStars = min(seenStars, stars)
        let pulls = openPulls.map { Item(number: $0.number, title: $0.title, url: $0.htmlUrl, isPR: true) }
        let issues = openIssues
            .filter { $0.pullRequest == nil && $0.number > seenNumber }
            .map { Item(number: $0.number, title: $0.title, url: $0.htmlUrl, isPR: false) }
        items = (pulls + issues).sorted { $0.number > $1.number }
    }

    mutating func markSeen() {
        seenNumber = max(seenNumber, items.first?.number ?? 0)
        seenStars = stars
        items.removeAll { !$0.isPR }
    }
}

@MainActor
@Observable
final class Store {
    private(set) var repos: [String]
    private(set) var states: [String: RepoState]
    private(set) var error: String?
    private(set) var lastChecked: Date?
    private(set) var isRefreshing = false
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    var newCount: Int { states.values.reduce(0) { $0 + $1.newCount } }

    private static let pollInterval: Duration = .seconds(300)
    private static let reposKey = "repos"
    private static let statesKey = "states"

    init() {
        let defaults = UserDefaults.standard
        repos = defaults.stringArray(forKey: Self.reposKey) ?? []
        states = defaults.data(forKey: Self.statesKey)
            .flatMap { try? JSONDecoder().decode([String: RepoState].self, from: $0) } ?? [:]

        // The store lives for the life of the app, so the loop never needs to stop.
        Task {
            while true {
                await refresh()
                try? await Task.sleep(for: Self.pollInterval)
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        error = await fetch(repos)
        lastChecked = .now
    }

    /// Returns false if the input isn't a recognizable repo.
    func add(_ input: String) -> Bool {
        guard let repo = Self.parseRepo(input) else {
            error = "Expected owner/repo or a GitHub URL"
            return false
        }
        guard !repos.contains(where: { $0.caseInsensitiveCompare(repo) == .orderedSame }) else {
            return true
        }
        repos.append(repo)
        save()
        Task {
            if let failure = await fetch([repo]) {
                error = failure
            }
        }
        return true
    }

    func remove(_ repo: String) {
        repos.removeAll { $0 == repo }
        states[repo] = nil
        save()
    }

    func markAllSeen() {
        states = states.mapValues {
            var state = $0
            state.markSeen()
            return state
        }
        save()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            self.error = "Launch at login: \(error.localizedDescription)"
        }
        if service.status == .requiresApproval {
            error = "Allow Gitizen in System Settings > Login Items"
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLogin = service.status == .enabled
    }

    /// Fetches the given repos and returns the first error, if any.
    private func fetch(_ targets: [String]) async -> String? {
        let api = GitHub(token: await GitHub.ghToken())
        var firstError: String?
        for repo in targets {
            do {
                async let info: RepoInfo = api.get("repos/\(repo)")
                async let pulls: [IssueDTO] = api.get("repos/\(repo)/pulls?state=open&per_page=100")
                async let issues: [IssueDTO] = api.get(
                    "repos/\(repo)/issues?state=open&sort=created&direction=desc&per_page=50")
                let (stars, openPulls, openIssues) = try await (info.stargazersCount, pulls, issues)

                guard repos.contains(repo) else { continue } // removed mid-fetch
                let newest = (openPulls + openIssues).map(\.number).max() ?? 0
                var state = states[repo] ?? RepoState(seenNumber: newest, seenStars: stars, stars: stars)
                state.update(stars: stars, openPulls: openPulls, openIssues: openIssues)
                states[repo] = state
            } catch {
                firstError = firstError ?? "\(repo): \(error.localizedDescription)"
            }
        }
        save()
        return firstError
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(repos, forKey: Self.reposKey)
        defaults.set(try? JSONEncoder().encode(states), forKey: Self.statesKey)
    }

    /// Accepts "owner/repo" or any github.com URL within a repo.
    nonisolated static func parseRepo(_ input: String) -> String? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://", "www.", "github.com/"] where text.hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        let parts = text.split(separator: "/").prefix(2).map(String.init)
        guard parts.count == 2 else { return nil }

        let owner = parts[0]
        var name = parts[1]
        if name.hasSuffix(".git") {
            name.removeLast(4)
        }
        let valid = [owner, name].allSatisfy {
            $0 != "." && $0 != ".." && $0.wholeMatch(of: /[A-Za-z0-9_.-]+/) != nil
        }
        return valid ? "\(owner)/\(name)" : nil
    }
}
