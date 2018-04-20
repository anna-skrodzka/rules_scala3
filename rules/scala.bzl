load("//rules/scala:private/toolchain.bzl", "annex_scala_runner_toolchain_implementation")
load("//rules/scala:private/basic_library.bzl", "basic_scala_library_implementation", "basic_scala_library_private_attributes")
load("//rules/scala:private/import.bzl", "scala_import_implementation")
load("//rules/scala:private/binary.bzl", "annex_scala_binary_implementation", "annex_scala_binary_private_attributes")
load("//rules/scala:private/library.bzl", "annex_scala_library_implementation", "annex_scala_library_private_attributes")
load("//rules/scala:private/provider.bzl", "annex_configure_basic_scala_implementation", "annex_configure_scala_implementation")
load("//rules/scala:private/test.bzl", "annex_scala_test_implementation", "annex_scala_test_private_attributes")
load("@rules_scala_annex//rules/scala:provider.bzl", "BasicScalaConfiguration", "ScalaConfiguration")

"""
Configures which Scala runner to use
"""
annex_scala_runner_toolchain = rule(
    annex_scala_runner_toolchain_implementation,
    attrs = {
        "runner": attr.label(
            allow_files = True,
            executable = True,
            cfg = "host",
        ),
    },
)

###

basic_scala_library = rule(
    implementation = basic_scala_library_implementation,
    attrs = basic_scala_library_private_attributes + {
        "srcs": attr.label_list(allow_files = [".scala", ".java", ".srcjar"]),
        "deps": attr.label_list(),
        "scala": attr.label(
            default = "@scala//:scala_basic",
            mandatory = True,
            providers = [BasicScalaConfiguration],
        ),
    },
    fragments = ["java"],
)

def basic_scala_binary(
        name,
        srcs,
        deps,
        main_class,
        scala,
        visibility):
    basic_scala_library(
        name = "%s-lib" % name,
        srcs = srcs,
        deps = deps,
        scala = scala,
    )

    # being lazy: use java_binary to write a launcher
    # instead of figuring out how to write it directly

    native.java_binary(
        name = name,
        visibility = visibility,
        runtime_deps = [":%s-lib" % name],
        main_class = main_class,
    )

_annex_configure_basic_scala = rule(
    implementation = annex_configure_basic_scala_implementation,
    attrs = {
        "compiler_classpath": attr.label_list(mandatory = True, providers = [JavaInfo]),
        "runtime_classpath": attr.label_list(mandatory = True, providers = [JavaInfo]),
        "version": attr.string(mandatory = True),
    },
)

"""
Configures a Scala provider for use by library, binary, and test rules.

Args:

  version:
    The full Scala version string, such as "2.12.5"

  runtime_classpath:
    The full Scala runtime classpath for use in library, binary, and test rules;
    i.e. scala-library + scala-reflect + ...

  compiler_classpath:
    The full Scala compiler classpath required to invoke the Scala compiler;
    i.e.. scala-compiler + scala-library +  scala-reflect + ...

  compiler_bridge:
    The Zinc compiler bridge with attached sources.

"""
_annex_configure_scala = rule(
    implementation = annex_configure_scala_implementation,
    attrs = {
        "version": attr.string(mandatory = True),
        "runtime_classpath": attr.label_list(mandatory = True, providers = [JavaInfo]),
        "compiler_classpath": attr.label_list(mandatory = True, providers = [JavaInfo]),
        "compiler_bridge": attr.label(allow_single_file = True, mandatory = True),
    },
)

def annex_configure_scala(name, compiler_bridge, compiler_bridge_classpath, compiler_classpath, **kwargs):
    _annex_configure_basic_scala(name = "{}_basic".format(name), compiler_classpath = compiler_classpath, **kwargs)

    basic_scala_library(
        name = "{}_compiler_bridge".format(name),
        deps = compiler_classpath + compiler_bridge_classpath,
        scala = ":{}_basic".format(name),
        srcs = [compiler_bridge],
    )

    _annex_configure_scala(name = name, compiler_bridge = ":{}_compiler_bridge".format(name), compiler_classpath = compiler_classpath, **kwargs)

"""
Compiles and links Scala/Java sources into a .jar file.

Args:

  srcs:
    The list of source files that are processed to create the target.

  deps:
    The list of libraries to link into this library. Deps can include
    standard Java libraries as well as cross compiled Scala libraries.

  scala:
    ScalaConfiguration(s) to use for compiling sources.

"""
annex_scala_library = rule(
    implementation = annex_scala_library_implementation,
    attrs = annex_scala_library_private_attributes + {
        "srcs": attr.label_list(allow_files = [".scala", ".java"]),
        "deps": attr.label_list(),
        "exports": attr.label_list(),
        "scala": attr.label(
            default = "@scala",
            mandatory = True,
            providers = [ScalaConfiguration],
        ),
        "plugins": attr.label_list(),
        "use_ijar": attr.bool(default = True),
    },
    toolchains = ["@rules_scala_annex//rules/scala:runner_toolchain_type"],
    outputs = {},
)

annex_scala_binary = rule(
    implementation = annex_scala_binary_implementation,
    attrs = annex_scala_binary_private_attributes + {
        "srcs": attr.label_list(allow_files = [".scala", ".java"]),
        "deps": attr.label_list(),
        "exports": attr.label_list(),
        "main_class": attr.string(),
        "scala": attr.label(
            default = "@scala",
            mandatory = True,
            providers = [ScalaConfiguration],
        ),
        "plugins": attr.label_list(),
        "use_ijar": attr.bool(default = True),
    },
    toolchains = ["@rules_scala_annex//rules/scala:runner_toolchain_type"],
    executable = True,
    outputs = {},
)

annex_scala_test = rule(
    implementation = annex_scala_test_implementation,
    attrs = annex_scala_test_private_attributes + {
        "srcs": attr.label_list(allow_files = [".scala", ".java"]),
        "deps": attr.label_list(),
        "exports": attr.label_list(),
        "scala": attr.label(
            default = "@scala",
            mandatory = True,
            providers = [ScalaConfiguration],
        ),
        "plugins": attr.label_list(),
        "use_ijar": attr.bool(default = True),
        "frameworks": attr.string_list(
            default = [
                "org.scalatest.tools.Framework",
                "org.scalacheck.ScalaCheckFramework",
                "org.specs2.runner.Specs2Framework",
                "minitest.runner.Framework",
                "utest.runner.Framework",
            ],
        ),
        "runner": attr.label(default = "@rules_scala_annex//rules/scala:test"),
    },
    toolchains = ["@rules_scala_annex//rules/scala:runner_toolchain_type"],
    test = True,
    executable = True,
    outputs = {},
)

"""
scala_import for use with bazel-deps
"""
scala_import = rule(
    implementation = scala_import_implementation,
    attrs = {
        "jars": attr.label_list(allow_files = True),  #current hidden assumption is that these point to full, not ijar'd jars
        "srcjar": attr.label(allow_single_file = True),
        "deps": attr.label_list(),
        "runtime_deps": attr.label_list(),
        "exports": attr.label_list(),
    },
)