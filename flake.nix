{
  description = "GeForce Infinity - Enhance your GeForce NOW experience";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        geforce-infinity = pkgs.stdenv.mkDerivation rec {
          pname = "geforce-infinity";
          version = "1.1.3";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            bun
            nodejs_22
            copyfiles
            makeWrapper
          ];

          buildInputs = with pkgs; [
            electron
          ];

          configurePhase = ''
            runHook preConfigure
            
            # Set up bun cache directory
            export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
            mkdir -p "$BUN_INSTALL_CACHE_DIR"
            
            # Install dependencies
            # --ignore-scripts skips postinstall (electron-builder install-app-deps)
            # which is not needed since Nix handles native dependencies
            bun install --frozen-lockfile --ignore-scripts
            
            runHook postConfigure
          '';

          buildPhase = ''
            runHook preBuild
            
            # Build CSS
            bun run scripts/build-css.ts
            
            # Build overlay
            bun run scripts/build-overlay.ts
            
            # Build electron
            bun run scripts/build-electron.ts
            
            # Copy assets (cpx is in node_modules, bun x runs it)
            bun x cpx "src/assets/**/*" dist/assets
            
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            
            mkdir -p $out/lib/geforce-infinity
            mkdir -p $out/bin
            mkdir -p $out/share/applications
            mkdir -p $out/share/icons/hicolor/512x512/apps
            
            # Copy application files
            cp -r dist $out/lib/geforce-infinity/
            cp -r node_modules $out/lib/geforce-infinity/
            cp package.json $out/lib/geforce-infinity/
            
            # Install icon
            if [ -f dist/assets/resources/infinitylogo.png ]; then
              cp dist/assets/resources/infinitylogo.png \
                $out/share/icons/hicolor/512x512/apps/net.astralvixen.geforceinfinity.png
            fi
            
            # Create wrapper script with X11 and Wayland support
            makeWrapper ${pkgs.electron}/bin/electron $out/bin/geforce-infinity \
              --add-flags "$out/lib/geforce-infinity/dist/electron/main.js" \
              --set NODE_ENV production \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.libpulseaudio ]}" \
              --suffix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}"
            
            # Install desktop file
            substitute ${./com.github.astralvixen.geforce-infinity.desktop} \
              $out/share/applications/net.astralvixen.geforceinfinity.desktop \
              --replace '/opt/geforce-infinity/geforce-infinity' "$out/bin/geforce-infinity"
            
            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Enhance your GeForce NOW application experience";
            homepage = "https://geforce-infinity.xyz/";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
            mainProgram = "geforce-infinity";
          };
        };

      in
      {
        packages = {
          default = geforce-infinity;
          geforce-infinity = geforce-infinity;
        };

        apps = {
          default = {
            type = "app";
            program = "${geforce-infinity}/bin/geforce-infinity";
          };
          geforce-infinity = {
            type = "app";
            program = "${geforce-infinity}/bin/geforce-infinity";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bun
            nodejs_22
            electron
            git
          ];

          shellHook = ''
            echo "GeForce Infinity Development Environment"
            echo "Run 'bun install --ignore-scripts' to install dependencies"
            echo "Run 'bun run build' to build the application"
            echo "Run 'bun run start' to start the application"
          '';
        };
      }
    ) // {
      # NixOS module
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.geforce-infinity;
          
          settingsFormat = pkgs.formats.json {};
          
          configFile = settingsFormat.generate "geforce-infinity-settings.json" {
            userAgent = cfg.settings.userAgent;
            autofocus = cfg.settings.autofocus;
            automute = cfg.settings.automute;
            notify = cfg.settings.notify;
            rpcEnabled = cfg.settings.rpcEnabled;
            informed = cfg.settings.informed;
            accentColor = cfg.settings.accentColor;
            inactivityNotification = cfg.settings.inactivityNotification;
            monitorWidth = cfg.settings.resolution.width;
            monitorHeight = cfg.settings.resolution.height;
            framesPerSecond = cfg.settings.fps;
          };
        in
        {
          options.programs.geforce-infinity = {
            enable = mkEnableOption "GeForce Infinity";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = literalExpression "self.packages.\${pkgs.system}.default";
              description = "The GeForce Infinity package to use.";
            };

            settings = {
              resolution = {
                width = mkOption {
                  type = types.int;
                  default = 1920;
                  description = "Monitor width for streaming (1366, 1920, or 2560).";
                };
                
                height = mkOption {
                  type = types.int;
                  default = 1080;
                  description = "Monitor height for streaming (768, 1080, or 1440).";
                };
              };

              fps = mkOption {
                type = types.int;
                default = 60;
                description = "Target frame rate (30, 60, or 120). 120 FPS requires GeForce NOW Ultimate.";
              };

              userAgent = mkOption {
                type = types.str;
                default = "";
                description = "Custom user agent string. Empty string uses GeForce Infinity default.";
              };

              accentColor = mkOption {
                type = types.str;
                default = "";
                description = "Custom accent color for GeForce NOW UI (hex color code or empty for default).";
              };

              rpcEnabled = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Discord Rich Presence to show current game in Discord status.";
              };

              notify = mkOption {
                type = types.bool;
                default = true;
                description = "Enable notification when gaming rig is ready.";
              };

              autofocus = mkOption {
                type = types.bool;
                default = false;
                description = "Automatically focus window when gaming rig is ready or on inactivity warning.";
              };

              automute = mkOption {
                type = types.bool;
                default = false;
                description = "Automatically mute game when window is not focused.";
              };

              inactivityNotification = mkOption {
                type = types.bool;
                default = false;
                description = "Enable notification when about to be kicked due to inactivity.";
              };

              informed = mkOption {
                type = types.bool;
                default = false;
                description = "Internal flag for first-time setup information.";
              };
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
            
            # Create system-wide default configuration
            environment.etc."geforce-infinity/settings.json".source = configFile;

            # Enable required system services
            hardware.opengl.enable = true;
            hardware.pulseaudio.enable = mkDefault true;
          };
        };

      # Home Manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.geforce-infinity;
          
          settingsFormat = pkgs.formats.json {};
          
          configFile = settingsFormat.generate "geforce-infinity-settings.json" {
            userAgent = cfg.settings.userAgent;
            autofocus = cfg.settings.autofocus;
            automute = cfg.settings.automute;
            notify = cfg.settings.notify;
            rpcEnabled = cfg.settings.rpcEnabled;
            informed = cfg.settings.informed;
            accentColor = cfg.settings.accentColor;
            inactivityNotification = cfg.settings.inactivityNotification;
            monitorWidth = cfg.settings.resolution.width;
            monitorHeight = cfg.settings.resolution.height;
            framesPerSecond = cfg.settings.fps;
          };
          
          # Wrapper for NixGL support on non-NixOS systems
          wrappedPackage = if cfg.nixGL.enable && cfg.nixGL.package != null then
            pkgs.writeShellScriptBin "geforce-infinity" ''
              exec ${cfg.nixGL.package}/bin/nixGL ${cfg.package}/bin/geforce-infinity "$@"
            ''
          else if cfg.nixGL.enable then
            # Fallback if nixGL.enable is true but no package is provided
            pkgs.writeShellScriptBin "geforce-infinity" ''
              echo "Warning: nixGL.enable is true but nixGL.package is not set."
              echo "Please configure nixGL overlay or set nixGL.package explicitly."
              echo "Running without NixGL wrapper..."
              exec ${cfg.package}/bin/geforce-infinity "$@"
            ''
          else
            cfg.package;
        in
        {
          options.programs.geforce-infinity = {
            enable = mkEnableOption "GeForce Infinity";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.default;
              defaultText = literalExpression "self.packages.\${pkgs.system}.default";
              description = "The GeForce Infinity package to use.";
            };

            nixGL = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Enable NixGL wrapper for running on non-NixOS systems.
                  Required for OpenGL acceleration on systems without Nix-managed graphics drivers.
                  Note: Requires nixGL to be available in pkgs (via overlay or flake input).
                '';
              };

              package = mkOption {
                type = types.nullOr types.package;
                default = null;
                defaultText = literalExpression "null";
                description = ''
                  The NixGL package to use. Set to pkgs.nixgl.nixGLIntel, pkgs.nixgl.nixGLNvidia, 
                  or pkgs.nixgl.auto.nixGLDefault after adding nixGL overlay.
                  If null and nixGL.enable is true, will attempt to use a basic wrapper.
                '';
              };
            };

            settings = {
              resolution = {
                width = mkOption {
                  type = types.int;
                  default = 1920;
                  description = "Monitor width for streaming (1366, 1920, or 2560).";
                };
                
                height = mkOption {
                  type = types.int;
                  default = 1080;
                  description = "Monitor height for streaming (768, 1080, or 1440).";
                };
              };

              fps = mkOption {
                type = types.int;
                default = 60;
                description = "Target frame rate (30, 60, or 120). 120 FPS requires GeForce NOW Ultimate.";
              };

              userAgent = mkOption {
                type = types.str;
                default = "";
                description = "Custom user agent string. Empty string uses GeForce Infinity default.";
              };

              accentColor = mkOption {
                type = types.str;
                default = "";
                description = "Custom accent color for GeForce NOW UI (hex color code or empty for default).";
              };

              rpcEnabled = mkOption {
                type = types.bool;
                default = true;
                description = "Enable Discord Rich Presence to show current game in Discord status.";
              };

              notify = mkOption {
                type = types.bool;
                default = true;
                description = "Enable notification when gaming rig is ready.";
              };

              autofocus = mkOption {
                type = types.bool;
                default = false;
                description = "Automatically focus window when gaming rig is ready or on inactivity warning.";
              };

              automute = mkOption {
                type = types.bool;
                default = false;
                description = "Automatically mute game when window is not focused.";
              };

              inactivityNotification = mkOption {
                type = types.bool;
                default = false;
                description = "Enable notification when about to be kicked due to inactivity.";
              };

              informed = mkOption {
                type = types.bool;
                default = false;
                description = "Internal flag for first-time setup information.";
              };
            };
          };

          config = mkIf cfg.enable {
            home.packages = [ wrappedPackage ];
            
            # Create default configuration file in user's config directory
            xdg.configFile."geforce-infinity/settings.json".source = configFile;
          };
        };
    };
}
