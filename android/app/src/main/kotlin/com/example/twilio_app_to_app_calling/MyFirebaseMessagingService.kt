package com.example.twilio_app_to_app_calling

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.twilio.voice.Voice

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token: $token")
        val intent = Intent(ACTION_FCM_TOKEN)
        intent.putExtra(EXTRA_FCM_TOKEN, token)
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "Message received from: ${remoteMessage.from}")

        if (remoteMessage.data.isNotEmpty()) {
            val valid = Voice.handleMessage(this, remoteMessage.data, object : com.twilio.voice.MessageListener {
                override fun onCallInvite(callInvite: com.twilio.voice.CallInvite) {
                    Log.d(TAG, "Call Invite received")
                    if (isAppInForeground()) {
                        val intent = Intent(ACTION_INCOMING_CALL)
                        intent.putExtra(EXTRA_CALL_INVITE, callInvite)
                        LocalBroadcastManager.getInstance(this@MyFirebaseMessagingService).sendBroadcast(intent)
                    } else {
                        showNotification(callInvite)
                    }
                }

                override fun onCancelledCallInvite(cancelledCallInvite: com.twilio.voice.CancelledCallInvite, callException: com.twilio.voice.CallException?) {
                    Log.d(TAG, "Cancelled Call Invite received")
                    cancelNotification()
                    val intent = Intent(ACTION_CANCELLED_CALL_INVITE)
                    intent.putExtra(EXTRA_CANCELLED_CALL_INVITE, cancelledCallInvite)
                    LocalBroadcastManager.getInstance(this@MyFirebaseMessagingService).sendBroadcast(intent)
                }
            })
            if (!valid) {
                Log.e(TAG, "The message was not a Twilio Voice SDK payload")
            }
        }
    }

    private fun showNotification(callInvite: com.twilio.voice.CallInvite) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        val channelId = "incoming_calls"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(channelId, "Incoming Calls", android.app.NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_INCOMING_CALL
            putExtra(EXTRA_CALL_INVITE, callInvite)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = android.app.PendingIntent.getActivity(this, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)

        val answerIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_ANSWER_CALL
            putExtra(EXTRA_CALL_INVITE, callInvite)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val answerPendingIntent = android.app.PendingIntent.getActivity(this, 1, answerIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)

        val rejectIntent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_REJECT_CALL
            putExtra(EXTRA_CALL_INVITE, callInvite)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val rejectPendingIntent = android.app.PendingIntent.getActivity(this, 2, rejectIntent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE)

        val notificationBuilder = androidx.core.app.NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Incoming Call")
            .setContentText("Call from ${callInvite.from}")
            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_MAX)
            .setCategory(androidx.core.app.NotificationCompat.CATEGORY_CALL)
            .setFullScreenIntent(pendingIntent, true)
            .addAction(android.R.drawable.ic_menu_call, "Answer", answerPendingIntent)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Reject", rejectPendingIntent)
            .setColor(android.graphics.Color.parseColor("#F22F46"))
            .setVisibility(androidx.core.app.NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setOngoing(true)
        
        notificationManager.notify(NOTIFICATION_ID, notificationBuilder.build())
    }

    private fun cancelNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
    }

    private fun isAppInForeground(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val appProcesses = activityManager.runningAppProcesses ?: return false
        val packageName = packageName
        for (appProcess in appProcesses) {
            if (appProcess.importance == android.app.ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND && appProcess.processName == packageName) {
                return true
            }
        }
        return false
    }

    companion object {
        private const val TAG = "TwilioFCM"
        private const val NOTIFICATION_ID = 1
        const val ACTION_FCM_TOKEN = "ACTION_FCM_TOKEN"
        const val EXTRA_FCM_TOKEN = "EXTRA_FCM_TOKEN"
        const val ACTION_INCOMING_CALL = "ACTION_INCOMING_CALL"
        const val ACTION_ANSWER_CALL = "ACTION_ANSWER_CALL"
        const val ACTION_REJECT_CALL = "ACTION_REJECT_CALL"
        const val EXTRA_CALL_INVITE = "EXTRA_CALL_INVITE"
        const val ACTION_CANCELLED_CALL_INVITE = "ACTION_CANCELLED_CALL_INVITE"
        const val EXTRA_CANCELLED_CALL_INVITE = "EXTRA_CANCELLED_CALL_INVITE"
    }
}
