explain analyze 
SELECT /*+PARALLEL(AI,4)*/* FROM (

SELECT 
  T.ACCT_ITEM_ID,
  T.ACCT_ID,
  T.USER_ID,
  T.ACCT_ITEM_TYPE_ID,
  T.BILLING_CYCLE_ID,
  T.ORIGINAL_AMOUNT,
  T.CDR_DISCOUNT,
  T.ACCT_DISCOUNT,
  T.ADJUST_AMOUNT,
  T.DUE_AMOUNT,
  T.PAY_AMOUNT,
  T.CREATE_DATE,
  T.OPT_DATE,
  T.PRICE_PLAN_ID,
  T.BILL_ID,
  T.TRADEMARK_ID,
  T.COUNTY_CODE,
  T.REGION_ID,
  T.STATE,
  M.BILL_PRIORITY  
FROM 
  AM_ACCT_ITEM_571 T,
  BS_ACCT_ITEM_TYPE M     
WHERE T.ACCT_ITEM_TYPE_ID = M.ACCT_ITEM_TYPE_ID(+)    
UNION ALL    
SELECT 
  0 as ACCT_ITEM_ID,
  T1.ACC_ID AS ACCT_ID,
  T1.USER_ID,
  T1.ACC_CODE AS ACCT_ITEM_TYPE_ID,
  202209 AS BILLING_CYCLE_ID,
  SUM(NVL(T1.TOTAL_FEE, 0)) AS ORIGINAL_AMOUNT,  0 AS CDR_DISCOUNT,
  SUM(0 - NVL(T1.DISCOUNT_FEE, 0)) AS ACCT_DISCOUNT,
  SUM(0 - NVL(T1.ADJUST_FEE, 0)) AS ADJUST_AMOUNT,
  SUM(NVL(T1.TOTAL_FEE, 0) - NVL(T1.DISCOUNT_FEE, 0) -    NVL(T1.ADJUST_FEE, 0) - NVL(T1.DERATED_FEE, 0)) AS DUE_AMOUNT,
  SUM((NVL(T1.CARD_PAYED_FEE, 0) + NVL(T1.OTHER_PAYED_FEE, 0))) AS PAY_AMOUNT,
  SYSDATE AS CREATE_DATE,
  SYSDATE AS OPT_DATE,
  MIN(PLAN_ID) AS PRICE_PLAN_ID,
  MIN(T1.BILL_ID) AS BILL_ID,
  MIN(T1.TRADEMARK) AS TRADEMARK_ID,
  ' ' AS COUNTY_CODE,
  '571' AS REGION_ID,
  '1' AS STATE,
  99 AS BILL_PRIORITY     
FROM TMP_USER_BILL_DTL_571_202208 T1     
GROUP BY 
  T1.BILL_CODE,
  T1.ACC_ID,
  T1.USER_ID,
  T1.ACC_CODE
  
) AI 
WHERE 1 = 1  
AND MOD(ACCT_ID,  10) = 1 
ORDER BY 
  ACCT_ID,
  BILLING_CYCLE_ID,
  USER_ID,
  BILL_PRIORITY 
limit 1000;
  
 Limit  (cost=60504.61..60507.11 rows=1000 width=546) (actual time=560.032..560.282 rows=1000 loops=1)
   ->  Sort  (cost=60504.61..60532.19 rows=11031 width=546) (actual time=560.031..560.238 rows=1000 loops=1)
         Sort Key: t.acct_id, t.billing_cycle_id, t.user_id, m.bill_priority
         Sort Method: top-N heapsort  Memory: 190kB
         ->  Append  (cost=1000.29..59789.48 rows=11031 width=546) (actual time=0.772..520.466 rows=205106 loops=1)
               ->  Gather  (cost=1000.29..54701.48 rows=10189 width=119) (actual time=0.771..415.572 rows=188246 loops=1)
                     Workers Planned: 3
                     Workers Launched: 3
                     ->  Nested Loop Left Join  (cost=0.29..52682.58 rows=3287 width=119) (actual time=0.101..391.106 rows=47062 loops=4)
                           ->  Parallel Seq Scan on am_acct_item_571 t  (cost=0.00..51480.20 rows=3287 width=116) (actual time=0.042..265.215 rows=47062 loops=4)
                                 Filter: (mod(acct_id, '10'::numeric) = '1'::numeric)
                                 Rows Removed by Filter: 462382
                           ->  Index Scan using bs_acct_item_type_pkey on bs_acct_item_type m  (cost=0.29..0.37 rows=1 width=9) (actual time=0.002..0.002 rows=1 loops=188246)
                                 Index Cond: (acct_item_type_id = t.acct_item_type_id)
               ->  Subquery Scan on "*SELECT* 2"  (cost=4733.52..4930.96 rows=842 width=513) (actual time=21.308..95.697 rows=16860 loops=1)
                     ->  Finalize GroupAggregate  (cost=4733.52..4914.12 rows=842 width=407) (actual time=21.305..90.898 rows=16860 loops=1)
                           Group Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                           ->  Gather Merge  (cost=4733.52..4851.05 rows=840 width=279) (actual time=21.267..42.232 rows=16860 loops=1)
                                 Workers Planned: 5
                                 Workers Launched: 5
                                 ->  Partial GroupAggregate  (cost=3733.44..3749.82 rows=168 width=279) (actual time=16.013..26.482 rows=2810 loops=6)
                                       Group Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                                       ->  Sort  (cost=3733.44..3733.86 rows=168 width=69) (actual time=15.982..16.163 rows=2810 loops=6)
                                             Sort Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                                             Sort Method: quicksort  Memory: 634kB
                                             Worker 0:  Sort Method: quicksort  Memory: 456kB
                                             Worker 1:  Sort Method: quicksort  Memory: 450kB
                                             Worker 2:  Sort Method: quicksort  Memory: 467kB
                                             Worker 3:  Sort Method: quicksort  Memory: 460kB
                                             Worker 4:  Sort Method: quicksort  Memory: 483kB
                                             ->  Parallel Seq Scan on tmp_user_bill_dtl_571_202208 t1  (cost=0.00..3727.23 rows=168 width=69) (actual time=0.026..14.108 rows=2810 loops=6)
                                                   Filter: (mod(acc_id, '10'::numeric) = '1'::numeric)
                                                   Rows Removed by Filter: 25258

 Planning Time: 6.471 ms
 Execution Time: 560.636 ms
(35 rows)

=========================================

explain analyze 
SELECT /*+PARALLEL(AI,4)*/* FROM (

SELECT 
  T.ACCT_ITEM_ID,
  T.ACCT_ID,
  T.USER_ID,
  T.ACCT_ITEM_TYPE_ID,
  T.BILLING_CYCLE_ID,
  T.ORIGINAL_AMOUNT,
  T.CDR_DISCOUNT,
  T.ACCT_DISCOUNT,
  T.ADJUST_AMOUNT,
  T.DUE_AMOUNT,
  T.PAY_AMOUNT,
  T.CREATE_DATE,
  T.OPT_DATE,
  T.PRICE_PLAN_ID,
  T.BILL_ID,
  T.TRADEMARK_ID,
  T.COUNTY_CODE,
  T.REGION_ID,
  T.STATE,
  M.BILL_PRIORITY  
FROM 
  AM_ACCT_ITEM_571 T,
  BS_ACCT_ITEM_TYPE M     
WHERE T.ACCT_ITEM_TYPE_ID = M.ACCT_ITEM_TYPE_ID(+)    
UNION ALL    
SELECT 
  0 as ACCT_ITEM_ID,
  T1.ACC_ID AS ACCT_ID,
  T1.USER_ID,
  T1.ACC_CODE AS ACCT_ITEM_TYPE_ID,
  202209 AS BILLING_CYCLE_ID,
  SUM(NVL(T1.TOTAL_FEE, 0)) AS ORIGINAL_AMOUNT,  0 AS CDR_DISCOUNT,
  SUM(0 - NVL(T1.DISCOUNT_FEE, 0)) AS ACCT_DISCOUNT,
  SUM(0 - NVL(T1.ADJUST_FEE, 0)) AS ADJUST_AMOUNT,
  SUM(NVL(T1.TOTAL_FEE, 0) - NVL(T1.DISCOUNT_FEE, 0) -    NVL(T1.ADJUST_FEE, 0) - NVL(T1.DERATED_FEE, 0)) AS DUE_AMOUNT,
  SUM((NVL(T1.CARD_PAYED_FEE, 0) + NVL(T1.OTHER_PAYED_FEE, 0))) AS PAY_AMOUNT,
  SYSDATE AS CREATE_DATE,
  SYSDATE AS OPT_DATE,
  MIN(PLAN_ID) AS PRICE_PLAN_ID,
  MIN(T1.BILL_ID) AS BILL_ID,
  MIN(T1.TRADEMARK) AS TRADEMARK_ID,
  ' ' AS COUNTY_CODE,
  '571' AS REGION_ID,
  '1' AS STATE,
  99 AS BILL_PRIORITY     
FROM TMP_USER_BILL_DTL_571_202208 T1     
GROUP BY 
  T1.BILL_CODE,
  T1.ACC_ID,
  T1.USER_ID,
  T1.ACC_CODE
  
) AI 
WHERE 1 = 1  
AND MOD(ACCT_ID,  10) = 1 
ORDER BY 
  ACCT_ID,
  BILLING_CYCLE_ID,
  USER_ID,
  BILL_PRIORITY 
