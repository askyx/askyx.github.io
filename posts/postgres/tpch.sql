

## envs

```

create database tpch;
\c tpch
\i /home/vscode/adb_tools/TPCH/TPCH/dbgen/dss.ddl
ALTER TABLE REGION ADD PRIMARY KEY (R_REGIONKEY);
ALTER TABLE NATION ADD PRIMARY KEY (N_NATIONKEY);
ALTER TABLE PART ADD PRIMARY KEY (P_PARTKEY);
ALTER TABLE SUPPLIER ADD PRIMARY KEY (S_SUPPKEY);
ALTER TABLE PARTSUPP ADD PRIMARY KEY (PS_PARTKEY,PS_SUPPKEY);
ALTER TABLE CUSTOMER ADD PRIMARY KEY (C_CUSTKEY);
ALTER TABLE LINEITEM ADD PRIMARY KEY (L_ORDERKEY,L_LINENUMBER);
ALTER TABLE ORDERS ADD PRIMARY KEY (O_ORDERKEY);


./dbgen -s 1000 

\copy supplier from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/supplier.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy region from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/region.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy partsupp from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/partsupp.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy part from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/part.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy orders from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/orders.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy nation from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/nation.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy lineitem from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/lineitem.tbl' with (format csv,encoding utf8,DELIMITER '|');
\copy customer from '/home/vscode/adb_tools/TPCH/TPCH/dbgen/customer.tbl' with (format csv,encoding utf8,DELIMITER '|');


vacuum analyze customer ;
vacuum analyze lineitem ;
vacuum analyze nation   ;
vacuum analyze orders   ;
vacuum analyze part     ;
vacuum analyze partsupp ;
vacuum analyze region   ;
vacuum analyze supplier ;

```


                            List of relations
 Schema |   Name   | Type  | Owner | Persistence |  Size   | Description 
--------+----------+-------+-------+-------------+---------+-------------
 public | customer | table | maoxp | permanent   | 2800 MB | 15000000
 public | lineitem | table | maoxp | permanent   | 86 GB   | 600037902
 public | nation   | table | maoxp | permanent   | 40 kB   | 25
 public | orders   | table | maoxp | permanent   | 20 GB   | 150000000
 public | part     | table | maoxp | permanent   | 3201 MB | 20000000
 public | partsupp | table | maoxp | permanent   | 13 GB   | 80000000
 public | region   | table | maoxp | permanent   | 40 kB   | 5
 public | supplier | table | maoxp | permanent   | 173 MB  | 1000000
(8 rows)


select * from customer;

----base1
set enable_mergejoin=off;
set enable_nestloop=off;
set pgxc_enable_remote_query=off;
set enable_fast_query_shipping=off;



----base2
set max_parallel_workers = 128;
set max_parallel_workers_per_gather = 128;
set work_mem = '64MB';


set min_parallel_table_scan_size = '1B';
set reduce_scan_bucket_size = 4096;
set reduce_scan_max_buckets = 2048;


set hash_mem_multiplier = 5;





      |   base test       |            |    
--------------------------------------------------------------------------------------------------------------------------------
  Q1  |   66416.088 ms    |  19405.438 ms           |   12224.385 ms  DOP 15
  Q2  | 1814317.442 ms    |  93345.116 ms
  Q3  |   63078.615 ms    |   9461.183 ms           |    6205.912 ms
  Q4  |   30307.878 ms    |  10549.029 ms           |    7163.654 ms
  Q5  |   49927.800 ms    |
  Q6  |   15914.630 ms    |
  Q7  |   31006.504 ms    |
  Q8  |   80034.168 ms    |
  Q9  |   89941.042 ms    |
  Q10 |   26574.637 ms    |
  Q11 |    9242.111 ms    |
  Q12 |   26083.005 ms    |
  Q13 |   31731.124 ms    |
  Q14 |   13519.179 ms    |
  Q15 |   33442.890 ms    |
  Q16 |   23600.211 ms    |
  Q17 |                   | 1557475.906 ms
  Q18 |  130985.611 ms    |   43447.228 ms
  Q19 |   17575.368 ms    |
  Q20 |                   |                         |   85847.156 ms  DOP 12
  Q21 |   96664.368 ms    |   33035.865 ms DOP8     |   22295.373 ms  DOP 14
  Q22 |   15751.630 ms    |
  all | 2666114.301 ms



Q1
  lineitem 使用条件过滤之后做聚合，过滤之后数据量为 591599349 ，约为总数据的 98.6% 大小为 84 G， 使用条件直接查询表 30DOP 时最短时间约为 2.5s ，但是个节点时间不一样， 最大时间为 4.5s, 再加上HashAggregate的时间，时间最小为7s

Q2
  subplan不需要进行reduce，但是当前会对查询进行最后加上reduce

Q8
  lineitem 和 orders 进行join，然后join的结果做reduce，之后上层还有两次reduce，导致时间增加， join 的结果集为182318228行，数据大小为 7609218190 ，做一次reduce，时间增加二十多秒
  执行计划个人觉得不正确，第一次 reduce 的 lineitem 和 orders 的结果集，然后和 supplier 和 nayion join 的结果集hashjoin，这里应该reduce 小表，上面的reduce也是类似的问题

Q9
  lineitem 需要全表扫然后join，时间是慢慢累加的，执行计划正确

Q13
  执行计划不正确，应该 reduce customer

Q17
  reduce 整个 lineitem

Q18
  两次scan lineitem， 且还reduce 一次， 执行计划应该能优化

Q20 
  Q8类似问题，reduce 大表

Q21
  多次扫描 lineitem，没有物化


1. 大部分语句使用并发，但是并发度低，且并发量不是线性增长的，ob使用256并发扫描，pg当前测试30并发之后性能不再增长，语句中进行scan和hash运算等应该都能使用hash加速的
2. 部分语句没有启用并发
3. 部分语句执行计划不正确，会进行大表reduce
4. 执行计划不确定，上面的结论是我之前记录的执行计划得出的，但是后面再测试时，部分执行计划发生变化。所以需要对语句单独设置参数

\timing on
set grammar to oracle;
-- start
select now();
-- Q1
select
  l_returnflag,
  l_linestatus,
  sum(l_quantity) as sum_qty,
  sum(l_extendedprice) as sum_base_price,
  sum(l_extendedprice * (1 - l_discount)) as sum_disc_price,
  sum(l_extendedprice * (1 - l_discount) * (1 + l_tax)) as sum_charge,
  avg(l_quantity) as avg_qty,
  avg(l_extendedprice) as avg_price,
  avg(l_discount) as avg_disc,
  count(*) as count_order
from
  lineitem
where
  l_shipdate <= date '1998-12-01' - interval '90' day
group by
  l_returnflag,
  l_linestatus
order by
  l_returnflag,
  l_linestatus;
                                                                                                                                                                                       QUERY PLAN                                                                                                                                                                                       
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=12427918.12..12427936.47 rows=6 width=236) (actual time=19401.790..19404.825 rows=4 loops=1)
   Output: l_returnflag, l_linestatus, sum(l_quantity), sum(l_extendedprice), sum((l_extendedprice * ('1'::numeric - l_discount))), sum(((l_extendedprice * ('1'::numeric - l_discount)) * ('1'::numeric + l_tax))), avg(l_quantity), avg(l_extendedprice), avg(l_discount), count(*)
   Group Key: lineitem.l_returnflag, lineitem.l_linestatus
   ->  Cluster Merge Gather  (cost=12427918.12..12427924.83 rows=270 width=236) (actual time=19401.575..19404.107 rows=200 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: lineitem.l_returnflag, lineitem.l_linestatus
         ->  Gather Merge  (cost=12427912.72..12427919.43 rows=54 width=236) (actual time=0.018..0.019 rows=0 loops=1)
               Output: l_returnflag, l_linestatus, (PARTIAL sum(l_quantity)), (PARTIAL sum(l_extendedprice)), (PARTIAL sum((l_extendedprice * ('1'::numeric - l_discount)))), (PARTIAL sum(((l_extendedprice * ('1'::numeric - l_discount)) * ('1'::numeric + l_tax)))), (PARTIAL avg(l_quantity)), (PARTIAL avg(l_extendedprice)), (PARTIAL avg(l_discount)), (PARTIAL count(*))
               Workers Planned: 9
               Workers Launched: 0
               
               
               
               
               
               ->  Sort  (cost=12426912.55..12426912.56 rows=6 width=236) (actual time=0.016..0.017 rows=0 loops=1)
                     Output: l_returnflag, l_linestatus, (PARTIAL sum(l_quantity)), (PARTIAL sum(l_extendedprice)), (PARTIAL sum((l_extendedprice * ('1'::numeric - l_discount)))), (PARTIAL sum(((l_extendedprice * ('1'::numeric - l_discount)) * ('1'::numeric + l_tax)))), (PARTIAL avg(l_quantity)), (PARTIAL avg(l_extendedprice)), (PARTIAL avg(l_discount)), (PARTIAL count(*))
                     Sort Key: lineitem.l_returnflag, lineitem.l_linestatus
                     Sort Method: quicksort  Memory: 25kB
                     Node 16387: (actual time=19261.286..19261.287 rows=4 loops=10)
                       
                       
                       
                       
                       
                       
                       
                       
                       
                     Node 16388: (actual time=19297.451..19297.452 rows=4 loops=10)
                       
                       
                       
                       
                       
                       
                       
                       
                       
                     Node 16389: (actual time=19255.993..19255.994 rows=4 loops=10)
                       
                       
                       
                       
                       
                       
                       
                       
                       
                     Node 16390: (actual time=19396.347..19396.348 rows=4 loops=10)
                       
                       
                       
                       
                       
                       
                       
                       
                       
                     Node 16391: (actual time=19384.471..19384.472 rows=4 loops=10)
                       
                       
                       
                       
                       
                       
                       
                       
                       
                     ->  Partial HashAggregate  (cost=12426912.31..12426912.47 rows=6 width=236) (actual time=0.010..0.010 rows=0 loops=1)
                           Output: l_returnflag, l_linestatus, PARTIAL sum(l_quantity), PARTIAL sum(l_extendedprice), PARTIAL sum((l_extendedprice * ('1'::numeric - l_discount))), PARTIAL sum(((l_extendedprice * ('1'::numeric - l_discount)) * ('1'::numeric + l_tax))), PARTIAL avg(l_quantity), PARTIAL avg(l_extendedprice), PARTIAL avg(l_discount), PARTIAL count(*)
                           Group Key: lineitem.l_returnflag, lineitem.l_linestatus
                           Batches: 1  Memory Usage: 24kB
                           Node 16387: (actual time=19261.239..19261.252 rows=4 loops=10)
                             
                             
                             
                             
                             
                             
                             
                             
                             
                           Node 16388: (actual time=19297.410..19297.420 rows=4 loops=10)
                             
                             
                             
                             
                             
                             
                             
                             
                             
                           Node 16389: (actual time=19255.951..19255.961 rows=4 loops=10)
                             
                             
                             
                             
                             
                             
                             
                             
                             
                           Node 16390: (actual time=19396.308..19396.318 rows=4 loops=10)
                             
                             
                             
                             
                             
                             
                             
                             
                             
                           Node 16391: (actual time=19384.428..19384.440 rows=4 loops=10)
                             
                             
                             
                             
                             
                             
                             
                             
                             
                           ->  Parallel Seq Scan on public.lineitem  (cost=0.00..12249126.15 rows=4444654 width=25) (actual time=0.007..0.007 rows=0 loops=1)
                                 Output: l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct, l_shipmode, l_comment
                                 Filter: ((lineitem.l_shipdate)::timestamp without time zone <= '1998-09-02 00:00:00'::timestamp without time zone)
                                 
                                 Node 16387: (actual time=0.033..4095.069 rows=11831168 loops=10)
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                 Node 16388: (actual time=0.029..4153.843 rows=11832700 loops=10)
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                 Node 16389: (actual time=0.032..4153.518 rows=11831235 loops=10)
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                 Node 16390: (actual time=0.026..4238.774 rows=11832522 loops=10)
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                 Node 16391: (actual time=0.029..4206.251 rows=11832310 loops=10)
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
                                   
 Planning Time: 0.814 ms
 Execution Time: 19405.438 ms
(179 rows)

-- Q2
select
  s_acctbal,
  s_name,
  n_name,
  p_partkey,
  p_mfgr,
  s_address,
  s_phone,
  s_comment
from
  part,
  supplier,
  partsupp,
  nation,
  region
where
  p_partkey = ps_partkey
  and s_suppkey = ps_suppkey
  and p_size = 15
  and p_type like '%BRASS'
  and s_nationkey = n_nationkey
  and n_regionkey = r_regionkey
  and r_name = 'EUROPE'
  and ps_supplycost = (
    select
      min(ps_supplycost)
    from
      partsupp,
      supplier,
      nation,
      region
    where
      p_partkey = ps_partkey
      and s_suppkey = ps_suppkey
      and s_nationkey = n_nationkey
      and n_regionkey = r_regionkey
      and r_name = 'EUROPE'
  )
order by
  s_acctbal desc,
  n_name,
  s_name,
  p_partkey limit 100;


                                                                                                                   QUERY PLAN                                                                                                                    
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=3351658.05..3351658.05 rows=5 width=0) (actual time=1814257.166..1814257.231 rows=100 loops=1)
   Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
   ->  Cluster Merge Gather  (cost=3351658.05..3351658.05 rows=5 width=0) (actual time=1814257.164..1814257.221 rows=100 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
         ->  Limit  (cost=3350657.95..3350657.95 rows=1 width=192) (actual time=0.042..0.047 rows=0 loops=1)
               Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
               
               
               
               
               
               ->  Sort  (cost=3350657.95..3350657.95 rows=0 width=192) (actual time=0.042..0.046 rows=0 loops=1)
                     Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                     Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
                     Sort Method: quicksort  Memory: 25kB
                     
                     
                     
                     
                     
                     ->  Hash Join  (cost=745137.06..3350657.94 rows=0 width=192) (actual time=0.028..0.033 rows=0 loops=1)
                           Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                           Inner Unique: true
                           Hash Cond: ((partsupp.ps_partkey = part.p_partkey) AND (partsupp.ps_supplycost = (SubPlan 1)))
                           
                           
                           
                           
                           
                           ->  Hash Join  (cost=35313.19..2640699.64 rows=25604 width=172) (never executed)
                                 Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, partsupp.ps_partkey, partsupp.ps_supplycost, nation.n_name
                                 Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                 
                                 
                                 
                                 
                                 
                                 ->  Seq Scan on public.partsupp  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                       Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                       
                                       
                                       
                                       
                                       
                                       
                                 ->  Hash  (cost=35213.19..35213.19 rows=8000 width=166) (never executed)
                                       Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                       
                                       
                                       
                                       
                                       
                                       ->  Cluster Reduce  (cost=10.39..35213.19 rows=8000 width=166) (never executed)
                                             Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                             
                                             
                                             
                                             
                                             
                                             ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=166) (never executed)
                                                   Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                                   Inner Unique: true
                                                   Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                   
                                                   
                                                   
                                                   
                                                   
                                                   ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=170) (never executed)
                                                         Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name, nation.n_regionkey
                                                         Inner Unique: true
                                                         Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                         
                                                         
                                                         
                                                         
                                                         
                                                         ->  Seq Scan on public.supplier  (cost=0.00..32180.00 rows=200000 width=144) (never executed)
                                                               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                               
                                                               
                                                               
                                                               
                                                               
                                                               
                                                         ->  Hash  (cost=5.25..5.25 rows=5 width=34) (never executed)
                                                               Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                               
                                                               
                                                               
                                                               
                                                               
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=34) (never executed)
                                                                     Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     
                                                                     
                                                                     
                                                                     
                                                                     
                                                   ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                         Output: region.r_regionkey
                                                         
                                                         
                                                         
                                                         
                                                         
                                                         ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                               Output: region.r_regionkey
                                                               Filter: (region.r_name = 'EUROPE'::bpchar)
                                                               Remote node: 16387,16388,16389,16390,16391
                                                               
                                                               
                                                               
                                                               
                                                               
                           ->  Hash  (cost=709595.86..709595.86 rows=15201 width=30) (actual time=0.015..0.017 rows=0 loops=1)
                                 Output: part.p_partkey, part.p_mfgr
                                 Buckets: 16384  Batches: 1  Memory Usage: 128kB
                                 
                                 
                                 
                                 
                                 
                                 ->  Seq Scan on public.part  (cost=0.00..709595.86 rows=15201 width=30) (actual time=0.014..0.014 rows=0 loops=1)
                                       Output: part.p_partkey, part.p_mfgr
                                       Filter: (((part.p_type)::text ~~ '%BRASS'::text) AND (part.p_size = 15))
                                       
                                       
                                       
                                       
                                       
                                       
                                 SubPlan 1
                                   ->  Materialize  (cost=28852782.33..28852782.35 rows=1 width=32) (never executed)
                                         Output: (min(partsupp_1.ps_supplycost))
                                         Node 16387: (actual time=68.332..68.333 rows=1 loops=25415)
                                         Node 16389: (actual time=68.358..68.358 rows=1 loops=25366)
                                         Node 16390: (actual time=68.541..68.541 rows=1 loops=25559)
                                         Node 16391: (actual time=68.065..68.065 rows=1 loops=24672)
                                         Node 16388: (actual time=68.520..68.520 rows=1 loops=25686)
                                         ->  Aggregate  (cost=28852782.33..28852782.34 rows=1 width=32) (never executed)
                                               Output: min(partsupp_1.ps_supplycost)
                                               Node 16387: (actual time=68.328..68.328 rows=1 loops=25415)
                                               Node 16389: (actual time=68.354..68.354 rows=1 loops=25366)
                                               Node 16390: (actual time=68.537..68.537 rows=1 loops=25559)
                                               Node 16391: (actual time=68.060..68.061 rows=1 loops=24672)
                                               Node 16388: (actual time=68.516..68.516 rows=1 loops=25686)
                                               ->  Hash Join  (cost=35440.19..28852782.33 rows=1 width=6) (never executed)
                                                     Output: partsupp_1.ps_supplycost
                                                     Hash Cond: (partsupp_1.ps_suppkey = supplier_1.s_suppkey)
                                                     Node 16387: (actual time=60.936..68.317 rows=1 loops=25415)
                                                     Node 16389: (actual time=60.947..68.341 rows=1 loops=25366)
                                                     Node 16390: (actual time=61.254..68.525 rows=1 loops=25559)
                                                     Node 16391: (actual time=60.791..68.049 rows=1 loops=24672)
                                                     Node 16388: (actual time=61.079..68.504 rows=1 loops=25686)
                                                     ->  Reduce Scan  (cost=1.00..28510892.47 rows=80013230 width=10) (actual time=0.185..0.186 rows=0 loops=1)
                                                           Output: partsupp_1.ps_supplycost, partsupp_1.ps_suppkey
                                                           Filter: (part.p_partkey = partsupp_1.ps_partkey)
                                                           Hash Buckets: 512
                                                           Node 16387: (actual time=1.373..6.585 rows=4 loops=25416)
                                                           Node 16389: (actual time=1.353..6.493 rows=4 loops=25367)
                                                           Node 16390: (actual time=1.377..6.528 rows=4 loops=25560)
                                                           Node 16391: (actual time=1.401..6.587 rows=4 loops=24673)
                                                           Node 16388: (actual time=1.369..6.597 rows=4 loops=25687)
                                                           ->  Cluster Reduce  (cost=1.00..27720136.32 rows=80013230 width=14) (actual time=0.001..0.001 rows=0 loops=1)
                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 ->  Seq Scan on public.partsupp partsupp_1  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                                                       Output: partsupp_1.ps_supplycost, partsupp_1.ps_suppkey, partsupp_1.ps_partkey
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                     ->  Hash  (cost=35339.19..35339.19 rows=8000 width=4) (never executed)
                                                           Output: supplier_1.s_suppkey
                                                           Node 16387: (actual time=46.197..46.197 rows=200535 loops=25415)
                                                           Node 16389: (actual time=46.307..46.307 rows=200535 loops=25366)
                                                           Node 16390: (actual time=46.488..46.488 rows=200535 loops=25559)
                                                           Node 16391: (actual time=46.039..46.039 rows=200535 loops=24672)
                                                           Node 16388: (actual time=46.261..46.261 rows=200535 loops=25686)
                                                           ->  Cluster Reduce  (cost=10.39..35339.19 rows=8000 width=4) (never executed)
                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                 Node 16387: (actual time=0.003..16.284 rows=200535 loops=25415)
                                                                 Node 16389: (actual time=0.003..16.251 rows=200535 loops=25366)
                                                                 Node 16390: (actual time=0.003..16.408 rows=200535 loops=25559)
                                                                 Node 16391: (actual time=0.004..16.405 rows=200535 loops=24672)
                                                                 Node 16388: (actual time=0.004..16.143 rows=200535 loops=25686)
                                                                 ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=4) (never executed)
                                                                       Output: supplier_1.s_suppkey
                                                                       Inner Unique: true
                                                                       Hash Cond: (nation_1.n_regionkey = region_1.r_regionkey)
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=8) (never executed)
                                                                             Output: supplier_1.s_suppkey, nation_1.n_regionkey
                                                                             Inner Unique: true
                                                                             Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             ->  Seq Scan on public.supplier supplier_1  (cost=0.00..32180.00 rows=200000 width=8) (never executed)
                                                                                   Output: supplier_1.s_suppkey, supplier_1.s_name, supplier_1.s_address, supplier_1.s_nationkey, supplier_1.s_phone, supplier_1.s_acctbal, supplier_1.s_comment
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                             ->  Hash  (cost=5.25..5.25 rows=5 width=8) (never executed)
                                                                                   Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   ->  Seq Scan on public.nation nation_1  (cost=0.00..5.25 rows=5 width=8) (never executed)
                                                                                         Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                         Remote node: 16387,16388,16389,16390,16391
                                                                                         
                                                                                         
                                                                                         
                                                                                         
                                                                                         
                                                                       ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                                             Output: region_1.r_regionkey
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             ->  Seq Scan on public.region region_1  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                                                   Output: region_1.r_regionkey
                                                                                   Filter: (region_1.r_name = 'EUROPE'::bpchar)
                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
 Planning Time: 4.552 ms
 Execution Time: 1814317.442 ms
