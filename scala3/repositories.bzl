"""Repository rules for defining Scala dependencies and toolchains"""

load(
    "//scala3/private:toolchain_constants.bzl",
    _unmandatory_toolchain_attrs = "UNMANDATORY_TOOLCHAIN_ATTRS",
)

# TODO
#def rules_scala3_dependencies():

#
# Remaining content of the file is only used to support toolchains.
#
GLOBAL_SCALACOPTS = [
    "-deprecation",
    "-unchecked",
    "-feature",
    "-explain",
    "-explain-types",
    "-indent",
    "-new-syntax",
    "-source:future",
    # "-language:strictEquality",
    # "-language:existentials",
    "-Ysafe-init",
    # "-Yexplicit-nulls",
    # "-Xfatal-warnings",
    "-Wconf:any:warning",
    "-Wunused:imports",
    "-Wunused:locals",
    "-Wunused:privates",
    "-Wunused:params",
    "-Wunused:unsafe-warn-patvars",
    "-Wunused:linted",
    "-Wunused:implicits",
]

# buildifier: disable=unnamed-macro
def scala3_register_toolchains(
        default_compiler = "zinc",
        register_default_toolchain = True,
        global_scalacopts = GLOBAL_SCALACOPTS,
        **kwargs):
    """Convenience macro for users which does typical setup.

    It will create a set of external toolchain repositories and register the
    default toolchain.

    Skip this macro and call the `scala3_define_toolchain` macros directly if you
    what to register a custom toolchain.

    Only the default toolchain will be registered. If `default_compiler` is zinc,
    then `scala3_zinc_toolchain` will be registered, otherwise
    `scala3_bootstrap_toolchain`. To use additional toolchains, add the
    `--extra_toolchains='@<toolchain_name>//:toolchain'` option to the bazel
    command.

    List of all repositories with toolchains:
    - scala3_bootstrap_toolchain
    - scala3_zinc_toolchain

    Args:
        default_compiler (str, opt): One of zinc or bootstrap.
        register_default_toolchain (bool, opt): If true, the default toolchain will be registered.
        global_scalacopts (list, opt): Same as `global_scalacopts` in `scala3_toolchain_repository`.
        **kwargs (dict): Default arguments for `scala3_toolchain_repository`.
    """

    if not default_compiler in ["zinc", "bootstrap"]:
        fail("Argument `default_compiler` of `scala3_register_toolchains` must be zinc or bootstrap.")

    toolchains = [
        {
            "name": "scala3_zinc_toolchain",
        },
        {
            "name": "scala3_bootstrap_toolchain",
            "is_zinc": False,
        },
        {
            "name": "scala3_mezel_toolchain",
            "enable_semanticdb": True,
            "enable_diagnostics": True,
            "global_scalacopts": ["-Xfatal-warnings"],
        },
    ]

    kwargs.update(global_scalacopts = global_scalacopts)

    for toolchain in toolchains:
        scala3_toolchain_repository(**(kwargs | toolchain))

    if register_default_toolchain:
        native.register_toolchains(
            "@scala3_{}_toolchain//:toolchain".format(default_compiler),
        )

