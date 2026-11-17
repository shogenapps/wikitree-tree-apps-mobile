# Translations

The app translates only its own words: the bar, menus, the People and start screens, the login
form, read-aloud messages, anniversaries, the widget and notifications, and the few notes the shell
puts on the Tree Apps page. The Tree Apps themselves, profiles and biographies come from
wikitree.com and appear as the site shows them.

The app follows the phone's language. On Android 13 and later people can also pick the app's
language on its own (Settings, Apps, Tree Apps, Language); the list there is built from the
`values-xx` folders, so a new language appears in it automatically.

## Languages

English is the source. These were added first, because WikiTree has active member communities
working in them (the Honor Code was translated into German, Dutch and French; there are Dutch and
French language portals; Sweden, Germany, the Netherlands, France, Italy and the Spanish-speaking
countries all have busy WikiTree projects):

| Code | Language | Status |
| --- | --- | --- |
| `de` | German | Machine translation, needs review |
| `nl` | Dutch | Machine translation, needs review |
| `fr` | French | Machine translation, needs review |
| `sv` | Swedish | Machine translation, needs review |
| `es` | Spanish | Machine translation, needs review |
| `it` | Italian | Machine translation, needs review |

Likely next: Norwegian (`nb`), Finnish (`fi`), Polish (`pl`), Danish (`da`), Portuguese (`pt`).

**Every translation so far was written by machine and should be checked by a native-speaking
WikiTree member before a store release.** When a language has been checked, change its status in
the table above, and on iPhone mark its strings as reviewed (see below).

Words kept in English on purpose: "Tree Apps" and "Tree App" (WikiTree's names for them, as on the
site), "WikiTree", "WikiTree ID" (in each language's word order) and "Trusted List".

## Where the words are

| Platform | English | Translations |
| --- | --- | --- |
| Android | `android/app/src/main/res/values/strings.xml` | `android/app/src/main/res/values-xx/strings.xml` |
| iPhone and iPad | the English text in the Swift code | `ios/Shared/Localizable.xcstrings` (a String Catalog, used by the app and the widget) |
| Notes on the Tree Apps page (`shared/shell.js`) | English in `shell.js` | the `shell_*` strings on Android, and the same English keys on iPhone |

The two platforms word a few things differently (Android says "Tap ☆", iPhone "Tap the star"), so
each has its own list, but most strings are the same sentence.

## Checking or correcting a translation

- **Android:** edit the line in `values-xx/strings.xml`. Keep placeholders such as `%1$s` and
  `%1$d` exactly as they are (they can move within the sentence). Write an apostrophe as `\'`.
- **iPhone:** open `ios/TreeApps.xcodeproj` in Xcode, select `Localizable.xcstrings`, pick the
  language on the left, correct the text, then right-click it and choose **Mark as Reviewed**.
  Untouched machine translations show as "Needs Review". Placeholders are `%@` (text) and `%lld`
  (a number); with two or more they are numbered, such as `%1$@`.

A reviewer who doesn't use Xcode or Android Studio can simply send corrections as a list of
"English: corrected translation" lines, and a developer puts them in.

## Adding a language

1. **Android:** copy `values/strings.xml` to a new `values-xx/strings.xml` (`xx` is the
   two-letter language code, for example `values-nb`), delete the lines marked
   `translatable="false"`, and translate the rest. Plurals (`<plurals>`) may need the extra forms
   the language uses (`few`, `many`).
2. **iPhone:** in Xcode select `Localizable.xcstrings`, press **+** at the bottom of the language
   list and choose the language. Xcode adds it to the project too. Translate each string.
3. Add the language to the table above.

## Adding a new string

- **Android:** add it to `values/strings.xml` and use it with `getString(R.string.name)`. Never
  put English text straight into Kotlin code. Then add the translation to each `values-xx` file
  (Android Studio's Translations Editor shows what is missing). A string that is missing falls
  back to English.
- **iPhone:** SwiftUI text such as `Text("Done")` or `Button("Reload")` is picked up by itself. Text
  that is first held in a `String` (a variable, a `? :` choice, a message) must be written as
  `String(localized: "…")`. On the next build Xcode adds new strings to `Localizable.xcstrings`,
  where they show as untranslated.
- **Page notes in `shell.js`:** use `text("shell_name", "English")` in `shell.js`, add
  `shell_name` to Android's `strings.xml` and to `MainActivity.shellTextJs()`, and to
  `ShellModel.shellText()` on iPhone.
