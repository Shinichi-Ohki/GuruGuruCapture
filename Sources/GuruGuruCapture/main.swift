import Cocoa
import CoreGraphics
import ApplicationServices

// MARK: - Settings

class Settings {
    static let shared = Settings()

    // MARK: Defaults
    struct Defaults {
        static let windowDuration: Double = 1.4
        static let minPoints: Int = 25
        static let triggerAngle: Double = 1.5  // 回数（1.5 = 1周半）
        static let minRadius: Double = 30.0
        static let cooldown: Double = 2.5
    }

    enum SaveDestination: Int {
        case both = 0          // ファイル + クリップボード
        case fileOnly = 1      // ファイルのみ
        case clipboardOnly = 2 // クリップボードのみ
    }

    var saveDestination: SaveDestination {
        get {
            SaveDestination(rawValue: UserDefaults.standard.integer(forKey: "saveDestination")) ?? .both
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "saveDestination")
        }
    }

    var saveDirectory: URL? {
        get {
            if let path = UserDefaults.standard.string(forKey: "saveDirectory") {
                return URL(fileURLWithPath: path)
            }
            return nil // nil = デスクトップ
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: "saveDirectory")
        }
    }

    func getActualSaveDirectory() -> URL {
        if let dir = saveDirectory {
            return dir
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
    }

    // MARK: Detection Settings

    var windowDuration: Double {
        get { UserDefaults.standard.double(forKey: "detection.windowDuration").clamped(to: 0.5...3.0, default: Defaults.windowDuration) }
        set { UserDefaults.standard.set(newValue, forKey: "detection.windowDuration") }
    }

    var minPoints: Int {
        get { UserDefaults.standard.integer(forKey: "detection.minPoints").clamped(to: 10...50, default: Defaults.minPoints) }
        set { UserDefaults.standard.set(newValue, forKey: "detection.minPoints") }
    }

    var triggerAngle: Double {
        get { UserDefaults.standard.double(forKey: "detection.triggerAngle").clamped(to: 0.5...3.0, default: Defaults.triggerAngle) }
        set { UserDefaults.standard.set(newValue, forKey: "detection.triggerAngle") }
    }

    var minRadius: Double {
        get { UserDefaults.standard.double(forKey: "detection.minRadius").clamped(to: 10...100, default: Defaults.minRadius) }
        set { UserDefaults.standard.set(newValue, forKey: "detection.minRadius") }
    }

    var cooldown: Double {
        get { UserDefaults.standard.double(forKey: "detection.cooldown").clamped(to: 0.5...5.0, default: Defaults.cooldown) }
        set { UserDefaults.standard.set(newValue, forKey: "detection.cooldown") }
    }

    func resetDetectionToDefaults() {
        windowDuration = Defaults.windowDuration
        minPoints = Defaults.minPoints
        triggerAngle = Defaults.triggerAngle
        minRadius = Defaults.minRadius
        cooldown = Defaults.cooldown
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>, default defaultValue: Self) -> Self {
        if self < range.lowerBound || self > range.upperBound { return defaultValue }
        return self
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    private let settings = Settings.shared
    private let tabView = NSTabView()

    // 保存先タブ
    private var saveRadioButtons: [NSButton] = []
    private var pathField: NSTextField!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "設定"
        self.init(window: window)

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 300))
        tabView.frame = NSRect(x: 12, y: 50, width: 396, height: 238)
        tabView.tabPosition = .top

        // タブ1: 保存先
        let saveTab = NSTabViewItem()
        saveTab.label = "保存先"
        saveTab.view = createSaveTabView()
        tabView.addTabViewItem(saveTab)

        // タブ2: 検出感度
        let detectionTab = NSTabViewItem()
        detectionTab.label = "検出感度"
        detectionTab.view = createDetectionTabView()
        tabView.addTabViewItem(detectionTab)

        contentView.addSubview(tabView)

        // デフォルトに戻すボタン
        let resetButton = NSButton(frame: NSRect(x: 12, y: 12, width: 230, height: 24))
        resetButton.title = "このタブの内容をデフォルトに戻す"
        resetButton.bezelStyle = .rounded
        resetButton.target = self
        resetButton.action = #selector(resetCurrentTabToDefaults)
        contentView.addSubview(resetButton)

        window.contentView = contentView
        window.center()
    }

    // MARK: - Save Tab

    private func createSaveTabView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 396, height: 238))

        // 保存先ラジオボタン
        let destLabel = NSTextField(labelWithString: "保存先:")
        destLabel.frame = NSRect(x: 20, y: 160, width: 80, height: 24)
        destLabel.alignment = .right
        view.addSubview(destLabel)

        let titles = ["ファイル + クリップボード", "ファイルのみ", "クリップボードのみ"]
        var prevButton: NSButton?

        for (index, title) in titles.enumerated() {
            let button = NSButton(radioButtonWithTitle: title, target: self, action: #selector(destinationChanged(_:)))
            button.frame = NSRect(x: 100, y: prevButton == nil ? 160 : prevButton!.frame.minY - 28, width: 280, height: 24)
            button.tag = index
            view.addSubview(button)
            saveRadioButtons.append(button)
            prevButton = button
        }

        saveRadioButtons[settings.saveDestination.rawValue].state = .on

        // ディレクトリ選択
        let dirLabel = NSTextField(labelWithString: "保存フォルダ:")
        dirLabel.frame = NSRect(x: 20, y: 60, width: 80, height: 24)
        dirLabel.alignment = .right
        view.addSubview(dirLabel)

        pathField = NSTextField(frame: NSRect(x: 100, y: 60, width: 200, height: 24))
        pathField.isEditable = false
        pathField.bezelStyle = .roundedBezel
        updatePathField()
        view.addSubview(pathField)

        let chooseButton = NSButton(frame: NSRect(x: 310, y: 60, width: 70, height: 24))
        chooseButton.title = "選択..."
        chooseButton.bezelStyle = .rounded
        chooseButton.target = self
        chooseButton.action = #selector(chooseDirectory)
        view.addSubview(chooseButton)

        return view
    }

    private func updatePathField() {
        if let dir = settings.saveDirectory {
            pathField.stringValue = dir.path
        } else {
            pathField.stringValue = "デスクトップ（デフォルト）"
        }
    }

    @objc private func destinationChanged(_ sender: NSButton) {
        for button in saveRadioButtons {
            button.state = button === sender ? .on : .off
        }
        if let destination = Settings.SaveDestination(rawValue: sender.tag) {
            settings.saveDestination = destination
        }
    }

    @objc private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "スクリーンショットの保存先フォルダを選択"

        if panel.runModal() == .OK, let url = panel.url {
            settings.saveDirectory = url
            updatePathField()
        }
    }

    // MARK: - Detection Tab

    private enum DetectionTag: Int {
        case windowDuration = 100
        case minPoints = 101
        case triggerAngle = 102
        case minRadius = 103
        case cooldown = 104
    }

    private var detectionSliders: [DetectionTag: NSSlider] = [:]
    private var detectionFields: [DetectionTag: NSTextField] = [:]

    private func createDetectionTabView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 396, height: 238))
        var y: CGFloat = 160

        // ヘルプ
        let helpLabel = NSTextField(wrappingLabelWithString: "値を大きくすると検出が厳しく、小さくすると敏感になります")
        helpLabel.frame = NSRect(x: 20, y: y, width: 350, height: 20)
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)
        y -= 30

        // 検出時間窓
        addSliderRow(to: view, at: &y, tag: .windowDuration, label: "検出時間 (秒):", value: settings.windowDuration, min: 0.5, max: 3.0)
        y -= 4

        // 最小ポイント数
        addSliderRow(to: view, at: &y, tag: .minPoints, label: "最小ポイント数:", value: Double(settings.minPoints), min: 10, max: 50)
        y -= 4

        // トリガー角度（回数）
        addSliderRow(to: view, at: &y, tag: .triggerAngle, label: "必要回転数:", value: settings.triggerAngle, min: 0.5, max: 3.0)
        y -= 4

        // 最小半径
        addSliderRow(to: view, at: &y, tag: .minRadius, label: "最小半径 (px):", value: settings.minRadius, min: 10, max: 100)
        y -= 4

        // クールダウン
        addSliderRow(to: view, at: &y, tag: .cooldown, label: "クールダウン (秒):", value: settings.cooldown, min: 0.5, max: 5.0)

        return view
    }

    private func addSliderRow(to view: NSView, at y: inout CGFloat, tag: DetectionTag, label: String, value: Double, min: Double, max: Double) {
        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 20, y: y, width: 110, height: 24)
        labelField.alignment = .right
        view.addSubview(labelField)

        let slider = NSSlider(frame: NSRect(x: 135, y: y, width: 160, height: 24))
        slider.minValue = min
        slider.maxValue = max
        slider.doubleValue = value
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(detectionSliderChanged(_:))
        slider.tag = tag.rawValue
        view.addSubview(slider)
        detectionSliders[tag] = slider

        let field = NSTextField(frame: NSRect(x: 300, y: y, width: 50, height: 24))
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = tag == .minPoints ? 0 : 1
        formatter.maximumFractionDigits = tag == .minPoints ? 0 : 1
        field.formatter = formatter
        field.doubleValue = value
        field.target = self
        field.action = #selector(detectionFieldChanged(_:))
        field.tag = tag.rawValue
        view.addSubview(field)
        detectionFields[tag] = field

        y -= 28
    }

    @objc private func detectionSliderChanged(_ sender: NSSlider) {
        guard let tag = DetectionTag(rawValue: sender.tag) else { return }
        let value = sender.doubleValue
        detectionFields[tag]?.doubleValue = value
        applyDetectionValue(tag: tag, value: value)
    }

    @objc private func detectionFieldChanged(_ sender: NSTextField) {
        guard let tag = DetectionTag(rawValue: sender.tag) else { return }
        let value = sender.doubleValue
        detectionSliders[tag]?.doubleValue = value
        applyDetectionValue(tag: tag, value: value)
    }

    private func applyDetectionValue(tag: DetectionTag, value: Double) {
        switch tag {
        case .windowDuration: settings.windowDuration = value
        case .minPoints: settings.minPoints = Int(value)
        case .triggerAngle: settings.triggerAngle = value
        case .minRadius: settings.minRadius = value
        case .cooldown: settings.cooldown = value
        }
    }

    // MARK: - Reset

    @objc private func resetCurrentTabToDefaults() {
        let currentTab = tabView.indexOfTabViewItem(tabView.selectedTabViewItem!)
        if currentTab == 0 {
            // 保存先タブ
            settings.saveDestination = .both
            settings.saveDirectory = nil
            updatePathField()
            for (index, button) in saveRadioButtons.enumerated() {
                button.state = index == 0 ? .on : .off
            }
        } else {
            // 検出感度タブ
            settings.resetDetectionToDefaults()
            detectionSliders[.windowDuration]?.doubleValue = Settings.Defaults.windowDuration
            detectionSliders[.minPoints]?.doubleValue = Double(Settings.Defaults.minPoints)
            detectionSliders[.triggerAngle]?.doubleValue = Settings.Defaults.triggerAngle
            detectionSliders[.minRadius]?.doubleValue = Settings.Defaults.minRadius
            detectionSliders[.cooldown]?.doubleValue = Settings.Defaults.cooldown

            detectionFields[.windowDuration]?.doubleValue = Settings.Defaults.windowDuration
            detectionFields[.minPoints]?.doubleValue = Double(Settings.Defaults.minPoints)
            detectionFields[.triggerAngle]?.doubleValue = Settings.Defaults.triggerAngle
            detectionFields[.minRadius]?.doubleValue = Settings.Defaults.minRadius
            detectionFields[.cooldown]?.doubleValue = Settings.Defaults.cooldown
        }
    }
}

