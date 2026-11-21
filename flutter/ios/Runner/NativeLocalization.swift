// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-21.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import Translation

private struct NativeLanguageResources: Decodable {
    let languages: [[String]]
    let sources: [String]
    let translations: [String: [String: String]]
}

final class NativeTranslationStore: @unchecked Sendable {
    static let shared = NativeTranslationStore()
    private let lock = NSLock()
    private let resources: NativeLanguageResources?
    private var cache: [String: [String: String]]
    private let cacheURL: URL?

    private init() {
        resources = Bundle.main.url(forResource: "NativeLanguages", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(NativeLanguageResources.self, from: $0) }
        cacheURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SwiftRust-Translations.json")
        cache = cacheURL.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([String: [String: String]].self, from: $0) } ?? [:]
    }
    var languages: [[String]] {
        let original = resources?.languages ?? [["en", "English"], ["zh-cn", "简体中文"]]
        let extra = UserDefaults.standard.dictionary(forKey: "native.apple-languages") as? [String: String] ?? [:]
        return original + extra.filter { code, _ in !original.contains { $0[0] == code } }
            .sorted { $0.value.localizedStandardCompare($1.value) == .orderedAscending }.map { [$0.key, $0.value] }
    }
    static func resolve(_ selection: String, preferred: [String], available: [String]) -> String {
        if !selection.isEmpty { return available.contains(selection) ? selection : "en" }
        for raw in preferred {
            let tag = raw.lowercased().replacingOccurrences(of: "_", with: "-")
            if tag.hasPrefix("zh") { return tag.contains("hant") || tag.contains("tw") || tag.contains("hk") ? "zh-tw" : "zh-cn" }
            if tag.hasPrefix("pt") { return tag.contains("br") ? "pt-br" : "pt-pt" }
            if available.contains(tag) { return tag }
            if let match = available.first(where: { $0 == tag.components(separatedBy: "-")[0] }) { return match }
        }
        return "en"
    }
    var language: String {
        Self.resolve(UserDefaults.standard.string(forKey: "native.language") ?? "",
                     preferred: Locale.preferredLanguages, available: languages.map { $0[0] })
    }
    static func appleIdentifier(_ code: String) -> String {
        switch code { case "zh-cn": return "zh-Hans"; case "zh-tw": return "zh-Hant"; case "kz": return "kk"; case "ge": return "ka"; default: return code }
    }
    func lookup(_ source: String, language: String? = nil) -> String {
        let code = language ?? self.language
        if code == "zh-cn" { return source }
        lock.lock(); let cached = cache[code]?[source]; lock.unlock()
        if let value = resources?.translations[code]?[source], !value.isEmpty { return value }
        return cached ?? source
    }
    func missing(for language: String) -> [String] {
        guard language != "zh-cn" else { return [] }
        lock.lock(); let translated = cache[language] ?? [:]; lock.unlock()
        return (resources?.sources ?? []).filter { source in
            translated[source] == nil && resources?.translations[language]?[source] == nil
        }
    }
    static func validTranslation(source: String, target: String) -> Bool {
        !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && source.components(separatedBy: "%@").count == target.components(separatedBy: "%@").count
    }
    func save(_ values: [String: String], language: String) throws {
        lock.lock()
        var updated = cache
        updated[language, default: [:]].merge(values.filter { Self.validTranslation(source: $0.key, target: $0.value) }) { _, new in new }
        lock.unlock()
        guard let cacheURL else { throw NativeCoreError(message: "无法保存翻译") }
        try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: cacheURL, options: .atomic)
        lock.lock(); cache = updated; lock.unlock()
    }
}

func NativeL(_ source: String, preserveAttribution: Bool = false) -> String {
    let value = NativeTranslationStore.shared.lookup(source)
    return preserveAttribution ? value : value.replacingOccurrences(of: "RustDesk", with: "SwiftRust", options: .caseInsensitive)
}
func NativeF(_ source: String, _ arguments: String...) -> String {
    let parts = NativeL(source).components(separatedBy: "%@")
    guard parts.count == arguments.count + 1 else { return source }
    return arguments.enumerated().reduce(parts[0]) { $0 + $1.element + parts[$1.offset + 1] }
}

@MainActor
final class NativeLocalization: ObservableObject {
    static let shared = NativeLocalization()
    @Published private(set) var revision = 0
    var selection: String { UserDefaults.standard.string(forKey: "native.language") ?? "" }
    var language: String { NativeTranslationStore.shared.language }
    func select(_ code: String) { UserDefaults.standard.set(code, forKey: "native.language"); revision += 1 }
    func refresh() { revision += 1 }
    @Published var translating = false
    @Published var translationMessage: String?
    @Published var retryTranslation = 0
    func loadAppleLanguages() async {
        guard #available(iOS 18.0, *) else { return }
        let languages = await LanguageAvailability().supportedLanguages
        var extra: [String: String] = [:]
        for language in languages {
            var code = language.minimalIdentifier.lowercased()
            if code.hasPrefix("zh") { code = language.script?.identifier == "Hant" ? "zh-tw" : "zh-cn" }
            let identifier = NativeTranslationStore.appleIdentifier(code)
            extra[code] = Locale(identifier: identifier).localizedString(forIdentifier: identifier) ?? identifier
        }
        UserDefaults.standard.set(extra, forKey: "native.apple-languages")
        revision += 1
    }
}

