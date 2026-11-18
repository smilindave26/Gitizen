import SwiftUI

@main
struct GitizenApp: App {
    @State private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            let count = store.newCount
            Image(systemName: count > 0 ? "bell.badge.fill" : "bell")
            if count > 0 {
                Text("\(count)")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct ContentView: View {
    let store: Store
    @State private var newRepo = ""
    @State private var listHeight: CGFloat = 0
    @State private var expanded: Set<String> = []
    @Environment(\.openURL) private var openURL

    private static let collapsedLimit = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.repos.isEmpty {
                Text("Add a repo to start watching.")
                    .foregroundStyle(.secondary)
            } else {
                // Size the scroll view to its content, up to a cap.
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(store.repos, id: \.self) { repo in
                            repoSection(repo)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .frame(height: min(listHeight, 420))
            }

            Divider()

            HStack {
                TextField("owner/repo", text: $newRepo)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(newRepo.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error = store.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }

            HStack {
                Button("Mark All Seen", action: store.markAllSeen)
                    .disabled(store.newCount == 0)
                Spacer()
                if let checked = store.lastChecked {
                    Text(checked.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isRefreshing)
                .help("Check now")
            }

            HStack {
                Toggle("Launch at login", isOn: Binding(
                    get: { store.launchAtLogin },
                    set: { store.setLaunchAtLogin($0) }))
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    @ViewBuilder
    private func repoSection(_ repo: String) -> some View {
        let state = store.states[repo]
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                link(repo, to: "https://github.com/\(repo)")
                    .fontWeight(.semibold)
                Spacer()
                if let state {
                    if state.newStars > 0 {
                        Text("+\(state.newStars)")
                            .foregroundStyle(.orange)
                    }
                    Label("\(state.stars)", systemImage: "star")
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.remove(repo)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help("Stop watching")
            }
            // New items have the highest numbers, so they sort first and survive the cap.
            let items = state?.items ?? []
            let isExpanded = expanded.contains(repo)
            let hidden = isExpanded ? 0 : max(0, items.count - Self.collapsedLimit)
            ForEach(items.dropLast(hidden)) { item in
                let isNew = state?.isNew(item) ?? false
                Button {
                    openURL(item.url)
                } label: {
                    Label {
                        HStack(spacing: 4) {
                            Text("#\(item.number) \(item.title)")
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(isNew ? .primary : .secondary)
                            if isNew {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    } icon: {
                        Image(systemName: item.isPR ? "arrow.triangle.pull" : "smallcircle.filled.circle")
                            .foregroundStyle(item.isPR ? .purple : .green)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            if items.count > Self.collapsedLimit {
                Button(isExpanded ? "Show less" : "\(hidden) more…") {
                    if isExpanded {
                        expanded.remove(repo)
                    } else {
                        expanded.insert(repo)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
            }
        }
    }

    private func link(_ title: String, to url: String) -> some View {
        Button(title) {
            if let url = URL(string: url) {
                openURL(url)
            }
        }
        .buttonStyle(.plain)
    }

    private func add() {
        if store.add(newRepo) {
            newRepo = ""
        }
    }
}
