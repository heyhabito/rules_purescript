{
  lib,
  runCommand,
  writeTextDir,

  cacert,
  fetchgit,
  nix-prefetch-git,
  stdenv,

  ctx
}:

let
  genBazelBuild = packagesJSON:
    let
      packageBuilds =
        lib.attrsets.mapAttrs
          (name: spec:
            let
              prefetch =
                builtins.fromJSON (builtins.readFile (runCommand "prefetch-${name}"
                  {
                    SSL_CERT_FILE = "${cacert.out}/etc/ssl/certs/ca-bundle.crt";
                    buildInputs = [
                      nix-prefetch-git
                    ];
                  }
                  ''
                    nix-prefetch-git \
                      --quiet \
                      --fetch-submodules \
                      --url ${spec.repo} \
                      --rev ${spec.version} > $out
                  ''));

            in
              stdenv.mkDerivation {
                name = name;
                version = spec.version;
                src = fetchgit {
                  url = spec.repo;
                  rev = prefetch.rev;
                  sha256 = prefetch.sha256;
                };
                phases = "installPhase";
                installPhase = ''
                  mkdir -p $out/src
                  cp -r $src/src/. $out/src

                  cat > $out/BUILD.bzl <<EOF
                  load(
                      "@com_habito_rules_purescript//purescript:purescript.bzl",
                      "purescript_library",
                  )

                  DEPS = ${"[" +
                    lib.strings.concatMapStringsSep "," (d: "\"" + d + "\"")
                      spec.dependencies + "]"}

                  def targets():
                      purescript_library(
                          name = "pkg",
                          src_strip_prefix = "src",
                          srcs = native.glob(["src/**/*.purs"]),
                          foreign_srcs = native.glob(["src/**/*.js"]),
                          deps = ["@${ctx.attr.packageset_name}-package-" + dep + "//:pkg" for dep in DEPS],
                          visibility = ["//visibility:public"],
                      )

                      native.filegroup(
                          name = "src",
                          srcs = native.glob(["src/**/*"]),
                      )
                  EOF
                '';
              }
          )
          packagesJSON;

      packageImports =
        lib.attrsets.mapAttrs
          (name: spec:
            ''
            #
                purescript_nixpkgs_package(
                    name = "${ctx.attr.packageset_name}-package-${name}",
                    packageset_name = "${ctx.attr.packageset_name}",
                    nix_file = "${ctx.attr.nix_file}",
                    attribute_path = base_attribute_path + ".${name}",
                    repositories = ${builtins.toJSON ctx.attr.repositories},
                )
            ''
          )
          packagesJSON;

    in
      packageBuilds // {
        packageImports =
          writeTextDir "packages.bzl"
            ''
            load(
                "@com_habito_rules_purescript//purescript:nixpkgs.bzl",
                "purescript_nixpkgs_package",
                "purescript_nixpkgs_packageset_aliases",
            )

            def purescript_import_packages(base_attribute_path):
                purescript_nixpkgs_packageset_aliases(
                    name = "${ctx.attr.packageset_name}",
                    packages = [
                        ${"\"" + lib.strings.concatStringsSep "\", \""
                          (lib.attrsets.attrNames packagesJSON) + "\""}
                    ],
                )

            ${lib.strings.concatStringsSep "\n"
              (lib.attrsets.attrValues packageImports)}
            '';
      };

in
  genBazelBuild
