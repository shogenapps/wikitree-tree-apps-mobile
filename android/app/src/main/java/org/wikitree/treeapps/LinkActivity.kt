package org.wikitree.treeapps

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Receives links from other apps and the home-screen shortcuts, and passes them straight on to
 * [MainActivity] with a stamp that is different every time.
 *
 * Android hands an activity its opening intent again whenever it recreates it (after closing the
 * app in the background, or after an update). Without the stamp MainActivity could not tell such
 * a repeat from the same link or shortcut being tapped a second time.
 */
class LinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startActivity(
            Intent(intent.action, intent.data, this, MainActivity::class.java)
                .putExtra(EXTRA_STAMP, System.currentTimeMillis())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        finish()
    }

    companion object {
        const val EXTRA_STAMP = "org.wikitree.treeapps.STAMP"
        const val ACTION_PEOPLE = "org.wikitree.treeapps.PEOPLE"
    }
}
