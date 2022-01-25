import sys as sys
import re as re
import pathlib as pl
import collections as col
import shutil as sh
import hashlib


def _get_container_metadata(refcon_name=None):

    if refcon_name is not None:
        select_names = [refcon_name, refcon_name.rsplit('_', 1)[0]]
        refcon_md = [(key.split('_')[-1], metadata) for key, metadata in config.items() if key.startswith('metadata_')]
        refcon_md = [(name, metadata) for name, metadata in refcon_md if name in select_names]
        if len(refcon_md) > 1:
            raise ValueError(f'Ambiguous reference container metadata for name selection: {select_names}')
    else:
        refcon_md = [(key.split('_')[-1], metadata) for key, metadata in config.items() if key.startswith('metadata_')]
    if not refcon_md:
        raise ValueError('No "metadata_" keys found in config. Did you forget to load a reference container config?')
    for rc_name, rc_md in refcon_md:
        if 'name' not in rc_md or rc_name != rc_md['name']:
            raise ValueError(f'Reference container name missing or mismatch: {rc_name} / {rc_md}')
    return refcon_md


def _get_md5_from_file(file_path):

    with open(file_path, 'r') as checksum:
        md5, file_name = checksum.read().strip().split()
    assert pl.Path(file_name) == file_path.with_suffix(''), f'Sh*t happened: {file_path} / {file_name}'
    return md5


def _get_file_size(file_path):

    size_in_bytes = file_path.stat().st_size
    return size_in_bytes


def create_refcon_base_map():
    """
    Build the association between reference container
    and the required base image - stored as dict during runtime
    """
    refcon_to_base_img = dict()

    refcon_md = _get_container_metadata()
    for rc_name, rc_md in refcon_md:
        base_image = rc_md.get('base_image', None)
        if base_image is None:
            raise ValueError(f'Key "base_image" is missing from reference container metadata: {rc_md}')
        rc_version = rc_md.get('version', None)
        if rc_version is None:
            raise ValueError(f'Key "version" is missing from reference container metadata: {rc_md}')
        try:
            _ = int(rc_version)
        except ValueError:
            raise ValueError(f'Reference container version must be a simple integer: {rc_version}')
        refcon_to_base_img[rc_name] = base_image
        versioned_name = rc_name + f'_v{rc_version}'
        refcon_to_base_img[versioned_name] = base_image
    return refcon_to_base_img


def _find_base_def_file(base_name):

    repo_path = pl.Path(workflow.basedir).absolute()
    def_files_folder = repo_path / pl.Path('def_files') / pl.Path('base')
    if not def_files_folder.is_dir():
        raise ValueError(f'Expected to find base def files at path {def_files_folder}, but that does not exist')
    def_file_path = def_files_folder / pl.Path(base_name + '.def')
    if not def_file_path.is_file():
        raise ValueError(f'Missing def file for base image - expected location: {def_file_path}')
    return def_file_path


def collect_base_images(wildcards):
    """
    Iterate through config and collect
    all required based images. If the user
    hasn't built a required base image, the
    missing rule to create the base image
    automatically results in a Snakemake error.
    """
    required_base_containers = []

    workflow_dir = pl.Path().cwd()

    refcon_md = _get_container_metadata()
    for key, rc_md in refcon_md:
        base_image = rc_md.get('base_image', None)
        if base_image is None:
            raise ValueError(f'Key "base_image" is missing from reference container metadata: {rc_md}')
        base_container_path = pl.Path(f'container/{base_image}.sif')
        if not base_container_path.is_file():
            # to make the manual builds easier, copy required
            # base image def files to container directory
            base_def_file = _find_base_def_file(base_image)
            target_def_file = base_container_path.with_suffix('.def')
            pl.Path('container/').mkdir(parents=True, exist_ok=True)
            sh.copy(base_def_file, target_def_file)
            info_msg = f'\nACTION REQUIRED --- missing base container detected: {base_image}.sif\n'
            info_msg += f'Please run the following build command in the "container" folder:\n'
            info_msg += f'$ cd {workflow_dir}/container\n'
            info_msg += f'$ sudo singularity build {base_image}.sif {base_image}.def\n\n'
            sys.stderr.write(info_msg)

        required_base_containers.append(base_container_path)
    return sorted(required_base_containers)


