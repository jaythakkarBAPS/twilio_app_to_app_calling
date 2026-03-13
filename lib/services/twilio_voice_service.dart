import 'package:flutter/services.dart';

class TwilioVoiceService {
  static const MethodChannel _channel = MethodChannel('twilio_voice_channel');
  static const EventChannel _eventChannel = EventChannel('twilio_voice_events');

  // Singleton pattern
  static final TwilioVoiceService _instance = TwilioVoiceService._internal();

  factory TwilioVoiceService() {
    return _instance;
  }

  TwilioVoiceService._internal();

  /// Pass the backend-generated access token to the native SDK
  Future<void> registerToken(String token) async {
    try {
      await _channel.invokeMethod('registerToken', {'token': token});
    } on PlatformException catch (e) {
      print("Failed to register token: '${e.message}'.");
    }
  }

  /// Make an outgoing call to a specific recipient (client:to or number)
  Future<void> makeCall(String to) async {
    try {
      await _channel.invokeMethod('makeCall', {'to': to});
    } on PlatformException catch (e) {
      print("Failed to make call: '${e.message}'.");
    }
  }

  /// Answer an incoming call
  Future<void> answerCall() async {
    try {
      await _channel.invokeMethod('answerCall');
    } on PlatformException catch (e) {
      print("Failed to answer call: '${e.message}'.");
    }
  }

  /// Toggle mute status
  Future<void> toggleMute(bool isMuted) async {
    try {
      await _channel.invokeMethod('toggleMute', {'isMuted': isMuted});
    } on PlatformException catch (e) {
      print("Failed to toggle mute: '${e.message}'.");
    }
  }

  /// Toggle speakerphone
  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    try {
      await _channel.invokeMethod('toggleSpeaker', {'isSpeakerOn': isSpeakerOn});
    } on PlatformException catch (e) {
      print("Failed to toggle speaker: '${e.message}'.");
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    try {
      await _channel.invokeMethod('rejectCall');
    } on PlatformException catch (e) {
      print("Failed to reject call: '${e.message}'.");
    }
  }

  /// Ends the active call
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      print("Failed to disconnect call: '${e.message}'.");
    }
  }

  /// Listen to call events from native side (e.g., ringing, connected, disconnected)
  Stream<String> get callEvents {
    return _eventChannel.receiveBroadcastStream().map((event) => event.toString());
  }
}
