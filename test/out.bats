#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

source_out() {
    stdin_payload=${1:-"stdin-source"}

    # source the common script
    source "$SUT_SCRIPTS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$stdin_payload.json)"

    # stub the log function
#    log() { echo "$@"; } # use this during development to see log output
    log() { :; }
    export -f log

    # source the sut
    source "$SUT_SCRIPTS_DIR/out"
}

@test "[out] not supported" {
    source_out

    output=$(main 5>&1)

    # should emit the version indicating this operation is not (yet) supported
    assert_equal "$(jq -r '.version.not' <<< "$output")" 'supported'
}