# Word Search

A native SwiftUI app for iPad, iPhone and macOS that builds word search puzzles from your own word banks. Puzzles can be played on screen or exported as printable PDFs.

## Features

- **Word banks** – create, edit and bulk-import named word lists (subjects), with validation for length and invalid characters
- **Puzzle generation** – fixed grid sizes with automatic word placement
- **Interactive play** – drag to select words directly on the grid
- **PDF export and sharing** – print-ready puzzles via the system share sheet
- **Light, dark and tinted app icons**, plus a macOS icon set

## Requirements

- Xcode 26 or later
- iOS 26 / macOS 26 deployment target

## Building

Open `WordSearchApp.xcodeproj` in Xcode, choose the `WordSearchApp` scheme and a destination (iPad, iPhone or My Mac), then Run.

From the command line:

```bash
xcodebuild -project WordSearchApp.xcodeproj -scheme WordSearchApp -destination 'platform=macOS' build
```

Run the tests with `test` in place of `build`.

## Project structure

```
assets/                          Source artwork (e.g. app icon master)
WordSearchApp.xcodeproj
WordSearchApp/                   App sources
  App/                           App entry point and theme
  Models/                        SwiftData models and word bank validation
  Engine/                        Puzzle generation and selection logic
  Export/                        PDF rendering and share sheet
  Views/                         Screens
    Components/                  Reusable management UI
  Assets.xcassets/
WordSearchAppTests/              Unit tests (Swift Testing)
WordSearchAppUITests/            UI tests
```

The Xcode project uses synchronized folders, so files added to these directories are picked up automatically.
