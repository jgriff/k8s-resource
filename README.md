# k8s-resource

![pulls](https://img.shields.io/docker/pulls/jgriff/k8s-resource)

A Concourse [resource](https://resource-types.concourse-ci.org/) for retrieving resources from a kubernetes cluster, along
with a general purpose `put` for running any `kubectl` command.

## Source Configuration

* `url`: _Required_. The kubernetes server URL, e.g. `"https://my-cluster:8443"`.
* `token`: _Required_.  Authorization token for the api server.
* `certificate_authority`: _Required_. The certificate authority for the api server.
  ```yaml
    certificate_authority: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
  ```

* `resource_types`: _Optional_. Comma separated list of resource type(s) to retrieve (defaults to just `pod`).
  ```yaml
    resource_types: deployment,service,pod
  ```
* `namespace`: _Optional_. The namespace to restrict the query to. \
  For `check`/`get`, this will default to all namespaces (`--all-namespaces`). \
  For `put`, this will default to remaining unset (not specified), but can be overridden with a step param (see [below](#out-execute-a-kubectl-command)).
* `filter`: _Optional_. Can contain any/all of the following criteria:
  * `name`: Matches against the `metadata.name` of the resource.  Supports both literal (`my-ns-1`) and regular expressions (`"my-ns-[0-9]*$"`).
    ```yaml
    source:
      filter:
        name: "my-ns-[0-9]*$"
    ```
  * `olderThan`: Time in seconds that the `metadata.creationTimestamp` must be older than (ex: `86400` for 24hrs).
    ```yaml
    source:
      filter:
        olderThan: 86400
    ```
  * `phases`: List of `status.phase` value(s) the resource must match at least one of.  This varies depending on the resource.
    For example, a [pod's status](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase) can be
    one of `Pending`, `Running`, `Succeeded`, `Failed` or `Unknown`.  To retrieve only `Failed` or `Unknown` pods:
    ```yaml
    source:
      filter:
        phases: 
          - Failed
          - Unknown
    ```
* `sensitive`: _Optional._  If `true`, the resource content will be considered sensitive and not show up in the logs or Concourse UI.  Can be overridden as a param to each `get` step. Default is `false`.
## Behavior

### `check`: Check for new k8s resource(s)

The current list of `resource_types` resources are fetched from the cluster, and filtered against any `filter` criteria configured.
Each matching resource is emitted as a separate version, uniquely identified by its `uid`/`resourceVersion` pair.

New versions will be triggered by encountering any of:

* new `uid` not seen before
* new `resourceVersion` for a `uid` (that was previously seen at a different `resourceVersion`)

**NOTE:**  Due to the way Concourse treats the versions from the first `check`, this resource will emit _only_ a
single initial resource version (or zero if none match).  It will be the first resource in the list returned from the query.
All subsequent `check` invocations after that will always emit the full batch of resources as individual versions.
This is done to give pipelines the opportunity to run across each k8s resource.  Otherwise, if all versions were emitted
from the first initial `check`, Concourse would only trigger on the last version in the list.


### `in`: Retrieve the k8s resource

Retrieve the single resource as JSON (`-o json`) and writes it to a file `resource.json`.
```
{
  "apiVersion": "v1",
  "kind": "...",
  "metadata": {...},
  ...
}
```

#### Parameters

* `sensitive`: _Optional._  Overrides the source configuration's value for this particular `get`.

### `out`: Execute `kubectl` commands

General purpose execution of `kubectl` with args provided as a param to `put`.

Additional parameters exist for more specific uses of kubectl functionality. Choose what fits the task best.

**Note:** at least one parameter should be given, otherwise the put step does nothing.

#### Parameters

* `kubectl`: _Optional._ The args to pass directly to `kubectl`. \
    **Note:** The `--server`, `--token`, `--certificate-authority` and `--namespace` will all be implicitly included in
    the command based on the `source` configuration.
* `namespace`: _Optional._  Overrides the source configuration's value for this particular `put` step.
* `set_images`: _Optional._ Changes the container image of one (or more) pod template(s) at runtime. This feature is a bulk operation for doing `kubectl set image ...` on many objects. Example:
  ```yaml
  jobs:
    - name: set-image-job
      plan:
        - put: my-k8s-resource
          params:
            set_images:
              - controller: Deployment/my-database
                container: mysql
                image: docker.io/mysql:5.7
  ```
  This will expect a `Deployment` object named `my-database` to exist in the namespace configured for `my-k8s-resource`, which is to have container named `mysql`. The image of this container will be changed to `docker.io/mysql:5.7`. Supposed the image was `docker.io/mysql:5.6` before, this will trigger the `Deployment` object to start a rollover to the new version.

  `set_images` actually takes an array of `{controller, container, image}` values for mass-changing objects in one `put` step. See this advanced example below. It employs the [docker-image-resource](https://github.com/concourse/docker-image-resource) and [load_var](https://concourse-ci.org/jobs.html#load-var-step) to feed the SHA hash of each docker image to the `Deployment`:
  ```yaml
  jobs:
    - name: set-sha-job
      plan:
        - get: my-docker-image-A
          params:
            skip_download: true
        - load_var: sha_my-docker-image-A
          file: my-docker-image-A/digest
          reveal: true
        - get: my-docker-image-B
          params:
            skip_download: true
        - load_var: sha_my-docker-image-B
          file: my-docker-image-B/digest
          reveal: true
        - put: my-k8s-resource
          params:
            set_images:
              - controller: Deployment/my-pod
                container: my-app
                image: my.registry.host/my-docker-image-A@((.:sha_my-docker-image-A))
              - controller: Deployment/my-other-pod
                container: my-other-app
                image: my.registry.host/my-docker-image-B@((.:sha_my-docker-image-B))
  ```

## Example

### `get` Resources

```yaml
resource_types:
  - name: k8s-resource
    type: docker-image
    source:
      repository: jgriff/k8s-resource

resources:
  - name: expired-namespace
    type: k8s-resource
    icon: kubernetes
    source:
      url: ((k8s-server))
      token: ((k8s-token))
      certificate_authority: ((k8s-ca))
      resource_types: namespaces
      filter:
        name: "my-ns-[0-9]*$"
        olderThan: 86400

jobs:
  - name: view-expired-namespaces
    plan:
      - get: expired-namespace
        version: every
        trigger: true
      - task: take-a-look
        config:
          platform: linux
          image_resource:
            type: registry-image
            source: { repository: busybox }
          inputs:
            - name: expired-namespace
          run:
            path: cat
            args: ["expired-namespace/resource.json"]
```

The pipeline above checks for kubernetes resources that:

* [x] are `namespaces`.
* [x] are named `my-ns-<number>` (e.g `my-ns-1`, `my-ns-200`, etc).
* [x] have existed for longer than 24 hours (`86400` seconds).

Each k8s resource that matches the above criteria is emitted individually from the `expired-namespace` resource,
and then the `take-a-look` task echoes the contents of the retrieved resource file (for demonstration purposes).

**NOTE:** Be sure to include `version: every` in your `get` step so you get _every_ k8s resource that matches your query.
Otherwise, Concourse will only trigger on the _latest_ resource to be emitted (the last one in the list that comes back from the query).

### `put` Resources

The pipeline below demonstrates using the `put` operation to deploy a resource file `deploy.yaml` from a git repo `my-k8s-repo` (config not shown).

```yaml
resource_types:
  - name: k8s-resource
    type: docker-image
    source:
      repository: jgriff/k8s-resource

resources:
  - name: k8s
    type: k8s-resource
    icon: kubernetes
    source:
      url: ((k8s-server))
      token: ((k8s-token))
      certificate_authority: ((k8s-ca))

jobs:
  - name: deploy-prod
    plan:
      - get: my-k8s-repo
        trigger: true
      - put: k8s
        params:
          kubectl: apply -f my-k8s-repo/deploy.yaml
          namespace: prod
```



### `get` and `put` Resources

The pipeline below demonstrates using both `get` and `put` in the same pipeline.

⚠️ **Warning:** Don't use the same `k8s-resource` instance for **both** `get` and `put` operations!  The `put` step
emits a meaningless version (it's just the `kubectl` command that was executed).  The problem is Concourse will include
that (meaningless) version in the version history for the resource.  It will then be offered to your `get` step which
will be unable to retrieve the nonsensical version and then fail.

So the best way to deal with this is to use one resource instance for the resources you are `get`'ing, and another
instance for general purpose `put`'ing things.

Here's an example that combines the previous 2 examples into a single pipeline that watches for expired namespaces, and
then deletes them.

```yaml
---
k8s-resource-source-config: &k8s-resource-source-config
  url: ((k8s-server))
  token: ((k8s-token))
  certificate_authority: ((k8s-ca))

resource_types:
  - name: k8s-resource
    type: docker-image
    source:
      repository: jgriff/k8s-resource

resources:
  - name: k8s
    type: k8s-resource
    icon: kubernetes
    source:
      << : *k8s-resource-source-config

  - name: expired-namespace
    type: k8s-resource
    icon: kubernetes
    source:
      << : *k8s-resource-source-config
      resource_types: namespaces
      filter:
        name: "my-ns-[0-9]*$"
        olderThan: 86400
        phases: [Active]

jobs:
  - name: delete-expired-namespaces
    plan:
      - get: expired-namespace
        version: every
        trigger: true
      - load_var: expired-namespace-resource
        file:     expired-namespace/resource.json
      - put: k8s
        params:
          kubectl: delete namespace ((.:expired-namespace-resource.metadata.name))
```
