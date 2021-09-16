#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

#setup() {
    # do any general setup
#}

source_check() {
    stdin_payload=${1:-"stdin-source"}
    kubectl_response=${2:-"kubectl-response"}

    # source the common script
    source "$SUT_ASSETS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$stdin_payload.json)"

    # stub the log function
    #log() { echo "$@"; } # use this during development to see log output
    log() { :; }
    export -f log

    # mock kubectl to return our expected response
    local expected_kubectl_args="--server=$source_url --token=$source_token ${expected_ca_arg:---certificate-authority=$source_ca_file} \
            get $source_resource_types ${expected_namespace_arg:---all-namespaces} --sort-by={.metadata.resourceVersion} -o json"

    if [ $kubectl_response == "FAIL" ]; then
        stub kubectl "$expected_kubectl_args : exit 1"
    else
        stub kubectl "$expected_kubectl_args : cat $BATS_TEST_DIRNAME/fixtures/$kubectl_response.json"
    fi

    # source the sut
    source "$SUT_ASSETS_DIR/check"
}

teardown() {
    # don't strictly assert invocations
    unstub kubectl || true
}

@test "[check] previous version is extracted" {
    source_check "stdin-source-with-version"

    extractPreviousVersion

    assert_equal $(jq -r '.uid' <<< "$previous_version") 'cee83946-92c3-11e9-a784-3497f601230d'
    assert_equal $(jq -r '.resourceVersion' <<< "$previous_version") '6988465'
}

@test "[check] previous version is empty if not provided" {
    source_check

    extractPreviousVersion

    assert_equal "$previous_version" ''
}

@test "[check] queries k8s cluster for new versions" {
    source_check

    queryForVersions

    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'namespace-other'
}

@test "[check] filter by name matches exact strings" {
    source_check "stdin-source-filter-name"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-other"
            }
        }
    ]'

    filterByName

    # then only names exactly matching remain
    assert_equal $(jq length <<< "$new_versions") 1
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-2'
}

@test "[check] filter by name matches regex" {
    source_check "stdin-source-filter-name-regex"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-other"
            }
        }
    ]'

    filterByName

    # then only names matching the regex remain
    assert_equal $(jq length <<< "$new_versions") 2
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
}

@test "[check] filter by name not configured" {
    source_check "stdin-source-empty"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-other"
            }
        }
    ]'

    filterByName

    # then our 'new_versions' is left unchanged
    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'namespace-other'
}

@test "[check] filter by olderThan" {
    source_check "stdin-source-filter-olderThan"

    now="$(date +%Y-%m-%dT%H:%M:%SZ)"
    hourAgo="$(date -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)"
    dayAgo="$(date -d '25 hours ago' +%Y-%m-%dT%H:%M:%SZ)"

    new_versions="[
        {
            \"metadata\": {
                \"name\": \"namespace-1\",
                \"creationTimestamp\": \"$now\"
            }
        },
        {
            \"metadata\": {
                \"name\": \"namespace-2\",
                \"creationTimestamp\": \"$hourAgo\"
            }
        },
        {
            \"metadata\": {
                \"name\": \"namespace-3\",
                \"creationTimestamp\": \"$dayAgo\"
            }
        }
    ]"

    filterByCreationOlderThan

    # then we only have namespaces older than our criteria (24 hours)
    assert_equal $(jq length <<< "$new_versions") 1
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-3'
}

@test "[check] filter by olderThan not configured" {
    source_check "stdin-source-empty"

    new_versions="[
        {
            \"metadata\": {
                \"name\": \"namespace-1\",
                \"creationTimestamp\": \"$now\"
            }
        },
        {
            \"metadata\": {
                \"name\": \"namespace-2\",
                \"creationTimestamp\": \"$hourAgo\"
            }
        },
        {
            \"metadata\": {
                \"name\": \"namespace-3\",
                \"creationTimestamp\": \"$dayAgo\"
            }
        }
    ]"

    filterByCreationOlderThan

    # then our 'new_versions' is left unchanged
    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'namespace-3'
}

