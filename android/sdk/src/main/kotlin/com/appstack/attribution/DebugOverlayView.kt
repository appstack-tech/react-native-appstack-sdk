package com.appstack.attribution

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

@SuppressLint("ViewConstructor")
internal class DebugOverlayView(context: Context) : FrameLayout(context) {

    private val textView: TextView
    private val contentLayout: LinearLayout
    private val collapsedButton: Button
    private lateinit var eventsTextView: TextView
    private lateinit var eventsHeader: Button
    private lateinit var eventsScrollView: ScrollView
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f

    private var isCollapsed = false
    private var eventsCollapsed = false

    companion object {
        const val TAG = "AppStackDebugOverlayView"
        // Overlay size in dp for maximized state
        private const val OVERLAY_WIDTH_DP = 320
        private const val OVERLAY_HEIGHT_DP = 420
    }

    // Pixel dimensions for the maximized overlay, pre-computed for reuse (needed when toggling)
    private val overlayWidthPx: Int = (OVERLAY_WIDTH_DP * resources.displayMetrics.density).toInt()
    private val overlayHeightPx: Int = (OVERLAY_HEIGHT_DP * resources.displayMetrics.density).toInt()

    init {
        // Set a tag to easily find this view later
        tag = TAG

        // Use the pre-computed pixel dimensions for the maximized state
        val overlayWidthPx = this.overlayWidthPx
        val overlayHeightPx = this.overlayHeightPx

        // Root vertical container holding header + debug content
        contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
        }

        // Header bar with title + actions
        val headerBar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val titleView = TextView(context).apply {
            text = "AppStack Debug"
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            textSize = 14f
        }

        val collapseBtn = Button(context).apply {
            text = "−"
            textSize = 12f
            setOnClickListener { toggleCollapse() }
        }

        headerBar.addView(titleView, LinearLayout.LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        headerBar.addView(collapseBtn)

        contentLayout.addView(headerBar)

        // Scrollable area for the debug text (monospace for easier reading)
        val scrollView = ScrollView(context).apply {
            isFillViewport = true
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        textView = TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = 12f
            typeface = Typeface.MONOSPACE
        }
        scrollView.addView(textView)
        contentLayout.addView(scrollView)

        // ----------------------------------------------------------------------------
        // Events dedicated section ----------------------------------------------------
        // ----------------------------------------------------------------------------

        eventsHeader = Button(context).apply {
            text = "Events (0) ▼"
            textSize = 12f
            setTypeface(typeface, Typeface.BOLD)
            setBackgroundColor(Color.TRANSPARENT)
            setTextColor(Color.WHITE)
            setOnClickListener { toggleEventsVisibility() }
        }
        contentLayout.addView(eventsHeader)

        eventsScrollView = ScrollView(context).apply {
            isFillViewport = true
            layoutParams = LinearLayout.LayoutParams(
                LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }
        eventsTextView = TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = 12f
            typeface = Typeface.MONOSPACE
        }
        eventsScrollView.addView(eventsTextView)
        contentLayout.addView(eventsScrollView)

        // "Flush Now" button allowing developers to force-flush the queue
        val flushButton = Button(context).apply {
            text = "Flush Now"
            setBackgroundColor(Color.parseColor("#FF6200EE"))
            setTextColor(Color.WHITE)
            setOnClickListener { AppStackAttributionSdk.flush() }
        }
        contentLayout.addView(flushButton, LinearLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

        // Add the full content layout to this FrameLayout
        addView(contentLayout, LayoutParams(
            LayoutParams.MATCH_PARENT,
            LayoutParams.MATCH_PARENT
        ))

        // Collapsed floating button (initially hidden)
        collapsedButton = Button(context).apply {
            text = "Debug"
            visibility = View.GONE
            setOnClickListener { toggleCollapse() }
            setOnTouchListener { _, event ->
                this@DebugOverlayView.onTouchEvent(event)
                false
            }
        }
        addView(collapsedButton)

        // Background with rounded corners for nicer look
        val bg = android.graphics.drawable.GradientDrawable().apply {
            cornerRadius = 16 * resources.displayMetrics.density
            setColor(Color.parseColor("#CC000000"))
        }
        background = bg

        // Set initial position (e.g., top-left) and fixed size for maximized state
        val layoutParams = LayoutParams(
            overlayWidthPx,
            overlayHeightPx
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            // Small starting margin
            leftMargin = 20
            topMargin = 200
        }
        this.layoutParams = layoutParams

        val padding = (10 * resources.displayMetrics.density).toInt()
        setPadding(padding, padding, padding, padding)
        // Ensure the overlay cannot be resized by content when maximized
        minimumWidth = overlayWidthPx
        minimumHeight = overlayHeightPx
        // For API 21+, set max size to prevent expansion
        // Fix: Remove usage of maxWidth and maxHeight, which are not available on FrameLayout
        // (see https://issuetracker.google.com/issues/37067913 and Android docs)
        // If you want to enforce max size, you must override onMeasure, but for now, just omit.
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        scope.launch {
            DebugStateProvider.formattedDebugString.collectLatest { text ->
                val idx = text.indexOf("Events:")
                val display = if (idx >= 0) text.substring(0, idx).trimEnd() else text
                textView.text = display
            }
        }

        scope.launch {
            DebugStateProvider.eventLines.collectLatest { lines ->
                eventsTextView.text = lines.joinToString("\n")
                eventsHeader.text = "Events (${lines.size}) ${if (eventsCollapsed) "▶" else "▼"}"
            }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        scope.cancel()
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        // This is a bit of a hack to get the view's params, but it's the simplest way for a view added directly
        val params = this.layoutParams as LayoutParams

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                initialX = params.leftMargin
                initialY = params.topMargin
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                params.leftMargin = initialX + (event.rawX - initialTouchX).toInt()
                params.topMargin = initialY + (event.rawY - initialTouchY).toInt()
                // We directly update layout params because we are not in a Relative/Constraint Layout
                this.layoutParams = params
                return true
            }
        }
        return super.onTouchEvent(event)
    }

    private fun toggleCollapse() {
        isCollapsed = !isCollapsed
        val params = this.layoutParams as LayoutParams

        if (isCollapsed) {
            // Hide content, show bubble
            contentLayout.visibility = View.GONE
            collapsedButton.visibility = View.VISIBLE
            // Reduce padding for compact button
            collapsedButton.setPadding(20, 10, 20, 10)

            // Shrink the overlay container so only the button is visible
            params.width = LayoutParams.WRAP_CONTENT
            params.height = LayoutParams.WRAP_CONTENT
            this.layoutParams = params

            // Remove the enforced min size while collapsed
            minimumWidth = 0
            minimumHeight = 0
        } else {
            // Restore full content
            contentLayout.visibility = View.VISIBLE
            collapsedButton.visibility = View.GONE

            // Restore the original overlay size
            params.width = overlayWidthPx
            params.height = overlayHeightPx
            this.layoutParams = params

            // Reinstate min size when expanded
            minimumWidth = overlayWidthPx
            minimumHeight = overlayHeightPx
        }
    }

    private fun toggleEventsVisibility() {
        eventsCollapsed = !eventsCollapsed
        eventsScrollView.visibility = if (eventsCollapsed) View.GONE else View.VISIBLE
        // Update header arrow immediately
        val currentText = eventsHeader.text.toString()
        // Replace arrow symbol only (last char)
        eventsHeader.text = currentText.dropLast(1) + if (eventsCollapsed) "▶" else "▼"
    }
} 