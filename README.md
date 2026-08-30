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

## Screenshots

> _Add screenshots here after your first build._

---

## Requirements

| | Minimum |
|---|---|
| **macOS** | 26.0+ (Tahoe) |
| **Xcode** | 16+ |
| **Swift** | 6 |

> **Note:** `glassEffect` and `.glassProminent` button styles require **macOS 26 (Tahoe)** or later.

---

## Getting Started

```bash
# Clone the repository
git clone https://github.com/your-username/BatchBreak.git
cd BatchBreak

# Open in Xcode
open BatchBreak.xcodeproj
```

Build and run the `BatchBreak` scheme on your Mac. No external dependencies or package manager setup needed.

---

## How It Works

1. **Drop files** onto the window, or click **Add Files…** to open a file picker.  
   Supported inputs: `JPG`, `PNG`, `HEIC`, `WEBP`, `TIFF`, `BMP`, `GIF`, `PDF`, `PSD`, and entire folders.

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
| JPEG   | ✅ | ✅ | Quality slider applies |
| PNG    | ✅ | ✅ | Lossless |
| HEIC   | ✅ | ✅ | Quality slider applies |
| WEBP   | ✅ | ✅ | |
| TIFF   | ✅ | ✅ | Lossless |
| PDF    | ✅ | ✅ | Multi-page split on export to images |
| PSD    | ✅ | — | Read-only; converts to any output format |
| BMP, GIF | ✅ | — | Accepted as input |

---

## Contributing

Pull requests are welcome! Please open an issue first if you'd like to discuss a significant change.

1. Fork the repo and create your branch from `main`.
2. Make your changes and verify the app builds cleanly.
3. Open a pull request with a clear description of what changed and why.

---

## License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<div align="center">
Made with ❤️ for macOS · Built with SwiftUI
</div>
