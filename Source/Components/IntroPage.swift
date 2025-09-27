import CoreImage.CIFilterBuiltins
import QuartzCore
import SwiftUI

struct Card: Identifiable, Equatable {
    let id: String = UUID().uuidString
    let image: ImageResource
    let title: LocalizedStringResource
}

let cards: [Card] = [
    .init(image: .twoBeers, title: ""),
]

struct IntroPage: View {
    @State private var activeCard: Card? = cards.first
    @State private var scrollView: UIScrollView?
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()
    @State private var initialAnimation: Bool = false
    @State private var titleProgress: CGFloat = 0
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AmbientBackground()
                    .animation(.easeInOut(duration: 1), value: activeCard)
                VStack(spacing: 40) {
                    Spacer()
                    InfiniteScrollView(collection: cards) { card in
                        CarouselCardView(card)
                    } uiScrollView: {
                        scrollView = $0
                    } onScroll: {
                        updateActiveCard()
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .containerRelativeFrame(.vertical) { value, _ in
                        value * 0.45
                    }
                    .visualEffect { [initialAnimation] content, proxy in
                        content
                            .offset(y: !initialAnimation ? -(proxy.size.height + 200) : 0)
                    }

                    VStack(spacing: 4) {
                        Text(.onboardingHeadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.secondary)
                            .blurOpacityEffect(initialAnimation)

                        Group {
                            Text(.appName)
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .textRenderer(TitleTextRenderer(progress: titleProgress))
                        }
                        .padding(.bottom, 12)
                        Text(.onboardingSubheadline)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.secondary)
                            .blurOpacityEffect(initialAnimation)
                    }
                    VStack(spacing: 12) {
                        Button(.continue, action: {
                            Task {
                                do { try await appModel.createAnonymousUser() } catch {
                                    print("error")
                                }
                            }
                        })
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .blurOpacityEffect(initialAnimation)
                        .frame(width: geometry.size.width * 0.8, height: 48)
                    }
                }
            }
            .safeAreaPadding(15)
            .onReceive(timer) { _ in
                if let scrollView {
                    scrollView.contentOffset.x += 0.35
                }
            }
            .task {
                try? await Task.sleep(for: .seconds(0.35))
                withAnimation(.smooth(duration: 0.75, extraBounce: 0)) {
                    initialAnimation = true
                }
                withAnimation(.smooth(duration: 2.5, extraBounce: 0).delay(0.3)) {
                    titleProgress = 1
                }
            }
        }
    }

    func updateActiveCard() {
        if let currentScrollOffset = scrollView?.contentOffset.x {
            let activeIndex = Int((currentScrollOffset / 220).rounded()) % cards.count
            guard activeCard?.id != cards[activeIndex].id else { return }
            activeCard = cards[activeIndex]
        }
    }

    @ViewBuilder
    private func AmbientBackground() -> some View {
        GeometryReader {
            let size = $0.size

            ZStack {
                ForEach(cards) { card in
                    Image(card.image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .frame(width: size.width, height: size.height)
                        .opacity(activeCard?.id == card.id ? 1 : 0)
                }

                Rectangle()
                    .fill(.black.opacity(0.45))
                    .ignoresSafeArea()
            }
            .compositingGroup()
            .blur(radius: 90, opaque: true)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func CarouselCardView(_ card: Card) -> some View {
        GeometryReader {
            let size = $0.size

            Image(card.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .bottom) {
                    VariableBlurView(maxBlurRadius: 10, direction: .blurredBottomClearTop)
                        .frame(height: 140)
                        .overlay {
                            VStack {
                                Text(card.title)
                                    .font(.system(.title3, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                            }
                        }
                }
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.4), radius: 10, x: 1, y: 0)
        }
        .frame(width: 220)
        .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content, phase in
            content
                .offset(y: phase == .identity ? -10 : 0)
                .rotationEffect(.degrees(phase.value * 5), anchor: .bottom)
        }
    }
}

extension View {
    func blurOpacityEffect(_ show: Bool) -> some View {
        blur(radius: show ? 0 : 2)
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.9)
    }
}

struct TitleTextRenderer: TextRenderer, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        let slices = layout.flatMap(\.self).flatMap(\.self)

        for (index, slice) in slices.enumerated() {
            let sliceProgressIndex = CGFloat(slices.count) * progress
            let sliceProgress = max(min(sliceProgressIndex / CGFloat(index + 1), 1), 0)
            ctx.addFilter(.blur(radius: 5 - (5 * sliceProgress)))
            ctx.opacity = sliceProgress
            ctx.translateBy(x: 0, y: 5 - (5 * sliceProgress))
            ctx.draw(slice, options: .disablesSubpixelQuantization)
        }
    }
}
