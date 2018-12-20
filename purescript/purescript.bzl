load(
    ":compile.bzl",
    _purescript_bundle = "purescript_bundle",
    _purescript_library = "purescript_library",
)

load(
    ":repositories.bzl",
    _purescript_repositories = "purescript_repositories",
)

load(
    ":toolchain.bzl",
    _purescript_toolchain = "purescript_toolchain",
)

purescript_bundle = _purescript_bundle

purescript_library = _purescript_library

purescript_repositories = _purescript_repositories

purescript_toolchain = _purescript_toolchain