def collect_reference_container_build_targets(wildcards):
    """
    Determine the target files to build one or more reference containers.
    By default, the MANIFEST and the definition file for each container
    are the only fixed outputs.
    If a container image is found at the expected location, then the completeness
    of the container can be verified by checking that all files exist in the
    container under /payload
    """
    required_manifests = []
    required_def_files = []
    required_containers = []
    required_verifications = []

    refcon_md = _get_container_metadata()
    for _, rc_md in refcon_md:
        short_name = rc_md['name']
        refcon_version = rc_md['version']
        refcon_name = short_name + f'_v{refcon_version}'

        manifest_path = f'container/{refcon_name}/MANIFEST.tsv'
        required_manifests.append(manifest_path)
        deffile_path = f'container/{refcon_name}/build.def'
        required_def_files.append(deffile_path)
        container_path = pl.Path(f'container/{refcon_name}.sif')
        required_containers.append(container_path)
        if container_path.is_file():
            # already build - add verification file
            content_path = f'container/{refcon_name}.content.ok'
            required_verifications.append(content_path)

    target_files = required_containers + required_def_files + required_manifests + required_verifications

    return target_files


def _process_transformation_spec(container_file_name, trans_spec, provider, prefix):
    """
    For all file transformations, the first entry in the file specification ("name")
    must not contain additional path information, because the downloaded source file
    is a different one
    """
    if str(pl.Path(container_file_name)) != pl.Path(container_file_name).name:
        raise ValueError(
            f'The specified output file name contains path information: {container_file_name}'
            '\nThis is not allowed for payload files generated by data transformations.'
        )

    transformation, source_info = list(trans_spec.items())[0]
    transformation = DataTransformations[transformation]
    if transformation == DataTransformations['decompress']:
        assert isinstance(source_info, str)
        source_file_path = prefix / pl.Path(source_info)
        source_cache_record = {(provider, transformation, source_file_path.name): source_file_path}
        transform_local_input = pl.Path(f'tmp_{transformation.name}/{provider.name}/{source_file_path.name}')
        transform_pair_record = {(provider, transformation, container_file_name): transform_local_input}
    elif transformation == DataTransformations['rename']:
        # rename does not need a tmp_ location as long as all data loading calls
        # support an explicit "output" argument
        assert isinstance(source_info, str)
        source_file_path = prefix / pl.Path(source_info)
        source_cache_record = {(provider, DataTransformations['raw'], container_file_name): source_file_path}
        transform_pair_record = {}
    elif transformation == DataTransformations['extract']:
        if isinstance(source_info, str):
            # just archive given, member name is identical to desired output name
            archive_path = source_info
            member_name = container_file_name
        elif isinstance(source_info, dict):
            archive_path = source_info['archive']
            member_name = source_info['member']
        else:
            raise ValueError(f'Cannot parse "extract" transformation source info: {source_info}')

        source_file_path = prefix / pl.Path(archive_path)
        source_cache_record = {(provider, transformation, source_file_path.name): source_file_path}
        transform_local_input = pl.Path(f'tmp_{transformation.name}/{provider.name}/{source_file_path.name}')
        transform_pair_record = {(provider, transformation, container_file_name): transform_local_input}
        transform_pair_record_member = {(provider, transformation, container_file_name, 'member'): member_name}
        transform_pair_record.update(transform_pair_record_member)
    elif transformation == DataTransformations['derive']:
        output_name = f'payload/{provider.name}/{container_file_name}'
        source_file_path = source_info['input']
        source_cache_record = dict()  # not None!
        rule_id = hashlib.md5((source_info['input'] + container_file_name).encode('utf-8')).hexdigest()
        derive_spec = {
            'input': f"payload/{provider.name}/{source_info['input']}",
            'output': output_name,
            'shell': source_info['shell'],
            'conda': source_info.get('conda', None),
            'singularity': source_info.get('singularity', None),
            'name': container_file_name,
            'rule_name': rule_id
        }
        transform_pair_record = {(provider, transformation, container_file_name): derive_spec}
    else:
        raise NotImplementedError(f'cannot handle {transformation}')

    return source_file_path, source_cache_record, transform_pair_record



