package com.wael.app

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Screenshots, screen recording and the recent-apps thumbnail are
        // blocked while FLAG_SECURE is set. Dart turns it on only for the
        // protected video player screen and clears it when that screen closes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "isEnabled" -> {
                        val flags = window.attributes.flags
                        result.success(flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
                    }
                    else -> result.notImplemented()
                }
            }
        // Downloaded subject PDFs: open in the phone's PDF app or share. The
        // file must be inside <cache>/pdfs; the receiving app gets a
        // content:// URI with read permission for this intent only.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILES_CHANNEL)
            .setMethodCallHandler { call, result ->
                val uri = call.argument<String>("path")?.let { pdfUri(it) }
                when (call.method) {
                    "open" -> {
                        if (uri == null) {
                            result.success("failed")
                            return@setMethodCallHandler
                        }
                        val view = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, PDF_MIME)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        try {
                            startActivity(view)
                            result.success("opened")
                        } catch (e: ActivityNotFoundException) {
                            result.success("no_app")
                        } catch (e: SecurityException) {
                            result.success("failed")
                        }
                    }
                    "share" -> {
                        if (uri == null) {
                            result.success("failed")
                            return@setMethodCallHandler
                        }
                        val title = call.argument<String>("title") ?: ""
                        val send = Intent(Intent.ACTION_SEND)
                            .setType(PDF_MIME)
                            .putExtra(Intent.EXTRA_STREAM, uri)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        // The grant reaches the app picked in the chooser.
                        send.clipData = ClipData.newRawUri(title, uri)
                        try {
                            startActivity(Intent.createChooser(send, title))
                            result.success("opened")
                        } catch (e: ActivityNotFoundException) {
                            result.success("no_app")
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // content:// URI for [path] when it is an existing file inside
    // <cache>/pdfs (canonical paths, so `..` and symlinks cannot escape).
    private fun pdfUri(path: String): Uri? {
        return try {
            val root = File(cacheDir, "pdfs").canonicalFile
            val file = File(path).canonicalFile
            if (!file.isFile || !file.path.startsWith(root.path + File.separator)) {
                null
            } else {
                FileProvider.getUriForFile(this, "$packageName.files", file)
            }
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        const val SECURE_CHANNEL = "com.wael.app/secure_screen"
        const val FILES_CHANNEL = "com.wael.app/files"
        const val PDF_MIME = "application/pdf"
    }
}
