"""Rules for compiling PureScript code"""

load(
    ":context.bzl",
    "purescript_context",
)

_PURESCRIPT_COMMON_ATTRS = {
    "srcs": attr.label_list(
        allow_files = [
            ".purs",
        ],
        doc = "PureScript source files",
        mandatory = True,
    ),
    "src_strip_prefix": attr.string(
        doc = "The directory in which the PureScript module hierarchy starts",
    ),
}

def _purescript_library_impl(ctx):
    ps = purescript_context(ctx)

    output = ctx.actions.declare_file("Lib.js")

    ctx.actions.run_shell(
        inputs = [ps.toolchain.version_file],
        outputs = [output],
        command = """
            echo $@
            cat {version_file} > {output}
        """.format(
            version_file = ps.toolchain.version_file.path,
            output = output.path,
        ),
    )

    return [
        DefaultInfo(
            files = depset([output]),
        )
    ]

purescript_library = rule(
    implementation = _purescript_library_impl,
    attrs = dict(
        _PURESCRIPT_COMMON_ATTRS,
    ),
    toolchains = [
        "@com_habito_rules_purescript//purescript:toolchain_type",
    ],
)

def _purescript_bundle_impl(ctx):
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
