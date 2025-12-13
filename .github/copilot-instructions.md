# GeForce Infinity - Copilot Instructions

## Project Overview

GeForce Infinity is an Electron-based desktop application that enhances the GeForce NOW streaming experience. It provides features like 120 FPS support, 2K resolution, custom Discord Rich Presence, account system with cloud sync, and various UI/UX improvements. The app targets Linux, macOS, and Windows.

**Tech Stack:** TypeScript, React, Electron, Tailwind CSS, Firebase, Bun (build tool)
**Codebase Size:** ~2,200 lines of TypeScript/TSX, ~20MB excluding node_modules
**Project Type:** Desktop application (Electron)

## Build Requirements

**Required Tools:**
- **Bun**: v1.3.4+ (primary build tool and package manager)
- **Node.js**: v20+ (for Electron compatibility)
- **TypeScript**: v5.8.3
- **Electron**: v37.2.0

**Note:** Yarn is listed in documentation but Bun is used for all build commands in package.json.

## Critical Build Instructions

### Initial Setup

**ALWAYS** use `bun install --ignore-scripts` to install dependencies. The postinstall script (`electron-builder install-app-deps`) will fail in most environments due to network connectivity issues with node-gyp rebuilding native modules. This failure is expected and does not affect development builds.

```bash
bun install --ignore-scripts
```

### Build Process

The build system uses custom TypeScript scripts in `scripts/` directory:

1. **Development Build** (full build):
```bash
bun run build
```
This runs 4 sequential steps:
- `build-css.ts`: Compiles Tailwind CSS from `src/overlay/index.css` to `dist/assets/tailwind.bundle.css`
- `build-overlay.ts`: Bundles React overlay using esbuild (entry: `src/overlay/index.tsx`)
- `build-electron.ts`: Compiles Electron TypeScript using `tsc -p tsconfig.electron.json`
- `cpx`: Copies all assets from `src/assets/**/*` to `dist/assets/`

**Expected Output:** `dist/` directory with `assets/`, `electron/`, `overlay/`, and `shared/` subdirectories.

**Expected Warnings:** "Browserslist: caniuse-lite is outdated" - this is harmless and can be ignored.

2. **Running the Application:**
```bash
bun run start
```
This runs `bun run build && electron dist/electron/main.js`. Requires X11/display server for GUI.

3. **Development Watch Mode:**
```bash
bun run dev
```
Runs concurrently:
- `bun:dev:overlay`: Vite dev server for overlay (not explicitly defined, uses bun dev mode)
- `bun:dev:electron`: TypeScript watch mode for Electron main process

### Linting

**IMPORTANT:** ESLint is configured but currently broken. The repository has `.eslintrc.cjs` but uses ESLint v9.30+ which requires `eslint.config.js` format.

```bash
bun run lint
```

**Expected Failure:** ESLint will fail with "couldn't find an eslint.config.js file" error. This is a known configuration issue. Do NOT attempt to fix this unless specifically addressing linting configuration.

**Code Style:** 
- Prettier with tab width 4 (enforced in CONTRIBUTING.md)
- Format before committing
- Settings: `"prettier.tabWidth": 4`

### Package Building

```bash
bun run dist
```
Creates distributable packages for Linux and Windows (AppImage, deb, rpm, zip, exe) in `builds/` directory. Requires system dependencies on Linux:
```bash
sudo apt install -y libarchive-tools libgtk-3-dev libnss3 libxss1 libasound2-plugins xvfb fakeroot dpkg rpm wine32 wine64
```

## Project Structure

### Root Files
- `package.json`: Main project configuration, defines all build scripts
- `tsconfig.electron.json`: TypeScript config for Electron main/preload processes
- `tailwind.config.js`: Tailwind CSS configuration (scans `src/overlay/**/*.{ts,tsx,js,jsx}`)
- `postcss.config.js`: PostCSS with Tailwind and Autoprefixer
- `.eslintrc.cjs`: ESLint config (incompatible with ESLint v9, needs migration)
- `net.astralvixen.geforceinfinity.yml`: Flatpak manifest for Linux packaging
- `com.github.astralvixen.geforce-infinity.desktop`: Desktop entry file

### Source Structure (`src/`)

**`src/electron/`** - Electron main process and backend
- `main.ts`: Application entry point, window management, Discord RPC integration
- `preload.ts`: Secure IPC bridge between main and renderer processes
- `ipc/`: IPC handlers for sidebar, updater, user settings
- `managers/`: Window manager, config manager, Discord manager, tray manager
- `types/`: TypeScript type definitions

**`src/overlay/`** - React-based UI overlay (injected into GeForce NOW)
- `index.tsx`: React app entry point, keyboard shortcut handler (Ctrl+I)
- `components/`: React components (sidebar, auth, settings, etc.)
- `contexts/`: React contexts (UserContext for Firebase auth)
- `hooks/`: Custom React hooks (useOutsideClick)
- `global.d.ts`: Global type definitions for window.electronAPI

**`src/shared/`** - Shared types between main and renderer
- `types.ts`: Config interface and defaults

**`src/utils/`** - Utility functions
- `cloudSync.ts`: Firebase Firestore sync for user settings

