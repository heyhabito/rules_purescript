"""Repository rules for PureScript-enabled WORKSPACEs"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def purescript_repositories():
    """Provide all repositories that are necessary for `rules_purescript` to
    function"""

    excludes = native.existing_rules().keys()

    if "bazel_skylib" not in excludes:
        http_archive(
            name = "bazel_skylib",
            strip_prefix = "bazel-skylib-0.5.0",
            urls = ["https://github.com/bazelbuild/bazel-skylib/archive/0.5.0.tar.gz"],
            sha256 = "b5f6abe419da897b7901f90cbab08af958b97a8f3575b0d3dd062ac7ce78541f",
        )
