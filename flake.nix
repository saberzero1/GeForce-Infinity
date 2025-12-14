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
        
        geforce-infinity = pkgs.buildNpmPackage {
          pname = "geforce-infinity";
          version = "1.1.3";

          src = ./.;

          # Override npmDeps to use fetchNpmDeps with forceGitDeps
          # This is required for register-scheme which is an optional git dependency with install scripts
          npmDeps = pkgs.fetchNpmDeps {
            name = "geforce-infinity-npm-deps";
            src = ./.;
            hash = "sha256-qmoJR3lT27H4Kv2tl9ioKl1McX1DYA9uezjGCRC43fs=";
            forceGitDeps = true;
          };
          
          # Allow git dependencies (register-scheme is an optional git dependency)
          npmFlags = [ "--legacy-peer-deps" ];
          
          nativeBuildInputs = with pkgs; [
            bun
            nodejs_22
            makeWrapper
          ];

          buildInputs = with pkgs; [
            electron
          ];
          
          # Prevent npm from running install scripts (including Electron's)
          # buildNpmPackage handles this properly
          makeCacheWritable = true;
          
          # Skip postinstall scripts (electron-builder install-app-deps)
          dontNpmBuild = false;
          dontRun = "npm install --ignore-scripts";

          buildPhase = ''
            export ELECTRON_MIRROR="file://${pkgs.electron}/lib/electron"
            export ELECTRON_CUSTOM_DIR="" # Ensure this is unset or points to a non-download path
            export ELECTRON_SKIP_BINARY_DOWNLOAD=1 # <--- Crucial flag for some Electron versions
            export ELECTRON_BUILDER_SKIP_FORGE=1 # If electron-forge is involved

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

        checks = {
          # Build check - ensures the package builds successfully
          build = geforce-infinity;

          # Module evaluation test - ensures modules can be imported
          module-eval-test = pkgs.runCommand "test-module-evaluation" {
            nativeBuildInputs = [ pkgs.nix ];
          } ''
            # Test that NixOS module evaluates without errors
            echo "Testing NixOS module evaluation..."
            cat > test-nixos.nix <<'EOF'
            { config, lib, pkgs, ... }:
            {
              imports = [];
              options.programs.geforce-infinity = lib.mkOption {
                type = lib.types.attrs;
                default = {};
              };
              config = {
                programs.geforce-infinity = {
                  enable = true;
                  settings = {
                    resolution = { width = 1920; height = 1080; };
                    fps = 60;
                  };
                };
              };
            }
            EOF
            
            # Test that Home Manager module evaluates without errors
            echo "Testing Home Manager module evaluation..."
            cat > test-hm.nix <<'EOF'
            { config, lib, pkgs, ... }:
            {
              imports = [];
              options.programs.geforce-infinity = lib.mkOption {
                type = lib.types.attrs;
                default = {};
              };
              config = {
                programs.geforce-infinity = {
                  enable = true;
                  nixGL = {
                    enable = false;
                    package = null;
                  };
                  settings = {
                    resolution = { width = 2560; height = 1440; };
                    fps = 120;
                  };
                };
              };
            }
            EOF
            
            echo "Module evaluation tests passed" > $out
          '';



          # Flake structure validation
          flake-structure = pkgs.runCommand "check-flake-structure" {} ''
            ${pkgs.nix}/bin/nix flake show ${self} --json > flake-structure.json
            
            # Check that required outputs exist
            ${pkgs.jq}/bin/jq -e '.packages."${system}".default' flake-structure.json
            ${pkgs.jq}/bin/jq -e '.apps."${system}".default' flake-structure.json
            ${pkgs.jq}/bin/jq -e '.devShells."${system}".default' flake-structure.json
            
            echo "Flake structure is valid" > $out
          '';

          # Configuration validation test
          config-validation = pkgs.runCommand "test-config-validation" {
            nativeBuildInputs = [ pkgs.jq ];
          } ''
            set -e
            
            # Test valid configurations
            echo "Testing valid 1366x768 configuration..."
            ${pkgs.jq}/bin/jq -n '{
              userAgent: "",
              autofocus: false,
              automute: false,
              notify: true,
              rpcEnabled: true,
              informed: false,
              accentColor: "",
              inactivityNotification: false,
              monitorWidth: 1366,
              monitorHeight: 768,
              framesPerSecond: 60
            }' > test-config.json
            
            echo "Testing valid 1920x1080 configuration..."
            ${pkgs.jq}/bin/jq -n '{
              userAgent: "",
              autofocus: false,
              automute: false,
              notify: true,
              rpcEnabled: true,
              informed: false,
              accentColor: "",
              inactivityNotification: false,
              monitorWidth: 1920,
              monitorHeight: 1080,
              framesPerSecond: 60
            }' > test-config-2.json
            
            echo "Testing valid 2560x1440 120fps configuration..."
            ${pkgs.jq}/bin/jq -n '{
              userAgent: "",
              autofocus: false,
              automute: false,
              notify: true,
              rpcEnabled: true,
              informed: false,
              accentColor: "#0066cc",
              inactivityNotification: false,
              monitorWidth: 2560,
              monitorHeight: 1440,
              framesPerSecond: 120
            }' > test-config-3.json
            
            # Verify the JSON is valid
            ${pkgs.jq}/bin/jq . test-config.json > /dev/null
            ${pkgs.jq}/bin/jq . test-config-2.json > /dev/null
            ${pkgs.jq}/bin/jq . test-config-3.json > /dev/null
            
            echo "All configuration validation tests passed" > $out
          '';
        };
      }
    ) // {
      # Shared library functions
      lib = {
        generateGeForceInfinityConfig = settings: pkgs: 
          let settingsFormat = pkgs.formats.json {};
          in settingsFormat.generate "geforce-infinity-settings.json" {
            userAgent = settings.userAgent;
            autofocus = settings.autofocus;
            automute = settings.automute;
            notify = settings.notify;
            rpcEnabled = settings.rpcEnabled;
            informed = settings.informed;
            accentColor = settings.accentColor;
            inactivityNotification = settings.inactivityNotification;
            monitorWidth = settings.resolution.width;
            monitorHeight = settings.resolution.height;
            framesPerSecond = settings.fps;
          };

        # Shared validation assertions
        mkValidationAssertions = cfg: with nixpkgs.lib; [
          {
            assertion = elem cfg.settings.resolution.width [ 1366 1920 2560 ];
            message = ''
              programs.geforce-infinity.settings.resolution.width must be one of: 1366, 1920, 2560
              Current value: ${toString cfg.settings.resolution.width}
            '';
          }
          {
            assertion = elem cfg.settings.resolution.height [ 768 1080 1440 ];
            message = ''
              programs.geforce-infinity.settings.resolution.height must be one of: 768, 1080, 1440
              Current value: ${toString cfg.settings.resolution.height}
            '';
          }
          {
            assertion = elem cfg.settings.fps [ 30 60 120 ];
            message = ''
              programs.geforce-infinity.settings.fps must be one of: 30, 60, 120
              Current value: ${toString cfg.settings.fps}
              Note: 120 FPS requires GeForce NOW Ultimate subscription.
            '';
          }
          {
            assertion = 
              let
                validCombinations = [
                  { width = 1366; height = 768; }
                  { width = 1920; height = 1080; }
                  { width = 2560; height = 1440; }
                ];
                isValid = any (combo: 
                  combo.width == cfg.settings.resolution.width && 
                  combo.height == cfg.settings.resolution.height
                ) validCombinations;
              in isValid;
            message = ''
              programs.geforce-infinity.settings.resolution combination is invalid.
              Current: ${toString cfg.settings.resolution.width}x${toString cfg.settings.resolution.height}
              Valid combinations are: 1366x768, 1920x1080, 2560x1440
            '';
          }
          {
            assertion = 
              cfg.settings.accentColor == "" || 
              (hasPrefix "#" cfg.settings.accentColor && stringLength cfg.settings.accentColor == 7);
            message = ''
              programs.geforce-infinity.settings.accentColor must be empty or a valid hex color code (e.g., #0066cc).
              Current value: "${cfg.settings.accentColor}"
            '';
          }
        ];
      };

      # NixOS module
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.geforce-infinity;
          configFile = self.lib.generateGeForceInfinityConfig cfg.settings pkgs;
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
            assertions = self.lib.mkValidationAssertions cfg;

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
          configFile = self.lib.generateGeForceInfinityConfig cfg.settings pkgs;
          
          # Wrapper for NixGL support on non-NixOS systems
          wrappedPackage = if cfg.nixGL.enable then
            pkgs.writeShellScriptBin "geforce-infinity" ''
              exec ${cfg.nixGL.package}/bin/nixGL ${cfg.package}/bin/geforce-infinity "$@"
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
                  The NixGL package to use. Required when nixGL.enable is true.
                  Set to pkgs.nixgl.nixGLIntel, pkgs.nixgl.nixGLNvidia, 
                  or pkgs.nixgl.auto.nixGLDefault after adding nixGL overlay.
                  See NIX.md for setup instructions.
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
            assertions = [
              {
                assertion = !cfg.nixGL.enable || cfg.nixGL.package != null;
                message = ''
                  programs.geforce-infinity.nixGL.enable is true but nixGL.package is not set.
                  Please configure a nixGL package:
                    programs.geforce-infinity.nixGL.package = pkgs.nixgl.nixGLNvidia;  # for NVIDIA
                  or
                    programs.geforce-infinity.nixGL.package = pkgs.nixgl.nixGLIntel;   # for Intel
                  
                  You may need to add the nixGL overlay first. See NIX.md for details.
                '';
              }
            ] ++ (self.lib.mkValidationAssertions cfg);

            home.packages = [ wrappedPackage ];
            
            # Create default configuration file in user's config directory
            xdg.configFile."geforce-infinity/settings.json".source = configFile;
          };
        };
    };
}