(254 rows)


                                                                                                                   QUERY PLAN                                                                                                                    
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=3351658.05..3351658.05 rows=5 width=0) (actual time=93159.067..93159.142 rows=100 loops=1)
   Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
   ->  Cluster Merge Gather  (cost=3351658.05..3351658.05 rows=5 width=0) (actual time=93159.065..93159.132 rows=100 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
         ->  Limit  (cost=3350657.95..3350657.95 rows=1 width=192) (actual time=0.054..0.060 rows=0 loops=1)
               Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
               
               
               
               
               
               ->  Sort  (cost=3350657.95..3350657.95 rows=0 width=192) (actual time=0.053..0.058 rows=0 loops=1)
                     Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                     Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
                     Sort Method: quicksort  Memory: 25kB
                     
                     
                     
                     
                     
                     ->  Hash Join  (cost=745137.06..3350657.94 rows=0 width=192) (actual time=0.039..0.044 rows=0 loops=1)
                           Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                           Inner Unique: true
                           Hash Cond: ((partsupp.ps_partkey = part.p_partkey) AND (partsupp.ps_supplycost = (SubPlan 1)))
                           
                           
                           
                           
                           
                           ->  Hash Join  (cost=35313.19..2640699.64 rows=25604 width=172) (never executed)
                                 Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, partsupp.ps_partkey, partsupp.ps_supplycost, nation.n_name
                                 Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                 
                                 
                                 
                                 
                                 
                                 ->  Seq Scan on public.partsupp  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                       Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                       
                                       
                                       
                                       
                                       
                                       
                                 ->  Hash  (cost=35213.19..35213.19 rows=8000 width=166) (never executed)
                                       Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                       
                                       
                                       
                                       
                                       
                                       ->  Cluster Reduce  (cost=10.39..35213.19 rows=8000 width=166) (never executed)
                                             Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                             
                                             
                                             
                                             
                                             
                                             ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=166) (never executed)
                                                   Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                                   Inner Unique: true
                                                   Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                   
                                                   
                                                   
                                                   
                                                   
                                                   ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=170) (never executed)
                                                         Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name, nation.n_regionkey
                                                         Inner Unique: true
                                                         Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                         
                                                         
                                                         
                                                         
                                                         
                                                         ->  Seq Scan on public.supplier  (cost=0.00..32180.00 rows=200000 width=144) (never executed)
                                                               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                               
                                                               
                                                               
                                                               
                                                               
                                                               
                                                         ->  Hash  (cost=5.25..5.25 rows=5 width=34) (never executed)
                                                               Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                               
                                                               
                                                               
                                                               
                                                               
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=34) (never executed)
                                                                     Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     
                                                                     
                                                                     
                                                                     
                                                                     
                                                   ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                         Output: region.r_regionkey
                                                         
                                                         
                                                         
                                                         
                                                         
                                                         ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                               Output: region.r_regionkey
                                                               Filter: (region.r_name = 'EUROPE'::bpchar)
                                                               Remote node: 16387,16388,16389,16390,16391
                                                               
                                                               
                                                               
                                                               
                                                               
                           ->  Hash  (cost=709595.86..709595.86 rows=15201 width=30) (actual time=0.025..0.028 rows=0 loops=1)
                                 Output: part.p_partkey, part.p_mfgr
                                 Buckets: 16384  Batches: 1  Memory Usage: 128kB
                                 
                                 
                                 
                                 
                                 
                                 ->  Seq Scan on public.part  (cost=0.00..709595.86 rows=15201 width=30) (actual time=0.024..0.024 rows=0 loops=1)
                                       Output: part.p_partkey, part.p_mfgr
                                       Filter: (((part.p_type)::text ~~ '%BRASS'::text) AND (part.p_size = 15))
                                       
                                       
                                       
                                       
                                       
                                       
                                 SubPlan 1
                                   ->  Materialize  (cost=28852782.33..28852782.35 rows=1 width=32) (never executed)
                                         Output: (min(partsupp_1.ps_supplycost))
                                         Node 16387: (actual time=1.602..1.602 rows=1 loops=25415)
                                         Node 16388: (actual time=1.458..1.458 rows=1 loops=25686)
                                         Node 16389: (actual time=1.605..1.605 rows=1 loops=25366)
                                         Node 16391: (actual time=1.540..1.541 rows=1 loops=24672)
                                         Node 16390: (actual time=1.612..1.612 rows=1 loops=25559)
                                         ->  Aggregate  (cost=28852782.33..28852782.34 rows=1 width=32) (never executed)
                                               Output: min(partsupp_1.ps_supplycost)
                                               Node 16387: (actual time=1.600..1.600 rows=1 loops=25415)
                                               Node 16388: (actual time=1.455..1.455 rows=1 loops=25686)
                                               Node 16389: (actual time=1.603..1.603 rows=1 loops=25366)
                                               Node 16391: (actual time=1.538..1.538 rows=1 loops=24672)
                                               Node 16390: (actual time=1.610..1.610 rows=1 loops=25559)
                                               ->  Hash Join  (cost=35440.19..28852782.33 rows=1 width=6) (never executed)
                                                     Output: partsupp_1.ps_supplycost
                                                     Hash Cond: (partsupp_1.ps_suppkey = supplier_1.s_suppkey)
                                                     Node 16387: (actual time=0.640..1.597 rows=1 loops=25415)
                                                     Node 16388: (actual time=0.495..1.452 rows=1 loops=25686)
                                                     Node 16389: (actual time=0.638..1.600 rows=1 loops=25366)
                                                     Node 16391: (actual time=0.580..1.535 rows=1 loops=24672)
                                                     Node 16390: (actual time=0.639..1.607 rows=1 loops=25559)
                                                     ->  Reduce Scan  (cost=1.00..28510892.47 rows=80013230 width=10) (actual time=0.428..0.429 rows=0 loops=1)
                                                           Output: partsupp_1.ps_supplycost, partsupp_1.ps_suppkey
                                                           Filter: (part.p_partkey = partsupp_1.ps_partkey)
                                                           Hash Buckets: 2048
                                                           Node 16387: (actual time=1.022..2.306 rows=4 loops=25416)
                                                           Node 16388: (actual time=1.017..2.301 rows=4 loops=25687)
                                                           Node 16389: (actual time=1.030..2.320 rows=4 loops=25367)
                                                           Node 16391: (actual time=1.065..2.359 rows=4 loops=24673)
                                                           Node 16390: (actual time=1.045..2.347 rows=4 loops=25560)
                                                           ->  Cluster Reduce  (cost=1.00..27720136.32 rows=80013230 width=14) (actual time=0.001..0.001 rows=0 loops=1)
                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 ->  Seq Scan on public.partsupp partsupp_1  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                                                       Output: partsupp_1.ps_supplycost, partsupp_1.ps_suppkey, partsupp_1.ps_partkey
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                     ->  Hash  (cost=35339.19..35339.19 rows=8000 width=4) (never executed)
                                                           Output: supplier_1.s_suppkey
                                                           
                                                           
                                                           
                                                           
                                                           
                                                           ->  Cluster Reduce  (cost=10.39..35339.19 rows=8000 width=4) (never executed)
                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=4) (never executed)
                                                                       Output: supplier_1.s_suppkey
                                                                       Inner Unique: true
                                                                       Hash Cond: (nation_1.n_regionkey = region_1.r_regionkey)
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=8) (never executed)
                                                                             Output: supplier_1.s_suppkey, nation_1.n_regionkey
                                                                             Inner Unique: true
                                                                             Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             ->  Seq Scan on public.supplier supplier_1  (cost=0.00..32180.00 rows=200000 width=8) (never executed)
                                                                                   Output: supplier_1.s_suppkey, supplier_1.s_name, supplier_1.s_address, supplier_1.s_nationkey, supplier_1.s_phone, supplier_1.s_acctbal, supplier_1.s_comment
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                             ->  Hash  (cost=5.25..5.25 rows=5 width=8) (never executed)
                                                                                   Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   ->  Seq Scan on public.nation nation_1  (cost=0.00..5.25 rows=5 width=8) (never executed)
                                                                                         Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                         Remote node: 16387,16388,16389,16390,16391
                                                                                         
                                                                                         
                                                                                         
                                                                                         
                                                                                         
                                                                       ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                                             Output: region_1.r_regionkey
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             ->  Seq Scan on public.region region_1  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                                                   Output: region_1.r_regionkey
                                                                                   Filter: (region_1.r_name = 'EUROPE'::bpchar)
                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                   
                                                                                   
                                                                                   
                                                                                   
                                                                                   
 Planning Time: 5.839 ms
 Execution Time: 93345.116 ms
(254 rows)

-- Q3 
select
  l_orderkey,
  sum(l_extendedprice * (1 - l_discount)) as revenue,
  o_orderdate,
  o_shippriority
from
  customer,
  orders,
  lineitem
where
  c_mktsegment = 'BUILDING'
  and c_custkey = o_custkey
  and l_orderkey = o_orderkey
  and o_orderdate < date '1995-03-15'
  and l_shipdate > date '1995-03-15'
group by
  l_orderkey,
  o_orderdate,
  o_shippriority
order by
  revenue desc,
  o_orderdate limit 10;

                                                                                                                                                                                                         QUERY PLAN                                                                                                                                                                                                         
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=19443915.05..19443915.05 rows=10 width=0) (actual time=63076.282..63076.291 rows=10 loops=1)
   Output: lineitem.l_orderkey, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), orders.o_orderdate, orders.o_shippriority
   ->  Cluster Merge Gather  (cost=19443915.05..19443915.07 rows=50 width=0) (actual time=63076.280..63076.288 rows=10 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC, orders.o_orderdate
         ->  Limit  (cost=19442914.05..19442914.07 rows=10 width=44) (actual time=0.008..0.011 rows=0 loops=1)
               Output: lineitem.l_orderkey, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), orders.o_orderdate, orders.o_shippriority
               
               
               
               
               
               ->  Sort  (cost=19442914.05..19442967.48 rows=21373 width=44) (actual time=0.008..0.011 rows=0 loops=1)
                     Output: lineitem.l_orderkey, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), orders.o_orderdate, orders.o_shippriority
                     Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC, orders.o_orderdate
                     Sort Method: quicksort  Memory: 25kB
                     
                     
                     
                     
                     
                     ->  Finalize GroupAggregate  (cost=19436293.72..19442452.18 rows=21373 width=44) (actual time=0.000..0.003 rows=0 loops=1)
                           Output: lineitem.l_orderkey, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))), orders.o_orderdate, orders.o_shippriority
                           Group Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                           
                           
                           
                           
                           
                           ->  Gather Merge  (cost=19436293.72..19441650.69 rows=42746 width=44) (never executed)
                                 Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
                                 Workers Planned: 2
                                 Workers Launched: 0
                                 
                                 
                                 
                                 
                                 
                                 ->  Partial GroupAggregate  (cost=19435293.70..19435716.71 rows=21373 width=44) (never executed)
                                       Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                                       Group Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Sort  (cost=19435293.70..19435315.96 rows=8906 width=24) (never executed)
                                             Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, lineitem.l_extendedprice, lineitem.l_discount
                                             Sort Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Parallel Hash Join  (cost=4372913.58..19434709.44 rows=8906 width=24) (never executed)
                                                   Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, lineitem.l_extendedprice, lineitem.l_discount
                                                   Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Parallel Seq Scan on public.lineitem  (cost=0.00..14999255.80 rows=16667452 width=16) (never executed)
                                                         Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                         Filter: ((lineitem.l_shipdate)::timestamp without time zone > '1995-03-15 00:00:00'::timestamp without time zone)
                                                         
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                   ->  Parallel Hash  (cost=4372496.16..4372496.16 rows=33394 width=12) (never executed)
                                                         Output: orders.o_orderdate, orders.o_shippriority, orders.o_orderkey
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Hash Join  (cost=769248.04..4372496.16 rows=33394 width=12) (never executed)
                                                               Output: orders.o_orderdate, orders.o_shippriority, orders.o_orderkey
                                                               Inner Unique: true
                                                               Hash Cond: (orders.o_custkey = customer.c_custkey)
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Parallel Seq Scan on public.orders  (cost=0.00..3546728.70 rows=4166634 width=16) (never executed)
                                                                     Output: orders.o_orderdate, orders.o_shippriority, orders.o_custkey, orders.o_orderkey
                                                                     Filter: ((orders.o_orderdate)::timestamp without time zone < '1995-03-15 00:00:00'::timestamp without time zone)
                                                                     
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                               ->  Parallel Hash  (cost=748702.11..748702.11 rows=1252315 width=4) (never executed)
                                                                     Output: customer.c_custkey
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Cluster Reduce  (cost=1.00..748702.11 rows=1252315 width=4) (never executed)
                                                                           Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Parallel Seq Scan on public.customer  (cost=0.00..436403.51 rows=250463 width=4) (never executed)
                                                                                 Output: customer.c_custkey
                                                                                 Filter: (customer.c_mktsegment = 'BUILDING'::bpchar)
                                                                                 
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
 Planning Time: 1.665 ms
 Execution Time: 63078.615 ms
