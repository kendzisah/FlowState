import SwiftUI
import RevenueCat

/// Custom-designed paywall. Replaces the dashboard-managed RevenueCatUI paywall
/// so we can match the app's calm, energy-tinted visual language and surface
/// concrete benefits + a 3-day trial timeline.
///
/// Used at two entry points:
///   • Root gate (no close button) — see RootView.
///   • Onboarding step (with close affordance) — see Step06Paywall.
struct PaywallView: View {
    /// When non-nil, renders an "X" in the top-trailing corner. Used by onboarding
    /// to let users skip Pro — the root gate keeps re-presenting until they purchase.
    var onClose: (() -> Void)? = nil

    /// Fires after a successful purchase or a restore that resolves to the Pro
    /// entitlement. Callers update `store.entitled` / onboarding draft state.
    var onCompleted: (CustomerInfo) -> Void

    @Environment(\.palette) private var palette

    @State private var offering: Offering?
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var loadError: String?
    @State private var heroPulse = false
    @State private var arrowBounce = false

    var body: some View {
        ZStack(alignment: .bottom) {
            decorativeBackground

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        hero
                        benefits
                        trialTimeline
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, onClose == nil ? 48 : 56)
                    .padding(.bottom, 28)
                }

                purchasePanel
            }

            if let onClose {
                closeButton(onClose)
            }
        }
        .task { await loadOfferings() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
            // `source` distinguishes the two presentation contexts so
            // attribution dashboards can split paywall conversion rate
            // between the onboarding step and the root entitlement gate.
            Analytics.track(.paywallShown(
                source: onClose == nil ? "gate" : "onboarding",
                offeringsLoaded: offering != nil
            ))
            Analytics.screen("Paywall", properties: [
                "source": onClose == nil ? "gate" : "onboarding",
            ])
        }
    }

    // MARK: - Pinned purchase panel

    private var purchasePanel: some View {
        VStack(spacing: 14) {
            scrollHint
            packageSection
            primaryCTA
            footer
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)

                LinearGradient(
                    colors: [
                        palette.bgGradientEnd.opacity(0.0),
                        palette.bgGradientEnd.opacity(0.55),
                        palette.bgGradientEnd.opacity(0.85)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)

                Rectangle()
                    .fill(palette.border.opacity(0.45))
                    .frame(height: 0.5)
            }
        )
    }

    private var scrollHint: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(palette.parkedAccent)
            .shadow(color: palette.parkedAccent.opacity(0.45), radius: 8)
            .offset(y: arrowBounce ? 5 : -5)
            .frame(height: 20)
            .padding(.top, 14)
            .padding(.bottom, 4)
            .accessibilityLabel("Scroll for more content")
            .onAppear {
                guard !arrowBounce else { return }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    arrowBounce = true
                }
            }
    }

    // MARK: - Background

    private var decorativeBackground: some View {
        ZStack {
            DriftingFogBlob(
                size: 320, color: palette.energySteady,
                opacity: 0.18, phase: 0.10, durationSeconds: 22
            )
            .offset(x: -120, y: -260)

            DriftingFogBlob(
                size: 280, color: palette.energyLocked,
                opacity: 0.14, phase: 0.55, durationSeconds: 26
            )
            .offset(x: 140, y: -180)

            DriftingFogBlob(
                size: 360, color: palette.energyScattered,
                opacity: 0.10, phase: 0.30, durationSeconds: 24
            )
            .offset(x: 80, y: 220)

            DriftingFogBlob(
                size: 240, color: palette.captionPulse,
                opacity: 0.09, phase: 0.80, durationSeconds: 28
            )
            .offset(x: -100, y: 380)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.parkedAccent.opacity(0.35),
                                palette.parkedAccent.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 220)
                    .scaleEffect(heroPulse ? 1.05 : 0.95)

                ZStack {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(palette.energyFoggy.opacity(0.85))
                        .offset(x: -8, y: 6)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundStyle(palette.parkedAccent)
                        .offset(x: 16, y: -2)
                        .shadow(color: palette.parkedAccent.opacity(0.4), radius: 12)
                }

                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.parkedAccent.opacity(0.85))
                    .offset(x: -52, y: -58)

                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.parkedAccent.opacity(0.65))
                    .offset(x: 60, y: 50)
            }
            .frame(height: 180)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text("FLOWSTATE PRO")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2.4)
            }
            .foregroundStyle(palette.parkedAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(palette.parkedAccent.opacity(0.55), lineWidth: 1.1)
                    .background(
                        Capsule().fill(palette.parkedAccent.opacity(0.08))
                    )
            )

            VStack(spacing: 8) {
                Text("Built for the way\nyour brain actually works.")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Three days free. Cancel anytime.\nNo streaks, no shame, no rocket emojis.")
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(spacing: 10) {
            sectionLabel("WHAT YOU UNLOCK")

            VStack(spacing: 10) {
                BenefitRow(
                    icon: "bolt.fill",
                    accent: palette.energyLocked,
                    title: "Energy-matched task list",
                    subtitle: "Tell it your focus level. It hides anything that doesn't fit."
                )
                BenefitRow(
                    icon: "cloud.fill",
                    accent: palette.energyFoggy,
                    title: "Foggy rest mode",
                    subtitle: "Low-battery days get one gentle action — not a guilt-trip list."
                )
                BenefitRow(
                    icon: "timer",
                    accent: palette.energySteady,
                    title: "Right-sized focus timers",
                    subtitle: "5 minutes when scattered, 25 when steady, no cap when locked in."
                )
                BenefitRow(
                    icon: "tray.full.fill",
                    accent: palette.energyScattered,
                    title: "Park without shame",
                    subtitle: "Brain hijack mid-session? Park it. Come back when ready."
                )
                BenefitRow(
                    icon: "rectangle.on.rectangle.angled",
                    accent: palette.parkedAccent,
                    title: "Live Activity + Lock Screen",
                    subtitle: "The timer follows you out of the app, so the session stays alive."
                )
                BenefitRow(
                    icon: "leaf.fill",
                    accent: palette.captionPulse,
                    title: "Calm by design",
                    subtitle: "No streaks. No badges. No daily score to defend."
                )
            }
        }
    }

    // MARK: - Trial timeline

    private var trialTimeline: some View {
        VStack(spacing: 12) {
            sectionLabel("YOUR 3-DAY TRIAL")

            VStack(spacing: 0) {
                TimelineStop(
                    day: "TODAY",
                    icon: "lock.open.fill",
                    accent: palette.energyLocked,
                    title: "Everything unlocks.",
                    subtitle: "Try every energy level. See how the list shifts when you do."
                )

                TimelineConnector(color: palette.border)

                TimelineStop(
                    day: "DAY 2",
                    icon: "bell.fill",
                    accent: palette.energySteady,
                    title: "We remind you, then remind you again.",
                    subtitle: "Apple sends a heads-up the day before your trial converts. No surprise charges."
                )

                TimelineConnector(color: palette.border)

                TimelineStop(
                    day: "DAY 3",
                    icon: "hourglass",
                    accent: palette.energyScattered,
                    title: "Trial ends. You decide.",
                    subtitle: "Cancel from Settings any time before this — keeps Pro until the trial's last minute."
                )
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(palette.surface.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                            .stroke(palette.border.opacity(0.6), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Package

    @ViewBuilder
    private var packageSection: some View {
        if let error = loadError {
            VStack(spacing: 10) {
                Text("Couldn't load offers")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(error)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") {
                    _Concurrency.Task { await loadOfferings() }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.parkedAccent)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(palette.surface.opacity(0.6))
            )
        } else if let offering {
            VStack(spacing: 10) {
                sectionLabel("CHOOSE YOUR PLAN")
                HStack(spacing: 10) {
                    // Ascending price so the cheapest option anchors first
                    // and the higher-value plans read as upgrades from there.
                    ForEach(sortedPackages(offering.availablePackages), id: \.identifier) { pkg in
                        PackageRow(
                            package: pkg,
                            isSelected: pkg.identifier == selectedPackage?.identifier
                        ) {
                            selectedPackage = pkg
                            Analytics.track(.paywallPackageSelected(
                                packageID: pkg.identifier,
                                price: NSDecimalNumber(decimal: pkg.storeProduct.price).doubleValue,
                                currency: pkg.storeProduct.currencyCode ?? "USD",
                                hasTrial: pkg.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
                            ))
                        }
                    }
                }
            }
        } else {
            ProgressView()
                .tint(palette.parkedAccent)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        VStack(spacing: 10) {
            Button {
                _Concurrency.Task { await purchase() }
            } label: {
                ZStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(palette.onEnergy)
                    } else {
                        Text(ctaLabel)
                            .font(.system(size: 17, weight: .bold))
                            .tracking(-0.2)
                    }
                }
                .foregroundStyle(palette.onEnergy)
                .frame(maxWidth: .infinity, minHeight: Geometry.minTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: Geometry.buttonRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [palette.parkedAccent, palette.energySteady],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: palette.parkedAccent.opacity(0.45), radius: 18, x: 0, y: 8)
                )
            }
            .buttonStyle(.pressable)
            .disabled(isPurchasing || selectedPackage == nil)
            .opacity(selectedPackage == nil ? 0.55 : 1)

            Text(subPriceCopy)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                Link("Terms of Use", destination: Self.termsURL)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.paywallTermsTapped)
                    })
                Text("·")
                    .foregroundStyle(palette.textDimmed)
                Link("Privacy Policy", destination: Self.privacyURL)
                    .simultaneousGesture(TapGesture().onEnded {
                        Analytics.track(.paywallPrivacyTapped)
                    })
                Text("·")
                    .foregroundStyle(palette.textDimmed)
                Button {
                    _Concurrency.Task { await restore() }
                } label: {
                    HStack(spacing: 4) {
                        if isRestoring {
                            ProgressView().scaleEffect(0.6)
                        }
                        Text(isRestoring ? "Restoring…" : "Restore")
                    }
                }
                .disabled(isRestoring)
            }
            .font(.system(size: 11, weight: .semibold))
            .tint(palette.textSecondary)
        }
    }

    // Apple's Standard EULA (opted into via App Store Connect → App
    // Information). Privacy policy is FlowState-authored, hosted on
    // GitHub Pages.
    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private static let privacyURL = URL(string: "https://kendzisah.github.io/FlowState/privacy")!

    // MARK: - Close

    private func closeButton(_ action: @escaping () -> Void) -> some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    Analytics.track(.paywallDismissed(source: "onboarding", action: "x_tap"))
                    action()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(palette.surface.opacity(0.7))
                                .overlay(Circle().stroke(palette.border.opacity(0.5), lineWidth: 1))
                        )
                }
                .padding(.trailing, 18)
                .padding(.top, 12)
            }
            Spacer()
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 10) {
            Capsule().fill(palette.border).frame(width: 18, height: 1)
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .tracking(2.2)
                .foregroundStyle(palette.textSecondary)
            Capsule().fill(palette.border).frame(width: 18, height: 1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Copy helpers

    private var ctaLabel: String {
        guard let pkg = selectedPackage else { return "Start free trial" }
        if pkg.storeProduct.introductoryDiscount?.paymentMode == .freeTrial {
            return "Start 3-day free trial"
        }
        return "Subscribe — \(pkg.storeProduct.localizedPriceString)"
    }

    private var subPriceCopy: String {
        guard let pkg = selectedPackage else { return "Loading pricing…" }
        let price = pkg.storeProduct.localizedPriceString
        let period = periodLabel(for: pkg)
        if pkg.storeProduct.introductoryDiscount?.paymentMode == .freeTrial {
            return "Then \(price) / \(period). Cancel anytime."
        }
        return "\(price) / \(period). Cancel anytime."
    }

    /// Sort packages by `storeProduct.price` ascending so the cheapest plan
    /// renders first. We compare the raw `Decimal` directly — same units
    /// because RC normalizes per-locale currency to a single value.
    private func sortedPackages(_ packages: [Package]) -> [Package] {
        packages.sorted { $0.storeProduct.price < $1.storeProduct.price }
    }

    private func periodLabel(for pkg: Package) -> String {
        switch pkg.packageType {
        case .annual:   return "year"
        case .sixMonth: return "6 months"
        case .threeMonth: return "3 months"
        case .twoMonth: return "2 months"
        case .monthly:  return "month"
        case .weekly:   return "week"
        case .lifetime: return "lifetime"
        default:        return "period"
        }
    }

    // MARK: - Actions

    private func loadOfferings() async {
        loadError = nil
        let startedAt = Date()
        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            let latency = Int(Date().timeIntervalSince(startedAt) * 1000)
            await MainActor.run {
                self.offering = current
                self.selectedPackage = current?.annual
                    ?? current?.availablePackages.first
            }
            Analytics.track(.paywallOfferingsLoaded(
                packageCount: current?.availablePackages.count ?? 0,
                latencyMs: latency
            ))
        } catch {
            await MainActor.run {
                self.loadError = error.localizedDescription
            }
            Analytics.track(.paywallOfferingsFailed(error: error.localizedDescription))
            AnalyticsErrorReporter.report(error, context: "paywall.offerings")
        }
    }

    private func purchase() async {
        guard let pkg = selectedPackage else { return }
        let hasTrial = pkg.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
        let price = NSDecimalNumber(decimal: pkg.storeProduct.price).doubleValue
        let currency = pkg.storeProduct.currencyCode ?? "USD"
        Analytics.track(.paywallPurchaseInitiated(
            packageID: pkg.identifier,
            price: price,
            currency: currency,
            hasTrial: hasTrial
        ))
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            if result.userCancelled {
                Analytics.track(.paywallPurchaseCancelled(packageID: pkg.identifier))
            } else {
                Analytics.track(.paywallPurchaseCompleted(
                    packageID: pkg.identifier,
                    currency: currency,
                    isTrial: hasTrial
                ))
                onCompleted(result.customerInfo)
            }
        } catch {
            loadError = error.localizedDescription
            Analytics.track(.paywallPurchaseFailed(
                packageID: pkg.identifier,
                error: error.localizedDescription
            ))
            AnalyticsErrorReporter.report(error, context: "paywall.purchase", properties: [
                "package_id": pkg.identifier,
            ])
        }
    }

    private func restore() async {
        Analytics.track(.paywallRestoreInitiated)
        isRestoring = true
        defer { isRestoring = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            let entitled = info.entitlements[SubscriptionManager.proEntitlementID]?.isActive == true
            Analytics.track(.paywallRestoreCompleted(entitled: entitled))
            if entitled {
                onCompleted(info)
            }
        } catch {
            loadError = error.localizedDescription
            Analytics.track(.paywallRestoreFailed(error: error.localizedDescription))
            AnalyticsErrorReporter.report(error, context: "paywall.restore")
        }
    }
}

