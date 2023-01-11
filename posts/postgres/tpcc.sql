SELECT 
    procpid, 
    start, 
    now() - start AS lap, 
    current_query 
FROM 
    (SELECT 
        backendid, 
        pg_stat_get_backend_pid(S.backendid) AS procpid, 
        pg_stat_get_backend_activity_start(S.backendid) AS start, 
       pg_stat_get_backend_activity(S.backendid) AS current_query 
    FROM 
        (SELECT pg_stat_get_backend_idset() AS backendid) AS S 
    ) AS S 
WHERE 
   current_query <> '<IDLE>' 
ORDER BY 
   lap DESC;







select pg_backend_pid();


pgxc_handle_unsupported_stmts




1	新订单	查询地区	

prepare s1(int, int) as
SELECT d_tax, d_next_o_id FROM bmsql_district WHERE d_w_id = $1 AND d_id = $2 FOR UPDATE;	
explain verbose execute s1(1, 1);
(动态语句1)
                                                                       QUERY PLAN                                                                       
--------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_district.d_tax, bmsql_district.d_next_o_id
   Node expr: $1
   Remote query: SELECT d_tax, d_next_o_id FROM public.bmsql_district bmsql_district WHERE ((d_w_id = $1) AND (d_id = $2)) FOR UPDATE OF bmsql_district
(4 rows)
(动态语句2)
                                                                       QUERY PLAN                                                                       
--------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_district.d_tax, bmsql_district.d_next_o_id
   Primary node/s: dn1
   Node/s: dn1, dn2
   Remote query: SELECT d_tax, d_next_o_id FROM public.bmsql_district bmsql_district WHERE ((d_w_id = $1) AND (d_id = $2)) FOR UPDATE OF bmsql_district
(5 rows)
(静态语句)
                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_district.d_tax, bmsql_district.d_next_o_id
   Primary node/s: dn1
   Node/s: dn1
   Remote query: SELECT d_tax, d_next_o_id FROM public.bmsql_district bmsql_district WHERE ((d_w_id = 1) AND (d_id = 1)) FOR UPDATE OF bmsql_district
(5 rows)
2	新订单	查询客户仓库	

prepare s2(int, int) as
SELECT c_discount, c_last, c_credit, w_tax FROM bmsql_customer JOIN bmsql_warehouse 
ON (w_id = c_w_id) WHERE c_w_id = $1 AND c_d_id = $2 AND c_id = $3;
explain verbose execute s2(2, 2, 1);
                                                                                                                                                                                                    
                                                                           QUERY PLAN                                                                                                               
                                                                                                                                                                 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Gather  (cost=0.17..10.41 rows=0 width=25)
   Remote node: 16386
   ->  Nested Loop  (cost=0.17..10.26 rows=0 width=25)
         Output: bmsql_customer.c_discount, bmsql_customer.c_last, bmsql_customer.c_credit, bmsql_warehouse.w_tax
         ->  Index Scan using bmsql_customer_pkey on public.bmsql_customer  (cost=0.17..8.19 rows=1 width=24)
               Output: bmsql_customer.c_w_id, bmsql_customer.c_d_id, bmsql_customer.c_id, bmsql_customer.c_discount, bmsql_customer.c_credit, bmsql_customer.c_last, bmsql_customer.c_first, bmsql_customer.c_credit_lim, bmsql_customer.c_balance, bmsql_customer.c_ytd_payment, bmsql_customer.c_payment_cnt, bmsql_customer.c_delivery_cnt, bmsql_customer.c_street_1, bmsql_customer.c_street_2, bmsql_customer.c_city, bmsql_customer.c_state, bmsql_customer.c_zip, bmsql_customer.c_phone, bmsql_customer.c_since, bmsql_customer.c_middle, bmsql_customer.c_data
               Index Cond: ((bmsql_customer.c_w_id = 2) AND (bmsql_customer.c_d_id = 2) AND (bmsql_customer.c_id = 1))
               Remote node: 16386
         ->  Seq Scan on public.bmsql_warehouse  (cost=0.00..2.06 rows=1 width=9)
               Output: bmsql_warehouse.w_id, bmsql_warehouse.w_ytd, bmsql_warehouse.w_tax, bmsql_warehouse.w_name, bmsql_warehouse.w_street_1, bmsql_warehouse.w_street_2, bmsql_warehouse.w_city, bmsql_warehouse.w_state, bmsql_warehouse.w_zip
               Filter: (bmsql_warehouse.w_id = 2)
               Remote node: 16386
