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

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      codegraph-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nodejs = pkgs.nodejs_22;
        version = "1.6.0";
      in
      {
        packages = rec {
          codegraph = pkgs.buildNpmPackage {
            pname = "codegraph";
            inherit version;
            src = codegraph-src;

            npmDepsHash = "sha256-pmkzXQObY25kqCnlpPKm+wYwe0jCAkwD2ZPfPg/4Auc=";

            nodejs = nodejs;

            nativeBuildInputs = with pkgs; [ makeWrapper ];

            # The optional Rust extraction kernel (codegraph-kernel) is not
            # built here. Build it with `scripts/build-kernel.sh` and drop the
            # .node into codegraph-kernel/prebuilds/<platform>-<arch>/. Without
            # it, extraction falls back to the wasm pipeline.

            # npmBuildHook resolves `vite` via the root `node_modules/.bin`
            # first, which hoists vite 5 (root devDeps: vitest 2 / plugin-svelte
            # 4). The ui workspace needs its own vite 7, so put its bin dir
            # ahead of the root's — and patch its shebangs, which the hook only
            # does for the root node_modules (unpatched `env node` bins fail
            # under the build sandbox).
            preBuild = ''
              patchShebangs ui/node_modules/vite/bin ui/node_modules/esbuild/bin
              export PATH="$PWD/ui/node_modules/.bin:$PATH"
            '';

            # npm prune links the ui workspace into node_modules
            # (`@colbymchenry/codegraph-ui -> ../../../ui`), but the ui/ dir is
            # not packed, so the copied symlink in $out dangles and trips
            # noBrokenSymlinks. The engine never imports the ui package at
            # runtime — vite inlines the viewer into dist/viewer — so remove
            # the link from $out. Must be postInstall: prune re-creates it if
            # run before the copy.
            postInstall = ''
              rm $out/bin/codegraph
              rm -f $out/lib/node_modules/@colbymchenry/codegraph/node_modules/@colbymchenry/codegraph-ui
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
      }
    );
}
