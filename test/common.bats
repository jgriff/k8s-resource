#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'

run_with() {
    . "$SUT_ASSETS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$1.json)"
}

@test "[common] extracts 'source.url' as variable 'source_url'" {
    run_with "stdin-source"
    assert isSet source_url
    assert_equal "$source_url" 'https://some-server:8443'
}

@test "[common] extracts 'source.token' as variable 'source_token'" {
    run_with "stdin-source"
    assert isSet source_token
    assert_equal "$source_token" 'a-token'
}

@test "[common] extracts 'source.certificate_authority' as variable 'source_ca'" {
    run_with "stdin-source"
    assert isSet source_ca
    assert_equal "$source_ca" 'a-certificate'
}

@test "[common] writes the content of 'source.certificate_authority' to file 'source_ca_file'" {
    run_with "stdin-source"
    assert isSet source_ca_file
    assert_equal $(head -n 1 $source_ca_file) 'a-certificate'
}

@test "[common] extracts 'source.insecure_skip_tls_verify' as variable 'source_insecure_skip_tls_verify'" {
    run_with "stdin-source-insecure-skip-tls-verify-true"
    assert isSet source_insecure_skip_tls_verify
    assert_equal "$source_insecure_skip_tls_verify" 'true'
}

@test "[common] extracts 'source.resource_types' as variable 'source_resource_types'" {
    run_with "stdin-source"
    assert isSet source_resource_types
    assert_equal "$source_resource_types" 'namespaces'
}

@test "[common] extracts 'source.sensitive' as variable 'source_sensitive'" {
    run_with "stdin-source-sensitive-true"
    assert isSet source_sensitive
    assert_equal "$source_sensitive" 'true'
}

@test "[common] extracts 'source.namespace' as variable 'source_namespace'" {
    run_with "stdin-source-namespace"
    assert isSet source_namespace
    assert_equal "$source_namespace" 'my-namespace'
}

@test "[common] extracts 'params.kubectl' as variable 'params_kubectl'" {
    run_with "stdin-params-kubectl"
    assert isSet params_kubectl
    assert_equal "$params_kubectl" 'apply -k overlays/prod'
}

@test "[common] extracts 'params.namespace' as variable 'params_namespace'" {
    run_with "stdin-params-namespace"
    assert isSet params_namespace
    assert_equal "$params_namespace" 'some-namespace'
}

@test "[common] extracts 'params.sensitive' as variable 'params_sensitive'" {
    run_with "stdin-params-sensitive-true"
    assert isSet params_sensitive
    assert_equal "$params_sensitive" 'true'
}

@test "[common] creates variable 'namespace_arg' with value of '-n \$source_namespace' when 'source.namespace' is configured" {
    run_with "stdin-source-namespace"
    assert isSet namespace_arg
    assert_equal "$namespace_arg" '-n my-namespace'
}

@test "[common] creates variable 'namespace_arg' with value of '-n \$params_namespace' when 'params.namespace' is configured (overrides 'source.namespace')" {
    run_with "stdin-source-namespace-params-namespace"
    assert isSet namespace_arg
    assert_equal "$namespace_arg" '-n my-override-namespace'
}

@test "[common] does not set variable 'namespace_arg' if neither 'source.namespace' nor 'params.namespace' is configured" {
    run_with "stdin-source"
    assert notSet namespace_arg
}

@test "[common] creates variable 'certificate_arg' with value of '--certificate-authority=<ca_file>'" {
    run_with "stdin-source"
    assert isSet certificate_arg
    assert_equal "$certificate_arg" "--certificate-authority=$source_ca_file"
}

@test "[common] creates variable 'certificate_arg' with value of '--certificate-authority=<ca_file>' when 'source.insecure_skip_tls_verify' is 'false'" {
    run_with "stdin-source-insecure-skip-tls-verify-false"
    assert isSet certificate_arg
    assert_equal "$certificate_arg" "--certificate-authority=$source_ca_file"
}

@test "[common] creates variable 'certificate_arg' with value of '--insecure-skip-tls-verify' when 'source.insecure_skip_tls_verify' is 'true' (overrides 'source.certificate_authority')" {
    run_with "stdin-source-insecure-skip-tls-verify-true"
    assert isSet certificate_arg
    assert_equal "$certificate_arg" '--insecure-skip-tls-verify'
}

