import enum as enum


class DataProviders(enum.Enum):
    gcloud = 1
    google = 1
    ftp = 2
    aws = 3
    amazon = 3
    globus = 4
    aspera = 5
    aspx = 5
    local = 6
    localhost = 6


class DataTransformations(enum.Enum):
    raw = 1
    decompress = 2
    uncompress = 2
    inflate = 2
    extract = 3
    rename = 4
    derive = 5


class FileIdentifiers(enum.Enum):
    name = 1
    alias1 = 2
    alias2 = 3



# case is ignored for matching
FILE_NAME_CHARS = '[a-z0-9_\.\-]+$'