**`src/lib/`** - Third-party library configurations
- `firebase.ts`: Firebase initialization

**`src/assets/`** - Static resources (images, icons, CSS)

### Build Artifacts
- `dist/`: Compiled output (gitignored)
- `builds/`: Electron-builder output for distributable packages (gitignored)
- `node_modules/`: Dependencies (gitignored)

## GitHub Workflows

### `.github/workflows/release.yml`
Triggers on: Push to tags matching `v*` or manual dispatch

Build steps:
1. Checkout repository
2. Setup Bun and Node.js v22
3. Install system dependencies (Ubuntu 24.04)
4. Install Wine for Windows cross-compilation
5. `bun install` (CI environment has better network/proxy setup, may work without `--ignore-scripts`)
6. `bun run build`
7. `bun run dist`
8. Upload artifacts to GitHub releases (draft release)

**Note:** CI uses `bun install` without `--ignore-scripts` flag. If CI fails with electron-builder postinstall errors, update workflow to use `bun install --ignore-scripts`.

**Validation:** To test locally before pushing, run `bun install --ignore-scripts && bun run build && bun run dist` (requires Linux environment with system dependencies).

### `.github/workflows/bump-version.yml`
Manual version bump workflow using standard-version. Skips tag and changelog generation.

### `.github/workflows/copilot-setup.yml`
Environment setup workflow for GitHub Copilot agents. Triggers on pull requests and manual dispatch.

Setup steps:
1. Checkout repository
2. Setup Bun v1.3.4
3. Setup Node.js v20
4. Install dependencies with `bun install --ignore-scripts`
5. Build application with `bun run build`
6. Verify dist directory structure (assets/, electron/, overlay/, shared/)

This workflow validates that the build environment is correctly configured according to the instructions in this file.

## Common Issues & Workarounds

1. **`bun install` fails with electron-builder postinstall error**
   - **Solution:** Use `bun install --ignore-scripts`
   - **Reason:** node-gyp rebuild of register-scheme native module fails due to network/proxy issues
   - **Impact:** No impact on development, only affects Electron native module registration

2. **ESLint fails to run**
   - **Current State:** Configuration is outdated for ESLint v9
   - **Workaround:** Skip linting or manually run Prettier for formatting
   - **Do NOT fix unless explicitly asked**

3. **"Browserslist: caniuse-lite is outdated" warning**
   - **Impact:** Harmless warning during Tailwind build
   - **Can be ignored:** This does not affect build output

4. **Electron app won't start (display error)**
   - **Reason:** Electron requires X11/Wayland display server
   - **For CI:** Use Xvfb (virtual framebuffer): `xvfb-run electron dist/electron/main.js`

## Testing

**No test infrastructure exists.** `bun run test` will fail with "Error: no test specified".

**Manual Testing:**
1. Build: `bun run build`
2. Check `dist/` directory structure exists
3. For UI changes: Run `bun run start` (requires display server)
4. Test keyboard shortcut: Press Ctrl+I to toggle sidebar

## Key Configuration Files

- **Electron**: `src/electron/main.ts` (app entry), `src/electron/preload.ts` (IPC bridge)
- **React**: `src/overlay/index.tsx` (overlay entry)
- **Build**: `scripts/build-*.ts` (custom build scripts)
- **TypeScript**: `tsconfig.electron.json` (Electron), inline config in `build-overlay.ts` (React/esbuild)
- **Styling**: `tailwind.config.js`, `src/overlay/index.css`
- **Package**: `package.json` (all scripts and dependencies)

## Code Quality Guidelines (from CONTRIBUTING.md)

1. Write clean, modular, and dynamic code
2. Avoid hardcoding whenever possible
3. Use comments for non-trivial logic
4. Format code with Prettier (tab width 4) before committing
5. Break large PRs into smaller changes
6. PRs require approval from @AstralVixen AND @t0msk

## Known TODOs in Codebase

- `src/electron/main.ts:42`: Future theme system using CSS files instead of runtime DOM manipulation
- `src/utils/cloudSync.ts:63`: Theme system implementation pending

## Validation Steps

Before submitting changes:
1. Run `bun install --ignore-scripts` (if dependencies changed)
2. Run `bun run build` - must succeed without errors
3. Verify `dist/` directory contains expected files
4. Format code with Prettier (tab width 4)
5. For significant changes: Test with `bun run start` or in CI workflow
6. Check that no build artifacts are committed (`.gitignore` excludes `dist/`, `builds/`, `node_modules/`)

## Important Notes

- **ALWAYS run `bun install --ignore-scripts`** when installing dependencies
- **ALWAYS run `bun run build`** before testing or running the app
- The app is designed to inject an overlay into GeForce NOW web application
- Firebase is used for user authentication and cloud settings sync
- Discord RPC integration shows currently playing game
- Main keyboard shortcut: Ctrl+I (toggles sidebar)
- Build times: ~10-30 seconds for full build, <5 seconds for individual steps

## Trust These Instructions

These instructions have been thoroughly tested and validated. Only search for additional information if these instructions are incomplete or found to be incorrect. When in doubt, refer to:
1. This file first
2. `package.json` scripts
3. `CONTRIBUTING.md` for code style
4. GitHub workflows for CI/CD process
