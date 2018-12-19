{ pkgs ? import ./nixpkgs {} }:

with pkgs;

mkShell {
  # Prevent Bazel using any toolchains provided by Xcode to improve uniformity
  # across OSX/Linux platforms.
  BAZEL_USE_CPP_ONLY_TOOLCHAIN=1;

  buildInputs = [
    bazel
    git
    nix
    purescript
  ];
}