(12 rows)

                                                                           QUERY PLAN                                                                                                               
                                                                                                                                                                 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Gather  (cost=0.17..10.41 rows=0 width=25)
   Remote node: 16386
   ->  Nested Loop  (cost=0.17..10.26 rows=0 width=25)
         Output: bmsql_customer.c_discount, bmsql_customer.c_last, bmsql_customer.c_credit, bmsql_warehouse.w_tax
         ->  Index Scan using bmsql_customer_pkey on public.bmsql_customer  (cost=0.17..8.19 rows=1 width=24)
               Output: bmsql_customer.c_w_id, bmsql_customer.c_d_id, bmsql_customer.c_id, bmsql_customer.c_discount, bmsql_customer.c_credit, bmsql_customer.c_last, bmsql_customer.c_first, bmsql_customer.c_credit_lim, bmsql_customer.c_balance, bmsql_customer.c_ytd_payment, bmsql_customer.c_payment_cnt, bmsql_customer.c_delivery_cnt, bmsql_customer.c_street_1, bmsql_customer.c_street_2, bmsql_customer.c_city, bmsql_customer.c_state, bmsql_customer.c_zip, bmsql_customer.c_phone, bmsql_customer.c_since, bmsql_customer.c_middle, bmsql_customer.c_data
               Index Cond: ((bmsql_customer.c_w_id = 2) AND (bmsql_customer.c_d_id = 2) AND (bmsql_customer.c_id = 1))
               Remote node: 16386
         ->  Seq Scan on public.bmsql_warehouse  (cost=0.00..2.06 rows=1 width=9)
               Output: bmsql_warehouse.w_id, bmsql_warehouse.w_ytd, bmsql_warehouse.w_tax, bmsql_warehouse.w_name, bmsql_warehouse.w_street_1, bmsql_warehouse.w_street_2, bmsql_warehouse.w_city, bmsql_warehouse.w_state, bmsql_warehouse.w_zip
               Filter: (bmsql_warehouse.w_id = 2)
               Remote node: 16386
(12 rows)

3	新订单	更新地区的下一个订单编号	

prepare s3(int, int) as
UPDATE bmsql_district SET d_next_o_id = d_next_o_id + 1 WHERE d_w_id = $1 AND d_id = $2;	
explain verbose execute s3(2, 2);
                                                              QUERY PLAN                                                               
---------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ((bmsql_district.d_next_o_id + 1))
   Node expr: $1
   Remote query: UPDATE public.bmsql_district bmsql_district SET d_next_o_id = (d_next_o_id + 1) WHERE ((d_w_id = $1) AND (d_id = $2))
(4 rows)

                                                              QUERY PLAN                                                               
---------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ((bmsql_district.d_next_o_id + 1))
   Primary node/s: dn1
   Node/s: dn1, dn2
   Remote query: UPDATE public.bmsql_district bmsql_district SET d_next_o_id = (d_next_o_id + 1) WHERE ((d_w_id = $1) AND (d_id = $2))
(5 rows)

4	新订单	插入订单表	

prepare s4(int, int, int, int, timestamp, int, int) as
INSERT INTO bmsql_oorder (o_id, o_d_id, o_w_id, o_c_id, o_entry_d, o_ol_cnt, o_all_local) VALUES ($1, $2, $3, $4, $5, $6, $7);	
explain verbose execute s4(3001, 2, 2, 1, '2022-04-24 14:16:10.828', 5, 1);
                                                                              QUERY PLAN                                                                              
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($3), ($2), ($1), ($4), ($6), ($7), ($5)
   Node expr: $3
   Remote query: INSERT INTO public.bmsql_oorder AS bmsql_oorder (o_w_id, o_d_id, o_id, o_c_id, o_ol_cnt, o_all_local, o_entry_d) VALUES ($3, $2, $1, $4, $6, $7, $5)
