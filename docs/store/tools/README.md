# Screenshot tools

- `frame.py raw.png out.png WIDTH HEIGHT "Caption" "Subcaption"` puts a raw device capture on the WikiTree
  green background with a caption, using headless Google Chrome and ImageMagick. iPhone: 1320 2868.
  Android: 1080 1920. Landscape captures were rotated 90° first so they fill a portrait frame.
- `feature.html` is the Play feature graphic; render at 1024 × 500 (needs `../../app-icon/wikitree-logo.svg`
  copied beside it as `wikitree-logo.svg`).
- iPhone captures: the "◂ Tree Apps" return-to-app label in the status bar (left by the test launch) was
  painted over in the header green. Status bar time was set to 10:24 with `simctl status_bar`.
