def _success(value):
    return struct(error = None, value = value)

def _error(message):
    return struct(error = message, value = None)

def _split(result, delimeter = " "):
    if result.error != None:
        return result
    return _success([arg for arg in result.value.strip().split(" ") if arg])

def _find_binary(ctx, binary_name):
    binary = ctx.which(binary_name)
    if binary == None:
        return _error("Unable to find binary: {}".format(binary_name))
    return _success(binary)

def _execute(ctx, binary, args):
    result = ctx.execute([binary] + args)
    if result.return_code != 0:
        return _error("Failed execute {} {}", binary, args)
    return _success(result.stdout)

def _pkg_config(ctx, pkg_config, pkg_name, args):
    return _execute(ctx, pkg_config, [pkg_name] + args)

def _extract_prefix(flags, prefix, strip = True):
    stripped, remain = [], []
    for arg in flags:
        if arg.startswith(prefix):
            if strip:
                stripped += [arg[len(prefix):]]
            else:
                stripped += [arg]
        else:
            remain += [arg]
    return stripped, remain

def _includes(ctx, pkg_config, pkg_name):
    includes = _split(_pkg_config(ctx, pkg_config, pkg_name, ["--cflags-only-I"]))
    if includes.error != None:
        return includes
    includes, unused = _extract_prefix(includes.value, "-I", strip = True)
    return _success(includes)

def _copts(ctx, pkg_config, pkg_name):
    return _split(_pkg_config(ctx, pkg_config, pkg_name, [
        "--cflags-only-other",
        "--libs-only-L",
        "--libs-only-l",
        "--static",
    ]))

def _linkopts(ctx, pkg_config, pkg_name):
    return _split(_pkg_config(ctx, pkg_config, pkg_name, [
        "--libs-only-other",
        "--static",
    ]))

def _symlinks(ctx, basename, srcpaths):
    result = []
    root = ctx.path("")
    base = root.get_child(basename)
    rootlen = len(str(base)) - len(basename)
    for src in [ctx.path(p) for p in srcpaths]:
        dest = base.get_child(src.basename)
        ctx.symlink(src, dest)
        result += [str(dest)[rootlen:]]
    return result

def _deps(ctx, pkg_config, pkg_name):
    deps = _split(_pkg_config(ctx, pkg_config, pkg_name, [
        "--libs-only-L",
        "--static",
    ]))
    if deps.error != None:
        return deps
    deps, unused = _extract_prefix(deps.value, "-L", strip = True)
    result = []
    for dep in {dep: True for dep in deps}.keys():
        base = "deps_" + "_".join(dep.split("/"))
        result += _symlinks(ctx, base, [dep])
    return _success(result)

def _fmt_array(array):
    return ",".join(['"{}"'.format(a) for a in array])

def _fmt_glob(array):
    return _fmt_array(["{}/**/*.h".format(a) for a in array])

def _pkg_config_impl(ctx):
    pkg_name = ctx.attr.pkg_name
    if pkg_name == "":
        pkg_name = ctx.attr.name

    pkg_config = _find_binary(ctx, "pkg-config")
    if pkg_config.error != None:
        return pkg_config
    pkg_config = pkg_config.value

    includes = _includes(ctx, pkg_config, pkg_name)
    if includes.error != None:
        return includes
    includes = includes.value
    includes = _symlinks(ctx, "includes", includes)
    strip_prefix = "includes"
    if len(includes) == 1:
        strip_prefix = includes[0]

    copts = _copts(ctx, pkg_config, pkg_name)
    if copts.error != None:
        return copts

    copts = copts.value

    linkopts = _linkopts(ctx, pkg_config, pkg_name)
    if linkopts.error != None:
        return linkopts
    linkopts = linkopts.value

    deps = _deps(ctx, pkg_config, pkg_name)
    if deps.error != None:
        return deps
    deps = deps.value

    build = ctx.template("BUILD", Label("//:BUILD.tmpl"), substitutions = {
        "%{name}": ctx.attr.name,
        "%{hdrs}": _fmt_glob(includes),
        "%{includes}": _fmt_array(includes),
        "%{copts}": _fmt_array(copts),
        "%{deps}": _fmt_array(deps),
        "%{linkopts}": _fmt_array(linkopts),
        "%{strip_prefix}": strip_prefix,
    }, executable = False)

pkg_config = repository_rule(
    attrs = {
        "pkg_name": attr.string(),
    },
    local = True,
    implementation = _pkg_config_impl,
)
