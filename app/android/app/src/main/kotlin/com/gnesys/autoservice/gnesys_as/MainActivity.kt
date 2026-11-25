package com.gnesys.autoservice.gnesys_as

import android.app.StatusBarManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        //window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
    private fun _modoPantallaCompleta() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let {
                it.hide(android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars())
                it.systemBarsBehavior =
                    android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
    }

    private fun _bloquearBarraNotificaciones() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val statusBarService = getSystemService("statusbar")
                val statusBarClass = Class.forName("android.app.StatusBarManager")
                val collapseMethod = statusBarClass.getMethod("collapsePanels")
                collapseMethod.isAccessible = true
                collapseMethod.invoke(statusBarService)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            _modoPantallaCompleta()
        }
    }

    override fun onResume() {
        super.onResume()
        _modoPantallaCompleta()
    }

    override fun onBackPressed() {
        // Bloqueado intencionalmente
    }
}