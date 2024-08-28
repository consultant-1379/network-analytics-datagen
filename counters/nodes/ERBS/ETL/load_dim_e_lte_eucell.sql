set temporary option ESCAPE_CHARACTER='ON';
set temporary option ON_ERROR='EXIT';

LOAD TABLE dim_e_lte_eucell (
OSS_ID,
EUTRANCELL_FDN,
CELL_TYPE,
ERBS_ID,
ENodeBFunction,
EUtranCellId,
CELL_ID,
TAC_NAME,
tac,
earfcndl,
earfcnul,
earfcn,
userLabel,
hostingDigitalUnit,
noOfPucchCqiUsers,
noOfPucchSrUsers,
cellRange,
ulChannelBandwidth,
pdcchCfiMode,
ERBS_FDN,
VENDOR,
STATUS 
)
FROM '/eniq/home/dcuser/ETL/dim_e_lte_eucell_anon.csv'
ESCAPES OFF
QUOTES OFF
--ROW DELIMITED BY '\n'
DELIMITED BY '|'
WITH CHECKPOINT OFF