// MARK: - Swirl Detector

class SwirlDetector {
    private struct TimedPoint {
        let point: CGPoint
        let time: Date
    }

    private var positions: [TimedPoint] = []
    private var onCooldown = false
    private let settings = Settings.shared

    var onSwirl: (([CGPoint]) -> Void)?

    func addPoint(_ point: CGPoint) {
        let now = Date()
        positions.append(TimedPoint(point: point, time: now))
        positions.removeAll { now.timeIntervalSince($0.time) > settings.windowDuration }
        checkSwirl()
    }

    private func checkSwirl() {
        guard !onCooldown, positions.count >= settings.minPoints else { return }
        let pts = positions.map { $0.point }
        let cx = pts.map { $0.x }.reduce(0, +) / CGFloat(pts.count)
        let cy = pts.map { $0.y }.reduce(0, +) / CGFloat(pts.count)
        let center = CGPoint(x: cx, y: cy)

        let avgRadius = pts.map {
            sqrt(pow($0.x - cx, 2) + pow($0.y - cy, 2))
        }.reduce(0, +) / CGFloat(pts.count)
        guard avgRadius >= settings.minRadius else { return }

        let triggerAngleRad = CGFloat(settings.triggerAngle * 2 * .pi)
        var totalAngle: CGFloat = 0
        for i in 1..<pts.count {
            let a1 = atan2(pts[i-1].y - center.y, pts[i-1].x - center.x)
            let a2 = atan2(pts[i].y - center.y, pts[i].x - center.x)
            var da = a2 - a1
            while da >  .pi { da -= 2 * .pi }
            while da < -.pi { da += 2 * .pi }
            totalAngle += da
        }

        if abs(totalAngle) >= triggerAngleRad {
            let capturedPts = pts
            startCooldown()
            onSwirl?(capturedPts)
        }
    }

