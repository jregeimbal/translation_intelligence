import Flutter
import UIKit
import AVFAudio

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let audioRecordChannelName = "com.speechlogic.omnialingo/audio_record"
  private var routeEventSink: FlutterEventSink?
  private var routeChangeObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioRouteEvents") else {
      return
    }

    let methodChannel = FlutterMethodChannel(
      name: Self.audioRecordChannelName,
      binaryMessenger: registrar.messenger()
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }

      switch call.method {
      case "getPlaybackDevices":
        result(self.getPlaybackDevices())
      case "getCurrentPlaybackDeviceId":
        result(self.getCurrentPlaybackDeviceId())
      case "setPlaybackDevice":
        let args = call.arguments as? [String: Any]
        let deviceId = args?["deviceId"] as? String
        result(self.setPlaybackDevice(deviceId))
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: "com.speechlogic.omnialingo/audio_route_events",
      binaryMessenger: registrar.messenger()
    )
    eventChannel.setStreamHandler(self)
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    routeEventSink = events
    emitRouteEvent("initial")

    routeChangeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] _ in
      self?.emitRouteEvent("route_changed")
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = routeChangeObserver {
      NotificationCenter.default.removeObserver(observer)
    }
    routeChangeObserver = nil
    routeEventSink = nil
    return nil
  }

  private func emitRouteEvent(_ event: String) {
    routeEventSink?([
      "event": event,
      "timestamp": Int(Date().timeIntervalSince1970 * 1000),
    ])
  }

  private func getPlaybackDevices() -> [[String: String]] {
    let audioSession = AVAudioSession.sharedInstance()
    var devices: [[String: String]] = []
    var seen = Set<String>()

    func addDevice(id: String, name: String, type: String) {
      if id.isEmpty || seen.contains(id) {
        return
      }
      seen.insert(id)
      devices.append([
        "id": id,
        "name": name,
        "type": type,
      ])
    }

    for output in audioSession.currentRoute.outputs {
      let id = "ios_output:\(output.uid)"
      addDevice(
        id: id,
        name: output.portName,
        type: audioPortTypeName(output.portType)
      )
    }

    addDevice(id: "ios_speaker", name: "Speaker", type: "Built-in Speaker")

    if UIDevice.current.userInterfaceIdiom == .phone {
      addDevice(id: "ios_receiver", name: "Receiver", type: "Built-in Receiver")
    }

    for input in audioSession.availableInputs ?? [] {
      let id = "ios_input:\(input.uid)"
      addDevice(
        id: id,
        name: input.portName,
        type: audioPortTypeName(input.portType)
      )
    }

    return devices
  }

  private func getCurrentPlaybackDeviceId() -> String? {
    let audioSession = AVAudioSession.sharedInstance()

    if let currentOutput = audioSession.currentRoute.outputs.first {
      switch currentOutput.portType {
      case .builtInSpeaker:
        return "ios_speaker"
      case .builtInReceiver:
        return "ios_receiver"
      default:
        if let matchingInput = (audioSession.availableInputs ?? []).first(where: {
          $0.uid == currentOutput.uid || $0.portType == currentOutput.portType
        }) {
          return "ios_input:\(matchingInput.uid)"
        }
        return "ios_output:\(currentOutput.uid)"
      }
    }

    return nil
  }

  private func setPlaybackDevice(_ deviceId: String?) -> Bool {
    let audioSession = AVAudioSession.sharedInstance()

    do {
      if deviceId == nil || deviceId?.isEmpty == true {
        try audioSession.setPreferredInput(nil)
        try audioSession.overrideOutputAudioPort(.none)
        return true
      }

      guard let deviceId = deviceId else {
        return false
      }

      if deviceId == "ios_speaker" {
        try audioSession.overrideOutputAudioPort(.speaker)
        return true
      }

      if deviceId == "ios_receiver" {
        try audioSession.overrideOutputAudioPort(.none)
        if let builtInMic = (audioSession.availableInputs ?? []).first(where: {
          $0.portType == .builtInMic
        }) {
          try audioSession.setPreferredInput(builtInMic)
        }
        return true
      }

      let inputPrefix = "ios_input:"
      if deviceId.hasPrefix(inputPrefix) {
        let uid = String(deviceId.dropFirst(inputPrefix.count))
        if let input = (audioSession.availableInputs ?? []).first(where: { $0.uid == uid }) {
          try audioSession.setPreferredInput(input)
          try audioSession.overrideOutputAudioPort(.none)
          return true
        }
        return false
      }

      let outputPrefix = "ios_output:"
      if deviceId.hasPrefix(outputPrefix) {
        let uid = String(deviceId.dropFirst(outputPrefix.count))
        if let input = (audioSession.availableInputs ?? []).first(where: { $0.uid == uid }) {
          try audioSession.setPreferredInput(input)
          try audioSession.overrideOutputAudioPort(.none)
          return true
        }
      }

      return false
    } catch {
      return false
    }
  }

  private func audioPortTypeName(_ portType: AVAudioSession.Port) -> String {
    switch portType {
    case .airPlay:
      return "AirPlay"
    case .bluetoothA2DP:
      return "Bluetooth A2DP"
    case .bluetoothHFP:
      return "Bluetooth HFP"
    case .bluetoothLE:
      return "Bluetooth LE"
    case .builtInMic:
      return "Built-in Microphone"
    case .builtInReceiver:
      return "Built-in Receiver"
    case .builtInSpeaker:
      return "Built-in Speaker"
    case .carAudio:
      return "Car Audio"
    case .headphones:
      return "Headphones"
    case .headsetMic:
      return "Headset"
    case .HDMI:
      return "HDMI"
    case .lineIn:
      return "Line In"
    case .lineOut:
      return "Line Out"
    case .usbAudio:
      return "USB Audio"
    @unknown default:
      return String(describing: portType)
    }
  }
}
