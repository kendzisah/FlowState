import SwiftUI

struct OnbRoutineTagGrid: View {
    let options: [RoutineOption]
    @Binding var selection: Set<RoutineOption>

    @Environment(\.palette) private var palette

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(options) { opt in
                Button {
                    if selection.contains(opt) {
                        selection.remove(opt)
                    } else {
                        selection.insert(opt)
                    }
                } label: {
                    let isSelected = selection.contains(opt)
                    HStack(spacing: 8) {
                        Text(opt.emoji)
                            .font(.system(size: 18))
                        Text(opt.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? palette.onEnergy : palette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? palette.energySteady : palette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? palette.energySteady : palette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(selection.contains(opt) ? .isSelected : [])
            }
        }
    }
}

/// Reusable scaffold for the three routine screens (S10–S12).
struct RoutineStepScaffold: View {
    let chip: String
    let chipIcon: String
    let title: String
    let subtitle: String
    let options: [RoutineOption]
    @Binding var selection: Set<RoutineOption>
    let onSuggest: () -> Void
    let onContinue: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer().frame(height: 70)

            HStack(spacing: 6) {
                Image(systemName: chipIcon)
                    .font(.system(size: 12, weight: .bold))
                Text(chip)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
            }
            .foregroundStyle(palette.energySteady)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(palette.surface))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(AppFont.titleTracking)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                OnbRoutineTagGrid(options: options, selection: $selection)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 10) {
                OnbSecondaryButton(title: "Suggest for me", systemImage: "sparkles", action: onSuggest)
                OnbPrimaryButton(
                    title: selection.isEmpty ? "Choose at least one to begin" : "Continue with my routines",
                    enabled: !selection.isEmpty,
                    action: onContinue
                )
            }
        }
        .padding(.horizontal, Geometry.horizontalPadding)
        .padding(.bottom, 20)
    }
}
