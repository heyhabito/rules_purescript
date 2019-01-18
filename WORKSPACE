workspace(name = "com_habito_rules_purescript")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Import rules_nixpkgs, used to provide support for PureScript toolchains
# backed by Nixpkgs

http_archive(
    name = "io_tweag_rules_nixpkgs",
    sha256 = "fe9a2b6b92df33dd159d22f9f3abc5cea2543b5da66edbbee128245c75504e41",
    strip_prefix = "rules_nixpkgs-674766086cda88976394fbd608620740857e2535",
    urls = ["https://github.com/tweag/rules_nixpkgs/archive/674766086cda88976394fbd608620740857e2535.tar.gz"],
)

load(
    "@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
    "nixpkgs_local_repository",
    "nixpkgs_package",
)

nixpkgs_local_repository(
    name = "nixpkgs",
    nix_file = "//nix:nixpkgs.nix",
)

# Import packages from Nixpkgs so that we can define a toolchain for use in
# the test suite

nixpkgs_package(
    name = "nixpkgs_purescript",
    repositories = {"nixpkgs": "@nixpkgs//:nixpkgs.nix"},
    attribute_path = "purescript",
)

nixpkgs_package(
    name = "nixpkgs_tar",
    repositories = {"nixpkgs": "@nixpkgs//:nixpkgs.nix"},
    attribute_path = "gnutar",
)

load(
    "//purescript:repositories.bzl",
    "purescript_repositories",
)

purescript_repositories()

load(
    "//purescript:nixpkgs.bzl",
    "purescript_nixpkgs_packageset",
)

purescript_nixpkgs_packageset(
    name = "psc-package",
    nix_file = "//nix:purescript-packages.nix",
    base_attribute_path = "purescriptPackages",
    repositories = {"nixpkgs": "@nixpkgs//:nixpkgs.nix"},
)

load(
    "@psc-package-imports//:packages.bzl",
    "purescript_import_packages",
)

purescript_import_packages(
    base_attribute_path = "purescriptPackages",
)

register_toolchains("//tests:purescript")
