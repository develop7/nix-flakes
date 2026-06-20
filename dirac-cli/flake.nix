{
  description = "Dirac CLI - autonomous coding agent";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          default = pkgs.buildNpmPackage {
            pname = "dirac-cli";
            version = "0.4.0";

            # Pull the published source directly from the npm registry.
            src = pkgs.fetchurl {
              url = "https://registry.npmjs.org/dirac-cli/-/dirac-cli-0.4.0.tgz";
              hash = "sha256-sZ2LeAWg5XRkwQVrsH28ma9LqEeNkQL+ncdAUyE8kqY=";
            };

            # Overlay the vendored lockfile so the dependency resolution
            # is reproducible regardless of what ships inside the registry tarball.
            postPatch = ''
              cp ${./vendor/package-lock.json} package-lock.json
              sed -i '/"man": *".\/man\/dirac\.1"/d' package.json
            '';

            npmDepsHash = "sha256-APnLcejSWQB/dcMumXn17P4lm8I4Uwtx97JJKlDXtIU=";

            dontNpmBuild = true;

            nativeBuildInputs = with pkgs; [
              python3
              pkg-config
            ];

            buildInputs = with pkgs; [ openssl ];

            meta = {
              description = "Autonomous coding agent CLI";
              homepage = "https://dirac.run";
              license = pkgs.lib.licenses.asl20;
              mainProgram = "dirac";
              platforms = [
                "x86_64-linux"
                "aarch64-linux"
                "x86_64-darwin"
                "aarch64-darwin"
              ];
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/dirac";
        };
      });
    };
}