(4 rows)

                                                                              QUERY PLAN                                                                              
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($3), ($2), ($1), ($4), ($6), ($7), ($5)
   Node expr: $3
   Remote query: INSERT INTO public.bmsql_oorder AS bmsql_oorder (o_w_id, o_d_id, o_id, o_c_id, o_ol_cnt, o_all_local, o_entry_d) VALUES ($3, $2, $1, $4, $6, $7, $5)
(4 rows)

5	新订单	插入新订单表	

prepare s5(int, int, int) as
INSERT INTO bmsql_new_order (no_o_id, no_d_id, no_w_id) VALUES ($1, $2, $3);	
explain verbose execute s5(3001, 2, 2);
                                                      QUERY PLAN                                                       
-----------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($3), ($2), ($1)
   Node expr: $3
   Remote query: INSERT INTO public.bmsql_new_order AS bmsql_new_order (no_w_id, no_d_id, no_o_id) VALUES ($3, $2, $1)
(4 rows)

                                                      QUERY PLAN                                                       
-----------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($3), ($2), ($1)
   Node expr: $3
   Remote query: INSERT INTO public.bmsql_new_order AS bmsql_new_order (no_w_id, no_d_id, no_o_id) VALUES ($3, $2, $1)
(4 rows)

6	新订单	查询商品信息	

prepare s6(int) as
SELECT i_price, i_name, i_data FROM bmsql_item WHERE i_id = $1;	
explain verbose execute s6(1);
                                             QUERY PLAN                                             
----------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_item.i_price, bmsql_item.i_name, bmsql_item.i_data
   Node expr: $1
   Remote query: SELECT i_price, i_name, i_data FROM public.bmsql_item bmsql_item WHERE (i_id = $1)
(4 rows)

                                             QUERY PLAN                                             
----------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_item.i_price, bmsql_item.i_name, bmsql_item.i_data
   Primary node/s: dn1
   Node/s: dn1, dn2
   Remote query: SELECT i_price, i_name, i_data FROM public.bmsql_item bmsql_item WHERE (i_id = $1)
(5 rows)

7	新订单	选择库存来更新	

prepare s7(int, int) as
SELECT 
s_quantity, s_data, s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05, s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10 
FROM bmsql_stock WHERE s_w_id = $1 AND s_i_id = $2 FOR UPDATE;	
explain verbose execute s7(2, 1);
                                                                                                                                         QUERY PLAN                                                 
                                                                                        
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_stock.s_quantity, bmsql_stock.s_data, bmsql_stock.s_dist_01, bmsql_stock.s_dist_02, bmsql_stock.s_dist_03, bmsql_stock.s_dist_04, bmsql_stock.s_dist_05, bmsql_stock.s_dist_06, bmsql_stock.s_dist_07, bmsql_stock.s_dist_08, bmsql_stock.s_dist_09, bmsql_stock.s_dist_10
   Node expr: $1
   Remote query: SELECT s_quantity, s_data, s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05, s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10 FROM public.bmsql_stock bmsql_stock WHERE ((s_w_id = $1) AND (s_i_id = $2)) FOR UPDATE OF bmsql_stock
(4 rows)

                                                                                                                                         QUERY PLAN                                                 
                                                                                        
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: bmsql_stock.s_quantity, bmsql_stock.s_data, bmsql_stock.s_dist_01, bmsql_stock.s_dist_02, bmsql_stock.s_dist_03, bmsql_stock.s_dist_04, bmsql_stock.s_dist_05, bmsql_stock.s_dist_06, bmsql_stock.s_dist_07, bmsql_stock.s_dist_08, bmsql_stock.s_dist_09, bmsql_stock.s_dist_10
   Primary node/s: dn1
   Node/s: dn1, dn2
   Remote query: SELECT s_quantity, s_data, s_dist_01, s_dist_02, s_dist_03, s_dist_04, s_dist_05, s_dist_06, s_dist_07, s_dist_08, s_dist_09, s_dist_10 FROM public.bmsql_stock bmsql_stock WHERE ((s_w_id = $1) AND (s_i_id = $2)) FOR UPDATE OF bmsql_stock
