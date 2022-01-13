
rule load_google_cloud_object:
    output:
        'payload/gcloud/{filename}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[(DataProviders['gcloud'], DataTransformations['raw'], wildcards.filename)]
    wildcard_constraints:
        filename = FILE_LOAD_CONSTRAINTS.get((DataProviders['gcloud'], DataTransformations['raw']), 'no-file')
    shell:
        'gsutil cp gs://{params.url} {output}'


rule load_google_cloud_object_extract:
    output:
        'tmp_extract/gcloud/{filename}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[(DataProviders['gcloud'], DataTransformations['extract'], wildcards.filename)]
    wildcard_constraints:
        filename = FILE_LOAD_CONSTRAINTS.get((DataProviders['gcloud'], DataTransformations['extract']), 'no-file')
    shell:
        'gsutil cp gs://{params.url} {output}'


rule load_google_cloud_object_decompress:
    output:
        'tmp_decompress/gcloud/{filename}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[(DataProviders['gcloud'], DataTransformations['decompress'], wildcards.filename)]
    wildcard_constraints:
        filename = FILE_LOAD_CONSTRAINTS.get((DataProviders['gcloud'], DataTransformations['decompress']), 'no-file')
    shell:
        'gsutil cp gs://{params.url} {output}'


rule load_ftp_object:
    output:
        'payload/ftp/{filename}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[(DataProviders['ftp'], DataTransformations['raw'], wildcards.filename)]
    wildcard_constraints:
        filename = FILE_LOAD_CONSTRAINTS.get((DataProviders['ftp'], DataTransformations['raw']), 'no-file')
    shell:
        'aria2c --out={output} --continue=true ftp://{params.url}'


rule load_ftp_object_extract:
    output:
        'tmp_extract/ftp/{filename}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[(DataProviders['ftp'], DataTransformations['extract'], wildcards.filename)]
    wildcard_constraints:
        filename = FILE_LOAD_CONSTRAINTS.get((DataProviders['ftp'], DataTransformations['extract']), 'no-file')
    shell:
        'aria2c --out={output} --continue=true ftp://{params.url}'


rule load_ftp_object_decompress:
    output:
        'tmp_decompress/ftp/{filename}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[(DataProviders['ftp'], DataTransformations['decompress'], wildcards.filename)]
    wildcard_constraints:
        filename = FILE_LOAD_CONSTRAINTS.get((DataProviders['ftp'], DataTransformations['decompress']), 'no-file')
    shell:
        'aria2c --out={output} --continue=true ftp://{params.url}'