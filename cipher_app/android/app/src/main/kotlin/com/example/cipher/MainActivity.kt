package com.sanruki.cipher

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "cipher.audio"

  private var previousMode: Int? = null
  private var previousSpeakerOn: Boolean? = null
  private var focusRequest: AudioFocusRequest? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "configureForCall" -> {
            try {
              configureForCall()
              result.success(true)
            } catch (e: Exception) {
              result.error("AUDIO_CONFIG_FAILED", e.message, null)
            }
          }
          "resetAfterCall" -> {
            try {
              resetAfterCall()
              result.success(true)
            } catch (e: Exception) {
              result.error("AUDIO_RESET_FAILED", e.message, null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun audioManager(): AudioManager {
    return getSystemService(Context.AUDIO_SERVICE) as AudioManager
  }

  private fun configureForCall() {
    val am = audioManager()

    if (previousMode == null) previousMode = am.mode
    if (previousSpeakerOn == null) previousSpeakerOn = am.isSpeakerphoneOn

    requestFocus(am)
    am.mode = AudioManager.MODE_IN_COMMUNICATION
    am.isSpeakerphoneOn = true
  }

  private fun requestFocus(am: AudioManager) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        if (focusRequest != null) return
        val attrs = AudioAttributes.Builder()
          .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
          .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
          .build()
        val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
          .setAudioAttributes(attrs)
          .setAcceptsDelayedFocusGain(false)
          .setOnAudioFocusChangeListener { }
          .build()
        focusRequest = req
        am.requestAudioFocus(req)
      } else {
        @Suppress("DEPRECATION")
        am.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
      }
    } catch (_: Exception) {}
  }

  private fun abandonFocus(am: AudioManager) {
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val req = focusRequest
        if (req != null) {
          am.abandonAudioFocusRequest(req)
          focusRequest = null
        }
      } else {
        @Suppress("DEPRECATION")
        am.abandonAudioFocus(null)
      }
    } catch (_: Exception) {}
  }

  private fun resetAfterCall() {
    val am = audioManager()
    abandonFocus(am)

    val spk = previousSpeakerOn
    if (spk != null) am.isSpeakerphoneOn = spk

    val mode = previousMode
    if (mode != null) am.mode = mode

    previousMode = null
    previousSpeakerOn = null
  }
}
