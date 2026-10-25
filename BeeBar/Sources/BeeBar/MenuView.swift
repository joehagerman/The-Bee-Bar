import SwiftUI
import AppKit

struct MenuView: View {
    @ObservedObject var store: BeeStore
    @State private var hoveredCardId: String? = nil

    var body: some View {
        if store.showingSettings {
            SettingsView(store: store)
        } else {
            VStack(spacing: 0) {
                // Top Header Bar
                headerBar
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                // Sync Progress Bar (if syncing)
                if store.isSyncing {
                    syncProgressBar
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }

                Divider()

                // Content Area: List of Recent Transcripts & Summaries
                if store.conversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }

                Divider()

                // Bottom Footer
                footerBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .frame(width: 380, height: 530)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 8) {
            // App Branding & Icon
            HStack(spacing: 6) {
                Text("🐝")
                    .font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bee Menu Bar")
                        .font(.system(size: 14, weight: .bold))
                    connectionStatusPill
                }
            }

            Spacer()

            // Header Action Buttons
            HStack(spacing: 6) {
                // Open in Finder Button
                Button(action: {
                    store.openFolderInFinder()
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open Bee Exports folder in Finder")

                // Sync Now Button
                Button(action: {
                    Task {
                        await store.performSync()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: store.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .rotationEffect(store.isSyncing ? .degrees(360) : .degrees(0))
                            .animation(store.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isSyncing)

                        Text(store.isSyncing ? "Syncing..." : "Sync")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.isSyncing)
                .help("Sync new Bee records immediately")

                // Settings Button
                Button(action: {
                    store.showingSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Preferences & Settings")
            }
        }
    }

    private var connectionStatusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(store.isConnected ? Color.green : Color.orange)
                .frame(width: 6, height: 6)

            Text(store.isConnected ? (store.config.endpoint.contains("8787") ? "Proxy Active" : "Online") : "Checking...")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Sync Progress Bar
    private var syncProgressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: store.syncProgress, total: 1.0)
                .progressViewStyle(.linear)
                .tint(Color.amber)

            HStack {
                Text(store.syncMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(Int(store.syncProgress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.amber)
            }
        }
    }

    // MARK: - Conversations List
    private var conversationsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RECENT SUMMARIES & TRANSCRIPTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(store.conversations.count) records")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(store.conversations.prefix(25)) { item in
                        conversationCard(item: item)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Item Card
    private func conversationCard(item: BeeConversationItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title & Timestamp
            HStack(alignment: .top, spacing: 6) {
                Text("🎙️")
                    .font(.system(size: 13))

                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Spacer()

                Text(item.relativeDateString)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Badges: turns, duration, tag
            HStack(spacing: 6) {
                if let dur = item.formattedDuration {
                    badge(text: "⏱️ \(dur)", color: .secondary.opacity(0.15))
                }
                if let turns = item.utteranceCount, turns > 0 {
                    badge(text: "💬 \(turns) turns", color: .secondary.opacity(0.15))
                }
                if let tag = item.tags?.first {
                    badge(text: "🏷️ \(tag)", color: Color.amber.opacity(0.2), textColor: Color.amber)
                }
            }

            // Summary Snippet
            if let snippet = item.summarySnippet, !snippet.isEmpty {
                Text(snippet.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            // Quick Actions: Summary, Transcript, Finder
            HStack(spacing: 6) {
                // Open Markdown Summary
                Button(action: {
                    store.openFile(atPath: item.markdownPath(storageDir: store.config.storageDir))
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                        Text("Summary (.md)")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Open formatted Markdown Executive Summary")

                // Open Verbatim Transcript
                Button(action: {
                    store.openFile(atPath: item.transcriptTextPath(storageDir: store.config.storageDir))
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                        Text("Transcript (.txt)")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Open verbatim audio transcript text")

                Spacer()

                // Show in Finder
                Button(action: {
                    store.revealInFinder(atPath: item.transcriptTextPath(storageDir: store.config.storageDir))
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .help("Reveal files in Finder")
            }
            .padding(.top, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(hoveredCardId == item.id ? Color(NSColor.controlBackgroundColor).opacity(0.8) : Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hoveredCardId == item.id ? Color.amber.opacity(0.4) : Color.gray.opacity(0.15), lineWidth: 1)
        )
        .onHover { isHovered in
            if isHovered {
                hoveredCardId = item.id
            } else if hoveredCardId == item.id {
                hoveredCardId = nil
            }
        }
    }

    private func badge(text: String, color: Color, textColor: Color = .secondary) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("🐝")
                .font(.system(size: 40))
            Text("No Bee Records Synced")
                .font(.system(size: 14, weight: .semibold))
            Text("Click Sync to fetch your latest Bee conversations, executive summaries, and transcripts.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Sync Now") {
                Task {
                    await store.performSync()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.amber)
            Spacer()
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            Text("Last synced: \(store.lastSyncTimeText)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button("Open Folder") {
                store.openFolderInFinder()
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color.amber)

            Text("•")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
}
