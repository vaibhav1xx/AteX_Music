# AteX Music - Agent & Engineering Guidelines

## Project Identity & Metadata
- **Display Name**: `AteX Music`
- **Dart Package**: `atex_music`
- **Application / Bundle ID**: `com.atex.atex_music`
- **API User-Agent**: `AteXMusic/1.0`

## Architectural Principles

### 1. 100% Offline-First & Zero-Server Architecture
- **No external paid backend servers** and **no hardcoded API keys**.
- All media assets—audio tracks, album cover art, user playlists, metadata, favorites, and `.lrc` synchronized lyrics—reside strictly locally on the user's device.
- Network access, if ever used in optional plugins, must be user-opt-in only for fetching public metadata without tracking or accounts.
- Local storage utilizes embedded local databases (e.g., SQLite via `sqflite` / `sqflite_common_ffi` or Hive) and file system caches.

### 2. Multi-Platform Safety & Plugin Abstraction
- Target Platforms: **Android**, **iOS**, **Windows**, **macOS**, **Android TV**, and **CarPlay / Android Auto**.
- **Rule**: Never import mobile-only or platform-specific plugins unconditionally on Windows or macOS.
- All platform-divergent capabilities (such as audio file discovery and scanning) must be abstracted behind clean platform interface classes:
  - Mobile (Android / iOS): `on_audio_query` or MediaStore APIs.
  - Desktop (Windows / macOS): `file_picker` + `audio_metadata_reader` directory scanning.
  - Audio playback: unified abstraction (e.g., `just_audio` / `media_kit` with native desktop backends).
- Android build uses Kotlin DSL (`android/app/build.gradle.kts`). Maintain Kotlin DSL conventions when adjusting Android Gradle configurations.

### 3. Visual Language & Theme
- **Background**: Deep OLED black (`#07090E`). Pure blacks (`#000000`) for high-contrast OLED power savings.
- **Surface & Cards**: Translucent frosted-glass cards (`rgba(255, 255, 255, 0.05)`) backed by `BackdropFilter` Gaussian blur with a subtle `1px` translucent border (`rgba(255, 255, 255, 0.1)`).
- **Accents**:
  - Electric Cyan: `#00E5FF` (primary glowing interactive elements, playback scrubbers, active states).
  - Deep Cobalt: `#2979FF` (secondary gradient anchors, headers, and badge backgrounds).
- **Typography & Readability**: High-contrast crisp white (`#FFFFFF`) titles and muted slate (`#8E9BAE`) metadata.

### 4. Responsive & Adaptive UI Architecture
- Layout adaptation implemented via `LayoutBuilder`:
  - **Compact (< 700px - Mobile / Portrait)**:
    - Frosted bottom navigation bar.
    - Floating frosted mini-player hovering above the bottom bar with gesture-to-expand.
  - **Expanded (>= 700px - Desktop / Tablet / Landscape)**:
    - Persistent frosted left navigation sidebar with logo monogram, main sections, and quick playlists.
    - Persistent full-width bottom playback dock with expanded scrubber, volume controls, and track details.
  - **Android TV / Leanback Mode**:
    - High-contrast neon focus rings (`#00E5FF`, 2px glow).
    - Unbroken D-pad / directional arrow-key `Focus` and `FocusTraversalGroup` navigation.
    - Touchscreen not required (`android.hardware.touchscreen` optional; `android.software.leanback` supported).

### 5. Verification & Code Quality Invariants
- Always run `flutter pub get` and `dart analyze` after editing Dart files.
- Zero analysis errors, zero warnings, and clean formatting must be maintained.
- Every commit or release artifact must build cleanly across supported targets in CI/CD.
