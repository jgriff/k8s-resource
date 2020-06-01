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

@test "[out] GH-7 changes into sources directory given" {
    source_out

    sourcesDirectory "$BATS_TMPDIR"

    # assert that we changed into the directory
    assert_equal $BATS_TMPDIR $PWD
}

@test "[out] GH-7 invoke kubectl with args provided by 'params.kubectl'" {
    source_out "stdin-source-namespace-params-kubectl"

    # mock kubectl to expect our invocation
    expected_kubectl_args="--server=$source_url --token=$source_token --certificate-authority=$source_ca_file -n my-namespace apply -k overlays/prod"
    stub kubectl "$expected_kubectl_args : echo 'stuff the k8s server sends back'"

    output=$(invokeKubectl)

    # verify kubectl was called correctly
    unstub kubectl

    # should emit the output of kubectl
    assert_equal "$output" 'stuff the k8s server sends back'
}

@test "[out] GH-7 uses no namespace when none configured" {
    source_out "stdin-source-params-kubectl"

    # mock kubectl to expect our invocation
    expected_kubectl_args="--server=$source_url --token=$source_token --certificate-authority=$source_ca_file apply -k overlays/prod"
    stub kubectl "$expected_kubectl_args : echo 'stuff the k8s server sends back'"

    output=$(invokeKubectl)

    # verify kubectl was called correctly
    unstub kubectl

    # should emit the output of kubectl
    assert_equal "$output" 'stuff the k8s server sends back'
}

@test "[out] GH-7 can override namespace in params" {
    source_out "stdin-source-namespace-params-kubectl-namespace"

    # mock kubectl to expect our invocation
    expected_kubectl_args="--server=$source_url --token=$source_token --certificate-authority=$source_ca_file -n my-override-namespace apply -k overlays/prod"
    stub kubectl "$expected_kubectl_args : echo 'stuff the k8s server sends back'"

    output=$(invokeKubectl)

    # verify kubectl was called correctly
    unstub kubectl

    # should emit the output of kubectl
    assert_equal "$output" 'stuff the k8s server sends back'
}

@test "[out] GH-7 emits the version as the kubectl command given by 'params.kubectl'" {
    source_out "stdin-source-namespace-params-kubectl"

    output=$(emitResult 5>&1)

    # should emit the version with the kubectl command executed
    assert_equal "$(jq -r '.version.kubectl' <<< "$output")" 'apply -k overlays/prod'
}

@test "[out] GH-7 emits the server url in the output metadata" {
    source_out "stdin-source-namespace-params-kubectl"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '. | any(.metadata[]; .name == "server" and .value == "https://some-server:8443")' <<< "$output")" 'true'
}

@test "[out] GH-7 emits the namespace in the output metadata" {
    source_out "stdin-source-namespace-params-kubectl"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '. | any(.metadata[]; .name == "namespace" and .value == "my-namespace")' <<< "$output")" 'true'
}

@test "[out] GH-7 emits empty string for the namespace in the output metadata if it was not configured" {
    source_out "stdin-source-params-kubectl"

    output=$(emitResult 5>&1)

    assert_equal "$(jq -r '. | any(.metadata[]; .name == "namespace" and .value == "")' <<< "$output")" 'true'
}