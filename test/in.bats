#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

setup() {
    rm -f "$BATS_TMPDIR/resource.json"
}

source_in() {
    stdin_payload=${1:-"stdin-source-with-version"}
    kubectl_response=${2:-"kubectl-response"}

    # source the common script
    source "$SUT_SCRIPTS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$stdin_payload.json)"

    # stub the log function
#    log() { echo "$@"; } # use this during development to see log output
    log() { :; }
    export -f log

    # mock kubectl to return our expected response
    local expected_kubectl_args="--server=$source_url --token=$source_token --certificate-authority=$source_ca_file \
            get $source_resource_types --all-namespaces --sort-by={.metadata.resourceVersion} -o json"
    stub kubectl "$expected_kubectl_args : cat $BATS_TEST_DIRNAME/fixtures/$kubectl_response.json"

    # source the sut
    source "$SUT_SCRIPTS_DIR/in"
}

teardown() {
    # don't strictly assert invocations
    unstub kubectl 2> /dev/null || true
}

@test "[in] version is extracted" {
    source_in

    extractVersion

    assert_equal "$uid" 'cee83946-92c3-11e9-a784-3497f601230d'
    assert_equal "$resourceVersion" '6988465'
}

@test "[in] fetches the resource matching the requested version" {
    source_in

    target_dir=$BATS_TMPDIR
    uid="8fca7c5f-c513-11e9-a16f-1831bfd00891"
    resourceVersion=22577654

    fetchResource

    # then a 'resource.json' file contains the retrieved resource
    retrieved_resource="$BATS_TMPDIR/resource.json"
    assert [ -e "$retrieved_resource" ]

    # and it contains the full resource content
    assert_equal "$(jq -r '.metadata.uid' < "$retrieved_resource")" '8fca7c5f-c513-11e9-a16f-1831bfd00891'
    assert_equal "$(jq -r '.metadata.resourceVersion' < "$retrieved_resource")" '22577654'
    assert_equal "$(jq -r '.metadata.name' < "$retrieved_resource")" 'namespace-2'
}

@test "[in] fetched resource file will be empty if the requested uid is not found" {
    source_in

    target_dir=$BATS_TMPDIR
    uid="uid-that-does-not-exist"
    resourceVersion=22577654

    fetchResource

    # then the 'resource.json' file will exist
    retrieved_resource="$BATS_TMPDIR/resource.json"
    assert [ -e "$retrieved_resource" ]

    # but it should be empty
    refute [ -s "$retrieved_resource/resource.json" ]
}

@test "[in] fetched resource file will be empty if the requested resourceVersion does not match" {
    source_in

    target_dir=$BATS_TMPDIR
    uid="8fca7c5f-c513-11e9-a16f-1831bfd00891"
    resourceVersion=42

    fetchResource

    # then the 'resource.json' file will exist
    retrieved_resource="$BATS_TMPDIR/resource.json"
    assert [ -e "$retrieved_resource" ]

    # but it should be empty
    refute [ -s "$retrieved_resource/resource.json" ]
}

@test "[in] GH-1: echos fetched resource content by default" {
    source_in

    target_dir=$BATS_TMPDIR

    # write out a dummy resource file that we expect our sut to log (publicly)
    jq -n "{
        apiVersion: \"v1\",
        kind: \"Pod\",
        metadata: {
            name: \"some-pod-7f56d7f494-d69k2\",
        },
    }" > $target_dir/resource.json

    # capture the args passed to the log() function
    output=""
    log() { output+="$@"; }
    export -f log

    # run it!
    emitResult

    # assert that we logged the content of the resource file publicly (-p)
    assert_output --partial "-p $(cat $target_dir/resource.json)"
}

gh1SensitiveFalse() {
    target_dir=$BATS_TMPDIR

    # write out a dummy resource file to use as input
    jq -n "{
        apiVersion: \"v1\",
        kind: \"Pod\",
        metadata: {
            name: \"some-pod-7f56d7f494-d69k2\",
        },
    }" > $target_dir/resource.json

    # capture the args passed to the log() function
    output=""
    log() { output+="$@"; }
    export -f log

    # run it!
    emitResult

    # assert that we logged the content of the resource file publicly (-p)
    assert_output --partial "-p $(cat $target_dir/resource.json)"
}

gh1SensitiveTrue() {
    target_dir=$BATS_TMPDIR

    # write out a dummy resource file to use as input
    jq -n "{
        apiVersion: \"v1\",
        kind: \"Pod\",
        metadata: {
            name: \"some-pod-7f56d7f494-d69k2\",
        },
    }" > $target_dir/resource.json

    # capture the args passed to the log() function
    output=""
    log() { output+="$@"; }
    export -f log

    # run it!
    emitResult

    # assert that we did NOT log the content of the resource file at all
    refute_output --partial "$(cat $target_dir/resource.json)"
}

@test "[in] GH-1: source config 'sensitive=false' enables echo'ing fetched resource" {
    source_in "stdin-source-sensitive-false"
    gh1SensitiveFalse
}

@test "[in] GH-1: source config 'sensitive=true' disables echo'ing fetched resource" {
    source_in "stdin-source-sensitive-true"
    gh1SensitiveTrue
}

@test "[in] GH-1: params config 'sensitive=false' enables echo'ing fetched resource" {
    source_in "stdin-params-sensitive-false"
    gh1SensitiveFalse
}

@test "[in] GH-1: params config 'sensitive=true' disables echo'ing fetched resource" {
    source_in "stdin-params-sensitive-true"
    gh1SensitiveTrue
}

@test "[in] GH-1: source config 'sensitive=true' and params config overrides with 'sensitive=false' then the resource is echo'd" {
    source_in "stdin-source-sensitive-true-params-sensitive-false"
    gh1SensitiveFalse
}

@test "[in] GH-1: source config 'sensitive=false' and params config overrides with 'sensitive=true' then the resource is NOT echo'd" {
    source_in "stdin-source-sensitive-false-params-sensitive-true"
    gh1SensitiveTrue
}

@test "[in] e2e in" {
    source_in

    output=$(main 5>&1)

    # should emit the version 'uid' and 'resourceVersion' attributes
    assert_equal "$(jq -r '.version | length' <<< "$output")" '2'
    assert_equal "$(jq -r '.version.uid' <<< "$output")" 'cee83946-92c3-11e9-a784-3497f601230d'
    assert_equal "$(jq -r '.version.resourceVersion' <<< "$output")" '6988465'

    # and include the resource's metadata
    assert_equal "$(jq -r '.metadata | length' <<< "$output")" '5'
    assert_equal "$(jq -r '. | any(.metadata[]; .name == "creationTimestamp" and .value == "2019-06-19T18:55:29Z")' <<< "$output")" 'true'
    assert_equal "$(jq -r '. | any(.metadata[]; .name == "name" and .value == "namespace-1")' <<< "$output")" 'true'
    assert_equal "$(jq -r '. | any(.metadata[]; .name == "resourceVersion" and .value == "6988465")' <<< "$output")" 'true'
    assert_equal "$(jq -r '. | any(.metadata[]; .name == "selfLink" and .value == "/api/v1/namespaces/namespace-1")' <<< "$output")" 'true'
    assert_equal "$(jq -r '. | any(.metadata[]; .name == "uid" and .value == "cee83946-92c3-11e9-a784-3497f601230d")' <<< "$output")" 'true'
}