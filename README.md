# PureScript rules for [Bazel][bazel]

Bazel automates building and testing software. It scales to very large
multi-language projects. This project extends Bazel with build rules for
PureScript.

[bazel]: https://bazel.build
[bazel-getting-started]: https://docs.bazel.build/versions/master/getting-started.html
[nix]: https://nixos.org/nix
[psc-package]: https://psc-package.readthedocs.io/en/latest/
[psc-prefetch]: https://github.com/heyhabito/psc-prefetch/

## Requirements

* [Bazel >= 0.20.0][bazel-getting-started]

## Setup

Add the following to your `WORKSPACE` and select a `$VERSION` (e.g. tag name or
commit hash) appropriately:

```bzl
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "com_habito_rules_purescript",
    strip_prefix = "rules_nixpkgs-$VERSION",
    urls = ["https://github.com/heyhabito/rules_purescript/archive/$VERSION.tar.gz"],
)

load(
    "//purescript:repositories.bzl",
    "purescript_repositories",
)

purescript_repositories()
```

## Configuring a toolchain

The `purescript_toolchain` rule allows you to define toolchains for compiling
PureScript code. Currently build tools and executables can be provided by:

* Nix

### Using Nix

This is the technique `rules_purescript` itself uses, so see this repository for
a working example of using Nix. First the following to your `WORKSPACE` to load
rules for working with `nixpkgs` (again, `$VERSION` is the version of
`rules_nixpkgs` you wish to use, and could be e.g. a tag or a commit hash):

```bzl
http_archive(
    name = "io_tweag_rules_nixpkgs",
    strip_prefix = "rules_nixpkgs-$VERSION",
    urls = ["https://github.com/tweag/rules_nixpkgs/archive/$VERSION.tar.gz"],
)

load(
    "@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
    "nixpkgs_local_repository",
    "nixpkgs_package",
)
```

`rules_nixpkgs` provides a number of ways for working with `nixpkgs`, but we'll
use `nixpkgs_local_repository`, which allows us to point to a `.nix` file in our
repository that exposes a `nixpkgs` expression (here a pinned version of
`nixpkgs`):

`WORKSPACE`:

```bzl
nixpkgs_local_repository(
    name = "nixpkgs",
    nix_file = "//nix:nixpkgs.nix",
)
```

`nix/nixpkgs.nix` (`$SHA` is the hash of the `nixpkgs` version we wish to pin):

```nix
import (fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/$SHA.tar.gz";
})
```

Now we can use the `nixpkgs_package` rule to pull the packages needed to form a
`purescript_toolchain` -- currently these are just PureScript and GNU Tar:

`WORKSPACE`:

```bzl
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
```

Now we can declare the toolchain in a `BUILD.bazel`:

```bzl
purescript_toolchain(
    name = "purescript",
    version = "0.12.1",
    tools = [
        "@nixpkgs_purescript//:bin",
        "@nixpkgs_tar//:bin",
    ],
)
```

and register it in the `WORKSPACE` using Bazel's `register_toolchains`:

```bzl
register_toolchains("//:purescript")
```

## Configuring a packageset

`rules_purescript` supports generating Bazel definitions for *a modified* version of PureScript
packagesets (as specified by [psc-package][psc-package]), with a `sha256` field added to each package.

### Psc-Prefetch
In order for Nix to verify the downloaded package is correct it needs a hash for each package.
This hash is checked against `nix-hash <directory> --type sha256 --base32` where directory is a checkout of the `repo` at the specified `version` (with submodules) with the `.git` directory removed.
[Psc-Prefetch][psc-prefetch] is a tool that can enrich a given package set with the necessary hashes. 

### Using Nix

The `purescript_nixpkgs_packageset` rule can be used to reify a Nix expression
describing a PureScript packageset:

`WORKSPACE`:

```bzl
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
```

The `nix_file` argument specifies a `.nix` file in the repository providing an
expression representing a function from a Bazel context to a Nix set with a
PureScript packageset (with hashes) in the attribute named by `base_attribute_path`:

`nix/purescript-packages.nix`:

```nix
{ ctx }:

with import <nixpkgs> {};

let
  genBazelBuild =
    callPackage <bazel_purescript_wrapper> { ctx = ctx; };

  packagesJSON =
    builtins.fromJSON (builtins.readFile (builtins.fetchurl {
      url = "https://raw.githubusercontent.com/heyhabito/package-sets/master/packages-with-sha256.json";
      sha256 = "0km8pnvn5wlprwc18bw9vng47dang1hp8x24k73njc50l3fi6rhh";
    }));

in {
  purescriptPackages = genBazelBuild packagesJSON;
}
```

In this file, the `<bazel_purescript_wrapper>` repository will be replaced by a
function capable of transforming a `packages.json` into a set of Nix derivations
representing those PureScript packages. It must be passed the Bazel context as
shown (here `{ ctx = ctx; }`).

The `purescript_nixpkgs_packageset` rule generates an external repository named
`<name>-imports` from which a Bazel-compatible set of rules for the packageset
can be imported and executed.  Once executed, the external repository `<name>`
can be used to reference packages in the set, e.g. given the `name =
"psc-package"` argument above, we could use:

```bzl
purescript_library(
    ...,
    deps = [
        "@psc-package//:prelude",
    ],
    ...,
)
```

## Rules reference

### Libraries

```bzl
purescript_library(
    name = "library-name",
    src_strip_prefix = "src",
    srcs = [
        "src/Library/Module.purs",
        "src/Library/AnotherModule.purs",
    ],
    foreign_srcs = [
        "src/Library/Module.js",
    ],
    deps = [
        "//path/to:library-dependency",

        "@psc-package//:prelude",
    ],
)
```

### Bundles

```bzl
purescript_bundle(
    name = "bundle-name",
    entry_point_module = "Main",
    main_module = "Main",
    src_strip_prefix = "src",
    srcs = [
        "src/Main.purs",
    ],
    foreign_srcs = [
        "src/Main.js",
    ],
    deps = [
        "//path/to:bundle-dependency",

        "@psc-package//:prelude",
    ],
)
```

## Using the REPL (PSCi)

Many rules generate targets for running REPLs. For example, the invocation:

```bzl
purescript_library(
    name = "library-name",
    ...,
)
```

will generate a target `library-name@repl`, which can be run to load a REPL
targeting that library:

```
$ bazel run //:library-name@repl
```

Note that to run `psci`, you'll need to pass your `purescript_toolchain` a
reference to a copy of the `psci-support` package's source (`.purs`) files,
which are needed to boot `psci`.

### Using a packageset

If you're using a packageset, `psci-support` should be included and the
`purescript_nixpkgs_packageset` rule will generate `.purs` targets for all
packages, which expose package source files:

```bzl
purescript_toolchain(
    ...,
    psci_support = "@psc-package//:psci-support.purs",
    ...
)
```