// MARK: - Benefit row

private struct BenefitRow: View {
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                .fill(palette.surface.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                        .stroke(palette.border.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

// MARK: - Timeline pieces

private struct TimelineStop: View {
    let day: String
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
            }
            .overlay(
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 1)
                    .frame(width: 36, height: 36)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(day)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2.0)
                    .foregroundStyle(accent)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct TimelineConnector: View {
    let color: Color
    var body: some View {
        HStack {
            Rectangle()
                .fill(color.opacity(0.6))
                .frame(width: 1, height: 18)
                .padding(.leading, 17)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Package row

private struct PackageRow: View {
    let package: Package
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.palette) private var palette

    private var hasTrial: Bool {
        package.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
    }

    private var trialDays: Int? {
        guard let intro = package.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return nil }
        let p = intro.subscriptionPeriod
        switch p.unit {
        case .day:   return p.value
        case .week:  return p.value * 7
        case .month: return p.value * 30
        case .year:  return p.value * 365
        @unknown default: return nil
        }
    }

    private var title: String {
        switch package.packageType {
        case .annual:     return "Annual"
        case .sixMonth:   return "6 Months"
        case .threeMonth: return "3 Months"
        case .twoMonth:   return "2 Months"
        case .monthly:    return "Monthly"
        case .weekly:     return "Weekly"
        case .lifetime:   return "Lifetime"
        default:          return package.storeProduct.localizedTitle
        }
    }

    private var perPeriod: String {
        switch package.packageType {
        case .annual:   return "/year"
        case .sixMonth: return "/6 mo"
        case .threeMonth: return "/3 mo"
        case .twoMonth: return "/2 mo"
        case .monthly:  return "/month"
        case .weekly:   return "/week"
        case .lifetime: return ""
        default:        return ""
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(package.storeProduct.localizedPriceString)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(perPeriod.isEmpty ? " " : perPeriod)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textDimmed)

                // Reserve consistent space across cards so the row doesn't
                // jitter when only some packages have a trial / badge.
                ZStack {
                    if package.packageType == .annual {
                        Text("BEST VALUE")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(palette.onEnergy)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(palette.parkedAccent))
                    } else if let days = trialDays {
                        Text("\(days)-day trial")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    } else if hasTrial {
                        Text("Free trial")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        // Empty placeholder keeps card heights uniform.
                        Text(" ")
                            .font(.system(size: 10))
                    }
                }
                .frame(height: 16)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                    .fill(palette.surface.opacity(isSelected ? 0.85 : 0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geometry.cardRadius, style: .continuous)
                            .stroke(
                                isSelected ? palette.parkedAccent : palette.border.opacity(0.6),
                                lineWidth: isSelected ? 1.6 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? palette.parkedAccent.opacity(0.25) : .clear,
                        radius: 14, x: 0, y: 6
                    )
            )
        }
        .buttonStyle(.pressable)
    }
}
