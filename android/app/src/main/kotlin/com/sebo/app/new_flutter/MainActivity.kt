package com.sebo.app.new_flutter

import android.database.Cursor
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SMS_CHANNEL = "com.sebo.app/sms"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSms" -> {
                        try {
                            val smsList = readSms()
                            result.success(smsList)
                        } catch (e: Exception) {
                            result.error("SMS_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSms(): List<Map<String, Any?>> {
        val smsList = mutableListOf<Map<String, Any?>>()
        val uri: Uri = Uri.parse("content://sms")
        val projection = arrayOf("address", "body", "date", "type")
        var cursor: Cursor? = null

        try {
            cursor = contentResolver.query(uri, projection, null, null, "date DESC")
            cursor?.let {
                val addressIdx = it.getColumnIndexOrThrow("address")
                val bodyIdx = it.getColumnIndexOrThrow("body")
                val dateIdx = it.getColumnIndexOrThrow("date")
                val typeIdx = it.getColumnIndexOrThrow("type")

                var count = 0
                while (it.moveToNext() && count < 2000) {
                    val type = it.getInt(typeIdx)
                    val kind = when (type) {
                        1 -> "inbox"
                        2 -> "sent"
                        else -> "other"
                    }
                    smsList.add(
                        mapOf(
                            "address" to it.getString(addressIdx),
                            "body" to it.getString(bodyIdx),
                            "date" to it.getLong(dateIdx).toString(),
                            "kind" to kind
                        )
                    )
                    count++
                }
            }
        } finally {
            cursor?.close()
        }

        return smsList
    }
}
