# Reference container

## Dependencies

The following binaries must be available in your `$PATH`:

- `git`
- `singularity`
- `aria2`
- proprietary clients depending on the reference sources used (see below)

## Install AWS client on Ubuntu

`sudo apt-get install awscli`

Tested on Ubuntu 20.04, installs AWS version:

`aws-cli/1.18.69 Python/3.8.10 Linux/5.4.0-90-generic botocore/1.16.19`

## Install gcloud SDK on Ubuntu

Use snap for automated updates:

`snap install google-cloud-sdk --classic`

Source:

[cloud.google.com/sdk/docs/downloads-snap](https://cloud.google.com/sdk/docs/downloads-snap)