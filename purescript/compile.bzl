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
pass Lib.purs, Lib2.purs and Lib3.purs all together, compiling the first two
modules again.

Consequently, the strategy we take for building PureScript compilation rules is
not to compile anything until an executable bundle is actually required --
library "compilation" simply requires bundling sources for any future
all-at-once compilation.
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
    rsync = ps.tools.rsync
    tar = ps.tools.tar

    package = ctx.outputs.package

    inputs = _purescript_process_inputs(ctx)

    ctx.actions.run_shell(
        mnemonic = "PureScriptBuildLibrary",
        progress_message = "PureScriptBuildLibrary {}".format(ctx.label),
        inputs = inputs.combined,
        outputs = [package],
        tools = [
            rsync,
            tar
        ],
        command = """
            set -o errexit

            package_directory=$(mktemp -d)
            file_list=$(mktemp)

            for p in "" {package_path_words}
            do
                if [[ -f $p ]]
                then
                    {tar} \
                        --extract \
                        --verbose \
                        --file $p \
                        --directory $package_directory >> $file_list
                fi
            done
            cat >> $file_list <<EOF
{src_relative_path_lines}
EOF

            {rsync} -LR {src_relative_path_words} $package_directory

            {tar} \
                --create \
                --file {package} \
                --directory $package_directory \
                --dereference \
                --files-from $file_list

            rm -rf $file_list $package_directory
        """.format(
            rsync = rsync.path,
            tar = tar.path,

            package = shell.quote(package.path),
            package_path_words = inputs.package_path_words,

            src_directory = inputs.src_directory,
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

def _purescript_process_inputs(ctx):
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
            * `src_directory`:
                  The directory which relative source paths are relative to
            * `src_relative_path_words`:
                  A space-delimited string of relative source file paths
            * `src_relative_path_lines`:
                  A line-broken string of relative source file paths
    """

    combined = []

    packages = []
    package_path_words = ""

    srcs = []
    src_directory = ctx.label.package
    src_relative_path_words = ""
    src_relative_path_lines = ""

    for d in ctx.files.deps:
        combined.append(d)
        if d.extension == "purs-package":
            packages.append(d)
            package_path_words += " {}".format(shell.quote(d.path))
        else:
            srcs.append(d)
            src_relative_path = paths.relativize(d.path, ctx.label.package)
            src_relative_path_words += " {}".format(
                shell.quote(src_directory + "/./" + src_relative_path),
            )

            src_relative_path_lines += "\n{}".format(src_relative_path)

    # Currently the "srcs" attribute is limited to only allow .purs files, so
    # it is guaranteed not to contain any packages and we can thus add it
    # wholesale to our list of sources.
    for s in ctx.files.srcs:
        combined.append(s)
        srcs.append(s)
        src_relative_path = paths.relativize(s.path, ctx.label.package)
        src_relative_path_words += " {}".format(
            shell.quote(src_directory + "/./" + src_relative_path),
        )

        src_relative_path_lines += "\n{}".format(src_relative_path)

    return struct(
        combined = combined,
        packages = packages,
        package_path_words = package_path_words,
        srcs = srcs,
        src_directory = src_directory,
        src_relative_path_words = src_relative_path_words,
        src_relative_path_lines = src_relative_path_lines,
    )
