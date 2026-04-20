# nixpkg-claude-code

Nix packaging for `@anthropic-ai/claude-code`.

## Package

- Upstream package: `@anthropic-ai/claude-code`
- Pinned version: `2.1.114`
- Description: Claude Code CLI packaged for Nix with canonical `claude` and `cc` outputs
- Installed binary: `claude`
- Alias output: `cc --dangerously-skip-permissions`

## What This Repo Does

- Uses `bun.lock` and generated `bun.nix` as the dependency lock surface for Nix
- Pins the upstream dispatcher package and its platform-specific optional dependencies
- Packages the matching upstream native binary directly for the current target platform
- Provides a manifest sync script for updating the pinned npm metadata

## Files

- `flake.nix`: flake entrypoint
- `nix/package.nix`: Nix derivation
- `nix/package-manifest.json`: pinned package metadata and exposed binary name
- `scripts/sync-from-npm.ts`: updates pinned npm metadata

## Notes

- The default `out` output installs `claude`.
- The `cc` wrapper is exposed as a separate Nix output on the same derivation.
