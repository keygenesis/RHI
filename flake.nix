{
  description = "RHI Linux port for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rhi-src = {
      url = "github:TwoToneEddy/RHI/linux_port";
      flake = false;
    };
  };

  outputs = { nixpkgs, rhi-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

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

          data="''${XDG_DATA_HOME:-$HOME/.local/share}/rhi-nix"
          rev="${rhi-src.rev or "linux_port"}"

          work="$data/$rev"
          src="$work/src"
          out="$work/out"

          export DOTNET_CLI_TELEMETRY_OPTOUT=1
          export DOTNET_NOLOGO=1

          export LD_LIBRARY_PATH="${
            pkgs.lib.makeLibraryPath runtimeLibs
          }:''${LD_LIBRARY_PATH:-}"

          if [[ ! -f "$out/RHI.Linux.dll" ]]; then
            echo "Building RHI Linux..."

            rm -rf "$work"
            mkdir -p "$src" "$out"

            cp -R ${rhi-src}/. "$src/"
            chmod -R u+w "$src"

            ${pkgs.dotnet-sdk_8}/bin/dotnet publish \
              "$src/RHI.Linux/RHI.Linux.csproj" \
              -c Release \
              --self-contained false \
              -o "$out"
          fi

          exec ${pkgs.dotnet-sdk_8}/bin/dotnet \
            "$out/RHI.Linux.dll" \
            "$@"
        '';
      };

    in {
      packages.${system}.default = rhi;
      packages.${system}.rhi = rhi;

      apps.${system}.default = {
        type = "app";
        program = "${rhi}/bin/rhi";
      };

      apps.${system}.rhi = {
        type = "app";
        program = "${rhi}/bin/rhi";
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          dotnet-sdk_8
          p7zip
        ];

        LD_LIBRARY_PATH =
          pkgs.lib.makeLibraryPath runtimeLibs;

        RHI_DOTNET =
          "${pkgs.dotnet-sdk_8}/bin/dotnet";
      };
    };
}
