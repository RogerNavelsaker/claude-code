# nixpkg-claude-code

Nix packaging for `@anthropic-ai/claude-code` using Bun and `bun2nix`.

## Package

- Upstream package: `@anthropic-ai/claude-code`
- Pinned version: `2.1.79`
- Description: Claude Code CLI packaged for Nix with a canonical `claude` output binary
- Installed binary: `claude`
- Upstream executable invoked by Bun: `claude`

## What This Repo Does

- Uses `bun.lock` and generated `bun.nix` as the dependency lock surface for Nix
- Builds the upstream package as an internal Bun application with `bun2nix`
- Exposes only the canonical binary name `claude`
- Provides a manifest sync script for updating the pinned npm metadata

## Files

- `flake.nix`: flake entrypoint
- `nix/package.nix`: Nix derivation
- `nix/package-manifest.json`: pinned package metadata and exposed binary name
- `scripts/sync-from-npm.ts`: updates pinned npm metadata without changing the canonical output binary

## Notes

- The default `out` output installs the longform binary name `claude`.
- The shortform wrapper `cc --dangerously-skip-permissions` is available as a separate Nix output, not in the default `out` output.
