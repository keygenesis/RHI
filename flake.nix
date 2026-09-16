cat > flake.nix <<'EOF'
{
  description = "RHI Linux for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      src = self.outPath;

      buildId =
        builtins.substring 0 12 (
          builtins.hashString "sha256"
            "${toString src}:${toString pkgs.dotnet-sdk_8}"
        );

      runtimeLibs = with pkgs; [
        fontconfig
        freetype
        libglvnd

        libX11
        libXcursor
        libXext
        libXi
        libXrandr
        libXrender
        libXfixes
        libXcomposite
        libXdamage
        libXinerama
        libICE
        libSM

        libxcb
        libxkbcommon
      ];

      rhi = pkgs.writeShellApplication {
        name = "rhi";

        runtimeInputs = with pkgs; [
          dotnet-sdk_8
          p7zip
        ];

        text = ''
          set -euo pipefail

          export DOTNET_CLI_TELEMETRY_OPTOUT=1
          export DOTNET_NOLOGO=1
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath runtimeLibs}:''${LD_LIBRARY_PATH:-}"

          data="''${XDG_DATA_HOME:-$HOME/.local/share}/rhi-nix"
          work="$data/${buildId}"
          source_copy="$work/src"
          out="$work/out"

          if [[ ! -f "$out/RHI.Linux.dll" ]]; then
            echo "Building RHI Linux..."

            rm -rf "$work"
            mkdir -p "$source_copy" "$out"

            cp -R ${src}/. "$source_copy/"
            chmod -R u+w "$source_copy"

            dotnet publish \
              "$source_copy/RHI.Linux/RHI.Linux.csproj" \
              -c Release \
              --self-contained false \
              -o "$out"

            echo "RHI Linux build complete."
          fi

          exec dotnet "$out/RHI.Linux.dll" "$@"
        '';
      };
    in
    {
      packages.${system} = {
        default = rhi;
        rhi = rhi;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${rhi}/bin/rhi";
        };

        rhi = {
          type = "app";
          program = "${rhi}/bin/rhi";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          dotnet-sdk_8
          p7zip
        ];

        LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;

        RHI_DOTNET = "${pkgs.dotnet-sdk_8}/bin/dotnet";

        DOTNET_CLI_TELEMETRY_OPTOUT = "1";
        DOTNET_NOLOGO = "1";
      };
    };
}
EOF
