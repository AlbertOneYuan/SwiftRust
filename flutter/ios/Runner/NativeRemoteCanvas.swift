// SwiftRust modifications © 2026 SwiftRust contributors. Modified 2026-11-20.
// SPDX-License-Identifier: AGPL-3.0-only
import SwiftUI
import UIKit

@available(iOS 17.0, *)
struct NativeRemoteCanvas: UIViewRepresentable {
    @ObservedObject var model: NativeShellModel
    func makeUIView(context: Context) -> NativeCanvasView { NativeCanvasView(model: model) }
    func updateUIView(_ view: NativeCanvasView, context: Context) { view.updateCursor(); view.updateControls() }
    static func dismantleUIView(_ view: NativeCanvasView, coordinator: ()) { view.stop() }
}

@available(iOS 17.0, *)
final class NativeCanvasView: UIView, UITextViewDelegate {
    private weak var model: NativeShellModel?
    private let video = CALayer()
    private let pointer = CALayer()
    private let fallbackCursor = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { _ in
        UIImage(systemName: "cursorarrow", withConfiguration: UIImage.SymbolConfiguration(pointSize: 60, weight: .bold))?
            .withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: CGRect(x: 0, y: 0, width: 64, height: 64))
    }.cgImage
    private let keyboard = UITextView()
    private let dock: NativeDockArea
    private var displayLink: CADisplayLink?
    private weak var guardedNavigation: UINavigationController?
    private weak var guardedSplit: UISplitViewController?
    private var previousSplitGesture = true
    private var previousWindowSize = CGSize.zero
    private var previousCanvasSize = CGSize.zero
    private var imageSize = CGSize.zero
    private var magnification: CGFloat = 1
    private var pan = CGPoint.zero
    private var keyboardLift: CGFloat = 0
    private var keyboardOffset: CGFloat = 0
    private var cursorPoint = CGPoint.zero
    private var receivedCursor = false
    private var screenOrigin: CGPoint { model?.displays.first(where: { $0.id == model?.displayIndex })?.origin ?? .zero }
    private var scale: CGFloat {
        guard imageSize.width > 0, imageSize.height > 0 else { return 1 }
        let height = bounds.height
        return min(bounds.width / imageSize.width, height / imageSize.height) * magnification
    }
    private var minimumMagnification: CGFloat {
        guard model?.limitZoomToWidth == true, imageSize.width > 0, imageSize.height > 0 else { return 0.25 }
        let height = bounds.height
        let fitted = min(bounds.width / imageSize.width, height / imageSize.height)
        return fitted > 0 ? (bounds.width / imageSize.width) / fitted : 1
    }
    func constrainZoomToWindowWidth() {
        guard model?.limitZoomToWidth == true, magnification < minimumMagnification else { return }
        magnification = minimumMagnification; pan = .zero
        alignWithKeyboard(); layoutLayers()
    }
    private var imageOrigin: CGPoint { CGPoint(x: (bounds.width-imageSize.width*scale)/2+pan.x, y: (bounds.height-imageSize.height*scale)/2+pan.y-keyboardOffset) }
    private struct Finger { var start: CGPoint; var position: CGPoint }
    private var fingers: [ObjectIdentifier: Finger] = [:]
    private var maxFingers = 0
    private var began: TimeInterval = 0
    private var moved = false
    private var dragging = false { didSet { if dragging && !oldValue { gestureFeedback() } } }
    private var directDown = false { didSet { if directDown && !oldValue { gestureFeedback() } } }
    private var scrolling = false
    private let gestureHaptic = UIImpactFeedbackGenerator(style: .light)
    private func gestureFeedback() { gestureHaptic.impactOccurred() }
    private var directTouchStartedInside = false
    private var longPress: Timer?
    private var pendingTap: Timer?
    private var lastTap = CGPoint.zero
    private var longPressed = false
    private var isDirectTouch: Bool { model?.inputMode.hasPrefix("touch") == true }
    private var twoFingerGesture = NativeTwoFingerGesture()
    private var previousCenter = CGPoint.zero
    private var scrollRemainder = CGPoint.zero

    init(model: NativeShellModel) {
        self.model = model
        dock = NativeDockArea(model: model)
        super.init(frame: .zero)
        model.canvas = self
        backgroundColor = .black; isOpaque = true; clipsToBounds = true; isMultipleTouchEnabled = true
        layer.addSublayer(video); layer.addSublayer(pointer)
        video.contentsGravity = .resize; video.minificationFilter = .linear; video.magnificationFilter = .linear
        pointer.contentsGravity = .resize; pointer.magnificationFilter = .linear
        keyboard.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        keyboard.alpha = 0.01; keyboard.accessibilityElementsHidden = true
        keyboard.delegate = self; keyboard.text = "\u{200B}"
        keyboard.autocorrectionType = .no; keyboard.autocapitalizationType = .none
        addSubview(keyboard)
        dock.frame = bounds
        dock.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dock)
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(hovered(_:)))
        addGestureRecognizer(hover)
        let wheel = UIPanGestureRecognizer(target: self, action: #selector(wheeled(_:)))
        wheel.allowedTouchTypes = []; wheel.allowedScrollTypesMask = .all
        addGestureRecognizer(wheel)
        NotificationCenter.default.addObserver(self, selector: #selector(inactive), name: UIApplication.willResignActiveNotification, object: nil)
        if let position = model.cursorPosition { remoteCursor(position) }
        if let (image, display) = model.lastFrame { displayFrame(image, display: display) }
    }
    required init?(coder: NSCoder) { nil }
    func updateControls() { dock.updateControls() }
    deinit { NotificationCenter.default.removeObserver(self) }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            if displayLink == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 60, preferred: 60)
                link.add(to: .main, forMode: .common); displayLink = link
            }
            var responder: UIResponder? = self
            while let current = responder {
                if let navigation = current as? UINavigationController {
                    guardedNavigation = navigation
                    navigation.interactivePopGestureRecognizer?.isEnabled = false
                    if #available(iOS 26.0, *) { navigation.interactiveContentPopGestureRecognizer?.isEnabled = false }
                }
                if let split = current as? UISplitViewController {
                    if guardedSplit !== split { previousSplitGesture = split.presentsWithGesture; guardedSplit = split }
                    split.presentsWithGesture = false
                }
                responder = current.next
            }
        } else { stop() }
    }
    func stop() {
        releaseInput(); displayLink?.invalidate(); displayLink = nil; hideSystemKeyboard()
        guardedNavigation?.interactivePopGestureRecognizer?.isEnabled = true
        if #available(iOS 26.0, *) { guardedNavigation?.interactiveContentPopGestureRecognizer?.isEnabled = true }
        guardedSplit?.presentsWithGesture = previousSplitGesture
        guardedNavigation = nil; guardedSplit = nil
    }
    @objc private func inactive() { releaseInput(); hideSystemKeyboard() }
    override func layoutSubviews() {
        super.layoutSubviews()
        let windowSize = window?.bounds.size ?? bounds.size
        if windowSize != previousWindowSize {
            previousWindowSize = windowSize
            if keyboard.inputView is NativeShortcutInputView { showShortcutKeyboard() }
        }
        if bounds.size != previousCanvasSize {
            previousCanvasSize = bounds.size
            constrainZoomToWindowWidth()
            alignWithKeyboard()
        }
        layoutLayers()
    }
    @objc private func tick() {
        guard UIApplication.shared.applicationState == .active, let model else { return }
        guard let (image, display) = model.core.frame(), display == model.displayIndex, model.connectionFailure == nil else { return }
        displayFrame(image, display: display)
    }
    func displayFrame(_ image: CGImage, display: Int) {
        guard let model, display == model.displayIndex, model.connectionFailure == nil else { return }
        model.lastFrame = (image, display)
        let size = CGSize(width: image.width, height: image.height)
        let resolution = NativeResolution(width: image.width, height: image.height)
        if model.connectionMetrics.frameResolution != resolution { model.connectionMetrics.frameResolution = resolution }
        if imageSize != size {
            imageSize = size; fit()
            if !receivedCursor {
                cursorPoint = CGPoint(x: screenOrigin.x+size.width/2, y: screenOrigin.y+size.height/2)
                model.cursorPosition = cursorPoint
            }
        }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        video.contents = image
        layoutLayers()
        CATransaction.commit()
        model.firstFrame()
    }
    func prepareDisplay() { model?.connectionMetrics.frameResolution = nil; model?.lastFrame = nil; video.contents = nil; imageSize = .zero; receivedCursor = false; fit() }
    func fit() { magnification = max(1, minimumMagnification); pan = .zero; alignWithKeyboard(); layoutLayers() }
    func originalSize() {
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let fitScale = min(bounds.width/imageSize.width, bounds.height/imageSize.height)
        magnification = max(1/max(fitScale, 0.001), model?.limitZoomToWidth == true ? minimumMagnification : 0); pan = .zero; alignWithKeyboard(); layoutLayers()
    }
    func zoom(by factor: CGFloat, at point: CGPoint? = nil) {
        guard model?.canvasLocked != true, imageSize.width > 0 else { return }
        var center = point ?? CGPoint(x: bounds.midX, y: bounds.midY)
        let origin = imageOrigin; let oldScale = scale
        let imageFrame = CGRect(origin: origin, size: CGSize(width: imageSize.width * scale, height: imageSize.height * scale))
        if point != nil && !imageFrame.contains(center) {
            let viewport = CGRect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - keyboardLift))
            let visibleImage = imageFrame.intersection(viewport)
            center = visibleImage.isNull || visibleImage.isEmpty
                ? CGPoint(x: viewport.midX, y: viewport.midY)
                : CGPoint(x: visibleImage.midX, y: visibleImage.midY)
        }
        let remote = CGPoint(x: (center.x-origin.x)/oldScale, y: (center.y-origin.y)/oldScale)
        let previousMagnification = magnification
        magnification = min(max(magnification * factor, minimumMagnification), max(12, minimumMagnification))
        if factor < 1, previousMagnification > minimumMagnification, magnification == minimumMagnification { gestureFeedback() }
        pan = CGPoint(x: center.x-(bounds.width-imageSize.width*scale)/2-remote.x*scale,
                      y: center.y-(bounds.height-imageSize.height*scale)/2-remote.y*scale+keyboardOffset)
        layoutLayers()
    }
    func transformCanvas(by factor: CGFloat, from previousCenter: CGPoint, to center: CGPoint) {
        guard model?.canvasLocked != true else { return }
        zoom(by: factor, at: previousCenter)
        pan.x += center.x - previousCenter.x
        pan.y += center.y - previousCenter.y
        layoutLayers()
    }
    func setKeyboardLift(_ lift: CGFloat) {
        guard abs(lift - keyboardLift) > 0.5 else { return }
        let layers = [video]
        let positions = layers.map { $0.presentation()?.position ?? $0.position }
        keyboardLift = lift
        constrainZoomToWindowWidth()
        alignWithKeyboard()
        layoutLayers()
        let duration = UIView.inheritedAnimationDuration
        if duration > 0 {
            for (layer, position) in zip(layers, positions) {
                let animation = CABasicAnimation(keyPath: "position")
                animation.fromValue = NSValue(cgPoint: position)
                animation.toValue = NSValue(cgPoint: layer.position)
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(animation, forKey: "keyboardPosition")
            }
        }
    }
    private func alignWithKeyboard() {
        keyboardOffset = keyboardLift > 0
            ? (bounds.height + imageSize.height * scale) / 2 + pan.y - (bounds.height - keyboardLift)
            : 0
    }
    private func layoutLayers() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        video.frame = CGRect(origin: imageOrigin, size: CGSize(width: imageSize.width*scale, height: imageSize.height*scale))
        updateCursor()
        CATransaction.commit()
    }
    func updateCursor() {
        guard let model else { return }
        let shape = model.cursor
        let image = shape?.image ?? fallbackCursor
        guard let image else { return }
        let size = CGFloat(model.cursorSize)/CGFloat(max(image.width,image.height))
        let hotspot = shape?.hotspot ?? .zero
        CATransaction.begin(); CATransaction.setDisableActions(true)
        pointer.contents = image
        pointer.isHidden = !model.drawLocalCursor
        pointer.frame = CGRect(x: imageOrigin.x+(cursorPoint.x-screenOrigin.x)*scale-hotspot.x*size,
            y: imageOrigin.y+(cursorPoint.y-screenOrigin.y)*scale-hotspot.y*size,
            width: CGFloat(image.width)*size, height: CGFloat(image.height)*size)
        CATransaction.commit()
    }
    func remoteCursor(_ point: CGPoint) {
        receivedCursor = true
        if !isDirectTouch, !fingers.isEmpty, model?.connected == true,
           model?.keyboardAllowed == true, model?.sessionToggle("view-only") != true { return }
        cursorPoint = point; model?.cursorPosition = point; updateCursor()
    }
    private func send(_ message: [String: String]) {
        guard model?.connected == true, model?.remoteKind != .camera, model?.keyboardAllowed == true else { return }
        _ = try? model?.core.call("mouse", ["message": message])
    }
    private func button(_ name: String, down: Bool) {
        var name = name
        if model?.sessionToggle("swap-left-right-mouse") == true {
            name = name == "left" ? "right" : name == "right" ? "left" : name
        }
        send(["type": down ? "down" : "up", "buttons": name,
              "x": String(Int(cursorPoint.x)), "y": String(Int(cursorPoint.y))])
    }
    func click(button name: String = "left") { button(name, down: true); button(name, down: false) }
    private func move(to point: CGPoint) {
        guard imageSize.width > 0 else { return }
        cursorPoint = CGPoint(x: min(max(point.x,screenOrigin.x),screenOrigin.x+imageSize.width-1),
            y: min(max(point.y,screenOrigin.y),screenOrigin.y+imageSize.height-1))
        model?.cursorPosition = cursorPoint
        send(["type":"move","x":String(Int(cursorPoint.x)),"y":String(Int(cursorPoint.y))])
        updateCursor()
    }
    private func relative(_ delta: CGPoint) {
        let speed = min(max(UserDefaults.standard.object(forKey: "native.pointer-speed") as? Double ?? 1, 0.25), 3)
        move(to: CGPoint(x: cursorPoint.x+delta.x/scale*speed, y: cursorPoint.y+delta.y/scale*speed))
        guard model?.canvasLocked != true else { return }
        let p=CGPoint(x:imageOrigin.x+(cursorPoint.x-screenOrigin.x)*scale,y:imageOrigin.y+(cursorPoint.y-screenOrigin.y)*scale)
        if p.x < 12 { pan.x += 12-p.x }; if p.x > bounds.width-12 { pan.x -= p.x-(bounds.width-12) }
        if p.y < 12 { pan.y += 12-p.y }; if p.y > bounds.height-keyboardLift-12 { pan.y -= p.y-(bounds.height-keyboardLift-12) }
        layoutLayers()
    }
    func acceptsDirectTouch(at point: CGPoint) -> Bool { video.frame.contains(point) }
    private func absolute(_ point: CGPoint) {
        move(to: CGPoint(x:(point.x-imageOrigin.x)/scale+screenOrigin.x,y:(point.y-imageOrigin.y)/scale+screenOrigin.y))
    }
    private var usesOriginalGestures: Bool { model?.inputMode == "mouse" || model?.inputMode == "touch" }
    private func scroll(_ delta: CGPoint, touch: Bool = false) {
        if touch, delta != .zero, !scrolling { scrolling = true; gestureFeedback() }
        let precise = touch && model?.peers.first(where: { $0.id == model?.remoteID })?.platform.lowercased().contains("mac") == true
        let speed = touch ? min(max(UserDefaults.standard.object(forKey: "native.scroll-speed") as? Double ?? 1, 0.25), 3) : 1
        let gain: CGFloat = (precise ? 1.5 : touch ? 1.0 / 12 : 1.0 / 20) * speed
        scrollRemainder.x += delta.x * gain; scrollRemainder.y += delta.y * gain
        var x=Int(scrollRemainder.x), y=Int(scrollRemainder.y)
        scrollRemainder.x -= CGFloat(x); scrollRemainder.y -= CGFloat(y)
        if model?.sessionToggle("reverse-mouse-wheel") == true {x = -x; y = -y}
        if x != 0 || y != 0 {send(["type":precise ? "trackpad" : "wheel","x":String(x),"y":String(y)])}
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if fingers.isEmpty { scrolling=false; gestureHaptic.prepare(); maxFingers=0; began=CACurrentMediaTime(); moved=false; longPressed=false; twoFingerGesture.end(); scrollRemainder = .zero }
        for touch in touches { let p=touch.location(in:self); fingers[ObjectIdentifier(touch)] = Finger(start:p,position:p) }
        for touch in event?.allTouches ?? touches {
            let id = ObjectIdentifier(touch)
            if var finger = fingers[id] { finger.position = touch.location(in: self); fingers[id] = finger }
        }
        maxFingers=max(maxFingers,fingers.count)
        longPress?.invalidate()
        if fingers.count == 1, let p=fingers.values.first?.position {
            if isDirectTouch {
                directTouchStartedInside = acceptsDirectTouch(at: p)
                guard directTouchStartedInside else { return }
                absolute(p)
            }
            if model?.inputMode == "mouse", pendingTap?.isValid == true, distance(p,lastTap)<24 {
                pendingTap?.invalidate(); click(); button("left",down:true); dragging=true
            }
            if !dragging {
                let trackpad = model?.inputMode == "trackpad"
                longPress=Timer.scheduledTimer(withTimeInterval:0.45,repeats:false){[weak self] _ in
                    guard let self, self.fingers.count==1, !self.moved else{return}
                    if self.isDirectTouch {
                        guard self.directTouchStartedInside, let point = self.fingers.values.first?.position, self.acceptsDirectTouch(at: point) else { return }
                    }
                    self.pendingTap?.invalidate()
                    if trackpad { self.dragging=true; self.button("left",down:true) }
                    else { self.longPressed=true; self.click(button:"right") }
                }
            }
        } else if fingers.count >= 2 {
            pendingTap?.invalidate(); releaseButtons()
            let points = fingers.sorted { $0.key < $1.key }.map(\.value)
            previousCenter=center(of: points.map(\.position))
            if fingers.count == 2 { twoFingerGesture.begin(first: points[0].position, second: points[1].position) }
        }
    }
    private func center(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        return CGPoint(x:points.reduce(0){$0+$1.x}/CGFloat(points.count), y:points.reduce(0){$0+$1.y}/CGFloat(points.count))
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let previous=fingers
        for touch in event?.allTouches ?? touches {
            let id=ObjectIdentifier(touch)
            if var finger=fingers[id] {finger.position=touch.location(in:self);fingers[id]=finger;if distance(finger.start,finger.position)>10{moved=true;longPress?.invalidate()}}
        }
        if maxFingers==1, fingers.count==1, let entry=fingers.first, let before=previous[entry.key] {
            guard !longPressed else { return }
            let p=entry.value.position
            if isDirectTouch {
                guard directTouchStartedInside && acceptsDirectTouch(at: p) else {
                    directTouchStartedInside = false
                    releaseButtons()
                    return
                }
                if moved && !directDown { absolute(entry.value.start); button("left",down:true); directDown=true }
                absolute(p)
            } else {relative(CGPoint(x:p.x-before.position.x,y:p.y-before.position.y))}
        } else if fingers.count == 1 && maxFingers == 2, let entry = fingers.first, let before = previous[entry.key] {
            if case .scroll(let delta) = twoFingerGesture.moveRemainingFinger(from: before.position, to: entry.value.position) {
                scroll(delta, touch: true)
            }
        } else if fingers.count==2 && maxFingers==2 {
            let points = fingers.sorted { $0.key < $1.key }.map(\.value)
            switch twoFingerGesture.move(first: points[0].position, second: points[1].position, canvasOnly: usesOriginalGestures) {
            case .scroll(let delta):
                if delta != .zero { moved = true }
                scroll(delta, touch: true)
            case .transform(let factor, let previous, let current):
                moved = true
                transformCanvas(by: factor, from: previous, to: current)
            }
        } else if fingers.count==3 {
            let center = center(of: Array(fingers.values).map(\.position))
            let delta = usesOriginalGestures
                ? CGPoint(x: 0, y: center.y - previousCenter.y)
                : CGPoint(x: center.x - previousCenter.x, y: 0)
            if usesOriginalGestures && delta != .zero { moved = true }
            scroll(delta, touch: true)
            previousCenter = center
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasDragging=dragging || directDown
        let point=touches.first?.location(in:self) ?? .zero
        for touch in touches {fingers.removeValue(forKey:ObjectIdentifier(touch))}
        longPress?.invalidate()
        if fingers.isEmpty {
            twoFingerGesture.end()
            releaseButtons()
            if !wasDragging && !longPressed && !moved && CACurrentMediaTime()-began<0.45 {
                if maxFingers==2 && !isDirectTouch {pendingTap?.invalidate();click(button:"right")}
                else if maxFingers==1 {
                    if isDirectTouch {
                        if directTouchStartedInside && acceptsDirectTouch(at: point) { absolute(point); click() }
                    }
                    else if pendingTap?.isValid == true && distance(point,lastTap)<24 {
                        pendingTap?.invalidate();click();click()
                    } else {
                        lastTap=point
                        pendingTap=Timer.scheduledTimer(withTimeInterval:0.22,repeats:false){[weak self] _ in self?.click()}
                    }
                }
            }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {releaseInput()}
    private func releaseButtons() {
        if dragging || directDown {button("left",down:false)}
        dragging=false;directDown=false
    }
    func releaseInput() {longPress?.invalidate();pendingTap?.invalidate();releaseButtons();fingers.removeAll();maxFingers=0;twoFingerGesture.end()}
    @objc private func hovered(_ gesture: UIHoverGestureRecognizer) {if gesture.state == .changed {absolute(gesture.location(in:self))}}
    @objc private func wheeled(_ gesture: UIPanGestureRecognizer) {
        let translation=gesture.translation(in:self);scroll(translation);gesture.setTranslation(.zero,in:self)
    }
    func toggleSystemKeyboard() {
        if keyboard.isFirstResponder { hideSystemKeyboard() } else { showSystemKeyboard() }
    }
    func showSystemKeyboard() {
        releaseInput()
        keyboard.keyboardType = .default
        let replacing = keyboard.inputView != nil
        model?.remoteKeyboardVisible = false
        keyboard.inputView = nil
        if keyboard.isFirstResponder { if replacing { keyboard.reloadInputViews() } }
        else { _ = keyboard.becomeFirstResponder() }
    }
    private var shortcutKeyboardHeight: CGFloat {
        let size = window?.bounds.size ?? bounds.size
        guard min(size.width, size.height) >= 550 else { return max(240, size.height * 0.45) }
        if size.width > size.height { return max(200, size.height * 0.39) }
        let fraction = size.width / max(1, size.height) >= 0.62 ? 0.375 : 0.45
        return max(240, size.height * fraction)
    }
    func showShortcutKeyboard() {
        guard let model else { return }
        releaseInput()
        keyboard.inputView = NativeShortcutInputView(model: model, height: shortcutKeyboardHeight, width: window?.bounds.width ?? bounds.width)
        model.remoteKeyboardVisible = true
        if keyboard.isFirstResponder { keyboard.reloadInputViews() }
        else { _ = keyboard.becomeFirstResponder() }
    }
    func hideSystemKeyboard() {
        _ = keyboard.resignFirstResponder()
        keyboard.inputView = nil
        if model?.remoteKeyboardVisible == true { model?.remoteKeyboardVisible = false }
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text.isEmpty, textView.markedTextRange == nil {key("VK_BACK");return false}
        if text == "\n" {key("VK_RETURN");return false}
        return true
    }
    func textViewDidChange(_ textView: UITextView) {
        guard textView.markedTextRange == nil else{return}
        let text=textView.text.replacingOccurrences(of:"\u{200B}",with:"")
        if !text.isEmpty {_ = try? model?.core.call("text",["value":text])}
        textView.text="\u{200B}"
    }
    private func key(_ value: String) {_ = try? model?.core.call("key",["value":value])}
    private func distance(_ a: CGPoint,_ b: CGPoint)->CGFloat {hypot(a.x-b.x,a.y-b.y)}
}


@available(iOS 17.0, *)
final class NativeShortcutInputView: UIInputView {
    init(model: NativeShellModel, height: CGFloat, width: CGFloat, terminal: NativeTerminalModel? = nil) {
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: height), inputViewStyle: .default)
        autoresizingMask = [.flexibleWidth]
        allowsSelfSizing = true
        backgroundColor = nativeKeyboardBackgroundColor
        isOpaque = true
        layer.cornerRadius = 28
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        clipsToBounds = true
        heightAnchor.constraint(equalToConstant: height).isActive = true
        let content = UIHostingConfiguration {
            GeometryReader { geometry in
                NativeRemoteKeyboard(model: model,
                    visible: Binding(get: { terminal?.shortcutKeyboardVisible ?? model.remoteKeyboardVisible }, set: { value in if let terminal { terminal.shortcutKeyboardVisible = value } else { model.remoteKeyboardVisible = value } }),
                    compact: geometry.size.height < 220, terminal: terminal)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.margins(.all, 0).makeContentView()
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    required init?(coder: NSCoder) { nil }
}


struct NativeTwoFingerGesture {
    private static let scrollThreshold: CGFloat = 8
    enum Action: Equatable {
        case scroll(CGPoint)
        case transform(CGFloat, CGPoint, CGPoint)
    }
    private enum Mode { case pending, scroll, transform }
    private var mode = Mode.pending
    private var initialDistance: CGFloat = 0
    private var previousDistance: CGFloat = 0
    private var initialFirst = CGPoint.zero
    private var initialSecond = CGPoint.zero
    private var initialCenter = CGPoint.zero
    private var previousCenter = CGPoint.zero
    mutating func begin(first: CGPoint, second: CGPoint) {
        let keepScrolling = mode == .scroll
        initialFirst = first; initialSecond = second
        initialDistance = hypot(second.x - first.x, second.y - first.y)
        previousDistance = initialDistance
        initialCenter = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        previousCenter = initialCenter
        mode = keepScrolling ? .scroll : .pending
    }
    mutating func move(first: CGPoint, second: CGPoint, canvasOnly: Bool = false) -> Action {
        let distance = hypot(second.x - first.x, second.y - first.y)
        let center = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        if mode == .pending {
            if abs(distance - initialDistance) > max(12, initialDistance * 0.08)
                || (canvasOnly && hypot(center.x - initialCenter.x, center.y - initialCenter.y) >= 6) { mode = .transform }
            else if !canvasOnly && abs(first.y - initialFirst.y) >= Self.scrollThreshold && abs(second.y - initialSecond.y) >= Self.scrollThreshold
                && (first.y - initialFirst.y) * (second.y - initialSecond.y) > 0 { mode = .scroll }
            else { return .scroll(.zero) }
        }
        let action: Action = mode == .transform
            ? .transform(previousDistance > 0 ? distance / previousDistance : 1, previousCenter, center)
            : .scroll(CGPoint(x: 0, y: center.y - previousCenter.y))
        previousCenter = center; previousDistance = distance
        return action
    }
    func moveRemainingFinger(from previous: CGPoint, to current: CGPoint) -> Action {
        .scroll(mode == .scroll ? CGPoint(x: 0, y: current.y - previous.y) : .zero)
    }
    mutating func end() { mode = .pending }
}
