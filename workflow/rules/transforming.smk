

rule decompress_gcloud_file:
    input:
        lambda wildcards: TRANSFORM_FILE_PAIRS.get((DataProviders['gcloud'], DataTransformations['decompress'], wildcards.filename), [])
    output:
        'payload/gcloud/{filename}'
    wildcard_constraints:
        filename = FILE_TRANSFORM_CONSTRAINTS.get((DataProviders['gcloud'], DataTransformations['decompress']), 'no-file')
    shell:
        'gzip -d -c {input} > {output}'


rule extract_gcloud_file:
    input:
        lambda wildcards: TRANSFORM_FILE_PAIRS.get((DataProviders['gcloud'], DataTransformations['extract'], wildcards.filename), [])
    output:
        'payload/gcloud/{filename}'
    wildcard_constraints:
        filename = FILE_TRANSFORM_CONSTRAINTS.get((DataProviders['gcloud'], DataTransformations['extract']), 'no-file')
    params:
        member_name = lambda wildcards: TRANSFORM_FILE_PAIRS.get((DataProviders['gcloud'], DataTransformations['extract'], wildcards.filename, 'member'), 'no-file')
    shell:
        'tar xzf {input} --to-stdout --overwrite {params.member_name} > {output}'


rule decompress_ftp_file:
    input:
        lambda wildcards: TRANSFORM_FILE_PAIRS[(DataProviders['ftp'], DataTransformations['decompress'], wildcards.filename)]
    output:
        'payload/ftp/{filename}'
    wildcard_constraints:
        filename = FILE_TRANSFORM_CONSTRAINTS.get((DataProviders['ftp'], DataTransformations['decompress']), 'no-file')
    shell:
        'gzip -d -c {input} > {output}'


rule extract_ftp_file:
    input:
        lambda wildcards: TRANSFORM_FILE_PAIRS.get((DataProviders['ftp'], DataTransformations['extract'], wildcards.filename), [])
    output:
        'payload/ftp/{filename}'
    wildcard_constraints:
        filename = FILE_TRANSFORM_CONSTRAINTS.get((DataProviders['ftp'], DataTransformations['extract']), 'no-file')
    params:
        member_name = lambda wildcards: TRANSFORM_FILE_PAIRS.get((DataProviders['ftp'], DataTransformations['extract'], wildcards.filename, 'member'), 'no-file')
    shell:
        'tar xzf {input} --to-stdout --overwrite {params.member_name} > {output}'


DERIVE_TRANSFORMATIONS = [derive_spec for transform_key, derive_spec in TRANSFORM_FILE_PAIRS.items() if transform_key[1] == DataTransformations['derive']]
for DT in DERIVE_TRANSFORMATIONS:
    rule:
        name: f"derive_{DT['rule_name']}"
        message: f"Deriving data file {DT['name']}"
        input:  DT['input']
        output: DT['output']
        conda: DT.get('conda', None)
        singularity: DT.get('singularity', None)
        shell: DT['shell']
