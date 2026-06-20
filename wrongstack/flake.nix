{
  description = "WrongStack - terminal AI coding agent";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

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
            pname = "wrongstack";
            version = "0.267.0";

            # Published source from the npm registry.
            src = pkgs.fetchurl {
              url = "https://registry.npmjs.org/wrongstack/-/wrongstack-0.267.0.tgz";
              hash = "sha256-4Ewey8IKLdfPUBL7OwFkus1QGOBu5xY4q9E88dh+1KQ=";
            };

            # Upstream tarball ships no package-lock.json; overlay a vendored
            # one (generated via `npm install --package-lock-only`) so the
            # dependency resolution is reproducible.
            postPatch = ''
              cp ${./package-lock.json} package-lock.json
            '';

            npmDepsHash = "sha256-ckdVWpGgcy3AEjPM1oX/JkHyDG/lQWh1ELcWaBk2Hw8=";

            # dist/ ships prebuilt in every @wrongstack/* tarball; build script
            # is a no-op ("echo 'no build'"). No postinstall hooks anywhere
            # in the tree, no native deps -> no node-gyp/python/pkg-config needed.
            dontNpmBuild = true;

            meta = {
              description = "Terminal AI coding agent (re-export of @wrongstack/cli)";
              homepage = "https://github.com/WrongStack/WrongStack";
              license = pkgs.lib.licenses.mit;
              mainProgram = "wstack";
              platforms = systems;
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/wstack";
        };
      });
    };
}
