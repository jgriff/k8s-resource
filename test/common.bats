#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'

run_with() {
    . "$SUT_SCRIPTS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$1.json)"
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

@test "[common] extracts 'params.sensitive' as variable 'params_sensitive'" {
    run_with "stdin-params-sensitive-true"
    assert isSet params_sensitive
    assert_equal "$params_sensitive" 'true'
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

@test "[common] defaults 'source_resource_types' to 'pod'" {
    run_with "stdin-source-empty"
    assert isSet source_resource_types
    assert_equal "$source_resource_types" 'pod'
}

@test "[common] defaults 'source_sensitive' to empty" {
    run_with "stdin-source-empty"
    assert notSet source_sensitive
    assert_equal "$source_sensitive" ''
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
