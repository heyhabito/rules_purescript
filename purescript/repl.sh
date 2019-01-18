#!/usr/bin/env bash

# The BUILD_WORKSPACE_DIRECTORY is set by `bazel run`.
if [ "$BUILD_WORKSPACE_DIRECTORY" = "" ]
then
    cat <<EOF
It looks like you are trying to invoke the REPL incorrectly.
Currently this script can only be invoked using `bazel run`, as in:

$ bazel run //path/to/target@repl

Note that if you using Bazel < 0.15 you will need the `--direct_run`
flag, as in:

$ bazel run --direct_run //path/to/target@repl
EOF
    exit 1
fi

RULES_PURESCRIPT_EXEC_ROOT=$(dirname $(readlink ${BUILD_WORKSPACE_DIRECTORY}/bazel-out))

pushd $RULES_PURESCRIPT_EXEC_ROOT
purs repl {psci_support} {library}
popd
