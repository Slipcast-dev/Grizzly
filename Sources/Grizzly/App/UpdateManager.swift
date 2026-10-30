import AppKit
import CryptoKit
import SwiftUI

/// Checks GitHub for a newer release, downloads its disk image inside the app and replaces the installed copy.
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    enum Phase: Equatable {
        case idle, checking, upToDate
        case available(ReleaseInfo)
        case downloading(Double)
        case installing
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    /// The sheet over the main window; opened by the check at launch when a new version is out.
    @Published var sheetVisible = false
    private var task: Task<Void, Never>?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    private var assetSuffix: String {
        #if arch(arm64)
        return "-arm64.dmg"
        #else
        return "-x64.dmg"
        #endif
    }

    /// `silent`: the check at launch. It says nothing when there is nothing new or the network is down.
    func check(silent: Bool) async {
        switch phase {
        case .checking, .downloading, .installing: return
        default: break
        }
        phase = .checking
        var request = URLRequest(url: UpdateCheck.latestReleaseURL, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Grizzly/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            if let release = try UpdateCheck.parse(data, assetSuffix: assetSuffix),
               UpdateCheck.isNewer(release.version, than: currentVersion) {
                phase = .available(release)
                if silent { sheetVisible = true }
            } else {
                phase = .upToDate
            }
        } catch {
            phase = silent ? .idle : .failed(L("Не удалось проверить обновления. Проверьте подключение к интернету."))
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    func install(_ release: ReleaseInfo) {
        guard case .available = phase else { return }
        phase = .downloading(0)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let dmg = try await self.download(release)
                self.phase = .installing
                let staged = try await Task.detached { try Self.stage(dmg: dmg, expected: release.version) }.value
                try self.replaceAndRelaunch(with: staged)
            } catch is CancellationError {
                self.phase = .idle
            } catch let error as UpdateError {
                self.phase = .failed(error.message)
            } catch {
                self.phase = .failed(L("Не удалось установить обновление."))
            }
        }
    }

    // MARK: Download

    private struct UpdateError: Error { let message: String }

    private static let maxDownload = 500.0 * 1024 * 1024

    private func download(_ release: ReleaseInfo) async throws -> URL {
        // A release without a published SHA-256 is never installed.
        guard release.sha256 != nil else { throw UpdateError(message: L("Не удалось скачать обновление.")) }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("grizzly-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent((release.assetName as NSString).lastPathComponent)
        FileManager.default.createFile(atPath: file.path, contents: nil)
        let out = try FileHandle(forWritingTo: file)
        defer { try? out.close() }

        var request = URLRequest(url: release.assetURL, timeoutInterval: 30)
        request.setValue("Grizzly/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError(message: L("Не удалось скачать обновление.")) }
        // Redirects must still end on a trusted GitHub host.
        guard let finalURL = response.url, UpdateCheck.isTrustedDownload(finalURL) else {
            throw UpdateError(message: L("Не удалось скачать обновление."))
        }
        let total = Double(response.expectedContentLength)
        if total > Self.maxDownload { throw UpdateError(message: L("Не удалось скачать обновление.")) }

        var hasher = SHA256()
        var chunk = Data()
        var received = 0.0
        var lastShown = 0.0
        for try await byte in bytes {
            chunk.append(byte)
            if chunk.count >= 1 << 16 {
                try out.write(contentsOf: chunk)
                hasher.update(data: chunk)
                received += Double(chunk.count)
                if received > Self.maxDownload { throw UpdateError(message: L("Не удалось скачать обновление.")) }
                chunk.removeAll(keepingCapacity: true)
                try Task.checkCancellation()
                if total > 0, received / total - lastShown > 0.01 {
                    lastShown = received / total
                    phase = .downloading(lastShown)
                }
            }
        }
        if !chunk.isEmpty { try out.write(contentsOf: chunk); hasher.update(data: chunk) }

        if let expected = release.sha256 {
            let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == expected else {
                try? FileManager.default.removeItem(at: dir)
                throw UpdateError(message: L("Контрольная сумма файла не совпала. Обновление не установлено."))
            }
        }
        return file
    }

    // MARK: Install

    /// Opens the disk image, copies Grizzly.app out of it and checks that it is the app and version announced.
    nonisolated private static func stage(dmg: URL, expected: String) throws -> URL {
        let work = dmg.deletingLastPathComponent()
        let mount = work.appendingPathComponent("mount")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        guard run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path, dmg.path]) else {
            throw UpdateError(message: L("Не удалось открыть образ диска с обновлением."))
        }
        defer { _ = run("/usr/bin/hdiutil", ["detach", "-force", mount.path]) }

        let source = mount.appendingPathComponent("Grizzly.app")
        let staged = work.appendingPathComponent("Grizzly.app")
        guard FileManager.default.fileExists(atPath: source.path),
              run("/usr/bin/ditto", [source.path, staged.path]) else {
            throw UpdateError(message: L("В образе диска нет Grizzly.app."))
        }
        let info = NSDictionary(contentsOf: staged.appendingPathComponent("Contents/Info.plist"))
        guard info?["CFBundleIdentifier"] as? String == "app.grizzly.Grizzly",
              UpdateCheck.normalized(info?["CFBundleShortVersionString"] as? String ?? "") == expected else {
            throw UpdateError(message: L("Скачанное приложение не совпало с анонсированной версией."))
        }
        _ = run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
        return staged
    }

    nonisolated private static func run(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    /// Quits Grizzly (asking about unsaved edits first); a helper script swaps the bundle once the app has exited and opens it again.
    private func replaceAndRelaunch(with staged: URL) throws {
        let destination = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: destination.deletingLastPathComponent().path) else {
            // No write access to the Applications folder: hand over the new app to install by hand.
            NSWorkspace.shared.activateFileViewerSelecting([staged])
            throw UpdateError(message: L("Нет прав на замену приложения. Новая версия показана в Finder: перетащите её в «Программы»."))
        }
        let state = AppState.shared
        guard state.confirmDiscard(state.documents.map(\.id)) else {
            phase = .idle
            return
        }
        let script = """
        for i in $(seq 1 300); do kill -0 "$1" 2>/dev/null || break; sleep 0.2; done
        kill -0 "$1" 2>/dev/null && exit 1
        ditto "$2" "$3.update" && rm -rf "$3" && mv "$3.update" "$3"
        open "$3"
        """
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), staged.path, destination.path]
        try helper.run()
        // The edits were just confirmed; quitting must not ask again.
        state.drafts.keys.forEach { state.discardDraft($0) }
        NSApp.terminate(nil)
    }
}

