# Nix Flake Installation Guide

GeForce Infinity provides a Nix Flake for easy installation and configuration on NixOS and other systems using Nix with flakes enabled.

## Prerequisites

You need to have Nix installed with flakes enabled. If you haven't enabled flakes yet:

```bash
# Add to ~/.config/nix/nix.conf or /etc/nix/nix.conf
experimental-features = nix-command flakes
```

## Quick Installation

### Try without installing

You can run GeForce Infinity directly without installing:

```bash
nix run github:saberzero1/GeForce-Infinity
```

### Install to user profile

```bash
nix profile install github:saberzero1/GeForce-Infinity
```

### Install from local checkout

```bash
git clone https://github.com/saberzero1/GeForce-Infinity.git
cd GeForce-Infinity
nix profile install .
```

## NixOS Configuration

> **Note**: Complete example configurations are available in the [examples/](examples/) directory.

### System-wide Installation

Add to your NixOS configuration (`/etc/nixos/configuration.nix`):

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    geforce-infinity.url = "github:saberzero1/GeForce-Infinity";
  };

  outputs = { self, nixpkgs, geforce-infinity, ... }: {
    nixosConfigurations.yourHostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        geforce-infinity.nixosModules.default
        {
          programs.geforce-infinity.enable = true;
          
          # Optional: use a specific version
          # programs.geforce-infinity.package = geforce-infinity.packages.x86_64-linux.default;
        }
      ];
    };
  };
}
```

Then rebuild your system:

```bash
sudo nixos-rebuild switch --flake .#yourHostname
```

### Home Manager Installation

Add to your Home Manager configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    geforce-infinity.url = "github:saberzero1/GeForce-Infinity";
  };

  outputs = { self, nixpkgs, home-manager, geforce-infinity, ... }: {
    homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        geforce-infinity.homeManagerModules.default
        {
          programs.geforce-infinity.enable = true;
          
          # Optional: use a specific version
          # programs.geforce-infinity.package = geforce-infinity.packages.x86_64-linux.default;
        }
      ];
    };
  };
}
```

Then activate the configuration:

```bash
home-manager switch --flake .#yourusername
```

## Development Environment

The flake provides a development shell with all necessary dependencies:

```bash
# Enter the development shell
nix develop github:saberzero1/GeForce-Infinity

# Or from a local checkout
git clone https://github.com/saberzero1/GeForce-Infinity.git
cd GeForce-Infinity
nix develop
```

Inside the development shell:

```bash
# Install dependencies
bun install --ignore-scripts

# Build the application
bun run build

# Start the application
bun run start
```

## Building from Source

To build the package from source:

```bash
# Build from GitHub
nix build github:saberzero1/GeForce-Infinity

# Or from local checkout
git clone https://github.com/saberzero1/GeForce-Infinity.git
cd GeForce-Infinity
nix build
```

The built application will be available in `./result/bin/geforce-infinity`.

## Configuration Options

Both NixOS and Home Manager modules support declarative configuration of all GeForce Infinity settings.

### NixOS Module Options

#### Basic Options

- `programs.geforce-infinity.enable`: Enable GeForce Infinity (default: `false`)
- `programs.geforce-infinity.package`: The GeForce Infinity package to use (default: latest from flake)

#### Streaming Settings

- `programs.geforce-infinity.settings.resolution.width`: Monitor width for streaming (default: `1920`)
  - Supported values: `1366`, `1920`, `2560`
- `programs.geforce-infinity.settings.resolution.height`: Monitor height for streaming (default: `1080`)
  - Supported values: `768`, `1080`, `1440`
- `programs.geforce-infinity.settings.fps`: Target frame rate (default: `60`)
  - Supported values: `30`, `60`, `120` (120 FPS requires GeForce NOW Ultimate)

#### UI Settings

- `programs.geforce-infinity.settings.accentColor`: Custom accent color for GeForce NOW UI (default: `""`)
  - Hex color code (e.g., `"#0066cc"`) or empty string for default
- `programs.geforce-infinity.settings.userAgent`: Custom user agent string (default: `""`)
  - Empty string uses GeForce Infinity default

#### Feature Toggles

- `programs.geforce-infinity.settings.rpcEnabled`: Enable Discord Rich Presence (default: `true`)
- `programs.geforce-infinity.settings.notify`: Enable notification when gaming rig is ready (default: `true`)
- `programs.geforce-infinity.settings.autofocus`: Automatically focus window when ready (default: `false`)
- `programs.geforce-infinity.settings.automute`: Automatically mute when window not focused (default: `false`)
- `programs.geforce-infinity.settings.inactivityNotification`: Notify before kick due to inactivity (default: `false`)

#### Example Configuration

```nix
programs.geforce-infinity = {
  enable = true;
  settings = {
    resolution = {
      width = 2560;
      height = 1440;
    };
    fps = 120;
    accentColor = "#0066cc";
    rpcEnabled = true;
    notify = true;
    autofocus = true;
    automute = true;
    inactivityNotification = true;
  };
};
```

