package com.example.twilio_app_to_app_calling

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.twilio.voice.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "TwilioVoice"
    private val CHANNEL = "twilio_voice_channel"
    private val EVENT_CHANNEL = "twilio_voice_events"

    private var accessToken: String? = null
    private var activeCall: Call? = null
    private var callInvite: CallInvite? = null
    private var eventSink: EventChannel.EventSink? = null
    private var fcmToken: String? = null

    private val callListener = object : Call.Listener {
        override fun onConnectFailure(call: Call, error: CallException) {
            Log.e(TAG, "Connect failure: ${error.message}")
            eventSink?.success("error: ${error.message}")
        }

        override fun onRinging(call: Call) {
            Log.d(TAG, "Ringing")
            eventSink?.success("ringing")
        }

        override fun onConnected(call: Call) {
            Log.d(TAG, "Connected")
            activeCall = call
            eventSink?.success("connected")
        }

        override fun onReconnecting(call: Call, error: CallException) {
            Log.d(TAG, "Reconnecting")
            eventSink?.success("reconnecting")
        }

        override fun onReconnected(call: Call) {
            Log.d(TAG, "Reconnected")
            eventSink?.success("reconnected")
        }

        override fun onDisconnected(call: Call, error: CallException?) {
            Log.d(TAG, "Disconnected")
            activeCall = null
            eventSink?.success("disconnected")
        }
    }

    private val voiceBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let {
                when (it.action) {
                    MyFirebaseMessagingService.ACTION_FCM_TOKEN -> {
                        fcmToken = it.getStringExtra(MyFirebaseMessagingService.EXTRA_FCM_TOKEN)
                        Log.d(TAG, "FCM token received in MainActivity: $fcmToken")
                        registerWithTwilio()
                    }
                    MyFirebaseMessagingService.ACTION_INCOMING_CALL -> {
                        callInvite = it.getParcelableExtra(MyFirebaseMessagingService.EXTRA_CALL_INVITE)
                        Log.d(TAG, "Incoming call invite received in MainActivity via broadcast")
                        cancelNotification()
                        eventSink?.success("incoming_call|${callInvite?.from}")
                    }
                    MyFirebaseMessagingService.ACTION_CANCELLED_CALL_INVITE -> {
                        Log.d(TAG, "Call invite cancelled")
                        callInvite = null
                        cancelNotification()
                        eventSink?.success("cancelled")
                    }
                    else -> {}
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "registerToken" -> {
                    accessToken = call.argument<String>("token")
                    Log.d(TAG, "Token registered")
                    registerWithTwilio()
                    result.success(null)
                }
                "makeCall" -> {
                    val to = call.argument<String>("to")
                    if (accessToken != null && to != null) {
                        makeCall(to)
                        result.success(null)
                    } else {
                        result.error("UNAUTHORIZED", "Token or 'to' is missing", null)
                    }
                }
                "answerCall" -> {
                    callInvite?.let {
                        activeCall = it.accept(this, callListener)
                        callInvite = null
                        cancelNotification()
                        result.success(null)
                    } ?: result.error("NO_CALL", "No incoming call to answer", null)
                }
                "rejectCall" -> {
                    callInvite?.let {
                        it.reject(this)
                        callInvite = null
                        cancelNotification()
                        result.success(null)
                    } ?: result.error("NO_CALL", "No incoming call to reject", null)
                }
                "disconnect" -> {
                    activeCall?.disconnect()
                    result.success(null)
                }
                "toggleMute" -> {
                    val isMuted = call.argument<Boolean>("isMuted") ?: false
                    activeCall?.mute(isMuted)
                    result.success(null)
                }
                "toggleSpeaker" -> {
                    val isSpeakerOn = call.argument<Boolean>("isSpeakerOn") ?: false
                    toggleSpeaker(isSpeakerOn)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    notifyFlutterOfIncomingCall()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun registerWithTwilio() {
        if (accessToken != null && fcmToken != null) {
            Voice.register(accessToken!!, Voice.RegistrationChannel.FCM, fcmToken!!, object : RegistrationListener {
                override fun onRegistered(accessToken: String, fcmToken: String) {
                    Log.d(TAG, "Successfully registered for VoIP push notifications")
                }

                override fun onError(error: RegistrationException, accessToken: String, fcmToken: String) {
                    Log.e(TAG, "Registration failed: ${error.message}")
                }
            })
        }
    }

    private fun toggleSpeaker(isOn: Boolean) {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        audioManager.isSpeakerphoneOn = isOn
    }

    private fun makeCall(to: String) {
        val params = HashMap<String, String>()
        params["To"] = to

        val connectOptions = ConnectOptions.Builder(accessToken!!)
            .params(params)
            .build()
        activeCall = Voice.connect(this, connectOptions, callListener)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        val filter = IntentFilter().apply {
            addAction(MyFirebaseMessagingService.ACTION_FCM_TOKEN)
            addAction(MyFirebaseMessagingService.ACTION_INCOMING_CALL)
            addAction(MyFirebaseMessagingService.ACTION_CANCELLED_CALL_INVITE)
        }
        LocalBroadcastManager.getInstance(this).registerReceiver(voiceBroadcastReceiver, filter)
        
        intent?.let { handleIntent(it) }
        
        checkPermissions()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        when (intent.action) {
            MyFirebaseMessagingService.ACTION_INCOMING_CALL,
            MyFirebaseMessagingService.ACTION_ANSWER_CALL,
            MyFirebaseMessagingService.ACTION_REJECT_CALL -> {
                callInvite = intent.getParcelableExtra(MyFirebaseMessagingService.EXTRA_CALL_INVITE)
                Log.d(TAG, "Handling call intent in MainActivity: ${intent.action}")

                if (intent.action == MyFirebaseMessagingService.ACTION_ANSWER_CALL) {
                    activeCall = callInvite?.accept(this, callListener)
                    callInvite = null
                } else if (intent.action == MyFirebaseMessagingService.ACTION_REJECT_CALL) {
                    callInvite?.reject(this)
                    callInvite = null
                }

                cancelNotification()
                notifyFlutterOfIncomingCall()
            }
        }
    }

    private fun cancelNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.cancel(1) // NOTIFICATION_ID = 1
    }

    private fun notifyFlutterOfIncomingCall() {
        Log.d(TAG, "Notifying Flutter: callInvite=${callInvite != null}, activeCall=${activeCall != null}, eventSink=${eventSink != null}")
        val from = callInvite?.from
        if (from != null && eventSink != null) {
            eventSink?.success("incoming_call|$from")
        } else if (activeCall != null && eventSink != null) {
            eventSink?.success("connected")
        }
    }

    override fun onDestroy() {
        LocalBroadcastManager.getInstance(this).unregisterReceiver(voiceBroadcastReceiver)
        super.onDestroy()
    }

    private fun checkPermissions() {
        val permissions = arrayOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.POST_NOTIFICATIONS // For Android 13+
        )
        val missingPermissions = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missingPermissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missingPermissions.toTypedArray(), 1)
        }
    }
}