(5 rows)

8	新订单	插入订单商品明细表	

prepare s8(int, int, int, int, int, int, int, int,  varchar) as
INSERT INTO bmsql_order_line 
(ol_o_id, ol_d_id, ol_w_id, ol_number, ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_dist_info) 
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);	
explain verbose execute s8(3001, 2, 2, 1, 1, 2, 1, 22.46, 's_dist_02');
                                                                                                        QUERY PLAN                                                                                  
                       
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($3), ($2), ($1), ($4), ($5), (($8)::numeric(6,2)), ($6), ($7), (($9)::character(24))
   Node expr: $3
   Remote query: INSERT INTO public.bmsql_order_line AS bmsql_order_line (ol_w_id, ol_d_id, ol_o_id, ol_number, ol_i_id, ol_amount, ol_supply_w_id, ol_quantity, ol_dist_info) VALUES ($3, $2, $1, $4, $5, $8, $6, $7, $9)
(4 rows)

                                                                                                        QUERY PLAN                                                                                  
                       
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($3), ($2), ($1), ($4), ($5), (($8)::numeric(6,2)), ($6), ($7), (($9)::character(24))
   Node expr: $3
   Remote query: INSERT INTO public.bmsql_order_line AS bmsql_order_line (ol_w_id, ol_d_id, ol_o_id, ol_number, ol_i_id, ol_amount, ol_supply_w_id, ol_quantity, ol_dist_info) VALUES ($3, $2, $1, $4, $5, $8, $6, $7, $9)
(4 rows)

9	新订单	更新库存	
prepare s9(int, int, int, int, int) as
UPDATE bmsql_stock SET 
s_quantity = $1, s_ytd = s_ytd + $2, s_order_cnt = s_order_cnt + 1, s_remote_cnt = s_remote_cnt + $3
WHERE s_w_id = $4 AND s_i_id = $5;	
explain verbose execute s9(92, 1, 0, 2, 1);
                                                                                                  QUERY PLAN                                                                                        
          
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($1), ((bmsql_stock.s_ytd + $2)), ((bmsql_stock.s_order_cnt + 1)), ((bmsql_stock.s_remote_cnt + $3))
   Node expr: $4
   Remote query: UPDATE public.bmsql_stock bmsql_stock SET s_quantity = $1, s_ytd = (s_ytd + $2), s_order_cnt = (s_order_cnt + 1), s_remote_cnt = (s_remote_cnt + $3) WHERE ((s_w_id = $4) AND (s_i_id = $5))
(4 rows)

                                                                                                  QUERY PLAN                                                                                        
          
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Data Node Scan on "__REMOTE_FQS_QUERY__"  (cost=0.00..0.00 rows=0 width=0)
   Output: ($1), ((bmsql_stock.s_ytd + $2)), ((bmsql_stock.s_order_cnt + 1)), ((bmsql_stock.s_remote_cnt + $3))
   Primary node/s: dn1
   Node/s: dn1, dn2
   Remote query: UPDATE public.bmsql_stock bmsql_stock SET s_quantity = $1, s_ytd = (s_ytd + $2), s_order_cnt = (s_order_cnt + 1), s_remote_cnt = (s_remote_cnt + $3) WHERE ((s_w_id = $4) AND (s_i_id = $5))
(5 rows)

1	查询库存水平	查询库存水平	

prepare s10(int, int, int, int) as 
SELECT count(*) AS low_stock FROM (
           SELECT s_w_id, s_i_id, s_quantity 
           FROM bmsql_stock 
WHERE s_w_id = $1 AND s_quantity < $2 AND s_i_id IN (
           SELECT ol_i_id 
           FROM bmsql_district 
           JOIN bmsql_order_line ON ol_w_id = d_w_id 
           AND ol_d_id = d_id 
           AND ol_o_id >= d_next_o_id - 20 
           AND ol_o_id < d_next_o_id 
           WHERE d_w_id = $3 AND d_id = $4 
           ) 
           ) AS L;
