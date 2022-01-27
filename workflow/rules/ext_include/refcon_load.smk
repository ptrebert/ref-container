"""
This module is designed to be included in other
workflows to locate and get reference data
from reference containers.
This module must never have any other dependencies!

Assumptions:
The config of the executing workflow must specify the
variables:
1) reference_container_folder: <path to folder>
2) reference_container_names: <list of container names to use>

"""

import pathlib
import pandas

localrules: refcon_run_dump_manifest, refcon_cache_manifests

REFCON_FOLDER = pathlib.Path(config['reference_container_folder'])
REFCON_NAMES = config['reference_container_names']
# Snakemake interacts with Singularity containers using "exec",
# which leads to a problem for the "refcon_run_get_file":
# dynamically setting the Singularity container for the
# "singularity:" keyword results in a parsing error for
# unclear reasons. Hence, for now, force the use of
# "singularity run" to extract data from reference containers
# (i.e., treat them like a regular file)
REFCON_USE_RUN = True

SINGULARITY_ENV_MODULE = config.get('singularity_env_module', 'Singularity')


def refcon_find_container(manifest_cache, ref_filename):

    if not pathlib.Path(manifest_cache).is_file():
        # could be a dry run
        return 'No-manifest-cache-available'

    manifests = pandas.read_hdf(manifest_cache, 'manifests')

    matched_names = set(manifests.loc[manifests['name'] == ref_filename, 'refcon_name'])
    matched_alias1 = set(manifests.loc[manifests['alias1'] == ref_filename, 'refcon_name'])
    matched_alias2 = set(manifests.loc[manifests['alias2'] == ref_filename, 'refcon_name'])

    select_container = sorted(matched_names.union(matched_alias1, matched_alias2))
    if len(select_container) > 1:
        raise ValueError(f'The requested reference file name "{ref_filename}" existis in multiple containers: {select_container}')
    elif len(select_container) == 0:
        raise ValueError(f'The requested reference file name "{ref_filename}" existis in none of these containers: {REFCON_NAMES}')
    else:
        pass
    container_path = REFCON_FOLDER / pathlib.Path(select_container[0] + '.sif')
    return container_path


if REFCON_USE_RUN:

    rule refcon_run_dump_manifest:
        input:
            sif = REFCON_FOLDER / pathlib.Path('{refcon_name}.sif')
        output:
            manifest = 'cache/refcon/{refcon_name}.manifest'
        envmodules:
            SINGULARITY_ENV_MODULE
        #singularity:
        #    lambda wildcards: f'{REFCON_FOLDER}/{wildcards.refcon_name}.sif'
        shell:
            '{input.sif} manifest > {output.manifest}'


    rule refcon_run_get_file:
        input:
            cache = 'cache/refcon/refcon_manifests.cache'
        output:
            'references/{filename}'
        envmodules:
            SINGULARITY_ENV_MODULE
        #singularity:
        #    lambda wildcards, input: refcon_find_container(input.cache, wildcards.filename)
        params:
            refcon_path = lambda wildcards, input: refcon_find_container(input.cache, wildcards.filename)
        shell:
            '{params.refcon_path} get {wildcards.filename} {output}'


rule refcon_cache_manifests:
    input:
        manifests = expand('cache/refcon/{refcon_name}.manifest', refcon_name=REFCON_NAMES)
    output:
        cache = 'cache/refcon/refcon_manifests.cache'
    run:
        merged_manifests = []
        for manifest_file in input.manifests:
            container_name = pathlib.Path(manifest_file).name.rsplit('.', 1)[0]
            assert container_name in REFCON_NAMES
            manifest = pandas.read_csv(manifest_file, sep='\t', header=0)
            manifest['refcon_name'] = container_name
            merged_manifests.append(manifest)
        merged_manifests = pandas.concat(merged_manifests, axis=0, ignore_index=False)

        merged_manifests.to_hdf(output.cache, 'manifests', mode='w')