(221 rows)

-- Q4
select
  o_orderpriority,
  count(*) as order_count
from
  orders
where
  o_orderdate >= date '1993-07-01'
  and o_orderdate < date '1993-07-01' + interval '3' month
  and exists (
    select
      *
    from
      lineitem
    where
      l_orderkey = o_orderkey
      and l_commitdate < l_receiptdate
  )
group by
  o_orderpriority
order by
  o_orderpriority;

                                                                                                                               QUERY PLAN                                                                                                                               
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=19823992.31..19823993.78 rows=5 width=24) (actual time=30307.376..30307.409 rows=5 loops=1)
   Output: orders.o_orderpriority, count(*)
   Group Key: orders.o_orderpriority
   ->  Cluster Merge Gather  (cost=19823992.31..19823993.48 rows=50 width=24) (actual time=30307.356..30307.383 rows=75 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: orders.o_orderpriority
         ->  Gather Merge  (cost=19823991.31..19823992.48 rows=10 width=24) (actual time=0.130..0.133 rows=0 loops=1)
               Output: orders.o_orderpriority, (PARTIAL count(*))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Sort  (cost=19822991.29..19822991.30 rows=5 width=24) (actual time=0.129..0.131 rows=0 loops=1)
                     Output: orders.o_orderpriority, (PARTIAL count(*))
                     Sort Key: orders.o_orderpriority
                     Sort Method: quicksort  Memory: 25kB
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Partial HashAggregate  (cost=19822991.18..19822991.23 rows=5 width=24) (actual time=0.125..0.127 rows=0 loops=1)
                           Output: orders.o_orderpriority, PARTIAL count(*)
                           Group Key: orders.o_orderpriority
                           Batches: 1  Memory Usage: 24kB
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Parallel Hash Semi Join  (cost=15897736.42..19822990.31 rows=173 width=16) (actual time=0.124..0.126 rows=0 loops=1)
                                 Output: orders.o_orderpriority
                                 Hash Cond: (orders.o_orderkey = lineitem.l_orderkey)
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=20) (never executed)
                                       Output: orders.o_orderpriority, orders.o_orderkey
                                       Filter: (((orders.o_orderdate)::timestamp without time zone >= '1993-07-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone < '1993-10-01 00:00:00'::timestamp without time zone))
                                       
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                 ->  Parallel Hash  (cost=15624285.27..15624285.27 rows=16667452 width=4) (actual time=0.006..0.007 rows=0 loops=1)
                                       Output: lineitem.l_orderkey
                                       Buckets: 131072  Batches: 1024  Memory Usage: 1024kB
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Seq Scan on public.lineitem  (cost=0.00..15624285.27 rows=16667452 width=4) (actual time=0.005..0.005 rows=0 loops=1)
                                             Output: lineitem.l_orderkey
                                             Filter: ((lineitem.l_commitdate)::timestamp without time zone < (lineitem.l_receiptdate)::timestamp without time zone)
                                             
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
 Planning Time: 0.862 ms
 Execution Time: 30307.878 ms
(129 rows)

-- Q5
select
  n_name,
  sum(l_extendedprice * (1 - l_discount)) as revenue
from
  customer,
  orders,
  lineitem,
  supplier,
  nation,
  region
where
  c_custkey = o_custkey
  and l_orderkey = o_orderkey
  and l_suppkey = s_suppkey
  and c_nationkey = s_nationkey
  and s_nationkey = n_nationkey
  and n_regionkey = r_regionkey
  and r_name = 'ASIA'
  and o_orderdate >= date '1994-01-01'
  and o_orderdate < date '1994-01-01' + interval '1' year
group by
  n_name
order by
  revenue desc;

                                                                                                                                                                                                                        QUERY PLAN                                                                                                                                                                                                                        
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=18195180.07..18195180.09 rows=5 width=58) (actual time=49926.807..49926.811 rows=5 loops=1)
   Output: nation.n_name, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
   Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC
   Sort Method: quicksort  Memory: 25kB
   ->  Finalize GroupAggregate  (cost=18195179.62..18195180.02 rows=5 width=58) (actual time=49926.725..49926.801 rows=5 loops=1)
         Output: nation.n_name, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
         Group Key: nation.n_name
         ->  Cluster Merge Gather  (cost=18195179.62..18195179.88 rows=10 width=58) (actual time=49926.683..49926.719 rows=75 loops=1)
               Remote node: 16387,16388,16389,16390,16391
               Sort Key: nation.n_name
               ->  Gather Merge  (cost=18194179.42..18194179.68 rows=2 width=58) (actual time=0.020..0.023 rows=0 loops=1)
                     Output: nation.n_name, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
                     Workers Planned: 2
                     Workers Launched: 0
                     
                     
                     
                     
                     
                     ->  Partial GroupAggregate  (cost=18193179.40..18193179.42 rows=1 width=58) (actual time=0.018..0.021 rows=0 loops=1)
                           Output: nation.n_name, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                           Group Key: nation.n_name
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Sort  (cost=18193179.40..18193179.40 rows=1 width=38) (actual time=0.018..0.020 rows=0 loops=1)
                                 Output: nation.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                 Sort Key: nation.n_name
                                 Sort Method: quicksort  Memory: 25kB
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Hash Join  (cost=18166207.71..18193179.39 rows=1 width=38) (actual time=0.007..0.010 rows=0 loops=1)
                                       Output: nation.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                       Hash Cond: ((supplier.s_suppkey = lineitem.l_suppkey) AND (supplier.s_nationkey = customer.c_nationkey))
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                             
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                       ->  Parallel Hash  (cost=18166206.51..18166206.51 rows=80 width=50) (actual time=0.004..0.006 rows=0 loops=1)
                                             Output: customer.c_nationkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey, nation.n_name, nation.n_nationkey
                                             Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Cluster Reduce  (cost=17741391.96..18166206.51 rows=80 width=50) (actual time=0.001..0.002 rows=0 loops=1)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Hash Join  (cost=17741390.96..18166196.51 rows=80 width=50) (never executed)
                                                         Output: customer.c_nationkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey, nation.n_name, nation.n_nationkey
                                                         Inner Unique: true
                                                         Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Hash Join  (cost=17741386.89..18166190.50 rows=400 width=54) (never executed)
                                                               Output: customer.c_nationkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey, nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                               Hash Cond: (customer.c_custkey = orders.o_custkey)
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Hash Join  (cost=5.31..424621.09 rows=50001 width=42) (never executed)
                                                                     Output: customer.c_custkey, customer.c_nationkey, nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                     Inner Unique: true
                                                                     Hash Cond: (customer.c_nationkey = nation.n_nationkey)
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=8) (never executed)
                                                                           Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                                           
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                     ->  Hash  (cost=5.25..5.25 rows=5 width=34) (never executed)
                                                                           Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=34) (never executed)
                                                                                 Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                                 Remote node: 16387,16388,16389,16390,16391
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                               ->  Parallel Hash  (cost=17741256.57..17741256.57 rows=10000 width=20) (never executed)
                                                                     Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Cluster Reduce  (cost=3860008.52..17741256.57 rows=10000 width=20) (never executed)
                                                                           Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Parallel Hash Join  (cost=3860007.52..17740460.57 rows=10000 width=20) (never executed)
                                                                                 Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey
                                                                                 Inner Unique: true
                                                                                 Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 ->  Parallel Seq Scan on public.lineitem  (cost=0.00..13749196.87 rows=50002358 width=20) (never executed)
                                                                                       Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                                       
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                 ->  Parallel Hash  (cost=3859226.27..3859226.27 rows=62500 width=8) (never executed)
                                                                                       Output: orders.o_custkey, orders.o_orderkey
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=8) (never executed)
                                                                                             Output: orders.o_custkey, orders.o_orderkey
                                                                                             Filter: (((orders.o_orderdate)::timestamp without time zone >= '1994-01-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone < '1995-01-01 00:00:00'::timestamp without time zone))
                                                                                             
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                         ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                               Output: region.r_regionkey
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                                     Output: region.r_regionkey
                                                                     Filter: (region.r_name = 'ASIA'::bpchar)
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
 Planning Time: 29.294 ms
 Execution Time: 49927.800 ms
(381 rows)

-- Q6 
select
  sum(l_extendedprice * l_discount) as revenue
from
  lineitem
where
  l_shipdate >= date '1994-01-01'
  and l_shipdate < date '1994-01-01' + interval '1' year
  and l_discount between .06 - 0.01 and .06 + 0.01
  and l_quantity < 24;

                                                                                                                                                                                 QUERY PLAN                                                                                                                                                                                 
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=18125565.65..18125565.66 rows=1 width=32) (actual time=15914.259..15914.260 rows=1 loops=1)
   Output: sum((l_extendedprice * l_discount))
   ->  Cluster Gather  (cost=18125562.39..18125565.60 rows=10 width=32) (actual time=14703.415..15914.232 rows=15 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         ->  Gather  (cost=18125562.39..18125562.60 rows=2 width=32) (actual time=0.008..0.011 rows=1 loops=1)
               Output: (PARTIAL sum((l_extendedprice * l_discount)))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Partial Aggregate  (cost=18124562.39..18124562.40 rows=1 width=32) (actual time=0.008..0.009 rows=1 loops=1)
                     Output: PARTIAL sum((l_extendedprice * l_discount))
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Parallel Seq Scan on public.lineitem  (cost=0.00..18124403.13 rows=31850 width=12) (actual time=0.005..0.005 rows=0 loops=1)
                           Output: l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct, l_shipmode, l_comment
                           Filter: ((lineitem.l_discount >= 0.05) AND (lineitem.l_discount <= 0.07) AND (lineitem.l_quantity < '24'::numeric) AND ((lineitem.l_shipdate)::timestamp without time zone >= '1994-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < '1995-01-01 00:00:00'::timestamp without time zone))
                           
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
 Planning Time: 0.190 ms
 Execution Time: 15914.630 ms

-- Q7 
select
  supp_nation,
  cust_nation,
  l_year,
  sum(volume) as revenue
from
  (
    select
      n1.n_name as supp_nation,
      n2.n_name as cust_nation,
      extract(year from l_shipdate) as l_year,
      l_extendedprice * (1 - l_discount) as volume
    from
      supplier,
      lineitem,
      orders,
      customer,
      nation n1,
      nation n2
    where
      s_suppkey = l_suppkey
      and o_orderkey = l_orderkey
      and c_custkey = o_custkey
      and s_nationkey = n1.n_nationkey
      and c_nationkey = n2.n_nationkey
      and (
        (n1.n_name = 'FRANCE' and n2.n_name = 'GERMANY')
        or (n1.n_name = 'GERMANY' and n2.n_name = 'FRANCE')
      )
      and l_shipdate between date '1995-01-01' and date '1996-12-31'
  ) as shipping
group by
  supp_nation,
  cust_nation,
  l_year
order by
  supp_nation,
  cust_nation,
  l_year;

                                                                                                                                                                                                               QUERY PLAN                                                                                                                                                                                                               
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=19985549.61..19985550.07 rows=4 width=92) (actual time=31005.329..31005.396 rows=4 loops=1)
   Output: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone)), sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
   Group Key: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone))
   ->  Cluster Merge Gather  (cost=19985549.61..19985549.88 rows=10 width=92) (actual time=31005.289..31005.327 rows=60 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone))
         ->  Gather Merge  (cost=19984549.41..19984549.68 rows=2 width=92) (actual time=0.014..0.017 rows=0 loops=1)
               Output: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone)), (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Partial GroupAggregate  (cost=19983549.39..19983549.42 rows=1 width=92) (actual time=0.013..0.016 rows=0 loops=1)
                     Output: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone)), PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Group Key: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone))
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Sort  (cost=19983549.39..19983549.39 rows=1 width=72) (actual time=0.012..0.015 rows=0 loops=1)
                           Output: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone)), lineitem.l_extendedprice, lineitem.l_discount
                           Sort Key: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone))
                           Sort Method: quicksort  Memory: 25kB
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Parallel Hash Join  (cost=19558896.07..19983549.38 rows=1 width=72) (actual time=0.007..0.010 rows=0 loops=1)
                                 Output: n1.n_name, n2.n_name, date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone), lineitem.l_extendedprice, lineitem.l_discount
                                 Hash Cond: (customer.c_custkey = orders.o_custkey)
                                 Join Filter: (((n1.n_name = 'FRANCE'::bpchar) AND (n2.n_name = 'GERMANY'::bpchar)) OR ((n1.n_name = 'GERMANY'::bpchar) AND (n2.n_name = 'FRANCE'::bpchar)))
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Hash Join  (cost=5.39..424621.17 rows=10000 width=30) (never executed)
                                       Output: customer.c_custkey, n2.n_name
                                       Inner Unique: true
                                       Hash Cond: (customer.c_nationkey = n2.n_nationkey)
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=8) (never executed)
                                             Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                             
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                       ->  Hash  (cost=5.38..5.38 rows=1 width=30) (never executed)
                                             Output: n2.n_name, n2.n_nationkey
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Seq Scan on public.nation n2  (cost=0.00..5.38 rows=1 width=30) (never executed)
                                                   Output: n2.n_name, n2.n_nationkey
                                                   Filter: ((n2.n_name = 'GERMANY'::bpchar) OR (n2.n_name = 'FRANCE'::bpchar))
                                                   Remote node: 16387,16388,16389,16390,16391
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                 ->  Parallel Hash  (cost=19558889.68..19558889.68 rows=80 width=46) (actual time=0.004..0.005 rows=0 loops=1)
                                       Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, orders.o_custkey, n1.n_name
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Cluster Reduce  (cost=16277774.59..19558889.68 rows=80 width=46) (actual time=0.001..0.002 rows=0 loops=1)
                                             Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Parallel Hash Join  (cost=16277773.59..19558879.68 rows=80 width=46) (never executed)
                                                   Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, orders.o_custkey, n1.n_name
                                                   Hash Cond: (orders.o_orderkey = lineitem.l_orderkey)
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=8) (never executed)
                                                         Output: orders.o_orderkey, orders.o_custkey, orders.o_orderstatus, orders.o_totalprice, orders.o_orderdate, orders.o_orderpriority, orders.o_clerk, orders.o_shippriority, orders.o_comment
                                                         
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                   ->  Parallel Hash  (cost=16277768.59..16277768.59 rows=400 width=46) (never executed)
                                                         Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_orderkey, n1.n_name
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Hash Join  (cost=27507.97..16277768.59 rows=400 width=46) (never executed)
                                                               Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_orderkey, n1.n_name
                                                               Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Parallel Seq Scan on public.lineitem  (cost=0.00..16249314.73 rows=250012 width=24) (never executed)
                                                                     Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                     Filter: (((lineitem.l_shipdate)::timestamp without time zone >= '1995-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone <= '1996-12-31 00:00:00'::timestamp without time zone))
                                                                     
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                               ->  Parallel Hash  (cost=27466.28..27466.28 rows=3335 width=30) (never executed)
                                                                     Output: supplier.s_suppkey, n1.n_name
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Cluster Reduce  (cost=6.39..27466.28 rows=3335 width=30) (never executed)
                                                                           Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Hash Join  (cost=5.39..26607.88 rows=667 width=30) (never executed)
                                                                                 Output: supplier.s_suppkey, n1.n_name
                                                                                 Inner Unique: true
                                                                                 Hash Cond: (supplier.s_nationkey = n1.n_nationkey)
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                                       Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                       
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                 ->  Hash  (cost=5.38..5.38 rows=1 width=30) (never executed)
                                                                                       Output: n1.n_name, n1.n_nationkey
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       ->  Seq Scan on public.nation n1  (cost=0.00..5.38 rows=1 width=30) (never executed)
                                                                                             Output: n1.n_name, n1.n_nationkey
                                                                                             Filter: ((n1.n_name = 'FRANCE'::bpchar) OR (n1.n_name = 'GERMANY'::bpchar))
                                                                                             Remote node: 16387,16388,16389,16390,16391
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
 Planning Time: 22.403 ms
 Execution Time: 31006.504 ms
(378 rows)

-- Q8 
select
  o_year,
  sum(case
    when nation = 'BRAZIL' then volume
    else 0
  end) / sum(volume) as mkt_share
from
  (
    select
      extract(year from o_orderdate) as o_year,
      l_extendedprice * (1 - l_discount) as volume,
      n2.n_name as nation
    from
      part,
      supplier,
      lineitem,
      orders,
      customer,
      nation n1,
      nation n2,
      region
    where
      p_partkey = l_partkey
      and s_suppkey = l_suppkey
      and l_orderkey = o_orderkey
      and o_custkey = c_custkey
      and c_nationkey = n1.n_nationkey
      and n1.n_regionkey = r_regionkey
      and r_name = 'AMERICA'
      and s_nationkey = n2.n_nationkey
      and o_orderdate between date '1995-01-01' and date '1996-12-31'
      and p_type = 'ECONOMY ANODIZED STEEL'
  ) as all_nations
group by
  o_year
order by
  o_year;

                                                                                                                                                                                                                           QUERY PLAN                                                                                                                                                                                                                           
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=18708615.69..18708616.09 rows=1 width=40) (actual time=80033.082..80033.106 rows=2 loops=1)
   Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), ((sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END))::numeric / sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
   Group Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
   ->  Cluster Merge Gather  (cost=18708615.69..18708615.97 rows=10 width=40) (actual time=80033.048..80033.060 rows=30 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
         ->  Gather Merge  (cost=18707615.49..18707615.77 rows=2 width=48) (actual time=0.304..0.308 rows=0 loops=1)
               Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), (PARTIAL sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END)), (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Partial GroupAggregate  (cost=18706615.47..18706615.51 rows=1 width=48) (actual time=0.303..0.306 rows=0 loops=1)
                     Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), PARTIAL sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END), PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Group Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Sort  (cost=18706615.47..18706615.47 rows=1 width=46) (actual time=0.302..0.305 rows=0 loops=1)
                           Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), n2.n_name, lineitem.l_extendedprice, lineitem.l_discount
                           Sort Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                           Sort Method: quicksort  Memory: 25kB
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Hash Join  (cost=18281812.16..18706615.46 rows=1 width=46) (actual time=0.293..0.296 rows=0 loops=1)
                                 Output: date_part('year'::text, (orders.o_orderdate)::timestamp without time zone), n2.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                 Inner Unique: true
                                 Hash Cond: (n1.n_regionkey = region.r_regionkey)
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Hash Join  (cost=18281808.08..18706611.37 rows=1 width=46) (never executed)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, n1.n_regionkey, n2.n_name
                                       Hash Cond: (customer.c_custkey = orders.o_custkey)
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Hash Join  (cost=5.31..424621.09 rows=50001 width=8) (never executed)
                                             Output: customer.c_custkey, n1.n_regionkey
                                             Inner Unique: true
                                             Hash Cond: (customer.c_nationkey = n1.n_nationkey)
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=8) (never executed)
                                                   Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                   
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                             ->  Hash  (cost=5.25..5.25 rows=5 width=8) (never executed)
                                                   Output: n1.n_nationkey, n1.n_regionkey
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Seq Scan on public.nation n1  (cost=0.00..5.25 rows=5 width=8) (never executed)
                                                         Output: n1.n_nationkey, n1.n_regionkey
                                                         Remote node: 16387,16388,16389,16390,16391
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                       ->  Parallel Hash  (cost=18281802.76..18281802.76 rows=1 width=46) (never executed)
                                             Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, orders.o_custkey, n2.n_name
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Cluster Reduce  (cost=17767992.87..18281802.76 rows=1 width=46) (never executed)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Parallel Hash Join  (cost=17767991.87..18281798.68 rows=1 width=46) (never executed)
                                                         Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                         Hash Cond: (part.p_partkey = lineitem.l_partkey)
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Seq Scan on public.part  (cost=0.00..513765.23 rows=11085 width=4) (never executed)
                                                               Output: part.p_partkey, part.p_name, part.p_mfgr, part.p_brand, part.p_type, part.p_size, part.p_container, part.p_retailprice, part.p_comment
                                                               Filter: ((part.p_type)::text = 'ECONOMY ANODIZED STEEL'::text)
                                                               
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                         ->  Parallel Hash  (cost=17767986.87..17767986.87 rows=400 width=50) (never executed)
                                                               Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Cluster Reduce  (cost=3886658.99..17767986.87 rows=400 width=50) (never executed)
                                                                     Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_partkey)), 0)]
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Hash Join  (cost=3886657.99..17767952.87 rows=400 width=50) (never executed)
                                                                           Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                                           Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Cluster Reduce  (cost=3860008.52..17741265.57 rows=10000 width=28) (never executed)
                                                                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 ->  Parallel Hash Join  (cost=3860007.52..17740460.57 rows=10000 width=28) (never executed)
                                                                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, lineitem.l_suppkey, orders.o_orderdate, orders.o_custkey
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       ->  Parallel Seq Scan on public.lineitem  (cost=0.00..13749196.87 rows=50002358 width=24) (never executed)
                                                                                             Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                                             
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                       ->  Parallel Hash  (cost=3859226.27..3859226.27 rows=62500 width=12) (never executed)
                                                                                             Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=12) (never executed)
                                                                                                   Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                                   Filter: (((orders.o_orderdate)::timestamp without time zone >= '1995-01-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone <= '1996-12-31 00:00:00'::timestamp without time zone))
                                                                                                   
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                           ->  Parallel Hash  (cost=26607.81..26607.81 rows=3333 width=30) (never executed)
                                                                                 Output: supplier.s_suppkey, n2.n_name
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 ->  Hash Join  (cost=5.31..26607.81 rows=3333 width=30) (never executed)
                                                                                       Output: supplier.s_suppkey, n2.n_name
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (supplier.s_nationkey = n2.n_nationkey)
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                             
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                       ->  Hash  (cost=5.25..5.25 rows=5 width=30) (never executed)
                                                                                             Output: n2.n_name, n2.n_nationkey
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             ->  Seq Scan on public.nation n2  (cost=0.00..5.25 rows=5 width=30) (never executed)
                                                                                                   Output: n2.n_name, n2.n_nationkey
                                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                 ->  Hash  (cost=4.06..4.06 rows=1 width=4) (actual time=0.290..0.290 rows=0 loops=1)
                                       Output: region.r_regionkey
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (actual time=0.287..0.288 rows=0 loops=1)
                                             Output: region.r_regionkey
                                             Filter: (region.r_name = 'AMERICA'::bpchar)
                                             Remote node: 16387,16388,16389,16390,16391
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
 Planning Time: 30.975 ms
 Execution Time: 80034.168 ms
(502 rows)

-- Q9 
select
  nation,
  o_year,
  sum(amount) as sum_profit
from
  (
    select
      n_name as nation,
      extract(year from o_orderdate) as o_year,
      l_extendedprice * (1 - l_discount) - ps_supplycost * l_quantity as amount
    from
      part,
      supplier,
      lineitem,
      partsupp,
      orders,
      nation
    where
      s_suppkey = l_suppkey
      and ps_suppkey = l_suppkey
      and ps_partkey = l_partkey
      and p_partkey = l_partkey
      and o_orderkey = l_orderkey
      and s_nationkey = n_nationkey
      and p_name like '%green%'
  ) as profit
group by
  nation,
  o_year
order by
  nation,
  o_year desc;

                                                                                                                                                                                                         QUERY PLAN                                                                                                                                                                                                         
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=19886199.23..19886199.61 rows=1 width=66) (actual time=87058.762..89938.439 rows=175 loops=1)
   Output: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), sum(((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)) - (partsupp.ps_supplycost * lineitem.l_quantity)))
   Group Key: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
   ->  Cluster Merge Gather  (cost=19886199.23..19886199.50 rows=10 width=66) (actual time=87058.723..89936.573 rows=2625 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)) DESC
         ->  Gather Merge  (cost=19885199.03..19885199.30 rows=2 width=66) (actual time=0.062..0.066 rows=0 loops=1)
               Output: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), (PARTIAL sum(((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)) - (partsupp.ps_supplycost * lineitem.l_quantity))))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Partial GroupAggregate  (cost=19884199.00..19884199.04 rows=1 width=66) (actual time=0.061..0.064 rows=0 loops=1)
                     Output: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), PARTIAL sum(((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)) - (partsupp.ps_supplycost * lineitem.l_quantity)))
                     Group Key: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Sort  (cost=19884199.00..19884199.01 rows=1 width=57) (actual time=0.060..0.063 rows=0 loops=1)
                           Output: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), lineitem.l_extendedprice, lineitem.l_discount, partsupp.ps_supplycost, lineitem.l_quantity
                           Sort Key: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)) DESC
                           Sort Method: quicksort  Memory: 25kB
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Parallel Hash Join  (cost=16603093.21..19884198.99 rows=1 width=57) (actual time=0.050..0.054 rows=0 loops=1)
                                 Output: nation.n_name, date_part('year'::text, (orders.o_orderdate)::timestamp without time zone), lineitem.l_extendedprice, lineitem.l_discount, partsupp.ps_supplycost, lineitem.l_quantity
                                 Hash Cond: (orders.o_orderkey = lineitem.l_orderkey)
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=8) (never executed)
                                       Output: orders.o_orderkey, orders.o_custkey, orders.o_orderstatus, orders.o_totalprice, orders.o_orderdate, orders.o_orderpriority, orders.o_clerk, orders.o_shippriority, orders.o_comment
                                       
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                 ->  Parallel Hash  (cost=16603093.20..16603093.20 rows=1 width=53) (actual time=0.047..0.050 rows=0 loops=1)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_quantity, lineitem.l_orderkey, partsupp.ps_supplycost, nation.n_name
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Hash Join  (cost=2655054.45..16603093.20 rows=1 width=53) (actual time=0.046..0.049 rows=0 loops=1)
                                             Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_quantity, lineitem.l_orderkey, partsupp.ps_supplycost, nation.n_name
                                             Hash Cond: ((supplier.s_suppkey = partsupp.ps_suppkey) AND (lineitem.l_partkey = partsupp.ps_partkey))
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Parallel Hash Join  (cost=31092.72..13976131.32 rows=400019 width=59) (never executed)
                                                   Output: supplier.s_suppkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_quantity, lineitem.l_suppkey, lineitem.l_partkey, lineitem.l_orderkey, nation.n_name
                                                   Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Parallel Seq Scan on public.lineitem  (cost=0.00..13749196.87 rows=50002358 width=29) (never executed)
                                                         Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                         
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                   ->  Parallel Hash  (cost=30884.41..30884.41 rows=16665 width=30) (never executed)
                                                         Output: supplier.s_suppkey, nation.n_name
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Cluster Reduce  (cost=6.31..30884.41 rows=16665 width=30) (never executed)
                                                               Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Hash Join  (cost=5.31..26607.81 rows=3333 width=30) (never executed)
                                                                     Output: supplier.s_suppkey, nation.n_name
                                                                     Inner Unique: true
                                                                     Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                           Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                           
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                     ->  Hash  (cost=5.25..5.25 rows=5 width=30) (never executed)
                                                                           Output: nation.n_name, nation.n_nationkey
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=30) (never executed)
                                                                                 Output: nation.n_name, nation.n_nationkey
                                                                                 Remote node: 16387,16388,16389,16390,16391
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                             ->  Parallel Hash  (cost=2623153.53..2623153.53 rows=53880 width=18) (actual time=0.003..0.004 rows=0 loops=1)
                                                   Output: part.p_partkey, partsupp.ps_supplycost, partsupp.ps_suppkey, partsupp.ps_partkey
                                                   Buckets: 65536  Batches: 2  Memory Usage: 512kB
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Cluster Reduce  (cost=514607.97..2623153.53 rows=53880 width=18) (actual time=0.001..0.001 rows=0 loops=1)
                                                         Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Hash Join  (cost=514606.97..2609462.33 rows=10776 width=18) (never executed)
                                                               Output: part.p_partkey, partsupp.ps_supplycost, partsupp.ps_suppkey, partsupp.ps_partkey
                                                               Inner Unique: true
                                                               Hash Cond: (partsupp.ps_partkey = part.p_partkey)
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Parallel Seq Scan on public.partsupp  (cost=0.00..2077352.47 rows=6667769 width=14) (never executed)
                                                                     Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                                                     
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                               ->  Parallel Hash  (cost=513765.23..513765.23 rows=67339 width=4) (never executed)
                                                                     Output: part.p_partkey
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Seq Scan on public.part  (cost=0.00..513765.23 rows=67339 width=4) (never executed)
                                                                           Output: part.p_partkey
                                                                           Filter: ((part.p_name)::text ~~ '%green%'::text)
                                                                           
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
 Planning Time: 41.746 ms
 Execution Time: 89941.042 ms
