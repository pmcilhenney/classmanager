import SwiftUI

struct LoadingSpinnerView: View {
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 0
    @State private var rotation3: Double = 0
    @State private var glowPulse: Bool = false
    @State private var appear: Bool = false
    // When true, show a full-screen blurred backdrop behind the spinner
    var withBackdrop: Bool = false

    var body: some View {
        ZStack {
            // MARK: - Orbit 1 (Primary Ring)
            Circle()
                .trim(from: 0.0, to: 0.8)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.1),
                            Color.white.opacity(0.9),
                            Color.blue.opacity(0.3)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 170, height: 170)
                .rotation3DEffect(.degrees(15), axis: (x: 1, y: 0, z: 0))
                .rotationEffect(.degrees(rotation1))
                .blur(radius: 0.8)
                .shadow(color: .blue.opacity(0.5), radius: 5)
                .animation(.linear(duration: 2.5).repeatForever(autoreverses: false), value: rotation1)

            // MARK: - Orbit 2 (Secondary Ring)
            Circle()
                .trim(from: 0.0, to: 0.8)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.cyan.opacity(0.2),
                            Color.white.opacity(0.8),
                            Color.blue.opacity(0.2)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 190, height: 190)
                .rotation3DEffect(.degrees(-25), axis: (x: 0, y: 1, z: 0))
                .rotationEffect(.degrees(rotation2))
                .blur(radius: 1.0)
                .shadow(color: .blue.opacity(0.4), radius: 4)
                .animation(.linear(duration: 3.0).repeatForever(autoreverses: false), value: rotation2)

            // MARK: - Orbit 3 (Counter-rotating Energy Trail)
            Circle()
                .trim(from: 0.0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.7),
                            Color.blue.opacity(0.3),
                            Color.cyan.opacity(0.2)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 210, height: 210)
                .rotation3DEffect(.degrees(35), axis: (x: 0.5, y: 1, z: 0))
                .rotationEffect(.degrees(-rotation3))
                .blur(radius: 1.2)
                .shadow(color: .cyan.opacity(0.5), radius: 6)
                .animation(.linear(duration: 4.0).repeatForever(autoreverses: false), value: rotation3)

            // MARK: - Center Academy Logo
            Image("gcems_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .shadow(color: .blue.opacity(glowPulse ? 0.6 : 0.2), radius: glowPulse ? 15 : 5)
                .scaleEffect(appear ? 1 : 0.9)
                .opacity(appear ? 1 : 0)
                .animation(.easeInOut(duration: 0.8), value: appear)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
        }
        .frame(width: 220, height: 220)
        .background(Color.clear)
        .overlay(
            Group {
                if withBackdrop {
                    Color.clear
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                } else { EmptyView() }
            }
        )
        .onAppear {
            withAnimation {
                appear = true
            }
            glowPulse = true
            rotation1 = 360
            rotation2 = 360
            rotation3 = 360
        }
    }
}

#Preview {
    ZStack {
        RadialGradient(
            colors: [.black, .blue.opacity(0.4)],
            center: .center,
            startRadius: 50,
            endRadius: 500
        )
        .ignoresSafeArea()

        LoadingSpinnerView()
    }
}
