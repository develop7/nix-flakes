{
  description = "oh-my-pi (omp): AI coding agent for the terminal — prebuilt release binary";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };

      version = "17.3.4";

      srcInfo = {
        x86_64-linux = {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-x64";
          hash = "sha256-P85LJWKAZLDNe/vGJF7NraMxdQ7Us0Gspr0pukR4qrU=";
        };
        aarch64-linux = {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/omp-linux-arm64";
          hash = "sha256-jifnv+SfwPM/bLC1ASirhf5UAzMNHftbs0zx90Is3Og=";
        };
      };

      licenseSrc =
        pkgs:
        pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/can1357/oh-my-pi/v${version}/LICENSE";
          hash = "sha256-VFY24ZOG09Tgrm13NUUnSZmZw+v7ymG5+lqk6tfAswg=";
        };

      ompFor =
        system:
        let
          pkgs = pkgsFor system;
          info = srcInfo.${system};
        in
        pkgs.stdenv.mkDerivation (finalAttrs: {
          pname = "oh-my-pi";
          inherit version;

          src = pkgs.fetchurl {
            url = info.url;
            hash = info.hash;
          };

          # The release artifact is a prebuilt Bun single-file binary, not
          # source — skip unpack/strip/patchELF entirely.
          dontUnpack = true;
          dontStrip = true;
          dontPatchELF = true;

          installPhase = ''
            runHook preInstall

            install -Dm755 $src $out/bin/omp
            install -Dm644 ${licenseSrc pkgs} $out/share/licenses/oh-my-pi/LICENSE

            runHook postInstall
          '';

          # Shell completions are intentionally NOT generated at build time:
          # the Bun single-file binary self-extracts into $HOME on first run,
          # which the strict Nix sandbox forbids. Generate them at runtime with
          # `omp completions bash|zsh|fish` if desired.
          meta = {
            description = "AI coding agent for the terminal — hash-anchored edits, optimized tool harness, LSP, Python, browser, subagents";
            homepage = "https://github.com/can1357/oh-my-pi";
            license = pkgs.lib.licenses.mit;
            mainProgram = "omp";
            platforms = supportedSystems;
            sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
          };
        });
    in
    {
      packages = forAllSystems (system: {
        default = ompFor system;
        omp = ompFor system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/omp";
        };
      });
    };
}