struct NativeLanguageSettings: View {
    @ObservedObject private var localization = NativeLocalization.shared
    var body: some View {
        Form {
            Section {
                HStack {
                    Label(NativeL("自动补全译文"), systemImage: "translate")
                    Spacer()
                    if localization.translating { ProgressView() }
                    else { Text("\(NativeTranslationStore.shared.missing(for: localization.language).count)").foregroundStyle(.secondary) }
                }.accessibilityIdentifier("native.automaticTranslation")
                if let message = localization.translationMessage {
                    Text(verbatim: message).font(.footnote).foregroundStyle(.secondary)
                    if !localization.translating {
                        Button(NativeL("重试翻译")) { localization.retryTranslation += 1 }
                    }
                }
            } footer: {
                Text(NativeL("优先使用内置译文，缺失的界面文字自动使用苹果翻译补全并保存在本机。首次可能需要下载语言包；苹果不支持的语言保留原文。不会翻译远程画面、主机名或输入内容。"))
            }
            Section {
                choice("", title: NativeL("跟随系统"))
                ForEach(NativeTranslationStore.shared.languages, id: \.first) { language in
                    choice(language[0], title: language[1])
                }
            } header: { Text(NativeL("语言")) }
        }
        .navigationTitle(NativeL("语言"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("native.languagePage")
        .task { await localization.loadAppleLanguages() }
    }
    private func choice(_ code: String, title: String) -> some View {
        Button { localization.select(code) } label: {
            HStack {
                Text(verbatim: title).foregroundStyle(.primary)
                Spacer()
                if localization.selection == code { Image(systemName: "checkmark").foregroundStyle(nativeRustBlue) }
            }.contentShape(Rectangle())
        }.accessibilityIdentifier("native.language.\(code.isEmpty ? "system" : code)")
    }
}

extension View {
    @ViewBuilder func nativeAutomaticTranslation() -> some View {
        if #available(iOS 18.0, *) { modifier(NativeAutomaticTranslation()) }
        else { self }
    }
}

@available(iOS 18.0, *)
private struct NativeAutomaticTranslation: ViewModifier {
    @ObservedObject private var localization = NativeLocalization.shared
    @State private var configuration: TranslationSession.Configuration?
    func body(content: Content) -> some View {
        content
            .task(id: localization.language + "-\(localization.retryTranslation)") {
                configuration = nil
                localization.translationMessage = nil
                localization.translating = false
                let language = localization.language
                guard !NativeTranslationStore.shared.missing(for: language).isEmpty else { return }
                let availability = await LanguageAvailability().status(from: Locale.Language(identifier: "zh-Hans"), to: Locale.Language(identifier: NativeTranslationStore.appleIdentifier(language)))
                guard !Task.isCancelled else { return }
                guard availability != .unsupported else {
                    localization.translationMessage = NativeL("苹果翻译暂不支持此语言。")
                    return
                }
                configuration = .init(source: Locale.Language(identifier: "zh-Hans"), target: Locale.Language(identifier: NativeTranslationStore.appleIdentifier(language)))
            }
            .translationTask(configuration) { session in
                let language = localization.language
                localization.translating = true
                defer { if localization.language == language { localization.translating = false } }
                do {
                    try Task.checkCancellation()
                    guard session.targetLanguage == Locale.Language(identifier: NativeTranslationStore.appleIdentifier(language)) else { return }
                    try await session.prepareTranslation()
                    let sources = NativeTranslationStore.shared.missing(for: language)
                    for start in stride(from: 0, to: sources.count, by: 40) {
                        try Task.checkCancellation()
                        let requests = sources[start..<min(start + 40, sources.count)].map { TranslationSession.Request(sourceText: $0, clientIdentifier: $0) }
                        let responses = try await session.translations(from: requests)
                        var values: [String: String] = [:]
                        for response in responses {
                            if let source = response.clientIdentifier { values[source] = response.targetText }
                        }
                        try Task.checkCancellation()
                        try NativeTranslationStore.shared.save(values, language: language)
                    }
                    localization.refresh()
                } catch is CancellationError { }
                catch {
                    if localization.language == language {
                        localization.translationMessage = NativeL("翻译未完成，可稍后重试。") + " " + error.localizedDescription
                    }
                }
            }
    }
}
