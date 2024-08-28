set temporary option ESCAPE_CHARACTER='ON';
set temporary option ON_ERROR='EXIT';

LOAD TABLE dim_e_lte_erbs (
OSS_ID,
ERBS_FDN,
ERBS_NAME,
ERBS_ID,
SITE_FDN,
SITE_ID,
MECONTEXTID,
NEMIMVERSION,
ERBS_VERSION,
VENDOR,
STATUS,
managedElementType
)
FROM '/eniq/home/dcuser/ETL/dim_e_lte_erbs_anon.csv'
ESCAPES OFF
QUOTES OFF
--ROW DELIMITED BY '\n'
DELIMITED BY '|'
WITH CHECKPOINT OFF

