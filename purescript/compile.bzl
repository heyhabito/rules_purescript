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

_PURESCRIPT_COMMON_ATTRS = {
    "srcs": attr.label_list(
        allow_files = [
            ".purs",
        ],
        doc = "The PureScript source files that make up this target",
        mandatory = True,
    ),
    "src_strip_prefix": attr.string(
        doc = "The directory in which the PureScript module hierarchy starts",
    ),
    "deps": attr.label_list(
        allow_files = [
            ".purs",
            ".purs-package",
        ],
        doc = "A list of other PureScript libraries that this target depends on",
    ),
}

def _purescript_library_impl(ctx):
    """Implements the purescript_library rule"""

    ps = purescript_context(ctx)
    purs = ps.tools.purs
    rsync = ps.tools.rsync
    tar = ps.tools.tar

    package = ctx.outputs.package

    inputs = _purescript_process_inputs(ps, ctx)

    ctx.actions.run_shell(
        mnemonic = "PureScriptBuildLibrary",
        progress_message = "PureScriptBuildLibrary {}".format(ctx.label),
        inputs = inputs.combined,
        outputs = [package],
        tools = [
            purs,
            rsync,
            tar
        ],
        command = """
            set -o errexit

            package_directory=$(mktemp -d)

            for p in "" {package_path_words}
            do
                if [[ -f $p ]]
                then
                    {tar} \
                        --extract \
                        --file $p \
                        --directory $package_directory
                fi
            done

            {purs} compile {src_path_words} \
                --output $package_directory/output > /dev/null 2>&1

            {rsync} \
                --copy-links \
                --relative \
                {src_relative_path_words} $package_directory > /dev/null 2>&1

            {tar} \
                --create \
                --file {package} \
                --directory $package_directory \
                --dereference \
                .

            rm -rf $package_directory
        """.format(
            purs = purs.path,
            rsync = rsync.path,
            tar = tar.path,

            package = shell.quote(package.path),
            package_path_words = inputs.package_path_words,

            src_root = ps.src_root,
            src_path_words = inputs.src_path_words,
            src_relative_path_words = inputs.src_relative_path_words,
            src_relative_path_lines = inputs.src_relative_path_lines,
        ),
    )

purescript_library = rule(
    implementation = _purescript_library_impl,
    attrs = dict(
        _PURESCRIPT_COMMON_ATTRS,
    ),
    outputs = {
        "package": "%{name}.purs-package",
    },
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)

def _purescript_bundle_impl(ctx):
    """Implements the purescript_bundle rule"""

    pass

purescript_bundle = rule(
    implementation = _purescript_bundle_impl,
    attrs = dict(
        _PURESCRIPT_COMMON_ATTRS,
    ),
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)

def _purescript_process_inputs(ps, ctx):
    """Splits a rule's inputs into dependency packages and raw sources

    Returns:
        A struct containing the following fields:
            * `combined`:
                  A list of all dependency package and raw source `File`s
            * `packages`:
                  A list of package `File`s
            * `package_path_words`:
                  A space-delimited string of dependency package paths
            * `srcs`:
                  A list of source `File`s
            * `src_path_words`:
                  A space-delimited string of source file paths
            * `src_relative_path_words`:
                  A space-delimited string of relative source file paths
            * `src_relative_path_lines`:
                  A line-broken string of relative source file paths
    """

    combined = []

    packages = []
    package_path_words = ""

    srcs = []
    src_path_words = ""
    src_relative_path_words = ""
    src_relative_path_lines = ""

    for d in ctx.files.deps + ctx.files.srcs:
        combined.append(d)
        if d.extension == "purs-package":
            packages.append(d)
            package_path_words += " {}".format(shell.quote(d.path))
        else:
            srcs.append(d)
            src_path_words += " {}".format(d.path)
            src_relative_path = paths.relativize(d.path, ps.src_root)
            src_relative_path_words += " {}".format(
                shell.quote(ps.src_root + "/./" + src_relative_path),
            )

            src_relative_path_lines += "\n{}".format(src_relative_path)

    return struct(
        combined = combined,
        packages = packages,
        package_path_words = package_path_words,
        srcs = srcs,
        src_path_words = src_path_words,
        src_relative_path_words = src_relative_path_words,
        src_relative_path_lines = src_relative_path_lines,
    )
