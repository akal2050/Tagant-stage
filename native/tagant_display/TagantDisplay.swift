// TAGANT stage display — iPad two-screen bridge for Godot.
//
// iPad screen  : native control panel (this file).
// TV/projector : the Godot view, moved onto the external-display scene.
// Panel <-> Godot talk over UDP on localhost (Godot listens on 47100, panel on 47101).
//
// Works without a paid Apple account: no entitlements needed.

import UIKit
import Network
import AVFoundation
import CoreText

// MARK: - Entry point (called from shim.mm, which Godot's plugin loader calls at launch)

@_cdecl("tagant_display_start_swift")
public func tagantDisplayStartSwift() {
    DispatchQueue.main.async {
        TagantDisplay.shared.start()
    }
}

// MARK: - External display scene delegate (iOS 27+ scene accessory path)

@objc(TagantExternalSceneDelegate)
final class TagantExternalSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        TagantDisplay.shared.attach(to: ws)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        TagantDisplay.shared.detach(from: scene)
    }
}

// MARK: - Host view controller on the TV

final class StageHostViewController: UIViewController {
    weak var stageView: UIView?
    /// Max width in real pixels that Godot renders on the TV (keeps the A16 cool on 4K screens).
    var maxPixelWidth: CGFloat = 1600

    override func loadView() {
        let v = UIView()
        v.backgroundColor = .black
        view = v
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutStage()
    }

    func layoutStage() {
        guard let stage = stageView, stage.superview === view else { return }
        // Godot renders at (view bounds in points) x (main screen scale).
        // We want exactly the TV's pixel size (capped), so shrink the bounds and scale back up.
        let s = TagantDisplay.shared.mainScale
        let e = view.window?.windowScene?.screen.scale ?? 1
        let W = view.bounds.width, H = view.bounds.height
        guard W > 0, H > 0 else { return }
        let r = min(1, maxPixelWidth / (W * e))
        let k = (e * r) / s                     // bounds factor
        stage.transform = .identity
        stage.bounds = CGRect(x: 0, y: 0, width: W * k, height: H * k)
        stage.center = CGPoint(x: W / 2, y: H / 2)
        stage.transform = CGAffineTransform(scaleX: 1 / k, y: 1 / k)
        stage.setNeedsLayout()
    }
}

// MARK: - Manager

// Breadcrumbs: each step is written to Documents/tagant_trail.txt *before* it happens.
// If the app dies, the next launch shows where it stopped, on the iPad remote.
enum Trail {
    static var url: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("tagant_trail.txt") }
    static var previous: String = ""
    static func begin() {
        previous = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? "".write(to: url, atomically: true, encoding: .utf8)
        mark("launch")
    }
    static func mark(_ s: String) {
        let line = "\(Date().timeIntervalSince1970.rounded()) \(s)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.synchronize(); try? h.close()
        } else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }
    static func markCleanExit() { mark("ok") }
}

final class TagantDisplay {
    static let shared = TagantDisplay()

    private(set) var mainScale: CGFloat = 2
    private var mainWindow: UIWindow?
    private var godotVC: UIViewController?
    private var originalSuperview: UIView?
    private weak var originalParentVC: UIViewController?

    private var externalWindow: UIWindow?
    private var externalScene: UIWindowScene?
    private var hostVC: StageHostViewController?

    private var panel: ControlPanel?
    private let link = GodotLink()
    private var setupTimer: Timer?
    private var accessoryRegistered = false
    private var stageReady = false              // true a few seconds after Godot's first frames
    private var pendingScene: UIWindowScene?    // a TV that connected before the stage was ready

    func start() {
        Trail.begin()
        UIApplication.shared.isIdleTimerDisabled = true
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in Trail.markCleanExit() }

        NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { [weak self] note in
            guard let ws = note.object as? UIWindowScene else { return }
            if ws.session.role == .windowExternalDisplayNonInteractive {
                // Let the system finish connecting, then take the scene.
                DispatchQueue.main.async { self?.attach(to: ws) }
            }
        }
        NotificationCenter.default.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] note in
            guard let sc = note.object as? UIScene else { return }
            self?.detach(from: sc)
        }

        link.onMessage = { [weak self] msg in self?.panel?.handle(godotMessage: msg) }
        link.start()

        // Godot's view controller appears a moment after launch: poll until it is in a window.
        setupTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if self.trySetup() { t.invalidate() }
        }
    }

    private func findGodotVC() -> UIViewController? {
        guard let cls = NSClassFromString("GDTAppDelegateService") as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString("viewController")
        guard cls.responds(to: sel), let r = cls.perform(sel) else { return nil }
        return r.takeUnretainedValue() as? UIViewController
    }

    private func trySetup() -> Bool {
        guard let vc = findGodotVC(), let win = vc.view.window else { return false }
        godotVC = vc
        mainWindow = win
        mainScale = win.screen.scale
        originalSuperview = vc.view.superview
        originalParentVC = vc.parent

        Trail.mark("godot view ready")
        let p = ControlPanel(link: link)
        p.translatesAutoresizingMaskIntoConstraints = true
        p.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        win.addSubview(p)
        panel = p
        layoutPanel()

        registerAccessoryIfAvailable(on: win.rootViewController ?? vc)

        // Give the world time to load before touching the TV (heavy scenes load on the main thread).
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.attachPendingIfAny()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            self?.stageReady = true
            self?.attachPendingIfAny()
        }
        return true
    }

    private func attachPendingIfAny() {
        guard stageReady else { return }
        if let ws = pendingScene, ws.activationState != .unattached {
            attach(to: ws)
            return
        }
        // iOS 26 and earlier: the external scene may already be connected.
        for sc in UIApplication.shared.connectedScenes {
            if let ws = sc as? UIWindowScene, ws.session.role == .windowExternalDisplayNonInteractive, externalScene == nil {
                attach(to: ws)
            }
        }
    }

    private func registerAccessoryIfAvailable(on vc: UIViewController) {
        guard !accessoryRegistered else { return }
        #if TAGANT_SCENE_ACCESSORY
        if #available(iOS 27.0, *) {
            let config = UISceneConfiguration(name: nil, sessionRole: .windowExternalDisplayNonInteractive)
            config.delegateClass = TagantExternalSceneDelegate.self
            let accessory = UISceneAccessory.externalNonInteractive(sceneConfiguration: config)
            _ = vc.registerSceneAccessory(accessory)
            accessoryRegistered = true
        }
        #endif
    }

    func attach(to ws: UIWindowScene) {
        // Never move the stage while Godot is still starting / loading the world:
        // remember the TV and attach once the stage is ready.
        guard stageReady, UIApplication.shared.applicationState == .active, let vc = godotVC else {
            pendingScene = ws
            return
        }
        guard externalScene !== ws else { return }
        pendingScene = nil
        Trail.mark("attach TV \(Int(ws.screen.bounds.width))x\(Int(ws.screen.bounds.height)) scale \(ws.screen.scale)")
        let host = StageHostViewController()
        let w = UIWindow(windowScene: ws)
        w.rootViewController = host
        w.isHidden = false
        externalWindow = w
        externalScene = ws
        hostVC = host

        // Move Godot's view controller *with* its view (UIKit forbids moving a
        // controller's root view on its own: UIViewControllerHierarchyInconsistency).
        let stage = vc.view!
        Trail.mark("move controller")
        vc.willMove(toParent: nil)
        stage.removeFromSuperview()
        vc.removeFromParent()
        host.addChild(vc)
        stage.autoresizingMask = []
        host.view.addSubview(stage)
        vc.didMove(toParent: host)
        host.stageView = stage
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        host.layoutStage()

        layoutPanel()
        Trail.mark("attached")
        link.send("screen:tv")
    }

    func detach(from scene: UIScene) {
        if pendingScene === scene { pendingScene = nil }
        guard let ws = externalScene, ws === scene else { return }
        if let vc = godotVC, let sup = originalSuperview {
            let stage = vc.view!
            vc.willMove(toParent: nil)
            stage.removeFromSuperview()
            vc.removeFromParent()
            if let parent = originalParentVC { parent.addChild(vc) }
            stage.transform = .identity
            stage.frame = sup.bounds
            stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            sup.addSubview(stage)
            if let parent = originalParentVC { vc.didMove(toParent: parent) }
            stage.setNeedsLayout()
        }
        externalWindow?.isHidden = true
        externalWindow = nil
        externalScene = nil
        hostVC = nil
        layoutPanel()
        link.send("screen:ipad")
    }

    var tvConnected: Bool { externalScene != nil }

    private func layoutPanel() {
        guard let p = panel, let win = mainWindow else { return }
        p.setMode(tv: tvConnected)
        // TV connected: the whole iPad is the remote. iPad alone: no panel, the karaoke is touched directly.
        p.frame = win.bounds
        p.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        p.isHidden = !tvConnected
        win.bringSubviewToFront(p)
    }
}

// MARK: - UDP link to Godot

final class GodotLink {
    var onMessage: ((String) -> Void)?
    private var conn: NWConnection?
    private var listener: NWListener?
    private let q = DispatchQueue(label: "tagant.link")

    func start() {
        let c = NWConnection(host: "127.0.0.1", port: 47100, using: .udp)
        c.start(queue: q)
        conn = c

        if let l = try? NWListener(using: .udp, on: 47101) {
            l.newConnectionHandler = { [weak self] nc in
                nc.start(queue: self?.q ?? .main)
                self?.receive(on: nc)
            }
            l.start(queue: q)
            listener = l
        }
    }

