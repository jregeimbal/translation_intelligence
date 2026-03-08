package com.example.translation_intelligence

import android.media.AudioFormat
import android.media.AudioRecord
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.example.translation_intelligence/audio_record"
		).setMethodCallHandler { call, result ->
			when (call.method) {
				"getMinBufferSize" -> {
					val sampleRate = call.argument<Int>("sampleRate")
					if (sampleRate == null) {
						result.error("bad_args", "sampleRate is required", null)
						return@setMethodCallHandler
					}

					val minBufferSize = AudioRecord.getMinBufferSize(
						sampleRate,
						AudioFormat.CHANNEL_IN_MONO,
						AudioFormat.ENCODING_PCM_16BIT
					)

					if (minBufferSize > 0) {
						result.success(minBufferSize)
					} else {
						result.success(0)
					}
				}
				else -> result.notImplemented()
			}
		}
	}
}
