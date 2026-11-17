# Store listing kit

Everything needed to list **WikiTree Tree Apps** on Google Play and the Apple App Store, for when the
WikiTree developer accounts exist. The project is to move to WikiTree's own repositories, and WikiTree
submits it to the stores as owner and publisher (made by the WikiTree Apps project). Prepared November 2026 from main at db6739c.

| File | What it is |
| --- | --- |
| `google-play-listing.md` | Title, short and full description, category, App content answers, release notes |
| `app-store-listing.md` | Name, subtitle, promo text, keywords, description, age rating, App Review notes |
| `description.txt` | The full description as plain text (same for both stores) |
| `privacy-policy.md` | Draft privacy policy to host on a public WikiTree page |
| `data-safety-and-privacy-labels.md` | Play Data safety form and Apple App Privacy answers, and the facts behind them |
| `PrivacyInfo.xcprivacy` | Apple privacy manifest, ready to add to both iOS targets |
| `graphics/play-icon-512.png` | Play hi-res icon (512 × 512) |
| `graphics/play-feature-1024x500.png` | Play feature graphic (1024 × 500) |
| `screenshots/android/` | Play phone screenshots, 1080 × 1920 (**not taken yet**) |
| `screenshots/ios/` | App Store iPhone 6.9" screenshots, 1320 × 2868 |

## Decisions needed (Ian / WikiTree)

1. **Permission to publish under the WikiTree name and logo**, and who at WikiTree owns the developer
   accounts (Google Play organisation account needs a D-U-N-S number; so does an Apple organisation
   account).
2. **Final app id**: currently `org.wikitree.treeapps` (Android `applicationId`, iOS bundle id, widget
   `org.wikitree.treeapps.BirthdayWidget`, App Group `group.org.wikitree.treeapps`). Cannot change after
   the first upload.
3. **Contact email** (public on both stores), **support URL** (Apple requires one), **privacy policy URL**
   (both require one, as a web page).
4. **Copyright line** for Apple, e.g. "2026 WikiTree".
5. **Icon**: the stores use the current WikiTree emblem icon. Confirm WikiTree is happy with it.
6. **Reviewer login**: a dedicated WikiTree test account for Apple and Google reviewers (not Ian's).
7. **iPad**: the iOS project targets iPhone and iPad, which means Apple also needs 13" iPad screenshots and
   reviews it on iPad. Recommended: make it iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).
8. **Privacy facts only WikiTree knows**: whether its servers log searches and page views by member, and
   any analytics on wikitree.com (marked CONFIRM in the privacy files).
9. **Account deletion**: wikitree.com's login page (shown inside the app) links to registration, so both
   stores will expect a way to delete the account: a public web page for Play, and an in-app link to
   start deletion for Apple. Needs a WikiTree page and probably a small ⋮ menu item.
10. **Login needed for the Tree Apps**: in November 2026 wikitree.com shows its login page instead of the
   Tree Apps to logged-out visitors, so the listing says a free account is needed and reviewers need a
   test login.

## Code changes still needed before submitting (not made here)

- Release signing key for Android (kept out of the repo); `android/app/testing.keystore` is test-only.
- Add `PrivacyInfo.xcprivacy` to the TreeApps and BirthdayWidget targets.
- Add `ITSAppUsesNonExemptEncryption = NO` to the iOS Info.plist.
- Real version numbers (Android `versionName` is `0.1.<CI run>`, iOS `MARKETING_VERSION` 0.1).
- Check the Play target API level required at submission time (the app targets 35).
- Host `assetlinks.json` and `apple-app-site-association` on wikitree.com (see `docs/wikitree-link-setup.md`)
  so links open in the app; the description says links "can" open in the app, which stays true either way.

## Screenshot sizes used

- **Google Play phone**: 9:16 PNG, 1080 × 1920 (Play limits: 2 to 8 images, sides 320 to 3840 px, long
  side at most twice the short side; 4 or more at 1080 px+ make the app eligible for promotion). The
  emulator's 1080 × 2400 captures are too tall for that ratio, so each is placed on a 1080 × 1920 canvas
  with a caption.
- **App Store iPhone 6.9"**: 1320 × 2868 portrait (the one size Apple now requires; it scales it for the
  smaller iPhones). Taken from an iPhone 17 Pro Max Simulator.
- People shown are public profiles (Windsor-1, Thomas-30484 and similar). No logged-in member data is
  shown.
