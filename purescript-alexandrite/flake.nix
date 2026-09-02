{
  description = "purescript-alexandrite: language implementation for the PureScript programming language";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    alexandrite = {
      url = "github:purefunctor/purescript-alexandrite/v0.0.19";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, alexandrite }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          purescript-alexandrite = pkgs.rustPlatform.buildRustPackage {
            pname = "purescript-alexandrite";
            version = "0.0.19";

            src = alexandrite;
            cargoLock.lockFile = "${alexandrite}/Cargo.lock";

            # Workspace default-members exclude compiler-bin; build the
            # compiler/LSP binary package explicitly.
            cargoBuildFlags = [ "-p" "purescript-alexandrite" ];
            cargoTestFlags = [ "-p" "purescript-alexandrite" ];

            meta = with pkgs.lib; {
              description = "Language implementation for the PureScript programming language";
              homepage = "https://github.com/purefunctor/purescript-alexandrite";
              license = licenses.bsd3;
              maintainers = [ ];
              mainProgram = "purescript-alexandrite";
            };
          };
          default = self.packages.${system}.purescript-alexandrite;
        });

      apps = forAllSystems (system:
        let
          inherit (self.packages.${system}) purescript-alexandrite;
        in
        {
          purescript-alexandrite = {
            type = "app";
            program = "${purescript-alexandrite}/bin/purescript-alexandrite";
          };
          purescript-analyzer = {
            type = "app";
            program = "${purescript-alexandrite}/bin/purescript-analyzer";
          };
          default = self.apps.${system}.purescript-alexandrite;
        });

      overlays.default = final: prev: {
        purescript-alexandrite = self.packages.${prev.system}.purescript-alexandrite;
      };

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              rustc
              cargo
              rustfmt
              clippy
            ];
            RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          };
        });
    };
}