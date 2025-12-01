import Flutter
import UIKit
import RoomPlan

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var roomScannerHandler: AnyObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup RoomScanner platform channels and platform view
    if #available(iOS 16.0, *) {
      let controller = window?.rootViewController as! FlutterViewController
      roomScannerHandler = RoomScannerHandler(messenger: controller.binaryMessenger)

      // Register platform view factory
      let registrar = self.registrar(forPlugin: "RoomPlanView")!
      let factory = RoomPlanViewFactory(messenger: registrar.messenger(), handler: roomScannerHandler as! RoomScannerHandler)
      registrar.register(factory, withId: "com.vron.mobile/room_plan_view")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

// MARK: - RoomScanner Handler

@available(iOS 16.0, *)
@objc(VronRoomScannerHandler)
class RoomScannerHandler: NSObject {
    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?

    private var roomCaptureView: RoomCaptureView?
    private var capturedRoom: CapturedRoom?
    private var isScanning = false
    private var scanStartTime: Date?
    private var pointCount = 0

    init(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.vron.mobile/room_scanner",
            binaryMessenger: messenger
        )
        eventChannel = FlutterEventChannel(
            name: "com.vron.mobile/room_scanner_events",
            binaryMessenger: messenger
        )
        super.init()

        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }

        eventChannel.setStreamHandler(self)
    }

    // NSCoding conformance (required but not used)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func encode(with coder: NSCoder) {
        // Not implemented - not used for archiving
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isRoomPlanAvailable":
            result(RoomCaptureSession.isSupported)

        case "startScanning":
            handleStartScanning(result: result)

        case "stopScanning":
            handleStopScanning(result: result)

        case "cancelScanning":
            handleCancelScanning(result: result)

        case "exportScan":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            handleExportScan(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleStartScanning(result: @escaping FlutterResult) {
        guard !isScanning else {
            result(FlutterError(code: "ALREADY_SCANNING", message: "Scan already in progress", details: nil))
            return
        }

        guard RoomCaptureSession.isSupported else {
            result(FlutterError(code: "NOT_SUPPORTED", message: "RoomPlan not supported on this device", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let captureView = RoomCaptureView(frame: .zero)
            self.roomCaptureView = captureView

            var configuration = RoomCaptureSession.Configuration()
            configuration.isCoachingEnabled = true

            captureView.captureSession.run(configuration: configuration)
            captureView.delegate = self

            self.isScanning = true
            self.scanStartTime = Date()
            self.pointCount = 0

            self.sendEvent(type: "started", data: [:])
            result(true)
        }
    }

    private func handleStopScanning(result: @escaping FlutterResult) {
        guard isScanning else {
            result(FlutterError(code: "NOT_SCANNING", message: "No scan in progress", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.roomCaptureView?.captureSession.stop()

            guard let finalRoom = self.capturedRoom else {
                result(FlutterError(code: "NO_DATA", message: "No scan data available", details: nil))
                return
            }

            self.isScanning = false

            let scanId = UUID().uuidString
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let usdzPath = "\(documentsPath)/scans/\(scanId).usdz"

            let scansDir = "\(documentsPath)/scans"
            try? FileManager.default.createDirectory(atPath: scansDir, withIntermediateDirectories: true)

            do {
                let usdzURL = URL(fileURLWithPath: usdzPath)
                try finalRoom.export(to: usdzURL)

                let duration = Date().timeIntervalSince(self.scanStartTime ?? Date())

                let scanResult: [String: Any] = [
                    "scanId": scanId,
                    "usdzPath": usdzPath,
                    "pointCount": self.pointCount,
                    "duration": duration,
                    "dimensions": self.extractDimensions(from: finalRoom),
                    "detectedObjects": self.extractObjects(from: finalRoom)
                ]

                self.sendEvent(type: "completed", data: scanResult)
                result(scanResult)
            } catch {
                result(FlutterError(code: "EXPORT_FAILED", message: error.localizedDescription, details: nil))
            }
        }
    }

    private func handleCancelScanning(result: @escaping FlutterResult) {
        guard isScanning else {
            result(FlutterError(code: "NOT_SCANNING", message: "No scan in progress", details: nil))
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.roomCaptureView?.captureSession.stop()
            self?.isScanning = false
            self?.capturedRoom = nil
            self?.sendEvent(type: "canceled", data: [:])
            result(nil)
        }
    }

    private func handleExportScan(args: [String: Any], result: @escaping FlutterResult) {
        guard let outputPath = args["outputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        result(outputPath)
    }

    private func extractDimensions(from room: CapturedRoom) -> [String: Any] {
        // Calculate room dimensions from wall surfaces
        var totalWidth: Double = 0
        var totalLength: Double = 0
        var totalHeight: Double = 0
        var count = 0

        for surface in room.walls {
            totalWidth += Double(surface.dimensions.x)
            totalLength += Double(surface.dimensions.z)
            totalHeight += Double(surface.dimensions.y)
            count += 1
        }

        let width = count > 0 ? totalWidth / Double(count) : 0
        let length = count > 0 ? totalLength / Double(count) : 0
        let height = count > 0 ? totalHeight / Double(count) : 0
        let area = width * length

        return [
            "width": width,
            "length": length,
            "height": height,
            "area": area
        ]
    }

    private func extractObjects(from room: CapturedRoom) -> [[String: Any]] {
        var objects: [[String: Any]] = []

        for object in room.objects {
            let objectData: [String: Any] = [
                "category": String(describing: object.category),
                "identifier": object.identifier.uuidString,
                "dimensions": [
                    "width": Double(object.dimensions.x),
                    "height": Double(object.dimensions.y),
                    "depth": Double(object.dimensions.z)
                ],
                "position": [
                    "x": Double(object.transform.columns.3.x),
                    "y": Double(object.transform.columns.3.y),
                    "z": Double(object.transform.columns.3.z)
                ]
            ]
            objects.append(objectData)
        }

        return objects
    }

    private func sendEvent(type: String, data: [String: Any]) {
        guard let eventSink = eventSink else { return }

        let event: [String: Any] = [
            "type": type,
            "data": data
        ]

        eventSink(event)
    }

    func getRoomCaptureView() -> RoomCaptureView? {
        return roomCaptureView
    }
}

// MARK: - FlutterStreamHandler

@available(iOS 16.0, *)
extension RoomScannerHandler: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - RoomCaptureViewDelegate

@available(iOS 16.0, *)
extension RoomScannerHandler: RoomCaptureViewDelegate {
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        if let error = error {
            sendEvent(type: "error", data: ["error": error.localizedDescription])
            return
        }

        self.capturedRoom = processedResult

        // Estimate point count based on number of surfaces and objects
        let surfaceCount = processedResult.walls.count + processedResult.openings.count
        let objectCount = processedResult.objects.count
        let estimatedPoints = (surfaceCount * 1000) + (objectCount * 500)
        self.pointCount = estimatedPoints

        sendEvent(type: "pointsUpdated", data: [
            "pointCount": estimatedPoints,
            "progress": 0.8
        ])
    }

    func captureView(didFailWithError error: Error) {
        sendEvent(type: "error", data: ["error": error.localizedDescription])
        isScanning = false
    }

    func captureView(didProvide instruction: RoomCaptureSession.Instruction) {
        let instructionText: String
        switch instruction {
        case .moveCloseToWall:
            instructionText = "Move closer to wall"
        case .moveAwayFromWall:
            instructionText = "Move away from wall"
        case .slowDown:
            instructionText = "Slow down"
        case .turnOnLight:
            instructionText = "Turn on lights"
        case .normal:
            instructionText = "Continue scanning"
        case .lowTexture:
            instructionText = "Low texture detected"
        @unknown default:
            instructionText = "Continue scanning"
        }

        sendEvent(type: "progress", data: [
            "instruction": instructionText
        ])
    }
}

// MARK: - Platform View Factory

@available(iOS 16.0, *)
class RoomPlanViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private weak var handler: RoomScannerHandler?

    init(messenger: FlutterBinaryMessenger, handler: RoomScannerHandler) {
        self.messenger = messenger
        self.handler = handler
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return RoomPlanNativeView(frame: frame, viewIdentifier: viewId, arguments: args, handler: handler)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

@available(iOS 16.0, *)
class RoomPlanNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private weak var handler: RoomScannerHandler?

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, handler: RoomScannerHandler?) {
        _view = UIView(frame: frame)
        _view.backgroundColor = .black
        self.handler = handler
        super.init()

        // Add the RoomCaptureView if handler has one
        if let captureView = handler?.getRoomCaptureView() {
            captureView.frame = _view.bounds
            captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            _view.addSubview(captureView)
        }
    }

    func view() -> UIView {
        return _view
    }
}
