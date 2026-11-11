package com.ludodo.checkmate

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // ANDROID_ID ties a guest account to this phone so it survives cleared
    // app data (lib/core/services/device_guest.dart). It is not used for ads.
    @SuppressLint("HardwareIds")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "checkmate/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "androidId") {
                    result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
