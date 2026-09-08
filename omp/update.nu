#!/usr/bin/env nu

const repo = "can1357/oh-my-pi"
const flake = "flake.nix"

def sri [hex: string] {
    let result = (^nix hash convert --hash-algo sha256 --from base16 --to sri $hex | complete)
    if $result.exit_code != 0 {
        error make { msg: $"failed to convert checksum to SRI: ($result.stderr | str trim)" }
    }
    $result.stdout | str trim
}

def checksum [sums: string, name: string] {
    let rows = $sums | lines | parse --regex '^(?<hash>[0-9a-fA-F]{64})\s+(?<name>.+)$'
    let matches = $rows | where name == $name
    if ($matches | is-empty) {
        error make { msg: $"checksum for `($name)` was not found in SHA256SUMS.txt" }
    }
    $matches.0.hash
}

def main [--dry-run (-n)] {
    let release = http get $"https://api.github.com/repos/($repo)/releases/latest"
    let tag = $release.tag_name
    if not ($tag | str starts-with "v") {
        error make { msg: $"unexpected release tag: ($tag)" }
    }
    let version = $tag | str replace --regex '^v' ''
    let sums = http get $"https://github.com/($repo)/releases/download/($tag)/SHA256SUMS.txt" | decode utf-8

    let x64_hash = sri (checksum $sums "omp-linux-x64")
    let arm64_hash = sri (checksum $sums "omp-linux-arm64")

    let original = open $flake --raw
    let lines = $original | lines
    let updated_state = $lines | reduce --fold { lines: [], target: "" } {|line, state|
        if ($line | str starts-with "      version = ") {
            {
                lines: ($state.lines | append $"      version = \"($version)\";"),
                target: $state.target,
            }
        } else if ($line | str contains "omp-linux-x64") {
            {
                lines: ($state.lines | append $line),
                target: "x64",
            }
        } else if ($line | str contains "omp-linux-arm64") {
            {
                lines: ($state.lines | append $line),
                target: "arm64",
            }
        } else if (($line | str starts-with "          hash = ") and $state.target == "x64") {
            {
                lines: ($state.lines | append $"          hash = \"($x64_hash)\";"),
                target: "",
            }
        } else if (($line | str starts-with "          hash = ") and $state.target == "arm64") {
            {
                lines: ($state.lines | append $"          hash = \"($arm64_hash)\";"),
                target: "",
            }
        } else {
            {
                lines: ($state.lines | append $line),
                target: $state.target,
            }
        }
    }
    let updated = ($updated_state.lines | str join "\n") + "\n"

    if $original == $updated {
        print $"OMP is already up to date: ($version)"
        return
    }

    if $dry_run {
        print $"Would update ($flake) to OMP ($version)"
    } else {
        $updated | save --force $flake
        print $"Updated ($flake) to OMP ($version)"
    }
}
