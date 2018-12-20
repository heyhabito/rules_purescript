"""Rules for compiling PureScript code

Currently the PureScript compiler operates in an "all-at-once" mode, in which
compiling any piece of code requires providing all the sources of its
dependencies (in contrast to say, providing the compiled outputs of its
dependencies and the source for the new piece of code). Consider the following
example:

  Lib.purs
  Lib2.purs
  Lib3.purs
    import Lib
    import Lib2

in which Lib.purs and Lib2.purs define modules Lib and Lib2 and Lib3.purs
defines a module Lib3 which depends on Lib and Lib2. If Lib.purs and Lib2.purs
are compiled (e.g. to Lib.js and Lib2.js), it is not possible to compile Lib3
by providing the compiler with Lib.js, Lib2.js and Lib3.purs -- we must instead
pass Lib.purs, Lib2.purs and Lib3.purs all together. That said, if the compiler
identifies that the sources given have compiled outputs already, it will
avoid recompilation.

Consequently, the strategy we take for building PureScript compilation rules is
both to compile sources _and package the outputs with those same sources_ so
that any future compilations will have both sets of files available.
"""

load(
    "@bazel_skylib//:lib.bzl",
    "paths",
    "shell",
)

load(
    ":context.bzl",
    "purescript_context",
)

_ATTRS = struct(
    srcs = attr.label_list(
        allow_files = [
            ".purs",
        ],
        doc = "The PureScript source files that make up this target",
        mandatory = True,
    ),
    foreign_srcs = attr.label_list(
        allow_files = [
            ".js",
        ],
        doc = "The JavaScript source files that provide foreign function interfaces for this target",
    ),
    src_strip_prefix = attr.string(
        doc = "The directory in which the PureScript module hierarchy starts",
    ),
    deps = attr.label_list(
        allow_files = [
            ".purs-package",
        ],
        doc = "A list of other PureScript libraries that this target depends on",
    ),
)

def _purescript_bundle_impl(ctx):
    """Implements the purescript_bundle rule"""

    pass

purescript_bundle = rule(
    implementation = _purescript_bundle_impl,
    attrs = {
    },
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)

PureScriptLibraryInfo = provider(
    doc = "Information about a PureScript library",
    fields = [
        "package",
        "srcs",
        "foreign_srcs",
        "transitive_srcs",
        "transitive_foreign_srcs",
    ],
)

def _purescript_library_impl(ctx):
    """Implements the purescript_library rule"""

    ps = purescript_context(ctx)
    purs = ps.tools.purs
    tar = ps.tools.tar

    package = ctx.outputs.package

    ctx_p = _purescript_process_ctx(ps, ctx)

    ctx.actions.run_shell(
        mnemonic = "PureScriptBuildLibrary",
        progress_message = "PureScriptBuildLibrary {}".format(ctx.label),
        inputs = ctx_p.transitive_srcs + ctx_p.transitive_foreign_srcs,
        outputs = [package],
        tools = [
            purs,
            tar
        ],
        command = """
            set -o errexit

            package_directory=$(mktemp -d)

            {purs} compile {transitive_src_path_words} \
                --output $package_directory/output > /dev/null

            {tar} \
                --create \
                --file {package} \
                --directory $package_directory \
                --dereference \
                .

            rm -rf $package_directory
        """.format(
            purs = purs.path,
            tar = tar.path,
            package = shell.quote(package.path),
            transitive_src_path_words = ctx_p.transitive_src_path_words,
        ),
    )

    return [
        PureScriptLibraryInfo(
            package = package,
            srcs = ctx_p.srcs,
            foreign_srcs = ctx_p.foreign_srcs,
            transitive_srcs = ctx_p.transitive_srcs,
            transitive_foreign_srcs = ctx_p.transitive_foreign_srcs,
        )
    ]

def _purescript_process_ctx(ps, ctx):
    """Processes a rule's context, building a list of inputs and transitive inputs"""

    deps_p = _purescript_process_deps(ctx)

    packages = depset(deps_p.packages)
    srcs = depset(ctx.files.srcs)
    foreign_srcs = depset(ctx.files.foreign_srcs)

    transitive_srcs = depset(
        items = ctx.files.srcs,
        transitive = deps_p.transitive_srcs,
    )

    transitive_srcs_list = transitive_srcs.to_list()
    transitive_src_path_words = " ".join([s.path for s in transitive_srcs_list])

    transitive_foreign_srcs = depset(
        items = ctx.files.foreign_srcs,
        transitive = deps_p.transitive_foreign_srcs,
    )

    return struct(
        packages = packages,
        srcs = srcs,
        foreign_srcs = foreign_srcs,
        transitive_srcs = transitive_srcs,
        transitive_src_path_words = transitive_src_path_words,
        transitive_foreign_srcs = transitive_foreign_srcs,
    )

def _purescript_process_deps(ctx):
    """Aggregates the transitive information records of a rule's dependencies"""

    packages = []
    transitive_srcs = []
    transitive_foreign_srcs = []

    for d in ctx.attr.deps:
        if d[PureScriptLibraryInfo]:
            info = d[PureScriptLibraryInfo]
            packages.append(info.package)
            transitive_srcs.append(info.transitive_srcs)
            transitive_foreign_srcs.append(info.transitive_foreign_srcs)

    return struct(
        packages = packages,
        transitive_srcs = transitive_srcs,
        transitive_foreign_srcs = transitive_foreign_srcs,
    )

purescript_library = rule(
    implementation = _purescript_library_impl,
    attrs = {
        "srcs": _ATTRS.srcs,
        "foreign_srcs": _ATTRS.foreign_srcs,
        "src_strip_prefix": _ATTRS.src_strip_prefix,
        "deps": _ATTRS.deps,
    },
    outputs = {
        "package": "%{name}.purs-package",
    },
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)
