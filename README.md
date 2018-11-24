# bazel_pkg_config

Bazel rules for pkg-config tools.

## Usage

Add the following in your `WORKSPACE`:

```bzl
http_archive(
    name = "bazel_pkg_config",
    strip_prefix = "bazel_pkg_config-master",
    urls = ["https://github.com/cherrry/bazel_pkg_config/archive/master.zip"],
)

load("@bazel_pkg_config//:pkg_config.bzl", "pkg_config")

pkg_config(
    name = "library_to_load",
    # See pkg_config.bzl for more available options.
)
```

In your code:

```cc
#include "library_to_load/header.h"

// ...
```

In corresponding `BUILD` file:

```bzl
cc_library(
    name = "my_lib",
    deps = [
        "@library_to_load//:lib",
    ],
)
```
