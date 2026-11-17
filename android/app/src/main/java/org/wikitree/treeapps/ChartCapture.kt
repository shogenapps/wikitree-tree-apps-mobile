package org.wikitree.treeapps

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import android.widget.ImageView
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * A picture of the whole chart, not just the part on screen, for "Share this chart" and
 * "Print or save as PDF".
 *
 * The page gets ready first (shell.js `__wtShellCapture`): the app's controls are hidden and it
 * says how big the web view needs to be to hold all of the chart, or all of a list that scrolls.
 * The web view is made that size behind a still picture of the screen (so nothing jumps about),
 * the chart is laid out in it, drawn into a bitmap, and everything is put back. If the page
 * cannot do this (an older page, or something fails) it is the screen as it was.
 *
 * Drawing parts of a web view that are off screen needs WebView.enableSlowWholeDocumentDraw(),
 * called in MainActivity before the first web view is made.
 */
class ChartCapture(
    private val web: WebView,
    /** What is on screen, used as the cover and as the answer if the whole chart can't be had. */
    private val screen: Bitmap,
    private val done: (Bitmap) -> Unit,
) {
    private val density = web.resources.displayMetrics.density
    private val oldWidth = web.layoutParams.width
    private val oldHeight = web.layoutParams.height
    private var cover: ImageView? = null
    private var finished = false

    fun start() {
        // A still picture of the screen over the web view while it is resized out of sight.
        // It takes the taps too, so nothing on the page is touched meanwhile.
        (web.parent as? FrameLayout)?.let { frame ->
            cover = ImageView(web.context).apply {
                setImageBitmap(screen)
                scaleType = ImageView.ScaleType.MATRIX
                isClickable = true
                frame.addView(this, frame.indexOfChild(web) + 1, FrameLayout.LayoutParams(web.width, web.height))
            }
        }
        // If anything hangs, the screen picture is shared after a while all the same.
        web.postDelayed({ finish(null) }, TIMEOUT_MS)
        ask("begin") { size -> if (size == null) finish(null) else grow(size, 0) }
    }

    /** Make the web view [size] (CSS pixels), let the page lay out, then fit the chart to it. */
    private fun grow(size: Size, pass: Int) {
        if (finished) return
        val w = (size.w * density).roundToInt().coerceAtLeast(1)
        val h = (size.h * density).roundToInt().coerceAtLeast(1)
        val lp = web.layoutParams
        if (lp.width != w || lp.height != h) {
            lp.width = w
            lp.height = h
            web.layoutParams = lp
        }
        web.postDelayed({
            ask("fit") { need ->
                when {
                    need == null -> finish(null)
                    // A list that grew taller when it got wider (or the like): grow again, a few times at most.
                    pass < 3 && (abs(need.w - size.w) > 2 || abs(need.h - size.h) > 2) -> grow(need, pass + 1)
                    // Let the page draw the chart where it was moved to.
                    else -> web.postDelayed({ draw() }, DRAW_DELAY_MS)
                }
            }
        }, LAYOUT_DELAY_MS)
    }

    private fun draw() {
        if (finished) return
        val w = web.width
        val h = web.height
        val picture = try {
            // Kept to MAX_PIXELS: a long list is drawn smaller rather than run out of memory.
            val scale = min(1f, sqrt(MAX_PIXELS / (w.toFloat() * h)))
            Bitmap.createBitmap((w * scale).roundToInt().coerceAtLeast(1), (h * scale).roundToInt().coerceAtLeast(1),
                Bitmap.Config.ARGB_8888).also {
                val canvas = Canvas(it)
                canvas.scale(scale, scale)
                canvas.translate(-web.scrollX.toFloat(), -web.scrollY.toFloat())
                web.draw(canvas)
            }
        } catch (_: Throwable) {
            null
        }
        finish(picture)
    }

    /** Hand over the picture (or the screen), then put the web view and the page back. */
    private fun finish(picture: Bitmap?) {
        if (finished) return
        finished = true
        val lp = web.layoutParams
        lp.width = oldWidth
        lp.height = oldHeight
        web.layoutParams = lp
        done(picture ?: screen)
        // The page puts its scroll positions back once the view is its own size again.
        web.postDelayed({
            web.evaluateJavascript("window.__wtShellCapture && __wtShellCapture('end')", null)
            web.postDelayed({ cover?.let { (it.parent as? ViewGroup)?.removeView(it) } }, 150)
        }, LAYOUT_DELAY_MS)
    }

    private fun ask(step: String, answer: (Size?) -> Unit) {
        web.evaluateJavascript("window.__wtShellCapture ? __wtShellCapture('$step') : ''") { result ->
            answer(
                try {
                    // The answer is the JSON text of a string holding the page's JSON.
                    val o = JSONObject(JSONArray("[$result]").getString(0))
                    Size(o.getDouble("w").toFloat(), o.getDouble("h").toFloat())
                } catch (_: Exception) {
                    null
                }
            )
        }
    }

    private class Size(val w: Float, val h: Float)

    companion object {
        private const val LAYOUT_DELAY_MS = 500L
        private const val DRAW_DELAY_MS = 300L
        private const val TIMEOUT_MS = 8000L
        private const val MAX_PIXELS = 12_000_000f
    }
}
