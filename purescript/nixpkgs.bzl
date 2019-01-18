"""Rules for defining PureScript package sets backed by Nixpkgs."""

load(
    "@bazel_skylib//:lib/dicts.bzl",
    "dicts",
)

load(
    "@io_tweag_rules_nixpkgs//nixpkgs:nixpkgs.bzl",
    "nixpkgs_package",
)

def purescript_nixpkgs_packageset(
    name,
    nix_file,
    base_attribute_path,
    repositories = {},
    **kwargs):

    """Defines a set of external repositories for a Nixpkgs-backed PureScript
    package set.

    Args:
        name: A unique name for this rule.
        nix_file: The `.nix` file that provides a set of PureScript packages.
        base_attribute_path: The path into the expression built by `nix_file`
          that represents the PureScript package set.
        repositories: A dictionary mapping Nixpkgs repositories to their
          definitions.
    """

    repositories = dicts.add(
        {
            "bazel_purescript_wrapper": "@com_habito_rules_purescript//purescript:nix/default.nix",
        },
        repositories,
    )

    nixopts = _purescript_nixpkgs_nixopts(
        packageset_name = name,
        nix_file = nix_file,
        repositories = repositories,
    )

    nixpkgs_package(
        name = name + "-imports",
        attribute_path = base_attribute_path + ".packageImports",
        repositories = repositories,
        nix_file = nix_file,
        build_file_content = """
exports_files(["packages.bzl"])
""",
        nixopts = nixopts,
        **kwargs
    )

def purescript_nixpkgs_package(
    name,
    packageset_name,
    nix_file,
    attribute_path,
    repositories = {},
    **kwargs):

    """Defines an external repository for a PureScript package supplied by Nixpkgs."""

    repositories = dicts.add(
        {
            "bazel_purescript_wrapper": "@com_habito_rules_purescript//purescript:nix/default.nix",
        },
        repositories,
    )

    build_file_content = """
load(
    "@com_habito_rules_purescript//purescript:purescript.bzl",
    "purescript_library",
)

load(
    ":BUILD.bzl",
    "targets",
)

targets()
"""

    nixopts = _purescript_nixpkgs_nixopts(
        packageset_name = packageset_name,
        nix_file = nix_file,
        repositories = repositories,
    )

    nixpkgs_args = dict(
        name = name,
        attribute_path = attribute_path,
        build_file_content = build_file_content,
        repositories = repositories,
        nix_file = nix_file,
        nixopts = nixopts,
        **kwargs
    )

    nixpkgs_package(
        **nixpkgs_args
    )

def _purescript_nixpkgs_nixopts(packageset_name, nix_file, repositories):
    """Creates a set of nix-build arguments from the given arguments."""

    repositories_nix_set = "{"
    for name, path in repositories.items():
        repositories_nix_set += "\"{name}\" = \"{path}\";".format(
            name = name,
            path = path,
        )

    repositories_nix_set += "}"

    return [
        "--arg",
        "ctx",
        "{{ attr = {{ packageset_name = \"{packageset_name}\"; nix_file = \"{nix_file}\"; repositories = {repositories}; }}; }}".format(
            packageset_name = packageset_name,
            nix_file = nix_file,
            repositories = repositories_nix_set
        ),
    ]

def _purescript_nixpkgs_packageset_aliases(repository_ctx):
    """Implements the purescript_nixpkgs_packageset_aliases repository rule.

    Defines a set of aliases for the given package set in the current
    repository.
    """

    build_file_content = """
package(default_visibility = ["//visibility:public"])

"""

    for package in repository_ctx.attr.packages:
        build_file_content += """
alias(
    name = "{package}",
    actual = "@{packageset_name}-package-{package}//:pkg",
)

alias(
    name = "{package}.purs",
    actual = "@{packageset_name}-package-{package}//:purs",
)
        """.format(
            package = package,
            packageset_name = repository_ctx.attr.name,
        )

    repository_ctx.file("BUILD", build_file_content)

purescript_nixpkgs_packageset_aliases = repository_rule(
    implementation = _purescript_nixpkgs_packageset_aliases,
    attrs = {
        "packages": attr.string_list(
            doc = "The list of packages to be aliased.",
        ),
    },
)