def _parse_file_spec(file_spec, check_file_name, provider, prefix):

    if len(file_spec) < 1:
        # not sure if that can happen
        raise ValueError('Empty source file specification')

    # check if last entry is a simple data transformation:
    # file decompress or file extract
    last_record = file_spec[-1]
    if isinstance(last_record, dict):
        source_file_path, source_cache_record, transform_pair_record = _process_transformation_spec(file_spec[0], last_record, provider, prefix)
        file_spec = file_spec[:-1]
    else:
        source_file_path = None
        source_cache_record = None
        transform_pair_record = dict()

    if len(file_spec) > 3:
        raise ValueError(f'Too many alias names defined for file: {file_spec}')

    file_identifier = {k.name: v for k, v in zip(FileIdentifiers, ['n/a'] * len(FileIdentifiers))}

    for id_name, file_name in zip(FileIdentifiers, file_spec):
        if id_name == FileIdentifiers['name']:
            # if file-specific path prefixes (= subfolder) are part of the
            # data source file list, strip them for the MANIFEST file
            clean_name = pl.Path(file_name).name
            if check_file_name.match(clean_name) is None:
                raise ValueError(f'File name contains illegal characters: {clean_name} --- allowed: {FILE_NAME_CHARS[:-2]}')
            file_identifier[id_name.name] = clean_name
            if source_cache_record is None:
                source_file_path = prefix / pl.Path(file_name)
                source_cache_record = {(provider, DataTransformations['raw'], clean_name): source_file_path}
        else:
            if check_file_name.match(file_name) is None:
                raise ValueError(f'File alias contains illegal characters: {id_name.name} / {file_name} --- allowed: {FILE_NAME_CHARS[:-2]}')
            file_identifier[id_name.name] = file_name
    return source_file_path, file_identifier, source_cache_record, transform_pair_record


def _parse_source_listing(source_spec, check_file_names):

    provider = DataProviders[source_spec['provider']]

    # path for download in Snakemake working directory
    local_root = pl.Path('payload') / pl.Path(provider.name)
    # path in container
    container_root = pl.Path('/payload')

    prefix = pl.Path(source_spec.get('prefix', ''))

    file_records = []
    file_names_or_aliases = set()

    source_path_cache = dict()
    transform_pair_cache = dict()

    for file_spec in source_spec['files']:
        file_record = dict()
        source_file_path, file_identifiers, source_cache_info, transform_pair = _parse_file_spec(file_spec, check_file_names, provider, prefix)
        source_path_cache.update(source_cache_info)
        transform_pair_cache.update(transform_pair)

        if any(x in file_names_or_aliases for x in file_identifiers.values()):
            raise ValueError(f'Duplicate name or alias in source: {file_identifiers} / {source_spec}')
        [file_names_or_aliases.add(x) for x in file_identifiers.values() if x != 'n/a']
        file_record['source_path'] = source_file_path
        file_record['target_path'] = local_root / pl.Path(file_identifiers['name'])
        file_record['target_path_md5'] = local_root / pl.Path(file_identifiers['name'] + '.md5')
        file_record['container_path'] = container_root / pl.Path(file_identifiers['name'])
        file_record['container_aliases'] = []

        if file_identifiers['alias1'] != 'n/a':
            aliases = [container_root / pl.Path(file_identifiers['alias1'])]
            if file_identifiers['alias2'] != 'n/a':
                aliases.append(container_root / pl.Path(file_identifiers['alias2']))
            file_record['container_aliases'] = aliases

        file_record.update(file_identifiers)
        file_records.append(file_record)

    return file_records, source_path_cache, transform_pair_cache, file_names_or_aliases


