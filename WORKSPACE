workspace(name = "com_habito_rules_purescript")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "io_tweag_rules_nixpkgs",
    sha256 = "e08bfff0e3413cae8549df72e3fce36f7b0e2369e864dfe41d3307ef100500f8",
    strip_prefix = "rules_nixpkgs-0.4.1",
    urls = ["https://github.com/tweag/rules_nixpkgs/archive/v0.4.1.tar.gz"],
)

load(
    "@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
    "nixpkgs_local_repository",
    "nixpkgs_package",
)

load(
    "//purescript:repositories.bzl",
    "purescript_repositories",
)

nixpkgs_local_repository(
    name = "nixpkgs",
    nix_file = "//nixpkgs:default.nix",
)

nixpkgs_package(
    name = "purescript",
    repositories = {"nixpkgs": "@nixpkgs//:default.nix"},
    attribute_path = "purescript",
)

nixpkgs_package(
    name = "rsync",
    repositories = {"nixpkgs": "@nixpkgs//:default.nix"},
    attribute_path = "rsync",
)

nixpkgs_package(
    name = "tar",
    repositories = {"nixpkgs": "@nixpkgs//:default.nix"},
    attribute_path = "gnutar",
)

purescript_repositories()

register_toolchains("//tests:purescript")
