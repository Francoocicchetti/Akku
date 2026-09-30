import SwiftUI
import AppKit

// Each hosting window controls its own animation, including a closed menu popover.
struct WindowVisibilityReader: NSViewRepresentable {
    @Binding var visible: Bool
    func makeNSView(context: Context) -> WatchView {
        let view = WatchView(); view.changed = { value in DispatchQueue.main.async { self.visible = value } }; return view
    }
    func updateNSView(_ view: WatchView, context: Context) {}
    final class WatchView: NSView {
        var changed: ((Bool) -> Void)?
        private var tokens: [NSObjectProtocol] = []
        private var reported: Bool?
        private func report(_ value: Bool) {
            guard reported != value else { return }
            reported = value; changed?(value)
        }
        private func updateVisibility() {
            guard let window else { report(false); return }
            report(window.isVisible && !window.isMiniaturized && !NSApp.isHidden &&
                   (window.occlusionState.contains(.visible) || window.isKeyWindow))
        }
        override func viewDidMoveToWindow() {
            tokens.forEach { NotificationCenter.default.removeObserver($0) }; tokens = []
            guard let window else { report(false); return }
            for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didBecomeKeyNotification,
                         NSWindow.didResignKeyNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification] {
                tokens.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in self?.updateVisibility() })
            }
            tokens.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in self?.report(false) })
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification,
                         NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
                tokens.append(NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) { [weak self] _ in self?.updateVisibility() })
            }
            updateVisibility()
        }
        deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
    }
}