def _scala3_toolchain_repository_impl(repository_ctx):
    repository_ctx.file("WORKSPACE.bazel", """workspace(name = "{}")""".format(
        repository_ctx.name,
    ))

    # TODO load maven deps, like `rules_scala_toolchain_deps_repositories` does.
    # `repository_ctx.attr.scala_version` should be used to resolve deps and
    # determine the full version
    scala_version = "3.5.1-RC1"
    compiler_bridge = repository_ctx.attr.compiler_bridge or "@scala3_sbt_bridge//jar"

    compiler_classpath = repository_ctx.attr.compiler_classpath or [
        "@scala3_compiler//jar",
        "@scala3_interfaces//jar",
        "@org_scala_sbt_compiler_interface//jar",
        "@scala_asm//jar",
        "@scala_tasty_core_3//jar",
        "@scala3_library//jar",
        "@scala_library_2_13//jar",
    ]

    runtime_classpath = repository_ctx.attr.runtime_classpath or [
        "@scala3_library//jar",
        "@scala_library_2_13//jar",
    ]

    # TODO replace with repository_ctx.template()
    build_content = """#Generated by scala3/repositories.bzl
load("@rules_scala3//scala3:toolchain.bzl", "scala_toolchain")
load("@bazel_skylib//rules:common_settings.bzl", "string_flag")

string_flag(
    name = "deps_direct",
    values = ["off", "warn", "error"],
    build_setting_default = "{deps_direct}",
)

config_setting(name = "deps_direct_off", flag_values = {{ ":deps_direct": "off" }})
config_setting(name = "deps_direct_warn", flag_values = {{ ":deps_direct": "warn" }})
config_setting(name = "deps_direct_error", flag_values = {{ ":deps_direct": "error" }})

string_flag(
    name = "deps_used",
    values = ["off", "warn", "error"],
    build_setting_default = "{deps_used}",
)

config_setting(name = "deps_used_off", flag_values = {{ ":deps_used": "off" }})
config_setting(name = "deps_used_warn", flag_values = {{ ":deps_used": "warn" }})
config_setting(name = "deps_used_error", flag_values = {{ ":deps_used": "error" }})

scala_toolchain(
    name = "toolchain_impl",
    scala_version = "{scala_version}",
    enable_diagnostics = {enable_diagnostics},
    enable_semanticdb = {enable_semanticdb},
    semanticdb_bundle_in_jar = {semanticdb_bundle_in_jar},
    is_zinc = {is_zinc},
    zinc_log_level = "{zinc_log_level}",
    compiler_bridge = "{compiler_bridge}",
    compiler_classpath = {compiler_classpath},
    runtime_classpath = {runtime_classpath},
    global_plugins = {global_plugins},
    global_scalacopts = {global_scalacopts},
    global_jvm_flags = {global_jvm_flags},
    deps_direct = select({{
        ":deps_direct_off": "off",
        ":deps_direct_warn": "warn",
        ":deps_direct_error": "error",
    }}),
    deps_used = select({{
        ":deps_used_off": "off",
        ":deps_used_warn": "warn",
        ":deps_used_error": "error",
    }}),
)

toolchain(
    name = "toolchain",
    toolchain = ":toolchain_impl",
    toolchain_type = "@rules_scala3//scala3:toolchain_type",
)
"""

    repository_ctx.file("BUILD.bazel", build_content.format(
        scala_version = scala_version,
        enable_semanticdb = repository_ctx.attr.enable_semanticdb,
        enable_diagnostics = repository_ctx.attr.enable_diagnostics,
        semanticdb_bundle_in_jar = repository_ctx.attr.semanticdb_bundle_in_jar,
        is_zinc = repository_ctx.attr.is_zinc,
        zinc_log_level = repository_ctx.attr.zinc_log_level,
        compiler_bridge = compiler_bridge,
        compiler_classpath = compiler_classpath,
        runtime_classpath = runtime_classpath,
        global_plugins = repository_ctx.attr.global_plugins,
        global_scalacopts = repository_ctx.attr.global_scalacopts,
        global_jvm_flags = repository_ctx.attr.global_jvm_flags,
        deps_direct = repository_ctx.attr.deps_direct,
        deps_used = repository_ctx.attr.deps_used,
    ))

_scala3_toolchain_repository_attrs = dict(
    scala_version = attr.string(
        default = "latest",
        doc = "The major version of scala, like 3.2 or latest.",
    ),
    **_unmandatory_toolchain_attrs
)

scala3_toolchain_repository = repository_rule(
    doc = """A repository rule for defining a `scala_toolchain`.

    If you want to override `deps_direct` or `deps_used` attribute, there is a
    command line interface for that as well. To do this add the option
    `--@<toolchain_name>//:<attribute_name>=<value>`, this will also work in
    `.bazelrc`. for example:

    ```bash
    bazel build --@scala3_zinc_toolchain//:deps_direct=off
    ```
    """,
    # TODO move to doc when maven deps loading is implemented inside scala3_toolchain_repository
    #Note: `scala3_rules` contains artifacts only for the last released minor version
    #of each major version of Scala 3.
    attrs = _scala3_toolchain_repository_attrs,
    implementation = _scala3_toolchain_repository_impl,
)
