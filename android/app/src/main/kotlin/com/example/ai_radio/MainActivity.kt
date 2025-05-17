package com.example.ai_radio

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ai.picovoice.cheetah.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "cheetah_transcription"
    private lateinit var cheetah: Cheetah
    private lateinit var audioRecord: AudioRecord
    private var isRecording = false
    private lateinit var handler: Handler
    private lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        handler = Handler(Looper.getMainLooper())

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTranscription" -> {
                    startCheetah()
                    result.success(null)
                }
                "stopTranscription" -> {
                    stopCheetah()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun startCheetah() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 1)
            return
        }

        val accessKey = "PgugZ5fBW4wJwZepkKSzxyPhLW6kavyZC84zK5zDejCqTzHu/xHwlQ=="
        val modelPath = "AIRA-cheetah-v2.1.0-25-05-17--09-28-43.pv" // Adjust path if needed

        cheetah = Cheetah.Builder()
            .setAccessKey(accessKey)
            .setModelPath(modelPath)
            .build(applicationContext)

        val sampleRate = cheetah.sampleRate
        val bufferSize = AudioRecord.getMinBufferSize(sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )

        isRecording = true
        audioRecord.startRecording()

        Thread {
            val frameLength = cheetah.frameLength
            val buffer = ShortArray(frameLength)

            while (isRecording) {
                val read = audioRecord.read(buffer, 0, frameLength)
                if (read > 0) {
                    val partialResult = cheetah.process(buffer)
                    if (partialResult.transcript.isNotEmpty()) {
                        sendTranscript(partialResult.transcript)
                    }

                    if (partialResult.isEndpoint) {
                        val finalResult = cheetah.flush()
                        if (finalResult.transcript.isNotEmpty()) {
                            sendTranscript(finalResult.transcript)
                        }
                    }
                }
            }
        }.start()
    }

    private fun stopCheetah() {
        isRecording = false
        if (::audioRecord.isInitialized) {
            audioRecord.stop()
            audioRecord.release()
        }
        if (::cheetah.isInitialized) {
            cheetah.delete()
        }
    }

    private fun sendTranscript(transcript: String) {
        handler.post {
            methodChannel.invokeMethod("onTranscript", transcript)
        }
    }
}
