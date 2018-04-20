load("//rules/common:private/utils.bzl", "write_launcher")
load(":private/library.bzl", "runner_common")
load(":private/binary.bzl", "annex_scala_binary_private_attributes")

annex_scala_test_private_attributes = annex_scala_binary_private_attributes

def annex_scala_test_implementation(ctx):
    res = runner_common(ctx)

    result = [res.java_info, res.scala_info]
    runner = ctx.actions.declare_file("test")

    files = ctx.files._java + [res.analysis]

    frameworks_file = ctx.actions.declare_file("test_frameworks.txt")
    ctx.actions.write(frameworks_file, "\n".join(ctx.attr.frameworks))
    files.append(frameworks_file)

    classpath_file = ctx.actions.declare_file("test_classpath.txt")
    ctx.actions.write(classpath_file, "\n".join([jar.short_path for jar in res.java_info.transitive_runtime_jars]))
    files.append(classpath_file)

    test_jars = res.java_info.transitive_runtime_deps
    runner_jars = ctx.attr.runner[JavaInfo].transitive_runtime_deps

    write_launcher(
        ctx,
        runner,
        runner_jars,
        "annex.TestRunner",
        [
            "-Dbazel.runPath=$RUNPATH",
            "-DscalaAnnex.analysis={}".format(res.analysis.short_path),
            "-DscalaAnnex.test.frameworks={}".format(frameworks_file.short_path),
            "-DscalaAnnex.test.classpath={}".format(classpath_file.short_path),
        ],
    )

    test_info = DefaultInfo(
        executable = runner,
        runfiles = ctx.runfiles(collect_default = True, collect_data = True, files = files, transitive_files = depset(direct = runner_jars.to_list(), transitive = [test_jars])),
    )
    result.append(test_info)
    return result