### Home Manager Module Options

Home Manager supports all the same settings as the NixOS module, plus additional options for non-NixOS systems.

#### Basic Options

- `programs.geforce-infinity.enable`: Enable GeForce Infinity for the user (default: `false`)
- `programs.geforce-infinity.package`: The GeForce Infinity package to use (default: latest from flake)

#### NixGL Integration (for non-NixOS systems)

- `programs.geforce-infinity.nixGL.enable`: Enable NixGL wrapper (default: `false`)
  - Required for OpenGL acceleration on non-NixOS systems
- `programs.geforce-infinity.nixGL.package`: The NixGL package to use (default: `null`)
  - Must be set if `nixGL.enable` is true
  - Options: `pkgs.nixgl.nixGLIntel`, `pkgs.nixgl.nixGLNvidia`, `pkgs.nixgl.auto.nixGLDefault`
  - Requires nixGL overlay to be configured (see example below)

#### All Settings Options

Home Manager supports all the same `settings.*` options as NixOS (resolution, fps, accentColor, etc.)

#### Example Home Manager Configuration

```nix
# First, add nixGL overlay to your configuration
nixpkgs.overlays = [
  (self: super: {
    nixgl = import (builtins.fetchTarball {
      url = "https://github.com/nix-community/nixGL/archive/main.tar.gz";
    }) { pkgs = super; };
  })
];

# Then configure GeForce Infinity
programs.geforce-infinity = {
  enable = true;
  
  # Enable NixGL for non-NixOS systems (e.g., Ubuntu with Nix)
  nixGL = {
    enable = true;
    package = pkgs.nixgl.nixGLNvidia;  # Use nixGLIntel for Intel GPUs
  };
  
  settings = {
    resolution = {
      width = 2560;
      height = 1440;
    };
    fps = 120;
    accentColor = "#e412e1";
    rpcEnabled = true;
    notify = true;
    autofocus = false;
    automute = true;
    inactivityNotification = true;
  };
};
```

### Configuration Priority

Settings are loaded with the following priority (highest to lowest):

1. User's local settings file (`~/.local/share/GeForceInfinity/settings.json`)
2. XDG config file (`~/.config/geforce-infinity/settings.json`) - Home Manager
3. System-wide config (`/etc/geforce-infinity/settings.json`) - NixOS
4. Application defaults

This allows users to override declarative settings through the UI if desired.

### Configuration Validation

The flake includes automatic validation for all configuration options to ensure valid values:

#### Validated Settings

**Resolution Validation:**
- Width must be one of: `1366`, `1920`, `2560`
- Height must be one of: `768`, `1080`, `1440`
- Valid combinations: `1366x768`, `1920x1080`, `2560x1440`

**FPS Validation:**
- Must be one of: `30`, `60`, `120`
- Note: 120 FPS requires GeForce NOW Ultimate subscription

**Accent Color Validation:**
- Must be empty string `""` or a valid hex color code (e.g., `#0066cc`)
- Format: `#` followed by exactly 6 hexadecimal characters

**NixGL Validation (Home Manager):**
- If `nixGL.enable` is `true`, `nixGL.package` must be set

#### Example Validation Errors

```nix
# This will fail at evaluation time:
programs.geforce-infinity.settings = {
  resolution = {
    width = 1234;   # ERROR: Invalid width
    height = 5678;  # ERROR: Invalid height
  };
  fps = 90;  # ERROR: Must be 30, 60, or 120
  accentColor = "blue";  # ERROR: Must be hex format
};
```

The module will provide clear error messages indicating which values are invalid and what the valid options are.

#### Testing Configuration

You can test your configuration before applying it:

```bash
# Test NixOS configuration
nix flake check

# Or run specific checks
nix build .#checks.x86_64-linux.nixos-module-defaults
nix build .#checks.x86_64-linux.config-validation
```

## System Requirements

GeForce Infinity requires:

- **Graphics**: OpenGL/Vulkan support (enabled via `hardware.opengl.enable` in NixOS)
- **Audio**: PulseAudio or PipeWire
- **Display**: X11 or Wayland
- **Network**: Internet connection for GeForce NOW streaming

The NixOS module automatically enables required hardware features.

### Display Server Compatibility

GeForce Infinity is built on Electron and supports both X11 and Wayland:

**X11**: Works out of the box on all systems.

**Wayland**: Fully supported with native Wayland backend. Electron will automatically use Wayland when:
- Running under a Wayland compositor (GNOME, KDE Plasma 6, Sway, etc.)
- `WAYLAND_DISPLAY` environment variable is set

To force Wayland mode (if auto-detection fails):
```bash
ELECTRON_OZONE_PLATFORM_HINT=wayland geforce-infinity
```

To force X11 mode on Wayland (via XWayland):
```bash
ELECTRON_OZONE_PLATFORM_HINT=x11 geforce-infinity
```

