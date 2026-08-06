{
  description = "Prime Agent: self-improving RLM agent for coding workflows and long-running autonomous tasks";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
      version = "0.7.0";
    in {
      packages = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          default = pkgs.buildNpmPackage {
            pname = "prime-agent";
            inherit version;

            # Release tarball from GitHub — prebuilt dist/, no source build needed.
            src = pkgs.fetchurl {
              url = "https://github.com/PrimeIntellect-ai/prime-agent/releases/download/v${version}/prime-agent-${version}.tgz";
              hash = "sha256-iLZXhRjHLNUaglvIDyjg/vmmTGfeSn1v16/Xyhs02gs=";
            };

            # Tarball ships no package-lock.json; overlay the vendored one so
            # dependency resolution is reproducible.
            postPatch = ''
              cp ${./package-lock.json} package-lock.json
            '';

            # Set by buildNpmPackage from the lockfile; placeholder until first
            # `nix build` reports the correct hash (see Verification).
            npmDepsHash = "sha256-/I4tXx3EXuu/NdDUsg16hDKCV8rblf/fRppjELlactU=";

            # dist/ ships prebuilt in the tarball; no build step.
            dontNpmBuild = true;

            # postinstall.cjs → dist/postinstall.js is a no-op unless
            # PRIME_AGENT_BOOTSTRAP_KERNEL_ON_INSTALL=1 or
            # PRIME_AGENT_BOOTSTRAP_TOOLS_ON_INSTALL=1 (neither is set).
            # Native deps (zeromq, koffi) ship prebuilt .node binaries, so
            # --ignore-scripts (buildNpmPackage default with dontNpmBuild)
            # produces a working install with no compiler toolchain.
            dontNpmInstall = false;

            meta = {
              description = "Self-improving RLM agent for coding workflows and long-running autonomous tasks";
              homepage = "https://github.com/PrimeIntellect-ai/prime-agent";
              license = pkgs.lib.licenses.mit;
              mainProgram = "prime-agent";
              platforms = systems;
            };
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/prime-agent";
        };
      });
    };
}
