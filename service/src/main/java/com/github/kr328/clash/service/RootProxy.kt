package com.github.kr328.clash.service

import android.content.Context

object RootProxy {
    const val MARKER_FILE = "root-transparent-proxy.enabled"

    fun setEnabled(context: Context, enabled: Boolean) {
        val marker = context.filesDir.resolve("clash").resolve(MARKER_FILE)

        if (enabled) {
            marker.parentFile?.mkdirs()
            marker.writeText("1\n")
        } else {
            marker.delete()
        }
    }
}
