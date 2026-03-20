import Flutter
import UIKit
import TwilioVoice
import PushKit
import CallKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, CallDelegate, PKPushRegistryDelegate, CXProviderDelegate, NotificationDelegate {
    var accessToken: String?
    var activeCall: Call?
    var callInvite: CallInvite?
    var eventSink: FlutterEventSink?
    
    var callKitProvider: CXProvider?
    var callKitCallController = CXCallController()
    var activeCallUUID: UUID?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        let voiceChannel = FlutterMethodChannel(name: "twilio_voice_channel",
                                                  binaryMessenger: controller.binaryMessenger)
        
        voiceChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "registerToken":
                if let args = call.arguments as? [String: Any],
                   let token = args["token"] as? String {
                    self.accessToken = token
                    self.registerPushKit()
                    print("Token registered on iOS")
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARG", message: "Token is missing", details: nil))
                }
            case "makeCall":
                if let args = call.arguments as? [String: Any],
                   let to = args["to"] as? String,
                   let token = self.accessToken {
                    self.makeCall(to: to, token: token)
                    result(nil)
                } else {
                    result(FlutterError(code: "UNAUTHORIZED", message: "Token or 'to' is missing", details: nil))
                }
            case "answerCall":
                if let uuid = self.activeCallUUID {
                    let answerCallAction = CXAnswerCallAction(call: uuid)
                    let transaction = CXTransaction(action: answerCallAction)
                    self.callKitCallController.request(transaction) { error in
                        if let error = error {
                            print("DEBUG: Failed to request answer transaction: \(error.localizedDescription)")
                            result(FlutterError(code: "CALL_ERROR", message: error.localizedDescription, details: nil))
                        } else {
                            result(nil)
                        }
                    }
                } else {
                    result(FlutterError(code: "NO_CALL", message: "No active call UUID", details: nil))
                }
            case "rejectCall":
                if let uuid = self.activeCallUUID {
                    let endCallAction = CXEndCallAction(call: uuid)
                    let transaction = CXTransaction(action: endCallAction)
                    self.callKitCallController.request(transaction) { error in
                        if let error = error {
                            print("DEBUG: Failed to request reject transaction: \(error.localizedDescription)")
                            result(FlutterError(code: "CALL_ERROR", message: error.localizedDescription, details: nil))
                        } else {
                            result(nil)
                        }
                    }
                } else {
                    result(FlutterError(code: "NO_CALL", message: "No active call UUID", details: nil))
                }
            case "disconnect":
                print("Disconnecting call with UUID: \(String(describing: self.activeCallUUID))")
                if let uuid = self.activeCallUUID {
                    let endCallAction = CXEndCallAction(call: uuid)
                    let transaction = CXTransaction(action: endCallAction)
                    self.callKitCallController.request(transaction) { error in
                        if let error = error {
                            print("Failed to request disconnect transaction: \(error.localizedDescription)")
                        }
                    }
                }
                self.activeCall?.disconnect()
                result(nil)
            case "toggleMute":
                if let args = call.arguments as? [String: Any],
                   let isMuted = args["isMuted"] as? Bool {
                    self.activeCall?.isMuted = isMuted
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARG", message: "isMuted is missing", details: nil))
                }
            case "toggleSpeaker":
                if let args = call.arguments as? [String: Any],
                   let isSpeakerOn = args["isSpeakerOn"] as? Bool {
                    self.toggleSpeaker(isOn: isSpeakerOn)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARG", message: "isSpeakerOn is missing", details: nil))
                }
            case "requestPermission":
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("Notification permission failed: \(error.localizedDescription)")
                        result(false)
                    } else {
                        result(granted)
                    }
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        let eventChannel = FlutterEventChannel(name: "twilio_voice_events",
                                                binaryMessenger: controller.binaryMessenger)
        eventChannel.setStreamHandler(self)
        
        setupCallKit()

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func setupCallKit() {
        let configuration = CXProviderConfiguration(localizedName: "Twilio Voice")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = false
        configuration.supportedHandleTypes = [.generic]
        
        callKitProvider = CXProvider(configuration: configuration)
        callKitProvider?.setDelegate(self, queue: nil)
    }

    func registerPushKit() {
        let pushRegistry = PKPushRegistry(queue: DispatchQueue.main)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.voIP]
    }

    func toggleSpeaker(isOn: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if isOn {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            print("Failed to toggle speaker: \(error.localizedDescription)")
        }
    }

    func makeCall(to: String, token: String) {
        let uuid = UUID()
        self.activeCallUUID = uuid
        
        let connectOptions = ConnectOptions(accessToken: token) { (builder) in
            builder.params = ["To": to]
        }
        activeCall = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        
        let handle = CXHandle(type: .generic, value: to)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        let transaction = CXTransaction(action: startCallAction)
        callKitCallController.request(transaction) { error in
            if let error = error {
                print("Failed to request transaction: \(error.localizedDescription)")
            }
        }
    }

    // MARK: PKPushRegistryDelegate
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        print("VoIP Push Token received: \(pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined())")
        if let token = self.accessToken {
            print("Registering with Twilio using token for identity...")
            TwilioVoiceSDK.register(accessToken: token, deviceToken: pushCredentials.token) { error in
                if let error = error {
                    print("Twilio registration failed: \(error.localizedDescription)")
                } else {
                    print("Twilio registration SUCCESSFUL")
                }
            }
        } else {
            print("Access token not available yet, will register with Twilio when available")
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("Incoming VoIP Push Payload: \(payload.dictionaryPayload)")
        let handled = TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
        if !handled {
             print("Twilio SDK could not handle the push payload")
        }
        completion()
    }

    // MARK: CallDelegate
    func callDidConnect(call: Call) {
        print("Call connected to: \(call.sid)")
        activeCall = call
        eventSink?("connected")
    }

    func endCallKit() {
        print("DEBUG: endCallKit() called, activeCallUUID: \(String(describing: activeCallUUID))")
        if let uuid = activeCallUUID {
            // reportCall is better for calls that ENDED (e.g., remote or error)
            // CXEndCallAction is better for calls that the user DISCONNECTS
            callKitProvider?.reportCall(with: uuid, endedAt: Date(), reason: .remoteEnded)
            activeCallUUID = nil
        }
    }

    func callDidDisconnect(call: Call, error: Error?) {
        print("DEBUG: callDidDisconnect sid: \(call.sid)")
        endCallKit()
        activeCall = nil
        eventSink?("disconnected")
    }

    func callDidFailToConnect(call: Call, error: Error) {
        print("DEBUG: callDidFailToConnect error: \(error.localizedDescription)")
        endCallKit()
        activeCall = nil
        eventSink?("error: \(error.localizedDescription)")
    }

    func callIsRinging(call: Call) {
        print("DEBUG: callIsRinging sid: \(call.sid)")
        if let uuid = activeCallUUID {
            callKitProvider?.reportOutgoingCall(with: uuid, startedConnectingAt: Date())
        }
        eventSink?("ringing")
    }
    
    func callIsReconnecting(call: Call, error: Error) {
        print("DEBUG: callIsReconnecting")
        eventSink?("reconnecting")
    }
    
    func callDidReconnect(call: Call) {
        print("DEBUG: callDidReconnect")
        eventSink?("reconnected")
    }
    
    // MARK: NotificationDelegate
    @objc func callInviteReceived(callInvite: CallInvite) {
        print("DEBUG: callInviteReceived from: \(callInvite.from ?? "Unknown")")
        self.callInvite = callInvite
        eventSink?("incoming_call|\(callInvite.from ?? "Unknown")")
        
        let uuid = UUID()
        self.activeCallUUID = uuid
        
        // Report to CallKit
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callInvite.from ?? "Unknown")
        callKitProvider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("DEBUG: Failed to report incoming call to CallKit: \(error.localizedDescription)")
            } else {
                print("DEBUG: Successfully reported incoming call to CallKit with UUID: \(uuid)")
            }
        }
    }

    @objc func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        print("DEBUG: cancelledCallInviteReceived sid: \(cancelledCallInvite.callSid)")
        endCallKit()
        self.callInvite = nil
        eventSink?("cancelled")
    }

    // MARK: CXProviderDelegate
    func providerDidReset(_ provider: CXProvider) {
        print("DEBUG: providerDidReset")
        activeCall?.disconnect()
        activeCall = nil
        activeCallUUID = nil
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("DEBUG: CXAnswerCallAction")
        if let invite = self.callInvite {
            let acceptOptions = AcceptOptions(callInvite: invite)
            self.activeCall = invite.accept(options: acceptOptions, delegate: self)
            self.callInvite = nil
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("DEBUG: CXEndCallAction")
        
        // If it's an ongoing call
        if activeCall != nil {
            activeCall?.disconnect()
            activeCall = nil
            eventSink?("disconnected")
        }
        
        // If it's an incoming invite that wasn't answered yet
        if callInvite != nil {
            callInvite?.reject()
            callInvite = nil
            eventSink?("cancelled")
        }
        
        activeCallUUID = nil
        action.fulfill()
    }
}

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