@test "[common] creates variable 'certificate_arg' with value of '--insecure-skip-tls-verify' when 'source.insecure_skip_tls_verify' is 'true' and 'source.ca_file' omitted" {
    run_with "stdin-source-insecure-skip-tls-verify-true-ca_file-omitted"
    assert isSet certificate_arg
    assert_equal "$certificate_arg" '--insecure-skip-tls-verify'
}

@test "[common] defaults 'source_url' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_url
    assert_equal "$source_url" ''
}

@test "[common] defaults 'source_token' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_token
    assert_equal "$source_token" ''
}

@test "[common] defaults 'source_certificate_authority' to empty string" {
    run_with "stdin-source-empty"
    assert notSet source_ca
    assert_equal "$source_ca" ''
    assert_equal "$(head -n 1 $source_ca_file)" ''
}

@test "[common] defaults 'source_insecure_skip_tls_verify' to false" {
    run_with "stdin-source-empty"
    assert_equal "$source_insecure_skip_tls_verify" 'false'
}

@test "[common] defaults 'source_resource_types' to 'pod'" {
    run_with "stdin-source-empty"
    assert isSet source_resource_types
    assert_equal "$source_resource_types" 'pod'
}

@test "[common] defaults 'source_namespace' to empty" {
    run_with "stdin-source-empty"
    assert notSet source_namespace
    assert_equal "$source_namespace" ''
}

@test "[common] defaults 'source_sensitive' to empty" {
    run_with "stdin-source-empty"
    assert notSet source_sensitive
    assert_equal "$source_sensitive" ''
}

@test "[common] defaults 'params_kubectl' to empty" {
    run_with "stdin-source-empty"
    assert notSet params_kubectl
    assert_equal "$params_kubectl" ''
}

@test "[common] defaults 'params_namespace' to empty" {
    run_with "stdin-source-empty"
    assert notSet params_namespace
    assert_equal "$params_namespace" ''
}

@test "[common] defaults 'params_sensitive' to empty" {
    run_with "stdin-source-empty"
    assert notSet params_sensitive
    assert_equal "$params_sensitive" ''
}

@test "[common] isSensitive() is true when 'params.sensitive=true'" {
    run_with "stdin-params-sensitive-true"
    assert isSensitive
}

@test "[common] isSensitive() is false when 'params.sensitive=false'" {
    run_with "stdin-params-sensitive-false"
    refute isSensitive
}

@test "[common] isSensitive() is true when 'source.sensitive=true' and 'params.sensitive' is not specified" {
    run_with "stdin-source-sensitive-true"
    assert isSensitive
}

@test "[common] isSensitive() is false when 'source.sensitive=true' and 'params.sensitive=false'" {
    run_with "stdin-source-sensitive-true-params-sensitive-false"
    refute isSensitive
}

@test "[common] isSensitive() is true when 'source.sensitive=true' and 'params.sensitive=true'" {
    run_with "stdin-source-sensitive-true-params-sensitive-true"
    assert isSensitive
}

@test "[common] isSensitive() is true when 'source.sensitive=false' and 'params.sensitive=true'" {
    run_with "stdin-source-sensitive-false-params-sensitive-true"
    assert isSensitive
}

@test "[common] isSensitive() is false when 'source.sensitive=false' and 'params.sensitive=false'" {
    run_with "stdin-source-sensitive-false-params-sensitive-false"
    refute isSensitive
}

@test "[common] namespace() strips the leading '-n' from 'namespace_arg'" {
    run_with "stdin-source"

    namespace_arg="-n my-ns"
    assert_equal "my-ns" "$(namespace)"
}

@test "[common] namespace() leaves '--all-namespaces' as-is" {
    run_with "stdin-source"

    namespace_arg="--all-namespaces"
    assert_equal "--all-namespaces" "$(namespace)"
}

@test "[common] namespace() handles unset 'namespace_arg' as empty string" {
    run_with "stdin-source"

    assert_equal "" "$(namespace)"
}