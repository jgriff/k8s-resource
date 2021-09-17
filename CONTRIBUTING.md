# Contributing

## Issues and Pull Requests

For small changes or quick fixes, a simple [pull request](https://github.com/jgriff/k8s-resource/pulls) is sufficient.

For non-trivial changes or bug reports, please file an [issue](https://github.com/jgriff/k8s-resource/issues) _before_ submitting a pull request.

For substantial changes, or to discuss a feature request, prefix your issue with "RFC:" (Request For Comment) and tag it with the label [`rfc`](https://github.com/jgriff/k8s-resource/labels/rfc).  

## Development

Build local `dev` images of all `kubectl` variants (`dev-kubectl-<each-k8s-version>`):
```shell
make build
```

Build a single, specific `kubectl` variant (`dev-kubectl-1.22`):
```shell
make build_1.22
```

Run unit tests across all `dev` image variants:
```shell
make test
```

Test a single, specific variant:
```shell
make test_1.22
```

Combine targets in single invocation:
```shell
make build_1.22 test_1.22
```

## Releases

Image releases to Docker Hub are performed by GitHub Actions whenever a new `v*` tag is created.  The leading `v` will be stripped when creating the Docker tag.

Each release ships a set of image variants for a range of `kubectl` versions following the pattern `<tag>-kubectl-<kubectl-version>`, where `<kubectl-version>` will be the `major.minor.patch` that we are shipping along with `major.minor` (tag moves with latest patch) 

For example, tagging the repo with `v1.2.3` will build and publish:

* `1.2.3-kubectl-<major>.<minor>.<patch>` 
* `1.2.3-kubectl-<major>.<minor>`

See the [`Makefile`](Makefile) for list of all current `kubectl` versions we are supporting.

The `latest` tag always represents the latest state of the `master` branch.