    private func startCooldown() {
        onCooldown = true
        positions.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.cooldown) { [weak self] in
            self?.onCooldown = false
        }
    }
}

// MARK: - Handle Type

enum HandlePosition {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
    case inside // 移動用
}

// MARK: - Selection Overlay View

class SelectionOverlayView: NSView {
    var selectionRect: NSRect {
        didSet { needsDisplay = true }
    }

    var onConfirm: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private let handleSize: CGFloat = 10
    private var dragHandle: HandlePosition? = nil
    private var dragStart: CGPoint = .zero
    private var rectAtDragStart: NSRect = .zero

    init(frame: NSRect, initialRect: NSRect) {
        self.selectionRect = initialRect
        super.init(frame: frame)

        // マウス追跡を有効化
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        // 全体を暗くする
        NSColor.black.withAlphaComponent(0.45).setFill()
        bounds.fill()

        // 選択範囲をくり抜く（明るく見せる）
        NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
        NSColor.clear.setFill()
        selectionRect.fill()
        NSGraphicsContext.current?.cgContext.setBlendMode(.normal)

        // 選択枠のボーダー
        let borderPath = NSBezierPath(rect: selectionRect)
        borderPath.lineWidth = 2
        NSColor.white.withAlphaComponent(0.9).setStroke()
        borderPath.stroke()

        // サイズラベル
        let sizeStr = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.6)
        ]
        let labelSize = (sizeStr as NSString).size(withAttributes: attrs)
        let labelX = selectionRect.midX - labelSize.width / 2
        let labelY: CGFloat
        if selectionRect.minY > 30 {
            labelY = selectionRect.minY - labelSize.height - 6
        } else {
            labelY = selectionRect.maxY + 6
        }
        let labelRect = NSRect(x: labelX - 4, y: labelY, width: labelSize.width + 8, height: labelSize.height + 2)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: labelRect, xRadius: 3, yRadius: 3).fill()
        (sizeStr as NSString).draw(at: NSPoint(x: labelRect.minX + 4, y: labelRect.minY + 1), withAttributes: attrs)

        // ヘルプテキスト
        let helpStr = "Enter / ダブルクリック: 確定  |  Esc / 右クリック: キャンセル"
        let helpAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white.withAlphaComponent(0.7)
        ]
        let helpSize = (helpStr as NSString).size(withAttributes: helpAttrs)
        let helpX = bounds.midX - helpSize.width / 2
        (helpStr as NSString).draw(at: NSPoint(x: helpX, y: 12), withAttributes: helpAttrs)

        // ハンドル描画
        for (pos, rect) in handleRects() {
            let _ = pos
            NSColor.white.setFill()
            NSColor.systemBlue.setStroke()
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    // MARK: Handle Geometry

    private func handleRects() -> [(HandlePosition, NSRect)] {
        let s = handleSize
        let r = selectionRect
        let mx = r.midX - s/2
        let my = r.midY - s/2

        return [
            (.topLeft,     NSRect(x: r.minX - s/2, y: r.maxY - s/2, width: s, height: s)),
            (.top,         NSRect(x: mx,            y: r.maxY - s/2, width: s, height: s)),
            (.topRight,    NSRect(x: r.maxX - s/2,  y: r.maxY - s/2, width: s, height: s)),
            (.left,        NSRect(x: r.minX - s/2,  y: my,           width: s, height: s)),
            (.right,       NSRect(x: r.maxX - s/2,  y: my,           width: s, height: s)),
            (.bottomLeft,  NSRect(x: r.minX - s/2,  y: r.minY - s/2, width: s, height: s)),
            (.bottom,      NSRect(x: mx,             y: r.minY - s/2, width: s, height: s)),
            (.bottomRight, NSRect(x: r.maxX - s/2,  y: r.minY - s/2, width: s, height: s)),
        ]
    }

    private func hitTest(point: CGPoint) -> HandlePosition? {
        let expanded: CGFloat = 6
        for (pos, rect) in handleRects() {
            if rect.insetBy(dx: -expanded, dy: -expanded).contains(point) {
                return pos
            }
        }
        if selectionRect.contains(point) { return .inside }
        return nil
    }

    // MARK: Mouse Events

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        dragHandle = hitTest(point: pt)
        dragStart = pt
        rectAtDragStart = selectionRect

        // ドラッグ開始時にカーソルを設定
        if let handle = dragHandle {
            setDragCursor(for: handle)
        }

        if event.clickCount == 2 {
            confirm()
        }
    }

    private func setDragCursor(for handle: HandlePosition) {
        switch handle {
        case .topLeft, .bottomRight:
            resizeNWSECursor.set()
        case .topRight, .bottomLeft:
            resizeNESWCursor.set()
        case .top, .bottom:
            resizeUpDownCursor.set()
        case .left, .right:
            resizeLeftRightCursor.set()
        case .inside:
            NSCursor.closedHand.set()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let handle = dragHandle else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let dx = pt.x - dragStart.x
        let dy = pt.y - dragStart.y
        var r = rectAtDragStart

        switch handle {
        case .inside:
            r.origin.x += dx
            r.origin.y += dy
        case .topLeft:
            r.origin.x += dx; r.size.width -= dx
            r.size.height += dy
        case .top:
            r.size.height += dy
        case .topRight:
            r.size.width += dx
            r.size.height += dy
        case .left:
            r.origin.x += dx; r.size.width -= dx
        case .right:
            r.size.width += dx
        case .bottomLeft:
            r.origin.x += dx; r.size.width -= dx
            r.origin.y += dy; r.size.height -= dy
        case .bottom:
            r.origin.y += dy; r.size.height -= dy
        case .bottomRight:
            r.size.width += dx
            r.origin.y += dy; r.size.height -= dy
        }

        // 最小サイズ
        if r.width < 10 { r.size.width = 10 }
        if r.height < 10 { r.size.height = 10 }

        selectionRect = r
    }

    override func mouseUp(with event: NSEvent) {
        dragHandle = nil
        // カーソルを元に戻す
        NSCursor.arrow.set()
    }

    // MARK: Cursor

    private lazy var resizeNWSECursor: NSCursor = {
        createDiagonalCursor(angle: -45)
    }()

    private lazy var resizeNESWCursor: NSCursor = {
        createDiagonalCursor(angle: 45)
    }()

    private lazy var resizeUpDownCursor: NSCursor = {
        createStraightCursor()
    }()

    private lazy var resizeLeftRightCursor: NSCursor = {
        createStraightCursor(vertical: false)
    }()

    private func createDiagonalCursor(angle: CGFloat) -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)

        image.lockFocus()
        let context = NSGraphicsContext.current?.cgContext

        // 回転
        context?.translateBy(x: 12, y: 12)
        context?.rotate(by: angle * .pi / 180)

        // 左右矢印を描画
        let path = NSBezierPath()
        path.lineWidth = 2
        NSColor.black.setStroke()

        // 左矢印
        path.move(to: NSPoint(x: -10, y: 0))
        path.line(to: NSPoint(x: 10, y: 0))
        // 左矢印の頭
        path.move(to: NSPoint(x: -10, y: 0))
        path.line(to: NSPoint(x: -6, y: 3))
        path.move(to: NSPoint(x: -10, y: 0))
        path.line(to: NSPoint(x: -6, y: -3))
        // 右矢印の頭
        path.move(to: NSPoint(x: 10, y: 0))
        path.line(to: NSPoint(x: 6, y: 3))
        path.move(to: NSPoint(x: 10, y: 0))
        path.line(to: NSPoint(x: 6, y: -3))

        path.stroke()
        image.unlockFocus()

        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }

    private func createStraightCursor(vertical: Bool = true) -> NSCursor {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)

        image.lockFocus()
        let path = NSBezierPath()
        path.lineWidth = 2
        NSColor.black.setStroke()

        if vertical {
            // 上下矢印
            path.move(to: NSPoint(x: 12, y: 2))
            path.line(to: NSPoint(x: 12, y: 22))
            // 上矢印の頭
            path.move(to: NSPoint(x: 12, y: 2))
            path.line(to: NSPoint(x: 9, y: 6))
            path.move(to: NSPoint(x: 12, y: 2))
            path.line(to: NSPoint(x: 15, y: 6))
            // 下矢印の頭
            path.move(to: NSPoint(x: 12, y: 22))
            path.line(to: NSPoint(x: 9, y: 18))
            path.move(to: NSPoint(x: 12, y: 22))
            path.line(to: NSPoint(x: 15, y: 18))
        } else {
            // 左右矢印
            path.move(to: NSPoint(x: 2, y: 12))
            path.line(to: NSPoint(x: 22, y: 12))
            // 左矢印の頭
            path.move(to: NSPoint(x: 2, y: 12))
            path.line(to: NSPoint(x: 6, y: 9))
            path.move(to: NSPoint(x: 2, y: 12))
            path.line(to: NSPoint(x: 6, y: 15))
            // 右矢印の頭
            path.move(to: NSPoint(x: 22, y: 12))
            path.line(to: NSPoint(x: 18, y: 9))
            path.move(to: NSPoint(x: 22, y: 12))
            path.line(to: NSPoint(x: 18, y: 15))
        }

        path.stroke()
        image.unlockFocus()

        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(event: event)
    }

    private func updateCursor(event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        let cursor: NSCursor
        switch hitTest(point: pt) {
        case .topLeft, .bottomRight:
            cursor = resizeNWSECursor
        case .topRight, .bottomLeft:
            cursor = resizeNESWCursor
        case .top, .bottom:
            cursor = resizeUpDownCursor
        case .left, .right:
            cursor = resizeLeftRightCursor
        case .inside:
            cursor = .openHand
        default:
            cursor = .arrow
        }
        cursor.set()
    }

    // MARK: Keyboard

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: confirm()  // Enter / numpad Enter
        case 53:     onCancel?() // Esc
        default:     super.keyDown(with: event)
        }
    }

    private func confirm() {
        onConfirm?(selectionRect)
    }
}

