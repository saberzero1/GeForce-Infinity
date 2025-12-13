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
          # Enable GeForce Infinity
          programs.geforce-infinity.enable = true;
          
          # Optional: Use a specific version/package
          # programs.geforce-infinity.package = geforce-infinity.packages.x86_64-linux.default;
          
          # Required system configuration for GeForce Infinity
          # (These are automatically enabled by the module, but shown here for reference)
          # hardware.opengl.enable = true;
          # hardware.pulseaudio.enable = true; # or services.pipewire
          
          # Example: If you prefer PipeWire over PulseAudio
          services.pipewire = {
            enable = true;
            alsa.enable = true;
            pulse.enable = true;
          };
          
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
    #       programs.geforce-infinity.enable = true;
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
