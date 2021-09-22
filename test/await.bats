#!/usr/bin/env bats

load '/opt/bats/addons/bats-support/load.bash'
load '/opt/bats/addons/bats-assert/load.bash'
load '/opt/bats/addons/bats-mock/stub.bash'

source_await() {
    stdin_payload=${1:-"stdin-source"}

    # source the common script
    source "$SUT_ASSETS_DIR/common" <<< "$(<$BATS_TEST_DIRNAME/fixtures/$stdin_payload.json)"

    # stub the log function
    log() { echo "$@"; } # use this during development to see log output
#    log() { :; }
    export -f log

    # source the sut
    source "$SUT_ASSETS_DIR/await"
}

@test "[await] GH-19 await is enabled if timeout is configured" {
    source_await "stdin-params-await"

    # stub 'awaitLoop' to expect to be called with our timeout
    invoked=false
    awaitLoop() { invoked=true; }
    export -f awaitLoop

    await

    # verify 'awaitLoop' was called
    assert_equal $invoked true
}

@test "[await] GH-19 await is NOT enabled if timeout is <= 0" {
    source_await "stdin-params-await-disabled"

    # stub 'awaitLoop' to expect to be called with our timeout
    invoked=false
    awaitLoop() { invoked=true; }
    export -f awaitLoop

    await

    # verify 'awaitLoop' was called
    assert_equal $invoked false
}

@test "[await] GH-19 getAwaitConditions() returns the explicitly configured conditions" {
    source_await "stdin-params-await"

    run getAwaitConditions

    assert_line --partial '"select(.kind == \"Pod\") | .status.containerStatuses[] | .ready"'
    assert_line --partial '"select(.kind == \"Deployment\") | select(.spec.replicas > 0) | .status.readyReplicas > 0"'
}

@test "[await] GH-19 getAwaitConditions() returns default conditions for the default 'resource_types'" {
    source_await "stdin-params-await-no-conditions"

    run getAwaitConditions

    # 'pods' are the default resource_types
    assert_line --partial '"select(.kind == \"Pod\") | .status.containerStatuses[] | .ready"'
}

@test "[await] GH-19 getAwaitConditions() returns default conditions for 'pod' 'resource_types'" {
    source_await "stdin-params-await-no-conditions"

    for type in "pod" "pods" "po"; do
        source_resource_types=$type

        run getAwaitConditions

        assert_line --partial '"select(.kind == \"Pod\") | .status.containerStatuses[] | .ready"'
    done
}

@test "[await] GH-19 getAwaitConditions() returns default conditions for 'deployment' 'resource_types'" {
    source_await "stdin-params-await-no-conditions"

    for type in "deployment" "deployments" "deploy"; do
        source_resource_types=$type

        run getAwaitConditions

        assert_line --partial '"select(.kind == \"Deployment\") | select(.spec.replicas > 0) | .spec.replicas == .status.readyReplicas"'
    done
}

@test "[await] GH-19 getAwaitConditions() returns default conditions for 'replicaset' 'resource_types'" {
    source_await "stdin-params-await-no-conditions"

    for type in "replicaset" "replicasets" "rs"; do
        source_resource_types=$type

        run getAwaitConditions

        assert_line --partial '"select(.kind == \"ReplicaSet\") | select(.spec.replicas > 0) | .spec.replicas == .status.readyReplicas"'
    done
}

@test "[await] GH-19 getAwaitConditions() returns default conditions for 'statefulset' 'resource_types'" {
    source_await "stdin-params-await-no-conditions"

    for type in "statefulset" "statefulsets" "sts"; do
        source_resource_types=$type

        run getAwaitConditions

        assert_line --partial '"select(.kind == \"StatefulSet\") | select(.spec.replicas > 0) | .spec.replicas == .status.readyReplicas"'
    done
}

@test "[await] GH-19 getAwaitConditions() returns combined default conditions for 'resource_types'" {
    source_await "stdin-params-await-no-conditions"

    source_resource_types="pod,deployment,rs,sts"

    run getAwaitConditions

    assert_line --partial '"select(.kind == \"Pod\") | .status.containerStatuses[] | .ready"'
    assert_line --partial '"select(.kind == \"Deployment\") | select(.spec.replicas > 0) | .spec.replicas == .status.readyReplicas"'
    assert_line --partial '"select(.kind == \"ReplicaSet\") | select(.spec.replicas > 0) | .spec.replicas == .status.readyReplicas"'
    assert_line --partial '"select(.kind == \"StatefulSet\") | select(.spec.replicas > 0) | .spec.replicas == .status.readyReplicas"'
}

@test "[await] GH-19 checkAwaitConditions() succeeds when all conditions are met" {
    source_await "stdin-params-await"

    # stub 'queryForVersions' to do nothing (we'll set 'new_versions' ourselves)
    stub queryForVersions

    # set the 'new_versions' variable with some mock data that would have been returned from our kubectl query
    new_versions='[
      {
        "kind": "Pod",
        "status": {
          "containerStatuses": [
            {
              "ready": true
            }
          ]
        }
      },
      {
        "kind": "Pod",
        "status": {
          "containerStatuses": [
            {
              "ready": true
            }
          ]
        }
      },
      {
        "kind": "Deployment",
        "spec": {
          "replicas": 2
        },
        "status": {
          "readyReplicas": 1
        }
      }
    ]'

    # invoke the sut
    run checkAwaitConditions

    # conditions should succeed
    assert_success
}

@test "[await] GH-19 checkAwaitConditions() fails when just one condition is not met" {
    source_await "stdin-params-await"

    # stub 'queryForVersions' to do nothing (we'll set 'new_versions' ourselves)
    stub queryForVersions

    # set the 'new_versions' variable with some mock data that would have been returned from our kubectl query
    new_versions='[
      {
        "kind": "Pod",
        "status": {
          "containerStatuses": [
            {
              "ready": true
            }
          ]
        }
      },
      {
        "kind": "Pod",
        "status": {
          "containerStatuses": [
            {
              "ready": false
            }
          ]
        }
      },
      {
        "kind": "Deployment",
        "spec": {
          "replicas": 2
        },
        "status": {
          "readyReplicas": 1
        }
      }
    ]'

    # invoke the sut
    run checkAwaitConditions

    # conditions should succeed
    assert_failure
}
