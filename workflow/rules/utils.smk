
rule md5_file_checksum:
    input:
        '{filepath}'
    output:
        '{filepath}.md5'
    shell:
        'md5sum {input} > {output}'


rule sha256_file_checksum:
    input:
        '{filepath}'
    output:
        '{filepath}.sha256'
    shell:
        'sha256sum {input} > {output}'


rule payload_listing:
    input:
        sif = 'container/{rc_name_version}.sif'
    output:
        listing = temp('container/{rc_name_version}.content.list')
    shell:
        'singularity exec {input.sif} ls -1 /payload > {output.listing}'
