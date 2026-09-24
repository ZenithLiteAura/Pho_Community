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
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File


class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.ZenithLiteAura.app.pho/RunGrpcServer"
  private val NOTIFY_CHANNEL = "com.ZenithLiteAura.app.pho/notifications"
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
            // 与 iOS AppDelegate 的 keepScreenOn 对称：直接操作窗口标志。
            // 不再使用 wakelock_plus —— 其 Dart 端(wakelock_plus_platform_interface
            // 1.6.0)与 Android 端(1.1.4)的 pigeon 通道名不一致，会报 channel-error。
            "keepScreenOn" -> {
              val enable = call.argument<Boolean>("enable") ?: false
              setKeepScreenOn(enable)
              result.success(true)
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

  // 保持屏幕常亮（同步/上传期间避免息屏导致网络与 CPU 被系统限制）。
  // 必须在 UI 线程操作 window；Activity 已销毁等异常仅记录，不影响主流程。
  private fun setKeepScreenOn(enable: Boolean) {
    runOnUiThread {
      try {
        if (enable) {
          window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
          window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
      } catch (e: Exception) {
        android.util.Log.w("PhoMainActivity", "setKeepScreenOn($enable) failed", e)
      }
    }
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
