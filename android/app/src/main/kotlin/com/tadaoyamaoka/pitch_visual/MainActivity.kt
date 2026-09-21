package com.tadaoyamaoka.pitch_visual

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Handler
import android.os.Build
import android.os.Looper
import android.provider.OpenableColumns
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import org.json.JSONObject

/** Device I/O only. Signal processing, WAV storage and application state live in Dart. */
class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val fileExecutor = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null
    private var methods: MethodChannel? = null
    private var events: EventChannel? = null
    @Volatile private var recorder: AudioRecord? = null
    private var sampleRate = 44100
    private var appInBackground = false
    private var permissionResult: MethodChannel.Result? = null
    private var pickerResult: MethodChannel.Result? = null
    private var pickerKind: String? = null
    private var player: MediaPlayer? = null
    private var playerPath: String? = null
    private var lastPlaybackPositionMs = 0
    private var focusRequest: AudioFocusRequest? = null
    private val audioManager by lazy { getSystemService(AUDIO_SERVICE) as AudioManager }
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change < 0) mainHandler.post {
            if (player != null) {
                val position = player?.currentPosition
                stopPlayback()
                lastPlaybackPositionMs = position ?: 0
                emit("interrupted", "Audio playback was interrupted by another application.", "audio", position)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methods = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pitch_visual/platform")
            .also { it.setMethodCallHandler(this) }
        events = EventChannel(flutterEngine.dartExecutor.binaryMessenger, "pitch_visual/audio")
            .also { it.setStreamHandler(this) }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) { eventSink = sink }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        permissionResult?.error("cancelled", "Microphone request was cancelled.", null)
        permissionResult = null
        stopCapture()
        stopPlayback()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "startCapture" -> requestCapture(result)
                "stopCapture" -> {
                    permissionResult?.error("cancelled", "Microphone request was cancelled.", null)
                    permissionResult = null
                    stopCapture()
                    result.success(null)
                }
                "play" -> {
                    play(call.argument<String>("path") ?: error("Missing path"),
                        call.argument<Number>("positionMs")?.toInt() ?: 0)
                    result.success(null)
                }
                "pausePlayback" -> {
                    val current = player
                    if (current?.isPlaying == true) current.pause()
                    lastPlaybackPositionMs = current?.currentPosition ?: lastPlaybackPositionMs
                    result.success(lastPlaybackPositionMs)
                }
                "stopPlayback" -> { stopPlayback(); result.success(null) }
                "getStorageDirectory" -> result.success(filesDir.absolutePath)
                "pickFile" -> pickFile(call.argument<String>("kind") ?: "tuning", result)
                "loadPreferences" -> {
                    val json = getSharedPreferences("pitch_visual", MODE_PRIVATE).getString("settings", null)
                    val legacy = getSharedPreferences("vocalpitchmonitor_settings", MODE_PRIVATE).all
                    result.success(json ?: if (legacy.isNotEmpty()) JSONObject(legacy).toString() else null)
                }
                "savePreferences" -> {
                    val json = call.argument<String>("json") ?: error("Missing settings JSON")
                    getSharedPreferences("pitch_visual", MODE_PRIVATE).edit().putString("settings", json).apply()
                    result.success(null)
                }
                "setKeepScreenOn" -> {
                    if (call.argument<Boolean>("enabled") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("platformError", error.message ?: "Device operation failed.", null)
        }
    }

    private fun requestCapture(result: MethodChannel.Result) {
        if (recorder != null) { result.success(sampleRate); return }
        if (permissionResult != null) { result.error("busy", "A microphone permission request is already open.", null); return }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            permissionResult = result
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 1001)
        } else startCapture(result)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 1001) return
        val result = permissionResult ?: return
        permissionResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) startCapture(result)
        else result.error("permissionDenied", "Microphone access is required for live pitch detection. Enable it in system settings.", null)
    }

    @Suppress("MissingPermission")
    private fun startCapture(result: MethodChannel.Result) {
        if (appInBackground) { result.error("inactive", "Open the application to use the microphone.", null); return }
        stopPlayback()
        var created: AudioRecord? = null
        try {
            for (rate in intArrayOf(44100, 48000)) {
                val minimum = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                if (minimum <= 0) continue
                val candidate = AudioRecord(MediaRecorder.AudioSource.MIC, rate,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(minimum, 8192))
                if (candidate.state == AudioRecord.STATE_INITIALIZED) {
                    created = candidate
                    sampleRate = rate
                    break
                }
                candidate.release()
            }
            val active = created ?: error("No supported microphone input is available.")
            active.startRecording()
            if (active.recordingState != AudioRecord.RECORDSTATE_RECORDING) error("Could not start the microphone.")
            recorder = active
            Thread({
                val buffer = ByteArray(4096)
                try {
                    while (recorder === active) {
                        val count = active.read(buffer, 0, buffer.size)
                        if (count > 0) {
                            val bytes = buffer.copyOf(count)
                            mainHandler.post {
                                if (recorder === active) eventSink?.success(mapOf(
                                    "type" to "pcm", "data" to bytes, "sampleRate" to sampleRate))
                            }
                        } else if (count < 0 && recorder === active) {
                            mainHandler.post {
                                if (recorder === active) {
                                    stopCapture()
                                    emit("error", "Microphone input stopped (code $count).")
                                }
                            }
                            break
                        }
                    }
                } catch (error: Exception) {
                    mainHandler.post {
                        if (recorder === active) {
                            recorder = null
                            emit("error", error.message ?: "Microphone input stopped.")
                        }
                    }
                } finally {
                    active.release()
                }
            }, "PitchVisualCapture").also { it.start() }
            result.success(sampleRate)
        } catch (error: Exception) {
            recorder = null
            created?.release()
            result.error("captureFailed", error.message ?: "Could not start the microphone.", null)
        }
    }

    private fun stopCapture() {
        val active = recorder ?: return
        recorder = null
        try { active.stop() } catch (_: IllegalStateException) { }
        // stop() unblocks read(); the worker releases its own recorder after read returns.
    }

    private fun play(path: String, positionMs: Int) {
        val file = File(path).canonicalFile
        require(file.path.startsWith(filesDir.canonicalPath + File.separator)) { "Playback file must be in application storage." }
        require(file.isFile) { "Recording does not exist." }
        stopCapture()
        if (player != null && playerPath == file.path) {
            player?.seekTo(maxOf(0, positionMs))
            player?.start()
            return
        }
        stopPlayback()
        requestPlaybackFocus()
        val current = MediaPlayer()
        try {
            current.setDataSource(file.path)
            current.setOnCompletionListener {
                if (player === it) { stopPlayback(); emit("playbackComplete") }
            }
            current.setOnErrorListener { failed, what, extra ->
                if (player === failed) { stopPlayback(); emit("error", "Audio playback failed ($what/$extra).") }
                true
            }
            current.prepare()
            player = current
            playerPath = file.path
            current.seekTo(maxOf(0, positionMs))
            current.start()
        } catch (error: Exception) {
            if (player !== current) current.release()
            stopPlayback()
            throw error
        }
    }

    private fun stopPlayback() {
        val current = player
        player = null
        playerPath = null
        lastPlaybackPositionMs = 0
        current?.release()
        if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        else audioManager.abandonAudioFocus(focusListener)
        focusRequest = null
    }

    @Suppress("DEPRECATION")
    private fun requestPlaybackFocus() {
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                .setOnAudioFocusChangeListener(focusListener, mainHandler).build()
            focusRequest = request
            audioManager.requestAudioFocus(request)
        } else audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Audio playback is unavailable while another application is using audio." }
    }

    private fun pickFile(kind: String, result: MethodChannel.Result) {
        require(kind == "audio" || kind == "tuning") { "Unknown document type." }
        if (pickerResult != null) { result.error("busy", "A document picker is already open.", null); return }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            if (kind == "audio") putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("audio/*", "application/octet-stream"))
        }
        pickerResult = result
        pickerKind = kind
        try { startActivityForResult(intent, 1002) } catch (error: Exception) {
            pickerResult = null
            pickerKind = null
            throw error
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 1002) return
        val result = pickerResult ?: return
        val kind = pickerKind
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            pickerResult = null
            pickerKind = null
            result.success(null)
            return
        }
        fileExecutor.execute {
            try {
                val limit = if (kind == "audio") 64 * 1024 * 1024 else 1024 * 1024
                val picked = readDocument(uri, limit)
                mainHandler.post {
                    if (pickerResult === result) {
                        pickerResult = null
                        pickerKind = null
                        result.success(picked)
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    if (pickerResult === result) {
                        pickerResult = null
                        pickerKind = null
                        result.error("fileReadFailed", error.message ?: "Could not read the selected document.", null)
                    }
                }
            }
        }
    }

    private fun readDocument(uri: Uri, limit: Int): Map<String, Any> {
        var name = uri.lastPathSegment ?: "Imported file"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameColumn >= 0 && !cursor.isNull(nameColumn)) name = cursor.getString(nameColumn)
                val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) require(cursor.getLong(sizeColumn) <= limit) { "Selected file is too large." }
            }
        }
        val bytes = contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                require(output.size() + count <= limit) { "Selected file is too large." }
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        } ?: error("Cannot open the selected document.")
        return mapOf("name" to name, "bytes" to bytes)
    }

    private fun emit(type: String, message: String? = null, reason: String? = null, positionMs: Int? = null) {
        val event = mutableMapOf<String, Any>("type" to type)
        if (message != null) event["message"] = message
        if (reason != null) event["reason"] = reason
        if (positionMs != null) event["positionMs"] = positionMs
        eventSink?.success(event)
    }

    override fun onStop() {
        appInBackground = true
        val interrupted = recorder != null || player?.isPlaying == true
        val position = player?.currentPosition
        val previousPosition = lastPlaybackPositionMs
        stopCapture()
        stopPlayback()
        lastPlaybackPositionMs = position ?: previousPosition
        if (interrupted) emit("interrupted", "Audio stopped while the application was inactive.", "background", position)
        super.onStop()
    }

    override fun onStart() {
        super.onStart()
        appInBackground = false
    }

    override fun onDestroy() {
        stopCapture()
        stopPlayback()
        permissionResult?.error("cancelled", "The application closed.", null)
        permissionResult = null
        pickerResult?.success(null)
        pickerResult = null
        fileExecutor.shutdownNow()
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        eventSink = null
        super.onDestroy()
    }
}