// MARK: - Full Screen Overlay Window

class SelWin: NSWindow {
    var overlayView: SelectionOverlayView!

    convenience init(screen: NSScreen, initialRect: NSRect) {
        self.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenPrimary]

        // NSScreen座標をウィンドウローカル座標に変換
        let localRect = NSRect(
            x: initialRect.minX - screen.frame.minX,
            y: initialRect.minY - screen.frame.minY,
            width: initialRect.width,
            height: initialRect.height
        )
        overlayView = SelectionOverlayView(frame: screen.frame, initialRect: localRect)
        contentView = overlayView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Screen Capture

func captureRegion(_ nsRect: NSRect) -> CGImage? {
    guard let screen = NSScreen.main else { return nil }
    let screenHeight = screen.frame.height
    let quartzRect = CGRect(
        x: nsRect.minX,
        y: screenHeight - nsRect.maxY,
        width: nsRect.width,
        height: nsRect.height
    )
    return CGWindowListCreateImage(quartzRect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
}

func boundingRect(from points: [CGPoint], padding: CGFloat = 25) -> NSRect {
    let minX = points.map { $0.x }.min()! - padding
    let maxX = points.map { $0.x }.max()! + padding
    let minY = points.map { $0.y }.min()! - padding
    let maxY = points.map { $0.y }.max()! + padding
    return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mouseMonitor: Any?
    private var keyMonitor: Any?
    private var selWin: SelWin?
    private let detector = SwirlDetector()
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        requestAccessibility()
        detector.onSwirl = { [weak self] points in
            DispatchQueue.main.async { self?.enterSelectionMode(points: points) }
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.detector.addPoint(NSEvent.mouseLocation)
        }
    }

    private func enterSelectionMode(points: [CGPoint]) {
        guard let screen = NSScreen.main else { return }
        let initialRect = boundingRect(from: points)

        let win = SelWin(screen: screen, initialRect: initialRect)

        win.overlayView.onConfirm = { [weak self, weak win] localRect in
            win?.orderOut(nil)
            self?.selWin = nil
            self?.stopKeyMonitor()

            // ウィンドウローカル座標 → スクリーン座標に戻す
            let screenRect = NSRect(
                x: localRect.minX + screen.frame.minX,
                y: localRect.minY + screen.frame.minY,
                width: localRect.width,
                height: localRect.height
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                guard let image = captureRegion(screenRect) else {
                    print("[GuruGuruCapture] ⚠️ キャプチャ失敗")
                    return
                }
                self?.handleCapturedImage(image, screenRect: screenRect)

                self?.statusItem?.button?.title = "📸"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self?.statusItem?.button?.title = "🌀"
                }
            }
        }

        win.overlayView.onCancel = { [weak self] in
            self?.cancelSelection()
        }

        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(win.overlayView)
        selWin = win

        // ESCキー監視を開始
        startKeyMonitor()

        // ステータスアイコン
        statusItem?.button?.title = "✂️"
    }