limit 1000;
                                                                                                                                                                    
                                                                                                                                                                    
                                                                          QUERY PLAN                                                                                
                                                                                                                                                                    
                                                                                                                                                              
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=24875.80..24876.21 rows=1000 width=0) (actual time=2664.773..2665.322 rows=1000 loops=1)
   Output: t.acct_item_id, t.acct_id, t.user_id, t.acct_item_type_id, t.billing_cycle_id, t.original_amount, t.cdr_discount, t.acct_discount, t.adjust_amount, t.due
   ->  Cluster Merge Gather  (cost=24875.80..24877.88 rows=5004 width=0) (actual time=2664.770..2665.258 rows=1000 loops=1)
         Remote node: 16387,16388,16389,16390,16391,16392
         Sort Key: t.acct_id, t.billing_cycle_id, t.user_id, m.bill_priority
         ->  Limit  (cost=24775.72..24777.80 rows=834 width=546) (actual time=0.063..0.071 rows=0 loops=1)
               Output: t.acct_item_id, t.acct_id, t.user_id, t.acct_item_type_id, t.billing_cycle_id, t.original_amount, t.cdr_discount, t.acct_discount, t.adjust_a
               Node 16388: (actual time=1155.176..1155.349 rows=1000 loops=1)
               Node 16389: (actual time=1158.427..1158.593 rows=1000 loops=1)
               Node 16390: (actual time=1386.100..1386.294 rows=1000 loops=1)
               Node 16391: (actual time=1128.066..1128.258 rows=1000 loops=1)
               Node 16387: (actual time=1188.856..1189.035 rows=1000 loops=1)
               Node 16392: (actual time=2664.288..2664.477 rows=1000 loops=1)
               ->  Sort  (cost=24775.72..24777.80 rows=834 width=546) (actual time=0.062..0.069 rows=0 loops=1)
                     Output: t.acct_item_id, t.acct_id, t.user_id, t.acct_item_type_id, t.billing_cycle_id, t.original_amount, t.cdr_discount, t.acct_discount, t.ad
                     Sort Key: t.acct_id, t.billing_cycle_id, t.user_id, m.bill_priority
                     Sort Method: quicksort  Memory: 25kB
                     Node 16388: (actual time=1155.173..1155.295 rows=1000 loops=1)
                     Node 16389: (actual time=1158.426..1158.547 rows=1000 loops=1)
                     Node 16390: (actual time=1386.099..1386.249 rows=1000 loops=1)
                     Node 16391: (actual time=1128.065..1128.214 rows=1000 loops=1)
                     Node 16387: (actual time=1188.854..1188.990 rows=1000 loops=1)
                     Node 16392: (actual time=2664.284..2664.431 rows=1000 loops=1)
                     ->  Append  (cost=17.96..24726.91 rows=834 width=546) (actual time=0.020..0.027 rows=0 loops=1)
                           Node 16388: (actual time=905.992..1088.964 rows=205106 loops=1)
                           Node 16389: (actual time=889.548..1081.956 rows=246162 loops=1)
                           Node 16390: (actual time=1124.323..1312.975 rows=226960 loops=1)
                           Node 16391: (actual time=892.749..1065.621 rows=190060 loops=1)
                           Node 16387: (actual time=959.178..1129.674 rows=182641 loops=1)
                           Node 16392: (actual time=2433.886..2605.870 rows=179690 loops=1)
                           ->  Hash Right Join  (cost=17.96..855.47 rows=0 width=119) (actual time=0.018..0.020 rows=0 loops=1)
                                 Output: t.acct_item_id, t.acct_id, t.user_id, t.acct_item_type_id, t.billing_cycle_id, t.original_amount, t.cdr_discount, t.acct_di
                                 Hash Cond: (m.acct_item_type_id = t.acct_item_type_id)
                                 Node 16388: (actual time=905.991..984.893 rows=188246 loops=1)
                                 Node 16389: (actual time=889.548..979.345 rows=229962 loops=1)
                                 Node 16390: (actual time=1124.323..1206.365 rows=210150 loops=1)
                                 Node 16391: (actual time=892.748..965.350 rows=173710 loops=1)
                                 Node 16387: (actual time=959.178..1026.879 rows=165871 loops=1)
                                 Node 16392: (actual time=2433.885..2502.537 rows=162680 loops=1)
                                 ->  Seq Scan on aicbs.bs_acct_item_type m  (cost=0.00..813.70 rows=6345 width=9) (never executed)
                                       Output: m.acct_item_type_id, m.partner_id, m.acct_item_type_code, m.acct_item_type_name, m.acct_item_type_desc, m.acct_item_t
                                       Remote node: 16387,16388,16389,16390,16391,16392
                                       Node 16388: (actual time=0.010..2.904 rows=38070 loops=1)
                                       Node 16389: (actual time=0.009..2.966 rows=38070 loops=1)
                                       Node 16390: (actual time=0.010..2.783 rows=38070 loops=1)
                                       Node 16391: (actual time=0.010..2.886 rows=38070 loops=1)
                                       Node 16387: (actual time=0.008..2.806 rows=38070 loops=1)
                                       Node 16392: (actual time=0.011..3.057 rows=38070 loops=1)
                                 ->  Hash  (cost=17.95..17.95 rows=1 width=116) (actual time=0.007..0.008 rows=0 loops=1)
                                       Output: t.acct_item_id, t.acct_id, t.user_id, t.acct_item_type_id, t.billing_cycle_id, t.original_amount, t.cdr_discount, t.a
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       Node 16388: (actual time=905.966..905.967 rows=188246 loops=1)
                                       Node 16389: (actual time=889.506..889.507 rows=229962 loops=1)
                                       Node 16390: (actual time=1124.278..1124.279 rows=210150 loops=1)
                                       Node 16391: (actual time=892.723..892.724 rows=173710 loops=1)
                                       Node 16387: (actual time=959.154..959.155 rows=165871 loops=1)
                                       Node 16392: (actual time=2433.855..2433.856 rows=162680 loops=1)
                                       ->  Seq Scan on aicbs.am_acct_item_571 t  (cost=0.00..17.95 rows=1 width=116) (actual time=0.007..0.007 rows=0 loops=1)
                                             Output: t.acct_item_id, t.acct_id, t.user_id, t.acct_item_type_id, t.billing_cycle_id, t.original_amount, t.cdr_discoun
                                             Filter: (mod(t.acct_id, '10'::numeric) = '1'::numeric)
                                             Remote node: 16388,16389,16390,16391,16387,16392
                                             Node 16388: (actual time=0.029..835.733 rows=188246 loops=1)
                                             Node 16389: (actual time=0.025..800.502 rows=229962 loops=1)
                                             Node 16390: (actual time=0.024..1047.470 rows=210150 loops=1)
                                             Node 16391: (actual time=0.027..825.888 rows=173710 loops=1)
                                             Node 16387: (actual time=0.036..897.871 rows=165871 loops=1)
                                             Node 16392: (actual time=0.020..2374.183 rows=162680 loops=1)
                           ->  Subquery Scan on "*SELECT* 2"  (cost=23136.24..23867.26 rows=833 width=513) (actual time=0.001..0.004 rows=0 loops=1)
                                 Output: (0)::numeric, "*SELECT* 2".acct_id, "*SELECT* 2".user_id, "*SELECT* 2".acct_item_type_id, (202209)::numeric, "*SELECT* 2".o
                                 Node 16388: (actual time=20.589..95.098 rows=16860 loops=1)
                                 Node 16389: (actual time=20.908..92.822 rows=16200 loops=1)
                                 Node 16390: (actual time=21.796..97.739 rows=16810 loops=1)
                                 Node 16391: (actual time=20.612..92.806 rows=16350 loops=1)
                                 Node 16387: (actual time=20.773..94.935 rows=16770 loops=1)
                                 Node 16392: (actual time=21.256..96.144 rows=17010 loops=1)
                                 ->  Finalize GroupAggregate  (cost=23136.24..23850.60 rows=139 width=407) (actual time=0.000..0.002 rows=0 loops=1)
                                       Output: 0, t1.acc_id, t1.user_id, t1.acc_code, 202209, sum(nvl(t1.total_fee, '0'::numeric(16,0))), 0, sum(('0'::numeri
                                       Group Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                                       Node 16388: (actual time=20.586..90.099 rows=16860 loops=1)
                                       Node 16389: (actual time=20.904..88.329 rows=16200 loops=1)
                                       Node 16390: (actual time=21.792..92.805 rows=16810 loops=1)
                                       Node 16391: (actual time=20.608..88.130 rows=16350 loops=1)
                                       Node 16387: (actual time=20.769..90.442 rows=16770 loops=1)
                                       Node 16392: (actual time=21.252..91.459 rows=17010 loops=1)
                                       ->  Gather Merge  (cost=23136.24..23669.08 rows=4165 width=279) (never executed)
                                             Output: t1.acc_id, t1.user_id, t1.acc_code, t1.bill_code, (PARTIAL sum(nvl(t1.total_fee, '0'::numeric(16,0)))), 
                                             Workers Planned: 5
                                             Workers Launched: 0
                                             Node 16388: (actual time=20.556..42.538 rows=16860 loops=1)
                                             Node 16389: (actual time=20.874..41.663 rows=16200 loops=1)
                                             Node 16390: (actual time=21.765..43.620 rows=16810 loops=1)
                                             Node 16391: (actual time=20.580..41.731 rows=16350 loops=1)
                                             Node 16387: (actual time=20.745..42.213 rows=16770 loops=1)
                                             Node 16392: (actual time=21.224..43.653 rows=17010 loops=1)
                                             ->  Partial GroupAggregate  (cost=22136.17..22167.43 rows=833 width=279) (never executed)
                                                   Output: t1.acc_id, t1.user_id, t1.acc_code, t1.bill_code, PARTIAL sum(nvl(t1.total_fee, '0'::numeric(16,0)
                                                   Group Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                                                   Node 16388: (actual time=15.343..25.933 rows=2810 loops=6)
                                                     Worker 0: actual time=13.636..19.328 rows=2288 loops=1
                                                     Worker 1: actual time=13.678..19.576 rows=2353 loops=1
                                                     Worker 2: actual time=14.751..29.497 rows=2721 loops=1
                                                     Worker 3: actual time=14.953..28.461 rows=2687 loops=1
                                                     Worker 4: actual time=14.957..27.455 rows=2685 loops=1
                                                   Node 16389: (actual time=15.426..24.689 rows=2700 loops=6)
                                                     Worker 0: actual time=14.174..25.724 rows=2358 loops=1
                                                     Worker 1: actual time=14.319..20.519 rows=2471 loops=1
                                                     Worker 2: actual time=14.561..24.549 rows=2420 loops=1
                                                     Worker 3: actual time=14.311..20.381 rows=2425 loops=1
                                                     Worker 4: actual time=14.790..25.547 rows=2427 loops=1
                                                   Node 16390: (actual time=16.151..24.434 rows=2802 loops=6)
                                                     Worker 0: actual time=14.913..22.934 rows=2439 loops=1
                                                     Worker 1: actual time=14.923..23.570 rows=2483 loops=1
                                                     Worker 2: actual time=15.301..21.813 rows=2582 loops=1
                                                     Worker 3: actual time=15.054..23.570 rows=2534 loops=1
                                                     Worker 4: actual time=15.414..21.764 rows=2517 loops=1
                                                   Node 16391: (actual time=15.127..26.443 rows=2725 loops=6)
                                                     Worker 0: actual time=13.415..19.117 rows=2343 loops=1
                                                     Worker 1: actual time=14.213..28.762 rows=2430 loops=1
                                                     Worker 2: actual time=14.336..26.736 rows=2546 loops=1
                                                     Worker 3: actual time=14.343..26.324 rows=2531 loops=1
                                                     Worker 4: actual time=14.342..26.835 rows=2505 loops=1
                                                   Node 16387: (actual time=15.026..24.351 rows=2795 loops=6)
                                                     Worker 0: actual time=13.769..23.682 rows=2440 loops=1
                                                     Worker 1: actual time=13.823..19.935 rows=2462 loops=1
                                                     Worker 2: actual time=13.799..19.906 rows=2424 loops=1
                                                     Worker 3: actual time=14.232..25.118 rows=2582 loops=1
                                                     Worker 4: actual time=14.240..25.711 rows=2596 loops=1
                                                   Node 16392: (actual time=15.552..26.711 rows=2835 loops=6)
                                                     Worker 0: actual time=14.082..29.223 rows=2503 loops=1
                                                     Worker 1: actual time=14.325..20.556 rows=2515 loops=1
                                                     Worker 2: actual time=14.719..29.457 rows=2567 loops=1
                                                     Worker 3: actual time=14.408..20.717 rows=2514 loops=1
                                                     Worker 4: actual time=15.021..28.316 rows=2652 loops=1
                                                   ->  Sort  (cost=22136.17..22136.58 rows=167 width=69) (never executed)
                                                         Output: t1.acc_id, t1.user_id, t1.acc_code, t1.bill_code, t1.total_fee, t1.discount_fee, t1.adjust_fee, t1.
                                                         Sort Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                                                         Node 16388: (actual time=15.318..15.506 rows=2810 loops=6)
                                                           Worker 0: actual time=13.608..13.704 rows=2288 loops=1
                                                           Worker 1: actual time=13.652..13.766 rows=2353 loops=1
                                                           Worker 2: actual time=14.725..14.954 rows=2721 loops=1
                                                           Worker 3: actual time=14.928..15.164 rows=2687 loops=1
                                                           Worker 4: actual time=14.932..15.133 rows=2685 loops=1
                                                         Node 16389: (actual time=15.399..15.590 rows=2700 loops=6)
                                                           Worker 0: actual time=14.143..14.373 rows=2358 loops=1
                                                           Worker 1: actual time=14.291..14.417 rows=2471 loops=1
                                                           Worker 2: actual time=14.535..14.728 rows=2420 loops=1
                                                           Worker 3: actual time=14.278..14.402 rows=2425 loops=1
                                                           Worker 4: actual time=14.765..14.971 rows=2427 loops=1
                                                         Node 16390: (actual time=16.125..16.289 rows=2802 loops=6)
                                                           Worker 0: actual time=14.886..15.020 rows=2439 loops=1
                                                           Worker 1: actual time=14.897..15.042 rows=2483 loops=1
                                                           Worker 2: actual time=15.273..15.383 rows=2582 loops=1
                                                           Worker 3: actual time=15.024..15.215 rows=2534 loops=1
                                                           Worker 4: actual time=15.386..15.497 rows=2517 loops=1
                                                         Node 16391: (actual time=15.102..15.301 rows=2725 loops=6)
                                                           Worker 0: actual time=13.389..13.485 rows=2343 loops=1
                                                           Worker 1: actual time=14.187..14.426 rows=2430 loops=1
                                                           Worker 2: actual time=14.310..14.520 rows=2546 loops=1
                                                           Worker 3: actual time=14.318..14.509 rows=2531 loops=1
                                                           Worker 4: actual time=14.317..14.515 rows=2505 loops=1
                                                         Node 16387: (actual time=15.001..15.166 rows=2795 loops=6)
                                                           Worker 0: actual time=13.742..13.905 rows=2440 loops=1
                                                           Worker 1: actual time=13.796..13.896 rows=2462 loops=1
                                                           Worker 2: actual time=13.770..13.875 rows=2424 loops=1
                                                           Worker 3: actual time=14.205..14.378 rows=2582 loops=1
                                                           Worker 4: actual time=14.215..14.398 rows=2596 loops=1
                                                         Node 16392: (actual time=15.526..15.722 rows=2835 loops=6)
                                                           Worker 0: actual time=14.052..14.302 rows=2503 loops=1
                                                           Worker 1: actual time=14.299..14.402 rows=2515 loops=1
                                                           Worker 2: actual time=14.694..14.934 rows=2567 loops=1
                                                           Worker 3: actual time=14.377..14.481 rows=2514 loops=1
                                                           Worker 4: actual time=14.993..15.213 rows=2652 loops=1
                                                         ->  Parallel Seq Scan on aicbs.tmp_user_bill_dtl_571_202208 t1  (cost=0.00..22130.00 rows=167 width=69) (ne
                                                               Output: t1.acc_id, t1.user_id, t1.acc_code, t1.bill_code, t1.total_fee, t1.discount_fee, t1.adjust_fe
                                                               Filter: (mod(t1.acc_id, '10'::numeric) = '1'::numeric)
                                                               Remote node: 16388,16389,16390,16391,16387,16392
                                                               Node 16388: (actual time=0.028..13.469 rows=2810 loops=6)
                                                                 Worker 0: actual time=0.028..12.146 rows=2288 loops=1
                                                                 Worker 1: actual time=0.029..12.132 rows=2353 loops=1
                                                                 Worker 2: actual time=0.028..13.060 rows=2721 loops=1
                                                                 Worker 3: actual time=0.025..13.253 rows=2687 loops=1
                                                                 Worker 4: actual time=0.028..13.260 rows=2685 loops=1
                                                               Node 16389: (actual time=0.030..13.572 rows=2700 loops=6)
                                                                 Worker 0: actual time=0.039..12.581 rows=2358 loops=1
                                                                 Worker 1: actual time=0.030..12.706 rows=2471 loops=1
                                                                 Worker 2: actual time=0.028..12.961 rows=2420 loops=1
                                                                 Worker 3: actual time=0.032..12.723 rows=2425 loops=1
                                                                 Worker 4: actual time=0.032..13.166 rows=2427 loops=1
                                                               Node 16390: (actual time=0.031..14.266 rows=2802 loops=6)
                                                                 Worker 0: actual time=0.027..13.345 rows=2439 loops=1
                                                                 Worker 1: actual time=0.031..13.342 rows=2483 loops=1
                                                                 Worker 2: actual time=0.030..13.616 rows=2582 loops=1
                                                                 Worker 3: actual time=0.038..13.390 rows=2534 loops=1
                                                                 Worker 4: actual time=0.041..13.780 rows=2517 loops=1
                                                               Node 16391: (actual time=0.029..13.294 rows=2725 loops=6)
                                                                 Worker 0: actual time=0.033..11.894 rows=2343 loops=1
                                                                 Worker 1: actual time=0.028..12.620 rows=2430 loops=1
                                                                 Worker 2: actual time=0.030..12.686 rows=2546 loops=1
                                                                 Worker 3: actual time=0.030..12.703 rows=2531 loops=1
                                                                 Worker 4: actual time=0.035..12.703 rows=2505 loops=1
                                                               Node 16387: (actual time=0.032..13.118 rows=2795 loops=6)
                                                                 Worker 0: actual time=0.030..12.173 rows=2440 loops=1
                                                                 Worker 1: actual time=0.031..12.191 rows=2462 loops=1
                                                                 Worker 2: actual time=0.036..12.214 rows=2424 loops=1
                                                                 Worker 3: actual time=0.039..12.563 rows=2582 loops=1
                                                                 Worker 4: actual time=0.039..12.568 rows=2596 loops=1
                                                               Node 16392: (actual time=0.026..13.633 rows=2835 loops=6)
                                                                 Worker 0: actual time=0.024..12.457 rows=2503 loops=1
                                                                 Worker 1: actual time=0.024..12.692 rows=2515 loops=1
                                                                 Worker 2: actual time=0.032..13.031 rows=2567 loops=1
                                                                 Worker 3: actual time=0.025..12.768 rows=2514 loops=1
                                                                 Worker 4: actual time=0.032..13.296 rows=2652 loops=1
 Planning Time: 0.525 ms
 Execution Time: 2669.876 ms
(214 rows)

Time: 2671.885 ms (00:02.672)




prepare s1 (int) as select * from ta where c1 = $1 for update;

execute s1(1)



create or replace procedure plpg_commit_test2 ()
language plpgsql
as $$
declare
    l_id    numeric;
begin
    execute 'truncate table plorasql_test1';
    commit_pg;
    INSERT into plorasql_test1 values (1);
    rollback_pg;
    INSERT into plorasql_test1 values (3);
    commit_pg;
end;
$$;


prepare s1 (int) as select * from ta where c1 = $1 for update;




do $$
declare
v_idx integer := 1;
begin
  while v_idx < 30 loop
    v_idx = v_idx+1;
    execute s1(v_idx);
  end loop;
end $$;


2、语法:
while condition loop
    statement;
end loop;

案例：
    prepare s1 (int) as select * from t where a = $1 for update;
    
create or replace function while_test(n integer)
returns integer as $$
declare counter integer:=0;
begin
    if (n<0) then
        return 0;
    end if;

    while counter<n loop
        counter := counter + 1;
        execute s1(counter);
    end loop;
    return counter;
end; $$
language plpgsql;

select while_test(4);


export PGHOST=10.1.207.165
export PGPORT=65032
export PGDATABASE=postgres
export PGUSER=wl
export PGPASSWORD=wl
export PGHOST=""
export PGPORT=""
export PGDATABASE=""
export PGUSER=""
export PGPASSWORD=""

create table pg_test (a1 serial,a2 int,a3 varchar(20),a4 timestamp); 

insert into pg_test(a2,a3,a4) select (random()*(2*10^5)),substr('abcdefghijklmnopqrstuvwxyz',1, (random()*26)::integer),now();


insert into t select i from generate_series(1,100000) i;



with t as (
            select
                max(trade_date) as trade_date
            from
                dw_trade_date
            where
                exchange_code = 'SSE'
            group by
               to_char(trade_date, 'yyyyMM')
        ), t2 as (
        select
            tfsti.module_id,
            tfsti.type_id,
            tfsti.security_id,
            tfsti.indicator_id,
            tfsti.indicator_date,
            tfsti.indicator_value
        from
            ods_robo_advisor.three_factor_strategy_text_indicator tfsti
                inner join
             t on tfsti.indicator_date = t.trade_date 
        where
            tfsti.module_id = 'DSYP'
        union all
        select
            module_id,
            type_id,
            security_id,
            indicator_id,
            indicator_date,
            indicator_value
        from
            ods_robo_advisor.three_factor_strategy_text_indicator tfsti
        where
            tfsti.module_id != 'DSYP') select * from t2 where module_id='DSYP'




CREATE TABLE aptp_collection_config (config_id integer NOT NULL,config_name character varying(128),function_name character varying(128),type character varying(32),scope character varying(1),collection_sql text
)
DISTRIBUTE BY HASH(config_id);
--
-- Data for Name: aptp_collection_config; Type: TABLE DATA; Schema: aptp_repo; Owner: cidbops
--
insert into aptp_collection_config values
(2  , 'PG HBA rules         ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'C', 'insert into aptp_hba_rules (snap_id,db_id,node_name,line_number,type,database,user_name,address,netmask,auth_method,options,error) select $1 as snap_id, $2 as db_id, $3 as node_name, line_number, type, database, user_name, address, netmask, auth_method, options, error from #SCHEMA#.aptp_pg_hba_file_rules'),
(6  , 'Archiver statistics  ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'A', 'insert into aptp_stat_archivers (snap_id,db_id,node_name,archived_count,last_archived_wal,last_archived_time,failed_count,last_failed_wal,last_failed_time,stats_reset) select $1 as snap_id, $2 as db_id,$3 as node_name, archived_count, last_archived_wal, last_archived_time, failed_count, last_failed_wal, last_failed_time, stats_reset from #SCHEMA#.aptp_pg_stat_archiver'),
(7  , 'BG writer statistics ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'A', 'insert into aptp_stat_bgwriters (snap_id,db_id,node_name,checkpoints_timed,checkpoints_req,checkpoint_write_time,checkpoint_sync_time,buffers_checkpoint,buffers_clean,max_written_clean,buffers_backend,buffers_backend_fsync,buffers_alloc,stats_reset) select $1 as snap_id, $2 as db_id,$3 as node_name, checkpoints_timed, checkpoints_req, checkpoint_write_time, checkpoint_sync_time, buffers_checkpoint, buffers_clean, maxwritten_clean, buffers_backend, buffers_backend_fsync, buffers_alloc, stats_reset from #SCHEMA#.aptp_pg_stat_bgwriter'),
(11 , 'PG WAL               ', 'aptp_gather_pg_wal       ', 'SNAPSHOT', 'A', ''),
(12 , 'Statement statistics ', 'aptp_gather_top_sql      ', 'SNAPSHOT', 'C', ''),
(14 , 'Active sessions      ', 'aptp_gather_db_sessions  ', 'SESSION', 'C', ''),
(15 , 'Performance metrics  ', 'aptp_gather_perf_metrics ', 'PERFORMANCE', 'A', ''),
(3  , 'User shadow          ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'S',  'insert into aptp_shadows (snap_id,db_id,user_name,can_createdb,is_super,can_replicat,passwd,valid_until) select $1 as snap_id, $2 as db_id, usename as user_name, usecreatedb as can_createdb, usesuper as is_super, userepl as can_replicat, passwd, valuntil as valid_until from #SCHEMA#.aptp_pg_shadow');

(5  , 'Table statistics     ', 'aptp_gather_db_common    ', 'SNAPSHOT   ', 'D',  'insert into aptp_stat_tables (snap_id,db_id,node_name,table_id,schema_name,table_name,table_page,table_tuple,seq_scan,seq_tup_read,idx_scan,idx_tup_fetch,n_tup_ins,n_tup_upd,n_tup_del,n_tup_hot_upd,n_live_tup,n_dead_tup,n_mod_since_analyze,last_vacuum,last_autovacuum,last_analyze,last_autoanalyze,vacuum_count,autovacuum_count,analyze_count,autoanalyze_count,heap_blks_read,heap_blks_hit,idx_blks_read,idx_blks_hit,toast_blks_read,toast_blks_hit,tidx_blks_read,tidx_blks_hit) SELECT $1 AS snap_id,$2 AS db_id,$3 as node_name,table_id,schema_name,table_name,table_page,table_tuple,seq_scan,seq_tup_read,idx_scan,idx_tup_fetch,n_tup_ins,n_tup_upd,n_tup_del,n_tup_hot_upd,n_live_tup,n_dead_tup,n_mod_since_analyze,last_vacuum,last_autovacuum,last_analyze,last_autoanalyze,vacuum_count,autovacuum_count,analyze_count,autoanalyze_count,heap_blks_read,heap_blks_hit,idx_blks_read,idx_blks_hit,toast_blks_read,toast_blks_hit,tidx_blks_read,tidx_blks_hit from #SCHEMA#.aptp_tables');
(1  , 'PG setting           ', 'aptp_gather_db_common    ', 'SNAPSHOT   ', 'A',  'insert into aptp_settings (snap_id,db_id,node_name,name,setting,unit,context,type,source,source_file,source_line,pending_restart) select $1 as snap_id, $2 as db_id, $3 as node_name, name, setting, unit, context, vartype as type, source, sourcefile as source_file, sourceline as source_line, pending_restart from #SCHEMA#.aptp_pg_settings where source <> \'default\' or name = \'block_size\''),
(4  , 'Index statistics     ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'D',  'insert into aptp_stat_indexes (snap_id,db_id,node_name,table_id,index_id,schema_name,table_name,index_name,index_page,index_tuple,index_scan,index_tuple_read,index_tuple_fetch,idx_blks_read,idx_blks_hit) select $1 AS snap_id,$2 AS db_id,$3 as node_name,table_id,index_id,schema_name,table_name,index_name,index_page,index_tuple,idx_scan,idx_tup_read,idx_tup_fetch,idx_blks_read,idx_blks_hit FROM #SCHEMA#.aptp_indexes'),
(8  , 'Sequences            ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'S',  'insert into aptp_sequence (snap_id,db_id,schema_name,sequence_name,sequence_owner,data_type,start_value,min_value,max_value,increment_by,cycle,cache_size,last_value) select $1 as snap_id, $2 as db_id, schemaname as schema_name, sequencename as sequence_name, sequenceowner as sequence_owner, data_type, start_value, min_value, max_value, increment_by, cycle, cache_size, last_value from #SCHEMA#.aptp_pg_sequences'),
(9  , 'PG LOG summary       ', 'aptp_gather_db_common    ', 'SNAPSHOT', 'A',  'insert into aptp_pg_log_summary (snap_id,db_id,node_name,user_name,database_name,connection_from,command_tag,error_severity,sql_state_code,application_name,item_cnt) select $1 as snap_id, $2 as db_id,$3 as node_name, user_name,database_name,connection_from,command_tag,error_severity,sql_state_code,application_name,item_cnt from #SCHEMA#.aptp_vw_log_summary'),
(13 , 'Base metrics         ', 'aptp_gather_base_metrics ', 'SNAPSHOT', 'A',  '');

(10 , 'PG LOG refresh       ', 'aptp_gather_db_common    ', 'SNAPSHOT   ', 'S',  'update #SCHEMA#.APTP_LOG_LAST_TIME set last_time = to_char(clock_timestamp(), \'yyyy-mm-dd HH24:MI:SS\''),


DROP FUNCTION if exists testtt();
CREATE OR REPLACE FUNCTION testtt()
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    l_node_item_temp       record;
BEGIN
    execute 'drop table if exists test1 cascade';
    execute 'create table if not exists test1 as select * from aptp_collection_config with no data';
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = 'SNAPSHOT'
                          order by config_id
    loop
        insert into test1(config_id, config_name, function_name, scope) values (l_config_item.config_id, l_config_item.config_name,l_config_item.function_name,l_config_item.scope);
    end loop;
END;
$$ language plpgsql;

select testtt();



shared_preload_libraries = 'pg_stat_statements,adb_stat_statements'

=====================


drop table if exists aptp_collection_config;
CREATE TABLE aptp_collection_config (config_id integer NOT NULL,config_name character varying(128),function_name character varying(128),type character varying(32),scope character varying(1),collection_sql text
);

DROP FUNCTION if exists static_static();
CREATE OR REPLACE FUNCTION static_static()
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = 'c'
                          order by config_id
    loop
        raise notice '####%',cnt;
    end loop;
END;
$$ language plpgsql;

DROP FUNCTION if exists static_dynamic();
CREATE OR REPLACE FUNCTION static_dynamic()
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = 'c'
                          order by config_id
    loop
        insert into testabcd(config_id, config_name, function_name, scope) values (l_config_item.config_id, l_config_item.config_name,l_config_item.function_name,l_config_item.scope);
    end loop;
END;
$$ language plpgsql;

DROP FUNCTION if exists static_mix();
CREATE OR REPLACE FUNCTION static_mix()
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = 'c'
                          order by config_id
    loop
        cnt = cnt + 1;
        raise notice '####%',cnt;
        insert into testabcd(config_id, config_name, function_name, scope) values (l_config_item.config_id, l_config_item.config_name,l_config_item.function_name,l_config_item.scope);
    end loop;
END;
$$ language plpgsql;

DROP FUNCTION if exists dynamic_static(text);
CREATE OR REPLACE FUNCTION dynamic_static(a text)
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = a
                          order by config_id
    loop
        raise notice '####%',cnt;
    end loop;
END;
$$ language plpgsql;

DROP FUNCTION if exists dynamic_dynamic(text);
CREATE OR REPLACE FUNCTION dynamic_dynamic(a text)
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = a
                          order by config_id
    loop
        insert into testabcd(config_id, config_name, function_name, scope) values (l_config_item.config_id, l_config_item.config_name,l_config_item.function_name,l_config_item.scope);
    end loop;
END;
$$ language plpgsql;

DROP FUNCTION if exists dynamic_mix(text);
CREATE OR REPLACE FUNCTION dynamic_mix(a text)
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    for l_config_item in select config_id, config_name, function_name, scope
                           from aptp_collection_config
                          where type = a
                          order by config_id
    loop
        cnt = cnt + 1;
        raise notice '####%',cnt;
        insert into testabcd(config_id, config_name, function_name, scope) values (l_config_item.config_id, l_config_item.config_name,l_config_item.function_name,l_config_item.scope);
    end loop;
END;
$$ language plpgsql;

DROP FUNCTION if exists normal_function();
CREATE OR REPLACE FUNCTION normal_function()
RETURNS void
AS $$
DECLARE
    l_config_item     record;
    cnt int:=0;
BEGIN
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'drop table if exists testabcd cascade';
    cnt = cnt + 1;
    raise notice '####%',cnt;
    execute 'create table if not exists testabcd as select * from aptp_collection_config with no data';
END;
$$ language plpgsql;

--test001
truncate aptp_collection_config;
insert into aptp_collection_config select generate_series(1,10),'a','b','c','d','e';
select static_static();
select count(*) from testabcd;

--test002
select static_dynamic();
select count(*) from testabcd;

--test003
select static_mix();
select count(*) from testabcd;

--test004
truncate aptp_collection_config;
insert into aptp_collection_config select generate_series(1,60),'a','b','c','d','e';
select static_static();
select count(*) from testabcd;

--test005
select static_dynamic();
select count(*) from testabcd;

--test006
select static_mix();
select count(*) from testabcd;

--test007
truncate aptp_collection_config;
insert into aptp_collection_config select generate_series(1,110),'a','b','c','d','e';
select static_static();
select count(*) from testabcd;

--test008
select static_dynamic();
select count(*) from testabcd;

--test009
select static_mix();
select count(*) from testabcd;

--test010
truncate aptp_collection_config;
insert into aptp_collection_config select generate_series(1,10),'a','b','c','d','e';
select dynamic_static('c');
select count(*) from testabcd;

--test011
select dynamic_dynamic('c');
select count(*) from testabcd;

--test012
select dynamic_mix('c');
select count(*) from testabcd;

--test013
truncate aptp_collection_config;
insert into aptp_collection_config select generate_series(1,60),'a','b','c','d','e';
select dynamic_static('c');
select count(*) from testabcd;

--test014
select dynamic_dynamic('c');
select count(*) from testabcd;

--test015
select dynamic_mix('c');
select count(*) from testabcd;

--test016
truncate aptp_collection_config;
insert into aptp_collection_config select generate_series(1,110),'a','b','c','d','e';
select dynamic_static('c');
select count(*) from testabcd;

--test017
select dynamic_dynamic('c');
select count(*) from testabcd;

--test018
select dynamic_mix('c');
select count(*) from testabcd;

--test019
select normal_function();
select count(*) from testabcd;

--test020
insert into testabcd select * from aptp_collection_config;
select count(*) from testabcd;

--cleanup
drop table if exists aptp_collection_config;
drop table if exists testabcd;
DROP FUNCTION if exists static_static();
DROP FUNCTION if exists static_dynamic();
DROP FUNCTION if exists static_mix();
DROP FUNCTION if exists dynamic_static(text);
DROP FUNCTION if exists dynamic_dynamic(text);
DROP FUNCTION if exists dynamic_mix(text);
DROP FUNCTION if exists normal_function();


ALTER TABLE test1 ALTER COLUMN collection_sql SET DEFAULT 'default_value';




(
  select offer_name from yd.offer where offer_id=a.prod_offer_id and manage_region_id='662') offer_name
from yd.rpt_comm_cm_msdisc a,
yd.tt_01 b
where a.serv_id=b.serv_id;



create schema crm_cfguse;

create table crm_cfguse.offer (
  disc_type                varchar(80)   ,
  eff_date                 date           ,
  status_date              date           ,
  prod_num_desc            varchar(4000) ,
  item_type                varchar(12)   ,
  remark                   varchar(4000) ,
  update_staff             numeric(22,0)         ,
  offer_sys_type           varchar(80)   ,
  manage_grade             varchar(120)  ,
  offer_provider_id        varchar(120)  ,
  pricing_plan_id          numeric(22,0)         ,
  disc_dyn                 varchar(12)   ,
  offer_desc               varchar(4000) ,
  crt_version              varchar(256)  ,
  status_cd                varchar(80)   ,
  exp_date                 date           ,
  ext_offer_id             varchar(120)  ,
  is_independent           varchar(80)   ,
  create_date              date           ,
  list_stat                varchar(12)   ,
  offer_type               varchar(80)   ,
  offer_sys_name           varchar(1000) ,
  is_add                   varchar(12)   ,
  is_ext                   varchar(12)   ,
  prod_offer_code          varchar(256)  ,
  use_version              varchar(256)  ,
  value_added_flag         varchar(80)   ,
  create_staff             numeric(22,0)         ,
  list_date                date           ,
  offer_id                 numeric(22,0)         ,
  offer_name               varchar(1000) ,
  update_date              date           ,
  brand_id                 numeric(22,0)         ,
  initial_cred_value       numeric(22,0)         ,
  post_id                  numeric(22,0)         ,
  min_num                  numeric(22,0)         ,
  offer_sys_py_name        varchar(1000) ,
  cancel_mutex_offer       varchar(80)   ,
  offer_nbr                varchar(120)  ,
  manage_region_id         numeric(22,0)         ,
  package_name             varchar(1000) ,
  max_num                  numeric(22,0)         ,
  city_id                  varchar(24)   ,
  lastest_op_ts            date           ,
  update_ts                date           ,
  constraint offer_pkey PRIMARY KEY (offer_id, city_id));
-- DISTRIBUTE BY HASH(offer_id) TO NODE(dm1_1, dm2_1, dm3_1, dm4_1, dm5_1, dm6_1, dm7_1, dm8_1)

create index crm_cfguse_idx_zzp_12037 on crm_cfguse.offer (status_cd);
create index crm_cfguse_idx_zzp_12038 on crm_cfguse.offer (update_ts);
create index crm_cfguse_idx_zzp_33350233 on crm_cfguse.offer (update_date);
create index crm_cfguse_idx_zzp_8702 on crm_cfguse.offer (create_date);
create index crm_cfguse_idx_zzp_8704 on crm_cfguse.offer (status_date);
create index idx_1325583 on crm_cfguse.offer (ext_offer_id);


create schema yd;

create View yd.offer
as
SELECT offer.disc_type,
   offer.eff_date,
   offer.status_date,
   offer.prod_num_desc,
   offer.item_type,
   offer.remark,
   offer.update_staff,
   offer.offer_sys_type,
   offer.manage_grade,
   offer.offer_provider_id,
   offer.pricing_plan_id,
   offer.disc_dyn,
   offer.offer_desc,
   offer.crt_version,
   offer.status_cd,
   offer.exp_date,
   offer.ext_offer_id,
   offer.is_independent,
   offer.create_date,
   offer.list_stat,
   offer.offer_type,
   offer.offer_sys_name,
   offer.is_add,
   offer.is_ext,
   offer.prod_offer_code,
   offer.use_version,
   offer.value_added_flag,
   offer.create_staff,
   offer.list_date,
   offer.offer_id,
   offer.offer_name,
   offer.update_date,
   offer.brand_id,
   offer.initial_cred_value,
   offer.post_id,
   offer.min_num,
   offer.offer_sys_py_name,
   offer.cancel_mutex_offer,
   offer.offer_nbr,
   offer.manage_region_id,
   offer.package_name,
   offer.max_num,
   offer.city_id,
   offer.lastest_op_ts,
   offer.update_ts
  FROM crm_cfguse.offer offer;


create schema summary;

create Table summary.rpt_comm_cm_msdisc (
  cust_id                     numeric(22,0)         ,
  serv_id                     numeric(22,0)         ,
  disc_id                     numeric(22,0)         ,
  msinfo_id                   numeric(22,0)         ,
  disc_item_level             varchar(6)    ,
  disc_item_id                numeric(22,0)         ,
  msitem_id                   numeric(22,0)         ,
  item_pri_id                 numeric(22,0)         ,
  disc_lev                    varchar(10)   ,
  is_ext                      character(12)         ,
  auto_ext_date               date           ,
  open_date                   date           ,
  limit_date                  date           ,
  acc_nbr                     varchar(96)   ,
  serv_nbr                    varchar(30)   ,
  consume_grade               varchar(64)   ,
  serv_lev                    varchar(64)   ,
  account_nbr                 varchar(30)   ,
  city_village_id             numeric(1,0)          ,
  serv_state                  varchar(64)   ,
  serv_channel_id             varchar(64)   ,
  serv_stat_id                varchar(64)   ,
  cust_class_dl               varchar(64)   ,
  cust_type_id                varchar(64)   ,
  user_type                   varchar(64)   ,
  user_char                   varchar(64)   ,
  payment_type                varchar(64)   ,
  billing_type                varchar(64)   ,
  prod_id                     numeric(22,0)         ,
  prod_cat_id                 numeric(22,0)         ,
  exchange_id                 numeric(22,0)         ,
  serv_col1                   varchar(30)   ,
  serv_col2                   varchar(30)   ,
  area_id                     numeric(22,0)         ,
  subst_id                    numeric(22,0)         ,
  branch_id                   numeric(22,0)         ,
  stop_type                   varchar(64)   ,
  cust_manager_id             varchar(64)   ,
  create_date                 date           ,
  address_id                  numeric(22,0)         ,
  subs_date                   date           ,
  modi_staff_id               varchar(64)   ,
  cmms_cust_id                numeric(22,0)         ,
  cust_name                   varchar(1000) ,
  sales_id                    varchar(100)  ,
  sales_type_id               varchar(64)   ,
  batch_id                    numeric(15,0)         ,
  load_date                   date           ,
  new_serv_stat_id            varchar(6)    ,
  new_payment_id              varchar(6)    ,
  is_phs_tk                   character(1)          ,
  serv_addr_id                varchar(64)   ,
  cust_nbr                    varchar(30)   ,
  arrear_month                numeric(6,0)          ,
  arrear_month_last           numeric(6,0)          ,
  ehome_type                  varchar(10)   ,
  serv_create_date            date           ,
  cz_flag                     varchar(100)  ,
  ehome_class                 numeric(10,0)         ,
  strat_grp_dl                varchar(64)   ,
  sale_org1                   varchar(64)   ,
  sale_org2                   varchar(64)   ,
  sale_org3                   varchar(64)   ,
  location_type               varchar(6)    ,
  region_flag                 varchar(6)    ,
  terminal_id                 numeric(4,0)          ,
  pstn_id                     numeric(10,0)         ,
  fee_id                      numeric(4,0)          ,
  payment_id                  numeric(1,0)          ,
  billing_id                  numeric(1,0)          ,
  strat_grp_xl                varchar(64)   ,
  fld1                        varchar(20)   ,
  fld3                        varchar(20)   ,
  cust_level                  varchar(64)   ,
  group_cust_type             varchar(10)   ,
  cust_region                 varchar(10)   ,
  group_cust_grade            varchar(10)   ,
  control_level               varchar(10)   ,
  net_connect_type            numeric(10,0)         ,
  trade_type_id               varchar(30)   ,
  acc_nbr2                    varchar(40)   ,
  cdma_class_id               numeric(4,0)          ,
  phone_number_id             numeric(4,0)          ,
  develop_channel             numeric(10,0)         ,
  stop_reason_id              numeric(10,0)         ,
  stop_time                   numeric(10,0)         ,
  online_time                 numeric(10,0)         ,
  wireless_type               numeric(10,0)         ,
  fee_mode                    numeric(1,0)          ,
  vpn_class                   numeric(4,0)          ,
  serv_grp_type               varchar(10)   ,
  business_type               varchar(3)    ,
  cust_brand                  varchar(3)    ,
  wireless_active_date        date           ,
  wireless_lable_date         date           ,
  cdma_disc_type              numeric(10,0)         ,
  mix_disc                    numeric(10,0)         ,
  disc_create_date            date           ,
  is_3g                       numeric(1,0)          ,
  add_disc_type               numeric(10,0)         ,
  speed_value                 numeric(10,2)         ,
  label_num                   numeric(10,0)         ,
  business_type2              numeric(10,0)         ,
  cdma_discmsinfo_type        numeric(10,0)         ,
  price_id                    numeric(22,0)         ,
  is_mix_prod                 numeric(1,0)          ,
  std_subst_id                numeric(22,0)         ,
  std_branch_id               numeric(22,0)         ,
  disc_item_id_op             numeric(22,0)         ,
  price_id_op                 numeric(22,0)         ,
  msobjgrp_id                 numeric(22,0)         ,
  givenum_org                 varchar(20)   ,
  income_org                  varchar(20)   ,
  givenum_servcen_org         varchar(20)   ,
  income_servcen_org          varchar(64)   ,
  board_subst_id              numeric(22,0)         ,
  board_branch_id             numeric(22,0)         ,
  msobject_id                 numeric(22,0)         ,
  add_discmsinfo_type         numeric(10,0)         ,
  mix_discmsinfo_type         numeric(4,0)          ,
  prod_offer_id               numeric(22,0)         ,
  role_id                     numeric(22,0)         );
-- DISTRIBUTE BY HASH(cust_id) TO NODE(dm1_1, dm2_1, dm3_1, dm4_1, dm5_1, dm6_1, dm7_1, dm8_1)

create index idx_1325650 on summary.rpt_comm_cm_msdisc (disc_id);
create index idx_1325663 on summary.rpt_comm_cm_msdisc (prod_offer_id);
create index idx_1325665 on summary.rpt_comm_cm_msdisc (price_id);
create index idx_1325674 on summary.rpt_comm_cm_msdisc (serv_id);
create index idx_1325691 on summary.rpt_comm_cm_msdisc (msinfo_id);



create View yd.rpt_comm_cm_msdisc
as
SELECT rpt_comm_cm_msdisc.cust_id,
   rpt_comm_cm_msdisc.serv_id,
   rpt_comm_cm_msdisc.disc_id,
   rpt_comm_cm_msdisc.msinfo_id,
   rpt_comm_cm_msdisc.disc_item_level,
   rpt_comm_cm_msdisc.disc_item_id,
   rpt_comm_cm_msdisc.msitem_id,
   rpt_comm_cm_msdisc.item_pri_id,
   rpt_comm_cm_msdisc.disc_lev,
   rpt_comm_cm_msdisc.is_ext,
   rpt_comm_cm_msdisc.auto_ext_date,
   rpt_comm_cm_msdisc.open_date,
   rpt_comm_cm_msdisc.limit_date,
   rpt_comm_cm_msdisc.acc_nbr,
   rpt_comm_cm_msdisc.serv_nbr,
   rpt_comm_cm_msdisc.consume_grade,
   rpt_comm_cm_msdisc.serv_lev,
   rpt_comm_cm_msdisc.account_nbr,
   rpt_comm_cm_msdisc.city_village_id,
   rpt_comm_cm_msdisc.serv_state,
   rpt_comm_cm_msdisc.serv_channel_id,
   rpt_comm_cm_msdisc.serv_stat_id,
   rpt_comm_cm_msdisc.cust_class_dl,
   rpt_comm_cm_msdisc.cust_type_id,
   rpt_comm_cm_msdisc.user_type,
   rpt_comm_cm_msdisc.user_char,
   rpt_comm_cm_msdisc.payment_type,
   rpt_comm_cm_msdisc.billing_type,
   rpt_comm_cm_msdisc.prod_id,
   rpt_comm_cm_msdisc.prod_cat_id,
   rpt_comm_cm_msdisc.exchange_id,
   rpt_comm_cm_msdisc.serv_col1,
   rpt_comm_cm_msdisc.serv_col2,
   rpt_comm_cm_msdisc.area_id,
   rpt_comm_cm_msdisc.subst_id,
   rpt_comm_cm_msdisc.branch_id,
   rpt_comm_cm_msdisc.stop_type,
   rpt_comm_cm_msdisc.cust_manager_id,
   rpt_comm_cm_msdisc.create_date,
   rpt_comm_cm_msdisc.address_id,
   rpt_comm_cm_msdisc.subs_date,
   rpt_comm_cm_msdisc.modi_staff_id,
   rpt_comm_cm_msdisc.cmms_cust_id,
   rpt_comm_cm_msdisc.sales_id,
   rpt_comm_cm_msdisc.sales_type_id,
   rpt_comm_cm_msdisc.batch_id,
   rpt_comm_cm_msdisc.load_date,
   rpt_comm_cm_msdisc.new_serv_stat_id,
   rpt_comm_cm_msdisc.new_payment_id,
   rpt_comm_cm_msdisc.is_phs_tk,
   rpt_comm_cm_msdisc.serv_addr_id,
   rpt_comm_cm_msdisc.cust_nbr,
   rpt_comm_cm_msdisc.arrear_month,
   rpt_comm_cm_msdisc.arrear_month_last,
   rpt_comm_cm_msdisc.ehome_type,
   rpt_comm_cm_msdisc.serv_create_date,
   rpt_comm_cm_msdisc.cz_flag,
   rpt_comm_cm_msdisc.ehome_class,
   rpt_comm_cm_msdisc.strat_grp_dl,
   rpt_comm_cm_msdisc.sale_org1,
   rpt_comm_cm_msdisc.sale_org2,
   rpt_comm_cm_msdisc.sale_org3,
   rpt_comm_cm_msdisc.location_type,
   rpt_comm_cm_msdisc.region_flag,
   rpt_comm_cm_msdisc.terminal_id,
   rpt_comm_cm_msdisc.pstn_id,
   rpt_comm_cm_msdisc.fee_id,
   rpt_comm_cm_msdisc.payment_id,
   rpt_comm_cm_msdisc.billing_id,
   rpt_comm_cm_msdisc.strat_grp_xl,
   rpt_comm_cm_msdisc.fld1,
   rpt_comm_cm_msdisc.fld3,
   rpt_comm_cm_msdisc.cust_level,
   rpt_comm_cm_msdisc.group_cust_type,
   rpt_comm_cm_msdisc.cust_region,
   rpt_comm_cm_msdisc.group_cust_grade,
   rpt_comm_cm_msdisc.control_level,
   rpt_comm_cm_msdisc.net_connect_type,
   rpt_comm_cm_msdisc.trade_type_id,
   rpt_comm_cm_msdisc.acc_nbr2,
   rpt_comm_cm_msdisc.cdma_class_id,
   rpt_comm_cm_msdisc.phone_number_id,
   rpt_comm_cm_msdisc.develop_channel,
   rpt_comm_cm_msdisc.stop_reason_id,
   rpt_comm_cm_msdisc.stop_time,
   rpt_comm_cm_msdisc.online_time,
   rpt_comm_cm_msdisc.wireless_type,
   rpt_comm_cm_msdisc.fee_mode,
   rpt_comm_cm_msdisc.vpn_class,
   rpt_comm_cm_msdisc.serv_grp_type,
   rpt_comm_cm_msdisc.business_type,
   rpt_comm_cm_msdisc.cust_brand,
   rpt_comm_cm_msdisc.wireless_active_date,
   rpt_comm_cm_msdisc.wireless_lable_date,
   rpt_comm_cm_msdisc.cdma_disc_type,
   rpt_comm_cm_msdisc.mix_disc,
   rpt_comm_cm_msdisc.disc_create_date,
   rpt_comm_cm_msdisc.is_3g,
   rpt_comm_cm_msdisc.add_disc_type,
   rpt_comm_cm_msdisc.speed_value,
   rpt_comm_cm_msdisc.label_num,
   rpt_comm_cm_msdisc.business_type2,
   rpt_comm_cm_msdisc.cdma_discmsinfo_type,
   rpt_comm_cm_msdisc.price_id,
   rpt_comm_cm_msdisc.is_mix_prod,
   rpt_comm_cm_msdisc.std_subst_id,
   rpt_comm_cm_msdisc.std_branch_id,
   rpt_comm_cm_msdisc.disc_item_id_op,
   rpt_comm_cm_msdisc.price_id_op,
   rpt_comm_cm_msdisc.msobjgrp_id,
   rpt_comm_cm_msdisc.givenum_org,
   rpt_comm_cm_msdisc.income_org,
   rpt_comm_cm_msdisc.givenum_servcen_org,
   rpt_comm_cm_msdisc.income_servcen_org,
   rpt_comm_cm_msdisc.board_subst_id,
   rpt_comm_cm_msdisc.board_branch_id,
   rpt_comm_cm_msdisc.msobject_id,
   rpt_comm_cm_msdisc.add_discmsinfo_type,
   rpt_comm_cm_msdisc.mix_discmsinfo_type,
   rpt_comm_cm_msdisc.prod_offer_id,
   rpt_comm_cm_msdisc.role_id
  FROM summary.rpt_comm_cm_msdisc rpt_comm_cm_msdisc
 WHERE rpt_comm_cm_msdisc.std_subst_id = 21100004::numeric;


create Table yd.tt_01 (
  serv_id    numeric(22,0)       ,
  acc_nbr    varchar(96) );


select b.acc_nbr, (select offer_name from yd.offer where offer_id=a.prod_offer_id and manage_region_id='662') offer_name
from
  yd.rpt_comm_cm_msdisc a,
  yd.tt_01 b
where 
  a.serv_id=b.serv_id;


                                         QUERY PLAN
---------------------------------------------------------------------------------------------
 Hash Join  (cost=10.14..40.73 rows=2 width=726)
   Output: b.acc_nbr, (SubPlan 1)
   Hash Cond: (b.serv_id = rpt_comm_cm_msdisc.serv_id)
   ->  Seq Scan on yd.tt_01 b  (cost=0.00..13.10 rows=310 width=232)
         Output: b.serv_id, b.acc_nbr
   ->  Hash  (cost=10.12..10.12 rows=1 width=44)
         Output: rpt_comm_cm_msdisc.prod_offer_id, rpt_comm_cm_msdisc.serv_id
         ->  Seq Scan on summary.rpt_comm_cm_msdisc  (cost=0.00..10.12 rows=1 width=44)
               Output: rpt_comm_cm_msdisc.prod_offer_id, rpt_comm_cm_msdisc.serv_id
               Filter: (rpt_comm_cm_msdisc.std_subst_id = '21100004'::numeric)
   SubPlan 1
     ->  Index Scan using offer_pkey on crm_cfguse.offer  (cost=0.14..8.15 rows=1 width=516)
           Output: offer.offer_name
           Index Cond: (offer.offer_id = rpt_comm_cm_msdisc.prod_offer_id)
           Filter: (offer.manage_region_id = '662'::numeric)
(15 rows)


                                                                    QUERY PLAN
---------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Gather  (cost=1015.56..5000001180.15 rows=2 width=64)
   Remote node: 16386,16387,16388
   ->  Hash Join  (cost=15.56..5000000179.55 rows=0 width=64)
         Output: b.acc_nbr, (SubPlan 1)
         Hash Cond: (b.serv_id = rpt_comm_cm_msdisc.serv_id)
         ->  Cluster Reduce  (cost=1.00..131.90 rows=248 width=54)
               Reduce: ('[0:3]={12338,16386,16387,16388}'::oid[])[COALESCE(hash_combin_mod(4, hash_numeric(b.serv_id)), 0)]
               ->  Seq Scan on yd.tt_01 b  (cost=0.00..19.90 rows=330 width=54)
                     Output: b.serv_id, b.acc_nbr
                     Remote node: 16386,16387,16388
         ->  Hash  (cost=14.55..14.55 rows=1 width=44)
               Output: rpt_comm_cm_msdisc.prod_offer_id, rpt_comm_cm_msdisc.serv_id
               ->  Cluster Reduce  (cost=1.00..14.55 rows=1 width=44)
                     Reduce: ('[0:3]={12338,16386,16387,16388}'::oid[])[COALESCE(hash_combin_mod(4, hash_numeric(rpt_comm_cm_msdisc.serv_id)), 0)]
                     ->  Seq Scan on summary.rpt_comm_cm_msdisc  (cost=0.00..10.25 rows=1 width=44)
                           Output: rpt_comm_cm_msdisc.prod_offer_id, rpt_comm_cm_msdisc.serv_id
                           Filter: (rpt_comm_cm_msdisc.std_subst_id = '21100004'::numeric)
                           Remote node: 16386,16387,16388
         SubPlan 1
           ->  Reduce Scan  (cost=1.00..15.67 rows=3 width=32)
                 Output: offer.offer_name
                 Filter: (offer.offer_id = rpt_comm_cm_msdisc.prod_offer_id)
                 Hash Buckets: 512
                 ->  Cluster Reduce  (cost=1.00..15.65 rows=3 width=54)
                       Reduce: unnest('[0:3]={12338,16386,16387,16388}'::oid[])
                       ->  Seq Scan on crm_cfguse.offer  (cost=0.00..10.75 rows=1 width=54)
                             Output: offer.offer_name, offer.offer_id
                             Filter: (offer.manage_region_id = '662'::numeric)
                             Remote node: 16386,16387,16388
(29 rows)