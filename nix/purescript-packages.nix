{ ctx }:

with import <nixpkgs> {};

let
  genBazelBuild =
    callPackage <bazel_purescript_wrapper> { ctx = ctx; };

  packagesJSON =
    builtins.fromJSON (builtins.readFile (builtins.fetchurl {
      url = "https://raw.githubusercontent.com/purescript/package-sets/psc-0.12.1/packages.json";
      sha256 = "0iy336bgz36snkxmrb4li6b9nnv0x4dx9gbcvnw5r2q9hzlx0zvj";
    }));

in {
  purescriptPackages = genBazelBuild packagesJSON;
}