    private func startKeyMonitor() {
        // ローカルモニター（アプリがアクティブな時）
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.cancelSelection()
                return nil
            }
            return event
        }
        // アプリをアクティベート
        NSApp.activate(ignoringOtherApps: true)
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func cancelSelection() {
        selWin?.orderOut(nil)
        selWin = nil
        stopKeyMonitor()
        // アプリを非アクティブにして他のアプリにフォーカスを戻す
        NSApp.deactivate()
        // 少し遅延してからアプリを隠す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.hide(nil)
        }
    }

    private func handleCapturedImage(_ image: CGImage, screenRect: NSRect) {
        let settings = Settings.shared

        // クリップボードにコピー
        if settings.saveDestination == .both || settings.saveDestination == .clipboardOnly {
            let nsImage = NSImage(cgImage: image, size: screenRect.size)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([nsImage])
        }

        // ファイルに保存
        if settings.saveDestination == .both || settings.saveDestination == .fileOnly {
            saveImage(image: image)
        }
    }

    private func saveImage(image: CGImage) {
        let saveDir = Settings.shared.getActualSaveDirectory()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let url = saveDir.appendingPathComponent("GuruGuru_\(formatter.string(from: Date())).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("[GuruGuruCapture] 💾 \(url.path)")
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.title = "🌀"
        let menu = NSMenu()
        menu.addItem(withTitle: "GuruGuruCapture 🌀", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let i1 = NSMenuItem(title: "マウスをぐるぐる → 範囲調整 → Enter で確定", action: nil, keyEquivalent: "")
        i1.isEnabled = false
        menu.addItem(i1)
        menu.addItem(.separator())
        menu.addItem(withTitle: "設定...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() { NSApplication.shared.terminate(nil) }
}

// MARK: - Entry Point
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
