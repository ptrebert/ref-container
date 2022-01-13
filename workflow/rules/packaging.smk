
rule dump_container_readme:
    output:
        readme = 'container/{rc_name_version}/README.txt'
    run:
        _, refcon_md = _get_container_metadata(wildcards.rc_name_version)[0]
        readme_txt = refcon_md.get('readme', None)
        if readme_txt is None:
            # since this rule should only be active if there is a
            # readme section in the config, this must indicate an error
            raise ValueError(f'Reference container config does not include a readme section: {wildcards.rc_name_version}')
        with open(output.readme, 'w') as readme:
            _ = readme.write(readme_txt)


rule create_reference_container_manifest:
    input:
        payload = lambda wildcards: PAYLOAD_PATH_MAP[wildcards.rc_name_version],
        payload_md5 = lambda wildcards: PAYLOAD_MD5_PATH_MAP[wildcards.rc_name_version]
    output:
        manifest = 'container/{rc_name_version}/MANIFEST.tsv'
    run:
        import pandas as pd

        file_records = FILE_RECORDS_MAP[wildcards.rc_name_version]

        manifest = pd.DataFrame.from_records(
            file_records,
            exclude=['container_path', 'container_aliases'],
            index=range(len(file_records))
        )
        manifest['file_size_byte'] = manifest['target_path'].apply(_get_file_size)
        manifest['file_md5'] = manifest['target_path_md5'].apply(_get_md5_from_file)
        manifest.drop(['target_path', 'target_path_md5'], axis=1, inplace=True)

        reorder = ['name', 'alias1', 'alias2', 'file_md5', 'file_size_byte', 'source_path']
        manifest = manifest[reorder]

        manifest.to_csv(output.manifest, index=False, header=True, sep='\t')


rule create_reference_container_definition_file:
    input:
        manifest = 'container/{rc_name_version}/MANIFEST.tsv',
        readme = select_container_readme
    output:
        def_file = 'container/{rc_name_version}/build.def'
    run:
        import io
        base_img = REFCON_BASE_MAP[wildcards.rc_name_version]
        base_img_abs = pl.Path(f'container/{base_img}.sif').absolute()

        # header section
        build_def = io.StringIO()
        build_def.write('Bootstrap: localimage\n')
        build_def.write(f'From: {base_img_abs}\n\n')

        # files and post section
        build_def.write('%files\n')
        build_def.write(f' {pl.Path(input.manifest).absolute()} /payload/MANIFEST.tsv\n')

        post_section = io.StringIO()  # could be empty, so buffer here first
        post_section.write('%post\n')
        add_post_section = False

        file_records = FILE_RECORDS_MAP[wildcards.rc_name_version]
        for fr in file_records:
            build_def.write(f" {pl.Path(fr['target_path']).absolute()} {fr['container_path']}\n")
            for alias in fr['container_aliases']:
                post_section.write(f" ln -s {fr['container_path']} {alias}\n")
                add_post_section = True

        if isinstance(input.readme, str) and pl.Path(input.readme).is_file():
            build_def.write(f' {pl.Path(input.readme).absolute()} /payload/README.txt\n')
        build_def.write('\n')
        if add_post_section:
            build_def.write(post_section.getvalue() + '\n')

        # label section
        build_def.write('%labels\n')
        container_labels = _get_container_labels(wildcards.rc_name_version)
        for label_name, label_value in container_labels:
            build_def.write(f' {label_name} {label_value}\n')

        with open(output.def_file, 'w') as dump:
            _ = dump.write(build_def.getvalue())


rule notify_user:
    input:
        def_file = 'container/{rc_name_version}/build.def'
    output:
        sif_file = 'container/{rc_name_version}.sif'
    message: 'Container ready to build'
    run:
        workflow_dir = pl.Path().cwd()

        rc_name = wildcards.rc_name_version

        info_msg = f'\nACTION REQUIRED --- reference container ready to build: {rc_name}.sif\n'
        info_msg += f'Please run the following build command in the "container" folder:\n'
        info_msg += f'$ cd {workflow_dir}/container\n'
        info_msg += f'$ sudo singularity build {rc_name}.sif {rc_name}/build.def\n\n'
        info_msg += '(Restart the pipeline afterwards to check the container payload)\n\n'
        sys.stderr.write(info_msg)


rule verify_container_content:
    input:
        container = 'container/{rc_name_version}.sif',
        payload = 'container/{rc_name_version}.content.list'
    output:
        check = 'container/{rc_name_version}.content.ok'
    run:
        import operator as op

        with open(input.payload, 'r') as dump:
            payload_files = dump.read().strip().split()
            payload_files = set(pl.Path(pf).name for pf in payload_files)

        file_records = FILE_RECORDS_MAP[wildcards.rc_name_version]
        get_names = op.itemgetter(*('name', 'alias1', 'alias2'))
        file_names = set().union(*(set(get_names(fr)) for fr in file_records))
        file_names = set(x for x in file_names if x != 'n/a')

        missing_in_container = sorted(file_names - payload_files)
        if missing_in_container:
            err_msg = '\nPAYLOAD ERROR'
            err_msg += '\nThe following files are not part of the reference container payload: '
            err_msg += f'{missing_in_container}\n\n'
            raise ValueError(err_msg)

        extra_in_container = payload_files - file_names
        # manifest must exist
        if not extra_in_container:
            raise ValueError(f'\nERROR\nReference container payload does not include MANIFEST\n\n')
        
        extra_in_container = sorted(extra_in_container - {'MANIFEST.tsv', 'README.txt'})
        if extra_in_container:
            err_msg = '\nPAYLOAD ERROR'
            err_msg += '\nThe following files are part of the payload but missing from the container config: '
            err_msg += f'{extra_in_container}\n\n'
            raise ValueError(err_msg)

        with open(output.check, 'w'):
            pass
