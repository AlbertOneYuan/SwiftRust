// SwiftRust modifications © 2026 SwiftRust contributors.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import StoreKit

@available(iOS 17.0, *)
@MainActor
final class NativeTipStore: ObservableObject {
    static let shared = NativeTipStore()
    static let productIDs = (1...4).map { "swiftrust.airefactor.me.tip.tier\($0)" }
    @Published private(set) var products: [Product] = []
    @Published private(set) var loading = false
    @Published private(set) var purchasing = false
    @Published private(set) var message: String?
    private var updates: Task<Void, Never>?

    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                await self.complete(result)
            }
        }
        Task {
            for await result in StoreKit.Transaction.unfinished { await complete(result) }
        }
    }

    func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            products = try await Product.products(for: Self.productIDs)
                .filter { $0.type == .consumable }
                .sorted { $0.price < $1.price }
            message = products.count == Self.productIDs.count ? nil : NativeL("赞助暂不可用，请稍后重试。")
        } catch {
            message = NativeL("无法连接 App Store。")
        }
    }

    func purchase(_ product: Product) async {
        guard !purchasing, Self.productIDs.contains(product.id), product.type == .consumable else { return }
        purchasing = true; message = nil
        defer { purchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let result): await complete(result)
            case .pending: message = NativeL("购买正在等待批准，完成后会自动确认。")
            case .userCancelled: break
            @unknown default: message = NativeL("购买尚未完成，请稍后重试。")
            }
        } catch {
            message = NativeL("购买未完成，请稍后重试。")
        }
    }

    private func complete(_ result: VerificationResult<StoreKit.Transaction>) async {
        switch result {
        case .verified(let transaction):
            guard Self.productIDs.contains(transaction.productID), transaction.productType == .consumable else { return }
            if transaction.revocationDate == nil {
                message = NativeL("谢谢你的赞助！又有动力继续打磨了。")
            }
            await transaction.finish()
        case .unverified:
            message = NativeL("无法验证此次购买，请稍后重试。")
        }
    }
}

@available(iOS 17.0, *)
struct NativeTipJar: View {
    @ObservedObject private var store = NativeTipStore.shared
    @ObservedObject private var localization = NativeLocalization.shared
    private let names = ["投喂一颗橘子", "续一杯灵感", "给 Bug 放个假", "给开发者续航"]
    private let icons = ["sun.max", "cup.and.saucer", "ladybug", "battery.100percent.bolt"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image("AlbertAvatar").resizable().scaledToFill()
                        .frame(width: 36, height: 36).clipShape(Circle()).accessibilityHidden(true)
                    Text(NativeL("Albert · SwiftRust 开发者"))
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    HStack(spacing: 8) { contactLinks }
                        .buttonStyle(.plain).foregroundStyle(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                }
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill").foregroundStyle(.red)
                    Text(NativeL("你的赞助，让 SwiftRust 持续变好。"))
                        .font(.headline)
                }
                VStack(spacing: 10) {
                    ForEach(Array(NativeTipStore.productIDs.enumerated()), id: \.element) { index, id in
                        let product = store.products.first { $0.id == id }
                        Button {
                            if let product { Task { await store.purchase(product) } }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: icons[index]).font(.body).frame(width: 22)
                                Text(NativeL(names[index])).font(.headline)
                                Spacer(minLength: 8)
                                Text(product?.displayPrice ?? "—").font(.headline).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain).foregroundStyle(product == nil ? Color.secondary : Color.primary)
                        .disabled(product == nil || store.purchasing || !AppStore.canMakePayments)
                        .accessibilityIdentifier("native.tip.tier\(index + 1)")
                    }
                }
                if store.loading || store.purchasing { ProgressView().frame(maxWidth: .infinity) }
                if let message = store.message {
                    HStack(spacing: 10) {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                            .accessibilityIdentifier("native.tip.message")
                        Spacer(minLength: 0)
                        if store.products.count < NativeTipStore.productIDs.count {
                            Button(NativeL("重试")) { Task { await store.load() } }
                                .buttonStyle(.bordered).disabled(store.loading || store.purchasing)
                        }
                    }
                }
                if !AppStore.canMakePayments {
                    Text(NativeL("此设备暂不允许 App 内购买。")).font(.footnote).foregroundStyle(.secondary)
                }
                Text(NativeL("自愿支持，不影响功能。TestFlight 测试不扣款。"))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(NativeL("支持 SwiftRust"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { store.start(); await store.load() }
    }

    private var contactLinks: some View {
        Group {
            Link(destination: URL(string: "https://github.com/AlbertOneYuan/SwiftRust")!) {
                contactIcon(Image("GitHubBrand"))
            }.accessibilityLabel("GitHub").accessibilityIdentifier("native.tip.repository")
            Link(destination: NativeContact.social) {
                contactIcon(Image("XBrand"))
            }.accessibilityLabel("X · @kiwicatone").accessibilityIdentifier("native.tip.social")
            Link(destination: NativeContact.feedback) {
                contactIcon(Image(systemName: "envelope"))
            }.accessibilityLabel(NativeL("发送反馈"))
        }
    }

    private func contactIcon(_ image: Image) -> some View {
        image.resizable().scaledToFit().frame(width: 18, height: 18)
            .frame(width: 36, height: 36)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
