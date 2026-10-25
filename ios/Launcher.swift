// Velocity - Launcher.swift
// Constantin Clerc (c22dev) - 0.1
import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import os

func nspKind(_ url: URL) -> String? {
    guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? h.close() }
    guard let d = try? h.read(upToCount: 0x10000), d.count >= 0x10, d.prefix(4) == Data("PFS0".utf8) else { return nil }
    let u32 = { (o: Int) in Int(d[o]) | Int(d[o + 1]) << 8 | Int(d[o + 2]) << 16 | Int(d[o + 3]) << 24 }
    let start = 0x10 + u32(4) * 0x18, end = start + u32(8)
    guard end <= d.count else { return nil }
    let names = String(decoding: d[start..<end], as: UTF8.self).split(separator: "\0")
    guard let tik = names.first(where: { $0.hasSuffix(".tik") }), let tid = UInt64(tik.prefix(16), radix: 16) else { return nil }
    guard [0x010040E0116B8, 0x010040E0116B9].contains(tid >> 12) else { return "other" }
    switch tid & 0xFFF {
    case 0: return "base"
    case 0x800: return "update"
    default: return "dlc"
    }
}

let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let configURL = docsURL.appendingPathComponent("config.json")

final class Settings: ObservableObject {
    @Published var prewarm = true
    @Published var rumble = true
    @Published var spatial = true
    @Published var backgroundCompile = true
    @Published var handheld = true
    var extra: [String: Any] = [:]
    private var autosave: AnyCancellable?

    init() {
        defer {
            autosave = objectWillChange.debounce(for: .milliseconds(150), scheduler: RunLoop.main).sink { [weak self] in try? self?.save() }
        }
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        extra = json
        prewarm = json["prewarm_pipelines"] as? Bool ?? true
        rumble = json["rumble"] as? Bool ?? true
        spatial = json["spatial_audio"] as? Bool ?? true
        backgroundCompile = json["background_compile"] as? Bool ?? true
        handheld = json["handheld"] as? Bool ?? true
    }

    func save() throws {
        var json = extra
        json["prewarm_pipelines"] = prewarm
        json["rumble"] = rumble
        json["spatial_audio"] = spatial
        json["background_compile"] = backgroundCompile
        json["handheld"] = handheld
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: configURL)
    }
}

struct GameFile: Identifiable {
    let id: String
    let name: String
    var optional = false
    var present: Bool {
        let path = docsURL.appendingPathComponent(name).path
        var dir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &dir) else { return false }
        return !dir.boolValue || !((try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []).isEmpty
    }