explain verbose execute s10(2, 15, 2, 2);

                                                                                                                                                              QUERY PLAN                            
                                                                                                                                  
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Gather  (cost=7829.26..7829.57 rows=1 width=8)
   Remote node: 16386
   ->  Aggregate  (cost=7829.26..7829.27 rows=1 width=8)
         Output: count(*)
         ->  Nested Loop  (cost=7794.23..7829.22 rows=16 width=0)
               Inner Unique: true
               ->  HashAggregate  (cost=7794.06..7808.46 rows=1440 width=4)
                     Output: bmsql_order_line.ol_i_id
                     Group Key: bmsql_order_line.ol_i_id
                     ->  Nested Loop  (cost=48.10..7790.46 rows=720 width=4)
                           Output: bmsql_order_line.ol_i_id
                           ->  Seq Scan on public.bmsql_district  (cost=0.00..2.75 rows=1 width=12)
                                 Output: bmsql_district.d_w_id, bmsql_district.d_id, bmsql_district.d_ytd, bmsql_district.d_tax, bmsql_district.d_next_o_id, bmsql_district.d_name, bmsql_district.d_street_1, bmsql_district.d_street_2, bmsql_district.d_city, bmsql_district.d_state, bmsql_district.d_zip
                                 Filter: ((bmsql_district.d_id = 2) AND (bmsql_district.d_w_id = 2))
                                 Remote node: 16386
                           ->  Bitmap Heap Scan on public.bmsql_order_line  (cost=48.10..7758.91 rows=2880 width=16)
                                 Output: bmsql_order_line.ol_w_id, bmsql_order_line.ol_d_id, bmsql_order_line.ol_o_id, bmsql_order_line.ol_number, bmsql_order_line.ol_i_id, bmsql_order_line.ol_delivery_d, bmsql_order_line.ol_amount, bmsql_order_line.ol_supply_w_id, bmsql_order_line.ol_quantity, bmsql_order_line.ol_dist_info
                                 Recheck Cond: ((bmsql_order_line.ol_w_id = 2) AND (bmsql_order_line.ol_d_id = 2) AND (bmsql_order_line.ol_o_id >= (bmsql_district.d_next_o_id - 20)) AND (bmsql_order_line.ol_o_id < bmsql_district.d_next_o_id))
                                 ->  Bitmap Index Scan on bmsql_order_line_pkey  (cost=0.00..47.38 rows=2880 width=0)
                                       Index Cond: ((bmsql_order_line.ol_w_id = 2) AND (bmsql_order_line.ol_d_id = 2) AND (bmsql_order_line.ol_o_id >= (bmsql_district.d_next_o_id - 20)) AND (bmsql_order_line.ol_o_id < bmsql_district.d_next_o_id))
                                       Remote node: 16386
               ->  Materialize  (cost=0.17..2.82 rows=1 width=4)
                     Output: bmsql_stock.s_i_id
                     ->  Index Scan using bmsql_stock_pkey on public.bmsql_stock  (cost=0.17..2.81 rows=1 width=4)
                           Output: bmsql_stock.s_i_id
                           Index Cond: ((bmsql_stock.s_w_id = 2) AND (bmsql_stock.s_i_id = bmsql_order_line.ol_i_id))
                           Filter: (bmsql_stock.s_quantity < 15)
                           Remote node: 16386
