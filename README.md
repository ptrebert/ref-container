# Reference container

This repository hosts a small Snakemake pipeline that enables (mostly) automatic builds of `reference containers`. 
Reference containers package related sets of reference data files that are used in computational analyses
(e.g., a reference genome plus index files) in a minimal yet self-sufficient and self-documenting Singularity container.

### Related work

When looking for solutions to ship large-ish datasets using Singularity containers, one may stumble upon the
work Rioux and colleagues, which is somewhat similar in spirit:

[arXiv 2020: Deploying large fixed file datasets with SquashFS and Singularity](https://arxiv.org/pdf/2002.06129.pdf)

[Reference implementation on github](https://github.com/aces/sing-squashfs-support)

## Intended use case

1. "Offline" systems: deploying computational analysis pipelines on infrastructure that is disconnected
from (general) internet access can be painful if necessary reference data cannot be downloaded automatically by the pipeline.
2. A similar set of reference data files is shared among several users and used in various pipelines.
3. Reference data files are (usually) publicly hosted and can be downloaded automatically on, e.g., a laptop with general
internet access, and then bundled in a container and transferred to the infrastructure with limited world access.
4. The reference data volume is manageable on a standard laptop or desktop, i.e. at most a few dozen gigabye per container.
5. There must be a machine available to build the containers, i.e. where the user has root privileges.

### Benefits

1. Apart from deleting the entire container, accidentally changing the reference data inside the container while
it is located on the target infrastructure is (probably?) impossible.
2. Instead of a folder hierarchy cluttered with original reference files and derived/altered versions that are
of unclear origin for other team members, a few dozen containers can provide hundreds of static reference files.
3. Each container contains a MANIFEST, and optionally a README, and is thus self-documenting at least to a minimal extent.
If the source location for the reference data files included a specific readme, it can simply be added to the
container during the build process.

## Dependencies for this pipeline

There is a Snakemake environment defined in `workflow/envs/run_*.yml`. Since this pipeline is assumed to be
executed on a machine where the user is root (the most straightforward way to build containers),
and retrieving data from cloud hosters usually requires some login or client configuration,
this repo cannot provide an out-of-the-box solution for all possible download sources.
As a rule of thumb, if the download works "live" in the shell, then it should also work as part of this pipeline.

Additionally, the following binaries must be available in your `$PATH` besides the download utilities:

- `git`
- `singularity`
- (proprietary) download clients depending on the reference sources used (see below)

### Utility: install AWS client on Ubuntu

`sudo apt-get install awscli`

Tested on Ubuntu 20.04, installs AWS version:

`aws-cli/1.18.69 Python/3.8.10 Linux/5.4.0-90-generic botocore/1.16.19`

### Utility: install gcloud SDK on Ubuntu

Use snap for automated updates:

`snap install google-cloud-sdk --classic`

Source:

[cloud.google.com/sdk/docs/downloads-snap](https://cloud.google.com/sdk/docs/downloads-snap)

## Interacting with a reference container

Each reference container has the same internal structure, supports three special commands and of course
can be inspected using `singularity inspect` or `singularity run-help`.

### Folders and files

All data are located under `/payload` inside the container. Each data file can have up to two symlinks
created under `/payload` to enable aliasing of files. For example, the original reference file
`Homo_Sapiens_assembly38_noalt.fasta` may be aliased (symlinked) by just `genome.fasta` to make working with the
reference files easier, especially when using the file names in analysis pipelines.

### Commands

`./CONTAINER.sif manifest` prints the MANIFEST to stdout (from its location `/payload/MANIFEST.tsv`)

`./CONTAINER.sif readme` prints the README to stdout (from its location `/payload/README.txt`) 
Note that a README in the container is optional.

`./CONTAINER.sif get REF_FILE_NAME_OR_ALIAS [DESTINATION]` copies the reference file to the current
working directory if DESTINATION is omitted or to DESTINATION. This command can be used to copy the necessary
references to the current analysis directory. Caveat: the container path `/payload` must be ommitted, and the file name
must include the file extension.

Note that all of the above commands are just shorthands for `singularity run CONTAINER.sif COMMAND`. Additionally,
since the Singularity container is fully functional, it supports all other common operations (if the required
binary is available in the container). For example, to get the uncompressed version of a reference file, one could run
the command:

`singularity exec CONTAINER.sif gzip -d -c /payload/REF_FILE_NAME_OR_ALIAS.gz > REF_FILE_NAME_OR_ALIAS`

### MANIFEST file format

The manifest is a tab-separated text table with header. The table columns are as follows:

1. name = name of the file
2. alias1 = name of a symlink to the file or n/a
3. alias2 = name of a symlink to the file or n/a
4. file_md5 = MD5 checksum of the file
5. file_size_byte = size of file in byte (outside of the container)
6. source_path = (download) source of the file

Referring to a specific file by name or by one of the aliases is equivalent.
During the build process of a container, it is checked that no two files specify
an identical alias, but note that file names or aliases can be identical between
containers. Reference files can be downloaded as part of an archive or in
compressed form and be decompressed before copying into the container. Hence,
the file name given as the source path may be slightly different from the file
name in the container (e.g., having the file extension `fasta.gz` instead of just `fasta`).

## Comments about Singularity

For complete information, please refer to the Singularity documentation:

[sylabs.io/guides/3.5/user-guide/build_env.html](https://sylabs.io/guides/3.5/user-guide/build_env.html)

Since all reference files will be copied to a temporary location during the build process,
the default `/tmp/XXX` folder can easily run out of space depending on the user's specific
system configuration. Cache and temp folder can be configured by setting the environment
variables `SINGULARITY_CACHEDIR` and `SINGULARITY_TMPDIR`. Passing these variables to the root
environment for the building process can be achieved by setting the `-E` option for `sudo`:

`sudo -E singularity build ...`

However, if root and user cache and temp locations are set to the same folder, then user-level
operations, e.g. `singularity exec`, that attempt to use the cache may run into permission errors.
A simple workaround is to set a shell alias for the Singularity build command that specifies separate
cache and temp folders on a storage location with sufficient space even for large container builts:

`alias buildsif='sudo SINGULARITY_CACHEDIR=/local/large_volume/singularity_build SINGULARITY_TMPDIR=/local/large_volume/singularity_build singularity build'`

## Using reference containers in external Snakemake workflows

The requirements to use reference containers in Snakemake workflows are as follows:
- the Singularity binary is available in `$PATH`
  - if Singularity has to be loaded as an `env module` (e.g., on HPCs), the name of the module
    can be specified by setting the option `singularity_env_module` in the Snakemake confguration
    (by default, the name is set to `Singularity`)
- the Snakemake base environment includes the `pandas` package
- your workflow is structured to find all reference files (loaded from reference containers) in the
  folder `references/` in the Snakemake working directory
  - if you need to adapt reference files for your workflow, then you should absolutely specify a different
    folder for derived reference files, e.g. `references_derived/`, to avoid rule ambiguity

If the above requirements are met, add the following code snippet at the top of your main Snakefile:

```python
import pathlib

refcon_module = pathlib.Path("ref-container/workflow/rules/ext_include/refcon_load.smk")
refcon_repo_path = config.get("refcon_repo_path", None)
if refcon_repo_path is None:
    refcon_repo_path = pathlib.Path(workflow.basedir).parent
else:
    refcon_repo_path = pathlib.Path(refcon_repo_path)
    assert refcon_repo_path.is_dir()
refcon_include_module = refcon_repo_path / refcon_module
include: refcon_include_module

[rest of the Snakefile]
```

The above enables you to either specify the top-level path where you cloned the `ref-container` repository
as part of you Snakemake configuration, or to simply put the `ref-container` repository next to your
workflow repository as follows:

```bash
$ ls
ref-container/
your-pipeline/
```

In your Snakemake configuration, you need to set the folder name where the reference containers are stored...

```yaml
reference_container_folder = PATH_TO_THE_CONTAINER_FOLDER
```

...and list the containers to use:

```yaml
reference_container_folder = PATH_TO_THE_CONTAINER_FOLDER
reference_container_names:
    - ref_container1
    - ref_container2
    - ref_container3
```

The reference container module included above will automatically retrieve requested reference files from
the containers, or raise an error if a file cannot be found or is not unambiguously identifiable.

To document which files have been used in your workflow, you can copy/archive the manifest files of the containers
that are cached in your pipeline working directory under `cache/refcon/` at the end of your analysis run.