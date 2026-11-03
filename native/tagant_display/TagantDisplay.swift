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
    var maxPixelWidth: CGFloat = 1920

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

final class TagantDisplay {
    static let shared = TagantDisplay()

    private(set) var mainScale: CGFloat = 2
    private var mainWindow: UIWindow?
    private var godotVC: UIViewController?
    private var originalSuperview: UIView?

    private var externalWindow: UIWindow?
    private var externalScene: UIWindowScene?
    private var hostVC: StageHostViewController?

    private var panel: ControlPanel?
    private let link = GodotLink()
    private var setupTimer: Timer?
    private var accessoryRegistered = false

    func start() {
        UIApplication.shared.isIdleTimerDisabled = true

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

        let p = ControlPanel(link: link)
        p.translatesAutoresizingMaskIntoConstraints = true
        p.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        win.addSubview(p)
        panel = p
        layoutPanel()

        registerAccessoryIfAvailable(on: win.rootViewController ?? vc)

        // iOS 26 and earlier: the external scene may already be connected.
        for sc in UIApplication.shared.connectedScenes {
            if let ws = sc as? UIWindowScene, ws.session.role == .windowExternalDisplayNonInteractive {
                attach(to: ws)
            }
        }
        return true
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
        guard externalScene !== ws, let vc = godotVC else { return }
        let host = StageHostViewController()
        let w = UIWindow(windowScene: ws)
        w.rootViewController = host
        w.isHidden = false
        externalWindow = w
        externalScene = ws
        hostVC = host

        let stage = vc.view!
        stage.removeFromSuperview()
        stage.autoresizingMask = []
        host.view.addSubview(stage)
        host.stageView = stage
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        host.layoutStage()

        layoutPanel()
        link.send("screen:tv")
    }

    func detach(from scene: UIScene) {
        guard let ws = externalScene, ws === scene else { return }
        if let vc = godotVC, let sup = originalSuperview {
            let stage = vc.view!
            stage.removeFromSuperview()
            stage.transform = .identity
            stage.frame = sup.bounds
            stage.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            sup.addSubview(stage)
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
        if tvConnected {
            p.frame = win.bounds          // whole iPad = remote
        } else {
            let h: CGFloat = 230          // iPad alone: Godot on top, remote strip below
            p.frame = CGRect(x: 0, y: win.bounds.height - h, width: win.bounds.width, height: h)
        }
        p.autoresizingMask = tvConnected ? [.flexibleWidth, .flexibleHeight] : [.flexibleWidth, .flexibleTopMargin]
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

// MARK: - Control panel (iPad side)

final class ControlPanel: UIView {
    private let link: GodotLink
    private let status = UILabel()
    private let takesLabel = UILabel()
    private let levelBar = UIProgressView(progressViewStyle: .bar)
    private let recButton = UIButton(type: .system)
    private var creatureButtons: [UIButton] = []
    private var recording = false
    private var stack = UIStackView()

    init(link: GodotLink) {
        self.link = link
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.06, alpha: 0.96)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func makeButton(_ title: String, _ action: @escaping () -> Void) -> UIButton {
        var cfg = UIButton.Configuration.bordered()
        cfg.title = title
        cfg.baseForegroundColor = UIColor(red: 0.62, green: 0.84, blue: 0.98, alpha: 1)
        cfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.07)
        cfg.cornerStyle = .small
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
        let b = UIButton(configuration: cfg, primaryAction: UIAction { _ in action() })
        b.titleLabel?.font = .monospacedSystemFont(ofSize: 17, weight: .medium)
        return b
    }

    private func row(_ views: [UIView]) -> UIStackView {
        let r = UIStackView(arrangedSubviews: views)
        r.axis = .horizontal
        r.spacing = 12
        r.distribution = .fillEqually
        return r
    }

    private func build() {
        let title = UILabel()
        title.text = "TAGANT · STAGE REMOTE"
        title.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        title.textColor = UIColor(white: 0.85, alpha: 1)

        status.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        status.textColor = UIColor(red: 0.85, green: 0.55, blue: 0.40, alpha: 1)

        let names = ["Myna", "Dove", "Camel", "Frog", "Goat"]
        creatureButtons = names.enumerated().map { i, n in
            makeButton(n) { [weak self] in self?.select(creature: i) }
        }

        let colours = row([
            makeButton("Dawn") { [weak self] in self?.link.send("sky:0") },
            makeButton("Noon") { [weak self] in self?.link.send("sky:1") },
            makeButton("Dusk") { [weak self] in self?.link.send("sky:2") },
            makeButton("Night") { [weak self] in self?.link.send("sky:3") },
        ])

        recButton.configuration = makeButton("● Record") {}.configuration
        recButton.addAction(UIAction { [weak self] _ in self?.toggleRecord() }, for: .touchUpInside)
        let transport = row([
            makeButton("Mic on") { [weak self] in self?.link.send("mic:on") },
            makeButton("Mic off") { [weak self] in self?.link.send("mic:off") },
            recButton,
            makeButton("▶ Hear last take") { [weak self] in self?.link.send("play:last") },
            makeButton("■ Stop") { [weak self] in self?.link.send("stop") },
        ])

        levelBar.progressTintColor = UIColor(red: 0.62, green: 0.84, blue: 0.98, alpha: 1)
        levelBar.trackTintColor = UIColor(white: 1, alpha: 0.08)
        takesLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        takesLabel.textColor = UIColor(white: 0.6, alpha: 1)
        takesLabel.text = "takes: 0"

        stack = UIStackView(arrangedSubviews: [title, status, row(creatureButtons), colours, transport, levelBar, takesLabel])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            levelBar.heightAnchor.constraint(equalToConstant: 8),
        ])
        setMode(tv: false)
        select(creature: 0)
    }

