
import SwiftUI
import SwiftGodotKit
import SwiftGodot

class GodotApp: ObservableObject {
    let maxTouchCount = 32
    var touches: [UITouch?] = []
    
    @Published var instance: GodotInstance?
    
    func createInstance(scene: String) {
        touches = [UITouch?](repeating: nil, count: maxTouchCount)
        instance = GodotInstance.create(args: ["--main-pack", (Bundle.main.resourcePath ?? ".") + "/" + scene, "--rendering-driver", "vulkan", "--rendering-method", "mobile", "--display-driver", "embedded"])
    }
    
    func getTouchId(touch: UITouch) -> Int {
        var first = -1
        for i in 0 ... maxTouchCount - 1 {
            if first == -1 && touches[i] == nil {
                first = i;
                continue;
            }
            if (touches[i] == touch) {
                return i;
            }
        }

        if (first != -1) {
            touches[first] = touch;
            return first;
        }

        return -1;
    }

    func removeTouchId(id: Int) {
        touches[id] = nil
    }
}

struct GodotAppView : UIViewRepresentable {
    @EnvironmentObject var app: GodotApp
    var view = UIGodotAppView()
    
    func makeUIView(context: Context) -> UIGodotAppView {
        view.contentScaleFactor = UIScreen.main.scale
        view.isMultipleTouchEnabled = true
        view.app = app
        return view
    }

    func updateUIView(_ uiView: UIGodotAppView, context: Context) {
        uiView.startGodotInstance()
    }
}

class UIGodotAppView : UIView {

    public var renderingLayer: CAMetalLayer!
    private var displayLink : CADisplayLink? = nil
    
    private var embedded: DisplayServerEmbedded!
    
    public var app: GodotApp?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        renderingLayer = CAMetalLayer()
        let size = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        renderingLayer.frame.size = CGSize(width: size, height: size)
        renderingLayer.contentsScale = self.contentScaleFactor
        
        layer.addSublayer(renderingLayer)
    }
    
    deinit {
        renderingLayer.removeFromSuperlayer()
    }
    
    override func layoutSubviews() {
        renderingLayer.frame = self.bounds
        if let instance = app?.instance {
            if instance.isStarted() {
                if embedded == nil {
                    embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle)
                }
                
                embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width * self.contentScaleFactor), y: Int32(self.bounds.size.height * self.contentScaleFactor)), id: Int32(DisplayServer.mainWindowId))
            }
        }
        super.layoutSubviews()
    }
    
    func startGodotInstance() {
        if let instance = app?.instance {
            if !instance.isStarted() {
                let rendererNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(renderingLayer!).toOpaque()))
                DisplayServerEmbedded.setNativeSurface(rendererNativeSurface)
                instance.start()
                displayLink = CADisplayLink(target: self, selector: #selector(iterate))
                displayLink!.add(to: .current, forMode: RunLoop.Mode.default)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let contentsScale = renderingLayer.contentsScale
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                var location = touch.location(in: self)
                if !self.layer.frame.contains(location) {
                    continue
                }
                location.x -= self.renderingLayer.frame.origin.x
                location.y -= self.renderingLayer.frame.origin.y
                let tapCount = touch.tapCount
                touchData.append([ "touchId": touchId, "location": location, "tapCount": tapCount ])
            }
            {
                let windowId = Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    let location = touch["location"] as! CGPoint
                    let tapCount = touch["tapCount"] as! Int
                    (DisplayServer.shared as! DisplayServerEmbedded).touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: true, doubleClick: tapCount > 1, window: windowId)
                }
            }()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let contentsScale = renderingLayer.contentsScale
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                var location = touch.location(in: self)
                if !self.layer.frame.contains(location) {
                    continue
                }
                location.x -= self.renderingLayer.frame.origin.x
                location.y -= self.renderingLayer.frame.origin.y
                var prevLocation = touch.previousLocation(in: self)
                if !self.layer.frame.contains(prevLocation) {
                    continue
                }
                prevLocation.x -= self.renderingLayer.frame.origin.x
                prevLocation.y -= self.renderingLayer.frame.origin.y
                let alt = touch.altitudeAngle
                let azim = touch.azimuthUnitVector(in: self)
                let force = touch.force
                let maximumPossibleForce = touch.maximumPossibleForce
                touchData.append([ "touchId": touchId, "location": location, "prevLocation": prevLocation, "alt": alt, "azim": azim, "force": force, "maximumPossibleForce": maximumPossibleForce ])
            }
            
            {
                let windowId = Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    let location = touch["location"] as! CGPoint
                    let prevLocation = touch["prevLocation"] as! CGPoint
                    let alt = touch["alt"] as! CGFloat
                    let azim = touch["azim"] as! CGVector
                    let force = touch["force"] as! CGFloat
                    let maximumPossibleForce = touch["maximumPossibleForce"] as! CGFloat
                    (DisplayServer.shared as! DisplayServerEmbedded).touchDrag(idx: Int32(touchId), prevX: Int32(prevLocation.x  * contentsScale), prevY: Int32(prevLocation.y  * contentsScale), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressure: Double(force) / Double(maximumPossibleForce), tilt: Vector2(x: Float(azim.dx) * Float(cos(alt)), y: Float(azim.dy) * cos(Float(alt))), window: windowId)
                }
            }()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let contentsScale = renderingLayer.contentsScale
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                app!.removeTouchId(id: touchId)
                var location = touch.location(in: self)
                if !self.layer.frame.contains(location) {
                    continue
                }
                location.x -= self.renderingLayer.frame.origin.x
                location.y -= self.renderingLayer.frame.origin.y
                touchData.append([ "touchId": touchId, "location": location ])
            }
            
            {
                let windowId = Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    let location = touch["location"] as! CGPoint
                    (DisplayServer.shared as! DisplayServerEmbedded).touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: false, doubleClick: false, window: windowId)
                }
            }()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                app!.removeTouchId(id: touchId)
                touchData.append([ "touchId": touchId ])
            }

            {
                let windowId = Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    (DisplayServer.shared as! DisplayServerEmbedded).touchesCanceled(idx: Int32(touchId), window: windowId)
                }
            }()
        }
    }

    override func removeFromSuperview() {
        displayLink?.invalidate()
        displayLink = nil
        
        if let instance = app?.instance {
            GodotInstance.destroy(instance: instance)
        }
    }
    
    override func didMoveToSuperview() {
        commonInit()
        startGodotInstance()
    }
    
    @objc
    func iterate() {
        if let instance = app?.instance {
            if instance.isStarted() {
                instance.iteration()
            }
        }
    }
}