def cache_container_payload():
    """
    This creates a runtime cache holding
    all payload files per container
    (indexed by container name and separated by type).
    Additionally, files are annotated with generic
    and specific alias to simplify manifest creation.
    """
    refcon_md = _get_container_metadata()

    source_cache = dict()  # cache (data provider, file name) to source path, e.g. URL
    local_payload_cache = col.defaultdict(list)  # cache payload files per container
    local_md5_cache = col.defaultdict(list)  # cache payload/md5 files per container
    file_records = col.defaultdict(list)  # file records for manifest file

    check_file_names = re.compile(FILE_NAME_CHARS, flags=re.IGNORECASE)

    global_names_or_aliases = set()

    for short_name, rc_md in refcon_md:
        refcon_version = rc_md['version']
        refcon_name = short_name + f'_v{refcon_version}'
        local_names_or_aliases = set()
        for source in rc_md['sources']:

            source_file_records, source_paths, transform_pairs, source_file_identifiers = _parse_source_listing(source, check_file_names)

            local_duplicate_names = local_names_or_aliases.intersection(source_file_identifiers)
            if local_duplicate_names:
                raise ValueError(f'Duplicate file names or aliases between sources within container: {refcon_name} / {local_duplicate_names}')
            local_names_or_aliases = local_names_or_aliases.union(source_file_identifiers)

            source_cache.update(source_paths)
            local_payload_cache[refcon_name].extend([fr['target_path'] for fr in source_file_records])
            local_md5_cache[refcon_name].extend([fr['target_path_md5'] for fr in source_file_records])
            file_records[refcon_name].extend(source_file_records)

        # globally (= between containers) duplicate names is not necessarily a problem,
        # [only if containers are used in the same analysis]
        # so print just an explicit warning message
        global_duplicate_names = global_names_or_aliases.intersection(local_names_or_aliases)
        if global_duplicate_names:
            warn_msg = '\nWARNING --- file names or aliases are identical between containers.\n'
            warn_msg += f'Currently processing reference container: {refcon_name}\n'
            warn_msg += f'Duplicate names or aliases: {global_duplicate_names}\n'
            sys.stderr.write(warn_msg)
        global_names_or_aliases = global_names_or_aliases.union(local_names_or_aliases)

    return source_cache, transform_pairs, local_payload_cache, local_md5_cache, file_records


def build_filename_constraints(which):

    if which == 'loading':
        name_cache = SOURCE_PATH_MAP
    elif which == 'transforming':
        name_cache = TRANSFORM_FILE_PAIRS
    else:
        raise ValueError(f'Unknown file name constraint requested: {which}')

    # filter out (archive) "member" keys for "extract" transformations
    def _filter_transform_pair_keys(record_key):
        if len(record_key) == 4:
            return False
        return True
    filter_keys = _filter_transform_pair_keys

    mapping = dict()
    for provider in DataProviders:
        for transformation in DataTransformations:
            file_names = [f for p, t, f in filter(filter_keys, name_cache.keys()) if p == provider and t == transformation]
            if not file_names:
                continue
            constraint = '(' + '|'.join(file_names) + ')'
            mapping[provider, transformation] = constraint
    return mapping


def select_container_readme(wildcards):

    _, refcon_md = _get_container_metadata(wildcards.rc_name_version)[0]
    if 'readme' in refcon_md:
        readme_path = f'container/{wildcards.rc_name_version}/README.txt'
    else:
        readme_path = []
    return readme_path


def _collect_git_labels():
    import subprocess as sp

    wd = pl.Path(workflow.basedir).absolute()  # should always be the repo folder

    collect_infos = ['rev-parse --short HEAD', 'rev-parse --abbrev-ref HEAD', 'config --get remote.origin.url']
    info_labels = ['git_hash', 'git_branch', 'git_url']

    git_labels = []
    for option, label in zip(collect_infos, info_labels):
        call = 'git ' + option
        try:
            out = sp.check_output(call, shell=True, cwd=wd).decode().strip()
            git_labels.append((label, out))
        except sp.CalledProcessError as err:
            err_msg = f'\nERROR --- could not collect git info using call: {call}\n'
            err_msg += f'Error message: {str(err)}\n'
            err_msg += f'Call executed in path: {wd}\n'
            err_msg += f'Proceeding with container building...\n'
            sys.stderr.write(err_msg)
            git_labels.append((label, 'unset-error'))
    return git_labels


def _get_container_labels(refcon_name):

    _, refcon_md = _get_container_metadata(refcon_name)[0]

    container_labels = []

    named_labels = ['author', 'contact', 'name', 'version']
    for n in named_labels:
        container_labels.append((n, refcon_md[n]))

    keyword_labels = refcon_md.get('labels', [])
    if not keyword_labels:
        refcon_name = refcon_md['name']
        warn_msg = f'\nWARNING --- no labels specified as part of the container configuration: {refcon_name}\n'
        warn_msg += 'This is strongly discouraged, but the container building process will proceed nevertheless.\n'
        sys.stderr.write(warn_msg)

    enum_labels = [(f'label_{i}', '"'+ l +'"') for i, l in enumerate(keyword_labels)]
    container_labels.extend(enum_labels)
    container_labels.extend(_collect_git_labels())

    return container_labels
