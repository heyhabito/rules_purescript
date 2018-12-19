"""Rules for defining PureScript toolchains"""

_PURESCRIPT_COMPILER = "purs"

_PURESCRIPT_TOOLS = [
    _PURESCRIPT_COMPILER,
]

def _purescript_check_required_tools(ctx):
    """Check that the required tools are present"""

    provided_tool_names = [t.basename for t in ctx.files.tools]
    for tool in _PURESCRIPT_TOOLS:
        if tool not in provided_tool_names:
            fail("Cannot find {tool} in {tools_label}".format(
                tool = tool,
                tools_label = ctx.attr.tools.label,
            ))

def _purescript_check_compiler_version(ctx):
    """Check that a given toolchain declares a single compiler and that it has the correct version"""

    compiler = None
    for t in ctx.files.tools:
        if t.basename == _PURESCRIPT_COMPILER:
            if compiler:
                fail("There can only be one tool named {compiler} in scope".format(
                    compiler = _PURESCRIPT_COMPILER
                ))

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

def _purescript_toolchain_impl(ctx):
    _purescript_check_required_tools(ctx)
    version_file = _purescript_check_compiler_version(ctx)

    return [
        platform_common.ToolchainInfo(
            name = ctx.label.name,
            mode = ctx.var["COMPILATION_MODE"],
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
        "tools": attr.label(
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