(28 rows)

                                                                                                                                                              QUERY PLAN                            
                                                                                                                                  
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Gather  (cost=7829.26..7829.57 rows=1 width=8)
   Remote node: 16386
   ->  Aggregate  (cost=7829.26..7829.27 rows=1 width=8)
         Output: count(*)
         ->  Nested Loop  (cost=7794.23..7829.22 rows=16 width=0)
               Inner Unique: true
               ->  HashAggregate  (cost=7794.06..7808.46 rows=1440 width=4)
                     Output: bmsql_order_line.ol_i_id
                     Group Key: bmsql_order_line.ol_i_id
                     ->  Nested Loop  (cost=48.10..7790.46 rows=720 width=4)
                           Output: bmsql_order_line.ol_i_id
                           ->  Seq Scan on public.bmsql_district  (cost=0.00..2.75 rows=1 width=12)
                                 Output: bmsql_district.d_w_id, bmsql_district.d_id, bmsql_district.d_ytd, bmsql_district.d_tax, bmsql_district.d_next_o_id, bmsql_district.d_name, bmsql_district.d_street_1, bmsql_district.d_street_2, bmsql_district.d_city, bmsql_district.d_state, bmsql_district.d_zip
                                 Filter: ((bmsql_district.d_id = 2) AND (bmsql_district.d_w_id = 2))
                                 Remote node: 16386
                           ->  Bitmap Heap Scan on public.bmsql_order_line  (cost=48.10..7758.91 rows=2880 width=16)
                                 Output: bmsql_order_line.ol_w_id, bmsql_order_line.ol_d_id, bmsql_order_line.ol_o_id, bmsql_order_line.ol_number, bmsql_order_line.ol_i_id, bmsql_order_line.ol_delivery_d, bmsql_order_line.ol_amount, bmsql_order_line.ol_supply_w_id, bmsql_order_line.ol_quantity, bmsql_order_line.ol_dist_info
                                 Recheck Cond: ((bmsql_order_line.ol_w_id = 2) AND (bmsql_order_line.ol_d_id = 2) AND (bmsql_order_line.ol_o_id >= (bmsql_district.d_next_o_id - 20)) AND (bmsql_order_line.ol_o_id < bmsql_district.d_next_o_id))
                                 ->  Bitmap Index Scan on bmsql_order_line_pkey  (cost=0.00..47.38 rows=2880 width=0)
                                       Index Cond: ((bmsql_order_line.ol_w_id = 2) AND (bmsql_order_line.ol_d_id = 2) AND (bmsql_order_line.ol_o_id >= (bmsql_district.d_next_o_id - 20)) AND (bmsql_order_line.ol_o_id < bmsql_district.d_next_o_id))
                                       Remote node: 16386
               ->  Materialize  (cost=0.17..2.82 rows=1 width=4)
                     Output: bmsql_stock.s_i_id
                     ->  Index Scan using bmsql_stock_pkey on public.bmsql_stock  (cost=0.17..2.81 rows=1 width=4)
                           Output: bmsql_stock.s_i_id
                           Index Cond: ((bmsql_stock.s_w_id = 2) AND (bmsql_stock.s_i_id = bmsql_order_line.ol_i_id))
                           Filter: (bmsql_stock.s_quantity < 15)
                           Remote node: 16386
(28 rows)

1	支付订单	更新地区金额	

UPDATE bmsql_district SET d_ytd = d_ytd + ? WHERE d_w_id = ? AND d_id = ?;	
UPDATE bmsql_district SET d_ytd = d_ytd + 50 WHERE d_w_id = 2 AND d_id = 2;


2	支付订单	查询地区	

SELECT d_name, d_street_1, d_street_2, d_city, d_state, d_zip FROM bmsql_district WHERE d_w_id = ? AND d_id = ?;	
SELECT d_name, d_street_1, d_street_2, d_city, d_state, d_zip FROM bmsql_district WHERE d_w_id = 2 AND d_id = 2;


3	支付订单	更新仓库金额	

UPDATE bmsql_warehouse SET w_ytd = w_ytd + ? WHERE w_id = ?;	
UPDATE bmsql_warehouse SET w_ytd = w_ytd + 50 WHERE w_id = 2;


4	支付订单	查询仓库	

SELECT w_name, w_street_1, w_street_2, w_city, w_state, w_zip FROM bmsql_warehouse WHERE w_id = ?;	
SELECT w_name, w_street_1, w_street_2, w_city, w_state, w_zip FROM bmsql_warehouse WHERE w_id = 2;


5	支付订单	查询客户id。可选，当payment.c_last != null时获取c_id 否则 随机获取 ，下面这条sql的仓库 地市是 随机获取的，15%的概率	

SELECT c_id FROM bmsql_customer WHERE c_w_id = ? AND c_d_id = ? AND c_last = ? ORDER BY c_first;	
SELECT c_id FROM bmsql_customer WHERE c_w_id = 2 AND c_d_id = 2 AND c_last = 'ABLEABLEBAR' ORDER BY c_first;