**Note**: On non-NixOS systems using Home Manager, NixGL integration may be required for proper OpenGL acceleration.

## Troubleshooting

### Audio not working

If audio doesn't work, ensure PulseAudio or PipeWire is enabled in your NixOS configuration:

```nix
# For PulseAudio
hardware.pulseaudio.enable = true;

# OR for PipeWire (preferred)
services.pipewire = {
  enable = true;
  alsa.enable = true;
  pulse.enable = true;
};
```

### Discord Rich Presence not working

Discord Rich Presence requires Discord to be running and accessible. Ensure:

1. Discord is installed and running
2. The Discord IPC socket is accessible at `$XDG_RUNTIME_DIR/discord-ipc-0`

### Display issues

If the application doesn't start or has display issues:

1. Ensure you're running on X11 or Wayland
2. Check that `hardware.opengl.enable = true` in your NixOS configuration
3. Try running with `ELECTRON_ENABLE_LOGGING=1` for debug output:

```bash
ELECTRON_ENABLE_LOGGING=1 geforce-infinity
```

### NixGL issues (non-NixOS systems)

If you're using Home Manager on a non-NixOS system and experience OpenGL/rendering issues:

1. **Enable NixGL** in your Home Manager configuration:
   ```nix
   programs.geforce-infinity.nixGL.enable = true;
   ```

2. **Choose the correct NixGL package** for your GPU:
   ```nix
   # For Intel GPUs
   programs.geforce-infinity.nixGL.package = pkgs.nixgl.nixGLIntel;
   
   # For NVIDIA GPUs
   programs.geforce-infinity.nixGL.package = pkgs.nixgl.nixGLNvidia;
   
   # Auto-detect (default)
   programs.geforce-infinity.nixGL.package = pkgs.nixgl.auto.nixGLDefault;
   ```

3. **Verify NixGL is working**:
   ```bash
   nixGL glxinfo | grep "OpenGL renderer"
   ```

4. **Add nixGL overlay** to your Home Manager configuration if not already present:
   ```nix
   nixpkgs.overlays = [
     (self: super: {
       nixgl = import (builtins.fetchTarball {
         url = "https://github.com/nix-community/nixGL/archive/main.tar.gz";
       }) { pkgs = super; };
     })
   ];
   ```

**Note**: NixGL is only necessary on non-NixOS systems where the graphics drivers are managed by the host system rather than Nix.

## Updating

### With `nix profile`

```bash
nix profile upgrade '.*geforce-infinity.*'
```

### With NixOS or Home Manager

Update your flake inputs:

```bash
nix flake update
```

Then rebuild:

```bash
# NixOS
sudo nixos-rebuild switch --flake .#yourHostname

# Home Manager
home-manager switch --flake .#yourusername
```

## Uninstalling

### From user profile

```bash
nix profile remove '.*geforce-infinity.*'
```

### From NixOS

Remove or set to `false` in your configuration:

```nix
programs.geforce-infinity.enable = false;
```

Then rebuild:

```bash
sudo nixos-rebuild switch --flake .#yourHostname
```

### From Home Manager

Remove or set to `false` in your configuration:

```nix
programs.geforce-infinity.enable = false;
```

Then rebuild:

```bash
home-manager switch --flake .#yourusername
```

## Development

### Updating npm Dependencies Hash

When `package-lock.json` is updated, the npm dependencies hash in `flake.nix` needs to be regenerated:

1. Set the hash to an invalid value in `flake.nix`:
   ```nix
   npmDeps = pkgs.fetchNpmDeps {
     src = ./.;
     hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
   };
   ```

2. Try to build the package:
   ```bash
   nix build .#geforce-infinity
   ```

3. Nix will fail and show the correct hash in the error message:
   ```
   error: hash mismatch in fixed-output derivation '/nix/store/...':
     specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
     got:       sha256-CORRECT_HASH_HERE
   ```

4. Update `flake.nix` with the correct hash:
   ```nix
   npmDeps = pkgs.fetchNpmDeps {
     src = ./.;
     hash = "sha256-CORRECT_HASH_HERE";
   };
   ```

5. Build again to verify:
   ```bash
   nix build .#geforce-infinity
   ```

### Local Development

To enter a development shell with all build dependencies:

```bash
nix develop
```

This provides:
- Bun for running build scripts
- Node.js 22
- All development tools
- Pre-configured environment

Inside the development shell, you can run normal development commands:

```bash
bun install --ignore-scripts  # Install dependencies
bun run build                 # Build the application
bun run start                 # Start the application
```

## Additional Resources

- [Official Website](https://geforce-infinity.xyz/)
- [GitHub Repository](https://github.com/saberzero1/GeForce-Infinity)
- [Discord Community](https://discord.gg/p5vRgQwZ9K)
- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)
- [NixOS Module System](https://nixos.org/manual/nixos/stable/index.html#sec-writing-modules)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