(376 rows)

-- Q10
select
  c_custkey,
  c_name,
  sum(l_extendedprice * (1 - l_discount)) as revenue,
  c_acctbal,
  n_name,
  c_address,
  c_phone,
  c_comment
from
  customer,
  orders,
  lineitem,
  nation
where
  c_custkey = o_custkey
  and l_orderkey = o_orderkey
  and o_orderdate >= date '1993-10-01'
  and o_orderdate < date '1993-10-01' + interval '3' month
  and l_returnflag = 'R'
  and c_nationkey = n_nationkey
group by
  c_custkey,
  c_name,
  c_acctbal,
  c_phone,
  n_name,
  c_address,
  c_comment
order by
  revenue desc 
limit 20;

                                                                                                                                                                                                                  QUERY PLAN                                                                                                                                                                                                                  
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=18693783.62..18693783.63 rows=20 width=0) (actual time=26571.794..26571.808 rows=20 loops=1)
   Output: customer.c_custkey, customer.c_name, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), customer.c_acctbal, nation.n_name, customer.c_address, customer.c_phone, customer.c_comment
   ->  Cluster Merge Gather  (cost=18693783.62..18693783.67 rows=100 width=0) (actual time=26571.794..26571.805 rows=20 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC
         ->  Limit  (cost=18692781.62..18692781.67 rows=20 width=201) (actual time=0.007..0.009 rows=0 loops=1)
               Output: customer.c_custkey, customer.c_name, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), customer.c_acctbal, nation.n_name, customer.c_address, customer.c_phone, customer.c_comment
               
               
               
               
               
               ->  Sort  (cost=18692781.62..18692782.21 rows=237 width=201) (actual time=0.006..0.008 rows=0 loops=1)
                     Output: customer.c_custkey, customer.c_name, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), customer.c_acctbal, nation.n_name, customer.c_address, customer.c_phone, customer.c_comment
                     Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC
                     Sort Method: quicksort  Memory: 25kB
                     
                     
                     
                     
                     
                     ->  Finalize GroupAggregate  (cost=18692708.45..18692775.31 rows=237 width=201) (actual time=0.000..0.002 rows=0 loops=1)
                           Output: customer.c_custkey, customer.c_name, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))), customer.c_acctbal, nation.n_name, customer.c_address, customer.c_phone, customer.c_comment
                           Group Key: customer.c_custkey, nation.n_name
                           
                           
                           
                           
                           
                           ->  Gather Merge  (cost=18692708.45..18692767.60 rows=474 width=201) (never executed)
                                 Output: customer.c_custkey, nation.n_name, customer.c_name, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                 Workers Planned: 2
                                 Workers Launched: 0
                                 
                                 
                                 
                                 
                                 
                                 ->  Partial GroupAggregate  (cost=18691708.42..18691712.87 rows=237 width=201) (never executed)
                                       Output: customer.c_custkey, nation.n_name, customer.c_name, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))), customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                       Group Key: customer.c_custkey, nation.n_name
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Sort  (cost=18691708.42..18691708.67 rows=99 width=181) (never executed)
                                             Output: customer.c_custkey, nation.n_name, customer.c_name, lineitem.l_extendedprice, lineitem.l_discount, customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                             Sort Key: customer.c_custkey, nation.n_name
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Parallel Hash Join  (cost=18266901.78..18691705.14 rows=99 width=181) (never executed)
                                                   Output: customer.c_custkey, nation.n_name, customer.c_name, lineitem.l_extendedprice, lineitem.l_discount, customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                                   Hash Cond: (customer.c_custkey = orders.o_custkey)
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Hash Join  (cost=5.31..424621.09 rows=50001 width=169) (never executed)
                                                         Output: customer.c_custkey, customer.c_name, customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment, nation.n_name
                                                         Inner Unique: true
                                                         Hash Cond: (customer.c_nationkey = nation.n_nationkey)
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=147) (never executed)
                                                               Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                               
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                         ->  Hash  (cost=5.25..5.25 rows=5 width=30) (never executed)
                                                               Output: nation.n_name, nation.n_nationkey
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=30) (never executed)
                                                                     Output: nation.n_name, nation.n_nationkey
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                   ->  Parallel Hash  (cost=18266865.58..18266865.58 rows=2471 width=16) (never executed)
                                                         Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Cluster Reduce  (cost=3860008.52..18266865.58 rows=2471 width=16) (never executed)
                                                               Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Parallel Hash Join  (cost=3860007.52..18266667.25 rows=2471 width=16) (never executed)
                                                                     Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount
                                                                     Inner Unique: true
                                                                     Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Seq Scan on public.lineitem  (cost=0.00..14374226.33 rows=12355582 width=16) (never executed)
                                                                           Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                           Filter: (lineitem.l_returnflag = 'R'::bpchar)
                                                                           
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                     ->  Parallel Hash  (cost=3859226.27..3859226.27 rows=62500 width=8) (never executed)
                                                                           Output: orders.o_custkey, orders.o_orderkey
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=8) (never executed)
                                                                                 Output: orders.o_custkey, orders.o_orderkey
                                                                                 Filter: (((orders.o_orderdate)::timestamp without time zone >= '1993-10-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone < '1994-01-01 00:00:00'::timestamp without time zone))
                                                                                 
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
 Planning Time: 2.820 ms
 Execution Time: 26574.637 ms
(274 rows)

-- Q11
select
  ps_partkey,
  sum(ps_supplycost * ps_availqty) as value
from
  partsupp,
  supplier,
  nation
where
  ps_suppkey = s_suppkey
  and s_nationkey = n_nationkey
  and n_name = 'GERMANY'
group by
  ps_partkey having
    sum(ps_supplycost * ps_availqty) > (
      select
        sum(ps_supplycost * ps_availqty) * 0.0000010000
      from
        partsupp,
        supplier,
        nation
      where
        ps_suppkey = s_suppkey
        and s_nationkey = n_nationkey
        and n_name = 'GERMANY'
    )
order by
  value desc;

                                                                                                             QUERY PLAN                                                                                                              
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Merge Gather  (cost=20075969062.80..20075969084.13 rows=42675 width=0) (actual time=5137.264..5179.741 rows=92698 loops=1)
   Remote node: 16387,16388,16389,16390,16391
   Sort Key: (sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty)))) DESC
   ->  Sort  (cost=2139786.19..2139807.53 rows=8535 width=36) (actual time=0.010..0.014 rows=0 loops=1)
         Output: partsupp.ps_partkey, (sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty))))
         Sort Key: (sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty)))) DESC
         Sort Method: quicksort  Memory: 25kB
         
         
         
         
         
         InitPlan 1 (returns $0)
           ->  Cluster Reduce  (cost=2131151.15..2131154.47 rows=1 width=32) (never executed)
                 Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                 
                 
                 
                 
                 
                 ->  Finalize Aggregate  (cost=2131150.15..2131150.17 rows=1 width=32) (actual time=4054.994..4054.997 rows=1 loops=1)
                       Output: (sum((partsupp_1.ps_supplycost * "numeric"(partsupp_1.ps_availqty))) * 0.000001)
                       
                       
                       
                       
                       
                       ->  Cluster Reduce  (cost=2131143.89..2131150.10 rows=10 width=32) (actual time=0.029..4054.967 rows=16 loops=1)
                             Reduce: '12338'::oid
                             Node 16387: (never executed)
                             Node 16388: (never executed)
                             Node 16389: (never executed)
                             Node 16390: (never executed)
                             Node 16391: (never executed)
                             ->  Gather  (cost=2131142.89..2131143.10 rows=2 width=32) (actual time=0.013..0.016 rows=1 loops=1)
                                   Output: (PARTIAL sum((partsupp_1.ps_supplycost * "numeric"(partsupp_1.ps_availqty))))
                                   Workers Planned: 2
                                   Workers Launched: 0
                                   
                                   
                                   
                                   
                                   
                                   ->  Partial Aggregate  (cost=2130142.89..2130142.90 rows=1 width=32) (actual time=0.013..0.015 rows=1 loops=1)
                                         Output: PARTIAL sum((partsupp_1.ps_supplycost * "numeric"(partsupp_1.ps_availqty)))
                                         
                                           
                                           
                                         
                                           
                                           
                                         
                                           
                                           
                                         
                                           
                                           
                                         
                                           
                                           
                                         ->  Parallel Hash Join  (cost=27483.91..2130062.88 rows=10668 width=10) (actual time=0.009..0.010 rows=0 loops=1)
                                               Output: partsupp_1.ps_supplycost, partsupp_1.ps_availqty
                                               Hash Cond: (partsupp_1.ps_suppkey = supplier_1.s_suppkey)
                                               
                                                 
                                                 
                                               
                                                 
                                                 
                                               
                                                 
                                                 
                                               
                                                 
                                                 
                                               
                                                 
                                                 
                                               ->  Parallel Seq Scan on public.partsupp partsupp_1  (cost=0.00..2077352.47 rows=6667769 width=14) (never executed)
                                                     Output: partsupp_1.ps_partkey, partsupp_1.ps_suppkey, partsupp_1.ps_availqty, partsupp_1.ps_supplycost, partsupp_1.ps_comment
                                                     
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                               ->  Parallel Hash  (cost=27442.22..27442.22 rows=3335 width=4) (actual time=0.003..0.004 rows=0 loops=1)
                                                     Output: supplier_1.s_suppkey
                                                     Buckets: 8192  Batches: 1  Memory Usage: 64kB
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     
                                                       
                                                       
                                                     ->  Cluster Reduce  (cost=6.33..27442.22 rows=3335 width=4) (actual time=0.001..0.002 rows=0 loops=1)
                                                           Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           ->  Hash Join  (cost=5.33..26607.82 rows=667 width=4) (never executed)
                                                                 Output: supplier_1.s_suppkey
                                                                 Inner Unique: true
                                                                 Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 
                                                                 ->  Parallel Seq Scan on public.supplier supplier_1  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                       Output: supplier_1.s_suppkey, supplier_1.s_name, supplier_1.s_address, supplier_1.s_nationkey, supplier_1.s_phone, supplier_1.s_acctbal, supplier_1.s_comment
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                 ->  Hash  (cost=5.31..5.31 rows=1 width=4) (never executed)
                                                                       Output: nation_1.n_nationkey
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       
                                                                       ->  Seq Scan on public.nation nation_1  (cost=0.00..5.31 rows=1 width=4) (never executed)
                                                                             Output: nation_1.n_nationkey
                                                                             Filter: (nation_1.n_name = 'GERMANY'::bpchar)
                                                                             Remote node: 16387,16388,16389,16390,16391
                                                                             
                                                                             
                                                                             
                                                                             
                                                                             
         ->  Finalize GroupAggregate  (cost=2131776.64..2139228.89 rows=8535 width=36) (actual time=0.000..0.001 rows=0 loops=1)
               Output: partsupp.ps_partkey, sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty)))
               Group Key: partsupp.ps_partkey
               Filter: (sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty))) > $0)
               
               
               
               
               
               ->  Gather Merge  (cost=2131776.64..2138140.72 rows=51208 width=36) (never executed)
                     Output: partsupp.ps_partkey, (PARTIAL sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty))))
                     Workers Planned: 2
                     Workers Launched: 0
                     
                     
                     
                     
                     
                     ->  Partial GroupAggregate  (cost=2130776.62..2131230.02 rows=25604 width=36) (never executed)
                           Output: partsupp.ps_partkey, PARTIAL sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty)))
                           Group Key: partsupp.ps_partkey
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Sort  (cost=2130776.62..2130803.29 rows=10668 width=14) (never executed)
                                 Output: partsupp.ps_partkey, partsupp.ps_supplycost, partsupp.ps_availqty
                                 Sort Key: partsupp.ps_partkey
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Hash Join  (cost=27483.91..2130062.88 rows=10668 width=14) (never executed)
                                       Output: partsupp.ps_partkey, partsupp.ps_supplycost, partsupp.ps_availqty
                                       Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Seq Scan on public.partsupp  (cost=0.00..2077352.47 rows=6667769 width=18) (never executed)
                                             Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                             
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                       ->  Parallel Hash  (cost=27442.22..27442.22 rows=3335 width=4) (never executed)
                                             Output: supplier.s_suppkey
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Cluster Reduce  (cost=6.33..27442.22 rows=3335 width=4) (never executed)
                                                   Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Hash Join  (cost=5.33..26607.82 rows=667 width=4) (never executed)
                                                         Output: supplier.s_suppkey
                                                         Inner Unique: true
                                                         Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                               
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                         ->  Hash  (cost=5.31..5.31 rows=1 width=4) (never executed)
                                                               Output: nation.n_nationkey
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.31 rows=1 width=4) (never executed)
                                                                     Output: nation.n_nationkey
                                                                     Filter: (nation.n_name = 'GERMANY'::bpchar)
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
 Planning Time: 2.638 ms
 Execution Time: 9242.111 ms
