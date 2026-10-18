import SwiftUI

struct RemoteContentView: View {
    @EnvironmentObject private var store: RemoteContentStore
    @State private var searchText = ""

    private var filteredFiles: [RemoteContentFile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.installedFiles }
        return store.installedFiles.filter { file in
            file.name.localizedCaseInsensitiveContains(query)
                || file.slug.localizedCaseInsensitiveContains(query)
                || file.fileName.localizedCaseInsensitiveContains(query)
                || file.category.localizedCaseInsensitiveContains(query)
                || file.localRelativePath.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppSearchField(text: $searchText, prompt: "Search remote files", clearLabel: "Clear")
                Divider()
                List {
                    Section {
                        RemoteContentStatusCard()
                    }

                    if store.installedFiles.isEmpty && !store.isBusy {
                        emptyState
                            .listRowSeparator(.hidden)
                    } else if filteredFiles.isEmpty && !store.isBusy {
                        searchEmptyState
                            .listRowSeparator(.hidden)
                    } else {
                        Section("Installed files") {
                            ForEach(filteredFiles) { file in
                                RemoteContentFileRow(file: file)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Remote Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.syncIfPossible(force: true)
                    } label: {
                        if store.isBusy {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isBusy)
                    .accessibilityLabel("Check updates")
                }
            }
            .onAppear {
                store.loadLocalState()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.and.arrow.down")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text("No remote files installed")
                .font(.headline)
            Text("Tap Check updates after publishing content from the PC panel.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: AppTheme.emptyIconSize, weight: .light))
                .foregroundStyle(.secondary)
            Text("No files found")
                .font(.headline)
            Text("Try another name, slug, category, or filename.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }
}

private struct RemoteContentStatusCard: View {
    @EnvironmentObject private var store: RemoteContentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AppRowIcon(
                    systemName: store.isBusy ? "arrow.triangle.2.circlepath" : "icloud.fill",
                    tint: store.isBusy ? Color(red: 0.26, green: 0.72, blue: 1.0) : AppTheme.accent,
                    symbolSize: 18,
                    frameSize: 42
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.statusText)
                        .font(.headline)
                    Text(store.detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("v\(store.remoteVersion)")
                        .font(.headline.weight(.black))
                        .foregroundColor(AppTheme.accent)
                    Text(store.installedFiles.count == 1 ? "1 file" : "\(store.installedFiles.count) files")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let progress = store.progress, store.isBusy {
                ProgressView(value: progress)
                    .tint(AppTheme.accent)
            }

            HStack {
                Button {
                    store.syncIfPossible(force: true)
                } label: {
                    Label("Check updates", systemImage: "arrow.clockwise.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy)

                if let lastChecked = store.lastChecked {
                    Text(lastChecked.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct RemoteContentFileRow: View {
    let file: RemoteContentFile

    var body: some View {
        HStack(spacing: 12) {
            AppRowIcon(systemName: icon, tint: tint, symbolSize: 17, frameSize: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(file.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("v\(file.version)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(tint)
                }

                Text(file.localRelativePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let description = file.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(file.category.isEmpty ? "files" : file.category)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(tint)
                    .lineLimit(1)
                Text(file.displaySize)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        if file.mimeType?.hasPrefix("image/") == true { return "photo.fill" }
        if file.mimeType?.contains("json") == true { return "curlybraces" }
        if file.mimeType?.hasPrefix("text/") == true { return "doc.text.fill" }
        return "doc.fill"
    }

    private var tint: Color {
        switch file.category.lowercased() {
        case "images", "image", "media":
            return Color(red: 0.26, green: 0.72, blue: 1.0)
        case "configs", "config":
            return .green
        default:
            return AppTheme.accent
        }
    }
}
