#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'

run_with_full_source() {
    . "$SUT_SCRIPTS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/stdin-source.json)"
}

run_with_empty_source() {
    . "$SUT_SCRIPTS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/stdin-source-empty.json)"
}

@test "[common] extracts the url from source config as variable 'url'" {
    run_with_full_source
    assert_equal "$url" 'https://some-server:8443'
}

@test "[common] extracts the token from source config as variable 'token'" {
    run_with_full_source
    assert_equal "$token" 'a-token'
}

@test "[common] extracts the certificate_authority from source config as variable 'ca'" {
    run_with_full_source
    assert_equal "$ca" 'a-certificate'
}

@test "[common] writes the certificate_authority from source config to file 'ca_file'" {
    run_with_full_source
    assert_equal $(head -n 1 $ca_file) 'a-certificate'
}

@test "[common] extracts the resource_types from source config as variable 'resource_types'" {
    run_with_full_source
    assert_equal "$resource_types" 'namespaces'
}

@test "[common] defaults the url to empty string" {
    run_with_empty_source
    assert_equal "$url" ''
}

@test "[common] defaults the token to empty string" {
    run_with_empty_source
    assert_equal "$token" ''
}

@test "[common] defaults the certificate_authority to empty string" {
    run_with_empty_source
    assert_equal "$ca" ''
    assert_equal "$(head -n 1 $ca_file)" ''
}

@test "[common] defaults the resource_types to 'pod'" {
    run_with_empty_source
    assert_equal "$resource_types" 'pod'
}