    private func receive(on nc: NWConnection) {
        nc.receiveMessage { [weak self] data, _, _, err in
            if let d = data, let s = String(data: d, encoding: .utf8) {
                DispatchQueue.main.async { self?.onMessage?(s) }
            }
            if err == nil { self?.receive(on: nc) }
        }
    }

    func send(_ s: String) {
        conn?.send(content: s.data(using: .utf8), completion: .contentProcessed { _ in })
    }
}

// MARK: - Fonts of the laptop version (copied into the app bundle by the plugin)

enum TFont {
    static var registered: [String: String] = [:]      // file name -> PostScript name
    static func register() {
        guard registered.isEmpty, let root = Bundle.main.resourceURL else { return }
        let fm = FileManager.default
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return }
        for case let u as URL in en where u.pathExtension.lowercased() == "ttf" {
            let n = u.deletingPathExtension().lastPathComponent
            guard ["Tektur", "Megrim", "Handjet"].contains(n) else { continue }
            CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
            if let ds = CTFontManagerCreateFontDescriptorsFromURL(u as CFURL) as? [CTFontDescriptor], let d = ds.first,
               let ps = CTFontDescriptorCopyAttribute(d, kCTFontNameAttribute) as? String {
                registered[n] = ps
            }
        }
    }
    static func font(_ name: String, _ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let ps = registered[name], let f = UIFont(name: ps, size: size) { return f }
        return .systemFont(ofSize: size, weight: weight)
    }
    static func isArabic(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) || (0x0750...0x077F).contains($0.value) || (0xFB50...0xFEFF).contains($0.value) }
    }
    /// Body text: Tektur for Latin, Handjet for Arabic (as on the laptop).
    static func body(_ s: String, _ size: CGFloat) -> UIFont { isArabic(s) ? font("Handjet", size * 1.2) : font("Tektur", size) }
    /// Titles: Megrim for Latin, Handjet for Arabic.
    static func title(_ s: String, _ size: CGFloat) -> UIFont { isArabic(s) ? font("Handjet", size * 1.1) : font("Megrim", size) }
}

// MARK: - Control panel (iPad side) — built from the layout Godot sends ("ui:{json}")

final class ControlPanel: UIView {
    private let link: GodotLink
    private let titleLabel = UILabel()
    private let tvLabel = UILabel()
    private let sceneStatus = UILabel()
    private let diagLabel = UILabel()
    private var godotDiag = ""
    private let levelBar = UIProgressView(progressViewStyle: .bar)
    private let stack = UIStackView()
    private let scroll = UIScrollView()
    private var tv = false
    private var ui: [String: Any] = [:]
    private var lastRaw = ""
    private var gotUI = false
    private var helloTimer: Timer?

