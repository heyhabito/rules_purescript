"""Functions for building context useful to PureScript rules"""

PureScriptContext = provider(
    fields = [
        "toolchain",
    ],
)

def purescript_context(ctx):
    toolchain = ctx.toolchains["@com_habito_rules_purescript//purescript:toolchain_type"]

    return PureScriptContext(
        toolchain = toolchain,
    )
