{
  description = "CodeGraph - semantic code intelligence for AI coding agents";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    codegraph-src = {
      url = "github:TontineTrust/codegraph/feat/haskell-support-clean";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, codegraph-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        nodejs = pkgs.nodejs_22;
        version = "1.4.1";
      in
      {
        packages = rec {
          codegraph = pkgs.buildNpmPackage {
            pname = "codegraph";
            inherit version;
            src = codegraph-src;

            # Replace on first build. The error will print the real hash.
            npmDepsHash = "sha256-HVd/0c0i0g+TjPE7hCXe2GPgbTwMb3nBoepTa3Dbkvo=";

            nodejs = nodejs;

            nativeBuildInputs = with pkgs; [ makeWrapper ];

            # The optional Rust extraction kernel (codegraph-kernel) is not
            # built here. Build it with `scripts/build-kernel.sh` and drop the
            # .node into codegraph-kernel/prebuilds/<platform>-<arch>/. Without
            # it, extraction falls back to the wasm pipeline.

            postInstall = ''
              rm $out/bin/codegraph
              makeWrapper ${nodejs}/bin/node $out/bin/codegraph \
                --add-flags "$out/lib/node_modules/@colbymchenry/codegraph/dist/bin/codegraph.js" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ nodejs ]}
            '';

            meta = with pkgs.lib; {
              description = "Semantic code intelligence for AI coding agents";
              homepage = "https://github.com/colbymchenry/codegraph";
              license = licenses.mit;
              mainProgram = "codegraph";
              platforms = platforms.unix;
            };
          };
          default = codegraph;
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.codegraph}/bin/codegraph";
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            nodePackages.npm
            rustup
            pkg-config
          ];

          shellHook = ''
            rustup target add "$(rustc -vV | sed -n 's|host: ||p')" 2>/dev/null || true
          '';
        };
      });
}
