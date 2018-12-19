load(
    ":compile.bzl",
    _purescript_library = "purescript_library",
)

load(
    ":toolchain.bzl",
    _purescript_toolchain = "purescript_toolchain",
)

purescript_library = _purescript_library

purescript_toolchain = _purescript_toolchain
