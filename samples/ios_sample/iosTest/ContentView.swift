
import SwiftUI
import SwiftGodotKit
import SwiftGodot

class GodotApp: ObservableObject {
    @Published var instance: GodotInstance?
    
    func createInstance(scene: String) {
        instance = GodotInstance.create(args: ["--main-pack", (Bundle.main.resourcePath ?? ".") + "/" + scene, "--rendering-driver", "vulkan", "--rendering-method", "mobile", "--display-driver", "embedded"])
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
        renderingLayer.frame.size = CGSize(width: 2000, height: 2000)
        
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
                    //embedded.setContentScale(UIScreen.main.scale)
                }
                embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width), y: Int32(self.bounds.size.height)), id: Int32(DisplayServer.mainWindowId))
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
    
    override func removeFromSuperview() {
        displayLink?.invalidate()
        displayLink = nil
        
        if let instance = app?.instance {
            instance.shutdown()
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
        windowLayer.frame.size = CGSize(width: 500, height: 500)
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
    
    override func layoutSubviews() {
        windowLayer.frame = self.bounds
        if inited {
            if embedded == nil {
                embedded = DisplayServerEmbedded(nativeHandle: DisplayServer.shared.handle)
            }
            embedded.resizeWindow(size: Vector2i(x: Int32(self.bounds.size.width), y: Int32(self.bounds.size.height)), id: subwindow.getWindowId())
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
                VStack {
                    GodotWindow(callback: windowCallback)
                    GodotWindow(callback: windowCallback2)
                    GodotWindow(callback: windowCallback3)
                }
            }
        }
        .padding()
        .environmentObject(app)
        .onAppear(perform: {
            app.createInstance(scene: "main.pck")
        })
    }
}  

#Preview {
    ContentView()
}