@test "[check] pare down version info and emit only uid/resourceVersion" {
    source_check

    new_versions='[
        {
            "metadata": {
                "uid": "uid-1",
                "foo": "bar-1",
                "resourceVersion": "resourceVersion-1"
            }
        },
        {
            "metadata": {
                "uid": "uid-2",
                "foo": "bar-2",
                "resourceVersion": "resourceVersion-2"
            }
        },
        {
            "metadata": {
                "uid": "uid-3",
                "foo": "bar-3",
                "resourceVersion": "resourceVersion-3"
            }
        }
    ]'

    pareDownVersionInfo

    # then our 'new_versions' still has all 3 versions
    assert_equal $(jq length <<< "$new_versions") 3

    # with their uid...
    assert_equal "$(jq -r '.[0].uid' <<< "$new_versions")" 'uid-1'
    assert_equal "$(jq -r '.[1].uid' <<< "$new_versions")" 'uid-2'
    assert_equal "$(jq -r '.[2].uid' <<< "$new_versions")" 'uid-3'

    # and their resourceVersion...
    assert_equal "$(jq -r '.[0].resourceVersion' <<< "$new_versions")" 'resourceVersion-1'
    assert_equal "$(jq -r '.[1].resourceVersion' <<< "$new_versions")" 'resourceVersion-2'
    assert_equal "$(jq -r '.[2].resourceVersion' <<< "$new_versions")" 'resourceVersion-3'

    # but nothing else!
    assert_equal "$(jq -r '.[0] | length' <<< "$new_versions")" '2'
    assert_equal "$(jq -r '.[1] | length' <<< "$new_versions")" '2'
    assert_equal "$(jq -r '.[2] | length' <<< "$new_versions")" '2'
}

@test "[check] emits result from first check with only initial version" {
    source_check

    new_versions="[
        {
            \"uid\": \"uid-1\",
            \"resourceVersion\": \"resourceVersion-1\"
        },
        {
            \"uid\": \"uid-2\",
            \"resourceVersion\": \"resourceVersion-2\"
        },
        {
            \"uid\": \"uid-3\",
            \"resourceVersion\": \"resourceVersion-3\"
        }
    ]"

    # check writes to fd 5 for the result, so redirect that to stdout for our test
    output=$(emitResult 5>&1)

    # emits only the first version since this is the "first" check (was called without a previous version)
    assert_equal $(jq length <<< "$output") 1
    assert_equal "$(jq -r '.[0].uid' <<< "$new_versions")" 'uid-1'
    assert_equal "$(jq -r '.[0].resourceVersion' <<< "$new_versions")" 'resourceVersion-1'
}

@test "[check] emits result from subsequent checks with all current versions" {
    source_check

    previous_version="does not matter, only that it is not empty"
    new_versions="[
        {
            \"uid\": \"uid-1\",
            \"resourceVersion\": \"resourceVersion-1\"
        },
        {
            \"uid\": \"uid-2\",
            \"resourceVersion\": \"resourceVersion-2\"
        },
        {
            \"uid\": \"uid-3\",
            \"resourceVersion\": \"resourceVersion-3\"
        }
    ]"

    # check writes to fd 5 for the result, so redirect that to stdout for our test
    output=$(emitResult 5>&1)

    # emits only the first version since this is the "first" check (was called without a previous version)
    assert_equal $(jq length <<< "$output") 3

    assert_equal "$(jq -r '.[0].uid' <<< "$new_versions")" 'uid-1'
    assert_equal "$(jq -r '.[0].resourceVersion' <<< "$new_versions")" 'resourceVersion-1'

    assert_equal "$(jq -r '.[1].uid' <<< "$new_versions")" 'uid-2'
    assert_equal "$(jq -r '.[1].resourceVersion' <<< "$new_versions")" 'resourceVersion-2'

    assert_equal "$(jq -r '.[2].uid' <<< "$new_versions")" 'uid-3'
    assert_equal "$(jq -r '.[2].resourceVersion' <<< "$new_versions")" 'resourceVersion-3'
}

