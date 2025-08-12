package com.appstack.attribution

import android.util.Log
import com.appstack.attribution.LogLevel

object Logger {
    private var level: LogLevel = LogLevel.INFO

    fun setLevel(l: LogLevel) {
        level = l
    }

    private fun shouldLog(l: LogLevel) = l.ordinal >= level.ordinal

    fun d(tag: String, msg: String) { if (shouldLog(LogLevel.DEBUG)) Log.d(tag, msg) }
    fun i(tag: String, msg: String) { if (shouldLog(LogLevel.INFO)) Log.i(tag, msg) }
    fun w(tag: String, msg: String) { if (shouldLog(LogLevel.WARN)) Log.w(tag, msg) }
    fun e(tag: String, msg: String, t: Throwable? = null) {
        if (shouldLog(LogLevel.ERROR)) Log.e(tag, msg, t)
    }
} 