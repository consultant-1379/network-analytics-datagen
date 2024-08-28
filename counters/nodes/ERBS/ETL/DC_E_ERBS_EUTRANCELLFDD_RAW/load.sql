set temporary option ESCAPE_CHARACTER='ON';
set temporary option ON_ERROR='EXIT';

LOAD TABLE <PARTITION> (
DC_RELEASE,
DC_SOURCE,
DC_SUSPECTFLAG,
DC_TIMEZONE,
ENodeBFunction,
ERBS,
EUtranCellFDD,
MOID,
NESW,
OSS_ID,
PERIOD_DURATION,
ROWSTATUS,
SESSION_ID,
SN,
TIMELEVEL,
<COUNTERS>
MIN_ID,
HOUR_ID,
DAY_ID,
MONTH_ID,
YEAR_ID,
DATE_ID,
UTC_DATETIME_ID,
DATETIME_ID datetime('YYYY-MM-DD HH:NN:SS')
)
FROM '/eniq/home/dcuser/ETL/<TABLE>/data_anon.csv'
ESCAPES OFF
QUOTES OFF
DELIMITED BY '|'
WITH CHECKPOINT OFF
 
