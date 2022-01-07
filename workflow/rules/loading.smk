
ruleorder: md5_file_checksum > load_google_cloud_object

rule load_google_cloud_object:
    output:
        'payload/gcloud/{file}'
    params:
        url = lambda wildcards: SOURCE_PATH_MAP[('gcloud', wildcards.file)]
    shell:
        'gsutil cp gs://{params.url} {output}'
