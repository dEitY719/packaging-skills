#!/usr/bin/env bash
# tests/bats/test_helper.bash -- shared setup for this repo's bats suite.
# Run: BATS_LIB_PATH=<dir with bats-support,bats-assert> bats -r tests/bats

bats_load_library bats-support
bats_load_library bats-assert

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

setup_isolated_home() {
    TEST_TEMP_HOME="$(mktemp -d)"
    export HOME="$TEST_TEMP_HOME"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    unset CLAUDE_CONFIG_DIR
    export TERM=dumb
}

teardown_isolated_home() {
    if [ -n "${TEST_TEMP_HOME:-}" ] && [ -d "$TEST_TEMP_HOME" ]; then
        rm -rf "$TEST_TEMP_HOME"
    fi
    unset TEST_TEMP_HOME
}
