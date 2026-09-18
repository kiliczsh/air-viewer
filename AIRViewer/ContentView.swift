import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var store = ReportStore()
    @State private var showingImporter = false

    var body: some View {
        NavigationSplitView {
            Sidebar(store: store)
                .navigationTitle("AIR Viewer")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Import report", systemImage: "square.and.arrow.down") { showingImporter = true }
                    }
                }
        } content: {
            EntryList(store: store)
                .navigationTitle(store.scope.title)
        } detail: {
            Inspector(store: store)
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls): if let url = urls.first { store.importReport(from: url) }
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .alert(store.reimportCandidate == nil ? "Couldn’t import report" : "Re-import report", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            if store.reimportCandidate != nil {
                Button("Re-Import") {
                    store.errorMessage = nil
                    showingImporter = true
                }
            }
            Button("OK", role: .cancel) {
                store.errorMessage = nil
                store.reimportCandidate = nil
            }
        } message: { Text(store.errorMessage ?? "Unknown error") }
    }
}

private struct Sidebar: View {
    @Bindable var store: ReportStore
    var body: some View {
        List(selection: $store.scope) {
            Section("Explore") {
                ForEach(ReportScope.allCases) { scope in
                    Label {
                        HStack { Text(scope.title); Spacer(); Text("\(store.count(for: scope))").foregroundStyle(.secondary).monospacedDigit() }
                    } icon: { Image(systemName: scope.icon).foregroundStyle(scope.tint) }
                    .tag(scope)
                }
            }
            if !store.recentReports.isEmpty {
                Section("Recent Reports") {
                    ForEach(store.recentReports) { savedReport in
                        Button {
                            store.reopen(savedReport)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(savedReport.filename)
                                    .lineLimit(1)
                                Text(savedReport.importedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Forget Report", role: .destructive) {
                                store.forget(savedReport)
                            }
                        }
                    }
                }
            }
            if let report = store.report {
                Section("Report") {
                    LabeledContent("Requests", value: "\(report.requestCount)")
                    LabeledContent("Imported", value: report.importedAt.formatted(date: .abbreviated, time: .shortened))
                    Text(report.filename).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            if store.report == nil {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Private by design", systemImage: "lock.fill").font(.caption.weight(.semibold))
                    Text("Content stays in memory. Recent Reports saves only references to the files you chose.").font(.caption2).foregroundStyle(.secondary)
                }.padding(12)
            }
        }
    }
}

private struct EntryList: View {
    @Bindable var store: ReportStore
    var body: some View {
        Group {
            if store.report == nil {
                ContentUnavailableView { Label("Import an Apple Intelligence Report", systemImage: "brain.head.profile") } description: { Text("Choose an Apple_Intelligence_Report.json export to explore it locally.") }
            } else if store.filteredEntries.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else {
                List(store.filteredEntries, selection: $store.selectedID) { entry in
                    EntryRow(entry: entry).tag(entry.id)
                }.listStyle(.plain)
            }
        }
        .searchable(text: $store.searchText, prompt: "Search content, model, tools…")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Menu("Role", systemImage: "person.crop.circle") {
                    Picker("Role", selection: $store.roleFilter) {
                        Text("All roles").tag("All")
                        ForEach(store.availableRoles, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                if !store.searchText.isEmpty || store.roleFilter != "All" {
                    Button("Reset filters", systemImage: "arrow.counterclockwise") { store.searchText = ""; store.roleFilter = "All" }
                }
            }
        }
    }
}

private struct EntryRow: View {
    let entry: ReportEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: entry.scope.icon).foregroundStyle(entry.scope.tint)
                Text(entry.title).font(.headline).lineLimit(1)
                Spacer()
                if let role = entry.role { Text(role.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary) }
            }
            Text(entry.preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            if !entry.tags.isEmpty { Text(entry.tags.prefix(4).joined(separator: " · ")).font(.caption).foregroundStyle(entry.scope.tint).lineLimit(1) }
        }.padding(.vertical, 5)
    }
}

private struct Inspector: View {
    @Bindable var store: ReportStore
    var body: some View {
        if let entry = store.selectedEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(entry.scope.title, systemImage: entry.scope.icon).font(.subheadline.weight(.semibold)).foregroundStyle(entry.scope.tint)
                        Text(entry.title).font(.title2.bold())
                        if !entry.tags.isEmpty { Text(entry.tags.joined(separator: "  ·  ")).font(.caption).foregroundStyle(.secondary) }
                    }
                    GroupBox("Content") { Text(entry.content).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled).font(.body) }
                    GroupBox("Source JSON") {
                        ScrollView(.horizontal) { Text(entry.rawJSON).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                    }
                }.padding(24).frame(maxWidth: 760, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Select an entry", systemImage: "sidebar.right", description: Text("Choose a result to inspect its content and source JSON."))
        }
    }
}

#Preview { ContentView() }
