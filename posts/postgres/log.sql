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
                                 Filter: (oracle.mod(acct_id, '10'::numeric) = '1'::numeric)
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
                                                   Filter: (oracle.mod(acc_id, '10'::numeric) = '1'::numeric)
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
                                             Filter: (oracle.mod(t.acct_id, '10'::numeric) = '1'::numeric)
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
                                       Output: 0, t1.acc_id, t1.user_id, t1.acc_code, 202209, sum(oracle.nvl(t1.total_fee, '0'::numeric(16,0))), 0, sum(('0'::numeri
                                       Group Key: t1.bill_code, t1.acc_id, t1.user_id, t1.acc_code
                                       Node 16388: (actual time=20.586..90.099 rows=16860 loops=1)
                                       Node 16389: (actual time=20.904..88.329 rows=16200 loops=1)
                                       Node 16390: (actual time=21.792..92.805 rows=16810 loops=1)
                                       Node 16391: (actual time=20.608..88.130 rows=16350 loops=1)
                                       Node 16387: (actual time=20.769..90.442 rows=16770 loops=1)
                                       Node 16392: (actual time=21.252..91.459 rows=17010 loops=1)
                                       ->  Gather Merge  (cost=23136.24..23669.08 rows=4165 width=279) (never executed)
                                             Output: t1.acc_id, t1.user_id, t1.acc_code, t1.bill_code, (PARTIAL sum(oracle.nvl(t1.total_fee, '0'::numeric(16,0)))), 
                                             Workers Planned: 5
                                             Workers Launched: 0
                                             Node 16388: (actual time=20.556..42.538 rows=16860 loops=1)
                                             Node 16389: (actual time=20.874..41.663 rows=16200 loops=1)
                                             Node 16390: (actual time=21.765..43.620 rows=16810 loops=1)
                                             Node 16391: (actual time=20.580..41.731 rows=16350 loops=1)
                                             Node 16387: (actual time=20.745..42.213 rows=16770 loops=1)
                                             Node 16392: (actual time=21.224..43.653 rows=17010 loops=1)
                                             ->  Partial GroupAggregate  (cost=22136.17..22167.43 rows=833 width=279) (never executed)
                                                   Output: t1.acc_id, t1.user_id, t1.acc_code, t1.bill_code, PARTIAL sum(oracle.nvl(t1.total_fee, '0'::numeric(16,0)
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
                                                               Filter: (oracle.mod(t1.acc_id, '10'::numeric) = '1'::numeric)
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