struct AkkuAnimationSchedule: TimelineSchedule {
    let active: Bool
    let origin: Date
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnySequence<Date> {
        AnySequence {
            var next: Date? = startDate
            return AnyIterator<Date> {
                guard let value = next else { return nil }
                next = active && mode != .lowFrequency ? EnergyPolicy.nextAnimationDate(after: value, origin: origin) : nil
                return value
            }
        }
    }
}
struct AkkuAvatar: View {
    let percent: Double?
    let mood: AkkuMood
    let animate: Bool
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var animationStart = Date()
    var body: some View {
        TimelineView(AkkuAnimationSchedule(active: animate && !reduceMotion && visible, origin: animationStart)) { timeline in
            let phase = EnergyPolicy.animationPhase(at: timeline.date, origin: animationStart)
            let t = animate && !reduceMotion && visible && phase < 2 ? phase : 0
            let movement = sin(.pi * t / 2)
            Canvas { context, size in
                context.scaleBy(x: size.width / 300, y: size.height / 350)
                let dark = Color(red: 0.18, green: 0.21, blue: 0.22)
                let energy = max(0, min(100, percent ?? 0))
                let tired = mood == .low || mood == .exhausted || mood == .breakTime || mood == .evening
                let green = mood == .exhausted ? Color(red: 0.94, green: 0.39, blue: 0.25) : mood == .low ? Color(red: 0.95, green: 0.68, blue: 0.20) : Color(red: 0.16, green: 0.87, blue: 0.31)
                let bob = sin(t * .pi * 2) * (mood == .full ? 7 : tired ? 2 : 4) * movement
                func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) { context.fill(Path(ellipseIn: CGRect(x: x,y: y,width: w,height: h)), with: .color(color)) }
                func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double, _ color: Color) { context.fill(Path(roundedRect: CGRect(x: x,y: y,width: w,height: h), cornerRadius: r), with: .color(color)) }
                func line(_ points: [CGPoint], _ color: Color, _ width: Double) { var p=Path(); p.addLines(points); context.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width,lineCap: .round,lineJoin: .round)) }
                oval(89, 329, 124, 8, .black.opacity(0.06))
                context.translateBy(x: 0, y: bob)
                if mood == .charging {
                    oval(52, 50, 196, 260, green.opacity(0.04 + movement * 0.05))
                }
                // Battery, ears and polarity marks preserve Akku's supplied visual identity.
                oval(43, 163, 64, 71, dark); oval(194, 163, 64, 71, dark)
                oval(52, 173, 47, 52, .white); oval(202, 173, 47, 52, .white)
                oval(58, 179, 40, 46, green); oval(202, 179, 40, 46, green)
                line([CGPoint(x:65,y:200),CGPoint(x:80,y:200)],dark,5)
                line([CGPoint(x:216,y:200),CGPoint(x:231,y:200)],dark,5)
                line([CGPoint(x:223.5,y:192.5),CGPoint(x:223.5,y:207.5)],dark,5)
                rect(123, 24, 55, 39, 14, dark)
                var tuft=Path(); tuft.move(to: CGPoint(x:148,y:33)); tuft.addQuadCurve(to:CGPoint(x:132,y:6),control:CGPoint(x:146,y:12)); tuft.addQuadCurve(to:CGPoint(x:130,y:22),control:CGPoint(x:130,y:12)); tuft.addQuadCurve(to:CGPoint(x:148,y:33),control:CGPoint(x:141,y:22)); tuft.move(to:CGPoint(x:152,y:33)); tuft.addQuadCurve(to:CGPoint(x:171,y:7),control:CGPoint(x:155,y:13)); tuft.addQuadCurve(to:CGPoint(x:169,y:22),control:CGPoint(x:171,y:14)); tuft.addQuadCurve(to:CGPoint(x:152,y:33),control:CGPoint(x:159,y:21)); context.fill(tuft,with:.color(dark))
                rect(140, 34, 21, 5, 2.5, green)
                rect(86, 46, 130, 258, 29, dark)
                rect(96, 57, 110, 204, 19, .white)
                for i in 0..<3 {
                    let y = 66.0 + Double(i) * 38
                    rect(103, y, 96, 32, 4, green.opacity(0.10))
                    let bottom = y + 32, cutoff = 174 - 108 * energy / 100
                    let height = max(0, min(32, bottom - cutoff))
                    if height > 0 { rect(103, bottom - height, 96, height, 4, green) }
                }
                var bolt=Path(); bolt.move(to:CGPoint(x:174,y:66)); bolt.addLines([CGPoint(x:132,y:125),CGPoint(x:150,y:125),CGPoint(x:139,y:170),CGPoint(x:179,y:113),CGPoint(x:158,y:113)]); bolt.closeSubpath()
                context.stroke(bolt,with:.color(.white),style:StrokeStyle(lineWidth:6,lineJoin:.round)); context.fill(bolt,with:.color(dark))
                var face=Path(); face.move(to:CGPoint(x:151,y:189)); face.addCurve(to:CGPoint(x:99,y:225),control1:CGPoint(x:103,y:144),control2:CGPoint(x:73,y:204)); face.addCurve(to:CGPoint(x:114,y:294),control1:CGPoint(x:75,y:259),control2:CGPoint(x:93,y:293)); face.addLine(to:CGPoint(x:186,y:294)); face.addCurve(to:CGPoint(x:202,y:225),control1:CGPoint(x:210,y:294),control2:CGPoint(x:224,y:260)); face.addCurve(to:CGPoint(x:151,y:189),control1:CGPoint(x:226,y:201),control2:CGPoint(x:197,y:144)); face.closeSubpath()
                context.fill(face,with:.color(.white)); context.stroke(face,with:.color(dark),style:StrokeStyle(lineWidth:10,lineJoin:.round))
                let blink = t >= 0.75 && t < 1
                if tired || blink {
                    var lids=Path(); lids.move(to:CGPoint(x:113,y:216)); lids.addQuadCurve(to:CGPoint(x:129,y:216),control:CGPoint(x:121,y:tired ? 219:214)); lids.move(to:CGPoint(x:173,y:216)); lids.addQuadCurve(to:CGPoint(x:189,y:216),control:CGPoint(x:181,y:tired ? 219:214)); context.stroke(lids,with:.color(dark),style:StrokeStyle(lineWidth:4,lineCap:.round))
                } else {
                    oval(113,205,17,20,dark); oval(172,205,17,20,dark)
                    if mood == .full { oval(116,207,5,5,.white); oval(175,207,5,5,.white) }
                }
                line([CGPoint(x:138,y:233),CGPoint(x:143,y:237)],dark,5)
                line([CGPoint(x:159,y:233),CGPoint(x:154,y:237)],dark,5)
                if mood == .charging { oval(139,248,24,12 + abs(sin(t * 4))*7*movement,dark) }
                else if mood == .breakTime { oval(143,247,16,21 + 5*movement,dark) }
                else {
                    var smile=Path(); smile.move(to:CGPoint(x:122,y:253)); smile.addQuadCurve(to:CGPoint(x:180,y:253),control:CGPoint(x:151,y:mood == .exhausted ? 244 : tired ? 266:283)); context.stroke(smile,with:.color(dark),style:StrokeStyle(lineWidth:7,lineCap:.round))
                }
                rect(124,296,54,29,9,dark)
                line([CGPoint(x:144,y:311),CGPoint(x:159,y:311)],.white,5)
                line([CGPoint(x:151.5,y:303.5),CGPoint(x:151.5,y:318.5)],.white,5)
                if mood == .full || mood == .charging {
                    let y=80 + sin(t * 2)*5*movement
                    line([CGPoint(x:246,y:y-7),CGPoint(x:246,y:y+7)],green,3)
                    line([CGPoint(x:239,y:y),CGPoint(x:253,y:y)],green,3)
                }
                if mood == .breakTime || mood == .evening {
                    context.draw(Text("z").font(.system(size:18,weight:.medium,design:.rounded)).foregroundColor(dark.opacity(0.55)),at:CGPoint(x:246,y:115 - sin(t)*3))
                    context.draw(Text("z").font(.system(size:12,weight:.medium,design:.rounded)).foregroundColor(dark.opacity(0.35)),at:CGPoint(x:259,y:95 - sin(t)*3))
                }
                if mood == .away { context.draw(Image(systemName:"location.fill"),at:CGPoint(x:246,y:103)) }
            }
        }.aspectRatio(300 / 350, contentMode: .fit)
            .background(WindowVisibilityReader(visible: $visible))
            .onChange(of: visible) { if $0 { animationStart = Date() } }
            .onChange(of: mood) { _ in animationStart = Date() }
            .onChange(of: animate) { if $0 { animationStart = Date() } }
            .onChange(of: reduceMotion) { if !$0 { animationStart = Date() } }
            .accessibilityElement(children: .ignore).accessibilityLabel(label)
    }
}
struct BuddyHero: View {
    @ObservedObject var model: BatteryModel
    @State private var details = false
    var body: some View {
        let companion = model.companionContext
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Palette.mint).frame(width: 6, height: 6)
                    Text(companion.mood.name(model.language)).font(.system(size: 11, weight: .medium))
                }
                Spacer()
                Text(model.contextDate, style: .time).font(.system(size: 11)).monospacedDigit().foregroundStyle(Palette.secondary)
            }
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(model.snapshot.percent.map { "\(Int($0.rounded()))" } ?? "—")
                            .font(.system(size: 60, weight: .medium, design: .default)).tracking(-4).monospacedDigit()
                        Text("%").font(.system(size: 25, weight: .regular)).foregroundStyle(Palette.mint)
                    }.accessibilityLabel(model.t("Battery", "Batería") + " " + (model.snapshot.percent.map { "\(Int($0))%" } ?? "—"))
                    Text(companion.message(model.language)).font(.system(size: 17, weight: .medium)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                AkkuAvatar(percent: model.snapshot.percent, mood: companion.mood,
                           animate: model.animateBuddy && !model.lowPower && !model.emergency,
                           label: "Akku · " + companion.mood.name(model.language))
                    .frame(width: 140, height: 164)
                    .background(Circle().fill(Palette.mint.opacity(0.06)).frame(width: 146, height: 146))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line)
                    Capsule().fill(Palette.mint).frame(width: geo.size.width * max(0, min(100, model.snapshot.percent ?? 0)) / 100)
                }
            }.frame(height: 5).accessibilityHidden(true)
            HStack(spacing: 8) {
                Label(model.location.status(model.language), systemImage: "location").lineLimit(2)
                Spacer(minLength: 2)
                Button { details.toggle() } label: {
                    Image(systemName: details ? "minus.circle" : "plus.circle").font(.system(size: 19))
                }.buttonStyle(.plain).foregroundStyle(Palette.mint).accessibilityLabel(model.t("How are we doing?", "¿Cómo vamos?"))
            }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
            if companion.mood == .breakTime {
                Button(model.t("A little later", "Un poco después")) { model.quietCompanion() }.buttonStyle(.bordered)
            } else if companion.mood == .low || companion.mood == .exhausted {
                Button(model.t("Feed Akku", "Alimentar a Akku")) { model.statusMessage = model.t("My food is electricity. Connect your MacBook charger and I'll recharge with you.", "Mi alimento es la electricidad. Conecta el cargador del MacBook y recargaré contigo.") }.buttonStyle(.bordered)
            }
            if details {
                Divider()
                Detail(text: model.t("About \(Int(model.usageSession.seconds / 60)) minutes of recent computer use. A 5-minute idle period or sleep starts a new session.", "Unos \(Int(model.usageSession.seconds / 60)) minutos de uso reciente. Cinco minutos de inactividad o el reposo inician otra sesión."))
                Detail(text: model.t("I use battery, time, open apps and the location you allow. I can't read your mind, messages or screen contents.", "Uso batería, hora, apps abiertas y la ubicación que permites. No leo tus pensamientos, mensajes ni el contenido de la pantalla."))
                if let activity = model.currentActivity { Detail(text: model.t("Activity from your plan or app context: ", "Actividad según tu plan o contexto de apps: ") + activity.name(model.language)) }
                Button(model.t("Quiet company for one hour", "Compañía en silencio por una hora")) { model.quietCompanion(); details = false }.buttonStyle(.bordered)
            }
        }.padding(18).background(Palette.peach).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}