(363 rows)

-- Q12  
select
  l_shipmode,
  sum(case
    when o_orderpriority = '1-URGENT'
      or o_orderpriority = '2-HIGH'
      then 1
    else 0
  end) as high_line_count,
  sum(case
    when o_orderpriority <> '1-URGENT'
      and o_orderpriority <> '2-HIGH'
      then 1
    else 0
  end) as low_line_count
from
  orders,
  lineitem
where
  o_orderkey = l_orderkey
  and l_shipmode in ('MAIL', 'SHIP')
  and l_commitdate < l_receiptdate
  and l_shipdate < l_commitdate
  and l_receiptdate >= date '1994-01-01'
  and l_receiptdate < date '1994-01-01' + interval '1' year
group by
  l_shipmode
order by
  l_shipmode;
                                                                                                                                                                                                                                                                                 QUERY PLAN                                                                                                                                                                                                                                                                                  
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=24162590.97..24162593.20 rows=7 width=27) (actual time=26082.548..26082.560 rows=2 loops=1)
   Output: lineitem.l_shipmode, sum(CASE WHEN ((orders.o_orderpriority = '1-URGENT'::bpchar) OR (orders.o_orderpriority = '2-HIGH'::bpchar)) THEN 1 ELSE 0 END), sum(CASE WHEN ((orders.o_orderpriority <> '1-URGENT'::bpchar) AND (orders.o_orderpriority <> '2-HIGH'::bpchar)) THEN 1 ELSE 0 END)
   Group Key: lineitem.l_shipmode
   ->  Cluster Merge Gather  (cost=24162590.97..24162592.60 rows=70 width=27) (actual time=26082.528..26082.542 rows=30 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: lineitem.l_shipmode
         ->  Gather Merge  (cost=24162589.57..24162591.20 rows=14 width=27) (actual time=0.084..0.087 rows=0 loops=1)
               Output: lineitem.l_shipmode, (PARTIAL sum(CASE WHEN ((orders.o_orderpriority = '1-URGENT'::bpchar) OR (orders.o_orderpriority = '2-HIGH'::bpchar)) THEN 1 ELSE 0 END)), (PARTIAL sum(CASE WHEN ((orders.o_orderpriority <> '1-URGENT'::bpchar) AND (orders.o_orderpriority <> '2-HIGH'::bpchar)) THEN 1 ELSE 0 END))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Sort  (cost=24161589.54..24161589.56 rows=7 width=27) (actual time=0.083..0.085 rows=0 loops=1)
                     Output: lineitem.l_shipmode, (PARTIAL sum(CASE WHEN ((orders.o_orderpriority = '1-URGENT'::bpchar) OR (orders.o_orderpriority = '2-HIGH'::bpchar)) THEN 1 ELSE 0 END)), (PARTIAL sum(CASE WHEN ((orders.o_orderpriority <> '1-URGENT'::bpchar) AND (orders.o_orderpriority <> '2-HIGH'::bpchar)) THEN 1 ELSE 0 END))
                     Sort Key: lineitem.l_shipmode
                     Sort Method: quicksort  Memory: 25kB
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Partial HashAggregate  (cost=24161589.38..24161589.45 rows=7 width=27) (actual time=0.078..0.081 rows=0 loops=1)
                           Output: lineitem.l_shipmode, PARTIAL sum(CASE WHEN ((orders.o_orderpriority = '1-URGENT'::bpchar) OR (orders.o_orderpriority = '2-HIGH'::bpchar)) THEN 1 ELSE 0 END), PARTIAL sum(CASE WHEN ((orders.o_orderpriority <> '1-URGENT'::bpchar) AND (orders.o_orderpriority <> '2-HIGH'::bpchar)) THEN 1 ELSE 0 END)
                           Group Key: lineitem.l_shipmode
                           Batches: 1  Memory Usage: 24kB
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Parallel Hash Join  (cost=3463721.91..24161583.81 rows=318 width=27) (actual time=0.077..0.079 rows=0 loops=1)
                                 Output: lineitem.l_shipmode, orders.o_orderpriority
                                 Inner Unique: true
                                 Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Seq Scan on public.lineitem  (cost=0.00..20624521.00 rows=7963 width=15) (never executed)
                                       Output: lineitem.l_shipmode, lineitem.l_orderkey
                                       Filter: ((lineitem.l_shipmode = ANY ('{MAIL,SHIP}'::bpchar[])) AND ((lineitem.l_receiptdate)::timestamp without time zone >= '1994-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_receiptdate)::timestamp without time zone < '1995-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_commitdate)::timestamp without time zone < (lineitem.l_receiptdate)::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < (lineitem.l_commitdate)::timestamp without time zone))
                                       
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                 ->  Parallel Hash  (cost=3234231.13..3234231.13 rows=12499902 width=20) (actual time=0.053..0.055 rows=0 loops=1)
                                       Output: orders.o_orderpriority, orders.o_orderkey
                                       Buckets: 65536  Batches: 512  Memory Usage: 512kB
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=20) (actual time=0.053..0.053 rows=0 loops=1)
                                             Output: orders.o_orderpriority, orders.o_orderkey
                                             
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
 Planning Time: 0.556 ms
 Execution Time: 26083.005 ms
(129 rows)

-- Q13  
select
  c_count,
  count(*) as custdist
from
  (
    select
      c_custkey,
      count(o_orderkey)
    from
      customer left outer join orders on
        c_custkey = o_custkey
        and o_comment not like '%special%requests%'
    group by
      c_custkey
  ) as c_orders (c_custkey, c_count)
group by
  c_count