6	支付订单	查询客户信息	

SELECT c_first, c_middle, c_last, c_street_1, c_street_2, c_city, c_state, c_zip, c_phone, c_since, c_credit, c_credit_lim, c_discount, c_balance 
FROM bmsql_customer WHERE c_w_id = ? AND c_d_id = ? AND c_id = ? FOR UPDATE;	
SELECT c_first, c_middle, c_last, c_street_1, c_street_2, c_city, c_state, c_zip, c_phone, c_since, c_credit, c_credit_lim, c_discount, c_balance 
FROM bmsql_customer WHERE c_w_id = 2 AND c_d_id = 2 AND c_id = 1 FOR UPDATE;


7	支付订单	更新客户。下面只执行其中一种分支	"当payment.c_credit.equals(""GC"") 为真时
UPDATE bmsql_customer SET c_balance = c_balance - ?, c_ytd_payment = c_ytd_payment + ?, c_payment_cnt = c_payment_cnt + 1 WHERE c_w_id = ? AND c_d_id = ? AND c_id = ?;
当 payment.c_credit.equals(""GC"") 为假时
SELECT c_data FROM bmsql_customer WHERE c_w_id = ? AND c_d_id = ? AND c_id = ?;
UPDATE bmsql_customer SET c_balance = c_balance - ?, c_ytd_payment = c_ytd_payment + ?, c_payment_cnt = c_payment_cnt + 1, c_data = ? WHERE c_w_id = ? AND c_d_id = ? AND c_id = ?;
"	"当payment.c_credit.equals(""GC"") 为真时
UPDATE bmsql_customer SET c_balance = c_balance - 50, c_ytd_payment = c_ytd_payment + 50, c_payment_cnt = c_payment_cnt + 1 WHERE c_w_id = 2 AND c_d_id = 2 AND c_id = 1;
当 payment.c_credit.equals(""GC"") 为假时
SELECT c_data FROM bmsql_customer WHERE c_w_id = 2 AND c_d_id = 2 AND c_id = 1;
UPDATE bmsql_customer SET c_balance = c_balance - 50, c_ytd_payment = c_ytd_payment + 50, c_payment_cnt = c_payment_cnt + 1, c_data = 'kpPptvxJnsCfvO1ytF4BDyvdazRSgRWn4sXjbv4Rf5lD7zbrvLCyCz3cShZtlZ0z3hyj4h1oYOLijM8QeoAJjtsMVeLrIllxr5yamzWvxTMvad2VbtgDvCuvBuBD6cQDCHbv8Fscz4KyXFpvSbZ18tht5HMOH5dFXCLl
3rjxalXVAd0xGAV7XlYOIGxq4J01L6AMnN7OqH68cB3zrqExErhJnLwYpjDrkPbP2HbBamF9oOkWXljHKGfsHYcnMGWVBnFHFmlxKZjLlLgLzEsXW4pM4BDDM2JPdZTkDu0fI0hGJL51TAHjhgJBQwj7F56NmELmw1Qit
edc0umZGrGL0F1406CzD' WHERE c_w_id = 2 AND c_d_id = 2 AND c_id = 1;"
8	支付订单	插入历史表	

INSERT INTO bmsql_history (h_c_id, h_c_d_id, h_c_w_id, h_d_id, h_w_id, h_date, h_amount, h_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?);	
INSERT INTO bmsql_history (h_c_id, h_c_d_id, h_c_w_id, h_d_id, h_w_id, h_date, h_amount, h_data) VALUES (1, 2, 2, 2, 2, '2022-04-24 14:16:10.828', 50, 'kdFsmsG0gO  t4J98uwY');










==================================================================



prepare s16(int, int, int, int, int, int) as 
select o_id, o_entry_d, o_carrier_id from bmsql_oorder 
where o_w_id = $1 and o_d_id = $2 and o_c_id = $3 and o_id = (
  select max(o_id) from bmsql_oorder where o_w_id = $4 and o_d_id = $5 and o_c_id = $6
);
explain verbose execute s16(1, 1, 1, 1, 1, 1);