    // the laptop palette (ui.gd): salt on near-black, red for what is active
    private let salt = UIColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1)
    private let red = UIColor(red: 0.62, green: 0.04, blue: 0.03, alpha: 1)
    private let ground = UIColor(red: 0.02, green: 0.01, blue: 0.01, alpha: 1)

    init(link: GodotLink) {
        self.link = link
        super.init(frame: .zero)
        TFont.register()
        backgroundColor = ground
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.indicatorStyle = .white
        addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -64),
        ])
        titleLabel.textColor = salt
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.6
        tvLabel.textColor = salt.withAlphaComponent(0.45)
        tvLabel.numberOfLines = 0
        sceneStatus.textColor = salt.withAlphaComponent(0.8)
        sceneStatus.numberOfLines = 0
        levelBar.progressTintColor = red
        levelBar.trackTintColor = UIColor(white: 1, alpha: 0.08)
        levelBar.heightAnchor.constraint(equalToConstant: 6).isActive = true
        diagLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        diagLabel.textColor = UIColor(red: 1, green: 0.6, blue: 0.5, alpha: 1)
        diagLabel.numberOfLines = 0
        AVAudioApplication.requestRecordPermission { _ in }
        // Ask Godot for the layout until it answers (it may start after us).
        helloTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if self.gotUI { t.invalidate(); return }
            self.link.send("hello")
        }
        rebuild()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setMode(tv: Bool) {
        self.tv = tv
        if tv { link.send("hello") }
        rebuild()
    }

    private func makeButton(_ title: String, on: Bool, id: String, size: CGFloat, height: CGFloat) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.title = title
        cfg.baseForegroundColor = salt
        cfg.background.backgroundColor = on ? red : UIColor(white: 1, alpha: 0.03)
        cfg.background.strokeColor = on ? red : salt.withAlphaComponent(0.3)
        cfg.background.strokeWidth = 1
        cfg.background.cornerRadius = 2
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        cfg.titleAlignment = .center
        let f = TFont.body(title, size)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = f; return a
        }
        let b = UIButton(configuration: cfg, primaryAction: UIAction { [weak self] _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            self?.link.send(id)
        })
        b.titleLabel?.numberOfLines = 3
        b.titleLabel?.lineBreakMode = .byWordWrapping
        b.titleLabel?.textAlignment = .center
        b.heightAnchor.constraint(greaterThanOrEqualToConstant: height).isActive = true
        return b
    }

    private func header(_ t: String) -> UILabel {
        let l = UILabel()
        l.text = t
        l.font = TFont.body(t, 16)
        l.textColor = salt.withAlphaComponent(0.55)
        l.numberOfLines = 0
        return l
    }

    private func align(_ l: UILabel, _ rtl: Bool) { l.textAlignment = rtl ? .right : .left }

    private func rebuild() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        let rtl = (ui["rtl"] as? Bool) ?? false
        semanticContentAttribute = rtl ? .forceRightToLeft : .forceLeftToRight
        stack.semanticContentAttribute = semanticContentAttribute
        let title = (ui["title"] as? String) ?? "TAGANT"
        titleLabel.text = title
        titleLabel.font = TFont.title(title, 34)
        align(titleLabel, rtl)
        align(sceneStatus, rtl)
        align(tvLabel, rtl)
        sceneStatus.font = TFont.body(sceneStatus.text ?? "", 17)
        stack.addArrangedSubview(titleLabel)
        if !(sceneStatus.text ?? "").isEmpty { stack.addArrangedSubview(sceneStatus) }
        let sections = (ui["sections"] as? [[String: Any]]) ?? []
        for sec in sections {
            let t = (sec["title"] as? String) ?? ""
            if !t.isEmpty { stack.addArrangedSubview(header(t)) }
            let buttons = (sec["buttons"] as? [[String: Any]]) ?? []
            if buttons.isEmpty { continue }
            let big = (sec["big"] as? Bool) ?? false
            let small = (sec["small"] as? Bool) ?? false
            let cols = max(1, (sec["cols"] as? Int) ?? 4)
            let size: CGFloat = big ? 24 : (small ? 15 : 19)
            let height: CGFloat = big ? 78 : (small ? 46 : 58)
            var i = 0
            while i < buttons.count {
                let slice = Array(buttons[i..<min(i + cols, buttons.count)])
                var views: [UIView] = []
                for bd in slice {
                    views.append(makeButton((bd["label"] as? String) ?? "?", on: (bd["on"] as? Bool) ?? false,
                                            id: (bd["id"] as? String) ?? "", size: size, height: height))
                }
                while views.count < cols && buttons.count > cols { views.append(UIView()) }   // keep the grid
                let row = UIStackView(arrangedSubviews: views)
                row.axis = .horizontal
                row.spacing = 10
                row.alignment = .fill
                row.distribution = .fillEqually
                row.semanticContentAttribute = semanticContentAttribute
                stack.addArrangedSubview(row)
                i += cols
            }
            stack.setCustomSpacing(26, after: stack.arrangedSubviews.last!)
        }
        stack.addArrangedSubview(levelBar)
        tvLabel.text = rtl ? "الشاشة الكبيرة متصلة" : "TV connected — the stage is on the big screen"
        tvLabel.font = TFont.body(tvLabel.text!, 13)
        stack.addArrangedSubview(tvLabel)
        // If the last run did not end cleanly, show where it stopped (for a photo to send).
        let prev = Trail.previous.trimmingCharacters(in: .whitespacesAndNewlines)
        var diag = ""
        if !prev.isEmpty && !prev.hasSuffix("ok") {
            diag = "LAST RUN STOPPED — app: " + prev.split(separator: "\n").suffix(4).map { String($0.split(separator: " ", maxSplits: 1).last ?? "") }.joined(separator: " › ")
        }
        if !godotDiag.isEmpty { diag += (diag.isEmpty ? "" : "\n") + "stage: " + godotDiag }
        if !diag.isEmpty {
            diagLabel.text = diag
            stack.addArrangedSubview(diagLabel)
        }
    }

    func handle(godotMessage msg: String) {
        let parts = msg.split(separator: ":", maxSplits: 1).map(String.init)
        guard let key = parts.first else { return }
        let val = parts.count > 1 ? parts[1] : ""
        switch key {
        case "ui":
            gotUI = true
            if val == lastRaw { return }
            if let d = val.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                lastRaw = val
                ui = obj
                rebuild()
            }
        case "level":
            levelBar.setProgress(Float(val) ?? 0, animated: false)
        case "status":
            let had = !(sceneStatus.text ?? "").isEmpty
            sceneStatus.text = val
            sceneStatus.font = TFont.body(val, 17)
            if had != !val.isEmpty { rebuild() }
        case "diag":
            godotDiag = val
            rebuild()
        default:
            break
        }
    }
}
