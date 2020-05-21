# k8s-resource

A Concourse [resource](https://resource-types.concourse-ci.org/) for retrieving resources from a kubernetes cluster.

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
* `filter`: _Optional_. Can contain any/all of the following criteria:
  * `name`: Matches against the `metadata.name` of the resource.  Supports both literal (`my-ns-1`) and regular expressions (`"my-ns-[0-9]*$"`).
  * `olderThan`: Time in seconds that the `metadata.creationTimestamp` must be older than.

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

### `out`: no-op (currently)

## Example

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
  - name: view-expired
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
  