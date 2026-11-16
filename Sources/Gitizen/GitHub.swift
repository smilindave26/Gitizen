import Foundation

struct RepoInfo: Decodable, Sendable {
    let stargazersCount: Int
}

/// An issue or PR from the issues or pulls endpoint. The issues endpoint
/// returns PRs too, and marks them with `pullRequest`.
struct IssueDTO: Decodable, Sendable {
    struct PullRequestRef: Decodable, Sendable {}

    let number: Int
    let title: String
    let htmlUrl: URL
    let pullRequest: PullRequestRef?
}

private struct ErrorBody: Decodable {
    let message: String
}

struct GitHubError: LocalizedError {
    let status: Int
    let message: String

    var errorDescription: String? { "\(message) (HTTP \(status))" }
}

struct GitHub: Sendable {
    let token: String?

    func get<T: Decodable & Sendable>(_ path: String) async throws -> T {
        guard let url = URL(string: "https://api.github.com/\(path)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message
                ?? HTTPURLResponse.localizedString(forStatusCode: status)
            throw GitHubError(status: status, message: message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    /// Borrows the token from the GitHub CLI, if it's installed and logged in.
    /// Runs off the main actor since it spawns a process and blocks on it.
    @concurrent
    static func ghToken() async -> String? {
        for path in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
        where FileManager.default.isExecutableFile(atPath: path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["auth", "token"]
            let stdout = Pipe()
            process.standardOutput = stdout
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                continue
            }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            let token = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if process.terminationStatus == 0, !token.isEmpty {
                return token
            }
        }
        return nil
    }
}
