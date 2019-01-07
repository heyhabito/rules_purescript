"""Functions for building context useful to PureScript rules."""

load(
    "@bazel_skylib//:lib/paths.bzl",
    "paths",
)

PureScriptContext = provider(
    doc = "Information about a PureScript build context/environment.",
    fields = {
        "src_root": """
The path to the directory where the PureScript module hierarchy begins.
""",
        "toolchain": """
The PureScript toolchain resolved for the rule.
""",
        "tools": """
The tools belonging to the PureScript toolchain resolved for the rule.
""",
    },
)

def purescript_context(ctx):
    """Builds a PureScriptContext from the given rule context"""

    toolchain = ctx.toolchains["@com_habito_rules_purescript//purescript:toolchain_type"]

    if hasattr(ctx.attr, "src_strip_prefix"):
        src_strip_prefix = ctx.attr.src_strip_prefix
    else:
        src_strip_prefix = ""

    src_root = paths.join(
        ctx.label.package,
        src_strip_prefix,
    )

    return PureScriptContext(
        src_root = src_root,
        toolchain = toolchain,
        tools = toolchain.tools,
    )
