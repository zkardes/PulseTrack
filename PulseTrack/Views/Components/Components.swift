import SwiftUI

// MARK: - Card container

struct Card<Content: View>: View {
    var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .padding(Theme.Layout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Layout.cornerRadius, style: .continuous)
                    .stroke(Theme.Colors.stroke, lineWidth: 1)
            )
    }
}

// MARK: - Circular progress ring (Whoop-style)

struct MetricRing: View {
    var progress: Double           // 0...1
    var color: Color
    var lineWidth: CGFloat = 14
    var value: String
    var label: String
    var size: CGFloat = 170

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.7), color], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 8)
                .animation(.easeInOut(duration: 0.8), value: progress)

            VStack(spacing: 2) {
                Text(value)
                    .font(Theme.Typography.metric(size * 0.24))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(label.uppercased())
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .tracking(1.5)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat pill

struct StatPill: View {
    var icon: String
    var value: String
    var label: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label.uppercased())
                .font(Theme.Typography.label)
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.Colors.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Section header

struct SectionHeader: View {
    var title: String
    var body: some View {
        Text(title.uppercased())
            .font(Theme.Typography.label)
            .foregroundStyle(Theme.Colors.textSecondary)
            .tracking(2)
    }
}

// MARK: - Horizontal bar

struct MiniBar: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color)
                    .frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: height)
    }
}
