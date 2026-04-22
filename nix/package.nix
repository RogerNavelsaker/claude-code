{ bash, fetchurl, lib, stdenv, stdenvNoCC, symlinkJoin }:

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
  platformKey =
    if stdenv.hostPlatform.isMusl
    then "${stdenv.hostPlatform.system}-musl"
    else stdenv.hostPlatform.system;
  platformDist =
    manifest.dist.platforms.${platformKey}
      or (throw "unsupported platform for ${manifest.binary.name}: ${platformKey}");
  binaryPath = manifest.binary.binaryPath or manifest.binary.name;
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
  basePackage = stdenvNoCC.mkDerivation {
    pname = manifest.package.repo;
    version = packageVersion;
    src = fetchurl {
      url = platformDist.url;
      hash = platformDist.hash;
    };
    sourceRoot = "package";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/${manifest.binary.name}" "$out/bin"
      cp "${binaryPath}" "$out/share/${manifest.binary.name}/${manifest.binary.name}"
      chmod +x "$out/share/${manifest.binary.name}/${manifest.binary.name}"
      cat > "$out/bin/${manifest.binary.name}" <<EOF
#!${lib.getExe bash}
export DISABLE_AUTOUPDATER=1
unset DEV
exec "$out/share/${manifest.binary.name}/${manifest.binary.name}" "\$@"
EOF
      chmod +x "$out/bin/${manifest.binary.name}"
      runHook postInstall
    '';
    meta = with lib; {
      description = manifest.meta.description;
      homepage = manifest.meta.homepage;
      license = resolvedLicense;
      mainProgram = manifest.binary.name;
      platforms = platforms.linux ++ platforms.darwin;
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
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
    ${aliasOutputLinks}
  '';
  meta = basePackage.meta;
}
