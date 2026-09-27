{
  description = "sandlock — lightweight Linux sandbox built on Landlock and seccomp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    sandlock = {
      url = "github:multikernel/sandlock/v0.8.9";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    sandlock,
  }: let
    version = "0.8.9";
    lib = nixpkgs.lib;

    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "riscv64-linux"
    ];

    mkSandlock = system: pkgs:
      pkgs.rustPlatform.buildRustPackage {
        pname = "sandlock";
        inherit version;
        src = sandlock;

        cargoLock.lockFile = "${sandlock}/Cargo.lock";

        # The suite sandboxes itself, so it needs a real root filesystem:
        # the default policy grants /usr, which the build sandbox does not
        # have ("open path /usr failed: No such file or directory"). Run it
        # on a host instead; the checks below cover the built artifacts.
        doCheck = false;

        # cargoBuildHook builds with --target, so the artifacts sit under the
        # target triple's directory.
        releaseDir = "target/${pkgs.stdenv.hostPlatform.rust.rustcTarget}/release";

        # An explicit installPhase replaces cargoInstallHook, which otherwise
        # copies the whole target/ tree (and segfaults doing so on the static
        # library). Only the release's own artifacts are installed.
        installPhase = ''
          runHook preInstall

          install -Dm755 $releaseDir/sandlock $out/bin/sandlock
          install -Dm755 $releaseDir/sandlock-oci $out/bin/sandlock-oci
          install -Dm755 $releaseDir/libsandlock_ffi.so $out/lib/libsandlock_ffi.so
          install -Dm644 crates/sandlock-ffi/include/sandlock.h $out/include/sandlock.h
          install -Dm644 <(
            sed -e "s|@PREFIX@|$out|g" -e "s|@VERSION@|$version|g" go/sandlock.pc.in
          ) $out/lib/pkgconfig/sandlock.pc

          runHook postInstall
        '';

        meta = {
          description = "Lightweight process sandbox using Landlock, seccomp, and seccomp user notification";
          homepage = "https://github.com/multikernel/sandlock";
          license = lib.licenses.asl20;
          mainProgram = "sandlock";
          platforms = systems;
        };
      };
  in {
    packages = lib.genAttrs systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        sandlock = mkSandlock system pkgs;
        default = self.packages.${system}.sandlock;
      }
    );

    checks = lib.genAttrs systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        sandlock = self.packages.${system}.sandlock;
      in {
        # Landlock and seccomp are available in the build sandbox, so the check
        # confines a real process rather than only parsing the command
        # surface: a broken sandbox is silent until something is denied.
        smoke =
          pkgs.runCommand "sandlock-smoke"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.netcat
            ];
          }
          ''
            export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR
            sandlock=${sandlock}/bin/sandlock

            $sandlock --version | grep -qx "sandlock ${version}"
            ${sandlock}/bin/sandlock-oci --help | grep -q "OCI-compliant runtime"

            # A granted command runs, and its exit code reaches the caller.
            $sandlock run -r ${pkgs.coreutils} -r /nix/store -- ${pkgs.coreutils}/bin/echo confined
            rc=0
            $sandlock run -r ${pkgs.coreutils} -r /nix/store -- ${pkgs.bash}/bin/bash -c "exit 42" || rc=$?
            test $rc = 42

            # A denied path stays denied even when its directory is granted.
            ! $sandlock run -r ${pkgs.coreutils} -r /nix/store -r /etc --fs-deny /etc/passwd -- \
              ${pkgs.coreutils}/bin/cat /etc/passwd

            # Outbound network is default-deny, and --net-allow opens exactly
            # the port it names. Asserted against a loopback listener rather
            # than a public address, so the verdict is the policy and not
            # whatever the build machine's egress allows. The listener is
            # probed outside the sandbox on both sides, so a refused connect
            # cannot be explained by a listener that died.
            port=39219
            ${pkgs.netcat}/bin/nc -lk 127.0.0.1 $port &
            listener=$!
            trap 'kill $listener' EXIT
            probe() { ${pkgs.bash}/bin/bash -c "exec 3<>/dev/tcp/127.0.0.1/$port"; }
            connect() {
              $sandlock run -r ${pkgs.coreutils} -r /nix/store "$@" -- \
                ${pkgs.bash}/bin/bash -c "exec 3<>/dev/tcp/127.0.0.1/$port"
            }
            probe
            ! connect
            connect --net-allow ":$port"
            ! connect --net-allow :39220
            probe

            touch $out
          '';
      }
    );

    devShells = lib.genAttrs systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = [
            pkgs.cargo
            pkgs.rustc
            pkgs.rustfmt
            pkgs.clippy
            pkgs.rust-analyzer
          ];
        };
      }
    );

    formatter = lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
