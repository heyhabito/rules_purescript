"""Functions for building context useful to PureScript rules"""

PureScriptContext = provider(
    fields = [
        "toolchain",
        "tools",
    ],
)

def purescript_context(ctx):
    """Builds a PureScriptContext from the given rule context"""

    toolchain = ctx.toolchains["@com_habito_rules_purescript//purescript:toolchain_type"]

    return PureScriptContext(
        toolchain = toolchain,
        tools = toolchain.tools,
    )