struct GodotWindow : UIViewRepresentable {
    @EnvironmentObject var app: GodotApp
    @State var callback: ((Window)->())?
    @State var node: String?
    var view = UIGodotWindow()

    func makeUIView(context: Context) -> UIGodotWindow {
        view.contentScaleFactor = UIScreen.main.scale
        view.isMultipleTouchEnabled = true
        view.callback = callback
        view.node = node
        view.app = app
        return view
    }
        
    func updateUIView(_ uiView: UIGodotWindow, context: Context) {
        uiView.initGodotWindow()
    }
}

class UIGodotWindow : UIView {
    
    public var windowLayer: CAMetalLayer!
    private var embedded: DisplayServerEmbedded!
    private var subwindow: Window!
    
    var callback: ((Window)->())?
    var node: String?
    var app: GodotApp?
    var inited = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func commonInit() {
        windowLayer = CAMetalLayer()
        let size = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
        windowLayer.frame.size = CGSize(width: size, height: size)
        windowLayer.contentsScale = self.contentScaleFactor
        windowLayer.backgroundColor = CGColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        layer.addSublayer(windowLayer)
    }
    
    deinit {
        windowLayer.removeFromSuperlayer()
    }
    
    func initGodotWindow() {
        if (!inited) {
            if let instance = app?.instance {
                if !instance.isStarted() {
                    return
                }
                if let node {
                    subwindow = ((Engine.getMainLoop() as! SceneTree).root!.findChild(pattern: node)! as! Window)
                } else {
                    subwindow = Window()
                }
                if let callback {
                    callback(subwindow)
                }
                let windowNativeSurface = RenderingNativeSurfaceApple.create(layer: UInt(bitPattern: Unmanaged.passUnretained(windowLayer!).toOpaque()))
                subwindow.setNativeSurface(windowNativeSurface)
                (Engine.getMainLoop() as! SceneTree).root!.addChild(node: subwindow)
                inited = true
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let contentsScale = windowLayer.contentsScale
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                var location = touch.location(in: self)
                if !self.layer.frame.contains(location) {
                    continue
                }
                location.x -= self.windowLayer.frame.origin.x
                location.y -= self.windowLayer.frame.origin.y
                let tapCount = touch.tapCount
                touchData.append([ "touchId": touchId, "location": location, "tapCount": tapCount ])
            }
            {
                let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    let location = touch["location"] as! CGPoint
                    let tapCount = touch["tapCount"] as! Int
                    (DisplayServer.shared as! DisplayServerEmbedded).touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: true, doubleClick: tapCount > 1, window: windowId)
                }
            }()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let contentsScale = windowLayer.contentsScale
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                var location = touch.location(in: self)
                if !self.layer.frame.contains(location) {
                    continue
                }
                location.x -= self.windowLayer.frame.origin.x
                location.y -= self.windowLayer.frame.origin.y
                var prevLocation = touch.previousLocation(in: self)
                if !self.layer.frame.contains(prevLocation) {
                    continue
                }
                prevLocation.x -= self.windowLayer.frame.origin.x
                prevLocation.y -= self.windowLayer.frame.origin.y
                let alt = touch.altitudeAngle
                let azim = touch.azimuthUnitVector(in: self)
                let force = touch.force
                let maximumPossibleForce = touch.maximumPossibleForce
                touchData.append([ "touchId": touchId, "location": location, "prevLocation": prevLocation, "alt": alt, "azim": azim, "force": force, "maximumPossibleForce": maximumPossibleForce ])
            }
            
            {
                let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    let location = touch["location"] as! CGPoint
                    let prevLocation = touch["prevLocation"] as! CGPoint
                    let alt = touch["alt"] as! CGFloat
                    let azim = touch["azim"] as! CGVector
                    let force = touch["force"] as! CGFloat
                    let maximumPossibleForce = touch["maximumPossibleForce"] as! CGFloat
                    (DisplayServer.shared as! DisplayServerEmbedded).touchDrag(idx: Int32(touchId), prevX: Int32(prevLocation.x  * contentsScale), prevY: Int32(prevLocation.y  * contentsScale), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressure: Double(force) / Double(maximumPossibleForce), tilt: Vector2(x: Float(azim.dx) * Float(cos(alt)), y: Float(azim.dy) * cos(Float(alt))), window: windowId)
                }
            }()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let contentsScale = windowLayer.contentsScale
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                app!.removeTouchId(id: touchId)
                var location = touch.location(in: self)
                if !self.layer.frame.contains(location) {
                    continue
                }
                location.x -= self.windowLayer.frame.origin.x
                location.y -= self.windowLayer.frame.origin.y
                touchData.append([ "touchId": touchId, "location": location ])
            }
            
            {
                let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    let location = touch["location"] as! CGPoint
                    (DisplayServer.shared as! DisplayServerEmbedded).touchPress(idx: Int32(touchId), x: Int32(location.x * contentsScale), y: Int32(location.y * contentsScale), pressed: false, doubleClick: false, window: windowId)
                }
            }()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let instance = app?.instance {
            
            var touchData: [[String : Any]] = []
            for touch in touches {
                let touchId = app!.getTouchId(touch: touch)
                if touchId == -1 {
                    continue
                }
                app!.removeTouchId(id: touchId)
                touchData.append([ "touchId": touchId ])
            }

            {
                let windowId = subwindow?.getWindowId() ?? Int32(DisplayServer.mainWindowId)
                for touch in touchData {
                    let touchId = touch["touchId"] as! Int
                    (DisplayServer.shared as! DisplayServerEmbedded).touchesCanceled(idx: Int32(touchId), window: windowId)
                }
            }()
        }
    }

    
    override func layoutSubviews() {
        windowLayer.frame = self.bounds
        if inited {
            if embedded == nil {
                embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle)
            }
            embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width * self.contentScaleFactor), y: Int32(self.bounds.size.height * self.contentScaleFactor)), id: subwindow.getWindowId())
        }
        super.layoutSubviews()
    }
    
    override func removeFromSuperview() {
        subwindow.getParent()!.removeChild(node: subwindow)
    }
    
    override func didMoveToSuperview() {
        commonInit()
        initGodotWindow()
    }
}

