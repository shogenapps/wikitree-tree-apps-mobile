package org.wikitree.treeapps

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintDocumentInfo
import android.print.pdf.PrintedPdfDocument
import java.io.FileOutputStream

/**
 * One printed page of a chart: its title at the top, the picture scaled to fit the paper the
 * person picked, and the link to the same chart at the bottom. Used for printing and for the
 * print dialog's "Save as PDF".
 */
class ChartPrintAdapter(
    private val context: Context,
    private val bitmap: Bitmap,
    private val title: String,
    private val link: String,
) : PrintDocumentAdapter() {

    private var attributes: PrintAttributes? = null

    override fun onLayout(
        oldAttributes: PrintAttributes?,
        newAttributes: PrintAttributes,
        cancellationSignal: CancellationSignal,
        callback: LayoutResultCallback,
        extras: Bundle?,
    ) {
        if (cancellationSignal.isCanceled) {
            callback.onLayoutCancelled()
            return
        }
        attributes = newAttributes
        val name = title.replace(Regex("[:/\\\\]"), "").trim() + ".pdf"
        val info = PrintDocumentInfo.Builder(name)
            .setContentType(PrintDocumentInfo.CONTENT_TYPE_PHOTO)
            .setPageCount(1)
            .build()
        callback.onLayoutFinished(info, newAttributes != oldAttributes)
    }

    override fun onWrite(
        pages: Array<out PageRange>,
        destination: ParcelFileDescriptor,
        cancellationSignal: CancellationSignal,
        callback: WriteResultCallback,
    ) {
        val pdf = PrintedPdfDocument(context, attributes ?: return callback.onWriteFailed(null))
        try {
            val page = pdf.startPage(0)
            val canvas = page.canvas
            // PDF units are points (1/72 inch).
            val width = canvas.width.toFloat()
            val height = canvas.height.toFloat()
            val margin = 28f
            val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.BLACK
                textSize = 14f
                typeface = Typeface.DEFAULT_BOLD
            }
            val linkPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.DKGRAY
                textSize = 8f
            }
            // The chart as large as fits the paper, keeping its shape, with the title just above
            // it and the link just below; the whole block is centred on the page.
            val titleGap = titlePaint.textSize + 12f
            val linkGap = linkPaint.textSize + 12f
            val boxW = width - margin * 2
            val boxH = height - margin * 2 - titleGap - linkGap
            val scale = minOf(boxW / bitmap.width, boxH / bitmap.height)
            val w = bitmap.width * scale
            val h = bitmap.height * scale
            val left = margin + (boxW - w) / 2
            val top = margin + titleGap + (boxH - h) / 2
            canvas.drawText(title, left, top - 12f, titlePaint)
            canvas.drawText(link, left, top + h + linkGap - 4f, linkPaint)
            canvas.drawBitmap(
                bitmap, null, RectF(left, top, left + w, top + h),
                Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG),
            )
            pdf.finishPage(page)
            if (cancellationSignal.isCanceled) {
                callback.onWriteCancelled()
                return
            }
            FileOutputStream(destination.fileDescriptor).use { pdf.writeTo(it) }
            callback.onWriteFinished(arrayOf(PageRange.ALL_PAGES))
        } catch (e: Exception) {
            callback.onWriteFailed(e.message)
        } finally {
            pdf.close()
        }
    }
}
