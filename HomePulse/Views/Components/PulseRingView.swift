import SwiftUI

struct PulseRingView: View {
    let ratio: Double
    let reachable: Int
    let total: Int

    @State private var animatedRatio: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.4

    private var ringColor: Color {
        switch ratio {
        case 0.8...: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 14)
                .frame(width: 160, height: 160)

            // Glow
            Circle()
                .stroke(ringColor.opacity(glowOpacity), lineWidth: 20)
                .frame(width: 160, height: 160)
                .blur(radius: 10)

            // Filled ring
            Circle()
                .trim(from: 0, to: animatedRatio)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.6), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 4) {
                Text("\(Int(animatedRatio * 100))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .scaleEffect(pulseScale)
                Text("\(reachable)/\(total) online")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.7)) {
                animatedRatio = ratio
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
                glowOpacity = 0.7
            }
        }
        .onChange(of: ratio) { newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedRatio = newValue
            }
        }
    }
}
