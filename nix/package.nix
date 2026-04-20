{ bash, bun2nix, lib, stdenv, symlinkJoin }:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  packageVersion =
    manifest.package.version
    + lib.optionalString (manifest.package ? packageRevision) "-r${toString manifest.package.packageRevision}";
  licenseMap = {
    "MIT" = lib.licenses.mit;
    "Apache-2.0" = lib.licenses.asl20;
    "SEE LICENSE IN README.md" = lib.licenses.unfree;
  };
  resolvedLicense =
    if builtins.hasAttr manifest.meta.licenseSpdx licenseMap
    then licenseMap.${manifest.meta.licenseSpdx}
    else lib.licenses.unfree;
  bundledBinaryPackage =
    {
      x86_64-linux =
        if stdenv.hostPlatform.isMusl
        then "@anthropic-ai/claude-code-linux-x64-musl"
        else "@anthropic-ai/claude-code-linux-x64";
      aarch64-linux =
        if stdenv.hostPlatform.isMusl
        then "@anthropic-ai/claude-code-linux-arm64-musl"
        else "@anthropic-ai/claude-code-linux-arm64";
      x86_64-darwin = "@anthropic-ai/claude-code-darwin-x64";
      aarch64-darwin = "@anthropic-ai/claude-code-darwin-arm64";
    }.${stdenv.hostPlatform.system}
      or (throw "unsupported Claude Code bundled package for ${stdenv.hostPlatform.system}");
  aliasSpecs = map (
    alias:
    if builtins.isString alias then
      {
        name = alias;
        args = [ ];
      }
    else
      alias
  ) (manifest.binary.aliases or [ ]);
  renderAliasArgs = args: lib.concatMapStringsSep " " lib.escapeShellArg args;
  aliasWrappers = lib.concatMapStrings
    (
      alias:
      ''
        cat > "$out/bin/${alias.name}" <<EOF
#!${lib.getExe bash}
exec "$out/bin/${manifest.binary.name}" ${renderAliasArgs alias.args} "\$@"
EOF
        chmod +x "$out/bin/${alias.name}"
      ''
    )
    aliasSpecs;
  aliasOutputLinks = lib.concatMapStrings
    (
      alias:
      ''
        mkdir -p "${"$" + alias.name}/bin"
        cat > "${"$" + alias.name}/bin/${alias.name}" <<EOF
#!${lib.getExe bash}
exec "$out/bin/${manifest.binary.name}" ${renderAliasArgs alias.args} "\$@"
EOF
        chmod +x "${"$" + alias.name}/bin/${alias.name}"
      ''
    )
    aliasSpecs;
  basePackage = bun2nix.writeBunApplication {
    pname = manifest.package.repo;
    version = packageVersion;
    packageJson = ../package.json;
    src = lib.cleanSource ../.;
    dontUseBunBuild = true;
    dontUseBunCheck = true;
    startScript = ''
      bunx ${manifest.binary.upstreamName or manifest.binary.name} "$@"
    '';
    bunDeps = bun2nix.fetchBunDeps {
      bunNix = ../bun.nix;
    };
    meta = with lib; {
      description = manifest.meta.description;
      homepage = manifest.meta.homepage;
      license = resolvedLicense;
      mainProgram = manifest.binary.name;
      platforms = platforms.linux ++ platforms.darwin;
      broken = manifest.stubbed || !(builtins.pathExists ../bun.nix);
    };
  };
in
symlinkJoin {
  pname = manifest.binary.name;
  version = packageVersion;
  name = "${manifest.binary.name}-${packageVersion}";
  outputs = [ "out" ] ++ map (alias: alias.name) aliasSpecs;
  paths = [ basePackage ];
  postBuild = ''
    rm -rf "$out/bin"
    mkdir -p "$out/bin"
    mkdir -p "$out/share/${manifest.binary.name}"
    bundledBinaryPath="$(find "${basePackage}/share/${manifest.package.repo}/node_modules/.bun" -path "*/node_modules/${bundledBinaryPackage}/claude" | head -n 1)"
    cp "$bundledBinaryPath" "$out/share/${manifest.binary.name}/${manifest.binary.name}"
    chmod +x "$out/share/${manifest.binary.name}/${manifest.binary.name}"
    cat > "$out/bin/${manifest.binary.name}" <<EOF
#!${lib.getExe bash}
export DISABLE_AUTOUPDATER=1
unset DEV
exec "$out/share/${manifest.binary.name}/${manifest.binary.name}" "\$@"
EOF
    chmod +x "$out/bin/${manifest.binary.name}"
    ${aliasOutputLinks}
  '';
  meta = basePackage.meta;
}
