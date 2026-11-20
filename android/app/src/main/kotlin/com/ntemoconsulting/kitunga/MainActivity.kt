package com.ntemoconsulting.kitunga

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // L'application dit si elle contient une clé Google Maps : sans clé,
        // les cartes restent sur OpenStreetMap (voir kitunga_map.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "site.kitunga.app/config").setMethodCallHandler { call, result ->
            if (call.method == "hasMapsKey") {
                val key = try {
                    packageManager.getApplicationInfo(packageName,
                        PackageManager.GET_META_DATA).metaData
                        ?.getString("com.google.android.geo.API_KEY")
                } catch (e: Exception) { null }
                result.success(!key.isNullOrBlank())
            } else {
                result.notImplemented()
            }
        }
    }
}
