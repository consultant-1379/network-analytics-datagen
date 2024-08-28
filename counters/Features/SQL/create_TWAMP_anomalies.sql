-- DSCP Mismatch 
-- Cause: incorrectly configured intermediate router node causing DSCP remapping
-- Affected node: rn_210022
-- Node FDN: SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210022

update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_01 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_02 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_03 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_04 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_05 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_06 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_07 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_08 set dscpRecMin=0 where TwampTestSession like '210022%'
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_09 set dscpRecMin=0 where TwampTestSession like '210022%'

-- Packets Lost
-- Cause: 6 minutes of node downtime during reboot
-- Affected node: rn_210021
-- Node FDN: SubNetwork=ONRM_RootMo,SubNetwork=LRAN,MeContext=rn_210021
-- All packets lost during this time, so for profile=1, 
-- this gives 3000 samples per min lost (lostPktsFwd/rev)
-- each minute is 60000 lost milliseconds of time (lostPeriodMin/Max)
-- each period is 20 ms, so lost 'count of periods' is 50 per min (lostPeriodsFwd/Rev)

update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_01 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_02 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_03 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_04 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_05 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_06 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_07 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_08 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
update DC_E_TCU_TWAMP_TEST_SESSION_V_RAW_09 set lostPktsFwd=3000, lostPktsRev=3000, lostPeriodsFwd=50, lostPeriodMaxFwd=50, lostPeriodMinFwd=60000, lostPeriodsRev=60000, lostPeriodMaxRev=60000, lostPeriodMinRev=60000, rxPkts=0, duplicPktFwd=0, duplicPktRev=0, reorderPktFwd=0, reorderPktRev=0 where TwampTestSession like '210021%' and HOUR_ID=4 and MIN_ID=15 and DCVECTOR_INDEX in (3,4,5,6,7,8)