order by
  custdist desc,
  c_count desc;

                                                                                              QUERY PLAN                                                                                               
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Merge Gather  (cost=5391195.30..5391195.40 rows=200 width=0) (actual time=31726.465..31726.481 rows=45 loops=1)
   Remote node: 16387,16388,16389,16390,16391
   Sort Key: (count(*)) DESC, (count(orders.o_orderkey)) DESC
   ->  Sort  (cost=5390191.30..5390191.40 rows=40 width=16) (actual time=0.006..0.008 rows=0 loops=1)
         Output: (count(orders.o_orderkey)), (count(*))
         Sort Key: (count(*)) DESC, (count(orders.o_orderkey)) DESC
         Sort Method: quicksort  Memory: 25kB
         
         
         
         
         
         ->  Finalize GroupAggregate  (cost=5390188.34..5390190.24 rows=40 width=16) (actual time=0.000..0.003 rows=0 loops=1)
               Output: (count(orders.o_orderkey)), count(*)
               Group Key: (count(orders.o_orderkey))
               
               
               
               
               
               ->  Sort  (cost=5390188.34..5390188.84 rows=200 width=16) (never executed)
                     Output: (count(orders.o_orderkey)), (PARTIAL count(*))
                     Sort Key: (count(orders.o_orderkey)) DESC
                     
                     
                     
                     
                     
                     ->  Cluster Reduce  (cost=5390160.70..5390180.70 rows=200 width=16) (never executed)
                           Reduce: ('[0:4]={16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint8((count(orders.o_orderkey)))), 0)]
                           
                           
                           
                           
                           
                           ->  Partial HashAggregate  (cost=5390159.70..5390161.70 rows=200 width=16) (never executed)
                                 Output: (count(orders.o_orderkey)), PARTIAL count(*)
                                 Group Key: count(orders.o_orderkey)
                                 
                                 
                                 
                                 
                                 
                                 ->  Finalize GroupAggregate  (cost=5110319.78..5345158.83 rows=600012 width=12) (never executed)
                                       Output: customer.c_custkey, count(orders.o_orderkey)
                                       Group Key: customer.c_custkey
                                       
                                       
                                       
                                       
                                       
                                       ->  Cluster Merge Reduce  (cost=5110319.78..5334259.76 rows=979790 width=12) (never executed)
                                             Reduce: ('[0:4]={16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(customer.c_custkey)), 0)]
                                             Sort Key: customer.c_custkey
                                             
                                             
                                             
                                             
                                             
                                             ->  Gather Merge  (cost=5110318.72..5231983.96 rows=979790 width=12) (never executed)
                                                   Output: customer.c_custkey, (PARTIAL count(orders.o_orderkey))
                                                   Workers Planned: 2
                                                   Workers Launched: 0
                                                   
                                                   
                                                   
                                                   
                                                   
                                                   ->  Partial GroupAggregate  (cost=5109318.69..5117891.86 rows=489895 width=12) (never executed)
                                                         Output: customer.c_custkey, PARTIAL count(orders.o_orderkey)
                                                         Group Key: customer.c_custkey
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Sort  (cost=5109318.69..5110543.43 rows=489895 width=8) (never executed)
                                                               Output: customer.c_custkey, orders.o_orderkey
                                                               Sort Key: customer.c_custkey
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Parallel Hash Left Join  (cost=4545851.67..5056319.44 rows=489895 width=8) (never executed)
                                                                     Output: customer.c_custkey, orders.o_orderkey
                                                                     Hash Cond: (customer.c_custkey = orders.o_custkey)
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=4) (never executed)
                                                                           Output: customer.c_custkey
                                                                           
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                     ->  Parallel Hash  (cost=4344917.42..4344917.42 rows=12247380 width=8) (never executed)
                                                                           Output: orders.o_orderkey, orders.o_custkey
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Cluster Reduce  (cost=1.00..4344917.42 rows=12247380 width=8) (never executed)
                                                                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 ->  Parallel Seq Scan on public.orders  (cost=0.00..3390479.92 rows=12247380 width=8) (never executed)
                                                                                       Output: orders.o_orderkey, orders.o_custkey
                                                                                       Filter: ((orders.o_comment)::text !~~ '%special%requests%'::text)
                                                                                       
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
 Planning Time: 0.800 ms
 Execution Time: 31731.124 ms
(195 rows)
-- Q14  
select
  100.00 * sum(case
    when p_type like 'PROMO%'
      then l_extendedprice * (1 - l_discount)
    else 0
  end) / sum(l_extendedprice * (1 - l_discount)) as promo_revenue
from
  lineitem,
  part
where
  l_partkey = p_partkey
  and l_shipdate >= date '1995-09-01'
  and l_shipdate < date '1995-09-01' + interval '1' month;

                                                                                                                                QUERY PLAN                                                                                                                                
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=16810859.01..16810859.03 rows=1 width=32) (actual time=13518.411..13518.413 rows=1 loops=1)
   Output: (('100'::numeric * (sum(CASE WHEN ((part.p_type)::text ~~ 'PROMO%'::text) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END))::numeric) / sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
   ->  Cluster Gather  (cost=16810855.73..16810858.94 rows=10 width=40) (actual time=13456.605..13518.385 rows=15 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         ->  Gather  (cost=16809855.73..16809855.94 rows=2 width=40) (actual time=0.034..0.036 rows=1 loops=1)
               Output: (PARTIAL sum(CASE WHEN ((part.p_type)::text ~~ 'PROMO%'::text) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END)), (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Partial Aggregate  (cost=16808855.73..16808855.74 rows=1 width=40) (actual time=0.034..0.035 rows=1 loops=1)
                     Output: PARTIAL sum(CASE WHEN ((part.p_type)::text ~~ 'PROMO%'::text) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END), PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Parallel Hash Join  (cost=525160.23..16808636.15 rows=8783 width=33) (actual time=0.031..0.031 rows=0 loops=1)
                           Output: part.p_type, lineitem.l_extendedprice, lineitem.l_discount
                           Inner Unique: true
                           Hash Cond: (lineitem.l_partkey = part.p_partkey)
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Cluster Reduce  (cost=1.00..16268984.63 rows=250012 width=16) (never executed)
                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_partkey)), 0)]
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Seq Scan on public.lineitem  (cost=0.00..16249314.73 rows=250012 width=16) (never executed)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey
                                       Filter: (((lineitem.l_shipdate)::timestamp without time zone >= '1995-09-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < '1995-10-01 00:00:00'::timestamp without time zone))
                                       
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                           ->  Parallel Hash  (cost=492932.18..492932.18 rows=1666644 width=25) (actual time=0.007..0.007 rows=0 loops=1)
                                 Output: part.p_type, part.p_partkey
                                 Buckets: 65536  Batches: 128  Memory Usage: 512kB
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Parallel Seq Scan on public.part  (cost=0.00..492932.18 rows=1666644 width=25) (actual time=0.005..0.005 rows=0 loops=1)
                                       Output: part.p_type, part.p_partkey
                                       
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
 Planning Time: 0.717 ms
 Execution Time: 13519.179 ms
(123 rows)

-- Q15
create view revenue0 (supplier_no, total_revenue) as
  select
    l_suppkey,
    sum(l_extendedprice * (1 - l_discount))
  from
    lineitem
  where
    l_shipdate >= date '1996-01-01'
    and l_shipdate < date '1996-01-01' + interval '3' month
  group by
    l_suppkey;

select
  s_suppkey,
  s_name,
  s_address,
  s_phone,
  total_revenue
from
  supplier,
  revenue0
where
  s_suppkey = supplier_no
  and total_revenue = (
    select
      max(total_revenue)
    from
      revenue0
  )
order by
  s_suppkey;

drop view revenue0;

                                                                                                                                                  QUERY PLAN                                                                                                                                                  
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Merge Gather  (cost=10573797281.50..10573797281.73 rows=450 width=0) (actual time=16785.748..16785.753 rows=1 loops=1)
   Remote node: 16387,16388,16389,16390,16391
   Sort Key: supplier.s_suppkey
   ->  Sort  (cost=16434848.84..16434849.06 rows=90 width=103) (actual time=0.014..0.018 rows=0 loops=1)
         Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_phone, revenue0.total_revenue
         Sort Key: supplier.s_suppkey
         Sort Method: quicksort  Memory: 25kB
         
         
         
         
         
         InitPlan 1 (returns $0)
           ->  Cluster Reduce  (cost=16404776.49..16404779.80 rows=1 width=32) (never executed)
                 Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                 
                 
                 
                 
                 
                 ->  Finalize Aggregate  (cost=16404775.49..16404775.50 rows=1 width=32) (actual time=16648.624..16648.626 rows=1 loops=1)
                       Output: max((sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))))
                       
                       
                       
                       
                       
                       ->  Cluster Reduce  (cost=16404770.97..16404775.48 rows=5 width=32) (actual time=0.033..16648.610 rows=6 loops=1)
                             Reduce: '12338'::oid
                             Node 16388: (never executed)
                             Node 16389: (never executed)
                             Node 16390: (never executed)
                             Node 16391: (never executed)
                             Node 16387: (never executed)
                             ->  Partial Aggregate  (cost=16404769.97..16404769.98 rows=1 width=32) (actual time=0.006..0.007 rows=1 loops=1)
                                   Output: PARTIAL max((sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))))
                                   
                                   
                                   
                                   
                                   
                                   ->  Finalize GroupAggregate  (cost=16277004.94..16399139.71 rows=90084 width=36) (actual time=0.000..0.001 rows=0 loops=1)
                                         Output: lineitem_1.l_suppkey, sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))
                                         Group Key: lineitem_1.l_suppkey
                                         
                                         
                                         
                                         
                                         
                                         ->  Cluster Merge Reduce  (cost=16277004.94..16394263.47 rows=500024 width=36) (never executed)
                                               Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem_1.l_suppkey)), 0)]
                                               Sort Key: lineitem_1.l_suppkey
                                               
                                               
                                               
                                               
                                               
                                               ->  Gather Merge  (cost=16277003.88..16340969.36 rows=500024 width=36) (never executed)
                                                     Output: lineitem_1.l_suppkey, (PARTIAL sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount))))
                                                     Workers Planned: 2
                                                     Workers Launched: 0
                                                     
                                                     
                                                     
                                                     
                                                     
                                                     ->  Partial GroupAggregate  (cost=16276003.86..16282254.16 rows=250012 width=36) (never executed)
                                                           Output: lineitem_1.l_suppkey, PARTIAL sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))
                                                           Group Key: lineitem_1.l_suppkey
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           
                                                             
                                                             
                                                           ->  Sort  (cost=16276003.86..16276628.89 rows=250012 width=16) (never executed)
                                                                 Output: lineitem_1.l_suppkey, lineitem_1.l_extendedprice, lineitem_1.l_discount
                                                                 Sort Key: lineitem_1.l_suppkey
                                                                 
                                                                   
                                                                   
                                                                 
                                                                   
                                                                   
                                                                 
                                                                   
                                                                   
                                                                 
                                                                   
                                                                   
                                                                 
                                                                   
                                                                   
                                                                 ->  Parallel Seq Scan on public.lineitem lineitem_1  (cost=0.00..16249314.73 rows=250012 width=16) (never executed)
                                                                       Output: lineitem_1.l_suppkey, lineitem_1.l_extendedprice, lineitem_1.l_discount
                                                                       Filter: (((lineitem_1.l_shipdate)::timestamp without time zone >= '1996-01-01 00:00:00'::timestamp without time zone) AND ((lineitem_1.l_shipdate)::timestamp without time zone < '1996-04-01 00:00:00'::timestamp without time zone))
                                                                       
                                                                       
                                                                         
                                                                         
                                                                       
                                                                         
                                                                         
                                                                       
                                                                         
                                                                         
                                                                       
                                                                         
                                                                         
                                                                       
                                                                         
                                                                         
         ->  Hash Join  (cost=16402140.92..16434845.92 rows=90 width=103) (actual time=0.008..0.010 rows=0 loops=1)
               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_phone, revenue0.total_revenue
               Inner Unique: true
               Hash Cond: (supplier.s_suppkey = revenue0.supplier_no)
               
               
               
               
               
               ->  Seq Scan on public.supplier  (cost=0.00..32180.00 rows=200000 width=71) (never executed)
                     Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                     
                     Node 16388: (never executed)
                     Node 16389: (never executed)
                     Node 16390: (never executed)
                     Node 16391: (never executed)
                     
               ->  Hash  (cost=16402112.77..16402112.77 rows=2252 width=36) (actual time=0.003..0.004 rows=0 loops=1)
                     Output: revenue0.total_revenue, revenue0.supplier_no
                     Buckets: 4096  Batches: 1  Memory Usage: 32kB
                     
                     
                     
                     
                     
                     ->  Subquery Scan on revenue0  (cost=16277004.94..16402112.77 rows=2252 width=36) (actual time=0.002..0.003 rows=0 loops=1)
                           Output: revenue0.total_revenue, revenue0.supplier_no
                           
                           
                           
                           
                           
                           ->  Finalize GroupAggregate  (cost=16277004.94..16402090.25 rows=450 width=36) (actual time=0.000..0.001 rows=0 loops=1)
                                 Output: lineitem.l_suppkey, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                                 Group Key: lineitem.l_suppkey
                                 Filter: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) = $0)
                                 
                                 
                                 
                                 
                                 
                                 ->  Cluster Merge Reduce  (cost=16277004.94..16394263.47 rows=500024 width=36) (never executed)
                                       Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                       Sort Key: lineitem.l_suppkey
                                       
                                       
                                       
                                       
                                       
                                       ->  Gather Merge  (cost=16277003.88..16340969.36 rows=500024 width=36) (never executed)
                                             Output: lineitem.l_suppkey, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
                                             Workers Planned: 2
                                             Workers Launched: 0
                                             
                                             
                                             
                                             
                                             
                                             ->  Partial GroupAggregate  (cost=16276003.86..16282254.16 rows=250012 width=36) (never executed)
                                                   Output: lineitem.l_suppkey, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                                                   Group Key: lineitem.l_suppkey
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Sort  (cost=16276003.86..16276628.89 rows=250012 width=16) (never executed)
                                                         Output: lineitem.l_suppkey, lineitem.l_extendedprice, lineitem.l_discount
                                                         Sort Key: lineitem.l_suppkey
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Seq Scan on public.lineitem  (cost=0.00..16249314.73 rows=250012 width=16) (never executed)
                                                               Output: lineitem.l_suppkey, lineitem.l_extendedprice, lineitem.l_discount
                                                               Filter: (((lineitem.l_shipdate)::timestamp without time zone >= '1996-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < '1996-04-01 00:00:00'::timestamp without time zone))
                                                               
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
 Planning Time: 0.670 ms
 Execution Time: 33442.890 ms
(236 rows)

-- Q16
select
  p_brand,
  p_type,
  p_size,
  count(distinct ps_suppkey) as supplier_cnt
from
  partsupp,
  part
where
  p_partkey = ps_partkey
  and p_brand <> 'Brand#45'
  and p_type not like 'MEDIUM POLISHED%'
  and p_size in (49, 14, 23, 45, 19, 3, 36, 9)
  and ps_suppkey not in (
    select
      s_suppkey
    from
      supplier
    where
      s_comment like '%Customer%Complaints%'
  )
group by
  p_brand,
  p_type,
  p_size
order by
  supplier_cnt desc,
  p_brand,
  p_type,
  p_size;

                                                                                                    QUERY PLAN                                                                                                    
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Merge Gather  (cost=3807405.16..3807495.04 rows=179776 width=0) (actual time=23588.679..23598.193 rows=27840 loops=1)
   Remote node: 16387,16388,16389,16390,16391
   Sort Key: (count(DISTINCT partsupp.ps_suppkey)) DESC, part.p_brand, part.p_type, part.p_size
   ->  Sort  (cost=3802809.64..3802899.52 rows=35955 width=44) (actual time=0.007..0.009 rows=0 loops=1)
         Output: part.p_brand, part.p_type, part.p_size, (count(DISTINCT partsupp.ps_suppkey))
         Sort Key: (count(DISTINCT partsupp.ps_suppkey)) DESC, part.p_brand, part.p_type, part.p_size
         Sort Method: quicksort  Memory: 25kB
         
         
         
         
         
         ->  GroupAggregate  (cost=3799140.08..3800088.92 rows=35955 width=44) (actual time=0.000..0.002 rows=0 loops=1)
               Output: part.p_brand, part.p_type, part.p_size, count(DISTINCT partsupp.ps_suppkey)
               Group Key: part.p_brand, part.p_type, part.p_size
               
               
               
               
               
               ->  Sort  (cost=3799140.08..3799257.94 rows=47143 width=40) (never executed)
                     Output: part.p_brand, part.p_type, part.p_size, partsupp.ps_suppkey
                     Sort Key: part.p_brand, part.p_type, part.p_size
                     
                     
                     
                     
                     
                     ->  Cluster Reduce  (cost=959418.10..3795480.68 rows=47143 width=40) (never executed)
                           Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashbpchar(part.p_brand)), 0)]
                           
                           
                           
                           
                           
                           ->  Hash Join  (cost=959417.10..3791664.97 rows=47143 width=40) (never executed)
                                 Output: part.p_brand, part.p_type, part.p_size, partsupp.ps_suppkey
                                 Inner Unique: true
                                 Hash Cond: (partsupp.ps_partkey = part.p_partkey)
                                 
                                 
                                 
                                 
                                 
                                 ->  Seq Scan on public.partsupp  (cost=37856.25..2781985.65 rows=8001323 width=8) (never executed)
                                       Output: partsupp.ps_suppkey, partsupp.ps_partkey
                                       Filter: (NOT (hashed SubPlan 1))
                                       
                                       
                                       
                                       
                                       
                                       
                                       SubPlan 1
                                         ->  Cluster Reduce  (cost=1.00..37831.00 rows=10100 width=4) (never executed)
                                               Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                               
                                               
                                               
                                               
                                               
                                               ->  Seq Scan on public.supplier  (cost=0.00..34680.00 rows=2020 width=4) (never executed)
                                                     Output: supplier.s_suppkey
                                                     Filter: ((supplier.s_comment)::text ~~ '%Customer%Complaints%'::text)
                                                     
                                                     
                                                     
                                                     
                                                     
                                                     
                                 ->  Hash  (cost=909593.10..909593.10 rows=589180 width=40) (never executed)
                                       Output: part.p_brand, part.p_type, part.p_size, part.p_partkey
                                       
                                       
                                       
                                       
                                       
                                       ->  Seq Scan on public.part  (cost=0.00..909593.10 rows=589180 width=40) (never executed)
                                             Output: part.p_brand, part.p_type, part.p_size, part.p_partkey
                                             Filter: ((part.p_brand <> 'Brand#45'::bpchar) AND ((part.p_type)::text !~~ 'MEDIUM POLISHED%'::text) AND (part.p_size = ANY ('{49,14,23,45,19,3,36,9}'::integer[])))
                                             
                                             
                                             
                                             
                                             
                                             
 Planning Time: 0.555 ms
 Execution Time: 23600.211 ms
(88 rows)

-- Q17
select
  sum(l_extendedprice) / 7.0 as avg_yearly
from
  lineitem,
  part
