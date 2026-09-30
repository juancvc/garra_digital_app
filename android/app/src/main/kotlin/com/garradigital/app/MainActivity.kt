package com.garradigital.app

import android.location.Address
import android.location.Geocoder
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.garradigital.app/social_area").setMethodCallHandler { call, result ->
            if (call.method != "resolveSocialArea") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val latitude = call.argument<Double>("latitude")
            val longitude = call.argument<Double>("longitude")
            if (latitude == null || longitude == null ||
                !latitude.isFinite() || !longitude.isFinite() ||
                latitude !in -90.0..90.0 || longitude !in -180.0..180.0) {
                result.success(null)
                return@setMethodCallHandler
            }
            val geocoder = Geocoder(this, Locale.getDefault())
            fun finish(addresses: List<Address>?) {
                val address = addresses?.firstOrNull()
                val label = listOf(address?.subLocality, address?.locality,
                    address?.subAdminArea, address?.adminArea)
                    .firstOrNull { !it.isNullOrBlank() }?.trim()
                runOnUiThread { result.success(label) }
            }
            try {
                if (Build.VERSION.SDK_INT >= 33) {
                    geocoder.getFromLocation(latitude, longitude, 1,
                        object : Geocoder.GeocodeListener {
                            override fun onGeocode(addresses: MutableList<Address>) {
                                finish(addresses)
                            }
                            override fun onError(errorMessage: String?) {
                                runOnUiThread { result.success(null) }
                            }
                        })
                } else {
                    Thread {
                        try {
                            @Suppress("DEPRECATION")
                            val addresses = geocoder.getFromLocation(latitude, longitude, 1)
                            finish(addresses)
                        } catch (_: Exception) {
                            runOnUiThread { result.success(null) }
                        }
                    }.start()
                }
            } catch (_: Exception) {
                result.success(null)
            }
        }
    }
}
