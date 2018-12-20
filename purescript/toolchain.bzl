"""Rules for defining PureScript toolchains"""

_PURESCRIPT_TOOLS = [
    "purs",
    "tar",
]

def _purescript_toolchain_impl(ctx):
    tools = _purescript_check_required_tools(ctx)
    version_file = _purescript_check_compiler_version(ctx)

    return [
        platform_common.ToolchainInfo(
            name = ctx.label.name,
            mode = ctx.var["COMPILATION_MODE"],
            tools = tools,
            compiler_flags = ctx.attr.compiler_flags,
            version_file = version_file
        ),
    ]

_purescript_toolchain = rule(
    implementation = _purescript_toolchain_impl,
    attrs = {
        "compiler_flags": attr.string_list(
            doc = "A set of flags that will be passed to the PureScript compiler on every invocation",
        ),
        "tools": attr.label_list(
            doc = "The PureScript compiler and set of associated tools",
            mandatory = True,
        ),
        "version": attr.string(
            doc = "The version of your PureScript compiler. This much match the version reported by the compiler executable",
            mandatory = True,
        ),
    },
)

def purescript_toolchain(
    name,
    version,
    tools,
    compiler_flags = [],
    **kwargs):
    """Declare a PureScript compiler toolchain."""

    impl_name = name + "-impl"
    impl_label = ":" + impl_name

    _purescript_toolchain(
        name = impl_name,
        version = version,
        tools = tools,
        compiler_flags = compiler_flags,
        visibility = ["//visibility:public"],
        **kwargs
    )

    native.toolchain(
        name = name,
        toolchain_type = "@com_habito_rules_purescript//purescript:toolchain_type",
        toolchain = impl_label,
    )

def _purescript_check_required_tools(ctx):
    """Check that the required tools are present

    Returns:
        A struct of tools keyed by tool name
    """

    tools_struct_dict = {}
    provided_tools = {
        t.basename: t
            for t in ctx.files.tools
    }

    for tool in _PURESCRIPT_TOOLS:
        if tool not in provided_tools:
            fail("Cannot find {tool} in {tools_label}".format(
                tool = tool,
                tools_label = ctx.attr.tools.label,
            ))

        tools_struct_dict[tool] = provided_tools[tool]

    return struct(**tools_struct_dict)

def _purescript_check_compiler_version(ctx):
    """Check that a given toolchain declares a single compiler and that it has the correct version

    Returns:
        A File containing the version reported by the single declared compiler
    """

    compiler = None
    for t in ctx.files.tools:
        if t.basename == "purs":
            if compiler:
                fail("There can only be one PureScript compiler (\"purs\") in scope")

            compiler = t

    version_file = ctx.actions.declare_file("purescript-compiler-version")
    ctx.actions.run_shell(
        mnemonic = "PureScriptVersionCheck",
        inputs = [compiler],
        outputs = [version_file],
        command = """
            {compiler} --version | sed -e \"s/ .*//\" > {version_file}
            if [[ \"{expected_version}\" != \"$(< {version_file})\" ]]
            then
                cat <<EOM

PureScript compiler version mismatch

  Expected (declared in purescript_toolchain): {expected_version}
  Actual (reported by "{compiler} --version"): $(< {version_file})

EOM
                exit 1
            fi
        """.format(
            compiler = compiler.path,
            version_file = version_file.path,
            expected_version = ctx.attr.version,
            toolchain_name = ctx.attr.name,
        ),
    )

    return version_file
