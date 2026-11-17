# App icon

The app icon is the WikiTree emblem (`wikitree-logo.svg`: orange disc, white tree, green hill) on white.

- **Android** (`android/app/src/main/res`): an adaptive icon. `mipmap-anydpi-v26/ic_launcher.xml` puts
  `mipmap-*/ic_launcher_foreground.png` (108dp canvas at 108, 162, 216, 324 and 432px, transparent) over
  `@color/icon_background`. The emblem is drawn 57dp wide and centred, so its farthest points (the tips
  of the hill) are 32.5dp from the centre, inside the 66dp safe circle that every launcher mask keeps.
- **iPhone** (`ios/TreeApps/Assets.xcassets/AppIcon.appiconset`): one opaque 1024px PNG with square
  corners; iOS applies its own mask. The emblem is 82% of the canvas width and centred.

To change the background, edit `icon_background` in `values/colors.xml` and re-export the iPhone PNG on
the same colour. To change the artwork, re-export all six PNGs from the SVG at the sizes above.
