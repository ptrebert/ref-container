# Module for dynamic environment / "runtime cache"
# This module can only be loaded and executed when
# the "functions.smk" module is available

REFCON_BASE_MAP = create_refcon_base_map()

SOURCE_PATH_MAP, TRANSFORM_FILE_PAIRS, PAYLOAD_PATH_MAP, PAYLOAD_MD5_PATH_MAP, FILE_RECORDS_MAP = cache_container_payload()

FILE_LOAD_CONSTRAINTS = build_filename_constraints('loading')

FILE_TRANSFORM_CONSTRAINTS = build_filename_constraints('transforming')
