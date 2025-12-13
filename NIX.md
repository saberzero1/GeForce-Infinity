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

### NixOS Module Options

- `programs.geforce-infinity.enable`: Enable GeForce Infinity (default: `false`)
- `programs.geforce-infinity.package`: The GeForce Infinity package to use (default: latest from flake)

### Home Manager Module Options

- `programs.geforce-infinity.enable`: Enable GeForce Infinity for the user (default: `false`)
- `programs.geforce-infinity.package`: The GeForce Infinity package to use (default: latest from flake)

## System Requirements

GeForce Infinity requires:

- **Graphics**: OpenGL/Vulkan support (enabled via `hardware.opengl.enable` in NixOS)
- **Audio**: PulseAudio or PipeWire
- **Display**: X11 or Wayland
- **Network**: Internet connection for GeForce NOW streaming

The NixOS module automatically enables required hardware features.

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

## Additional Resources

- [Official Website](https://geforce-infinity.xyz/)
- [GitHub Repository](https://github.com/saberzero1/GeForce-Infinity)
- [Discord Community](https://discord.gg/p5vRgQwZ9K)
- [Nix Flakes Documentation](https://nixos.wiki/wiki/Flakes)
- [NixOS Module System](https://nixos.org/manual/nixos/stable/index.html#sec-writing-modules)
- [Home Manager Documentation](https://nix-community.github.io/home-manager/)
