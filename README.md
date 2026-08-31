<div align="center">

# BatchBreak

**The batch image converter for macOS — built with SwiftUI.**

Convert hundreds of images at once to JPEG, PNG, HEIC, WEBP, TIFF, or PDF. Just drop your files in and hit Convert.

[![Platform](https://img.shields.io/badge/Platform-macOS-black?logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

</div>

---

## Features

- 🖼️ **Batch conversion** — import individual files, mixed selections, or entire folders at once
- 🔄 **6 output formats** — JPEG, PNG, HEIC, WEBP, TIFF, and PDF
- 📄 **PDF support** — convert PDF pages to images, or images into a PDF; multi-page PDFs are split per page
- 🎚️ **Quality control** — adjustable compression slider with a live estimated output size
- 🗂️ **Grid & List views** — toggle between a photo grid or a compact list at any time
- 📊 **Conversion summary** — floating toast shows how many files were converted and how much space was saved
- ✨ **Liquid Glass UI** — native macOS look using `glassEffect` materials and capsule buttons
- 🔒 **Sandbox-safe** — uses security-scoped bookmarks to access files and output folders correctly
- 🚀 **Async conversion** — runs on a detached task with per-file progress updates so the UI stays responsive

---

## How It Works

1. **Drop files** onto the window, or click **Add Files…** to open a file picker.  
   Supported inputs: `JPG`, `PNG`, `HEIC`, `HEIF`, `WEBP`, `TIFF`, `BMP`, `GIF`, `PDF`, `AI`, `EPS`, `SVG`, `PSD`, `JP2`, `JPE`, `JPS`, `ICO`, `PICT`, `PPM`, `PNM`, `PAM`, `SGI`, `RAS`, `WBMP`, `MNG`, RAW camera files (`DNG`, `CR2`, `CR3`, `RAF`, `ARW`, `NEF`, `NRW`, `ORF`, `RW2`), and entire folders.

2. **Choose a format** from the menu in the bottom bar (`JPEG`, `PNG`, `HEIC`, `WEBP`, `TIFF`, `PDF`).

3. **Adjust quality** with the slider (affects JPEG and HEIC compression; lossless formats ignore it).  
   The estimated total output size updates in real time.

4. Click **Convert** and pick an output folder. BatchBreak converts all files concurrently and shows a progress toast.

5. Once done, a summary toast shows the number of files converted and space saved. Hit **Show in Finder** to open the output folder.

---

## Project Structure

```
BatchBreak/
├── BatchBreakApp.swift     # App entry point, window configuration
├── ContentView.swift       # Main UI: empty state, grid/list, control bar, conversion logic
├── PhotoItem.swift         # File model, output format enum, thumbnail loading, size estimation
├── PhotoCardView.swift     # Grid card component
└── QualitySlider.swift     # Custom quality slider component
```

---

## Supported Formats

| Format | Input | Output | Notes |
|--------|:-----:|:------:|-------|
| JPEG / JPE / JPS | ✅ | ✅ | Quality slider applies |
| PNG    | ✅ | ✅ | Lossless |
| HEIC / HEIF | ✅ | ✅ | Quality slider applies |
| WEBP   | ✅ | ✅ | |
| TIFF   | ✅ | ✅ | Lossless |
| PDF    | ✅ | ✅ | Multi-page split on export to images |
| AI     | ✅ | — | Adobe Illustrator (Multi-page artboard split on export) |
| EPS    | ✅ | — | Vector & raster PostScript (`.eps`, `.epsf`, `.ps`) |
| SVG    | ✅ | — | Scalable Vector Graphics |
| JPEG 2000 (JP2) | ✅ | — | |
| ICO    | ✅ | — | Windows icon format |
| BMP / WBMP | ✅ | — | |
| GIF    | ✅ | — | |
| MNG    | ✅ | — | Animated PNG predecessor |
| PICT   | ✅ | — | Classic Mac image format |
| PPM / PNM / PAM | ✅ | — | Portable bitmap formats |
| SGI    | ✅ | — | Silicon Graphics image format |
| RAS    | ✅ | — | Sun Raster format |
| PSD    | ✅ | — | Adobe Photoshop |
| **RAW Camera Formats** | | | |
| DNG    | ✅ | — | Adobe Digital Negative |
| CR2 / CR3 | ✅ | — | Canon RAW |
| RAF    | ✅ | — | Fujifilm RAW |
| ARW / SRF | ✅ | — | Sony RAW |
| NEF / NRW | ✅ | — | Nikon RAW |
| ORF    | ✅ | — | Olympus RAW |
| RW2    | ✅ | — | Panasonic RAW |

---

## License & Usage

The App: You are completely free to download and use this macOS app for any personal or commercial purpose.

The Code: This is a source-available project, not open-source. The source code is provided for portfolio viewing only. You may not modify, distribute, or use this code in your own projects without my explicit permission. You also may not re-upload or distribute the app under your own name.

If you would like to use snippets of this code or contribute, please contact me at k.madusanka1@gmail.com.
See [LICENSE](LICENSE) for details.
