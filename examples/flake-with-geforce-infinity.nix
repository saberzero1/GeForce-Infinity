# Example NixOS configuration with GeForce Infinity
#
# This is a minimal example showing how to integrate GeForce Infinity
# into your NixOS configuration using flakes.
#
# Usage:
#   1. Copy this to your NixOS flake.nix and adapt it to your needs
#   2. Run: sudo nixos-rebuild switch --flake .#yourHostname
#
{
  description = "Example NixOS configuration with GeForce Infinity";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    geforce-infinity.url = "github:saberzero1/GeForce-Infinity";
    
    # Optional: Home Manager
    # home-manager = {
    #   url = "github:nix-community/home-manager";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };
  };

  outputs = { self, nixpkgs, geforce-infinity, ... }@inputs: {
    nixosConfigurations.yourHostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the GeForce Infinity NixOS module
        geforce-infinity.nixosModules.default
        
        # Your system configuration
        ({ config, pkgs, ... }: {
          # Enable GeForce Infinity with custom settings
          programs.geforce-infinity = {
            enable = true;
            
            # Optional: Use a specific version/package
            # package = geforce-infinity.packages.x86_64-linux.default;
            
            # Configure default settings (optional)
            settings = {
              # Streaming quality
              resolution = {
                width = 2560;   # 1366, 1920, or 2560
                height = 1440;  # 768, 1080, or 1440
              };
              fps = 120;  # 30, 60, or 120 (requires GFN Ultimate)
              
              # UI customization
              accentColor = "#0066cc";  # Hex color or "" for default
              userAgent = "";  # Custom user agent or "" for default
              
              # Feature toggles
              rpcEnabled = true;  # Discord Rich Presence
              notify = true;  # Gaming rig ready notification
              autofocus = true;  # Auto-focus window when ready
              automute = true;  # Auto-mute when unfocused
              inactivityNotification = true;  # Inactivity warning
            };
          };
          
          # Required system configuration for GeForce Infinity
          # (hardware.graphics/hardware.opengl is automatically enabled by the module)
          
          # Audio: Choose PulseAudio or PipeWire
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };
          
          # OR use PulseAudio instead:
          # hardware.pulseaudio.enable = true;
          
          # Other system configuration...
          # boot.loader.systemd-boot.enable = true;
          # networking.hostName = "yourHostname";
          # etc...
        })
      ];
    };
    
    # Example Home Manager configuration
    # homeConfigurations.yourusername = home-manager.lib.homeManagerConfiguration {
    #   pkgs = nixpkgs.legacyPackages.x86_64-linux;
    #   modules = [
    #     geforce-infinity.homeManagerModules.default
    #     ({ config, pkgs, ... }: {
    #       # For non-NixOS systems, add nixGL overlay first
    #       # IMPORTANT: Pin to a specific commit for production use, not 'main'
    #       # nixpkgs.overlays = [
    #       #   (self: super: {
    #       #     nixgl = import (builtins.fetchTarball {
    #       #       url = "https://github.com/nix-community/nixGL/archive/7d6bc1b21316bab6cf4a6520c2639a11c8eb2b8a.tar.gz";
    #       #       sha256 = "0000000000000000000000000000000000000000000000000000";
    #       #     }) { pkgs = super; };
    #       #   })
    #       # ];
    #       
    #       programs.geforce-infinity = {
    #         enable = true;
    #         
    #         # Enable NixGL for non-NixOS systems (e.g., Ubuntu with Nix)
    #         nixGL = {
    #           enable = false;  # Set to true on non-NixOS systems
    #           package = null;  # Set to pkgs.nixgl.nixGLNvidia or pkgs.nixgl.nixGLIntel
    #         };
    #         
    #         # Same settings options as NixOS module
    #         settings = {
    #           resolution = { width = 2560; height = 1440; };
    #           fps = 120;
    #           accentColor = "#e412e1";
    #           rpcEnabled = true;
    #           notify = true;
    #           autofocus = true;
    #           automute = true;
    #           inactivityNotification = true;
    #         };
    #       };
    #       
    #       # Other user configuration...
    #       home.username = "yourusername";
    #       home.homeDirectory = "/home/yourusername";
    #       home.stateVersion = "24.05";
    #     })
    #   ];
    # };
  };
}
