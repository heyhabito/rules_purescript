{ ctx }:

with import <nixpkgs> {};

let
  genBazelBuild =
    callPackage <bazel_purescript_wrapper> { ctx = ctx; };

  packagesJSON =
    builtins.fromJSON (builtins.readFile (builtins.fetchurl {
      url = "https://raw.githubusercontent.com/heyhabito/psc-packages-with-checksum/master/packages.json";
      sha256 = "1xdfgfm1mvx8xwjarrc3chc3byf0gnrm80k4qyl074f2hy9mwxzn";
    }));

in {
  purescriptPackages = genBazelBuild packagesJSON;
}
