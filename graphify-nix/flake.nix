# flake.nix for graphify v0.8.40
# ------------------------------------------------------------------
# Build with:  nix build .#graphify        (CLI)
#              nix build .#graphify-mcp    (MCP server)
# Run with:    nix run .#graphify
#              nix run .#graphify-mcp
# ------------------------------------------------------------------
# Upstream ships both `graphify` (CLI) and `graphify-mcp` (MCP server) as
# console_scripts of the SAME wheel (`graphifyy`), with `mcp` listed as an
# optional dependency. We split them into two flake outputs so the CLI does
# not pull the `mcp` runtime: `graphify` (no `mcp`) and `graphify-mcp`
# (adds `mcp`). They share the same source/build via `mkGraphify`.
# ------------------------------------------------------------------
# Upstream nixpkgs PR (v0.4.23 base, unmerged, merge-conflict):
#   https://github.com/NixOS/nixpkgs/pull/511402
# Trick: `python3.pkgs.tree-sitter-grammars` is an auto-generated
# Python wrapper around every grammar in `pkgs.grammars`, exposing
# the `import tree_sitter_<lang>; ts.<lang>().language()` API the
# project uses at runtime.
# ------------------------------------------------------------------
# Haskell support is integrated from upstream PR #192
# (https://github.com/safishamsi/graphify/pull/192, target branch v3).
# The PR targets v3, not v0.8.40, so its source changes are backported
# via haskell-support.patch. The `tree-sitter-haskell` Python binding
# ships as `python3.pkgs.tree-sitter-grammars.tree-sitter-haskell`
# in nixpkgs (v0.23.1).
# ------------------------------------------------------------------
{
  description = "graphify - turn any folder of code, docs, papers, images, or videos into a queryable knowledge graph (Python CLI)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in {
      packages = forEachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          py = pkgs.python3;
          tsg = py.pkgs.tree-sitter-grammars;

          version = "0.8.40";
          src = pkgs.fetchFromGitHub {
            owner = "safishamsi";
            repo = "graphify";
            rev = "v${version}";
            hash = "sha256-S0EUnbpc1OTzCrq0nmMpRZekWIsb3K7gV9x7F+BJTng=";
          };

          # Shared tree-sitter grammar set (identical for both outputs).
          grammars = with tsg; [
            tree-sitter-bash
            tree-sitter-c
            tree-sitter-c-sharp
            tree-sitter-cpp
            tree-sitter-elixir
            tree-sitter-fortran
            tree-sitter-go
            tree-sitter-groovy
            tree-sitter-haskell
            tree-sitter-java
            tree-sitter-javascript
            tree-sitter-json
            tree-sitter-julia
            tree-sitter-kotlin
            tree-sitter-lua
            tree-sitter-php
            tree-sitter-powershell
            tree-sitter-python
            tree-sitter-ruby
            tree-sitter-rust
            tree-sitter-scala
            tree-sitter-swift
            tree-sitter-typescript
            tree-sitter-verilog
            tree-sitter-zig
          ];

          # Both flake outputs build the same upstream wheel; they differ
          # only in whether the `mcp` runtime dep is included (which
          # determines whether the `graphify-mcp` entry point works).
          mkGraphify = { withMcp }:
            py.pkgs.buildPythonApplication {
              __structuredAttrs = true;
              pname = "graphify";
              inherit version src;
              pyproject = true;

              build-system = [ py.pkgs.setuptools ];

              # Backport of upstream PR #192 (Haskell language support).
              # The PR targets branch v3, not v0.8.40; this patch applies
              # the source changes (extract_haskell + DISPATCH + .hs/.lhs
              # in detect.py/pyproject) to v0.8.40's tree.
              patches = [ ./haskell-support.patch ];

              # Several tree-sitter grammars in nixpkgs carry versions that
              # don't satisfy graphify's tighter pins (e.g. tree-sitter-lua
              # 0.0.19 vs >=0.2; tree-sitter-kotlin 0.3.8 vs >=1.0). The
              # compiled .so files are ABI-compatible across these minors,
              # so we skip the strict wheel-METADATA check and let the
              # actual parser binding load them.
              dontCheckRuntimeDeps = true;

              dependencies =
                (with py.pkgs; [
                  networkx
                  numpy
                  rapidfuzz
                  tree-sitter
                ])
                ++ grammars
                ++ nixpkgs.lib.optional withMcp py.pkgs.mcp;

# `dm` (tree-sitter-dm) and `terraform` (tree-sitter-hcl) are
# intentionally omitted - neither is packaged in nixpkgs.
# `tree-sitter-objc` is also omitted - only present in nixpkgs via the
# unmerged PR #511402. Objective-C (.m/.mm) files will fail to parse
# with a "tree_sitter_objc not installed" hint, same as the other
# optional grammars.
              optional-dependencies = with py.pkgs; {
                neo4j     = [ neo4j ];
                falkordb  = [ falkordb ];
                pdf       = [ pypdf markdownify ];
                watch     = [ watchdog ];
                svg       = [ matplotlib ];
                leiden    = [ graspologic ];
                office    = [ python-docx openpyxl ];
                google    = [ openpyxl ];
                video     = [ faster-whisper yt-dlp ];
                kimi      = [ openai tiktoken ];
                ollama    = [ openai ];
                bedrock   = [ boto3 ];
                anthropic = [ anthropic ];
                gemini    = [ openai tiktoken ];
                openai    = [ openai tiktoken ];
                sql       = [ tsg.tree-sitter-sql ];
                chinese   = [ jieba ];
              };

              meta = {
                description = "AI coding assistant skill - turn any folder of code, docs, papers, images, or videos into a queryable knowledge graph"
                  + nixpkgs.lib.optionalString withMcp " (MCP server)";
                homepage    = "https://github.com/safishamsi/graphify";
                changelog   = "https://github.com/safishamsi/graphify/blob/v${version}/CHANGELOG.md";
                license     = nixpkgs.lib.licenses.mit;
                mainProgram = if withMcp then "graphify-mcp" else "graphify";
                platforms   = nixpkgs.lib.platforms.unix;
              };
            };

          graphify     = mkGraphify { withMcp = false; };
          graphify-mcp = mkGraphify { withMcp = true;  };
        in {
          default = graphify;
          inherit graphify graphify-mcp;
        });

      apps = forEachSystem (system: {
        graphify = {
          type = "app";
          program = "${self.packages.${system}.graphify}/bin/graphify";
        };
        graphify-mcp = {
          type = "app";
          program = "${self.packages.${system}.graphify-mcp}/bin/graphify-mcp";
        };
      });
    };
}