/// The update status with its buttons: used in Settings and in the sheet shown after the check at launch.
struct UpdateView: View {
    @ObservedObject var updater: UpdateManager
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch updater.phase {
            case .idle:
                EmptyView()
            case .checking:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Проверяем обновления…") }
            case .upToDate:
                Label("У вас установлена последняя версия.", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .available(let release):
                Label("Вышла новая версия \(release.version)", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .foregroundColor(theme.accent)
                Text("Установлена версия \(updater.currentVersion).").font(.callout).foregroundColor(.secondary)
                if !release.notes.isEmpty {
                    ScrollView {
                        Text(release.notes).font(.callout).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                }
                HStack {
                    Button("Скачать и установить") { updater.install(release) }.buttonStyle(.hoverFilled)
                    Button("Позже") { updater.sheetVisible = false }.buttonStyle(.hoverText)
                }
            case .downloading(let progress):
                Text("Загрузка обновления… \(Int(progress * 100))%")
                ProgressView(value: progress)
                Button("Отмена") { updater.cancel() }.buttonStyle(.hoverText)
            case .installing:
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Устанавливаем… Grizzly перезапустится.") }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundColor(.orange)
            }
        }
    }
}

/// Shown over the main window when the check at launch finds a newer version.
struct UpdateSheet: View {
    @ObservedObject var updater: UpdateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            UpdateView(updater: updater)
            HStack {
                Spacer()
                Button("Закрыть") { updater.sheetVisible = false }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
