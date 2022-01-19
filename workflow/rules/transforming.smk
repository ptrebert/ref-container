

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