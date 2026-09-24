package com.example.adhd_assistant

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private lateinit var widgetChannel: MethodChannel

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		widgetChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"adhd_assistant/widget_actions",
		)
		widgetChannel.setMethodCallHandler { call, result ->
			if (call.method == "getInitialWidgetAction") {
				result.success(widgetAction(intent))
			} else {
				result.notImplemented()
			}
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		if (::widgetChannel.isInitialized) {
			widgetChannel.invokeMethod("widgetAction", widgetAction(intent))
		}
	}

	private fun widgetAction(intent: Intent?): String? {
		return intent?.getStringExtra(VoiceCaptureWidget.ACTION_EXTRA)
	}
}