    func status(_ found: Bool) -> String {
        guard found else { return optional ? "none" : "missing" }
        let attrs = try? FileManager.default.attributesOfItem(atPath: docsURL.appendingPathComponent(name).path)
        guard attrs?[.type] as? FileAttributeType != .typeDirectory, let size = attrs?[.size] as? Int64 else { return "found" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

let gameFiles = [
    GameFile(id: "Base Game", name: "base.nsp"),
    GameFile(id: "Update 1.0.9", name: "update.nsp"),
    GameFile(id: "Console Keys", name: "prod.keys"),
    GameFile(id: "Firmware", name: "Firmware"),
]

final class Files: ObservableObject {
    static let shared = Files()
    @Published var present: [String: Bool] = [:]
    @Published var copying: String?
    @Published var error: String?

    var ready: Bool { gameFiles.allSatisfy { $0.optional || present[$0.name] == true } }

    func scan() {
        let fm = FileManager.default
        for n in (try? fm.contentsOfDirectory(atPath: docsURL.path)) ?? [] where n.lowercased().hasSuffix(".nsp") && !gameFiles.contains(where: { $0.name == n }) && !n.hasPrefix("dlc") {
            let url = docsURL.appendingPathComponent(n)
            let dest = docsURL.appendingPathComponent(Files.target(for: url))
            if dest != url && !fm.fileExists(atPath: dest.path) { try? fm.moveItem(at: url, to: dest) }
        }
        present = Dictionary(uniqueKeysWithValues: gameFiles.map { ($0.name, $0.present) })
    }

    func copy(_ urls: [URL]) {
        error = nil
        DispatchQueue.global(qos: .userInitiated).async {
            for url in urls {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let name = Files.target(for: url)
                DispatchQueue.main.async { self.copying = name }
                let dest = docsURL.appendingPathComponent(name)
                do {
                    if FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.removeItem(at: dest) }
                    try FileManager.default.copyItem(at: url, to: dest)
                } catch {
                    DispatchQueue.main.async { self.error = "\(url.lastPathComponent): \(error.localizedDescription)" }
                }
            }
            DispatchQueue.main.async {
                self.copying = nil
                self.scan()
            }
        }
    }

    static func target(for url: URL) -> String {
        let n = url.lastPathComponent.lowercased()
        if n.hasSuffix(".keys") { return "prod.keys" }
        if url.hasDirectoryPath { return "Firmware" }
        if n.hasSuffix(".nsp") {
            switch nspKind(url) {
            case "base": return "base.nsp"
            case "update": return "update.nsp"
            case "dlc": return "dlc-\(url.lastPathComponent)"
            case "other": return url.lastPathComponent
            default: break
            }
            if n.contains("upd") || n.contains("update") { return "update.nsp" }
            if n.contains("base") || n.contains("sonic") || n.contains("colo") { return "base.nsp" }
        }
        return url.lastPathComponent
    }
}

struct LauncherView: View {
    @StateObject private var s = Settings()
    @ObservedObject private var files = Files.shared
    @State private var error: String?
    @State private var picking = false
    @State private var memory = os_proc_available_memory()
    @Environment(\.scenePhase) private var phase
    let play: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                Text("Velocity").font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
                if files.ready && files.copying == nil {
                    if let error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
                    playButton
                } else {
                    importView
                }
                Text("proudly made by c22dev").font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            Form {
                if !files.ready { gameFilesSection }
                Section {
                    Toggle("Vibration", isOn: $s.rumble)
                } footer: {
                    Text("Any controller works (Switch Pro, Joy-Con, DualSense, Xbox...), with touch controls when none is connected")
                }
                Section {
                    Toggle("Spatial audio", isOn: $s.spatial)
                } footer: {
                    Text("Plays the game's 5.1 mix in spatial audio. Choose Fixed or Head Tracked for AirPods in Control Center")
                }
                Section {
                    Picker("Console mode", selection: $s.handheld) {
                        Text("Docked (1080p)").tag(false)
                        Text("Handheld (720p)").tag(true)
                    }
                } footer: {
                    Text("Handheld renders at 720p: lighter on the GPU and battery")
                }
                Section {
                    Toggle("Prewarm pipelines", isOn: $s.prewarm)
                    Toggle("Background shader compiling", isOn: $s.backgroundCompile)
                } footer: {
                    Text("Builds the game's graphics pipelines in the background at startup")
                }
                Section {
                    HStack {
                        Text("Memory available")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(memory), countStyle: .memory))
                                .foregroundStyle(.secondary).monospacedDigit()
                            if memory < 4 << 30 {
                                Text("4 GB is recommended: close other apps").font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                }
                if files.ready { gameFilesSection }
            }
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $picking, allowedContentTypes: [.data, .folder], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { files.copy(urls) }
        }
        .onAppear { files.scan() }
        .onChange(of: phase) { _, p in if p == .active { files.scan() } }
        .task {
            while !Task.isCancelled {
                memory = os_proc_available_memory()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    var gameFilesSection: some View {
        Section("Game files") {
            ForEach(gameFiles) { f in
                HStack {
                    Image(systemName: files.present[f.name] == true ? "checkmark.circle.fill" : (f.optional ? "minus.circle" : "xmark.circle.fill"))
                        .foregroundStyle(files.present[f.name] == true ? .green : (f.optional ? .secondary : .red))
                    Text(f.id)
                    Spacer()
                    Text(f.status(files.present[f.name] == true)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder var importView: some View {
        VStack(spacing: 12) {
            if let name = files.copying {
                ProgressView()
                Text("Copying \(name)…").font(.callout)
            } else {
                Button("Import game files") { picking = true }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                Text("Import prod.keys, the base game and update 1.0.9 .nsp files and the Firmware folder (+DLC)/put them in On My iPhone")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if let e = files.error { Text(e).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
        }
    }

    @ViewBuilder var playButton: some View {
        let button = Button(action: start) {
            Text("Play").font(.title3.weight(.semibold)).frame(maxWidth: 220)
        }
        .controlSize(.large)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
        #else
        button.buttonStyle(.borderedProminent)
        #endif
    }

    func start() {
        do { try s.save() } catch { self.error = "Could not save settings: \(error.localizedDescription)"; return }
        play()
    }
}

private final class LauncherDoor {
    var host: UIViewController?
    var done: (() -> Void)?
    func close(then next: @escaping () -> Void) {
        guard done != nil else { return }
        done = nil
        host?.view.isHidden = true
        host?.dismiss(animated: false)
        next()
    }
}

@_cdecl("nx_show_launcher")
public func nxShowLauncher(_ viewController: UnsafeMutableRawPointer, _ play: @convention(c) () -> Void, _ controller: @convention(c) () -> Void) {
    let parent = Unmanaged<UIViewController>.fromOpaque(viewController).takeUnretainedValue()
    let door = LauncherDoor()
    door.done = {}
    let host = UIHostingController(rootView: LauncherView(play: { door.close(then: { play() }) }))
    door.host = host
    host.modalPresentationStyle = .fullScreen
    parent.present(host, animated: false)
}