where
  p_partkey = l_partkey
  and p_brand = 'Brand#23'
  and p_container = 'MED BOX'
  and l_quantity < (
    select
      0.2 * avg(l_quantity)
    from
      lineitem
    where
      l_partkey = p_partkey
  );

                                                                                                                                                                                             QUERY PLAN                                                                                                                                                                                             
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=269812352.05..269812352.06 rows=1 width=32) (actual time=1219598.825..1219598.829 rows=1 loops=1)
   Output: (sum(lineitem.l_extendedprice) / 7.0)
   ->  Cluster Gather  (cost=269812350.20..269812352.01 rows=6 width=32) (actual time=1107544.591..1219598.759 rows=6 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         ->  Partial Aggregate  (cost=269811350.20..269811350.21 rows=1 width=32) (actual time=1107544.100..1107544.104 rows=1 loops=1)
               Output: PARTIAL sum(lineitem.l_extendedprice)
               
               
               
               
               
               ->  Hash Join  (cost=710932.43..269811347.17 rows=1211 width=8) (actual time=1574.119..1107535.461 rows=9028 loops=1)
                     Output: lineitem.l_extendedprice
                     Inner Unique: true
                     Hash Cond: (lineitem.l_partkey = part.p_partkey)
                     Join Filter: (lineitem.l_quantity < (SubPlan 1))
                     Rows Removed by Join Filter: 91424
                     
                     
                     
                     
                     
                     ->  Cluster Reduce  (cost=1.00..55360537.28 rows=100004715 width=17) (actual time=0.286..24537.203 rows=100000053 loops=1)
                           Reduce: ('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(6, hashint4(lineitem.l_partkey)), 0)]
                           
                           
                           
                           
                           
                           ->  Seq Scan on public.lineitem  (cost=0.00..17249361.88 rows=120005658 width=17) (actual time=0.007..0.007 rows=0 loops=1)
                                 Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                 
                                 
                                 
                                 
                                 
                                 
                     ->  Hash  (cost=710888.36..710888.36 rows=3446 width=4) (actual time=1497.653..1497.655 rows=3338 loops=1)
                           Output: part.p_partkey
                           Buckets: 4096  Batches: 1  Memory Usage: 150kB
                           
                           
                           
                           
                           
                           ->  Cluster Reduce  (cost=1.00..710888.36 rows=3446 width=4) (actual time=0.512..1497.190 rows=3338 loops=1)
                                 Reduce: ('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(6, hashint4(part.p_partkey)), 0)]
                                 
                                 
                                 
                                 
                                 
                                 ->  Seq Scan on public.part  (cost=0.00..709595.86 rows=4135 width=4) (actual time=0.015..0.015 rows=0 loops=1)
                                       Output: part.p_partkey
                                       Filter: ((part.p_brand = 'Brand#23'::bpchar) AND (part.p_container = 'MED BOX'::bpchar))
                                       
                                       
                                       
                                       
                                       
                                       
                     SubPlan 1
                       ->  Aggregate  (cost=213477366.06..213477366.07 rows=1 width=32) (actual time=10.618..10.618 rows=1 loops=100452)
                             Output: (0.2 * avg(lineitem_1.l_quantity))
                             Node 16387: (actual time=10.531..10.531 rows=1 loops=98555)
                             Node 16389: (actual time=10.569..10.569 rows=1 loops=99151)
                             Node 16388: (actual time=10.512..10.512 rows=1 loops=100020)
                             Node 16391: (actual time=10.570..10.571 rows=1 loops=102855)
                             Node 16390: (actual time=10.609..10.609 rows=1 loops=99949)
                             ->  Reduce Scan  (cost=1.00..211977295.33 rows=600028290 width=5) (actual time=3.731..13.952 rows=31 loops=100453)
                                   Output: lineitem_1.l_quantity
                                   Filter: (lineitem_1.l_partkey = part.p_partkey)
                                   Hash Buckets: 2048
                                   Node 16387: (actual time=2.231..12.387 rows=31 loops=98556)
                                   Node 16389: (actual time=2.274..12.454 rows=31 loops=99152)
                                   Node 16388: (actual time=2.209..12.352 rows=31 loops=100021)
                                   Node 16391: (actual time=2.184..12.362 rows=31 loops=102856)
                                   Node 16390: (actual time=2.185..12.406 rows=31 loops=99950)
                                   ->  Cluster Reduce  (cost=1.00..206047327.88 rows=600028290 width=9) (actual time=151554.798..198587.494 rows=600037902 loops=1)
                                         Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                                         
                                         
                                         
                                         
                                         
                                         ->  Seq Scan on public.lineitem lineitem_1  (cost=0.00..17249361.88 rows=120005658 width=9) (actual time=0.019..0.019 rows=0 loops=1)
                                               Output: lineitem_1.l_quantity, lineitem_1.l_partkey
                                               
                                               
                                               
                                               
                                               
                                               
 Planning Time: 0.989 ms
 Execution Time: 1557475.906 ms
(95 rows)

-- Q18  
select
  c_name,
  c_custkey,
  o_orderkey,
  o_orderdate,
  o_totalprice,
  sum(l_quantity)
from
  customer,
  orders,
  lineitem
where
  o_orderkey in (
    select
      l_orderkey
    from
      lineitem
    group by
      l_orderkey having
        sum(l_quantity) > 300
  )
  and c_custkey = o_custkey
  and o_orderkey = l_orderkey
group by
  c_name,
  c_custkey,
  o_orderkey,
  o_orderdate,
  o_totalprice
order by
  o_totalprice desc,
  o_orderdate limit 100;

                                                                                                                                                                                                         QUERY PLAN                                                                                                                                                                                                         
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=46471884.13..46471884.18 rows=100 width=0) (actual time=130963.045..130963.103 rows=100 loops=1)
   Output: customer.c_name, customer.c_custkey, orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, (sum(lineitem.l_quantity))
   ->  Cluster Merge Gather  (cost=46471884.13..46471884.38 rows=500 width=0) (actual time=130963.043..130963.093 rows=100 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: orders.o_totalprice DESC, orders.o_orderdate
         ->  Limit  (cost=46470874.13..46470874.38 rows=100 width=71) (actual time=0.007..0.010 rows=0 loops=1)
               Output: customer.c_name, customer.c_custkey, orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, (sum(lineitem.l_quantity))
               
               
               
               
               
               ->  Sort  (cost=46470874.13..46470885.23 rows=4439 width=71) (actual time=0.007..0.009 rows=0 loops=1)
                     Output: customer.c_name, customer.c_custkey, orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, (sum(lineitem.l_quantity))
                     Sort Key: orders.o_totalprice DESC, orders.o_orderdate
                     Sort Method: quicksort  Memory: 25kB
                     
                     
                     
                     
                     
                     ->  GroupAggregate  (cost=46470604.61..46470704.48 rows=4439 width=71) (actual time=0.000..0.002 rows=0 loops=1)
                           Output: customer.c_name, customer.c_custkey, orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, sum(lineitem.l_quantity)
                           Group Key: customer.c_custkey, orders.o_orderkey
                           
                           
                           
                           
                           
                           ->  Sort  (cost=46470604.61..46470615.71 rows=4439 width=44) (never executed)
                                 Output: customer.c_custkey, orders.o_orderkey, customer.c_name, orders.o_orderdate, orders.o_totalprice, lineitem.l_quantity
                                 Sort Key: customer.c_custkey, orders.o_orderkey
                                 
                                 
                                 
                                 
                                 
                                 ->  Hash Join  (cost=28751010.89..46470335.71 rows=4439 width=44) (never executed)
                                       Output: customer.c_custkey, orders.o_orderkey, customer.c_name, orders.o_orderdate, orders.o_totalprice, lineitem.l_quantity
                                       Inner Unique: true
                                       Hash Cond: (orders.o_custkey = customer.c_custkey)
                                       
                                       
                                       
                                       
                                       
                                       ->  Cluster Reduce  (cost=28187651.28..45889034.83 rows=22194 width=25) (never executed)
                                             Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                             
                                             
                                             
                                             
                                             
                                             ->  Hash Join  (cost=28187650.28..45887255.31 rows=22194 width=25) (never executed)
                                                   Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey, lineitem.l_quantity
                                                   Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                   
                                                   
                                                   
                                                   
                                                   
                                                   ->  Seq Scan on public.lineitem  (cost=0.00..17249361.88 rows=120005658 width=9) (never executed)
                                                         Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                         
                                                         
                                                         
                                                         
                                                         
                                                         
                                                   ->  Hash  (cost=28187303.52..28187303.52 rows=27741 width=24) (never executed)
                                                         Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey, lineitem_1.l_orderkey
                                                         
                                                         
                                                         
                                                         
                                                         
                                                         ->  Hash Join  (cost=23645059.81..28187303.52 rows=27741 width=24) (never executed)
                                                               Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey, lineitem_1.l_orderkey
                                                               Inner Unique: true
                                                               Hash Cond: (orders.o_orderkey = lineitem_1.l_orderkey)
                                                               
                                                               
                                                               
                                                               
                                                               
                                                               ->  Seq Scan on public.orders  (cost=0.00..4109224.32 rows=29999766 width=20) (never executed)
                                                                     Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey
                                                                     
                                                                     
                                                                     
                                                                     
                                                                     
                                                                     
                                                               ->  Hash  (cost=23633680.88..23633680.88 rows=693515 width=4) (never executed)
                                                                     Output: lineitem_1.l_orderkey
                                                                     
                                                                     
                                                                     
                                                                     
                                                                     
                                                                     ->  Finalize GroupAggregate  (cost=22707978.12..23626745.73 rows=138703 width=4) (never executed)
                                                                           Output: lineitem_1.l_orderkey
                                                                           Group Key: lineitem_1.l_orderkey
                                                                           Filter: (sum(lineitem_1.l_quantity) > '300'::numeric)
                                                                           
                                                                           
                                                                           
                                                                           
                                                                           
                                                                           ->  Gather Merge  (cost=22707978.12..23589295.90 rows=4161092 width=36) (never executed)
                                                                                 Output: lineitem_1.l_orderkey, (PARTIAL sum(lineitem_1.l_quantity))
                                                                                 Workers Planned: 2
                                                                                 Workers Launched: 0
                                                                                 
                                                                                 
                                                                                 
                                                                                 
                                                                                 
                                                                                 ->  Partial GroupAggregate  (cost=22706978.10..23108002.61 rows=2080546 width=36) (never executed)
                                                                                       Output: lineitem_1.l_orderkey, PARTIAL sum(lineitem_1.l_quantity)
                                                                                       Group Key: lineitem_1.l_orderkey
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       ->  Sort  (cost=22706978.10..22831984.00 rows=50002358 width=9) (never executed)
                                                                                             Output: lineitem_1.l_orderkey, lineitem_1.l_quantity
                                                                                             Sort Key: lineitem_1.l_orderkey
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             ->  Parallel Seq Scan on public.lineitem lineitem_1  (cost=0.00..13749196.87 rows=50002358 width=9) (never executed)
                                                                                                   Output: lineitem_1.l_orderkey, lineitem_1.l_quantity
                                                                                                   
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                       ->  Hash  (cost=508279.89..508279.89 rows=3000058 width=23) (never executed)
                                             Output: customer.c_name, customer.c_custkey
                                             
                                             
                                             
                                             
                                             
                                             ->  Seq Scan on public.customer  (cost=0.00..508279.89 rows=3000058 width=23) (never executed)
                                                   Output: customer.c_name, customer.c_custkey
                                                   
                                                   
                                                   
                                                   
                                                   
                                                   
 Planning Time: 3.858 ms
 Execution Time: 130985.611 ms
(189 rows)

-- Q19
select
  sum(l_extendedprice* (1 - l_discount)) as revenue
from
  lineitem,
  part
where
  (
    p_partkey = l_partkey
    and p_brand = 'Brand#12'
    and p_container in ('SM CASE', 'SM BOX', 'SM PACK', 'SM PKG')
    and l_quantity >= 1 and l_quantity <= 1 + 10
    and p_size between 1 and 5
    and l_shipmode in ('AIR', 'AIR REG')
    and l_shipinstruct = 'DELIVER IN PERSON'
  )
  or
  (
    p_partkey = l_partkey
    and p_brand = 'Brand#23'
    and p_container in ('MED BAG', 'MED BOX', 'MED PKG', 'MED PACK')
    and l_quantity >= 10 and l_quantity <= 10 + 10
    and p_size between 1 and 10
    and l_shipmode in ('AIR', 'AIR REG')
    and l_shipinstruct = 'DELIVER IN PERSON'
  )
  or
  (
    p_partkey = l_partkey
    and p_brand = 'Brand#34'
    and p_container in ('LG CASE', 'LG BOX', 'LG PACK', 'LG PKG')
    and l_quantity >= 20 and l_quantity <= 20 + 10
    and p_size between 1 and 15
    and l_shipmode in ('AIR', 'AIR REG')
    and l_shipinstruct = 'DELIVER IN PERSON'
  );

                                                                                                                                                                                                                                                                                                                                                                              QUERY PLAN                                                                                                                                                                                                                                                                                                                                                                              
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize Aggregate  (cost=19522960.36..19522960.37 rows=1 width=32) (actual time=17574.714..17574.717 rows=1 loops=1)
   Output: sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
   ->  Cluster Gather  (cost=19522957.10..19522960.31 rows=10 width=32) (actual time=15535.460..17574.678 rows=15 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         ->  Gather  (cost=19521957.10..19521957.31 rows=2 width=32) (actual time=0.071..0.075 rows=1 loops=1)
               Output: (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
               Workers Planned: 2
               Workers Launched: 0
               
               
               
               
               
               ->  Partial Aggregate  (cost=19520957.10..19520957.11 rows=1 width=32) (actual time=0.071..0.073 rows=1 loops=1)
                     Output: PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     
                       
                       
                     ->  Parallel Hash Join  (cost=769136.47..19520956.86 rows=32 width=12) (actual time=0.068..0.069 rows=0 loops=1)
                           Output: lineitem.l_extendedprice, lineitem.l_discount
                           Inner Unique: true
                           Hash Cond: (lineitem.l_partkey = part.p_partkey)
                           Join Filter: (((part.p_brand = 'Brand#12'::bpchar) AND (part.p_container = ANY ('{"SM CASE","SM BOX","SM PACK","SM PKG"}'::bpchar[])) AND (lineitem.l_quantity >= '1'::numeric) AND (lineitem.l_quantity <= '11'::numeric) AND (part.p_size <= 5)) OR ((part.p_brand = 'Brand#23'::bpchar) AND (part.p_container = ANY ('{"MED BAG","MED BOX","MED PKG","MED PACK"}'::bpchar[])) AND (lineitem.l_quantity >= '10'::numeric) AND (lineitem.l_quantity <= '20'::numeric) AND (part.p_size <= 10)) OR ((part.p_brand = 'Brand#34'::bpchar) AND (part.p_container = ANY ('{"LG CASE","LG BOX","LG PACK","LG PKG"}'::bpchar[])) AND (lineitem.l_quantity >= '20'::numeric) AND (lineitem.l_quantity <= '30'::numeric) AND (part.p_size <= 15)))
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           
                             
                             
                           ->  Parallel Seq Scan on public.lineitem  (cost=0.00..18749432.60 rows=909635 width=21) (never executed)
                                 Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                 Filter: ((lineitem.l_shipmode = ANY ('{AIR,"AIR REG"}'::bpchar[])) AND (lineitem.l_shipinstruct = 'DELIVER IN PERSON'::bpchar) AND (((lineitem.l_quantity >= '1'::numeric) AND (lineitem.l_quantity <= '11'::numeric)) OR ((lineitem.l_quantity >= '10'::numeric) AND (lineitem.l_quantity <= '20'::numeric)) OR ((lineitem.l_quantity >= '20'::numeric) AND (lineitem.l_quantity <= '30'::numeric))))
                                 
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                           ->  Parallel Hash  (cost=768886.78..768886.78 rows=19975 width=30) (actual time=0.003..0.004 rows=0 loops=1)
                                 Output: part.p_partkey, part.p_brand, part.p_container, part.p_size
                                 Buckets: 65536  Batches: 1  Memory Usage: 512kB
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Cluster Reduce  (cost=1.00..768886.78 rows=19975 width=30) (actual time=0.001..0.001 rows=0 loops=1)
                                       Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Seq Scan on public.part  (cost=0.00..763761.78 rows=3995 width=30) (never executed)
                                             Output: part.p_partkey, part.p_brand, part.p_container, part.p_size
                                             Filter: ((part.p_size >= 1) AND (((part.p_brand = 'Brand#12'::bpchar) AND (part.p_container = ANY ('{"SM CASE","SM BOX","SM PACK","SM PKG"}'::bpchar[])) AND (part.p_size <= 5)) OR ((part.p_brand = 'Brand#23'::bpchar) AND (part.p_container = ANY ('{"MED BAG","MED BOX","MED PKG","MED PACK"}'::bpchar[])) AND (part.p_size <= 10)) OR ((part.p_brand = 'Brand#34'::bpchar) AND (part.p_container = ANY ('{"LG CASE","LG BOX","LG PACK","LG PKG"}'::bpchar[])) AND (part.p_size <= 15))))
                                             
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
 Planning Time: 1.160 ms
 Execution Time: 17575.368 ms
(125 rows)

-- Q20
select
  s_name,
  s_address
from
  supplier,
  nation
where
  s_suppkey in (
    select
      ps_suppkey
    from
      partsupp
    where
      ps_partkey in (
        select
          p_partkey
        from
          part
        where
          p_name like 'forest%'
      )
      and ps_availqty > (
        select
          0.5 * sum(l_quantity)
        from
          lineitem
        where
          l_partkey = ps_partkey
          and l_suppkey = ps_suppkey
          and l_shipdate >= date '1994-01-01'
          and l_shipdate < date '1994-01-01' + interval '1' year
      )
  )
  and s_nationkey = n_nationkey
  and n_name = 'CANADA'
order by
  s_name;

                                                                                                                                                                                                                           QUERY PLAN                                                                                                                                                                                                                           
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=15321193.31..15321195.48 rows=1 width=40)
   Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), ((sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END))::numeric / sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
   Group Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
   ->  Cluster Merge Gather  (cost=15321193.31..15321194.86 rows=60 width=40)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
         ->  Gather Merge  (cost=15320192.11..15320193.66 rows=12 width=48)
               Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), (PARTIAL sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END)), (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
               Workers Planned: 12
               ->  Partial GroupAggregate  (cost=15319191.86..15319191.91 rows=1 width=48)
                     Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), PARTIAL sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END), PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Group Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                     ->  Sort  (cost=15319191.86..15319191.87 rows=1 width=46)
                           Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), n2.n_name, lineitem.l_extendedprice, lineitem.l_discount
                           Sort Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                           ->  Parallel Hash Join  (cost=14947609.58..15319191.85 rows=1 width=46)
                                 Output: date_part('year'::text, (orders.o_orderdate)::timestamp without time zone), n2.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                 Inner Unique: true
                                 Hash Cond: (n1.n_regionkey = region.r_regionkey)
                                 ->  Parallel Hash Join  (cost=14947605.54..15319187.81 rows=1 width=46)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, n1.n_regionkey, n2.n_name
                                       Hash Cond: (customer.c_custkey = orders.o_custkey)
                                       ->  Parallel Hash Join  (cost=5.13..371549.88 rows=10000 width=8)
                                             Output: customer.c_custkey, n1.n_regionkey
                                             Inner Unique: true
                                             Hash Cond: (customer.c_nationkey = n1.n_nationkey)
                                             ->  Parallel Seq Scan on public.customer  (cost=0.00..370777.24 rows=250005 width=8)
                                                   Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                   
                                             ->  Parallel Hash  (cost=5.10..5.10 rows=2 width=8)
                                                   Output: n1.n_nationkey, n1.n_regionkey
                                                   ->  Parallel Seq Scan on public.nation n1  (cost=0.00..5.10 rows=2 width=8)
                                                         Output: n1.n_nationkey, n1.n_regionkey
                                                         Remote node: 16387,16388,16389,16390,16391
                                       ->  Parallel Hash  (cost=14947600.40..14947600.40 rows=1 width=46)
                                             Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, orders.o_custkey, n2.n_name
                                             ->  Cluster Reduce  (cost=14517155.96..14947600.40 rows=1 width=46)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                   ->  Parallel Hash Join  (cost=14517154.96..14947596.33 rows=1 width=46)
                                                         Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                         Hash Cond: (part.p_partkey = lineitem.l_partkey)
                                                         ->  Parallel Seq Scan on public.part  (cost=0.00..430433.05 rows=2217 width=4)
                                                               Output: part.p_partkey, part.p_name, part.p_mfgr, part.p_brand, part.p_type, part.p_size, part.p_container, part.p_retailprice, part.p_comment
                                                               Filter: ((part.p_type)::text = 'ECONOMY ANODIZED STEEL'::text)
                                                               
                                                         ->  Parallel Hash  (cost=14517154.16..14517154.16 rows=64 width=50)
                                                               Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                               ->  Cluster Reduce  (cost=2846912.50..14517154.16 rows=64 width=50)
                                                                     Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_partkey)), 0)]
                                                                     ->  Parallel Hash Join  (cost=2846911.50..14517145.36 rows=64 width=50)
                                                                           Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                                           Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                                           ->  Cluster Reduce  (cost=2823654.97..14493882.82 rows=1600 width=28)
                                                                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                                                                 ->  Parallel Hash Join  (cost=2823653.97..14493752.82 rows=1600 width=28)
                                                                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, lineitem.l_suppkey, orders.o_orderdate, orders.o_custkey
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                                       ->  Parallel Seq Scan on public.lineitem  (cost=0.00..11649097.86 rows=8000377 width=24)
                                                                                             Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                                             
                                                                                       ->  Parallel Hash  (cost=2823520.05..2823520.05 rows=10714 width=12)
                                                                                             Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                             ->  Parallel Seq Scan on public.orders  (cost=0.00..2823520.05 rows=10714 width=12)
                                                                                                   Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                                   Filter: (((orders.o_orderdate)::timestamp without time zone >= '1995-01-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone <= '1996-12-31 00:00:00'::timestamp without time zone))
                                                                                                   
                                                                           ->  Parallel Hash  (cost=23246.53..23246.53 rows=800 width=30)
                                                                                 Output: supplier.s_suppkey, n2.n_name
                                                                                 ->  Parallel Hash Join  (cost=5.13..23246.53 rows=800 width=30)
                                                                                       Output: supplier.s_suppkey, n2.n_name
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (supplier.s_nationkey = n2.n_nationkey)
                                                                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..23180.00 rows=20000 width=8)
                                                                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                             
                                                                                       ->  Parallel Hash  (cost=5.10..5.10 rows=2 width=30)
                                                                                             Output: n2.n_name, n2.n_nationkey
                                                                                             ->  Parallel Seq Scan on public.nation n2  (cost=0.00..5.10 rows=2 width=30)
                                                                                                   Output: n2.n_name, n2.n_nationkey
                                                                                                   Remote node: 16387,16388,16389,16390,16391
                                 ->  Parallel Hash  (cost=4.03..4.03 rows=1 width=4)
                                       Output: region.r_regionkey
                                       ->  Parallel Seq Scan on public.region  (cost=0.00..4.03 rows=1 width=4)
                                             Output: region.r_regionkey
                                             Filter: (region.r_name = 'AMERICA'::bpchar)
                                             Remote node: 16387,16388,16389,16390,16391
(87 rows)


-- Q21
select
  s_name,
  count(*) as numwait
from
  supplier,
  lineitem l1,
  orders,
  nation
where
  s_suppkey = l1.l_suppkey
  and o_orderkey = l1.l_orderkey
  and o_orderstatus = 'F'
  and l1.l_receiptdate > l1.l_commitdate
  and exists (
    select
      *
    from
      lineitem l2
    where
      l2.l_orderkey = l1.l_orderkey
      and l2.l_suppkey <> l1.l_suppkey
  )
  and not exists (
    select
      *
    from
      lineitem l3
    where
      l3.l_orderkey = l1.l_orderkey
      and l3.l_suppkey <> l1.l_suppkey
      and l3.l_receiptdate > l3.l_commitdate
  )
  and s_nationkey = n_nationkey
  and n_name = 'SAUDI ARABIA'
group by
  s_name
order by
  numwait desc,
  s_name limit 100;

                                                                                                                                                                  QUERY PLAN                                                                                                                                                                  
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=49858398.06..49858398.06 rows=1 width=34) (actual time=96662.124..96662.141 rows=100 loops=1)
   Output: supplier.s_name, (count(*))
   ->  Sort  (cost=49858398.06..49858398.06 rows=1 width=34) (actual time=96662.122..96662.132 rows=100 loops=1)
         Output: supplier.s_name, (count(*))
         Sort Key: (count(*)) DESC, supplier.s_name
         Sort Method: top-N heapsort  Memory: 37kB
         ->  Finalize GroupAggregate  (cost=49858397.74..49858398.05 rows=1 width=34) (actual time=95220.779..96654.767 rows=39950 loops=1)
               Output: supplier.s_name, count(*)
               Group Key: supplier.s_name
               ->  Cluster Merge Gather  (cost=49858397.74..49858397.99 rows=10 width=34) (actual time=95220.763..96601.118 rows=289535 loops=1)
                     Remote node: 16387,16388,16389,16390,16391
                     Sort Key: supplier.s_name
                     ->  Gather Merge  (cost=49857397.54..49857397.79 rows=2 width=34) (actual time=0.213..0.217 rows=0 loops=1)
                           Output: supplier.s_name, (PARTIAL count(*))
                           Workers Planned: 2
                           Workers Launched: 0
                           
                           
                           
                           
                           
                           ->  Partial GroupAggregate  (cost=49856397.51..49856397.53 rows=1 width=34) (actual time=0.212..0.215 rows=0 loops=1)
                                 Output: supplier.s_name, PARTIAL count(*)
                                 Group Key: supplier.s_name
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 
                                   
                                   
                                 ->  Sort  (cost=49856397.51..49856397.52 rows=1 width=26) (actual time=0.211..0.214 rows=0 loops=1)
                                       Output: supplier.s_name
                                       Sort Key: supplier.s_name
                                       Sort Method: quicksort  Memory: 25kB
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       
                                         
                                         
                                       ->  Parallel Hash Anti Join  (cost=46182470.09..49856397.50 rows=1 width=26) (actual time=0.204..0.207 rows=0 loops=1)
                                             Output: supplier.s_name
                                             Hash Cond: (l1.l_orderkey = l3.l_orderkey)
                                             Join Filter: (l3.l_suppkey <> l1.l_suppkey)
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             
                                               
                                               
                                             ->  Parallel Hash Semi Join  (cost=30284733.67..33893550.46 rows=36 width=34) (actual time=0.090..0.092 rows=0 loops=1)
                                                   Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey
                                                   Hash Cond: (orders.o_orderkey = l2.l_orderkey)
                                                   Join Filter: (l2.l_suppkey <> l1.l_suppkey)
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Parallel Hash Join  (cost=15715185.33..19128630.63 rows=2612 width=38) (never executed)
                                                         Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey, orders.o_orderkey
                                                         Hash Cond: (orders.o_orderkey = l1.l_orderkey)
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Seq Scan on public.orders  (cost=0.00..3390479.92 rows=6121202 width=4) (never executed)
                                                               Output: orders.o_orderkey, orders.o_custkey, orders.o_orderstatus, orders.o_totalprice, orders.o_orderdate, orders.o_orderpriority, orders.o_clerk, orders.o_shippriority, orders.o_comment
                                                               Filter: (orders.o_orderstatus = 'F'::bpchar)
                                                               
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                         ->  Parallel Hash  (cost=15714851.98..15714851.98 rows=26668 width=34) (never executed)
                                                               Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               ->  Parallel Hash Join  (cost=27507.91..15714851.98 rows=26668 width=34) (never executed)
                                                                     Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey
                                                                     Hash Cond: (l1.l_suppkey = supplier.s_suppkey)
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     
                                                                       
                                                                       
                                                                     ->  Parallel Seq Scan on public.lineitem l1  (cost=0.00..15624285.27 rows=16667452 width=8) (never executed)
                                                                           Output: l1.l_orderkey, l1.l_partkey, l1.l_suppkey, l1.l_linenumber, l1.l_quantity, l1.l_extendedprice, l1.l_discount, l1.l_tax, l1.l_returnflag, l1.l_linestatus, l1.l_shipdate, l1.l_commitdate, l1.l_receiptdate, l1.l_shipinstruct, l1.l_shipmode, l1.l_comment
                                                                           Filter: ((l1.l_receiptdate)::timestamp without time zone > (l1.l_commitdate)::timestamp without time zone)
                                                                           
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                     ->  Parallel Hash  (cost=27466.22..27466.22 rows=3335 width=30) (never executed)
                                                                           Output: supplier.s_name, supplier.s_suppkey
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           
                                                                             
                                                                             
                                                                           ->  Cluster Reduce  (cost=6.33..27466.22 rows=3335 width=30) (never executed)
                                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 
                                                                                   
                                                                                   
                                                                                 ->  Hash Join  (cost=5.33..26607.82 rows=667 width=30) (never executed)
                                                                                       Output: supplier.s_name, supplier.s_suppkey
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       
                                                                                         
                                                                                         
                                                                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=34) (never executed)
                                                                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                             
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                       ->  Hash  (cost=5.31..5.31 rows=1 width=4) (never executed)
                                                                                             Output: nation.n_nationkey
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             
                                                                                               
                                                                                               
                                                                                             ->  Seq Scan on public.nation  (cost=0.00..5.31 rows=1 width=4) (never executed)
                                                                                                   Output: nation.n_nationkey
                                                                                                   Filter: (nation.n_name = 'SAUDI ARABIA'::bpchar)
                                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                                                                   
                                                                                                     
                                                                                                     
                                                   ->  Parallel Hash  (cost=13749196.87..13749196.87 rows=50002358 width=8) (actual time=0.001..0.002 rows=0 loops=1)
                                                         Output: l2.l_orderkey, l2.l_suppkey
                                                         Buckets: 131072  Batches: 2048  Memory Usage: 1024kB
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         ->  Parallel Seq Scan on public.lineitem l2  (cost=0.00..13749196.87 rows=50002358 width=8) (actual time=0.001..0.001 rows=0 loops=1)
                                                               Output: l2.l_orderkey, l2.l_suppkey
                                                               
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                                               
                                                                 
                                                                 
                                             ->  Parallel Hash  (cost=15624285.27..15624285.27 rows=16667452 width=8) (actual time=0.010..0.010 rows=0 loops=1)
                                                   Output: l3.l_orderkey, l3.l_suppkey
                                                   Buckets: 131072  Batches: 1024  Memory Usage: 1024kB
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   
                                                     
                                                     
                                                   ->  Parallel Seq Scan on public.lineitem l3  (cost=0.00..15624285.27 rows=16667452 width=8) (actual time=0.007..0.007 rows=0 loops=1)
                                                         Output: l3.l_orderkey, l3.l_suppkey
                                                         Filter: ((l3.l_receiptdate)::timestamp without time zone > (l3.l_commitdate)::timestamp without time zone)
                                                         
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
                                                         
                                                           
                                                           
 Planning Time: 11.878 ms
 Execution Time: 96664.368 ms
