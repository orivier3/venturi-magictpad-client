import SwiftUI
import AppKit
import Network

protocol AppKitTouchesViewDelegate: AnyObject {
    // Provides `.touching` touches only.
    func touchesView(_ view: AppKitTouchesView, didUpdateTouchingTouches touches: Set<NSTouch>)
}

final class AppKitTouchesView: NSView {
    weak var delegate: AppKitTouchesViewDelegate?
    var connection: NWConnection?
    //192.168.0.45.
    var hostUDP: NWEndpoint.Host = "192.168.0.178"
    var portUDP: NWEndpoint.Port = 20001
    var testMessage:String = "Message from swift"
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // We're interested in `.indirect` touches only.
        allowedTouchTypes = [.indirect]
        // We'd like to receive resting touches as well.
        wantsRestingTouches = true
        
        //Initialize socket connection
        self.connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)
        self.connection?.stateUpdateHandler = { (newState) in
           print("This is stateUpdateHandler:")
           switch (newState) {
               case .ready:
                   print("State: Ready\n")
               case .setup:
                   print("State: Setup\n")
               case .cancelled:
                   print("State: Cancelled\n")
               case .preparing:
                   print("State: Preparing\n")
               default:
                   print("ERROR! State not defined!\n")
           }
       }

       self.connection?.start(queue: .global())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func handleTouches(with event: NSEvent) {
        // Get all `.touching` touches only (includes `.began`, `.moved` & `.stationary`).
        let touches = event.touches(matching: .touching, in: self)
        var index = 0
        var touchMessage = ""
        for touch in touches{
            touchMessage += "Finger\(index)-\(touch.normalizedPosition.x);\(touch.normalizedPosition.y)|"
            index+=1
        }
        print(touchMessage)
        self.sendUDP(touchMessage)
        // Forward them via delegate.
        delegate?.touchesView(self, didUpdateTouchingTouches: touches)
    }

    override func touchesBegan(with event: NSEvent) {
        handleTouches(with: event)
        let lockPoint = CGPoint(x:100,y:100)
        CGWarpMouseCursorPosition(lockPoint)
    }

    override func touchesEnded(with event: NSEvent) {
        handleTouches(with: event)
    }

    override func touchesMoved(with event: NSEvent) {
        handleTouches(with: event)
        let lockPoint = CGPoint(x:100,y:100)
        CGWarpMouseCursorPosition(lockPoint)
    }

    override func touchesCancelled(with event: NSEvent) {
        handleTouches(with: event)
    }
    override func rotate(with event: NSEvent) {
        self.sendUDP("Rotate;\(event.rotation)")
    }
    override func magnify(with event: NSEvent) {
        self.sendUDP("Pinch;\(event.magnification)")
    }
    
    func sendUDP(_ content: String) {
        let contentToSendUDP = content.data(using: String.Encoding.utf8)
        self.connection?.send(content: contentToSendUDP, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                //print("Data was sent to UDP")
            } else {
                //print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
        }
}

struct Touch: Identifiable {
    // `Identifiable` -> `id` is required for `ForEach` (see below).
    let id: Int
    // Normalized touch X position on a device (0.0 - 1.0).
    let normalizedX: CGFloat
    // Normalized touch Y position on a device (0.0 - 1.0).
    let normalizedY: CGFloat

    init(_ nsTouch: NSTouch) {
        self.normalizedX = nsTouch.normalizedPosition.x
        // `NSTouch.normalizedPosition.y` is flipped -> 0.0 means bottom. But the
        // `Touch` structure is meants to be used with the SwiftUI -> flip it.
        self.normalizedY = 1.0 - nsTouch.normalizedPosition.y
        self.id = nsTouch.hash
    }
}

struct TouchesView: NSViewRepresentable {
    // Up to date list of touching touches.
    @Binding var touches: [Touch]

    func updateNSView(_ nsView: AppKitTouchesView, context: Context) {
    }

    func makeNSView(context: Context) -> AppKitTouchesView {
        let view = AppKitTouchesView()
        view.delegate = context.coordinator
        return view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, AppKitTouchesViewDelegate {
        let parent: TouchesView

        init(_ view: TouchesView) {
            self.parent = view
        }

        func touchesView(_ view: AppKitTouchesView, didUpdateTouchingTouches touches: Set<NSTouch>) {
            parent.touches = touches.map(Touch.init)
        }
    }
}

struct TrackPadView: View {
    private let touchViewSize: CGFloat = 10

    @State var touches: [Touch] = []

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                TouchesView(touches: self.$touches)

                ForEach(self.touches) { touch in
                    Circle()
                        .foregroundColor(Color.red)
                        .frame(width: self.touchViewSize, height: self.touchViewSize)
                        .offset(
                            x: proxy.size.width * touch.normalizedX - self.touchViewSize / 2.0,
                            y: proxy.size.height * touch.normalizedY - self.touchViewSize / 2.0
                        )
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        TrackPadView()
            .background(Color.gray)
            .aspectRatio(1.6, contentMode: .fit)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
