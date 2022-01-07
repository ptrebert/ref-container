
include: "workflow/rules/functions.smk"
include: "workflow/rules/global_env.smk"
include: "workflow/rules/utils.smk"
include: "workflow/rules/loading.smk"
include: "workflow/rules/packaging.smk"


rule build_basic_reference_container:
    input:
        collect_base_images,
        collect_reference_container_build_targets