@test "[check] e2e initial check" {
    source_check

    output=$(main 5>&1)

    # should emit 1 version
    assert_equal $(jq length <<< "$output") 1
    # with only its 'uid' and 'resourceVersion' attributes
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '2'
    assert_equal "$(jq -r '.[0].uid' <<< "$output")" 'cee83946-92c3-11e9-a784-3497f601230d'
    assert_equal "$(jq -r '.[0].resourceVersion' <<< "$output")" '6988465'
}

@test "[check] e2e subsequent check" {
    source_check "stdin-source-with-version"

    output=$(main 5>&1)

    # should emit all 3 versions
    assert_equal $(jq length <<< "$output") 3
    # with only its 'uid' and 'resourceVersion' attributes
    assert_equal "$(jq -r '.[0] | length' <<< "$output")" '2'
    assert_equal "$(jq -r '.[0].uid' <<< "$output")" 'cee83946-92c3-11e9-a784-3497f601230d'
    assert_equal "$(jq -r '.[0].resourceVersion' <<< "$output")" '6988465'
    assert_equal "$(jq -r '.[1] | length' <<< "$output")" '2'
    assert_equal "$(jq -r '.[1].uid' <<< "$output")" '8fca7c5f-c513-11e9-a16f-1831bfd00891'
    assert_equal "$(jq -r '.[1].resourceVersion' <<< "$output")" '22577654'
    assert_equal "$(jq -r '.[2] | length' <<< "$output")" '2'
    assert_equal "$(jq -r '.[2].uid' <<< "$output")" 'd0abb6fa-d17a-4e05-8d71-d5c3810945ad'
    assert_equal "$(jq -r '.[2].resourceVersion' <<< "$output")" '56109593'
}

@test "[check] GH-2 queries namespace specified in source config 'namespace'" {
    expected_namespace_arg="-n my-namespace"
    source_check "stdin-source-namespace"

    queryForVersions

    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'namespace-other'
}

@test "[check] GH-9 filter by phases matches exact strings" {
    source_check "stdin-source-filter-phases"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            },
            "status": {
                "phase": "Active"
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-3"
            },
            "status": {
                "phase": "Foo"
            }
        }
    ]'

    filterByPhases

    # then only names exactly matching remain
    assert_equal $(jq length <<< "$new_versions") 2
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-3'
}

@test "[check] GH-9 filter by phases not configured" {
    source_check "stdin-source-empty"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            },
            "status": {
                "phase": "Active"
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-3"
            },
            "status": {
                "phase": "Foo"
            }
        }
    ]'

    filterByPhases

    # then only names exactly matching remain
    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'namespace-3'
}

@test "[check] GH-9 filter by phases handles duplicates" {
    source_check "stdin-source-filter-phases-duplicates"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            },
            "status": {
                "phase": "Active"
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-3"
            },
            "status": {
                "phase": "Foo"
            }
        }
    ]'

    filterByPhases

    # then only names exactly matching remain
    assert_equal $(jq length <<< "$new_versions") 2
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-3'
}

@test "[check] filter by jq matches queries" {
    source_check "stdin-source-filter-jq"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1"
            },
            "spec": {
                "somekey": "somevalue",
                "number1": 4,
                "number2": 4
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            }
        },
        {
            "metadata": {
                "name": "namespace-3"
            },
            "status": {
                "anynumber": 5
            }
        },
        {
            "metadata": {
                "name": "namespace-4"
            },
            "status": {
                "anynumber": 2
            }
        },
        {
            "metadata": {
                "name": "namespace-5"
            },
            "status": {
                "number1": 666
            }
        },
        {
            "metadata": {
                "name": "namespace-6"
            }
        }
    ]'

    filterByJQExpressions

    # then only names exactly matching remain
    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal $(jq -r '[.[] | if .metadata.name == "namespace-2" then .metadata.name else "" end ] | join("")' <<< "$new_versions") 'namespace-2'
    assert_equal $(jq -r '[.[] | if .metadata.name == "namespace-1" then .metadata.name else "" end ] | join("")' <<< "$new_versions") 'namespace-1'
    assert_equal $(jq -r '[.[] | if .metadata.name == "namespace-3" then .metadata.name else "" end ] | join("")' <<< "$new_versions") 'namespace-3'
}

