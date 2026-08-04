{
  description = "JetBrains IntelliJ Language Server — standalone LSP for Java and Kotlin";

  inputs = {
    nixpkgs.url = "flake:nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        version = "263.2689.0";

        src = pkgs.fetchurl {
          url = "https://download.jetbrains.com/language-server/intellij-server/${version}/intellij-server-${version}.tar.gz";
          sha256 = "sha256-v0qkdKh0mcw79whuZNBfnEFA9UZJVvvVdK3MLUw+QWI=";
        };

        # Native .so dependencies discovered via objdump -p on all .so files in the tarball.
        runtimeLibs = with pkgs; [
          libX11
          libXext
          libXi
          libXrender
          libXtst
          libXfixes
          freetype
          fontconfig
          alsa-lib
          zlib
          stdenv.cc.cc.lib # libstdc++.so, libgcc_s.so
          wayland
          libxkbcommon
        ];
      in
      {
        packages = {
          default = pkgs.stdenv.mkDerivation {
            pname = "intellij-server";
            inherit version src;

            nativeBuildInputs = [ pkgs.autoPatchelfHook ];
            buildInputs = runtimeLibs;

            # The tarball extracts to intellij-server-${version}/.
            # Preserve the full directory structure — the native launcher resolves
            # JBR, product-info.json, lib/*.jar, plugins/, and vmoptions relative
            # to its own location.
            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp -r ./* $out/
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "JetBrains IntelliJ-powered language server for Java and Kotlin (LSP)";
              homepage = "https://www.jetbrains.com/help/intellij-vscode/About-instance.html";
              license = licenses.unfree;
              platforms = [ "x86_64-linux" ];
              mainProgram = "intellij-server";
            };
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/intellij-server";
        };

        devShells.default = pkgs.mkShell {
          packages = [ self.packages.${system}.default ];
        };
      });
}