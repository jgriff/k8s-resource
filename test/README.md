# Testing

The [`check`](../scripts/check), [`in`](../scripts/in) and [`out`](../scripts/out) scripts are all written in bash, and
tested with [bats](https://github.com/bats-core/bats-core).  The `.bats` test scripts are all located in this directory.

## Running the Tests

The tests are designed to run in a Docker container, providing a consistent environment with `bats` (and some add-ons)
pre-installed.  This means **you do not need to have bats installed for yourself to run the tests**.

The [`run.sh`](run.sh) script handles everything for you.

```bash
./run.sh 
```

This will:

* [x] Build the resource image under test (this [`Dockerfile`](../Dockerfile)).
* [x] Build a test image on top of the resource image with `bats` to run the tests (this [`Dockerfile`](Dockerfile)).
* [x] Run all of the tests
* [x] Clean up by deleting the images
* [x] Report the test results (you will also see the bats test output in your terminal).

The `run.sh` script also supports options for running a subset of the tests, and an interactive shell for adhoc manual
testing (ideal for local development iterations).

### Running Selective Tests

You can select which test(s) to run by passing them as args to `run.sh`.

For example, to run **only** the `check.bats` tests:

```bash
./run.sh check
```

You can specify multiple tests.  To run both `check.bats` and `in.bats`:

```bash
./run.sh check in
```

By default, all tests are run.  You can also explicitly run all tests with the `all` argument:

```bash
./run.sh all
```

### Test Shell

Instead of running the tests and exiting, you can open an interactive shell into the test container and run
the tests yourself.

```bash
./run.sh shell
```



This will build the resource and test image as usual, but instead of running the tests and exiting it will drop you into
a shell session inside the test container mounted with your local working directory (your project root will be mounted as `/code`
in the test container).

This lets you make changes from your local machine, and run the tests (with your changes) from the active shell.
A much faster feedback loop for local development.

* Run all tests:
    ```bash 
    root@77b54bdc2ec4:/code# bats test
    ```
* Run just the `check.bats` tests:
    ```bash 
    root@77b54bdc2ec4:/code# bats test/check.bats
    ```  

**Note:** Here you are invoking `bats` directly.  The basic syntax is:

```
bats {dir|file}
```

* Specifying a directory will run _all_ of the `.bats` tests in that directory.
* Specifying a single `.bats` file runs only the tests in that file.
* See the `bats` [documentation](https://github.com/bats-core/bats-core) for details.

Exit the shell in normal fashion with the `exit` command. 

### Testing a Pre-Built Image

If you already have an image you want tested, you can specify it with the `-i` option.

```bash 
./run.sh -i my-k8s-resource:my-tag
```

This will cause the `run.sh` script to skip building the image under test, and instead use the one you provide.  This can
be useful for smoke testing candidate releases as part of a pipeline.

### Help

For all available options, see the help (`-h`).

```bash
./run.sh -h
``` 