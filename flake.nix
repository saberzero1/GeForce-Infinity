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
            
            # Install dependencies (skip postinstall to avoid electron-builder install-app-deps)
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
            
            # Copy assets
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
            
            # Create wrapper script
            makeWrapper ${pkgs.electron}/bin/electron $out/bin/geforce-infinity \
              --add-flags "$out/lib/geforce-infinity/dist/electron/main.js" \
              --set NODE_ENV production \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.libpulseaudio ]}"
            
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
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

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
          };

          config = mkIf cfg.enable {
            home.packages = [ cfg.package ];

            # XDG desktop entries will be automatically installed from the package
          };
        };
    };
}
