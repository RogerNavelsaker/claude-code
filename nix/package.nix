{ bash, bun, bun2nix, lib, makeWrapper, symlinkJoin }:

let
  manifest = builtins.fromJSON (builtins.readFile ./package-manifest.json);
  licenseMap = {
    "MIT" = lib.licenses.mit;
    "Apache-2.0" = lib.licenses.asl20;
    "SEE LICENSE IN README.md" = lib.licenses.unfree;
  };
  resolvedLicense =
    if builtins.hasAttr manifest.meta.licenseSpdx licenseMap
    then licenseMap.${manifest.meta.licenseSpdx}
    else lib.licenses.unfree;
  preserveWorkingDirectory = builtins.elem manifest.package.repo [
    "gemini-cli"
    "claude-code"
    "codex"
  ];
  aliasWrappers = lib.concatMapStrings
    (
      alias:
      ''
        makeWrapper "$out/bin/${manifest.binary.name}" "$out/bin/${alias}"
      ''
    )
    (manifest.binary.aliases or [ ]);
  basePackage = bun2nix.writeBunApplication {
    pname = manifest.package.repo;
    version = manifest.package.version;
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
  name = "${manifest.binary.name}-${manifest.package.version}";
  paths = [ basePackage ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    rm -rf "$out/bin"
    mkdir -p "$out/bin"
    if [ "${if preserveWorkingDirectory then "1" else ""}" = "1" ]; then
      entrypoint="$(find "${basePackage}/share/${manifest.package.repo}/node_modules" -path "*/node_modules/${manifest.package.npmName}/${manifest.binary.entrypoint}" | head -n 1)"
      cat > "$out/bin/${manifest.binary.name}" <<EOF
#!${lib.getExe bash}
exec ${lib.getExe' bun "bun"} "$entrypoint" "\$@"
EOF
      chmod +x "$out/bin/${manifest.binary.name}"
    else
      makeWrapper "${basePackage}/bin/${manifest.package.repo}" "$out/bin/${manifest.binary.name}"
    fi
    ${aliasWrappers}
  '';
  meta = basePackage.meta;
}
