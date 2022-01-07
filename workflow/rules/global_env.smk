
# case is ignored for matching
FILE_NAME_CHARS = '[a-z0-9_\.\-]+$'

REFCON_BASE_MAP = create_refcon_base_map()

SOURCE_PATH_MAP, PAYLOAD_PATH_MAP, PAYLOAD_MD5_PATH_MAP, FILE_RECORDS_MAP = cache_container_payload()