(369 rows)

-- Q22
set grammar to postgres;
select
  cntrycode,
  count(*) as numcust,
  sum(c_acctbal) as totacctbal
from
  (
    select
      substring(c_phone from 1 for 2) as cntrycode,
      c_acctbal
    from
      customer
    where
      substring(c_phone from 1 for 2) in
        ('13', '31', '23', '29', '30', '18', '17')
      and c_acctbal > (
        select
          avg(c_acctbal)
        from
          customer
        where
          c_acctbal > 0.00
          and substring(c_phone from 1 for 2) in
            ('13', '31', '23', '29', '30', '18', '17')
      )
      and not exists (
        select
          *
        from
          orders
        where
          o_custkey = c_custkey
      )
  ) as custsale
group by
  cntrycode
order by
  cntrycode;

                                                                                                              QUERY PLAN                                                                                                              
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Cluster Merge Gather  (cost=10019090686.60..10019090793.37 rows=19122 width=0) (actual time=14922.786..14922.793 rows=7 loops=1)
   Remote node: 16387,16388,16389,16390,16391
   Sort Key: ("substring"((customer.c_phone)::text, 1, 2))
   ->  Finalize GroupAggregate  (cost=4986773.94..4986880.72 rows=3824 width=72) (actual time=0.000..0.003 rows=0 loops=1)
         Output: ("substring"((customer.c_phone)::text, 1, 2)), count(*), sum(customer.c_acctbal)
         Group Key: ("substring"((customer.c_phone)::text, 1, 2))
         InitPlan 1 (returns $0)
           ->  Cluster Reduce  (cost=523450.26..523453.57 rows=1 width=32) (never executed)
                 Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                 ->  Finalize Aggregate  (cost=523449.26..523449.27 rows=1 width=32) (actual time=825.015..825.016 rows=1 loops=1)
                       Output: avg(customer_1.c_acctbal)
                       ->  Cluster Reduce  (cost=523443.00..523449.21 rows=10 width=32) (actual time=0.033..824.992 rows=16 loops=1)
                             Reduce: '12338'::oid
                             ->  Gather  (cost=523442.00..523442.21 rows=2 width=32) (actual time=0.028..0.030 rows=1 loops=1)
                                   Output: (PARTIAL avg(customer_1.c_acctbal))
                                   Workers Planned: 2
                                   Workers Launched: 0
                                   ->  Partial Aggregate  (cost=522442.00..522442.01 rows=1 width=32) (actual time=0.027..0.028 rows=1 loops=1)
                                         Output: PARTIAL avg(customer_1.c_acctbal)
                                         ->  Parallel Seq Scan on public.customer customer_1  (cost=0.00..522342.66 rows=39734 width=6) (actual time=0.022..0.023 rows=0 loops=1)
                                               Output: customer_1.c_custkey, customer_1.c_name, customer_1.c_address, customer_1.c_nationkey, customer_1.c_phone, customer_1.c_acctbal, customer_1.c_mktsegment, customer_1.c_comment
                                               Filter: ((customer_1.c_acctbal > 0.00) AND ("substring"((customer_1.c_phone)::text, 1, 2) = ANY ('{13,31,23,29,30,18,17}'::text[])))
         ->  Sort  (cost=4986773.94..4986781.91 rows=3188 width=72) (never executed)
               Output: ("substring"((customer.c_phone)::text, 1, 2)), (PARTIAL count(*)), (PARTIAL sum(customer.c_acctbal))
               Sort Key: ("substring"((customer.c_phone)::text, 1, 2))
               ->  Cluster Reduce  (cost=4985972.63..4986588.43 rows=3188 width=72) (never executed)
                     Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashtext(("substring"((customer.c_phone)::text, 1, 2)))), 0)]
                     ->  Gather  (cost=4985971.63..4986318.33 rows=3188 width=72) (never executed)
                           Output: ("substring"((customer.c_phone)::text, 1, 2)), (PARTIAL count(*)), (PARTIAL sum(customer.c_acctbal))
                           Workers Planned: 2
                           Params Evaluated: $0
                           Workers Launched: 0
                           ->  Partial HashAggregate  (cost=4984971.63..4984999.53 rows=1594 width=72) (never executed)
                                 Output: ("substring"((customer.c_phone)::text, 1, 2)), PARTIAL count(*), PARTIAL sum(customer.c_acctbal)
                                 Group Key: "substring"((customer.c_phone)::text, 1, 2)
                                 ->  Parallel Hash Anti Join  (cost=4413422.56..4984959.68 rows=1594 width=38) (never executed)
                                       Output: "substring"((customer.c_phone)::text, 1, 2), customer.c_acctbal
                                       Hash Cond: (customer.c_custkey = orders.o_custkey)
                                       ->  Parallel Seq Scan on public.customer  (cost=0.00..522342.66 rows=14584 width=26) (never executed)
                                             Output: customer.c_phone, customer.c_acctbal, customer.c_custkey
                                             Filter: ((customer.c_acctbal > $0) AND ("substring"((customer.c_phone)::text, 1, 2) = ANY ('{13,31,23,29,30,18,17}'::text[])))
                                       ->  Parallel Hash  (cost=4208345.78..4208345.78 rows=12499902 width=4) (never executed)
                                             Output: orders.o_custkey
                                             ->  Cluster Reduce  (cost=1.00..4208345.78 rows=12499902 width=4) (never executed)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                   ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=4) (never executed)
                                                         Output: orders.o_custkey
                                                         

 Planning Time: 1.089 ms
 Execution Time: 15751.630 ms
(212 rows)
  
-- end
select now();



Node [0-9]*: [\(]actual time=[0-9.]* rows=[0-9]* loops=[0-9*][\)]
Worker [0-9]*: actual time=[0-9.]* rows=[0-9]* loops=[0-9*]