let windowCallback = { (subwindow: Window) -> () in
    let ctr = VBoxContainer()
    ctr.setAnchorsPreset(Control.LayoutPreset.fullRect)
    subwindow.addChild(node: ctr)
    
    var button1 = Button()
    button1.text = "SubWindow 1"
    var button2 = Button()
    button2.text = "Another Button"
    ctr.addChild(node: button1)
    ctr.addChild(node: button2)
}

let windowCallback2 = { (subwindow: Window) -> () in
    let ctr = VBoxContainer()
    ctr.setAnchorsPreset(Control.LayoutPreset.fullRect)
    subwindow.addChild(node: ctr)
    
    var button1 = Button()
    button1.text = "SubWindow 2"
    var button2 = Button()
    button2.text = "Another Button 2"
    ctr.addChild(node: button1)
    ctr.addChild(node: button2)
}

let windowCallback3 = { (subwindow: Window) -> () in
    let ctr = VBoxContainer()
    ctr.setAnchorsPreset(Control.LayoutPreset.fullRect)
    subwindow.addChild(node: ctr)
    
    var button1 = Button()
    button1.text = "SubWindow 3"
    var button2 = Button()
    button2.text = "Another Button 3"
    ctr.addChild(node: button1)
    ctr.addChild(node: button2)
}

struct ContentView: View {
    @StateObject var app = GodotApp()
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            HStack {
                GodotAppView()
//                VStack {
//                    GodotWindow(callback: windowCallback)
//                    GodotWindow(callback: windowCallback2)
//                    GodotWindow(callback: windowCallback3)
//                }
            }
        }
        .padding()
        .environmentObject(app)
        .onAppear(perform: {
            app.createInstance(scene: "game.pck")
        })
    }
}  

#Preview {
    ContentView()
}