    func setMode(tv: Bool) {
        status.text = tv ? "TV / projector connected — stage is on the big screen"
                         : "No TV detected — stage shown here. Plug in HDMI."
        // Compact strip when there is no TV: hide the less important rows.
        for (i, v) in stack.arrangedSubviews.enumerated() where i == 0 || i == 3 || i == 6 {
            v.isHidden = !tv
        }
    }

    private func select(creature i: Int) {
        link.send("creature:\(i)")
        for (j, b) in creatureButtons.enumerated() {
            b.configuration?.baseBackgroundColor = j == i ? UIColor(red: 0.62, green: 0.84, blue: 0.98, alpha: 0.28)
                                                          : UIColor(white: 1, alpha: 0.07)
        }
    }

    private func toggleRecord() {
        if recording {
            link.send("rec:stop")
        } else {
            requestMic { [weak self] ok in
                guard ok else { self?.status.text = "Microphone not allowed — Settings › Tagant Stage › Microphone"; return }
                self?.link.send("rec:start")
            }
        }
    }

    private func requestMic(_ done: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { ok in DispatchQueue.main.async { done(ok) } }
    }

    func handle(godotMessage msg: String) {
        let parts = msg.split(separator: ":", maxSplits: 1).map(String.init)
        guard let key = parts.first else { return }
        let val = parts.count > 1 ? parts[1] : ""
        switch key {
        case "level":
            levelBar.setProgress(Float(val) ?? 0, animated: false)
        case "rec":
            recording = (val == "on")
            var cfg = recButton.configuration
            cfg?.title = recording ? "■ Stop rec" : "● Record"
            cfg?.baseForegroundColor = recording ? UIColor(red: 1, green: 0.4, blue: 0.35, alpha: 1)
                                                 : UIColor(red: 0.62, green: 0.84, blue: 0.98, alpha: 1)
            recButton.configuration = cfg
        case "takes":
            takesLabel.text = "takes: \(val)"
        case "info":
            takesLabel.text = val
        default:
            break
        }
    }
}
