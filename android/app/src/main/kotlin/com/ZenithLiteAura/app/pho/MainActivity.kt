package com.ZenithLiteAura.app.pho

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import run.Run

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File


class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.example.img_syncer/RunGrpcServer"
  private val NOTIFY_CHANNEL = "com.example.img_syncer/notifications"
  private val SYNC_NOTIFICATION_CHANNEL_ID = "pho_sync"
  private val SYNC_NOTIFICATION_ID = 1001

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
        call,
        result ->
      if (call.method == "RunGrpcServer") {
        val re =  Run.runGrpcServer()
        result.success(re)
      } else if (call.method == "scanFile") {
        scanFile(call.argument("path"), call.argument("volumeName"), call.argument("relativePath"), call.argument("mimeType"))
        result.success(null)
      } else {
        result.notImplemented()
      }
    }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFY_CHANNEL)
        .setMethodCallHandler { call, result ->
          when (call.method) {
            "requestAuthorization" -> {
              requestNotificationPermission()
              result.success(hasNotificationPermission())
            }
            "checkAuthorizationStatus" -> result.success(hasNotificationPermission())
            "sendLocalNotification" -> {
              val title = call.argument<String>("title") ?: ""
              val body = call.argument<String>("body") ?: ""
              val isPassive = call.argument<Boolean>("isPassive") ?: false
              sendSyncNotification(title, body)
              result.success(null)
            }
            else -> result.notImplemented()
          }
        }
  }

  private fun requestNotificationPermission() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        !hasNotificationPermission()) {
      ActivityCompat.requestPermissions(
          this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
    }
  }

  private fun hasNotificationPermission(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      ContextCompat.checkSelfPermission(
          this, android.Manifest.permission.POST_NOTIFICATIONS) ==
          PackageManager.PERMISSION_GRANTED
    } else {
      true
    }
  }

  private fun sendSyncNotification(title: String, body: String) {
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
          SYNC_NOTIFICATION_CHANNEL_ID, "Pho 同步", NotificationManager.IMPORTANCE_DEFAULT)
      manager.createNotificationChannel(channel)
    }
    val builder = NotificationCompat.Builder(this, SYNC_NOTIFICATION_CHANNEL_ID)
        .setSmallIcon(android.R.drawable.stat_notify_sync)
        .setContentTitle(title)
        .setContentText(body)
        .setAutoCancel(true)
        .setPriority(NotificationCompat.PRIORITY_DEFAULT)
    manager.notify(SYNC_NOTIFICATION_ID, builder.build())
  }

  private fun scanFile(path: String?, volumeName: String?, relativePath: String?, mimeType: String?) {
    // if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        // val values = ContentValues().apply {
        //     put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
        //     put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
        //     put(MediaStore.MediaColumns.IS_PENDING, 1)
        // }

        // val contentUri: Uri = MediaStore.Files.getContentUri(volumeName)
        // val itemUri = contentResolver.insert(contentUri, values)
        
        // values.clear()
        // values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        // contentResolver.update(itemUri!!, null, null)
        // } else {
            val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
            val file = File(path)
            val contentUri = Uri.fromFile(file)
            mediaScanIntent.data = contentUri
            sendBroadcast(mediaScanIntent)
        // }
  }
}
