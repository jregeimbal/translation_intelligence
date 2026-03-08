package com.example.translation_intelligence

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioManager
import android.os.Bundle
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private var deviceEventSink: EventChannel.EventSink? = null
	private var audioDeviceCallback: AudioDeviceCallback? = null
	private var selectedPlaybackDeviceId: String? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		selectedPlaybackDeviceId = null
	}

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
				"getPlaybackDevices" -> {
					result.success(getPlaybackDevices())
				}
				"getCurrentPlaybackDeviceId" -> {
					result.success(getCurrentPlaybackDeviceId())
				}
				"setPlaybackDevice" -> {
					val deviceId = call.argument<String>("deviceId")
					result.success(setPlaybackDevice(deviceId))
				}
				else -> result.notImplemented()
			}
		}

		EventChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"com.example.translation_intelligence/audio_route_events"
		).setStreamHandler(object : EventChannel.StreamHandler {
			override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
				deviceEventSink = events
				emitDeviceRouteEvent("initial")

				if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
					return
				}

				val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
				if (audioManager == null) {
					deviceEventSink?.success(mapOf("event" to "audio_manager_unavailable"))
					return
				}

				audioDeviceCallback = object : AudioDeviceCallback() {
					override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
						emitDeviceRouteEvent("devices_added")
					}

					override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
						emitDeviceRouteEvent("devices_removed")
					}
				}

				audioManager.registerAudioDeviceCallback(audioDeviceCallback, null)
			}

			override fun onCancel(arguments: Any?) {
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
					val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
					audioDeviceCallback?.let { callback ->
						audioManager?.unregisterAudioDeviceCallback(callback)
					}
				}
				audioDeviceCallback = null
				deviceEventSink = null
			}
		})
	}

	private fun emitDeviceRouteEvent(eventName: String) {
		runOnUiThread {
			deviceEventSink?.success(
				mapOf(
					"event" to eventName,
					"timestamp" to System.currentTimeMillis(),
				)
			)
		}
	}

	private fun getPlaybackDevices(): List<Map<String, String>> {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
			return emptyList()
		}

		val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
			?: return emptyList()
		val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

		return outputDevices
			.filter { it.isSink }
			.map { device ->
				mapOf(
					"id" to device.id.toString(),
					"name" to (device.productName?.toString() ?: ""),
					"type" to audioDeviceTypeName(device.type),
				)
			}
	}

	private fun getCurrentPlaybackDeviceId(): String? {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
			return selectedPlaybackDeviceId
		}

		val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
			?: return selectedPlaybackDeviceId
		return audioManager.communicationDevice?.id?.toString() ?: selectedPlaybackDeviceId
	}

	private fun setPlaybackDevice(deviceId: String?): Boolean {
		val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
			?: return false

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			if (deviceId.isNullOrEmpty()) {
				audioManager.clearCommunicationDevice()
				selectedPlaybackDeviceId = null
				return true
			}

			val target = audioManager.availableCommunicationDevices.firstOrNull {
				it.id.toString() == deviceId
			}
			if (target == null) {
				return false
			}

			val applied = audioManager.setCommunicationDevice(target)
			if (applied) {
				selectedPlaybackDeviceId = deviceId
			}
			return applied
		}

		selectedPlaybackDeviceId = deviceId
		return false
	}

	private fun audioDeviceTypeName(type: Int): String {
		return when (type) {
			AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth A2DP"
			AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth SCO"
			AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Built-in Earpiece"
			AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Built-in Speaker"
			AudioDeviceInfo.TYPE_BLE_HEADSET -> "BLE Headset"
			AudioDeviceInfo.TYPE_BLE_SPEAKER -> "BLE Speaker"
			AudioDeviceInfo.TYPE_BLE_BROADCAST -> "BLE Broadcast"
			AudioDeviceInfo.TYPE_DOCK -> "Dock"
			AudioDeviceInfo.TYPE_HDMI -> "HDMI"
			AudioDeviceInfo.TYPE_HDMI_ARC -> "HDMI ARC"
			AudioDeviceInfo.TYPE_HDMI_EARC -> "HDMI eARC"
			AudioDeviceInfo.TYPE_HEARING_AID -> "Hearing Aid"
			AudioDeviceInfo.TYPE_LINE_ANALOG -> "Line Analog"
			AudioDeviceInfo.TYPE_LINE_DIGITAL -> "Line Digital"
			AudioDeviceInfo.TYPE_USB_DEVICE -> "USB Device"
			AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Headset"
			AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired Headphones"
			AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
			else -> "Type $type"
		}
	}
}