@test "[check] filter by jq expressions handles empty payload" {
    source_check "stdin-source-empty.json"

    new_versions=''

    filterByJQExpressions
    assert_equal "$new_versions" ""

    # again, but with filter present and empty - that is not "jq" key
    echo '{ "source": {"filter": {}} }' > $payload
    filterByJQExpressions
    assert_equal "$new_versions" ""
}

@test "[check] filter by jq expressions with operator" {
    source_check "stdin-source-filter-jq-operator"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1",
                "number": 333
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            },
            "spec": {
                "number": 333
            }
        },
        {
            "metadata": {
                "name": "namespace-3",
                "number": 666
            },
            "spec": {
                "number": 666
            }
        },
        {
            "metadata": {
                "name": "namespace-4",
                "number": 777
            },
            "spec": {
                "number": 777
            }
        }
    ]'

    filterByJQExpressions

    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-3'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-4'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'null'
}

@test "[check] filter by jq expressions with transformation" {
    source_check "stdin-source-filter-jq-transformation"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1",
                "number": 111
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            },
            "spec": {
                "number": 222
            }
        },
        {
            "metadata": {
                "name": "namespace-3",
                "number": 333
            },
            "spec": {
                "number": 333
            }
        },
        {
            "metadata": {
                "name": "namespace-4",
                "number": 444
            },
            "spec": {
                "number": 444
            }
        }
    ]'

    filterByJQExpressions

    assert_equal "$(jq -r '.[0].metadata.uid' <<< "$new_versions")" 'uuuu-iiii-dddd'
    assert_equal "$(jq -r '.[0].metadata.resourceVersion' <<< "$new_versions")" '12345'
    assert_equal "$(jq -r '.[0].metadata.sum' <<< "$new_versions")" '777'
}

@test "[check] filter by jq expressions with transformation (no parens)" {
    source_check "stdin-source-filter-jq-transformation-no-parens"

    new_versions='[
        {
            "metadata": {
                "name": "namespace-1",
                "number": 111
            }
        },
        {
            "metadata": {
                "name": "namespace-2"
            },
            "spec": {
                "number": 222
            }
        },
        {
            "metadata": {
                "name": "namespace-3",
                "number": 333
            },
            "spec": {
                "number": 333
            }
        },
        {
            "metadata": {
                "name": "namespace-4",
                "number": 444
            },
            "spec": {
                "number": 444
            }
        }
    ]'

    filterByJQExpressions

    assert_equal "$(jq -r '.[0].metadata.uid' <<< "$new_versions")" 'uuuu-iiii-dddd'
    assert_equal "$(jq -r '.[0].metadata.resourceVersion' <<< "$new_versions")" '12345'
    assert_equal "$(jq -r '.[0].metadata.sum' <<< "$new_versions")" '777'
}

@test "[check] GH-12 exits with error if kubectl fails" {
    source_check "stdin-source" "FAIL"

    run queryForVersions
    assert_failure
}

@test "[check] GH-20 uses '--insecure-skip-tls-verify' when 'source.insecure_skip_tls_verify' is 'true'" {
    expected_ca_arg="--insecure-skip-tls-verify"
    source_check "stdin-source-insecure-skip-tls-verify-true"

    queryForVersions

    assert_equal $(jq length <<< "$new_versions") 3
    assert_equal "$(jq -r '.[0].metadata.name' <<< "$new_versions")" 'namespace-1'
    assert_equal "$(jq -r '.[1].metadata.name' <<< "$new_versions")" 'namespace-2'
    assert_equal "$(jq -r '.[2].metadata.name' <<< "$new_versions")" 'namespace-other'
}
