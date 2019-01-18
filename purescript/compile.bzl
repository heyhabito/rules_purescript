"""Rules for compiling PureScript code.

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
    "@bazel_skylib//:lib/paths.bzl",
    "paths",
)

load(
    "@bazel_skylib//:lib/shell.bzl",
    "shell",
)

load(
    ":context.bzl",
    "purescript_context",
)

_ATTRS = struct(
    # Common public attributes.
    entry_point_module = attr.string(
        doc = """
The name of the module to be used as an entry point.
""",
        mandatory = True,
    ),
    main_module = attr.string(
        doc = """
If supplied, code will be generated to run the `main` function in this module.
""",
    ),
    srcs = attr.label_list(
        doc = """
The PureScript source files that make up this target.
""",
        allow_files = [
            ".purs",
        ],
        mandatory = True,
    ),
    foreign_srcs = attr.label_list(
        doc = """
The JavaScript source files that provide foreign function interfaces for this
target.
""",
        allow_files = [
            ".js",
        ],
    ),
    src_strip_prefix = attr.string(
        doc = """
The directory in which the PureScript module hierarchy starts.
""",
    ),
    deps = attr.label_list(
        doc = """
A list of other PureScript libraries that this target depends on.
""",
        allow_files = [
            ".purs-package",
        ],
    ),

    # Common private attributes.
    _repl_template = attr.label(
        doc = """
The template to be used for generating scripts which invoke PureScript REPLs.
""",
        default = Label("@com_habito_rules_purescript//purescript:repl.sh"),
        allow_single_file = True,
    ),
)

PureScriptBundleInfo = provider(
    doc = "Information about a PureScript bundle.",
    fields = {
        "bundle": "The bundle `File`.",
    },
)

def _purescript_bundle_impl(ctx):
    """Implements the purescript_bundle rule."""

    ps = purescript_context(ctx)
    purs = ps.tools.purs
    tar = ps.tools.tar

    repl_template = ctx.file._repl_template
    entry_point_module = ctx.attr.entry_point_module
    bundle = ctx.outputs.bundle

    bundle_package = ctx.actions.declare_file("bundle.purs-package")
    bundle_repl = ctx.actions.declare_file("bundle@repl")

    ctx_p = _purescript_process_ctx(ps, ctx)

    _purescript_build_library(
        ps,
        ctx,
        mnemonic = "PureScriptBuildBundle",
        progress_message = "PureScriptBuildBundle {}".format(ctx.label),
        purs = purs,
        tar = tar,
        ctx_p = ctx_p,
        package = bundle_package,
        repl_template = repl_template,
        repl = bundle_repl,
    )

    if ctx.attr.main_module:
        main_argument = "--main {}".format(ctx.attr.main_module)
    else:
        main_argument = ""

    ctx.actions.run_shell(
        mnemonic = "PureScriptBundle",
        progress_message = "PureScriptBundle {}".format(ctx.label),
        inputs = [bundle_package],
        outputs = [bundle],
        tools = [
            purs,
            tar,
        ],
        command = """
            set -o errexit

            package_directory=$(mktemp -d)

            {tar} \
                --extract \
                --file {bundle_package} \
                --directory $package_directory

            {purs} bundle $package_directory/output/*/*.js \
                --module {entry_point_module} \
                {main_argument} \
                --output {bundle} > /dev/null

            rm -rf $package_directory
        """.format(
            tar = tar.path,
            bundle_package = bundle_package.path,
            purs = purs.path,
            entry_point_module = entry_point_module,
            main_argument = main_argument,
            bundle = bundle.path,
        ),
    )

    return [
        PureScriptBundleInfo(
            bundle = bundle,
        )
    ]

purescript_bundle = rule(
    implementation = _purescript_bundle_impl,
    doc = """
Build a bundle from PureScript sources.
""",
    attrs = {
        "entry_point_module": _ATTRS.entry_point_module,
        "main_module": _ATTRS.main_module,
        "srcs": _ATTRS.srcs,
        "foreign_srcs": _ATTRS.foreign_srcs,
        "src_strip_prefix": _ATTRS.src_strip_prefix,
        "deps": _ATTRS.deps,

        "_repl_template": _ATTRS._repl_template,
    },
    outputs = {
        "bundle": "%{name}.js",
    },
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)

PureScriptLibraryInfo = provider(
    doc = "Information about a PureScript library.",
    fields = {
        "package": """
The package `File` containing the library's artifacts.
""",
        "srcs": """
A `depset` of the library's PureScript source `File`s.
""",
        "foreign_srcs": """
A `depset` of the library's foreign JavaScript source `File`s.
""",
        "transitive_srcs": """
A transitive `depset` of the library's PureScript source `File`s.
""",
        "transitive_foreign_srcs": """
A transitive `depset` of the library's foreign JavaScript source `Files`.
""",
    },
)

def _purescript_library_impl(ctx):
    """Implements the purescript_library rule."""

    ps = purescript_context(ctx)
    purs = ps.tools.purs
    tar = ps.tools.tar

    package = ctx.outputs.package
    repl_template = ctx.file._repl_template
    repl = ctx.outputs.repl

    ctx_p = _purescript_process_ctx(ps, ctx)

    _purescript_build_library(
        ps,
        ctx,
        mnemonic = "PureScriptBuildLibrary",
        progress_message = "PureScriptBuildLibrary {}".format(ctx.label),
        purs = purs,
        tar = tar,
        ctx_p = ctx_p,
        package = package,
        repl_template = repl_template,
        repl = repl,
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

def _purescript_build_library(
    ps,
    ctx,
    mnemonic,
    progress_message,
    purs,
    tar,
    ctx_p,
    package,
    repl_template,
    repl):

    if ps.psci_support:
        psci_support_files = " ".join([f.path for f in ps.psci_support.files])
    else:
        psci_support_files = ""

    ctx.actions.expand_template(
        template = repl_template,
        output = repl,
        substitutions = {
            "{psci_support}": psci_support_files,
            "{library}": ctx_p.transitive_src_path_words,
        },
        is_executable = True,
    )

    ctx.actions.run_shell(
        mnemonic = mnemonic,
        progress_message = progress_message,
        inputs = ctx_p.transitive_srcs + ctx_p.transitive_foreign_srcs,
        outputs = [package],
        tools = [
            purs,
            tar,
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
            transitive_src_path_words = ctx_p.transitive_src_path_words,
            package = shell.quote(package.path),
        ),
    )

def _purescript_process_ctx(ps, ctx):
    """Processes a rule's context, building a list of inputs and transitive
    inputs."""

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
    """Aggregates the transitive information records of a rule's
    dependencies."""

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
    doc = """
Build a library from PureScript sources.
""",
    attrs = {
        "srcs": _ATTRS.srcs,
        "foreign_srcs": _ATTRS.foreign_srcs,
        "src_strip_prefix": _ATTRS.src_strip_prefix,
        "deps": _ATTRS.deps,

        "_repl_template": _ATTRS._repl_template,
    },
    outputs = {
        "package": "%{name}.purs-package",
        "repl": "%{name}@repl",
    },
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)
