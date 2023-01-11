
                            List of relations
 Schema |   Name   | Type  | Owner | Persistence |  Size   | Description 
--------+----------+-------+-------+-------------+---------+-------------
 public | customer | table | maoxp | permanent   | 2800 MB | 
 public | lineitem | table | maoxp | permanent   | 86 GB   | 
 public | nation   | table | maoxp | permanent   | 40 kB   | 
 public | orders   | table | maoxp | permanent   | 20 GB   | 
 public | part     | table | maoxp | permanent   | 3201 MB | 
 public | partsupp | table | maoxp | permanent   | 13 GB   | 
 public | region   | table | maoxp | permanent   | 40 kB   | 
 public | supplier | table | maoxp | permanent   | 173 MB  | 
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

1. 大部分语句使用并发，但是并发度低，加大并发，加大hash相关的设置，后面需要仔细调研hash算子和并发机制，提升更大的设置
2. Q2，Q17没有使用并发
3. Reduce Scan 没有进行谓词下推，导致下层节点会全表扫描，且数据会全量传输

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
  l_shipdate <= date '1998-12-01' - interval '90' day (3)
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
               Node 16387: (actual time=19265.884..19268.031 rows=40 loops=1)
               Node 16388: (actual time=19301.816..19304.658 rows=40 loops=1)
               Node 16389: (actual time=19260.884..19264.119 rows=40 loops=1)
               Node 16390: (actual time=19401.250..19404.175 rows=40 loops=1)
               Node 16391: (actual time=19389.029..19392.029 rows=40 loops=1)
               ->  Sort  (cost=12426912.55..12426912.56 rows=6 width=236) (actual time=0.016..0.017 rows=0 loops=1)
                     Output: l_returnflag, l_linestatus, (PARTIAL sum(l_quantity)), (PARTIAL sum(l_extendedprice)), (PARTIAL sum((l_extendedprice * ('1'::numeric - l_discount)))), (PARTIAL sum(((l_extendedprice * ('1'::numeric - l_discount)) * ('1'::numeric + l_tax)))), (PARTIAL avg(l_quantity)), (PARTIAL avg(l_extendedprice)), (PARTIAL avg(l_discount)), (PARTIAL count(*))
                     Sort Key: lineitem.l_returnflag, lineitem.l_linestatus
                     Sort Method: quicksort  Memory: 25kB
                     Node 16387: (actual time=19261.286..19261.287 rows=4 loops=10)
                       Worker 0: actual time=19260.125..19260.126 rows=4 loops=1
                       Worker 1: actual time=19260.197..19260.199 rows=4 loops=1
                       Worker 2: actual time=19260.255..19260.255 rows=4 loops=1
                       Worker 3: actual time=19260.645..19260.646 rows=4 loops=1
                       Worker 4: actual time=19260.870..19260.872 rows=4 loops=1
                       Worker 5: actual time=19260.707..19260.708 rows=4 loops=1
                       Worker 6: actual time=19261.522..19261.524 rows=4 loops=1
                       Worker 7: actual time=19261.550..19261.552 rows=4 loops=1
                       Worker 8: actual time=19261.503..19261.504 rows=4 loops=1
                     Node 16388: (actual time=19297.451..19297.452 rows=4 loops=10)
                       Worker 0: actual time=19295.956..19295.957 rows=4 loops=1
                       Worker 1: actual time=19296.454..19296.455 rows=4 loops=1
                       Worker 2: actual time=19296.412..19296.413 rows=4 loops=1
                       Worker 3: actual time=19296.488..19296.489 rows=4 loops=1
                       Worker 4: actual time=19296.959..19296.960 rows=4 loops=1
                       Worker 5: actual time=19297.512..19297.513 rows=4 loops=1
                       Worker 6: actual time=19297.770..19297.771 rows=4 loops=1
                       Worker 7: actual time=19297.711..19297.712 rows=4 loops=1
                       Worker 8: actual time=19297.747..19297.748 rows=4 loops=1
                     Node 16389: (actual time=19255.993..19255.994 rows=4 loops=10)
                       Worker 0: actual time=19253.847..19253.848 rows=4 loops=1
                       Worker 1: actual time=19254.693..19254.694 rows=4 loops=1
                       Worker 2: actual time=19255.459..19255.460 rows=4 loops=1
                       Worker 3: actual time=19254.650..19254.651 rows=4 loops=1
                       Worker 4: actual time=19255.867..19255.868 rows=4 loops=1
                       Worker 5: actual time=19255.841..19255.842 rows=4 loops=1
                       Worker 6: actual time=19256.545..19256.547 rows=4 loops=1
                       Worker 7: actual time=19255.977..19255.979 rows=4 loops=1
                       Worker 8: actual time=19256.555..19256.556 rows=4 loops=1
                     Node 16390: (actual time=19396.347..19396.348 rows=4 loops=10)
                       Worker 0: actual time=19394.204..19394.205 rows=4 loops=1
                       Worker 1: actual time=19394.927..19394.928 rows=4 loops=1
                       Worker 2: actual time=19395.594..19395.594 rows=4 loops=1
                       Worker 3: actual time=19395.692..19395.693 rows=4 loops=1
                       Worker 4: actual time=19395.875..19395.876 rows=4 loops=1
                       Worker 5: actual time=19396.627..19396.628 rows=4 loops=1
                       Worker 6: actual time=19396.610..19396.610 rows=4 loops=1
                       Worker 7: actual time=19396.279..19396.280 rows=4 loops=1
                       Worker 8: actual time=19396.844..19396.845 rows=4 loops=1
                     Node 16391: (actual time=19384.471..19384.472 rows=4 loops=10)
                       Worker 0: actual time=19382.693..19382.694 rows=4 loops=1
                       Worker 1: actual time=19383.428..19383.430 rows=4 loops=1
                       Worker 2: actual time=19383.608..19383.609 rows=4 loops=1
                       Worker 3: actual time=19383.951..19383.952 rows=4 loops=1
                       Worker 4: actual time=19384.316..19384.317 rows=4 loops=1
                       Worker 5: actual time=19384.407..19384.408 rows=4 loops=1
                       Worker 6: actual time=19384.559..19384.559 rows=4 loops=1
                       Worker 7: actual time=19384.510..19384.511 rows=4 loops=1
                       Worker 8: actual time=19384.697..19384.698 rows=4 loops=1
                     ->  Partial HashAggregate  (cost=12426912.31..12426912.47 rows=6 width=236) (actual time=0.010..0.010 rows=0 loops=1)
                           Output: l_returnflag, l_linestatus, PARTIAL sum(l_quantity), PARTIAL sum(l_extendedprice), PARTIAL sum((l_extendedprice * ('1'::numeric - l_discount))), PARTIAL sum(((l_extendedprice * ('1'::numeric - l_discount)) * ('1'::numeric + l_tax))), PARTIAL avg(l_quantity), PARTIAL avg(l_extendedprice), PARTIAL avg(l_discount), PARTIAL count(*)
                           Group Key: lineitem.l_returnflag, lineitem.l_linestatus
                           Batches: 1  Memory Usage: 24kB
                           Node 16387: (actual time=19261.239..19261.252 rows=4 loops=10)
                             Worker 0: actual time=19260.089..19260.099 rows=4 loops=1
                             Worker 1: actual time=19260.155..19260.167 rows=4 loops=1
                             Worker 2: actual time=19260.220..19260.229 rows=4 loops=1
                             Worker 3: actual time=19260.604..19260.615 rows=4 loops=1
                             Worker 4: actual time=19260.825..19260.839 rows=4 loops=1
                             Worker 5: actual time=19260.663..19260.672 rows=4 loops=1
                             Worker 6: actual time=19261.471..19261.481 rows=4 loops=1
                             Worker 7: actual time=19261.503..19261.513 rows=4 loops=1
                             Worker 8: actual time=19261.457..19261.468 rows=4 loops=1
                           Node 16388: (actual time=19297.410..19297.420 rows=4 loops=10)
                             Worker 0: actual time=19295.914..19295.927 rows=4 loops=1
                             Worker 1: actual time=19296.413..19296.422 rows=4 loops=1
                             Worker 2: actual time=19296.367..19296.377 rows=4 loops=1
                             Worker 3: actual time=19296.442..19296.451 rows=4 loops=1
                             Worker 4: actual time=19296.923..19296.932 rows=4 loops=1
                             Worker 5: actual time=19297.473..19297.482 rows=4 loops=1
                             Worker 6: actual time=19297.723..19297.733 rows=4 loops=1
                             Worker 7: actual time=19297.661..19297.670 rows=4 loops=1
                             Worker 8: actual time=19297.702..19297.711 rows=4 loops=1
                           Node 16389: (actual time=19255.951..19255.961 rows=4 loops=10)
                             Worker 0: actual time=19253.802..19253.814 rows=4 loops=1
                             Worker 1: actual time=19254.651..19254.660 rows=4 loops=1
                             Worker 2: actual time=19255.423..19255.432 rows=4 loops=1
                             Worker 3: actual time=19254.607..19254.617 rows=4 loops=1
                             Worker 4: actual time=19255.824..19255.834 rows=4 loops=1
                             Worker 5: actual time=19255.799..19255.809 rows=4 loops=1
                             Worker 6: actual time=19256.490..19256.501 rows=4 loops=1
                             Worker 7: actual time=19255.928..19255.938 rows=4 loops=1
                             Worker 8: actual time=19256.511..19256.521 rows=4 loops=1
                           Node 16390: (actual time=19396.308..19396.318 rows=4 loops=10)
                             Worker 0: actual time=19394.165..19394.174 rows=4 loops=1
                             Worker 1: actual time=19394.887..19394.896 rows=4 loops=1
                             Worker 2: actual time=19395.555..19395.565 rows=4 loops=1
                             Worker 3: actual time=19395.648..19395.659 rows=4 loops=1
                             Worker 4: actual time=19395.839..19395.849 rows=4 loops=1
                             Worker 5: actual time=19396.585..19396.595 rows=4 loops=1
                             Worker 6: actual time=19396.565..19396.574 rows=4 loops=1
                             Worker 7: actual time=19396.236..19396.246 rows=4 loops=1
                             Worker 8: actual time=19396.798..19396.808 rows=4 loops=1
                           Node 16391: (actual time=19384.428..19384.440 rows=4 loops=10)
                             Worker 0: actual time=19382.647..19382.657 rows=4 loops=1
                             Worker 1: actual time=19383.379..19383.389 rows=4 loops=1
                             Worker 2: actual time=19383.567..19383.580 rows=4 loops=1
                             Worker 3: actual time=19383.908..19383.918 rows=4 loops=1
                             Worker 4: actual time=19384.266..19384.282 rows=4 loops=1
                             Worker 5: actual time=19384.366..19384.376 rows=4 loops=1
                             Worker 6: actual time=19384.519..19384.529 rows=4 loops=1
                             Worker 7: actual time=19384.466..19384.475 rows=4 loops=1
                             Worker 8: actual time=19384.650..19384.665 rows=4 loops=1
                           ->  Parallel Seq Scan on public.lineitem  (cost=0.00..12249126.15 rows=4444654 width=25) (actual time=0.007..0.007 rows=0 loops=1)
                                 Output: l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct, l_shipmode, l_comment
                                 Filter: ((lineitem.l_shipdate)::timestamp without time zone <= '1998-09-02 00:00:00'::timestamp without time zone)
                                 Remote node: 16389,16387,16390,16388,16391
                                 Node 16387: (actual time=0.033..4095.069 rows=11831168 loops=10)
                                   Worker 0: actual time=0.024..4088.353 rows=11794828 loops=1
                                   Worker 1: actual time=0.029..3981.048 rows=11926712 loops=1
                                   Worker 2: actual time=0.028..3968.305 rows=11933599 loops=1
                                   Worker 3: actual time=0.025..4227.594 rows=11729510 loops=1
                                   Worker 4: actual time=0.036..4074.888 rows=11855745 loops=1
                                   Worker 5: actual time=0.036..3983.004 rows=11889486 loops=1
                                   Worker 6: actual time=0.039..4215.129 rows=11746501 loops=1
                                   Worker 7: actual time=0.035..3991.488 rows=11927802 loops=1
                                   Worker 8: actual time=0.038..4132.631 rows=11809057 loops=1
                                 Node 16388: (actual time=0.029..4153.843 rows=11832700 loops=10)
                                   Worker 0: actual time=0.031..4171.583 rows=11785139 loops=1
                                   Worker 1: actual time=0.021..4074.922 rows=11896571 loops=1
                                   Worker 2: actual time=0.021..4138.133 rows=11850430 loops=1
                                   Worker 3: actual time=0.029..4211.945 rows=11803002 loops=1
                                   Worker 4: actual time=0.023..4140.966 rows=11851647 loops=1
                                   Worker 5: actual time=0.026..4183.727 rows=11762856 loops=1
                                   Worker 6: actual time=0.036..4122.313 rows=11850472 loops=1
                                   Worker 7: actual time=0.036..4142.956 rows=11844223 loops=1
                                   Worker 8: actual time=0.034..4203.058 rows=11800516 loops=1
                                 Node 16389: (actual time=0.032..4153.518 rows=11831235 loops=10)
                                   Worker 0: actual time=0.033..4218.119 rows=11751301 loops=1
                                   Worker 1: actual time=0.024..4259.956 rows=11758055 loops=1
                                   Worker 2: actual time=0.025..4100.490 rows=11900477 loops=1
                                   Worker 3: actual time=0.022..4186.118 rows=11821879 loops=1
                                   Worker 4: actual time=0.041..4275.508 rows=11751595 loops=1
                                   Worker 5: actual time=0.042..4120.077 rows=11814360 loops=1
                                   Worker 6: actual time=0.032..4238.241 rows=11783265 loops=1
                                   Worker 7: actual time=0.025..4128.681 rows=11858411 loops=1
                                   Worker 8: actual time=0.036..4110.802 rows=11876359 loops=1
                                 Node 16390: (actual time=0.026..4238.774 rows=11832522 loops=10)
                                   Worker 0: actual time=0.035..4199.230 rows=11825892 loops=1
                                   Worker 1: actual time=0.026..4321.762 rows=11765854 loops=1
                                   Worker 2: actual time=0.005..4306.397 rows=11788943 loops=1
                                   Worker 3: actual time=0.006..4225.549 rows=11855808 loops=1
                                   Worker 4: actual time=0.007..4258.070 rows=11824411 loops=1
                                   Worker 5: actual time=0.028..4093.070 rows=11911419 loops=1
                                   Worker 6: actual time=0.037..4292.798 rows=11799018 loops=1
                                   Worker 7: actual time=0.039..4373.878 rows=11731047 loops=1
                                   Worker 8: actual time=0.036..4133.303 rows=11914333 loops=1
                                 Node 16391: (actual time=0.029..4206.251 rows=11832310 loops=10)
                                   Worker 0: actual time=0.025..4186.226 rows=11809205 loops=1
                                   Worker 1: actual time=0.022..4373.394 rows=11706209 loops=1
                                   Worker 2: actual time=0.028..4332.164 rows=11739234 loops=1
                                   Worker 3: actual time=0.006..4364.799 rows=11712535 loops=1
                                   Worker 4: actual time=0.026..4171.774 rows=11870551 loops=1
                                   Worker 5: actual time=0.025..4296.756 rows=11727697 loops=1
                                   Worker 6: actual time=0.043..4131.706 rows=11889797 loops=1
                                   Worker 7: actual time=0.044..4020.025 rows=11981914 loops=1
                                   Worker 8: actual time=0.030..4284.208 rows=11774713 loops=1
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
               Node 16387: (actual time=1772063.313..1772063.335 rows=100 loops=1)
               Node 16389: (actual time=1772250.135..1772250.157 rows=100 loops=1)
               Node 16390: (actual time=1773945.812..1773945.835 rows=100 loops=1)
               Node 16391: (actual time=1745415.807..1745415.834 rows=100 loops=1)
               Node 16388: (actual time=1775183.282..1775183.305 rows=100 loops=1)
               ->  Sort  (cost=3350657.95..3350657.95 rows=0 width=192) (actual time=0.042..0.046 rows=0 loops=1)
                     Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                     Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
                     Sort Method: quicksort  Memory: 25kB
                     Node 16387: (actual time=1772063.310..1772063.325 rows=100 loops=1)
                     Node 16389: (actual time=1772250.133..1772250.148 rows=100 loops=1)
                     Node 16390: (actual time=1773945.810..1773945.826 rows=100 loops=1)
                     Node 16391: (actual time=1745415.805..1745415.821 rows=100 loops=1)
                     Node 16388: (actual time=1775183.279..1775183.294 rows=100 loops=1)
                     ->  Hash Join  (cost=745137.06..3350657.94 rows=0 width=192) (actual time=0.028..0.033 rows=0 loops=1)
                           Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                           Inner Unique: true
                           Hash Cond: ((partsupp.ps_partkey = part.p_partkey) AND (partsupp.ps_supplycost = (SubPlan 1)))
                           Node 16387: (actual time=1110131.517..1772047.609 rows=9470 loops=1)
                           Node 16389: (actual time=1112923.104..1772232.293 rows=9458 loops=1)
                           Node 16390: (actual time=1109979.548..1773927.901 rows=9502 loops=1)
                           Node 16391: (actual time=1110835.367..1745398.589 rows=9109 loops=1)
                           Node 16388: (actual time=1110921.287..1775168.659 rows=9568 loops=1)
                           ->  Hash Join  (cost=35313.19..2640699.64 rows=25604 width=172) (never executed)
                                 Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, partsupp.ps_partkey, partsupp.ps_supplycost, nation.n_name
                                 Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                 Node 16387: (actual time=20573.025..32966.004 rows=3208034 loops=1)
                                 Node 16389: (actual time=22980.367..35854.371 rows=3209194 loops=1)
                                 Node 16390: (actual time=6954.031..19535.323 rows=3206648 loops=1)
                                 Node 16391: (actual time=50302.949..63560.849 rows=3208964 loops=1)
                                 Node 16388: (actual time=283.111..12716.873 rows=3209960 loops=1)
                                 ->  Seq Scan on public.partsupp  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                       Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16387: (actual time=0.022..2321.959 rows=15996576 loops=1)
                                       Node 16389: (actual time=0.011..2684.095 rows=16007608 loops=1)
                                       Node 16390: (actual time=0.009..2591.602 rows=15990792 loops=1)
                                       Node 16391: (actual time=0.012..2482.790 rows=16002272 loops=1)
                                       Node 16388: (actual time=0.012..2410.073 rows=16002752 loops=1)
                                 ->  Hash  (cost=35213.19..35213.19 rows=8000 width=166) (never executed)
                                       Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                       Node 16387: (actual time=20572.554..20572.557 rows=200535 loops=1)
                                       Node 16389: (actual time=22980.335..22980.338 rows=200535 loops=1)
                                       Node 16390: (actual time=6953.691..6953.693 rows=200535 loops=1)
                                       Node 16391: (actual time=50302.601..50302.604 rows=200535 loops=1)
                                       Node 16388: (actual time=282.865..282.868 rows=200535 loops=1)
                                       ->  Cluster Reduce  (cost=10.39..35213.19 rows=8000 width=166) (never executed)
                                             Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                             Node 16387: (actual time=0.218..20517.812 rows=200535 loops=1)
                                             Node 16389: (actual time=0.222..22923.730 rows=200535 loops=1)
                                             Node 16390: (actual time=0.352..6898.595 rows=200535 loops=1)
                                             Node 16391: (actual time=0.283..50239.798 rows=200535 loops=1)
                                             Node 16388: (actual time=0.273..230.389 rows=200535 loops=1)
                                             ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=166) (never executed)
                                                   Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                                   Inner Unique: true
                                                   Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                   Node 16387: (actual time=0.056..119.575 rows=40056 loops=1)
                                                   Node 16389: (actual time=0.068..127.699 rows=39991 loops=1)
                                                   Node 16390: (actual time=0.080..125.878 rows=40202 loops=1)
                                                   Node 16391: (actual time=0.057..122.222 rows=40239 loops=1)
                                                   Node 16388: (actual time=0.061..123.351 rows=40047 loops=1)
                                                   ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=170) (never executed)
                                                         Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name, nation.n_regionkey
                                                         Inner Unique: true
                                                         Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                         Node 16387: (actual time=0.025..97.179 rows=199723 loops=1)
                                                         Node 16389: (actual time=0.048..105.502 rows=199970 loops=1)
                                                         Node 16390: (actual time=0.032..103.140 rows=200370 loops=1)
                                                         Node 16391: (actual time=0.028..99.691 rows=199703 loops=1)
                                                         Node 16388: (actual time=0.033..100.750 rows=200234 loops=1)
                                                         ->  Seq Scan on public.supplier  (cost=0.00..32180.00 rows=200000 width=144) (never executed)
                                                               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16387: (actual time=0.004..30.007 rows=199723 loops=1)
                                                               Node 16389: (actual time=0.027..37.360 rows=199970 loops=1)
                                                               Node 16390: (actual time=0.009..37.024 rows=200370 loops=1)
                                                               Node 16391: (actual time=0.004..32.427 rows=199703 loops=1)
                                                               Node 16388: (actual time=0.005..33.345 rows=200234 loops=1)
                                                         ->  Hash  (cost=5.25..5.25 rows=5 width=34) (never executed)
                                                               Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                               Node 16387: (actual time=0.016..0.017 rows=25 loops=1)
                                                               Node 16389: (actual time=0.016..0.016 rows=25 loops=1)
                                                               Node 16390: (actual time=0.016..0.017 rows=25 loops=1)
                                                               Node 16391: (actual time=0.017..0.018 rows=25 loops=1)
                                                               Node 16388: (actual time=0.022..0.023 rows=25 loops=1)
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=34) (never executed)
                                                                     Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     Node 16387: (actual time=0.007..0.010 rows=25 loops=1)
                                                                     Node 16389: (actual time=0.006..0.009 rows=25 loops=1)
                                                                     Node 16390: (actual time=0.006..0.009 rows=25 loops=1)
                                                                     Node 16391: (actual time=0.007..0.010 rows=25 loops=1)
                                                                     Node 16388: (actual time=0.008..0.016 rows=25 loops=1)
                                                   ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                         Output: region.r_regionkey
                                                         Node 16387: (actual time=0.017..0.018 rows=1 loops=1)
                                                         Node 16389: (actual time=0.015..0.015 rows=1 loops=1)
                                                         Node 16390: (actual time=0.029..0.030 rows=1 loops=1)
                                                         Node 16391: (actual time=0.022..0.023 rows=1 loops=1)
                                                         Node 16388: (actual time=0.019..0.019 rows=1 loops=1)
                                                         ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                               Output: region.r_regionkey
                                                               Filter: (region.r_name = 'EUROPE'::bpchar)
                                                               Remote node: 16387,16388,16389,16390,16391
                                                               Node 16387: (actual time=0.014..0.015 rows=1 loops=1)
                                                               Node 16389: (actual time=0.010..0.011 rows=1 loops=1)
                                                               Node 16390: (actual time=0.021..0.023 rows=1 loops=1)
                                                               Node 16391: (actual time=0.018..0.019 rows=1 loops=1)
                                                               Node 16388: (actual time=0.015..0.016 rows=1 loops=1)
                           ->  Hash  (cost=709595.86..709595.86 rows=15201 width=30) (actual time=0.015..0.017 rows=0 loops=1)
                                 Output: part.p_partkey, part.p_mfgr
                                 Buckets: 16384  Batches: 1  Memory Usage: 128kB
                                 Node 16387: (actual time=1089478.433..1089478.436 rows=9470 loops=1)
                                 Node 16389: (actual time=1089864.879..1089864.883 rows=9458 loops=1)
                                 Node 16390: (actual time=1102918.327..1102918.331 rows=9502 loops=1)
                                 Node 16391: (actual time=1060438.912..1060438.916 rows=9109 loops=1)
                                 Node 16388: (actual time=1110550.816..1110550.820 rows=9568 loops=1)
                                 ->  Seq Scan on public.part  (cost=0.00..709595.86 rows=15201 width=30) (actual time=0.014..0.014 rows=0 loops=1)
                                       Output: part.p_partkey, part.p_mfgr
                                       Filter: (((part.p_type)::text ~~ '%BRASS'::text) AND (part.p_size = 15))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16387: (actual time=0.030..1400.121 rows=15945 loops=1)
                                       Node 16389: (actual time=0.022..1388.619 rows=15908 loops=1)
                                       Node 16390: (actual time=0.211..1521.970 rows=16057 loops=1)
                                       Node 16391: (actual time=0.032..1488.675 rows=15563 loops=1)
                                       Node 16388: (actual time=0.051..1486.255 rows=16118 loops=1)
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
                                                                 Node 16387: (actual time=0.010..6611.079 rows=80000000 loops=1)
                                                                 Node 16389: (actual time=0.010..6498.273 rows=80000000 loops=1)
                                                                 Node 16390: (actual time=0.009..6881.127 rows=80000000 loops=1)
                                                                 Node 16391: (actual time=0.014..6772.778 rows=80000000 loops=1)
                                                                 Node 16388: (actual time=0.015..6761.055 rows=80000000 loops=1)
                                                                 ->  Seq Scan on public.partsupp partsupp_1  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                                                       Output: partsupp_1.ps_supplycost, partsupp_1.ps_suppkey, partsupp_1.ps_partkey
                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                       Node 16387: (actual time=0.009..3738.103 rows=15996576 loops=1)
                                                                       Node 16389: (actual time=0.014..3933.574 rows=16007608 loops=1)
                                                                       Node 16390: (actual time=0.014..3781.220 rows=15990792 loops=1)
                                                                       Node 16391: (actual time=0.010..4148.903 rows=16002272 loops=1)
                                                                       Node 16388: (actual time=0.015..3550.565 rows=16002752 loops=1)
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
                                                                       Node 16387: (actual time=0.077..105.770 rows=40056 loops=1)
                                                                       Node 16389: (actual time=0.081..112.910 rows=39991 loops=1)
                                                                       Node 16390: (actual time=0.061..112.656 rows=40202 loops=1)
                                                                       Node 16391: (actual time=0.115..107.845 rows=40239 loops=1)
                                                                       Node 16388: (actual time=0.086..106.689 rows=40047 loops=1)
                                                                       ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=8) (never executed)
                                                                             Output: supplier_1.s_suppkey, nation_1.n_regionkey
                                                                             Inner Unique: true
                                                                             Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                             Node 16387: (actual time=0.024..84.335 rows=199723 loops=1)
                                                                             Node 16389: (actual time=0.041..91.498 rows=199970 loops=1)
                                                                             Node 16390: (actual time=0.025..91.283 rows=200370 loops=1)
                                                                             Node 16391: (actual time=0.024..86.455 rows=199703 loops=1)
                                                                             Node 16388: (actual time=0.028..85.151 rows=200234 loops=1)
                                                                             ->  Seq Scan on public.supplier supplier_1  (cost=0.00..32180.00 rows=200000 width=8) (never executed)
                                                                                   Output: supplier_1.s_suppkey, supplier_1.s_name, supplier_1.s_address, supplier_1.s_nationkey, supplier_1.s_phone, supplier_1.s_acctbal, supplier_1.s_comment
                                                                                   Remote node: 16389,16387,16390,16388,16391
                                                                                   Node 16387: (actual time=0.005..28.806 rows=199723 loops=1)
                                                                                   Node 16389: (actual time=0.022..34.995 rows=199970 loops=1)
                                                                                   Node 16390: (actual time=0.004..35.444 rows=200370 loops=1)
                                                                                   Node 16391: (actual time=0.005..33.054 rows=199703 loops=1)
                                                                                   Node 16388: (actual time=0.005..30.048 rows=200234 loops=1)
                                                                             ->  Hash  (cost=5.25..5.25 rows=5 width=8) (never executed)
                                                                                   Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                   Node 16387: (actual time=0.014..0.014 rows=25 loops=1)
                                                                                   Node 16389: (actual time=0.014..0.014 rows=25 loops=1)
                                                                                   Node 16390: (actual time=0.014..0.015 rows=25 loops=1)
                                                                                   Node 16391: (actual time=0.014..0.014 rows=25 loops=1)
                                                                                   Node 16388: (actual time=0.016..0.017 rows=25 loops=1)
                                                                                   ->  Seq Scan on public.nation nation_1  (cost=0.00..5.25 rows=5 width=8) (never executed)
                                                                                         Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                         Remote node: 16387,16388,16389,16390,16391
                                                                                         Node 16387: (actual time=0.005..0.008 rows=25 loops=1)
                                                                                         Node 16389: (actual time=0.005..0.008 rows=25 loops=1)
                                                                                         Node 16390: (actual time=0.006..0.009 rows=25 loops=1)
                                                                                         Node 16391: (actual time=0.006..0.009 rows=25 loops=1)
                                                                                         Node 16388: (actual time=0.008..0.011 rows=25 loops=1)
                                                                       ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                                             Output: region_1.r_regionkey
                                                                             Node 16387: (actual time=0.036..0.036 rows=1 loops=1)
                                                                             Node 16389: (actual time=0.024..0.024 rows=1 loops=1)
                                                                             Node 16390: (actual time=0.024..0.025 rows=1 loops=1)
                                                                             Node 16391: (actual time=0.035..0.036 rows=1 loops=1)
                                                                             Node 16388: (actual time=0.037..0.038 rows=1 loops=1)
                                                                             ->  Seq Scan on public.region region_1  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                                                   Output: region_1.r_regionkey
                                                                                   Filter: (region_1.r_name = 'EUROPE'::bpchar)
                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                   Node 16387: (actual time=0.025..0.026 rows=1 loops=1)
                                                                                   Node 16389: (actual time=0.017..0.018 rows=1 loops=1)
                                                                                   Node 16390: (actual time=0.017..0.019 rows=1 loops=1)
                                                                                   Node 16391: (actual time=0.024..0.026 rows=1 loops=1)
                                                                                   Node 16388: (actual time=0.025..0.027 rows=1 loops=1)
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
               Node 16387: (actual time=53453.471..53453.494 rows=100 loops=1)
               Node 16388: (actual time=49942.084..49942.108 rows=100 loops=1)
               Node 16389: (actual time=53848.382..53848.405 rows=100 loops=1)
               Node 16391: (actual time=51151.368..51151.390 rows=100 loops=1)
               Node 16390: (actual time=53767.354..53767.377 rows=100 loops=1)
               ->  Sort  (cost=3350657.95..3350657.95 rows=0 width=192) (actual time=0.053..0.058 rows=0 loops=1)
                     Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                     Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
                     Sort Method: quicksort  Memory: 25kB
                     Node 16387: (actual time=53453.469..53453.485 rows=100 loops=1)
                     Node 16388: (actual time=49942.082..49942.097 rows=100 loops=1)
                     Node 16389: (actual time=53848.380..53848.396 rows=100 loops=1)
                     Node 16391: (actual time=51151.366..51151.381 rows=100 loops=1)
                     Node 16390: (actual time=53767.351..53767.366 rows=100 loops=1)
                     ->  Hash Join  (cost=745137.06..3350657.94 rows=0 width=192) (actual time=0.039..0.044 rows=0 loops=1)
                           Output: supplier.s_acctbal, supplier.s_name, nation.n_name, part.p_partkey, part.p_mfgr, supplier.s_address, supplier.s_phone, supplier.s_comment
                           Inner Unique: true
                           Hash Cond: ((partsupp.ps_partkey = part.p_partkey) AND (partsupp.ps_supplycost = (SubPlan 1)))
                           Node 16387: (actual time=29139.384..53443.698 rows=9470 loops=1)
                           Node 16388: (actual time=25470.748..49931.102 rows=9568 loops=1)
                           Node 16389: (actual time=28986.730..53837.619 rows=9458 loops=1)
                           Node 16391: (actual time=27163.091..51140.554 rows=9109 loops=1)
                           Node 16390: (actual time=28689.875..53756.848 rows=9502 loops=1)
                           ->  Hash Join  (cost=35313.19..2640699.64 rows=25604 width=172) (never executed)
                                 Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, partsupp.ps_partkey, partsupp.ps_supplycost, nation.n_name
                                 Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                 Node 16387: (actual time=771.639..10560.464 rows=3208034 loops=1)
                                 Node 16388: (actual time=534.958..10318.774 rows=3209960 loops=1)
                                 Node 16389: (actual time=884.070..11161.827 rows=3209194 loops=1)
                                 Node 16391: (actual time=1162.072..11042.454 rows=3208964 loops=1)
                                 Node 16390: (actual time=277.271..10494.054 rows=3206648 loops=1)
                                 ->  Seq Scan on public.partsupp  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                       Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16387: (actual time=0.030..2418.896 rows=15996576 loops=1)
                                       Node 16388: (actual time=0.040..2478.183 rows=16002752 loops=1)
                                       Node 16389: (actual time=0.028..2891.289 rows=16007608 loops=1)
                                       Node 16391: (actual time=0.036..2516.609 rows=16002272 loops=1)
                                       Node 16390: (actual time=0.030..2554.792 rows=15990792 loops=1)
                                 ->  Hash  (cost=35213.19..35213.19 rows=8000 width=166) (never executed)
                                       Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                       Node 16387: (actual time=771.552..771.556 rows=200535 loops=1)
                                       Node 16388: (actual time=534.851..534.855 rows=200535 loops=1)
                                       Node 16389: (actual time=884.025..884.028 rows=200535 loops=1)
                                       Node 16391: (actual time=1161.967..1161.969 rows=200535 loops=1)
                                       Node 16390: (actual time=277.137..277.140 rows=200535 loops=1)
                                       ->  Cluster Reduce  (cost=10.39..35213.19 rows=8000 width=166) (never executed)
                                             Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                             Node 16387: (actual time=0.247..714.446 rows=200535 loops=1)
                                             Node 16388: (actual time=0.239..474.505 rows=200535 loops=1)
                                             Node 16389: (actual time=0.213..823.035 rows=200535 loops=1)
                                             Node 16391: (actual time=0.237..1099.757 rows=200535 loops=1)
                                             Node 16390: (actual time=0.276..223.290 rows=200535 loops=1)
                                             ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=166) (never executed)
                                                   Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name
                                                   Inner Unique: true
                                                   Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                   Node 16387: (actual time=0.070..124.008 rows=40056 loops=1)
                                                   Node 16388: (actual time=0.080..126.057 rows=40047 loops=1)
                                                   Node 16389: (actual time=0.064..125.034 rows=39991 loops=1)
                                                   Node 16391: (actual time=0.074..124.306 rows=40239 loops=1)
                                                   Node 16390: (actual time=0.051..121.790 rows=40202 loops=1)
                                                   ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=170) (never executed)
                                                         Output: supplier.s_acctbal, supplier.s_name, supplier.s_address, supplier.s_phone, supplier.s_comment, supplier.s_suppkey, nation.n_name, nation.n_regionkey
                                                         Inner Unique: true
                                                         Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                         Node 16387: (actual time=0.042..101.633 rows=199723 loops=1)
                                                         Node 16388: (actual time=0.054..103.668 rows=200234 loops=1)
                                                         Node 16389: (actual time=0.042..102.717 rows=199970 loops=1)
                                                         Node 16391: (actual time=0.050..102.026 rows=199703 loops=1)
                                                         Node 16390: (actual time=0.024..99.365 rows=200370 loops=1)
                                                         ->  Seq Scan on public.supplier  (cost=0.00..32180.00 rows=200000 width=144) (never executed)
                                                               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16387: (actual time=0.022..28.800 rows=199723 loops=1)
                                                               Node 16388: (actual time=0.028..28.047 rows=200234 loops=1)
                                                               Node 16389: (actual time=0.023..32.838 rows=199970 loops=1)
                                                               Node 16391: (actual time=0.028..30.148 rows=199703 loops=1)
                                                               Node 16390: (actual time=0.004..29.209 rows=200370 loops=1)
                                                         ->  Hash  (cost=5.25..5.25 rows=5 width=34) (never executed)
                                                               Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                               Node 16387: (actual time=0.014..0.016 rows=25 loops=1)
                                                               Node 16388: (actual time=0.020..0.021 rows=25 loops=1)
                                                               Node 16389: (actual time=0.014..0.015 rows=25 loops=1)
                                                               Node 16391: (actual time=0.016..0.017 rows=25 loops=1)
                                                               Node 16390: (actual time=0.014..0.015 rows=25 loops=1)
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=34) (never executed)
                                                                     Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     Node 16387: (actual time=0.005..0.008 rows=25 loops=1)
                                                                     Node 16388: (actual time=0.010..0.013 rows=25 loops=1)
                                                                     Node 16389: (actual time=0.005..0.008 rows=25 loops=1)
                                                                     Node 16391: (actual time=0.006..0.010 rows=25 loops=1)
                                                                     Node 16390: (actual time=0.005..0.008 rows=25 loops=1)
                                                   ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                         Output: region.r_regionkey
                                                         Node 16387: (actual time=0.015..0.016 rows=1 loops=1)
                                                         Node 16388: (actual time=0.019..0.019 rows=1 loops=1)
                                                         Node 16389: (actual time=0.015..0.015 rows=1 loops=1)
                                                         Node 16391: (actual time=0.019..0.020 rows=1 loops=1)
                                                         Node 16390: (actual time=0.018..0.018 rows=1 loops=1)
                                                         ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                               Output: region.r_regionkey
                                                               Filter: (region.r_name = 'EUROPE'::bpchar)
                                                               Remote node: 16387,16388,16389,16390,16391
                                                               Node 16387: (actual time=0.011..0.012 rows=1 loops=1)
                                                               Node 16388: (actual time=0.015..0.015 rows=1 loops=1)
                                                               Node 16389: (actual time=0.011..0.012 rows=1 loops=1)
                                                               Node 16391: (actual time=0.015..0.016 rows=1 loops=1)
                                                               Node 16390: (actual time=0.014..0.015 rows=1 loops=1)
                           ->  Hash  (cost=709595.86..709595.86 rows=15201 width=30) (actual time=0.025..0.028 rows=0 loops=1)
                                 Output: part.p_partkey, part.p_mfgr
                                 Buckets: 16384  Batches: 1  Memory Usage: 128kB
                                 Node 16387: (actual time=28363.559..28363.563 rows=9470 loops=1)
                                 Node 16388: (actual time=24932.440..24932.444 rows=9568 loops=1)
                                 Node 16389: (actual time=28100.952..28100.956 rows=9458 loops=1)
                                 Node 16391: (actual time=25998.188..25998.192 rows=9109 loops=1)
                                 Node 16390: (actual time=28409.402..28409.405 rows=9502 loops=1)
                                 ->  Seq Scan on public.part  (cost=0.00..709595.86 rows=15201 width=30) (actual time=0.024..0.024 rows=0 loops=1)
                                       Output: part.p_partkey, part.p_mfgr
                                       Filter: (((part.p_type)::text ~~ '%BRASS'::text) AND (part.p_size = 15))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16387: (actual time=1.178..1356.297 rows=15945 loops=1)
                                       Node 16388: (actual time=0.289..1342.372 rows=16118 loops=1)
                                       Node 16389: (actual time=0.030..1139.990 rows=15908 loops=1)
                                       Node 16391: (actual time=0.047..1264.364 rows=15563 loops=1)
                                       Node 16390: (actual time=0.149..1196.050 rows=16057 loops=1)
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
                                                                 Node 16387: (actual time=0.012..6425.235 rows=80000000 loops=1)
                                                                 Node 16388: (actual time=0.014..6522.099 rows=80000000 loops=1)
                                                                 Node 16389: (actual time=0.013..6509.005 rows=80000000 loops=1)
                                                                 Node 16391: (actual time=0.011..6728.823 rows=80000000 loops=1)
                                                                 Node 16390: (actual time=0.015..6534.960 rows=80000000 loops=1)
                                                                 ->  Seq Scan on public.partsupp partsupp_1  (cost=0.00..2544096.32 rows=16002646 width=14) (never executed)
                                                                       Output: partsupp_1.ps_supplycost, partsupp_1.ps_suppkey, partsupp_1.ps_partkey
                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                       Node 16387: (actual time=0.576..3820.895 rows=15996576 loops=1)
                                                                       Node 16388: (actual time=0.499..3568.051 rows=16002752 loops=1)
                                                                       Node 16389: (actual time=0.022..4053.808 rows=16007608 loops=1)
                                                                       Node 16391: (actual time=0.027..3645.002 rows=16002272 loops=1)
                                                                       Node 16390: (actual time=0.023..3736.112 rows=15990792 loops=1)
                                                     ->  Hash  (cost=35339.19..35339.19 rows=8000 width=4) (never executed)
                                                           Output: supplier_1.s_suppkey
                                                           Node 16387: (actual time=3705.144..3705.147 rows=200535 loops=1)
                                                           Node 16388: (actual time=43.194..43.197 rows=200535 loops=1)
                                                           Node 16389: (actual time=3597.463..3597.467 rows=200535 loops=1)
                                                           Node 16391: (actual time=1770.214..1770.218 rows=200535 loops=1)
                                                           Node 16390: (actual time=3342.175..3342.177 rows=200535 loops=1)
                                                           ->  Cluster Reduce  (cost=10.39..35339.19 rows=8000 width=4) (never executed)
                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                 Node 16387: (actual time=0.008..3678.342 rows=200535 loops=1)
                                                                 Node 16388: (actual time=0.007..16.872 rows=200535 loops=1)
                                                                 Node 16389: (actual time=0.007..3570.602 rows=200535 loops=1)
                                                                 Node 16391: (actual time=0.005..1743.816 rows=200535 loops=1)
                                                                 Node 16390: (actual time=0.008..3315.321 rows=200535 loops=1)
                                                                 ->  Hash Join  (cost=9.39..32842.19 rows=1600 width=4) (never executed)
                                                                       Output: supplier_1.s_suppkey
                                                                       Inner Unique: true
                                                                       Hash Cond: (nation_1.n_regionkey = region_1.r_regionkey)
                                                                       Node 16387: (actual time=1.017..112.213 rows=40056 loops=1)
                                                                       Node 16388: (actual time=1.107..109.821 rows=40047 loops=1)
                                                                       Node 16389: (actual time=0.334..108.054 rows=39991 loops=1)
                                                                       Node 16391: (actual time=0.330..108.305 rows=40239 loops=1)
                                                                       Node 16390: (actual time=0.356..109.934 rows=40202 loops=1)
                                                                       ->  Hash Join  (cost=5.31..32799.31 rows=8000 width=8) (never executed)
                                                                             Output: supplier_1.s_suppkey, nation_1.n_regionkey
                                                                             Inner Unique: true
                                                                             Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                             Node 16387: (actual time=0.384..90.267 rows=199723 loops=1)
                                                                             Node 16388: (actual time=0.730..88.084 rows=200234 loops=1)
                                                                             Node 16389: (actual time=0.054..86.440 rows=199970 loops=1)
                                                                             Node 16391: (actual time=0.061..86.620 rows=199703 loops=1)
                                                                             Node 16390: (actual time=0.039..88.115 rows=200370 loops=1)
                                                                             ->  Seq Scan on public.supplier supplier_1  (cost=0.00..32180.00 rows=200000 width=8) (never executed)
                                                                                   Output: supplier_1.s_suppkey, supplier_1.s_name, supplier_1.s_address, supplier_1.s_nationkey, supplier_1.s_phone, supplier_1.s_acctbal, supplier_1.s_comment
                                                                                   Remote node: 16389,16387,16390,16388,16391
                                                                                   Node 16387: (actual time=0.351..31.985 rows=199723 loops=1)
                                                                                   Node 16388: (actual time=0.696..28.959 rows=200234 loops=1)
                                                                                   Node 16389: (actual time=0.029..31.547 rows=199970 loops=1)
                                                                                   Node 16391: (actual time=0.034..28.967 rows=199703 loops=1)
                                                                                   Node 16390: (actual time=0.013..27.595 rows=200370 loops=1)
                                                                             ->  Hash  (cost=5.25..5.25 rows=5 width=8) (never executed)
                                                                                   Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                   Node 16387: (actual time=0.027..0.027 rows=25 loops=1)
                                                                                   Node 16388: (actual time=0.025..0.026 rows=25 loops=1)
                                                                                   Node 16389: (actual time=0.018..0.018 rows=25 loops=1)
                                                                                   Node 16391: (actual time=0.020..0.020 rows=25 loops=1)
                                                                                   Node 16390: (actual time=0.018..0.019 rows=25 loops=1)
                                                                                   ->  Seq Scan on public.nation nation_1  (cost=0.00..5.25 rows=5 width=8) (never executed)
                                                                                         Output: nation_1.n_nationkey, nation_1.n_regionkey
                                                                                         Remote node: 16387,16388,16389,16390,16391
                                                                                         Node 16387: (actual time=0.017..0.021 rows=25 loops=1)
                                                                                         Node 16388: (actual time=0.016..0.019 rows=25 loops=1)
                                                                                         Node 16389: (actual time=0.009..0.012 rows=25 loops=1)
                                                                                         Node 16391: (actual time=0.010..0.014 rows=25 loops=1)
                                                                                         Node 16390: (actual time=0.009..0.013 rows=25 loops=1)
                                                                       ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                                             Output: region_1.r_regionkey
                                                                             Node 16387: (actual time=0.411..0.411 rows=1 loops=1)
                                                                             Node 16388: (actual time=0.065..0.065 rows=1 loops=1)
                                                                             Node 16389: (actual time=0.030..0.030 rows=1 loops=1)
                                                                             Node 16391: (actual time=0.030..0.030 rows=1 loops=1)
                                                                             Node 16390: (actual time=0.038..0.038 rows=1 loops=1)
                                                                             ->  Seq Scan on public.region region_1  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                                                   Output: region_1.r_regionkey
                                                                                   Filter: (region_1.r_name = 'EUROPE'::bpchar)
                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                   Node 16387: (actual time=0.404..0.405 rows=1 loops=1)
                                                                                   Node 16388: (actual time=0.054..0.055 rows=1 loops=1)
                                                                                   Node 16389: (actual time=0.021..0.022 rows=1 loops=1)
                                                                                   Node 16391: (actual time=0.022..0.023 rows=1 loops=1)
                                                                                   Node 16390: (actual time=0.028..0.029 rows=1 loops=1)
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
               Node 16388: (actual time=62218.904..62403.893 rows=10 loops=1)
               Node 16389: (actual time=31944.942..32153.908 rows=10 loops=1)
               Node 16390: (actual time=32239.927..32450.810 rows=10 loops=1)
               Node 16391: (actual time=32045.068..32251.861 rows=10 loops=1)
               Node 16387: (actual time=62870.580..63075.528 rows=10 loops=1)
               ->  Sort  (cost=19442914.05..19442967.48 rows=21373 width=44) (actual time=0.008..0.011 rows=0 loops=1)
                     Output: lineitem.l_orderkey, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), orders.o_orderdate, orders.o_shippriority
                     Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC, orders.o_orderdate
                     Sort Method: quicksort  Memory: 25kB
                     Node 16388: (actual time=62218.901..62403.889 rows=10 loops=1)
                     Node 16389: (actual time=31944.940..32153.903 rows=10 loops=1)
                     Node 16390: (actual time=32239.925..32450.808 rows=10 loops=1)
                     Node 16391: (actual time=32045.065..32251.857 rows=10 loops=1)
                     Node 16387: (actual time=62870.577..63075.524 rows=10 loops=1)
                     ->  Finalize GroupAggregate  (cost=19436293.72..19442452.18 rows=21373 width=44) (actual time=0.000..0.003 rows=0 loops=1)
                           Output: lineitem.l_orderkey, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))), orders.o_orderdate, orders.o_shippriority
                           Group Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                           Node 16388: (actual time=61724.467..62350.019 rows=225813 loops=1)
                           Node 16389: (actual time=31440.140..32099.843 rows=226430 loops=1)
                           Node 16390: (actual time=31727.445..32396.773 rows=226254 loops=1)
                           Node 16391: (actual time=31546.957..32197.697 rows=225816 loops=1)
                           Node 16387: (actual time=62363.343..63021.342 rows=226728 loops=1)
                           ->  Gather Merge  (cost=19436293.72..19441650.69 rows=42746 width=44) (never executed)
                                 Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
                                 Workers Planned: 2
                                 Workers Launched: 0
                                 Node 16388: (actual time=61724.449..62139.599 rows=225994 loops=1)
                                 Node 16389: (actual time=31440.121..31888.451 rows=226603 loops=1)
                                 Node 16390: (actual time=31727.434..32185.460 rows=226416 loops=1)
                                 Node 16391: (actual time=31546.948..31986.690 rows=225946 loops=1)
                                 Node 16387: (actual time=62363.329..62809.308 rows=226867 loops=1)
                                 ->  Partial GroupAggregate  (cost=19435293.70..19435716.71 rows=21373 width=44) (never executed)
                                       Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                                       Group Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                                       Node 16388: (actual time=61716.201..61899.144 rows=75331 loops=3)
                                         Worker 0: actual time=61711.929..61897.637 rows=75843 loops=1
                                         Worker 1: actual time=61713.016..61902.371 rows=77689 loops=1
                                       Node 16389: (actual time=31432.215..31614.950 rows=75534 loops=3)
                                         Worker 0: actual time=31436.274..31612.456 rows=72967 loops=1
                                         Worker 1: actual time=31428.591..31615.356 rows=76780 loops=1
                                       Node 16390: (actual time=31719.213..31901.578 rows=75472 loops=3)
                                         Worker 0: actual time=31714.739..31898.486 rows=75559 loops=1
                                         Worker 1: actual time=31723.846..31902.080 rows=73623 loops=1
                                       Node 16391: (actual time=31539.605..31722.880 rows=75315 loops=3)
                                         Worker 0: actual time=31536.472..31724.789 rows=77068 loops=1
                                         Worker 1: actual time=31535.819..31723.166 rows=76467 loops=1
                                       Node 16387: (actual time=62359.648..62542.010 rows=75622 loops=3)
                                         Worker 0: actual time=62358.714..62543.042 rows=76071 loops=1
                                         Worker 1: actual time=62358.828..62543.959 rows=76588 loops=1
                                       ->  Sort  (cost=19435293.70..19435315.96 rows=8906 width=24) (never executed)
                                             Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, lineitem.l_extendedprice, lineitem.l_discount
                                             Sort Key: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority
                                             Node 16388: (actual time=61716.173..61747.071 rows=198899 loops=3)
                                               Worker 0: actual time=61711.896..61744.253 rows=200442 loops=1
                                               Worker 1: actual time=61712.997..61745.391 rows=205220 loops=1
                                             Node 16389: (actual time=31432.189..31462.972 rows=199032 loops=3)
                                               Worker 0: actual time=31436.249..31466.455 rows=191446 loops=1
                                               Worker 1: actual time=31428.566..31460.819 rows=203105 loops=1
                                             Node 16390: (actual time=31719.200..31749.454 rows=199060 loops=3)
                                               Worker 0: actual time=31714.724..31745.329 rows=199737 loops=1
                                               Worker 1: actual time=31723.834..31753.705 rows=193845 loops=1
                                             Node 16391: (actual time=31539.586..31570.664 rows=199478 loops=3)
                                               Worker 0: actual time=31536.460..31568.744 rows=204597 loops=1
                                               Worker 1: actual time=31535.794..31567.932 rows=202410 loops=1
                                             Node 16387: (actual time=62359.626..62389.990 rows=199391 loops=3)
                                               Worker 0: actual time=62358.690..62389.844 rows=200657 loops=1
                                               Worker 1: actual time=62358.818..62390.035 rows=201382 loops=1
                                             ->  Parallel Hash Join  (cost=4372913.58..19434709.44 rows=8906 width=24) (never executed)
                                                   Output: lineitem.l_orderkey, orders.o_orderdate, orders.o_shippriority, lineitem.l_extendedprice, lineitem.l_discount
                                                   Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                   Node 16388: (actual time=55202.283..61617.457 rows=198899 loops=3)
                                                     Worker 0: actual time=55204.864..61610.795 rows=200442 loops=1
                                                     Worker 1: actual time=55193.593..61613.734 rows=205220 loops=1
                                                   Node 16389: (actual time=24840.338..31334.605 rows=199032 loops=3)
                                                     Worker 0: actual time=24845.258..31342.076 rows=191446 loops=1
                                                     Worker 1: actual time=24841.680..31329.253 rows=203105 loops=1
                                                   Node 16390: (actual time=25033.223..31620.108 rows=199060 loops=3)
                                                     Worker 0: actual time=25024.560..31615.943 rows=199737 loops=1
                                                     Worker 1: actual time=25036.208..31626.592 rows=193845 loops=1
                                                   Node 16391: (actual time=24846.498..31440.420 rows=199478 loops=3)
                                                     Worker 0: actual time=24838.308..31433.772 rows=204597 loops=1
                                                     Worker 1: actual time=24848.851..31434.243 rows=202410 loops=1
                                                   Node 16387: (actual time=55801.987..62261.561 rows=199391 loops=3)
                                                     Worker 0: actual time=55804.713..62260.666 rows=200657 loops=1
                                                     Worker 1: actual time=55793.646..62259.893 rows=201382 loops=1
                                                   ->  Parallel Seq Scan on public.lineitem  (cost=0.00..14999255.80 rows=16667452 width=16) (never executed)
                                                         Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                         Filter: ((lineitem.l_shipdate)::timestamp without time zone > '1995-03-15 00:00:00'::timestamp without time zone)
                                                         Remote node: 16389,16387,16390,16388,16391
                                                         Node 16388: (actual time=0.377..37039.808 rows=21567591 loops=3)
                                                           Worker 0: actual time=0.364..36727.464 rows=21030868 loops=1
                                                           Worker 1: actual time=0.373..37325.213 rows=21566389 loops=1
                                                         Node 16389: (actual time=0.063..12497.733 rows=21567163 loops=3)
                                                           Worker 0: actual time=0.060..11915.059 rows=22439656 loops=1
                                                           Worker 1: actual time=0.070..12781.553 rows=21446924 loops=1
                                                         Node 16390: (actual time=0.077..12370.038 rows=21561253 loops=3)
                                                           Worker 0: actual time=0.118..12791.610 rows=20593031 loops=1
                                                           Worker 1: actual time=0.069..12040.801 rows=21640830 loops=1
                                                         Node 16391: (actual time=0.096..12325.068 rows=21567915 loops=3)
                                                           Worker 0: actual time=0.056..12212.269 rows=21419714 loops=1
                                                           Worker 1: actual time=0.177..12225.681 rows=21537346 loops=1
                                                         Node 16387: (actual time=0.395..37393.378 rows=21567584 loops=3)
                                                           Worker 0: actual time=0.394..37210.928 rows=21821174 loops=1
                                                           Worker 1: actual time=0.413..37343.036 rows=22285209 loops=1
                                                   ->  Parallel Hash  (cost=4372496.16..4372496.16 rows=33394 width=12) (never executed)
                                                         Output: orders.o_orderdate, orders.o_shippriority, orders.o_orderkey
                                                         Node 16388: (actual time=12569.862..12569.871 rows=971882 loops=3)
                                                           Worker 0: actual time=12568.634..12568.645 rows=986121 loops=1
                                                           Worker 1: actual time=12568.734..12568.741 rows=969210 loops=1
                                                         Node 16389: (actual time=7199.560..7199.571 rows=970420 loops=3)
                                                           Worker 0: actual time=7198.488..7198.494 rows=917689 loops=1
                                                           Worker 1: actual time=7198.514..7198.521 rows=1005806 loops=1
                                                         Node 16390: (actual time=7284.237..7284.246 rows=971078 loops=3)
                                                           Worker 0: actual time=7283.121..7283.129 rows=1022828 loops=1
                                                           Worker 1: actual time=7283.319..7283.326 rows=942621 loops=1
                                                         Node 16391: (actual time=7027.891..7027.897 rows=971022 loops=3)
                                                           Worker 0: actual time=7026.945..7026.950 rows=996644 loops=1
                                                           Worker 1: actual time=7026.950..7026.956 rows=947209 loops=1
                                                         Node 16387: (actual time=12851.829..12851.836 rows=971551 loops=3)
                                                           Worker 0: actual time=12850.591..12850.598 rows=964217 loops=1
                                                           Worker 1: actual time=12850.573..12850.579 rows=960287 loops=1
                                                         ->  Parallel Hash Join  (cost=769248.04..4372496.16 rows=33394 width=12) (never executed)
                                                               Output: orders.o_orderdate, orders.o_shippriority, orders.o_orderkey
                                                               Inner Unique: true
                                                               Hash Cond: (orders.o_custkey = customer.c_custkey)
                                                               Node 16388: (actual time=10877.086..12144.371 rows=971882 loops=3)
                                                                 Worker 0: actual time=10879.233..12149.532 rows=986121 loops=1
                                                                 Worker 1: actual time=10867.302..12144.308 rows=969210 loops=1
                                                               Node 16389: (actual time=5543.989..6808.994 rows=970420 loops=3)
                                                                 Worker 0: actual time=5548.537..6801.177 rows=917689 loops=1
                                                                 Worker 1: actual time=5533.788..6806.219 rows=1005806 loops=1
                                                               Node 16390: (actual time=5519.623..6840.936 rows=971078 loops=3)
                                                                 Worker 0: actual time=5523.375..6825.087 rows=1022828 loops=1
                                                                 Worker 1: actual time=5510.021..6841.353 rows=942621 loops=1
                                                               Node 16391: (actual time=5297.853..6605.459 rows=971022 loops=3)
                                                                 Worker 0: actual time=5301.562..6599.891 rows=996644 loops=1
                                                                 Worker 1: actual time=5288.240..6614.567 rows=947209 loops=1
                                                               Node 16387: (actual time=11143.472..12409.307 rows=971551 loops=3)
                                                                 Worker 0: actual time=11133.699..12416.638 rows=964217 loops=1
                                                                 Worker 1: actual time=11146.411..12391.894 rows=960287 loops=1
                                                               ->  Parallel Seq Scan on public.orders  (cost=0.00..3546728.70 rows=4166634 width=16) (never executed)
                                                                     Output: orders.o_orderdate, orders.o_shippriority, orders.o_custkey, orders.o_orderkey
                                                                     Filter: ((orders.o_orderdate)::timestamp without time zone < '1995-03-15 00:00:00'::timestamp without time zone)
                                                                     Remote node: 16389,16387,16390,16388,16391
                                                                     Node 16388: (actual time=0.579..8260.471 rows=4859698 loops=3)
                                                                       Worker 0: actual time=0.574..8323.789 rows=4796035 loops=1
                                                                       Worker 1: actual time=0.586..8218.631 rows=4997644 loops=1
                                                                     Node 16389: (actual time=0.054..2978.130 rows=4857286 loops=3)
                                                                       Worker 0: actual time=0.055..3001.529 rows=4761600 loops=1
                                                                       Worker 1: actual time=0.055..2961.956 rows=4852894 loops=1
                                                                     Node 16390: (actual time=0.038..2957.880 rows=4859942 loops=3)
                                                                       Worker 0: actual time=0.038..3039.949 rows=4567795 loops=1
                                                                       Worker 1: actual time=0.036..2916.494 rows=4903742 loops=1
                                                                     Node 16391: (actual time=0.042..2728.460 rows=4857720 loops=3)
                                                                       Worker 0: actual time=0.041..2700.868 rows=4921157 loops=1
                                                                       Worker 1: actual time=0.040..2702.816 rows=4910114 loops=1
                                                                     Node 16387: (actual time=0.514..8573.849 rows=4856815 loops=3)
                                                                       Worker 0: actual time=0.510..8540.458 rows=4905589 loops=1
                                                                       Worker 1: actual time=0.511..8548.076 rows=4931187 loops=1
                                                               ->  Parallel Hash  (cost=748702.11..748702.11 rows=1252315 width=4) (never executed)
                                                                     Output: customer.c_custkey
                                                                     Node 16388: (actual time=1528.202..1528.203 rows=1000063 loops=3)
                                                                       Worker 0: actual time=1527.025..1527.027 rows=1009354 loops=1
                                                                       Worker 1: actual time=1527.139..1527.139 rows=1003723 loops=1
                                                                     Node 16389: (actual time=1521.623..1521.624 rows=1000063 loops=3)
                                                                       Worker 0: actual time=1520.639..1520.640 rows=995405 loops=1
                                                                       Worker 1: actual time=1520.639..1520.641 rows=993659 loops=1
                                                                     Node 16390: (actual time=1522.838..1522.839 rows=1000063 loops=3)
                                                                       Worker 0: actual time=1521.792..1521.794 rows=1001844 loops=1
                                                                       Worker 1: actual time=1521.974..1521.974 rows=977125 loops=1
                                                                     Node 16391: (actual time=1518.895..1518.896 rows=1000063 loops=3)
                                                                       Worker 0: actual time=1518.024..1518.024 rows=991878 loops=1
                                                                       Worker 1: actual time=1518.024..1518.025 rows=1004123 loops=1
                                                                     Node 16387: (actual time=1517.411..1517.411 rows=1000063 loops=3)
                                                                       Worker 0: actual time=1516.245..1516.246 rows=988748 loops=1
                                                                       Worker 1: actual time=1516.247..1516.248 rows=990910 loops=1
                                                                     ->  Cluster Reduce  (cost=1.00..748702.11 rows=1252315 width=4) (never executed)
                                                                           Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                           Node 16388: (actual time=1298.770..1381.381 rows=1000063 loops=3)
                                                                             Worker 0: actual time=1297.585..1380.080 rows=1009354 loops=1
                                                                             Worker 1: actual time=1297.713..1379.661 rows=1003723 loops=1
                                                                           Node 16389: (actual time=479.969..1376.152 rows=1000063 loops=3)
                                                                             Worker 0: actual time=478.971..1372.969 rows=995405 loops=1
                                                                             Worker 1: actual time=478.971..1372.665 rows=993659 loops=1
                                                                           Node 16390: (actual time=440.450..1374.544 rows=1000063 loops=3)
                                                                             Worker 0: actual time=439.381..1372.635 rows=1001844 loops=1
                                                                             Worker 1: actual time=439.590..1369.786 rows=977125 loops=1
                                                                           Node 16391: (actual time=416.596..1365.320 rows=1000063 loops=3)
                                                                             Worker 0: actual time=415.703..1363.240 rows=991878 loops=1
                                                                             Worker 1: actual time=415.704..1364.979 rows=1004123 loops=1
                                                                           Node 16387: (actual time=1278.539..1374.378 rows=1000063 loops=3)
                                                                             Worker 0: actual time=1277.359..1370.661 rows=988748 loops=1
                                                                             Worker 1: actual time=1277.365..1370.541 rows=990910 loops=1
                                                                           ->  Parallel Seq Scan on public.customer  (cost=0.00..436403.51 rows=250463 width=4) (never executed)
                                                                                 Output: customer.c_custkey
                                                                                 Filter: (customer.c_mktsegment = 'BUILDING'::bpchar)
                                                                                 Remote node: 16389,16387,16390,16388,16391
                                                                                 Node 16388: (actual time=0.181..1128.903 rows=199942 loops=3)
                                                                                   Worker 0: actual time=0.027..1117.118 rows=196881 loops=1
                                                                                   Worker 1: actual time=0.025..1118.875 rows=196254 loops=1
                                                                                 Node 16389: (actual time=0.036..323.242 rows=200079 loops=3)
                                                                                   Worker 0: actual time=0.037..309.943 rows=200725 loops=1
                                                                                   Worker 1: actual time=0.038..310.549 rows=200165 loops=1
                                                                                 Node 16390: (actual time=0.029..317.356 rows=200170 loops=3)
                                                                                   Worker 0: actual time=0.028..311.550 rows=201833 loops=1
                                                                                   Worker 1: actual time=0.028..324.280 rows=215693 loops=1
                                                                                 Node 16391: (actual time=0.030..299.554 rows=199847 loops=3)
                                                                                   Worker 0: actual time=0.028..299.285 rows=208586 loops=1
                                                                                   Worker 1: actual time=0.027..299.121 rows=208541 loops=1
                                                                                 Node 16387: (actual time=0.149..1145.623 rows=200025 loops=3)
                                                                                   Worker 0: actual time=0.032..1149.217 rows=197260 loops=1
                                                                                   Worker 1: actual time=0.031..1148.265 rows=208154 loops=1
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
               Node 16390: (actual time=29561.517..29888.017 rows=15 loops=1)
               Node 16391: (actual time=29683.872..30025.460 rows=15 loops=1)
               Node 16387: (actual time=28244.313..28524.884 rows=15 loops=1)
               Node 16388: (actual time=29229.151..29512.888 rows=15 loops=1)
               Node 16389: (actual time=30008.950..30307.158 rows=15 loops=1)
               ->  Sort  (cost=19822991.29..19822991.30 rows=5 width=24) (actual time=0.129..0.131 rows=0 loops=1)
                     Output: orders.o_orderpriority, (PARTIAL count(*))
                     Sort Key: orders.o_orderpriority
                     Sort Method: quicksort  Memory: 25kB
                     Node 16390: (actual time=29558.585..29558.630 rows=5 loops=3)
                       Worker 0: actual time=29557.148..29557.208 rows=5 loops=1
                       Worker 1: actual time=29557.364..29557.400 rows=5 loops=1
                     Node 16391: (actual time=29681.195..29681.233 rows=5 loops=3)
                       Worker 0: actual time=29680.221..29680.267 rows=5 loops=1
                       Worker 1: actual time=29679.962..29679.995 rows=5 loops=1
                     Node 16387: (actual time=28241.978..28242.038 rows=5 loops=3)
                       Worker 0: actual time=28240.967..28241.006 rows=5 loops=1
                       Worker 1: actual time=28240.913..28240.946 rows=5 loops=1
                     Node 16388: (actual time=29226.612..29226.668 rows=5 loops=3)
                       Worker 0: actual time=29225.716..29225.768 rows=5 loops=1
                       Worker 1: actual time=29225.565..29225.613 rows=5 loops=1
                     Node 16389: (actual time=30006.381..30006.456 rows=5 loops=3)
                       Worker 0: actual time=30005.382..30005.424 rows=5 loops=1
                       Worker 1: actual time=30005.347..30005.387 rows=5 loops=1
                     ->  Partial HashAggregate  (cost=19822991.18..19822991.23 rows=5 width=24) (actual time=0.125..0.127 rows=0 loops=1)
                           Output: orders.o_orderpriority, PARTIAL count(*)
                           Group Key: orders.o_orderpriority
                           Batches: 1  Memory Usage: 24kB
                           Node 16390: (actual time=29558.529..29558.576 rows=5 loops=3)
                             Worker 0: actual time=29557.072..29557.136 rows=5 loops=1
                             Worker 1: actual time=29557.288..29557.326 rows=5 loops=1
                           Node 16391: (actual time=29681.143..29681.181 rows=5 loops=3)
                             Worker 0: actual time=29680.148..29680.194 rows=5 loops=1
                             Worker 1: actual time=29679.894..29679.927 rows=5 loops=1
                           Node 16387: (actual time=28241.928..28241.988 rows=5 loops=3)
                             Worker 0: actual time=28240.909..28240.949 rows=5 loops=1
                             Worker 1: actual time=28240.840..28240.874 rows=5 loops=1
                           Node 16388: (actual time=29226.516..29226.575 rows=5 loops=3)
                             Worker 0: actual time=29225.579..29225.635 rows=5 loops=1
                             Worker 1: actual time=29225.433..29225.484 rows=5 loops=1
                           Node 16389: (actual time=30006.311..30006.388 rows=5 loops=3)
                             Worker 0: actual time=30005.314..30005.358 rows=5 loops=1
                             Worker 1: actual time=30005.268..30005.309 rows=5 loops=1
                           ->  Parallel Hash Semi Join  (cost=15897736.42..19822990.31 rows=173 width=16) (actual time=0.124..0.126 rows=0 loops=1)
                                 Output: orders.o_orderpriority
                                 Hash Cond: (orders.o_orderkey = lineitem.l_orderkey)
                                 Node 16390: (actual time=22628.631..29479.205 rows=350769 loops=3)
                                   Worker 0: actual time=22614.687..29475.507 rows=359433 loops=1
                                   Worker 1: actual time=22633.787..29479.908 rows=340860 loops=1
                                 Node 16391: (actual time=23241.458..29601.498 rows=351020 loops=3)
                                   Worker 0: actual time=23246.098..29604.993 rows=331483 loops=1
                                   Worker 1: actual time=23226.889..29596.018 rows=367642 loops=1
                                 Node 16387: (actual time=22502.580..28161.648 rows=350051 loops=3)
                                   Worker 0: actual time=22507.281..28157.919 rows=357846 loops=1
                                   Worker 1: actual time=22507.232..28157.482 rows=358831 loops=1
                                 Node 16388: (actual time=22912.436..29147.548 rows=350523 loops=3)
                                   Worker 0: actual time=22917.688..29144.489 rows=357137 loops=1
                                   Worker 1: actual time=22917.276..29144.984 rows=358513 loops=1
                                 Node 16389: (actual time=23239.466..29927.270 rows=350113 loops=3)
                                   Worker 0: actual time=23245.507..29930.163 rows=333781 loops=1
                                   Worker 1: actual time=23245.219..29922.737 rows=363854 loops=1
                                 ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=20) (never executed)
                                       Output: orders.o_orderpriority, orders.o_orderkey
                                       Filter: (((orders.o_orderdate)::timestamp without time zone >= '1993-07-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone < '1993-10-01 00:00:00'::timestamp without time zone))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16390: (actual time=0.112..2431.964 rows=382505 loops=3)
                                         Worker 0: actual time=0.116..2442.776 rows=355473 loops=1
                                         Worker 1: actual time=0.098..2427.882 rows=392317 loops=1
                                       Node 16391: (actual time=0.093..2545.738 rows=382595 loops=3)
                                         Worker 0: actual time=0.106..2523.506 rows=408573 loops=1
                                         Worker 1: actual time=0.120..2552.988 rows=364840 loops=1
                                       Node 16387: (actual time=0.084..2441.303 rows=381950 loops=3)
                                         Worker 0: actual time=0.108..2442.536 rows=398565 loops=1
                                         Worker 1: actual time=0.100..2441.215 rows=393673 loops=1
                                       Node 16388: (actual time=0.096..2504.374 rows=382386 loops=3)
                                         Worker 0: actual time=0.107..2508.682 rows=386688 loops=1
                                         Worker 1: actual time=0.123..2508.394 rows=383648 loops=1
                                       Node 16389: (actual time=0.092..2383.584 rows=381822 loops=3)
                                         Worker 0: actual time=0.105..2391.785 rows=365730 loops=1
                                         Worker 1: actual time=0.120..2383.803 rows=391464 loops=1
                                 ->  Parallel Hash  (cost=15624285.27..15624285.27 rows=16667452 width=4) (actual time=0.006..0.007 rows=0 loops=1)
                                       Output: lineitem.l_orderkey
                                       Buckets: 131072  Batches: 1024  Memory Usage: 1024kB
                                       Node 16390: (actual time=19861.473..19861.473 rows=25290584 loops=3)
                                         Worker 0: actual time=19860.358..19860.359 rows=23809586 loops=1
                                         Worker 1: actual time=19860.385..19860.386 rows=25820744 loops=1
                                       Node 16391: (actual time=20347.635..20347.635 rows=25292566 loops=3)
                                         Worker 0: actual time=20346.714..20346.715 rows=25417533 loops=1
                                         Worker 1: actual time=20346.730..20346.730 rows=24821122 loops=1
                                       Node 16387: (actual time=19670.821..19670.822 rows=25288296 loops=3)
                                         Worker 0: actual time=19669.984..19669.985 rows=25887179 loops=1
                                         Worker 1: actual time=19669.998..19669.999 rows=26003247 loops=1
                                       Node 16388: (actual time=20103.623..20103.624 rows=25294532 loops=3)
                                         Worker 0: actual time=20102.778..20102.780 rows=25386627 loops=1
                                         Worker 1: actual time=20102.778..20102.780 rows=24836709 loops=1
                                       Node 16389: (actual time=20498.141..20498.142 rows=25286180 loops=3)
                                         Worker 0: actual time=20497.252..20497.253 rows=26193856 loops=1
                                         Worker 1: actual time=20497.240..20497.240 rows=25154041 loops=1
                                       ->  Parallel Seq Scan on public.lineitem  (cost=0.00..15624285.27 rows=16667452 width=4) (actual time=0.005..0.005 rows=0 loops=1)
                                             Output: lineitem.l_orderkey
                                             Filter: ((lineitem.l_commitdate)::timestamp without time zone < (lineitem.l_receiptdate)::timestamp without time zone)
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16390: (actual time=0.035..13951.120 rows=25290584 loops=3)
                                               Worker 0: actual time=0.034..14305.905 rows=23809586 loops=1
                                               Worker 1: actual time=0.029..13741.711 rows=25820744 loops=1
                                             Node 16391: (actual time=0.039..14342.142 rows=25292566 loops=3)
                                               Worker 0: actual time=0.035..14309.092 rows=25417533 loops=1
                                               Worker 1: actual time=0.037..14314.835 rows=24821122 loops=1
                                             Node 16387: (actual time=0.045..13804.232 rows=25288296 loops=3)
                                               Worker 0: actual time=0.047..13649.236 rows=25887179 loops=1
                                               Worker 1: actual time=0.047..13673.140 rows=26003247 loops=1
                                             Node 16388: (actual time=0.042..14280.778 rows=25294532 loops=3)
                                               Worker 0: actual time=0.043..14297.002 rows=25386627 loops=1
                                               Worker 1: actual time=0.044..14310.372 rows=24836709 loops=1
                                             Node 16389: (actual time=0.042..14637.919 rows=25286180 loops=3)
                                               Worker 0: actual time=0.039..14382.434 rows=26193856 loops=1
                                               Worker 1: actual time=0.039..14647.481 rows=25154041 loops=1
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
                     Node 16388: (actual time=48731.085..49461.146 rows=15 loops=1)
                     Node 16390: (actual time=48762.367..49652.355 rows=15 loops=1)
                     Node 16387: (actual time=48814.675..49585.940 rows=15 loops=1)
                     Node 16389: (actual time=48786.093..49804.249 rows=15 loops=1)
                     Node 16391: (actual time=48746.181..49926.412 rows=15 loops=1)
                     ->  Partial GroupAggregate  (cost=18193179.40..18193179.42 rows=1 width=58) (actual time=0.018..0.021 rows=0 loops=1)
                           Output: nation.n_name, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                           Group Key: nation.n_name
                           Node 16388: (actual time=48726.724..48753.368 rows=5 loops=3)
                             Worker 0: actual time=48725.288..48750.957 rows=5 loops=1
                             Worker 1: actual time=48724.459..48749.414 rows=5 loops=1
                           Node 16390: (actual time=48758.769..48785.508 rows=5 loops=3)
                             Worker 0: actual time=48756.563..48781.117 rows=5 loops=1
                             Worker 1: actual time=48758.342..48786.289 rows=5 loops=1
                           Node 16387: (actual time=48811.232..48837.731 rows=5 loops=3)
                             Worker 0: actual time=48810.382..48837.533 rows=5 loops=1
                             Worker 1: actual time=48809.966..48836.214 rows=5 loops=1
                           Node 16389: (actual time=48781.913..48808.839 rows=5 loops=3)
                             Worker 0: actual time=48781.663..48810.302 rows=5 loops=1
                             Worker 1: actual time=48781.720..48810.407 rows=5 loops=1
                           Node 16391: (actual time=48742.213..48769.046 rows=5 loops=3)
                             Worker 0: actual time=48742.182..48770.749 rows=5 loops=1
                             Worker 1: actual time=48741.036..48767.230 rows=5 loops=1
                           ->  Sort  (cost=18193179.40..18193179.40 rows=1 width=38) (actual time=0.018..0.020 rows=0 loops=1)
                                 Output: nation.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                 Sort Key: nation.n_name
                                 Sort Method: quicksort  Memory: 25kB
                                 Node 16388: (actual time=48719.862..48728.325 rows=48789 loops=3)
                                   Worker 0: actual time=48718.529..48726.690 rows=47222 loops=1
                                   Worker 1: actual time=48718.340..48726.239 rows=45185 loops=1
                                 Node 16390: (actual time=48752.061..48760.560 rows=48581 loops=3)
                                   Worker 0: actual time=48750.347..48758.068 rows=44885 loops=1
                                   Worker 1: actual time=48751.335..48760.133 rows=51033 loops=1
                                 Node 16387: (actual time=48804.609..48813.042 rows=48076 loops=3)
                                   Worker 0: actual time=48803.570..48812.209 rows=49366 loops=1
                                   Worker 1: actual time=48803.463..48811.767 rows=47504 loops=1
                                 Node 16389: (actual time=48775.224..48783.974 rows=48480 loops=3)
                                   Worker 0: actual time=48774.542..48783.921 rows=51516 loops=1
                                   Worker 1: actual time=48774.485..48783.790 rows=51883 loops=1
                                 Node 16391: (actual time=48735.549..48744.024 rows=48822 loops=3)
                                   Worker 0: actual time=48735.077..48744.077 rows=52068 loops=1
                                   Worker 1: actual time=48734.371..48742.639 rows=48006 loops=1
                                 ->  Parallel Hash Join  (cost=18166207.71..18193179.39 rows=1 width=38) (actual time=0.007..0.010 rows=0 loops=1)
                                       Output: nation.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                       Hash Cond: ((supplier.s_suppkey = lineitem.l_suppkey) AND (supplier.s_nationkey = customer.c_nationkey))
                                       Node 16388: (actual time=48299.194..48697.609 rows=48789 loops=3)
                                         Worker 0: actual time=48300.502..48698.088 rows=47222 loops=1
                                         Worker 1: actual time=48293.061..48694.460 rows=45185 loops=1
                                       Node 16390: (actual time=48327.253..48730.849 rows=48581 loops=3)
                                         Worker 0: actual time=48321.376..48731.052 rows=44885 loops=1
                                         Worker 1: actual time=48328.522..48728.821 rows=51033 loops=1
                                       Node 16387: (actual time=48372.960..48783.960 rows=48076 loops=3)
                                         Worker 0: actual time=48365.454..48782.414 rows=49366 loops=1
                                         Worker 1: actual time=48377.156..48782.962 rows=47504 loops=1
                                       Node 16389: (actual time=48307.836..48754.181 rows=48480 loops=3)
                                         Worker 0: actual time=48300.050..48751.062 rows=51516 loops=1
                                         Worker 1: actual time=48309.099..48752.293 rows=51883 loops=1
                                       Node 16391: (actual time=48318.143..48714.624 rows=48822 loops=3)
                                         Worker 0: actual time=48319.341..48712.281 rows=52068 loops=1
                                         Worker 1: actual time=48319.631..48713.954 rows=48006 loops=1
                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16388: (actual time=0.050..18.145 rows=66745 loops=3)
                                               Worker 0: actual time=0.066..19.415 rows=64245 loops=1
                                               Worker 1: actual time=0.042..15.590 rows=71686 loops=1
                                             Node 16390: (actual time=0.041..16.367 rows=66790 loops=3)
                                               Worker 0: actual time=0.047..15.664 rows=66894 loops=1
                                               Worker 1: actual time=0.053..17.106 rows=67541 loops=1
                                             Node 16387: (actual time=0.065..15.086 rows=66574 loops=3)
                                               Worker 0: actual time=0.048..14.307 rows=69433 loops=1
                                               Worker 1: actual time=0.046..14.187 rows=68070 loops=1
                                             Node 16389: (actual time=0.054..15.991 rows=66657 loops=3)
                                               Worker 0: actual time=0.064..15.614 rows=64030 loops=1
                                               Worker 1: actual time=0.054..16.594 rows=68147 loops=1
                                             Node 16391: (actual time=0.050..16.842 rows=66568 loops=3)
                                               Worker 0: actual time=0.063..16.505 rows=66449 loops=1
                                               Worker 1: actual time=0.041..16.912 rows=67432 loops=1
                                       ->  Parallel Hash  (cost=18166206.51..18166206.51 rows=80 width=50) (actual time=0.004..0.006 rows=0 loops=1)
                                             Output: customer.c_nationkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey, nation.n_name, nation.n_nationkey
                                             Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                             Node 16388: (actual time=48228.214..48228.252 rows=1215875 loops=3)
                                               Worker 0: actual time=48227.038..48227.064 rows=1171745 loops=1
                                               Worker 1: actual time=48227.023..48227.074 rows=1226991 loops=1
                                             Node 16390: (actual time=48259.857..48259.940 rows=1215969 loops=3)
                                               Worker 0: actual time=48258.714..48258.737 rows=1217322 loops=1
                                               Worker 1: actual time=48258.726..48258.749 rows=1246432 loops=1
                                             Node 16387: (actual time=48308.409..48308.434 rows=1212486 loops=3)
                                               Worker 0: actual time=48307.200..48307.220 rows=1207373 loops=1
                                               Worker 1: actual time=48307.218..48307.244 rows=1240564 loops=1
                                             Node 16389: (actual time=48235.629..48235.659 rows=1213250 loops=3)
                                               Worker 0: actual time=48234.389..48234.417 rows=1197590 loops=1
                                               Worker 1: actual time=48234.399..48234.427 rows=1272851 loops=1
                                             Node 16391: (actual time=48243.065..48243.093 rows=1212463 loops=3)
                                               Worker 0: actual time=48241.956..48241.985 rows=1229076 loops=1
                                               Worker 1: actual time=48241.949..48241.973 rows=1219686 loops=1
                                             ->  Cluster Reduce  (cost=17741391.96..18166206.51 rows=80 width=50) (actual time=0.001..0.002 rows=0 loops=1)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                                   Node 16388: (actual time=47182.142..47751.842 rows=1215875 loops=3)
                                                     Worker 0: actual time=47180.963..47748.628 rows=1171745 loops=1
                                                     Worker 1: actual time=47180.958..47748.740 rows=1226991 loops=1
                                                   Node 16390: (actual time=47334.288..47721.262 rows=1215969 loops=3)
                                                     Worker 0: actual time=47333.156..47712.836 rows=1217322 loops=1
                                                     Worker 1: actual time=47333.136..47727.734 rows=1246432 loops=1
                                                   Node 16387: (actual time=47679.109..47808.491 rows=1212486 loops=3)
                                                     Worker 0: actual time=47677.903..47799.846 rows=1207373 loops=1
                                                     Worker 1: actual time=47677.904..47803.667 rows=1240564 loops=1
                                                   Node 16389: (actual time=47323.505..47716.327 rows=1213250 loops=3)
                                                     Worker 0: actual time=47322.265..47705.672 rows=1197590 loops=1
                                                     Worker 1: actual time=47322.257..47714.286 rows=1272851 loops=1
                                                   Node 16391: (actual time=47210.325..47716.521 rows=1212463 loops=3)
                                                     Worker 0: actual time=47209.184..47710.763 rows=1229076 loops=1
                                                     Worker 1: actual time=47209.206..47711.348 rows=1219686 loops=1
                                                   ->  Hash Join  (cost=17741390.96..18166196.51 rows=80 width=50) (never executed)
                                                         Output: customer.c_nationkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey, nation.n_name, nation.n_nationkey
                                                         Inner Unique: true
                                                         Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                         Node 16388: (actual time=42813.464..46233.499 rows=1215849 loops=3)
                                                           Worker 0: actual time=42814.773..46204.729 rows=1177451 loops=1
                                                           Worker 1: actual time=42806.942..46254.741 rows=1235546 loops=1
                                                         Node 16390: (actual time=42889.452..46474.386 rows=1215958 loops=3)
                                                           Worker 0: actual time=42882.876..46533.808 rows=1167131 loops=1
                                                           Worker 1: actual time=42891.032..46443.354 rows=1243916 loops=1
                                                         Node 16387: (actual time=43163.404..46823.061 rows=1212582 loops=3)
                                                           Worker 0: actual time=43165.223..46861.136 rows=1283691 loops=1
                                                           Worker 1: actual time=43165.093..46874.058 rows=1283297 loops=1
                                                         Node 16389: (actual time=42810.982..46571.270 rows=1216360 loops=3)
                                                           Worker 0: actual time=42812.536..46592.725 rows=1277310 loops=1
                                                           Worker 1: actual time=42812.638..46598.588 rows=1263309 loops=1
                                                         Node 16391: (actual time=42808.395..46366.661 rows=1209294 loops=3)
                                                           Worker 0: actual time=42809.893..46493.716 rows=1290814 loops=1
                                                           Worker 1: actual time=42810.166..46218.561 rows=1169930 loops=1
                                                         ->  Parallel Hash Join  (cost=17741386.89..18166190.50 rows=400 width=54) (never executed)
                                                               Output: customer.c_nationkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey, nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                               Hash Cond: (customer.c_custkey = orders.o_custkey)
                                                               Node 16388: (actual time=42813.393..45569.017 rows=6080234 loops=3)
                                                                 Worker 0: actual time=42814.670..45562.719 rows=5864672 loops=1
                                                                 Worker 1: actual time=42806.860..45577.863 rows=6194200 loops=1
                                                               Node 16390: (actual time=42889.392..45810.959 rows=6066732 loops=3)
                                                                 Worker 0: actual time=42882.828..45895.683 rows=5843433 loops=1
                                                                 Worker 1: actual time=42890.942..45765.519 rows=6198503 loops=1
                                                               Node 16387: (actual time=43163.328..46131.899 rows=6063786 loops=3)
                                                                 Worker 0: actual time=43165.137..46161.396 rows=6407466 loops=1
                                                                 Worker 1: actual time=43165.007..46173.816 rows=6415269 loops=1
                                                               Node 16389: (actual time=42810.909..45902.773 rows=6070342 loops=3)
                                                                 Worker 0: actual time=42812.503..45894.065 rows=6371933 loops=1
                                                                 Worker 1: actual time=42812.609..45907.141 rows=6304450 loops=1
                                                               Node 16391: (actual time=42808.315..45703.719 rows=6066978 loops=3)
                                                                 Worker 0: actual time=42809.780..45785.497 rows=6475507 loops=1
                                                                 Worker 1: actual time=42810.081..45575.935 rows=5881815 loops=1
                                                               ->  Hash Join  (cost=5.31..424621.09 rows=50001 width=42) (never executed)
                                                                     Output: customer.c_custkey, customer.c_nationkey, nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                     Inner Unique: true
                                                                     Hash Cond: (customer.c_nationkey = nation.n_nationkey)
                                                                     Node 16388: (actual time=0.223..578.469 rows=1000754 loops=3)
                                                                       Worker 0: actual time=0.242..585.071 rows=968540 loops=1
                                                                       Worker 1: actual time=0.324..574.113 rows=1014017 loops=1
                                                                     Node 16390: (actual time=0.140..574.817 rows=999249 loops=3)
                                                                       Worker 0: actual time=0.104..570.400 rows=1009899 loops=1
                                                                       Worker 1: actual time=0.226..580.832 rows=1002506 loops=1
                                                                     Node 16387: (actual time=0.188..559.180 rows=999485 loops=3)
                                                                       Worker 0: actual time=0.240..555.323 rows=1014190 loops=1
                                                                       Worker 1: actual time=0.230..559.938 rows=1017904 loops=1
                                                                     Node 16389: (actual time=0.185..554.992 rows=1000538 loops=3)
                                                                       Worker 0: actual time=0.350..543.796 rows=1019748 loops=1
                                                                       Worker 1: actual time=0.078..552.638 rows=1008770 loops=1
                                                                     Node 16391: (actual time=0.208..557.683 rows=999974 loops=3)
                                                                       Worker 0: actual time=0.262..551.213 rows=1029785 loops=1
                                                                       Worker 1: actual time=0.259..552.358 rows=1010656 loops=1
                                                                     ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=8) (never executed)
                                                                           Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                                           Remote node: 16389,16387,16390,16388,16391
                                                                           Node 16388: (actual time=0.049..284.043 rows=1000754 loops=3)
                                                                             Worker 0: actual time=0.053..299.412 rows=968540 loops=1
                                                                             Worker 1: actual time=0.066..274.855 rows=1014017 loops=1
                                                                           Node 16390: (actual time=0.044..276.407 rows=999249 loops=3)
                                                                             Worker 0: actual time=0.051..260.391 rows=1009899 loops=1
                                                                             Worker 1: actual time=0.054..284.852 rows=1002506 loops=1
                                                                           Node 16387: (actual time=0.046..254.648 rows=999485 loops=3)
                                                                             Worker 0: actual time=0.062..250.743 rows=1014190 loops=1
                                                                             Worker 1: actual time=0.053..255.315 rows=1017904 loops=1
                                                                           Node 16389: (actual time=0.050..256.107 rows=1000538 loops=3)
                                                                             Worker 0: actual time=0.074..241.282 rows=1019748 loops=1
                                                                             Worker 1: actual time=0.042..245.530 rows=1008770 loops=1
                                                                           Node 16391: (actual time=0.047..259.827 rows=999974 loops=3)
                                                                             Worker 0: actual time=0.054..247.743 rows=1029785 loops=1
                                                                             Worker 1: actual time=0.054..250.498 rows=1010656 loops=1
                                                                     ->  Hash  (cost=5.25..5.25 rows=5 width=34) (never executed)
                                                                           Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                           Node 16388: (actual time=0.057..0.058 rows=25 loops=3)
                                                                             Worker 0: actual time=0.064..0.065 rows=25 loops=1
                                                                             Worker 1: actual time=0.052..0.053 rows=25 loops=1
                                                                           Node 16390: (actual time=0.041..0.042 rows=25 loops=3)
                                                                             Worker 0: actual time=0.031..0.032 rows=25 loops=1
                                                                             Worker 1: actual time=0.052..0.053 rows=25 loops=1
                                                                           Node 16387: (actual time=0.055..0.055 rows=25 loops=3)
                                                                             Worker 0: actual time=0.060..0.061 rows=25 loops=1
                                                                             Worker 1: actual time=0.060..0.061 rows=25 loops=1
                                                                           Node 16389: (actual time=0.062..0.062 rows=25 loops=3)
                                                                             Worker 0: actual time=0.101..0.101 rows=25 loops=1
                                                                             Worker 1: actual time=0.025..0.025 rows=25 loops=1
                                                                           Node 16391: (actual time=0.058..0.059 rows=25 loops=3)
                                                                             Worker 0: actual time=0.063..0.065 rows=25 loops=1
                                                                             Worker 1: actual time=0.061..0.062 rows=25 loops=1
                                                                           ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=34) (never executed)
                                                                                 Output: nation.n_name, nation.n_nationkey, nation.n_regionkey
                                                                                 Remote node: 16387,16388,16389,16390,16391
                                                                                 Node 16388: (actual time=0.040..0.044 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.046..0.050 rows=25 loops=1
                                                                                   Worker 1: actual time=0.038..0.042 rows=25 loops=1
                                                                                 Node 16390: (actual time=0.027..0.030 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.017..0.021 rows=25 loops=1
                                                                                   Worker 1: actual time=0.036..0.040 rows=25 loops=1
                                                                                 Node 16387: (actual time=0.039..0.042 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.043..0.047 rows=25 loops=1
                                                                                   Worker 1: actual time=0.043..0.047 rows=25 loops=1
                                                                                 Node 16389: (actual time=0.045..0.049 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.079..0.083 rows=25 loops=1
                                                                                   Worker 1: actual time=0.013..0.017 rows=25 loops=1
                                                                                 Node 16391: (actual time=0.042..0.046 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.049..0.052 rows=25 loops=1
                                                                                   Worker 1: actual time=0.045..0.048 rows=25 loops=1
                                                               ->  Parallel Hash  (cost=17741256.57..17741256.57 rows=10000 width=20) (never executed)
                                                                     Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey
                                                                     Node 16388: (actual time=41845.226..41845.233 rows=6080234 loops=3)
                                                                       Worker 0: actual time=41844.042..41844.048 rows=5960749 loops=1
                                                                       Worker 1: actual time=41844.056..41844.062 rows=6119160 loops=1
                                                                     Node 16390: (actual time=41868.650..41868.657 rows=6066732 loops=3)
                                                                       Worker 0: actual time=41867.519..41867.523 rows=6175713 loops=1
                                                                       Worker 1: actual time=41867.532..41867.538 rows=6064092 loops=1
                                                                     Node 16387: (actual time=42209.587..42209.593 rows=6063786 loops=3)
                                                                       Worker 0: actual time=42208.390..42208.394 rows=6003195 loops=1
                                                                       Worker 1: actual time=42208.401..42208.406 rows=6080495 loops=1
                                                                     Node 16389: (actual time=41844.611..41844.618 rows=6070342 loops=3)
                                                                       Worker 0: actual time=41843.417..41843.422 rows=6078419 loops=1
                                                                       Worker 1: actual time=41843.391..41843.396 rows=6134162 loops=1
                                                                     Node 16391: (actual time=41844.026..41844.033 rows=6066978 loops=3)
                                                                       Worker 0: actual time=41842.924..41842.930 rows=6101726 loops=1
                                                                       Worker 1: actual time=41842.917..41842.922 rows=6112443 loops=1
                                                                     ->  Cluster Reduce  (cost=3860008.52..17741256.57 rows=10000 width=20) (never executed)
                                                                           Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                                           Node 16388: (actual time=38829.169..39868.372 rows=6080234 loops=3)
                                                                             Worker 0: actual time=38827.998..39858.473 rows=5960749 loops=1
                                                                             Worker 1: actual time=38827.992..39873.306 rows=6119160 loops=1
                                                                           Node 16390: (actual time=38973.844..39835.810 rows=6066732 loops=3)
                                                                             Worker 0: actual time=38972.694..39809.946 rows=6175713 loops=1
                                                                             Worker 1: actual time=38972.695..39849.097 rows=6064092 loops=1
                                                                           Node 16387: (actual time=39654.028..40209.466 rows=6063786 loops=3)
                                                                             Worker 0: actual time=39652.831..40189.438 rows=6003195 loops=1
                                                                             Worker 1: actual time=39652.836..40203.398 rows=6080495 loops=1
                                                                           Node 16389: (actual time=38881.695..39814.977 rows=6070342 loops=3)
                                                                             Worker 0: actual time=38880.470..39801.674 rows=6078419 loops=1
                                                                             Worker 1: actual time=38880.478..39801.972 rows=6134162 loops=1
                                                                           Node 16391: (actual time=38609.713..39811.583 rows=6066978 loops=3)
                                                                             Worker 0: actual time=38608.598..39796.133 rows=6101726 loops=1
                                                                             Worker 1: actual time=38608.588..39803.393 rows=6112443 loops=1
                                                                           ->  Parallel Hash Join  (cost=3860007.52..17740460.57 rows=10000 width=20) (never executed)
                                                                                 Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_suppkey
                                                                                 Inner Unique: true
                                                                                 Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                                 Node 16388: (actual time=21872.009..34802.646 rows=6073134 loops=3)
                                                                                   Worker 0: actual time=21877.650..34428.837 rows=5927320 loops=1
                                                                                   Worker 1: actual time=21876.690..35391.180 rows=6267581 loops=1
                                                                                 Node 16390: (actual time=21668.465..35000.574 rows=6073456 loops=3)
                                                                                   Worker 0: actual time=21673.606..35015.254 rows=5885091 loops=1
                                                                                   Worker 1: actual time=21673.552..35121.853 rows=6200247 loops=1
                                                                                 Node 16387: (actual time=22151.670..35617.282 rows=6064145 loops=3)
                                                                                   Worker 0: actual time=22155.881..36133.628 rows=6426295 loops=1
                                                                                   Worker 1: actual time=22155.870..35385.606 rows=5998793 loops=1
                                                                                 Node 16389: (actual time=21509.982..35135.061 rows=6067161 loops=3)
                                                                                   Worker 0: actual time=21493.815..34519.453 rows=5974912 loops=1
                                                                                   Worker 1: actual time=21512.379..35645.127 rows=6417567 loops=1
                                                                                 Node 16391: (actual time=21438.726..34867.275 rows=6070174 loops=3)
                                                                                   Worker 0: actual time=21444.163..35215.286 rows=6424011 loops=1
                                                                                   Worker 1: actual time=21444.383..34337.794 rows=5884135 loops=1
                                                                                 ->  Parallel Seq Scan on public.lineitem  (cost=0.00..13749196.87 rows=50002358 width=20) (never executed)
                                                                                       Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                                       Node 16388: (actual time=0.073..8806.877 rows=40004963 loops=3)
                                                                                         Worker 0: actual time=0.058..8706.709 rows=40231552 loops=1
                                                                                         Worker 1: actual time=0.116..9029.319 rows=39097731 loops=1
                                                                                       Node 16390: (actual time=0.067..8396.416 rows=40003653 loops=3)
                                                                                         Worker 0: actual time=0.075..8805.603 rows=38562830 loops=1
                                                                                         Worker 1: actual time=0.093..8267.144 rows=41160807 loops=1
                                                                                       Node 16387: (actual time=0.051..8444.541 rows=39999804 loops=3)
                                                                                         Worker 0: actual time=0.054..8163.826 rows=40289972 loops=1
                                                                                         Worker 1: actual time=0.055..8027.284 rows=39480033 loops=1
                                                                                       Node 16389: (actual time=0.052..8554.942 rows=39999542 loops=3)
                                                                                         Worker 0: actual time=0.047..8172.243 rows=40836524 loops=1
                                                                                         Worker 1: actual time=0.054..8206.429 rows=41407151 loops=1
                                                                                       Node 16391: (actual time=0.049..8843.563 rows=40004672 loops=3)
                                                                                         Worker 0: actual time=0.061..8934.883 rows=40058535 loops=1
                                                                                         Worker 1: actual time=0.049..8975.207 rows=40186269 loops=1
                                                                                 ->  Parallel Hash  (cost=3859226.27..3859226.27 rows=62500 width=8) (never executed)
                                                                                       Output: orders.o_custkey, orders.o_orderkey
                                                                                       Node 16388: (actual time=3027.406..3027.406 rows=1518884 loops=3)
                                                                                         Worker 0: actual time=3026.358..3026.359 rows=1563182 loops=1
                                                                                         Worker 1: actual time=3026.356..3026.356 rows=1514972 loops=1
                                                                                       Node 16390: (actual time=3023.688..3023.689 rows=1518449 loops=3)
                                                                                         Worker 0: actual time=3022.679..3022.680 rows=1326516 loops=1
                                                                                         Worker 1: actual time=3022.697..3022.697 rows=1564698 loops=1
                                                                                       Node 16387: (actual time=2959.038..2959.038 rows=1515874 loops=3)
                                                                                         Worker 0: actual time=2957.968..2957.968 rows=1543358 loops=1
                                                                                         Worker 1: actual time=2957.970..2957.970 rows=1542179 loops=1
                                                                                       Node 16389: (actual time=2971.604..2971.605 rows=1516585 loops=3)
                                                                                         Worker 0: actual time=2970.515..2970.515 rows=1528041 loops=1
                                                                                         Worker 1: actual time=2970.514..2970.514 rows=1522877 loops=1
                                                                                       Node 16391: (actual time=2844.860..2844.861 rows=1517147 loops=3)
                                                                                         Worker 0: actual time=2843.852..2843.853 rows=1517251 loops=1
                                                                                         Worker 1: actual time=2843.875..2843.876 rows=1493508 loops=1
                                                                                       ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=8) (never executed)
                                                                                             Output: orders.o_custkey, orders.o_orderkey
                                                                                             Filter: (((orders.o_orderdate)::timestamp without time zone >= '1994-01-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone < '1995-01-01 00:00:00'::timestamp without time zone))
                                                                                             Remote node: 16389,16387,16390,16388,16391
                                                                                             Node 16388: (actual time=0.030..2465.412 rows=1518884 loops=3)
                                                                                               Worker 0: actual time=0.033..2461.053 rows=1563182 loops=1
                                                                                               Worker 1: actual time=0.032..2459.765 rows=1514972 loops=1
                                                                                             Node 16390: (actual time=0.027..2469.274 rows=1518449 loops=3)
                                                                                               Worker 0: actual time=0.025..2508.813 rows=1326516 loops=1
                                                                                               Worker 1: actual time=0.028..2455.901 rows=1564698 loops=1
                                                                                             Node 16387: (actual time=0.033..2380.993 rows=1515874 loops=3)
                                                                                               Worker 0: actual time=0.031..2370.656 rows=1543358 loops=1
                                                                                               Worker 1: actual time=0.034..2368.511 rows=1542179 loops=1
                                                                                             Node 16389: (actual time=0.033..2413.360 rows=1516585 loops=3)
                                                                                               Worker 0: actual time=0.031..2413.085 rows=1528041 loops=1
                                                                                               Worker 1: actual time=0.034..2414.923 rows=1522877 loops=1
                                                                                             Node 16391: (actual time=0.027..2337.230 rows=1517147 loops=3)
                                                                                               Worker 0: actual time=0.023..2330.499 rows=1517251 loops=1
                                                                                               Worker 1: actual time=0.024..2344.099 rows=1493508 loops=1
                                                         ->  Hash  (cost=4.06..4.06 rows=1 width=4) (never executed)
                                                               Output: region.r_regionkey
                                                               Node 16388: (actual time=0.018..0.018 rows=1 loops=3)
                                                                 Worker 0: actual time=0.016..0.017 rows=1 loops=1
                                                                 Worker 1: actual time=0.020..0.020 rows=1 loops=1
                                                               Node 16390: (actual time=0.018..0.018 rows=1 loops=3)
                                                                 Worker 0: actual time=0.013..0.014 rows=1 loops=1
                                                                 Worker 1: actual time=0.015..0.015 rows=1 loops=1
                                                               Node 16387: (actual time=0.022..0.022 rows=1 loops=3)
                                                                 Worker 0: actual time=0.017..0.017 rows=1 loops=1
                                                                 Worker 1: actual time=0.017..0.017 rows=1 loops=1
                                                               Node 16389: (actual time=0.023..0.023 rows=1 loops=3)
                                                                 Worker 0: actual time=0.016..0.017 rows=1 loops=1
                                                                 Worker 1: actual time=0.020..0.020 rows=1 loops=1
                                                               Node 16391: (actual time=0.020..0.021 rows=1 loops=3)
                                                                 Worker 0: actual time=0.018..0.019 rows=1 loops=1
                                                                 Worker 1: actual time=0.019..0.019 rows=1 loops=1
                                                               ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (never executed)
                                                                     Output: region.r_regionkey
                                                                     Filter: (region.r_name = 'ASIA'::bpchar)
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     Node 16388: (actual time=0.013..0.014 rows=1 loops=3)
                                                                       Worker 0: actual time=0.012..0.012 rows=1 loops=1
                                                                       Worker 1: actual time=0.015..0.015 rows=1 loops=1
                                                                     Node 16390: (actual time=0.014..0.014 rows=1 loops=3)
                                                                       Worker 0: actual time=0.011..0.012 rows=1 loops=1
                                                                       Worker 1: actual time=0.012..0.013 rows=1 loops=1
                                                                     Node 16387: (actual time=0.017..0.018 rows=1 loops=3)
                                                                       Worker 0: actual time=0.014..0.014 rows=1 loops=1
                                                                       Worker 1: actual time=0.014..0.014 rows=1 loops=1
                                                                     Node 16389: (actual time=0.017..0.017 rows=1 loops=3)
                                                                       Worker 0: actual time=0.011..0.012 rows=1 loops=1
                                                                       Worker 1: actual time=0.015..0.015 rows=1 loops=1
                                                                     Node 16391: (actual time=0.015..0.016 rows=1 loops=3)
                                                                       Worker 0: actual time=0.015..0.015 rows=1 loops=1
                                                                       Worker 1: actual time=0.015..0.016 rows=1 loops=1
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
               Node 16390: (actual time=14701.931..14703.230 rows=3 loops=1)
               Node 16387: (actual time=15697.674..15699.050 rows=3 loops=1)
               Node 16388: (actual time=15809.244..15810.627 rows=3 loops=1)
               Node 16389: (actual time=15821.352..15822.579 rows=3 loops=1)
               Node 16391: (actual time=15912.555..15914.138 rows=3 loops=1)
               ->  Partial Aggregate  (cost=18124562.39..18124562.40 rows=1 width=32) (actual time=0.008..0.009 rows=1 loops=1)
                     Output: PARTIAL sum((l_extendedprice * l_discount))
                     Node 16390: (actual time=14699.530..14699.530 rows=1 loops=3)
                       Worker 0: actual time=14698.212..14698.212 rows=1 loops=1
                       Worker 1: actual time=14698.673..14698.674 rows=1 loops=1
                     Node 16387: (actual time=15695.567..15695.568 rows=1 loops=3)
                       Worker 0: actual time=15694.633..15694.633 rows=1 loops=1
                       Worker 1: actual time=15694.634..15694.635 rows=1 loops=1
                     Node 16388: (actual time=15807.082..15807.083 rows=1 loops=3)
                       Worker 0: actual time=15806.116..15806.117 rows=1 loops=1
                       Worker 1: actual time=15806.114..15806.115 rows=1 loops=1
                     Node 16389: (actual time=15818.912..15818.913 rows=1 loops=3)
                       Worker 0: actual time=15817.818..15817.818 rows=1 loops=1
                       Worker 1: actual time=15817.817..15817.818 rows=1 loops=1
                     Node 16391: (actual time=15910.294..15910.295 rows=1 loops=3)
                       Worker 0: actual time=15909.272..15909.273 rows=1 loops=1
                       Worker 1: actual time=15909.271..15909.272 rows=1 loops=1
                     ->  Parallel Seq Scan on public.lineitem  (cost=0.00..18124403.13 rows=31850 width=12) (actual time=0.005..0.005 rows=0 loops=1)
                           Output: l_orderkey, l_partkey, l_suppkey, l_linenumber, l_quantity, l_extendedprice, l_discount, l_tax, l_returnflag, l_linestatus, l_shipdate, l_commitdate, l_receiptdate, l_shipinstruct, l_shipmode, l_comment
                           Filter: ((lineitem.l_discount >= 0.05) AND (lineitem.l_discount <= 0.07) AND (lineitem.l_quantity < '24'::numeric) AND ((lineitem.l_shipdate)::timestamp without time zone >= '1994-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < '1995-01-01 00:00:00'::timestamp without time zone))
                           Remote node: 16389,16387,16390,16388,16391
                           Node 16390: (actual time=0.054..14463.833 rows=762128 loops=3)
                             Worker 0: actual time=0.045..14459.059 rows=775659 loops=1
                             Worker 1: actual time=0.067..14463.719 rows=755115 loops=1
                           Node 16387: (actual time=0.040..15461.783 rows=761315 loops=3)
                             Worker 0: actual time=0.045..15461.944 rows=759993 loops=1
                             Worker 1: actual time=0.042..15475.041 rows=715534 loops=1
                           Node 16388: (actual time=0.076..15568.726 rows=761865 loops=3)
                             Worker 0: actual time=0.080..15572.359 rows=751202 loops=1
                             Worker 1: actual time=0.105..15570.478 rows=749991 loops=1
                           Node 16389: (actual time=0.068..15581.678 rows=761418 loops=3)
                             Worker 0: actual time=0.053..15576.254 rows=775316 loops=1
                             Worker 1: actual time=0.051..15572.052 rows=789056 loops=1
                           Node 16391: (actual time=0.070..15672.631 rows=760397 loops=3)
                             Worker 0: actual time=0.082..15676.146 rows=748488 loops=1
                             Worker 1: actual time=0.066..15681.069 rows=728947 loops=1
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
               Node 16390: (actual time=30698.089..30855.841 rows=12 loops=1)
               Node 16391: (actual time=30659.309..30823.034 rows=12 loops=1)
               Node 16387: (actual time=30654.334..30806.736 rows=12 loops=1)
               Node 16388: (actual time=30737.539..30891.508 rows=12 loops=1)
               Node 16389: (actual time=30853.911..31004.764 rows=12 loops=1)
               ->  Partial GroupAggregate  (cost=19983549.39..19983549.42 rows=1 width=92) (actual time=0.013..0.016 rows=0 loops=1)
                     Output: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone)), PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Group Key: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone))
                     Node 16390: (actual time=30692.823..30717.712 rows=4 loops=3)
                       Worker 0: actual time=30688.572..30710.334 rows=4 loops=1
                       Worker 1: actual time=30693.626..30720.202 rows=4 loops=1
                     Node 16391: (actual time=30655.091..30680.573 rows=4 loops=3)
                       Worker 0: actual time=30654.251..30679.926 rows=4 loops=1
                       Worker 1: actual time=30652.394..30676.421 rows=4 loops=1
                     Node 16387: (actual time=30648.688..30673.841 rows=4 loops=3)
                       Worker 0: actual time=30650.283..30678.170 rows=4 loops=1
                       Worker 1: actual time=30649.176..30675.874 rows=4 loops=1
                     Node 16388: (actual time=30731.180..30756.419 rows=4 loops=3)
                       Worker 0: actual time=30727.686..30750.888 rows=4 loops=1
                       Worker 1: actual time=30729.012..30753.308 rows=4 loops=1
                     Node 16389: (actual time=30849.412..30874.612 rows=4 loops=3)
                       Worker 0: actual time=30846.629..30870.012 rows=4 loops=1
                       Worker 1: actual time=30849.616..30876.123 rows=4 loops=1
                     ->  Sort  (cost=19983549.39..19983549.39 rows=1 width=72) (actual time=0.012..0.015 rows=0 loops=1)
                           Output: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone)), lineitem.l_extendedprice, lineitem.l_discount
                           Sort Key: n1.n_name, n2.n_name, (date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone))
                           Sort Method: quicksort  Memory: 25kB
                           Node 16390: (actual time=30683.634..30694.121 rows=38932 loops=3)
                             Worker 0: actual time=30680.384..30689.427 rows=34516 loops=1
                             Worker 1: actual time=30683.808..30695.162 rows=41451 loops=1
                           Node 16391: (actual time=30645.858..30656.984 rows=38982 loops=3)
                             Worker 0: actual time=30644.897..30656.117 rows=39399 loops=1
                             Worker 1: actual time=30643.584..30653.994 rows=36884 loops=1
                           Node 16387: (actual time=30639.638..30650.278 rows=38887 loops=3)
                             Worker 0: actual time=30640.424..30652.370 rows=42914 loops=1
                             Worker 1: actual time=30639.467..30650.952 rows=40960 loops=1
                           Node 16388: (actual time=30722.029..30732.897 rows=38805 loops=3)
                             Worker 0: actual time=30719.198..30729.162 rows=35809 loops=1
                             Worker 1: actual time=30720.261..30730.619 rows=37577 loops=1
                           Node 16389: (actual time=30840.277..30850.955 rows=38898 loops=3)
                             Worker 0: actual time=30838.209..30847.932 rows=36301 loops=1
                             Worker 1: actual time=30840.067..30851.415 rows=40894 loops=1
                           ->  Parallel Hash Join  (cost=19558896.07..19983549.38 rows=1 width=72) (actual time=0.007..0.010 rows=0 loops=1)
                                 Output: n1.n_name, n2.n_name, date_part('year'::text, (lineitem.l_shipdate)::timestamp without time zone), lineitem.l_extendedprice, lineitem.l_discount
                                 Hash Cond: (customer.c_custkey = orders.o_custkey)
                                 Join Filter: (((n1.n_name = 'FRANCE'::bpchar) AND (n2.n_name = 'GERMANY'::bpchar)) OR ((n1.n_name = 'GERMANY'::bpchar) AND (n2.n_name = 'FRANCE'::bpchar)))
                                 Node 16390: (actual time=30313.965..30653.952 rows=38932 loops=3)
                                   Worker 0: actual time=30304.133..30654.333 rows=34516 loops=1
                                   Worker 1: actual time=30317.911..30652.277 rows=41451 loops=1
                                 Node 16391: (actual time=30296.173..30615.793 rows=38982 loops=3)
                                   Worker 0: actual time=30299.559..30614.767 rows=39399 loops=1
                                   Worker 1: actual time=30299.333..30615.177 rows=36884 loops=1
                                 Node 16387: (actual time=30289.115..30610.239 rows=38887 loops=3)
                                   Worker 0: actual time=30277.721..30608.019 rows=42914 loops=1
                                   Worker 1: actual time=30290.500..30608.694 rows=40960 loops=1
                                 Node 16388: (actual time=30324.968..30692.807 rows=38805 loops=3)
                                   Worker 0: actual time=30328.303..30691.983 rows=35809 loops=1
                                   Worker 1: actual time=30328.240..30692.191 rows=37577 loops=1
                                 Node 16389: (actual time=30447.074..30810.835 rows=38898 loops=3)
                                   Worker 0: actual time=30453.760..30810.837 rows=36301 loops=1
                                   Worker 1: actual time=30435.930..30808.890 rows=40894 loops=1
                                 ->  Hash Join  (cost=5.39..424621.17 rows=10000 width=30) (never executed)
                                       Output: customer.c_custkey, n2.n_name
                                       Inner Unique: true
                                       Hash Cond: (customer.c_nationkey = n2.n_nationkey)
                                       Node 16390: (actual time=0.125..397.006 rows=79987 loops=3)
                                         Worker 0: actual time=0.207..395.402 rows=82610 loops=1
                                         Worker 1: actual time=0.091..397.601 rows=78504 loops=1
                                       Node 16391: (actual time=0.203..384.380 rows=80047 loops=3)
                                         Worker 0: actual time=0.244..383.460 rows=84561 loops=1
                                         Worker 1: actual time=0.245..382.850 rows=83561 loops=1
                                       Node 16387: (actual time=0.183..376.457 rows=80052 loops=3)
                                         Worker 0: actual time=0.230..376.314 rows=80896 loops=1
                                         Worker 1: actual time=0.235..375.945 rows=80495 loops=1
                                       Node 16388: (actual time=0.163..391.835 rows=79979 loops=3)
                                         Worker 0: actual time=0.107..389.346 rows=83656 loops=1
                                         Worker 1: actual time=0.293..392.170 rows=81864 loops=1
                                       Node 16389: (actual time=0.220..420.326 rows=79981 loops=3)
                                         Worker 0: actual time=0.190..418.692 rows=83556 loops=1
                                         Worker 1: actual time=0.366..420.886 rows=78052 loops=1
                                       ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=8) (never executed)
                                             Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16390: (actual time=0.044..256.164 rows=999249 loops=3)
                                               Worker 0: actual time=0.048..252.860 rows=1026469 loops=1
                                               Worker 1: actual time=0.059..258.336 rows=983279 loops=1
                                             Node 16391: (actual time=0.062..244.679 rows=999974 loops=3)
                                               Worker 0: actual time=0.069..236.321 rows=1053534 loops=1
                                               Worker 1: actual time=0.069..236.802 rows=1045768 loops=1
                                             Node 16387: (actual time=0.049..237.699 rows=999485 loops=3)
                                               Worker 0: actual time=0.055..236.402 rows=1006521 loops=1
                                               Worker 1: actual time=0.055..236.034 rows=1009618 loops=1
                                             Node 16388: (actual time=0.049..252.218 rows=1000754 loops=3)
                                               Worker 0: actual time=0.057..243.864 rows=1046466 loops=1
                                               Worker 1: actual time=0.068..247.593 rows=1025475 loops=1
                                             Node 16389: (actual time=0.055..279.666 rows=1000538 loops=3)
                                               Worker 0: actual time=0.050..271.913 rows=1045597 loops=1
                                               Worker 1: actual time=0.084..283.298 rows=981585 loops=1
                                       ->  Hash  (cost=5.38..5.38 rows=1 width=30) (never executed)
                                             Output: n2.n_name, n2.n_nationkey
                                             Node 16390: (actual time=0.027..0.028 rows=2 loops=3)
                                               Worker 0: actual time=0.032..0.033 rows=2 loops=1
                                               Worker 1: actual time=0.020..0.021 rows=2 loops=1
                                             Node 16391: (actual time=0.028..0.029 rows=2 loops=3)
                                               Worker 0: actual time=0.025..0.026 rows=2 loops=1
                                               Worker 1: actual time=0.019..0.020 rows=2 loops=1
                                             Node 16387: (actual time=0.030..0.030 rows=2 loops=3)
                                               Worker 0: actual time=0.030..0.030 rows=2 loops=1
                                               Worker 1: actual time=0.028..0.029 rows=2 loops=1
                                             Node 16388: (actual time=0.030..0.031 rows=2 loops=3)
                                               Worker 0: actual time=0.023..0.024 rows=2 loops=1
                                               Worker 1: actual time=0.026..0.027 rows=2 loops=1
                                             Node 16389: (actual time=0.030..0.031 rows=2 loops=3)
                                               Worker 0: actual time=0.023..0.024 rows=2 loops=1
                                               Worker 1: actual time=0.031..0.032 rows=2 loops=1
                                             ->  Seq Scan on public.nation n2  (cost=0.00..5.38 rows=1 width=30) (never executed)
                                                   Output: n2.n_name, n2.n_nationkey
                                                   Filter: ((n2.n_name = 'GERMANY'::bpchar) OR (n2.n_name = 'FRANCE'::bpchar))
                                                   Remote node: 16387,16388,16389,16390,16391
                                                   Node 16390: (actual time=0.020..0.021 rows=2 loops=3)
                                                     Worker 0: actual time=0.022..0.024 rows=2 loops=1
                                                     Worker 1: actual time=0.014..0.015 rows=2 loops=1
                                                   Node 16391: (actual time=0.020..0.022 rows=2 loops=3)
                                                     Worker 0: actual time=0.018..0.019 rows=2 loops=1
                                                     Worker 1: actual time=0.013..0.015 rows=2 loops=1
                                                   Node 16387: (actual time=0.021..0.023 rows=2 loops=3)
                                                     Worker 0: actual time=0.020..0.022 rows=2 loops=1
                                                     Worker 1: actual time=0.019..0.021 rows=2 loops=1
                                                   Node 16388: (actual time=0.020..0.023 rows=2 loops=3)
                                                     Worker 0: actual time=0.015..0.019 rows=2 loops=1
                                                     Worker 1: actual time=0.015..0.018 rows=2 loops=1
                                                   Node 16389: (actual time=0.021..0.023 rows=2 loops=3)
                                                     Worker 0: actual time=0.016..0.018 rows=2 loops=1
                                                     Worker 1: actual time=0.021..0.023 rows=2 loops=1
                                 ->  Parallel Hash  (cost=19558889.68..19558889.68 rows=80 width=46) (actual time=0.004..0.005 rows=0 loops=1)
                                       Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, orders.o_custkey, n1.n_name
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       Node 16390: (actual time=29878.680..29878.690 rows=974548 loops=3)
                                         Worker 0: actual time=29877.239..29877.249 rows=948501 loops=1
                                         Worker 1: actual time=29877.484..29877.493 rows=985385 loops=1
                                       Node 16391: (actual time=29872.129..29872.138 rows=974393 loops=3)
                                         Worker 0: actual time=29870.906..29870.913 rows=995975 loops=1
                                         Worker 1: actual time=29870.906..29870.915 rows=967598 loops=1
                                       Node 16387: (actual time=29872.791..29872.800 rows=973254 loops=3)
                                         Worker 0: actual time=29871.659..29871.667 rows=985182 loops=1
                                         Worker 1: actual time=29871.658..29871.669 rows=1004865 loops=1
                                       Node 16388: (actual time=29892.547..29892.557 rows=975278 loops=3)
                                         Worker 0: actual time=29891.347..29891.355 rows=1015156 loops=1
                                         Worker 1: actual time=29891.343..29891.353 rows=979673 loops=1
                                       Node 16389: (actual time=29984.507..29984.517 rows=975554 loops=3)
                                         Worker 0: actual time=29983.289..29983.297 rows=960052 loops=1
                                         Worker 1: actual time=29983.305..29983.313 rows=982059 loops=1
                                       ->  Cluster Reduce  (cost=16277774.59..19558889.68 rows=80 width=46) (actual time=0.001..0.002 rows=0 loops=1)
                                             Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                             Node 16390: (actual time=26769.363..29541.513 rows=974548 loops=3)
                                               Worker 0: actual time=26767.940..29533.246 rows=948501 loops=1
                                               Worker 1: actual time=26768.144..29543.421 rows=985385 loops=1
                                             Node 16391: (actual time=25924.444..29537.001 rows=974393 loops=3)
                                               Worker 0: actual time=25923.213..29533.896 rows=995975 loops=1
                                               Worker 1: actual time=25923.222..29530.748 rows=967598 loops=1
                                             Node 16387: (actual time=25945.897..29544.193 rows=973254 loops=3)
                                               Worker 0: actual time=25944.763..29539.866 rows=985182 loops=1
                                               Worker 1: actual time=25944.757..29542.072 rows=1004865 loops=1
                                             Node 16388: (actual time=29336.785..29538.165 rows=975278 loops=3)
                                               Worker 0: actual time=29335.577..29531.998 rows=1015156 loops=1
                                               Worker 1: actual time=29335.554..29543.016 rows=979673 loops=1
                                             Node 16389: (actual time=29520.419..29620.421 rows=975554 loops=3)
                                               Worker 0: actual time=29519.205..29613.444 rows=960052 loops=1
                                               Worker 1: actual time=29519.211..29614.655 rows=982059 loops=1
                                             ->  Parallel Hash Join  (cost=16277773.59..19558879.68 rows=80 width=46) (never executed)
                                                   Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, orders.o_custkey, n1.n_name
                                                   Hash Cond: (orders.o_orderkey = lineitem.l_orderkey)
                                                   Node 16390: (actual time=22725.601..26053.992 rows=975214 loops=3)
                                                     Worker 0: actual time=22728.527..26112.208 rows=915784 loops=1
                                                     Worker 1: actual time=22729.526..26027.715 rows=1006771 loops=1
                                                   Node 16391: (actual time=21835.014..25317.556 rows=973773 loops=3)
                                                     Worker 0: actual time=21838.448..25374.499 rows=959061 loops=1
                                                     Worker 1: actual time=21824.945..25363.340 rows=957423 loops=1
                                                   Node 16387: (actual time=21975.093..25269.327 rows=974916 loops=3)
                                                     Worker 0: actual time=21964.392..25274.231 rows=1017545 loops=1
                                                     Worker 1: actual time=21978.597..25287.510 rows=1014713 loops=1
                                                   Node 16388: (actual time=25172.901..28487.649 rows=974728 loops=3)
                                                     Worker 0: actual time=25175.968..28332.615 rows=920910 loops=1
                                                     Worker 1: actual time=25175.605..28634.172 rows=1026835 loops=1
                                                   Node 16389: (actual time=25202.756..28655.472 rows=974396 loops=3)
                                                     Worker 0: actual time=25206.425..28601.686 rows=949682 loops=1
                                                     Worker 1: actual time=25190.951..28652.423 rows=950942 loops=1
                                                   ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=8) (never executed)
                                                         Output: orders.o_orderkey, orders.o_custkey, orders.o_orderstatus, orders.o_totalprice, orders.o_orderdate, orders.o_orderpriority, orders.o_clerk, orders.o_shippriority, orders.o_comment
                                                         Remote node: 16389,16387,16390,16388,16391
                                                         Node 16390: (actual time=0.042..1910.080 rows=9999806 loops=3)
                                                           Worker 0: actual time=0.055..2021.597 rows=9310876 loops=1
                                                           Worker 1: actual time=0.044..1866.128 rows=10320477 loops=1
                                                         Node 16391: (actual time=0.039..1971.919 rows=10000065 loops=3)
                                                           Worker 0: actual time=0.055..1852.185 rows=10481583 loops=1
                                                           Worker 1: actual time=0.032..1796.271 rows=10129299 loops=1
                                                         Node 16387: (actual time=0.042..1892.927 rows=9998956 loops=3)
                                                           Worker 0: actual time=0.048..1886.205 rows=10208073 loops=1
                                                           Worker 1: actual time=0.046..1899.772 rows=10193155 loops=1
                                                         Node 16388: (actual time=0.050..2071.925 rows=10001059 loops=3)
                                                           Worker 0: actual time=0.059..2022.914 rows=10026318 loops=1
                                                           Worker 1: actual time=0.055..2032.146 rows=9948630 loops=1
                                                         Node 16389: (actual time=0.045..2173.891 rows=10000114 loops=3)
                                                           Worker 0: actual time=0.047..2176.620 rows=10146464 loops=1
                                                           Worker 1: actual time=0.055..2207.037 rows=10239592 loops=1
                                                   ->  Parallel Hash  (cost=16277768.59..16277768.59 rows=400 width=46) (never executed)
                                                         Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_orderkey, n1.n_name
                                                         Node 16390: (actual time=18376.639..18376.643 rows=975214 loops=3)
                                                           Worker 0: actual time=18375.171..18375.175 rows=799044 loops=1
                                                           Worker 1: actual time=18375.458..18375.462 rows=1062270 loops=1
                                                         Node 16391: (actual time=17327.648..17327.651 rows=973773 loops=3)
                                                           Worker 0: actual time=17326.410..17326.413 rows=988849 loops=1
                                                           Worker 1: actual time=17326.426..17326.430 rows=985174 loops=1
                                                         Node 16387: (actual time=17678.043..17678.047 rows=974916 loops=3)
                                                           Worker 0: actual time=17676.895..17676.898 rows=964276 loops=1
                                                           Worker 1: actual time=17676.899..17676.903 rows=996284 loops=1
                                                         Node 16388: (actual time=20652.227..20652.231 rows=974728 loops=3)
                                                           Worker 0: actual time=20651.021..20651.025 rows=930188 loops=1
                                                           Worker 1: actual time=20651.027..20651.031 rows=897847 loops=1
                                                         Node 16389: (actual time=20396.326..20396.330 rows=974396 loops=3)
                                                           Worker 0: actual time=20395.099..20395.103 rows=909009 loops=1
                                                           Worker 1: actual time=20395.115..20395.119 rows=992228 loops=1
                                                         ->  Parallel Hash Join  (cost=27507.97..16277768.59 rows=400 width=46) (never executed)
                                                               Output: lineitem.l_shipdate, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_orderkey, n1.n_name
                                                               Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                               Node 16390: (actual time=101.146..17777.285 rows=975214 loops=3)
                                                                 Worker 0: actual time=99.679..17841.558 rows=799044 loops=1
                                                                 Worker 1: actual time=99.970..17743.381 rows=1062270 loops=1
                                                               Node 16391: (actual time=87.728..16799.237 rows=973773 loops=3)
                                                                 Worker 0: actual time=86.502..16778.319 rows=988849 loops=1
                                                                 Worker 1: actual time=86.522..16785.628 rows=985174 loops=1
                                                               Node 16387: (actual time=87.519..17131.850 rows=974916 loops=3)
                                                                 Worker 0: actual time=86.366..17158.358 rows=964276 loops=1
                                                                 Worker 1: actual time=86.384..17104.088 rows=996284 loops=1
                                                               Node 16388: (actual time=61.118..20086.660 rows=974728 loops=3)
                                                                 Worker 0: actual time=59.934..20072.052 rows=930188 loops=1
                                                                 Worker 1: actual time=59.900..20148.672 rows=897847 loops=1
                                                               Node 16389: (actual time=98.986..19821.309 rows=974396 loops=3)
                                                                 Worker 0: actual time=97.757..19853.984 rows=909009 loops=1
                                                                 Worker 1: actual time=97.766..19814.085 rows=992228 loops=1
                                                               ->  Parallel Seq Scan on public.lineitem  (cost=0.00..16249314.73 rows=250012 width=24) (never executed)
                                                                     Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                     Filter: (((lineitem.l_shipdate)::timestamp without time zone >= '1995-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone <= '1996-12-31 00:00:00'::timestamp without time zone))
                                                                     Remote node: 16389,16387,16390,16388,16391
                                                                     Node 16390: (actual time=0.041..11738.145 rows=12152494 loops=3)
                                                                       Worker 0: actual time=0.048..10763.136 rows=9964350 loops=1
                                                                       Worker 1: actual time=0.048..12303.083 rows=13226820 loops=1
                                                                     Node 16391: (actual time=0.037..11519.233 rows=12151319 loops=3)
                                                                       Worker 0: actual time=0.042..11460.721 rows=12337612 loops=1
                                                                       Worker 1: actual time=0.044..11420.414 rows=12290723 loops=1
                                                                     Node 16387: (actual time=0.037..11530.835 rows=12156534 loops=3)
                                                                       Worker 0: actual time=0.040..11443.108 rows=12024005 loops=1
                                                                       Worker 1: actual time=0.047..11582.189 rows=12420197 loops=1
                                                                     Node 16388: (actual time=0.037..12194.166 rows=12151437 loops=3)
                                                                       Worker 0: actual time=0.044..11758.139 rows=11614645 loops=1
                                                                       Worker 1: actual time=0.042..11750.078 rows=11173813 loops=1
                                                                     Node 16389: (actual time=0.039..12547.421 rows=12155279 loops=3)
                                                                       Worker 0: actual time=0.043..11295.017 rows=11342034 loops=1
                                                                       Worker 1: actual time=0.045..12907.205 rows=12380647 loops=1
                                                               ->  Parallel Hash  (cost=27466.28..27466.28 rows=3335 width=30) (never executed)
                                                                     Output: supplier.s_suppkey, n1.n_name
                                                                     Node 16390: (actual time=101.065..101.067 rows=26724 loops=3)
                                                                       Worker 0: actual time=99.613..99.615 rows=20754 loops=1
                                                                       Worker 1: actual time=99.880..99.882 rows=29513 loops=1
                                                                     Node 16391: (actual time=87.662..87.664 rows=26724 loops=3)
                                                                       Worker 0: actual time=86.436..86.437 rows=27056 loops=1
                                                                       Worker 1: actual time=86.442..86.443 rows=27239 loops=1
                                                                     Node 16387: (actual time=87.455..87.457 rows=26724 loops=3)
                                                                       Worker 0: actual time=86.306..86.308 rows=27868 loops=1
                                                                       Worker 1: actual time=86.314..86.316 rows=26409 loops=1
                                                                     Node 16388: (actual time=61.042..61.044 rows=26724 loops=3)
                                                                       Worker 0: actual time=59.837..59.839 rows=30135 loops=1
                                                                       Worker 1: actual time=59.842..59.844 rows=30100 loops=1
                                                                     Node 16389: (actual time=98.917..98.918 rows=26724 loops=3)
                                                                       Worker 0: actual time=97.699..97.701 rows=29428 loops=1
                                                                       Worker 1: actual time=97.698..97.700 rows=30807 loops=1
                                                                     ->  Cluster Reduce  (cost=6.39..27466.28 rows=3335 width=30) (never executed)
                                                                           Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                           Node 16390: (actual time=30.311..70.035 rows=26724 loops=3)
                                                                             Worker 0: actual time=28.848..68.157 rows=20754 loops=1
                                                                             Worker 1: actual time=29.129..68.910 rows=29513 loops=1
                                                                           Node 16391: (actual time=29.472..71.987 rows=26724 loops=3)
                                                                             Worker 0: actual time=28.226..70.725 rows=27056 loops=1
                                                                             Worker 1: actual time=28.236..70.826 rows=27239 loops=1
                                                                           Node 16387: (actual time=26.219..71.571 rows=26724 loops=3)
                                                                             Worker 0: actual time=25.065..70.529 rows=27868 loops=1
                                                                             Worker 1: actual time=25.068..70.428 rows=26409 loops=1
                                                                           Node 16388: (actual time=31.264..33.641 rows=26724 loops=3)
                                                                             Worker 0: actual time=30.055..32.656 rows=30135 loops=1
                                                                             Worker 1: actual time=30.058..32.648 rows=30100 loops=1
                                                                           Node 16389: (actual time=28.985..69.714 rows=26724 loops=3)
                                                                             Worker 0: actual time=27.756..68.666 rows=29428 loops=1
                                                                             Worker 1: actual time=27.757..68.717 rows=30807 loops=1
                                                                           ->  Hash Join  (cost=5.39..26607.88 rows=667 width=30) (never executed)
                                                                                 Output: supplier.s_suppkey, n1.n_name
                                                                                 Inner Unique: true
                                                                                 Hash Cond: (supplier.s_nationkey = n1.n_nationkey)
                                                                                 Node 16390: (actual time=0.059..25.700 rows=5328 loops=3)
                                                                                   Worker 0: actual time=0.058..23.855 rows=4928 loops=1
                                                                                   Worker 1: actual time=0.068..25.188 rows=5000 loops=1
                                                                                 Node 16391: (actual time=0.050..24.304 rows=5338 loops=3)
                                                                                   Worker 0: actual time=0.044..23.356 rows=5725 loops=1
                                                                                   Worker 1: actual time=0.056..23.197 rows=5772 loops=1
                                                                                 Node 16387: (actual time=0.051..21.626 rows=5345 loops=3)
                                                                                   Worker 0: actual time=0.055..20.762 rows=5084 loops=1
                                                                                   Worker 1: actual time=0.055..20.901 rows=4994 loops=1
                                                                                 Node 16388: (actual time=0.055..24.702 rows=5375 loops=3)
                                                                                   Worker 0: actual time=0.057..23.085 rows=4994 loops=1
                                                                                   Worker 1: actual time=0.055..23.274 rows=5205 loops=1
                                                                                 Node 16389: (actual time=0.062..24.480 rows=5337 loops=3)
                                                                                   Worker 0: actual time=0.064..23.853 rows=5114 loops=1
                                                                                   Worker 1: actual time=0.066..23.929 rows=5095 loops=1
                                                                                 ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                                       Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                                       Node 16390: (actual time=0.025..16.237 rows=66790 loops=3)
                                                                                         Worker 0: actual time=0.025..14.960 rows=62837 loops=1
                                                                                         Worker 1: actual time=0.032..16.305 rows=63093 loops=1
                                                                                       Node 16391: (actual time=0.020..13.834 rows=66568 loops=3)
                                                                                         Worker 0: actual time=0.020..13.233 rows=71701 loops=1
                                                                                         Worker 1: actual time=0.025..13.163 rows=71348 loops=1
                                                                                       Node 16387: (actual time=0.020..12.357 rows=66574 loops=3)
                                                                                         Worker 0: actual time=0.022..12.021 rows=62614 loops=1
                                                                                         Worker 1: actual time=0.026..12.081 rows=63175 loops=1
                                                                                       Node 16388: (actual time=0.021..14.882 rows=66745 loops=3)
                                                                                         Worker 0: actual time=0.022..13.582 rows=62139 loops=1
                                                                                         Worker 1: actual time=0.024..13.735 rows=63022 loops=1
                                                                                       Node 16389: (actual time=0.025..15.007 rows=66657 loops=3)
                                                                                         Worker 0: actual time=0.029..14.902 rows=63128 loops=1
                                                                                         Worker 1: actual time=0.033..14.914 rows=63511 loops=1
                                                                                 ->  Hash  (cost=5.38..5.38 rows=1 width=30) (never executed)
                                                                                       Output: n1.n_name, n1.n_nationkey
                                                                                       Node 16390: (actual time=0.022..0.023 rows=2 loops=3)
                                                                                         Worker 0: actual time=0.019..0.020 rows=2 loops=1
                                                                                         Worker 1: actual time=0.024..0.025 rows=2 loops=1
                                                                                       Node 16391: (actual time=0.020..0.021 rows=2 loops=3)
                                                                                         Worker 0: actual time=0.015..0.016 rows=2 loops=1
                                                                                         Worker 1: actual time=0.020..0.020 rows=2 loops=1
                                                                                       Node 16387: (actual time=0.020..0.021 rows=2 loops=3)
                                                                                         Worker 0: actual time=0.020..0.020 rows=2 loops=1
                                                                                         Worker 1: actual time=0.018..0.019 rows=2 loops=1
                                                                                       Node 16388: (actual time=0.022..0.023 rows=2 loops=3)
                                                                                         Worker 0: actual time=0.019..0.019 rows=2 loops=1
                                                                                         Worker 1: actual time=0.023..0.024 rows=2 loops=1
                                                                                       Node 16389: (actual time=0.025..0.025 rows=2 loops=3)
                                                                                         Worker 0: actual time=0.022..0.023 rows=2 loops=1
                                                                                         Worker 1: actual time=0.020..0.021 rows=2 loops=1
                                                                                       ->  Seq Scan on public.nation n1  (cost=0.00..5.38 rows=1 width=30) (never executed)
                                                                                             Output: n1.n_name, n1.n_nationkey
                                                                                             Filter: ((n1.n_name = 'FRANCE'::bpchar) OR (n1.n_name = 'GERMANY'::bpchar))
                                                                                             Remote node: 16387,16388,16389,16390,16391
                                                                                             Node 16390: (actual time=0.017..0.018 rows=2 loops=3)
                                                                                               Worker 0: actual time=0.016..0.017 rows=2 loops=1
                                                                                               Worker 1: actual time=0.019..0.020 rows=2 loops=1
                                                                                             Node 16391: (actual time=0.015..0.016 rows=2 loops=3)
                                                                                               Worker 0: actual time=0.012..0.013 rows=2 loops=1
                                                                                               Worker 1: actual time=0.014..0.015 rows=2 loops=1
                                                                                             Node 16387: (actual time=0.014..0.016 rows=2 loops=3)
                                                                                               Worker 0: actual time=0.014..0.015 rows=2 loops=1
                                                                                               Worker 1: actual time=0.013..0.014 rows=2 loops=1
                                                                                             Node 16388: (actual time=0.013..0.018 rows=2 loops=3)
                                                                                               Worker 0: actual time=0.012..0.015 rows=2 loops=1
                                                                                               Worker 1: actual time=0.013..0.021 rows=2 loops=1
                                                                                             Node 16389: (actual time=0.017..0.019 rows=2 loops=3)
                                                                                               Worker 0: actual time=0.016..0.018 rows=2 loops=1
                                                                                               Worker 1: actual time=0.014..0.016 rows=2 loops=1
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
                                                                                                                                                                                           
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 Finalize GroupAggregate  (cost=18708615.69..18708616.09 rows=1 width=40) (actual time=80033.082..80033.106 rows=2 loops=1)
   Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), ((sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END))::numeric / sum((lineitem.l_extended
price * ('1'::numeric - lineitem.l_discount))))
   Group Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
   ->  Cluster Merge Gather  (cost=18708615.69..18708615.97 rows=10 width=40) (actual time=80033.048..80033.060 rows=30 loops=1)
         Remote node: 16387,16388,16389,16390,16391
         Sort Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
         ->  Gather Merge  (cost=18707615.49..18707615.77 rows=2 width=48) (actual time=0.304..0.308 rows=0 loops=1)
               Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), (PARTIAL sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END)), (PARTIAL sum((l
ineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
               Workers Planned: 2
               Workers Launched: 0
               Node 16390: (actual time=78443.694..79796.481 rows=6 loops=1)
               Node 16391: (actual time=78480.350..79963.102 rows=6 loops=1)
               Node 16387: (actual time=78431.072..79560.196 rows=6 loops=1)
               Node 16388: (actual time=78498.753..79613.320 rows=6 loops=1)
               Node 16389: (actual time=78505.000..80032.530 rows=6 loops=1)
               ->  Partial GroupAggregate  (cost=18706615.47..18706615.51 rows=1 width=48) (actual time=0.303..0.306 rows=0 loops=1)
                     Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), PARTIAL sum(CASE WHEN (n2.n_name = 'BRAZIL'::bpchar) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END), PARTIAL sum
((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Group Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                     Node 16390: (actual time=78439.899..78445.088 rows=2 loops=3)
                       Worker 0: actual time=78438.568..78443.446 rows=2 loops=1
                       Worker 1: actual time=78438.759..78444.089 rows=2 loops=1
                     Node 16391: (actual time=78476.517..78481.709 rows=2 loops=3)
                       Worker 0: actual time=78474.964..78479.909 rows=2 loops=1
                       Worker 1: actual time=78475.550..78480.995 rows=2 loops=1
                     Node 16387: (actual time=78427.377..78432.528 rows=2 loops=3)
                       Worker 0: actual time=78426.481..78432.088 rows=2 loops=1
                       Worker 1: actual time=78425.624..78430.351 rows=2 loops=1
                     Node 16388: (actual time=78495.087..78500.191 rows=2 loops=3)
                       Worker 0: actual time=78494.070..78499.211 rows=2 loops=1
                       Worker 1: actual time=78493.631..78498.513 rows=2 loops=1
                     Node 16389: (actual time=78500.808..78505.995 rows=2 loops=3)
                       Worker 0: actual time=78500.457..78506.241 rows=2 loops=1
                       Worker 1: actual time=78499.492..78504.628 rows=2 loops=1
                     ->  Sort  (cost=18706615.47..18706615.47 rows=1 width=46) (actual time=0.302..0.305 rows=0 loops=1)
                           Output: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), n2.n_name, lineitem.l_extendedprice, lineitem.l_discount
                           Sort Key: (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                           Sort Method: quicksort  Memory: 25kB
                           Node 16390: (actual time=78434.714..78435.978 rows=16381 loops=3)
                             Worker 0: actual time=78433.516..78434.722 rows=15539 loops=1
                             Worker 1: actual time=78433.329..78434.642 rows=16996 loops=1
                           Node 16391: (actual time=78471.404..78472.631 rows=16290 loops=3)
                             Worker 0: actual time=78470.018..78471.186 rows=15704 loops=1
                             Worker 1: actual time=78470.151..78471.437 rows=17114 loops=1
                           Node 16387: (actual time=78422.168..78423.416 rows=16355 loops=3)
                             Worker 0: actual time=78420.828..78422.176 rows=17821 loops=1
                             Worker 1: actual time=78420.927..78421.983 rows=15067 loops=1
                           Node 16388: (actual time=78489.961..78491.136 rows=16251 loops=3)
                             Worker 0: actual time=78488.896..78490.070 rows=16435 loops=1
                             Worker 1: actual time=78488.622..78489.776 rows=15664 loops=1
                           Node 16389: (actual time=78495.697..78496.932 rows=16331 loops=3)
                             Worker 0: actual time=78494.766..78496.059 rows=18457 loops=1
                             Worker 1: actual time=78494.378..78495.584 rows=16261 loops=1
                           ->  Hash Join  (cost=18281812.16..18706615.46 rows=1 width=46) (actual time=0.293..0.296 rows=0 loops=1)
                                 Output: date_part('year'::text, (orders.o_orderdate)::timestamp without time zone), n2.n_name, lineitem.l_extendedprice, lineitem.l_discount
                                 Inner Unique: true
                                 Hash Cond: (n1.n_regionkey = region.r_regionkey)
                                 Node 16390: (actual time=78207.572..78430.934 rows=16381 loops=3)
                                   Worker 0: actual time=78209.134..78429.862 rows=15539 loops=1
                                   Worker 1: actual time=78209.186..78429.303 rows=16996 loops=1
                                 Node 16391: (actual time=78245.977..78467.728 rows=16290 loops=3)
                                   Worker 0: actual time=78239.833..78466.550 rows=15704 loops=1
                                   Worker 1: actual time=78247.088..78466.170 rows=17114 loops=1
                                 Node 16387: (actual time=78183.672..78418.515 rows=16355 loops=3)
                                   Worker 0: actual time=78184.040..78416.789 rows=17821 loops=1
                                   Worker 1: actual time=78187.324..78417.526 rows=15067 loops=1
                                 Node 16388: (actual time=78253.371..78486.356 rows=16251 loops=3)
                                   Worker 0: actual time=78255.264..78485.268 rows=16435 loops=1
                                   Worker 1: actual time=78254.462..78485.140 rows=15664 loops=1
                                 Node 16389: (actual time=78240.628..78491.870 rows=16331 loops=3)
                                   Worker 0: actual time=78242.429..78490.524 rows=18457 loops=1
                                   Worker 1: actual time=78242.705..78490.181 rows=16261 loops=1
                                 ->  Parallel Hash Join  (cost=18281808.08..18706611.37 rows=1 width=46) (never executed)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, n1.n_regionkey, n2.n_name
                                       Hash Cond: (customer.c_custkey = orders.o_custkey)
                                       Node 16390: (actual time=78207.494..78419.537 rows=81427 loops=3)
                                         Worker 0: actual time=78209.054..78419.090 rows=76926 loops=1
                                         Worker 1: actual time=78209.064..78417.515 rows=84268 loops=1
                                       Node 16391: (actual time=78245.898..78456.346 rows=81699 loops=3)
                                         Worker 0: actual time=78239.723..78455.596 rows=78721 loops=1
                                         Worker 1: actual time=78247.008..78454.315 rows=85250 loops=1
                                       Node 16387: (actual time=78183.590..78407.190 rows=81479 loops=3)
                                         Worker 0: actual time=78183.936..78404.452 rows=88678 loops=1
                                         Worker 1: actual time=78187.220..78407.091 rows=74951 loops=1
                                       Node 16388: (actual time=78253.278..78475.067 rows=81384 loops=3)
                                         Worker 0: actual time=78255.148..78473.956 rows=81395 loops=1
                                         Worker 1: actual time=78254.339..78474.237 rows=78666 loops=1
                                       Node 16389: (actual time=78240.493..78480.442 rows=81375 loops=3)
                                         Worker 0: actual time=78242.248..78477.639 rows=91767 loops=1
                                         Worker 1: actual time=78242.608..78478.807 rows=80943 loops=1
                                       ->  Hash Join  (cost=5.31..424621.09 rows=50001 width=8) (never executed)
                                             Output: customer.c_custkey, n1.n_regionkey
                                             Inner Unique: true
                                             Hash Cond: (customer.c_nationkey = n1.n_nationkey)
                                             Node 16390: (actual time=0.177..517.506 rows=999249 loops=3)
                                               Worker 0: actual time=0.216..514.183 rows=1012079 loops=1
                                               Worker 1: actual time=0.233..514.739 rows=1013768 loops=1
                                             Node 16391: (actual time=0.138..556.781 rows=999974 loops=3)
                                               Worker 0: actual time=0.248..565.122 rows=955292 loops=1
                                               Worker 1: actual time=0.081..552.995 rows=1020587 loops=1
                                             Node 16387: (actual time=0.206..511.713 rows=999485 loops=3)
                                               Worker 0: actual time=0.281..511.407 rows=1000555 loops=1
                                               Worker 1: actual time=0.261..511.963 rows=1000361 loops=1
                                             Node 16388: (actual time=0.200..557.638 rows=1000754 loops=3)
                                               Worker 0: actual time=0.253..553.252 rows=1022390 loops=1
                                               Worker 1: actual time=0.247..560.661 rows=981974 loops=1
                                             Node 16389: (actual time=0.195..531.111 rows=1000538 loops=3)
                                               Worker 0: actual time=0.215..528.193 rows=1020493 loops=1
                                               Worker 1: actual time=0.293..526.674 rows=1022188 loops=1
                                             ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=8) (never executed)
                                                   Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                   Remote node: 16389,16387,16390,16388,16391
                                                   Node 16390: (actual time=0.045..243.593 rows=999249 loops=3)
                                                     Worker 0: actual time=0.050..236.324 rows=1012079 loops=1
                                                     Worker 1: actual time=0.053..237.675 rows=1013768 loops=1
                                                   Node 16391: (actual time=0.043..279.198 rows=999974 loops=3)
                                                     Worker 0: actual time=0.062..295.784 rows=955292 loops=1
                                                     Worker 1: actual time=0.041..270.505 rows=1020587 loops=1
                                                   Node 16387: (actual time=0.045..237.326 rows=999485 loops=3)
                                                     Worker 0: actual time=0.053..237.020 rows=1000555 loops=1
                                                     Worker 1: actual time=0.056..238.274 rows=1000361 loops=1
                                                   Node 16388: (actual time=0.040..279.190 rows=1000754 loops=3)
                                                     Worker 0: actual time=0.053..259.877 rows=1022390 loops=1
                                                     Worker 1: actual time=0.033..291.217 rows=981974 loops=1
                                                   Node 16389: (actual time=0.053..253.828 rows=1000538 loops=3)
                                                     Worker 0: actual time=0.059..243.980 rows=1020493 loops=1
                                                     Worker 1: actual time=0.074..241.343 rows=1022188 loops=1
                                             ->  Hash  (cost=5.25..5.25 rows=5 width=8) (never executed)
                                                   Output: n1.n_nationkey, n1.n_regionkey
                                                   Node 16390: (actual time=0.044..0.045 rows=25 loops=3)
                                                     Worker 0: actual time=0.049..0.050 rows=25 loops=1
                                                     Worker 1: actual time=0.046..0.046 rows=25 loops=1
                                                   Node 16391: (actual time=0.041..0.041 rows=25 loops=3)
                                                     Worker 0: actual time=0.058..0.059 rows=25 loops=1
                                                     Worker 1: actual time=0.019..0.020 rows=25 loops=1
                                                   Node 16387: (actual time=0.047..0.048 rows=25 loops=3)
                                                     Worker 0: actual time=0.047..0.047 rows=25 loops=1
                                                     Worker 1: actual time=0.055..0.056 rows=25 loops=1
                                                   Node 16388: (actual time=0.051..0.052 rows=25 loops=3)
                                                     Worker 0: actual time=0.054..0.055 rows=25 loops=1
                                                     Worker 1: actual time=0.052..0.053 rows=25 loops=1
                                                   Node 16389: (actual time=0.050..0.050 rows=25 loops=3)
                                                     Worker 0: actual time=0.045..0.045 rows=25 loops=1
                                                     Worker 1: actual time=0.071..0.071 rows=25 loops=1
                                                   ->  Seq Scan on public.nation n1  (cost=0.00..5.25 rows=5 width=8) (never executed)
                                                         Output: n1.n_nationkey, n1.n_regionkey
                                                         Remote node: 16387,16388,16389,16390,16391
                                                         Node 16390: (actual time=0.032..0.036 rows=25 loops=3)
                                                           Worker 0: actual time=0.036..0.040 rows=25 loops=1
                                                           Worker 1: actual time=0.035..0.039 rows=25 loops=1
                                                         Node 16391: (actual time=0.028..0.032 rows=25 loops=3)
                                                           Worker 0: actual time=0.044..0.048 rows=25 loops=1
                                                           Worker 1: actual time=0.008..0.011 rows=25 loops=1
                                                         Node 16387: (actual time=0.034..0.038 rows=25 loops=3)
                                                           Worker 0: actual time=0.035..0.039 rows=25 loops=1
                                                           Worker 1: actual time=0.041..0.045 rows=25 loops=1
                                                         Node 16388: (actual time=0.039..0.043 rows=25 loops=3)
                                                           Worker 0: actual time=0.041..0.045 rows=25 loops=1
                                                           Worker 1: actual time=0.040..0.044 rows=25 loops=1
                                                         Node 16389: (actual time=0.037..0.041 rows=25 loops=3)
                                                           Worker 0: actual time=0.033..0.036 rows=25 loops=1
                                                           Worker 1: actual time=0.057..0.060 rows=25 loops=1
                                       ->  Parallel Hash  (cost=18281802.76..18281802.76 rows=1 width=46) (never executed)
                                             Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, orders.o_custkey, n2.n_name
                                             Node 16390: (actual time=77499.725..77499.799 rows=81427 loops=3)
                                               Worker 0: actual time=77498.314..77498.364 rows=81561 loops=1
                                               Worker 1: actual time=77498.362..77498.419 rows=83848 loops=1
                                             Node 16391: (actual time=77498.501..77498.571 rows=81699 loops=3)
                                               Worker 0: actual time=77497.160..77497.217 rows=75013 loops=1
                                               Worker 1: actual time=77497.169..77497.216 rows=85049 loops=1
                                             Node 16387: (actual time=77484.415..77484.499 rows=81479 loops=3)
                                               Worker 0: actual time=77483.146..77483.235 rows=84413 loops=1
                                               Worker 1: actual time=77483.144..77483.190 rows=83995 loops=1
                                             Node 16388: (actual time=77508.701..77508.749 rows=81384 loops=3)
                                               Worker 0: actual time=77507.421..77507.467 rows=71617 loops=1
                                               Worker 1: actual time=77507.428..77507.475 rows=83967 loops=1
                                             Node 16389: (actual time=77516.793..77516.877 rows=81375 loops=3)
                                               Worker 0: actual time=77515.556..77515.604 rows=89061 loops=1
                                               Worker 1: actual time=77515.576..77515.624 rows=89609 loops=1
                                             ->  Cluster Reduce  (cost=17767992.87..18281802.76 rows=1 width=46) (never executed)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                   Node 16390: (actual time=75585.401..77446.083 rows=81427 loops=3)
                                                     Worker 0: actual time=75583.986..77444.573 rows=81561 loops=1
                                                     Worker 1: actual time=75584.038..77444.840 rows=83848 loops=1
                                                   Node 16391: (actual time=74563.077..77446.760 rows=81699 loops=3)
                                                     Worker 0: actual time=74561.747..77445.151 rows=75013 loops=1
                                                     Worker 1: actual time=74561.738..77445.577 rows=85049 loops=1
                                                   Node 16387: (actual time=77408.724..77417.124 rows=81479 loops=3)
                                                     Worker 0: actual time=77407.458..77415.759 rows=84413 loops=1
                                                     Worker 1: actual time=77407.451..77415.682 rows=83995 loops=1
                                                   Node 16388: (actual time=76218.464..77430.045 rows=81384 loops=3)
                                                     Worker 0: actual time=76217.169..77426.987 rows=71617 loops=1
                                                     Worker 1: actual time=76217.179..77429.289 rows=83967 loops=1
                                                   Node 16389: (actual time=76309.227..77440.438 rows=81375 loops=3)
                                                     Worker 0: actual time=76308.004..77439.608 rows=89061 loops=1
                                                     Worker 1: actual time=76307.989..77439.717 rows=89609 loops=1
                                                   ->  Parallel Hash Join  (cost=17767991.87..18281798.68 rows=1 width=46) (never executed)
                                                         Output: lineitem.l_extendedprice, lineitem.l_discount, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                         Hash Cond: (part.p_partkey = lineitem.l_partkey)
                                                         Node 16390: (actual time=72454.989..75520.459 rows=81363 loops=3)
                                                           Worker 0: actual time=72456.349..75519.050 rows=83640 loops=1
                                                           Worker 1: actual time=72448.155..75520.590 rows=74665 loops=1
                                                         Node 16391: (actual time=71357.229..74497.980 rows=81085 loops=3)
                                                           Worker 0: actual time=71350.187..74501.508 rows=74907 loops=1
                                                           Worker 1: actual time=71358.850..74493.043 rows=84078 loops=1
                                                         Node 16387: (actual time=73604.232..77334.547 rows=81701 loops=3)
                                                           Worker 0: actual time=73594.804..77325.924 rows=84716 loops=1
                                                           Worker 1: actual time=73608.048..77327.329 rows=82861 loops=1
                                                         Node 16388: (actual time=72420.723..76147.470 rows=81670 loops=3)
                                                           Worker 0: actual time=72423.090..76140.037 rows=75447 loops=1
                                                           Worker 1: actual time=72422.070..76150.701 rows=79385 loops=1
                                                         Node 16389: (actual time=71996.669..76234.041 rows=81545 loops=3)
                                                           Worker 0: actual time=71998.752..76216.218 rows=86327 loops=1
                                                           Worker 1: actual time=71998.969..76226.063 rows=88239 loops=1
                                                         ->  Parallel Seq Scan on public.part  (cost=0.00..513765.23 rows=11085 width=4) (never executed)
                                                               Output: part.p_partkey, part.p_name, part.p_mfgr, part.p_brand, part.p_type, part.p_size, part.p_container, part.p_retailprice, part.p_comment
                                                               Filter: ((part.p_type)::text = 'ECONOMY ANODIZED STEEL'::text)
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16390: (actual time=0.092..334.524 rows=8948 loops=3)
                                                                 Worker 0: actual time=0.094..329.101 rows=8937 loops=1
                                                                 Worker 1: actual time=0.168..336.701 rows=9075 loops=1
                                                               Node 16391: (actual time=0.047..340.337 rows=8890 loops=3)
                                                                 Worker 0: actual time=0.088..336.096 rows=7540 loops=1
                                                                 Worker 1: actual time=0.032..343.290 rows=9620 loops=1
                                                               Node 16387: (actual time=0.090..1512.044 rows=8969 loops=3)
                                                                 Worker 0: actual time=0.070..1514.125 rows=9465 loops=1
                                                                 Worker 1: actual time=0.145..1513.420 rows=9468 loops=1
                                                               Node 16388: (actual time=0.138..1211.046 rows=8990 loops=3)
                                                                 Worker 0: actual time=0.096..1214.810 rows=9492 loops=1
                                                                 Worker 1: actual time=0.225..1208.391 rows=8706 loops=1
                                                               Node 16389: (actual time=0.086..314.465 rows=8955 loops=3)
                                                                 Worker 0: actual time=0.067..317.581 rows=9987 loops=1
                                                                 Worker 1: actual time=0.158..316.714 rows=9869 loops=1
                                                         ->  Parallel Hash  (cost=17767986.87..17767986.87 rows=400 width=50) (never executed)
                                                               Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                               Node 16390: (actual time=71942.554..71942.590 rows=12149337 loops=3)
                                                                 Worker 0: actual time=71941.132..71941.145 rows=12166054 loops=1
                                                                 Worker 1: actual time=71941.198..71941.212 rows=12022726 loops=1
                                                               Node 16391: (actual time=70883.228..70883.245 rows=12160158 loops=3)
                                                                 Worker 0: actual time=70881.869..70881.892 rows=11962185 loops=1
                                                                 Worker 1: actual time=70881.899..70881.913 rows=12280625 loops=1
                                                               Node 16387: (actual time=71971.198..71971.226 rows=12150477 loops=3)
                                                                 Worker 0: actual time=71969.931..71969.987 rows=12130706 loops=1
                                                                 Worker 1: actual time=71969.918..71969.930 rows=12133798 loops=1
                                                               Node 16388: (actual time=71065.610..71065.625 rows=12155182 loops=3)
                                                                 Worker 0: actual time=71064.333..71064.346 rows=12748498 loops=1
                                                                 Worker 1: actual time=71064.320..71064.333 rows=11601164 loops=1
                                                               Node 16389: (actual time=71552.034..71552.050 rows=12157588 loops=3)
                                                                 Worker 0: actual time=71550.809..71550.822 rows=12251059 loops=1
                                                                 Worker 1: actual time=71550.823..71550.835 rows=12584139 loops=1
                                                               ->  Cluster Reduce  (cost=3886658.99..17767986.87 rows=400 width=50) (never executed)
                                                                     Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_partkey)), 0)]
                                                                     Node 16390: (actual time=65622.202..67008.654 rows=12149337 loops=3)
                                                                       Worker 0: actual time=65620.798..67011.762 rows=12166054 loops=1
                                                                       Worker 1: actual time=65620.831..66976.337 rows=12022726 loops=1
                                                                     Node 16391: (actual time=64647.748..66046.675 rows=12160158 loops=3)
                                                                       Worker 0: actual time=64646.411..66066.155 rows=11962185 loops=1
                                                                       Worker 1: actual time=64646.403..66035.205 rows=12280625 loops=1
                                                                     Node 16387: (actual time=65796.895..67059.458 rows=12150477 loops=3)
                                                                       Worker 0: actual time=65795.626..66992.059 rows=12130706 loops=1
                                                                       Worker 1: actual time=65795.611..66994.669 rows=12133798 loops=1
                                                                     Node 16388: (actual time=64867.794..66196.605 rows=12155182 loops=3)
                                                                       Worker 0: actual time=64866.508..66121.665 rows=12748498 loops=1
                                                                       Worker 1: actual time=64866.512..66189.699 rows=11601164 loops=1
                                                                     Node 16389: (actual time=65228.221..66502.801 rows=12157588 loops=3)
                                                                       Worker 0: actual time=65226.976..66453.225 rows=12251059 loops=1
                                                                       Worker 1: actual time=65227.010..66469.038 rows=12584139 loops=1
                                                                     ->  Parallel Hash Join  (cost=3886657.99..17767952.87 rows=400 width=50) (never executed)
                                                                           Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, orders.o_orderdate, orders.o_custkey, n2.n_name
                                                                           Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                                           Node 16390: (actual time=50236.531..55474.560 rows=12181006 loops=3)
                                                                             Worker 0: actual time=50230.250..55740.840 rows=12811660 loops=1
                                                                             Worker 1: actual time=50237.900..55685.716 rows=12654931 loops=1
                                                                           Node 16391: (actual time=50175.839..55360.934 rows=12134449 loops=3)
                                                                             Worker 0: actual time=50177.213..55453.347 rows=11768655 loops=1
                                                                             Worker 1: actual time=50176.751..55517.497 rows=12639415 loops=1
                                                                           Node 16387: (actual time=50679.496..56066.419 rows=12136730 loops=3)
                                                                             Worker 0: actual time=50672.754..55837.514 rows=12226867 loops=1
                                                                             Worker 1: actual time=50682.143..55713.833 rows=11162944 loops=1
                                                                           Node 16388: (actual time=50212.464..55783.048 rows=12167654 loops=3)
                                                                             Worker 0: actual time=50215.315..56425.881 rows=12945817 loops=1
                                                                             Worker 1: actual time=50205.395..55303.331 rows=11840065 loops=1
                                                                           Node 16389: (actual time=50562.606..56005.710 rows=12152903 loops=3)
                                                                             Worker 0: actual time=50563.899..55272.306 rows=10237687 loops=1
                                                                             Worker 1: actual time=50563.766..56565.099 rows=14154589 loops=1
                                                                           ->  Cluster Reduce  (cost=3860008.52..17741265.57 rows=10000 width=28) (never executed)
                                                                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                                                                 Node 16390: (actual time=45503.814..48318.360 rows=12181006 loops=3)
                                                                                   Worker 0: actual time=45503.802..48315.851 rows=12201661 loops=1
                                                                                   Worker 1: actual time=45503.811..48309.283 rows=12223724 loops=1
                                                                                 Node 16391: (actual time=46163.794..48275.971 rows=12134449 loops=3)
                                                                                   Worker 0: actual time=46163.814..48271.394 rows=12095893 loops=1
                                                                                   Worker 1: actual time=46163.789..48269.224 rows=12098249 loops=1
                                                                                 Node 16387: (actual time=47689.460..48807.622 rows=12136730 loops=3)
                                                                                   Worker 0: actual time=47689.465..48788.231 rows=12268832 loops=1
                                                                                   Worker 1: actual time=47689.462..48788.537 rows=12313413 loops=1
                                                                                 Node 16388: (actual time=47040.684..48296.703 rows=12167654 loops=3)
                                                                                   Worker 0: actual time=47040.688..48255.005 rows=12476722 loops=1
                                                                                   Worker 1: actual time=47040.674..48310.935 rows=12067491 loops=1
                                                                                 Node 16389: (actual time=47517.032..48644.437 rows=12152903 loops=3)
                                                                                   Worker 0: actual time=47517.015..48627.345 rows=12288709 loops=1
                                                                                   Worker 1: actual time=47517.035..48626.061 rows=12337906 loops=1
                                                                                 ->  Parallel Hash Join  (cost=3860007.52..17740460.57 rows=10000 width=28) (never executed)
                                                                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey, lineitem.l_suppkey, orders.o_orderdate, orders.o_custkey
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                                       Node 16390: (actual time=22344.287..36967.456 rows=12154059 loops=3)
                                                                                         Worker 0: actual time=22349.612..36883.337 rows=11950396 loops=1
                                                                                         Worker 1: actual time=22349.734..36915.568 rows=11988732 loops=1
                                                                                       Node 16391: (actual time=23354.529..38023.143 rows=12153470 loops=3)
                                                                                         Worker 0: actual time=23344.085..37973.839 rows=11476483 loops=1
                                                                                         Worker 1: actual time=23359.742..38061.079 rows=12476431 loops=1
                                                                                       Node 16387: (actual time=23453.416..38566.875 rows=12157194 loops=3)
                                                                                         Worker 0: actual time=23459.149..38591.894 rows=12071259 loops=1
                                                                                         Worker 1: actual time=23442.115..37983.286 rows=11380994 loops=1
                                                                                       Node 16388: (actual time=23837.357..38786.220 rows=12151553 loops=3)
                                                                                         Worker 0: actual time=23843.978..39906.947 rows=12799615 loops=1
                                                                                         Worker 1: actual time=23843.748..38138.153 rows=11631489 loops=1
                                                                                       Node 16389: (actual time=23317.952..38798.743 rows=12156468 loops=3)
                                                                                         Worker 0: actual time=23304.696..37036.891 rows=11063072 loops=1
                                                                                         Worker 1: actual time=23324.235..40296.210 rows=13966474 loops=1
                                                                                       ->  Parallel Seq Scan on public.lineitem  (cost=0.00..13749196.87 rows=50002358 width=24) (never executed)
                                                                                             Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem
.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                                             Remote node: 16389,16387,16390,16388,16391
                                                                                             Node 16390: (actual time=0.044..7259.188 rows=40003653 loops=3)
                                                                                               Worker 0: actual time=0.054..6923.664 rows=38653590 loops=1
                                                                                               Worker 1: actual time=0.054..7204.889 rows=40757718 loops=1
                                                                                             Node 16391: (actual time=0.048..8215.173 rows=40004672 loops=3)
                                                                                               Worker 0: actual time=0.051..8655.537 rows=37440441 loops=1
                                                                                               Worker 1: actual time=0.060..7959.868 rows=40950086 loops=1
                                                                                             Node 16387: (actual time=0.051..8159.692 rows=39999804 loops=3)
                                                                                               Worker 0: actual time=0.062..7942.513 rows=40160637 loops=1
                                                                                               Worker 1: actual time=0.070..8497.518 rows=38362976 loops=1
                                                                                             Node 16388: (actual time=0.056..8700.286 rows=40004963 loops=3)
                                                                                               Worker 0: actual time=0.068..8778.483 rows=38168694 loops=1
                                                                                               Worker 1: actual time=0.069..8657.134 rows=40772123 loops=1
                                                                                             Node 16389: (actual time=0.051..8339.102 rows=39999542 loops=3)
                                                                                               Worker 0: actual time=0.056..7950.719 rows=40538445 loops=1
                                                                                               Worker 1: actual time=0.058..7845.811 rows=41807578 loops=1
                                                                                       ->  Parallel Hash  (cost=3859226.27..3859226.27 rows=62500 width=12) (never executed)
                                                                                             Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                             Node 16390: (actual time=3615.300..3615.301 rows=3037277 loops=3)
                                                                                               Worker 0: actual time=3615.452..3615.453 rows=3104522 loops=1
                                                                                               Worker 1: actual time=3615.439..3615.439 rows=2934662 loops=1
                                                                                             Node 16391: (actual time=3673.998..3673.998 rows=3038343 loops=3)
                                                                                               Worker 0: actual time=3674.087..3674.087 rows=2975204 loops=1
                                                                                               Worker 1: actual time=3674.104..3674.105 rows=3063821 loops=1
                                                                                             Node 16387: (actual time=3625.557..3625.558 rows=3039415 loops=3)
                                                                                               Worker 0: actual time=3625.669..3625.670 rows=3097123 loops=1
                                                                                               Worker 1: actual time=3625.338..3625.338 rows=2928869 loops=1
                                                                                             Node 16388: (actual time=3769.995..3769.996 rows=3037541 loops=3)
                                                                                               Worker 0: actual time=3770.106..3770.107 rows=3049598 loops=1
                                                                                               Worker 1: actual time=3769.779..3769.780 rows=3103426 loops=1
                                                                                             Node 16389: (actual time=3869.300..3869.300 rows=3038966 loops=3)
                                                                                               Worker 0: actual time=3869.098..3869.098 rows=3076531 loops=1
                                                                                               Worker 1: actual time=3869.415..3869.416 rows=3058962 loops=1
                                                                                             ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=12) (never executed)
                                                                                                   Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                                   Filter: (((orders.o_orderdate)::timestamp without time zone >= '1995-01-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without ti
me zone <= '1996-12-31 00:00:00'::timestamp without time zone))
                                                                                                   Remote node: 16389,16387,16390,16388,16391
                                                                                                   Node 16390: (actual time=0.033..2633.411 rows=3037277 loops=3)
                                                                                                     Worker 0: actual time=0.036..2620.448 rows=3104522 loops=1
                                                                                                     Worker 1: actual time=0.039..2637.005 rows=2934662 loops=1
                                                                                                   Node 16391: (actual time=0.031..2730.539 rows=3038343 loops=3)
                                                                                                     Worker 0: actual time=0.037..2755.206 rows=2975204 loops=1
                                                                                                     Worker 1: actual time=0.034..2702.920 rows=3063821 loops=1
                                                                                                   Node 16387: (actual time=0.027..2686.199 rows=3039415 loops=3)
                                                                                                     Worker 0: actual time=0.027..2667.228 rows=3097123 loops=1
                                                                                                     Worker 1: actual time=0.030..2708.344 rows=2928869 loops=1
                                                                                                   Node 16388: (actual time=0.032..2773.542 rows=3037541 loops=3)
                                                                                                     Worker 0: actual time=0.034..2760.884 rows=3049598 loops=1
                                                                                                     Worker 1: actual time=0.034..2748.844 rows=3103426 loops=1
                                                                                                   Node 16389: (actual time=0.033..2884.159 rows=3038966 loops=3)
                                                                                                     Worker 0: actual time=0.036..2876.506 rows=3076531 loops=1
                                                                                                     Worker 1: actual time=0.036..2884.022 rows=3058962 loops=1
                                                                           ->  Parallel Hash  (cost=26607.81..26607.81 rows=3333 width=30) (never executed)
                                                                                 Output: supplier.s_suppkey, n2.n_name
                                                                                 Node 16390: (actual time=105.878..105.879 rows=66790 loops=3)
                                                                                   Worker 0: actual time=104.468..104.470 rows=66823 loops=1
                                                                                   Worker 1: actual time=104.511..104.512 rows=59353 loops=1
                                                                                 Node 16391: (actual time=73.781..73.782 rows=66568 loops=3)
                                                                                   Worker 0: actual time=72.438..72.439 rows=63238 loops=1
                                                                                   Worker 1: actual time=72.434..72.436 rows=64844 loops=1
                                                                                 Node 16387: (actual time=74.397..74.398 rows=66574 loops=3)
                                                                                   Worker 0: actual time=73.117..73.119 rows=64871 loops=1
                                                                                   Worker 1: actual time=73.130..73.131 rows=64263 loops=1
                                                                                 Node 16388: (actual time=109.355..109.356 rows=66745 loops=3)
                                                                                   Worker 0: actual time=108.078..108.080 rows=67567 loops=1
                                                                                   Worker 1: actual time=108.071..108.072 rows=67113 loops=1
                                                                                 Node 16389: (actual time=109.351..109.353 rows=66657 loops=3)
                                                                                   Worker 0: actual time=108.132..108.133 rows=67787 loops=1
                                                                                   Worker 1: actual time=108.132..108.134 rows=67689 loops=1
                                                                                 ->  Hash Join  (cost=5.31..26607.81 rows=3333 width=30) (never executed)
                                                                                       Output: supplier.s_suppkey, n2.n_name
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (supplier.s_nationkey = n2.n_nationkey)
                                                                                       Node 16390: (actual time=0.047..34.506 rows=66790 loops=3)
                                                                                         Worker 0: actual time=0.050..35.123 rows=66823 loops=1
                                                                                         Worker 1: actual time=0.054..30.162 rows=59353 loops=1
                                                                                       Node 16391: (actual time=0.045..31.407 rows=66568 loops=3)
                                                                                         Worker 0: actual time=0.047..30.398 rows=63238 loops=1
                                                                                         Worker 1: actual time=0.049..30.823 rows=64844 loops=1
                                                                                       Node 16387: (actual time=0.045..32.050 rows=66574 loops=3)
                                                                                         Worker 0: actual time=0.047..31.277 rows=64871 loops=1
                                                                                         Worker 1: actual time=0.050..31.029 rows=64263 loops=1
                                                                                       Node 16388: (actual time=0.050..33.078 rows=66745 loops=3)
                                                                                         Worker 0: actual time=0.052..32.065 rows=67567 loops=1
                                                                                         Worker 1: actual time=0.053..31.860 rows=67113 loops=1
                                                                                       Node 16389: (actual time=0.047..34.363 rows=66657 loops=3)
                                                                                         Worker 0: actual time=0.047..35.115 rows=67787 loops=1
                                                                                         Worker 1: actual time=0.055..35.022 rows=67689 loops=1
                                                                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                             Remote node: 16389,16387,16390,16388,16391
                                                                                             Node 16390: (actual time=0.021..15.738 rows=66790 loops=3)
                                                                                               Worker 0: actual time=0.023..16.292 rows=66823 loops=1
                                                                                               Worker 1: actual time=0.025..13.384 rows=59353 loops=1
                                                                                             Node 16391: (actual time=0.018..13.054 rows=66568 loops=3)
                                                                                               Worker 0: actual time=0.020..12.993 rows=63238 loops=1
                                                                                               Worker 1: actual time=0.020..12.881 rows=64844 loops=1
                                                                                             Node 16387: (actual time=0.018..13.400 rows=66574 loops=3)
                                                                                               Worker 0: actual time=0.019..13.071 rows=64871 loops=1
                                                                                               Worker 1: actual time=0.022..13.022 rows=64263 loops=1
                                                                                             Node 16388: (actual time=0.023..14.591 rows=66745 loops=3)
                                                                                               Worker 0: actual time=0.025..13.379 rows=67567 loops=1
                                                                                               Worker 1: actual time=0.024..13.264 rows=67113 loops=1
                                                                                             Node 16389: (actual time=0.021..15.822 rows=66657 loops=3)
                                                                                               Worker 0: actual time=0.021..16.322 rows=67787 loops=1
                                                                                               Worker 1: actual time=0.025..16.231 rows=67689 loops=1
                                                                                       ->  Hash  (cost=5.25..5.25 rows=5 width=30) (never executed)
                                                                                             Output: n2.n_name, n2.n_nationkey
                                                                                             Node 16390: (actual time=0.018..0.019 rows=25 loops=3)
                                                                                               Worker 0: actual time=0.017..0.018 rows=25 loops=1
                                                                                               Worker 1: actual time=0.018..0.019 rows=25 loops=1
                                                                                             Node 16391: (actual time=0.017..0.018 rows=25 loops=3)
                                                                                               Worker 0: actual time=0.017..0.017 rows=25 loops=1
                                                                                               Worker 1: actual time=0.019..0.020 rows=25 loops=1
                                                                                             Node 16387: (actual time=0.017..0.018 rows=25 loops=3)
                                                                                               Worker 0: actual time=0.016..0.017 rows=25 loops=1
                                                                                               Worker 1: actual time=0.017..0.018 rows=25 loops=1
                                                                                             Node 16388: (actual time=0.018..0.018 rows=25 loops=3)
                                                                                               Worker 0: actual time=0.016..0.017 rows=25 loops=1
                                                                                               Worker 1: actual time=0.019..0.019 rows=25 loops=1
                                                                                             Node 16389: (actual time=0.018..0.019 rows=25 loops=3)
                                                                                               Worker 0: actual time=0.017..0.018 rows=25 loops=1
                                                                                               Worker 1: actual time=0.020..0.020 rows=25 loops=1
                                                                                             ->  Seq Scan on public.nation n2  (cost=0.00..5.25 rows=5 width=30) (never executed)
                                                                                                   Output: n2.n_name, n2.n_nationkey
                                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                                   Node 16390: (actual time=0.009..0.012 rows=25 loops=3)
                                                                                                     Worker 0: actual time=0.008..0.012 rows=25 loops=1
                                                                                                     Worker 1: actual time=0.009..0.012 rows=25 loops=1
                                                                                                   Node 16391: (actual time=0.008..0.011 rows=25 loops=3)
                                                                                                     Worker 0: actual time=0.007..0.010 rows=25 loops=1
                                                                                                     Worker 1: actual time=0.010..0.013 rows=25 loops=1
                                                                                                   Node 16387: (actual time=0.008..0.011 rows=25 loops=3)
                                                                                                     Worker 0: actual time=0.007..0.010 rows=25 loops=1
                                                                                                     Worker 1: actual time=0.008..0.011 rows=25 loops=1
                                                                                                   Node 16388: (actual time=0.008..0.011 rows=25 loops=3)
                                                                                                     Worker 0: actual time=0.007..0.010 rows=25 loops=1
                                                                                                     Worker 1: actual time=0.009..0.013 rows=25 loops=1
                                                                                                   Node 16389: (actual time=0.009..0.012 rows=25 loops=3)
                                                                                                     Worker 0: actual time=0.008..0.011 rows=25 loops=1
                                                                                                     Worker 1: actual time=0.011..0.014 rows=25 loops=1
                                 ->  Hash  (cost=4.06..4.06 rows=1 width=4) (actual time=0.290..0.290 rows=0 loops=1)
                                       Output: region.r_regionkey
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       Node 16390: (actual time=0.017..0.018 rows=1 loops=3)
                                         Worker 0: actual time=0.017..0.017 rows=1 loops=1
                                         Worker 1: actual time=0.016..0.016 rows=1 loops=1
                                       Node 16391: (actual time=0.020..0.020 rows=1 loops=3)
                                         Worker 0: actual time=0.020..0.020 rows=1 loops=1
                                         Worker 1: actual time=0.020..0.020 rows=1 loops=1
                                       Node 16387: (actual time=0.016..0.017 rows=1 loops=3)
                                         Worker 0: actual time=0.018..0.018 rows=1 loops=1
                                         Worker 1: actual time=0.018..0.018 rows=1 loops=1
                                       Node 16388: (actual time=0.017..0.017 rows=1 loops=3)
                                         Worker 0: actual time=0.016..0.016 rows=1 loops=1
                                         Worker 1: actual time=0.014..0.014 rows=1 loops=1
                                       Node 16389: (actual time=0.019..0.020 rows=1 loops=3)
                                         Worker 0: actual time=0.017..0.018 rows=1 loops=1
                                         Worker 1: actual time=0.019..0.019 rows=1 loops=1
                                       ->  Seq Scan on public.region  (cost=0.00..4.06 rows=1 width=4) (actual time=0.287..0.288 rows=0 loops=1)
                                             Output: region.r_regionkey
                                             Filter: (region.r_name = 'AMERICA'::bpchar)
                                             Remote node: 16387,16388,16389,16390,16391
                                             Node 16390: (actual time=0.013..0.014 rows=1 loops=3)
                                               Worker 0: actual time=0.014..0.015 rows=1 loops=1
                                               Worker 1: actual time=0.013..0.014 rows=1 loops=1
                                             Node 16391: (actual time=0.014..0.015 rows=1 loops=3)
                                               Worker 0: actual time=0.016..0.017 rows=1 loops=1
                                               Worker 1: actual time=0.015..0.016 rows=1 loops=1
                                             Node 16387: (actual time=0.012..0.013 rows=1 loops=3)
                                               Worker 0: actual time=0.014..0.015 rows=1 loops=1
                                               Worker 1: actual time=0.014..0.015 rows=1 loops=1
                                             Node 16388: (actual time=0.012..0.013 rows=1 loops=3)
                                               Worker 0: actual time=0.013..0.014 rows=1 loops=1
                                               Worker 1: actual time=0.011..0.012 rows=1 loops=1
                                             Node 16389: (actual time=0.013..0.014 rows=1 loops=3)
                                               Worker 0: actual time=0.012..0.013 rows=1 loops=1
                                               Worker 1: actual time=0.014..0.015 rows=1 loops=1
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
               Node 16388: (actual time=82982.449..86123.275 rows=525 loops=1)
               Node 16387: (actual time=83478.591..86724.445 rows=525 loops=1)
               Node 16389: (actual time=84457.377..87624.481 rows=525 loops=1)
               Node 16390: (actual time=84968.410..88155.590 rows=525 loops=1)
               Node 16391: (actual time=86682.750..89936.941 rows=525 loops=1)
               ->  Partial GroupAggregate  (cost=19884199.00..19884199.04 rows=1 width=66) (actual time=0.061..0.064 rows=0 loops=1)
                     Output: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), PARTIAL sum(((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)) - (partsupp.ps_supplycost * lineitem.l_quantity)))
                     Group Key: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone))
                     Node 16388: (actual time=82931.977..85407.062 rows=175 loops=3)
                       Worker 0: actual time=82867.066..85232.703 rows=175 loops=1
                       Worker 1: actual time=82947.100..85464.849 rows=175 loops=1
                     Node 16387: (actual time=83432.638..85904.998 rows=175 loops=3)
                       Worker 0: actual time=83474.197..86042.707 rows=175 loops=1
                       Worker 1: actual time=83435.977..85931.016 rows=175 loops=1
                     Node 16389: (actual time=84443.050..86935.403 rows=175 loops=3)
                       Worker 0: actual time=84441.955..86910.734 rows=175 loops=1
                       Worker 1: actual time=84430.528..86894.753 rows=175 loops=1
                     Node 16390: (actual time=84906.365..87383.222 rows=175 loops=3)
                       Worker 0: actual time=84865.099..87276.287 rows=175 loops=1
                       Worker 1: actual time=84886.268..87318.590 rows=175 loops=1
                     Node 16391: (actual time=86624.966..89128.247 rows=175 loops=3)
                       Worker 0: actual time=86639.626..89181.094 rows=175 loops=1
                       Worker 1: actual time=86553.216..88923.124 rows=175 loops=1
                     ->  Sort  (cost=19884199.00..19884199.01 rows=1 width=57) (actual time=0.060..0.063 rows=0 loops=1)
                           Output: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)), lineitem.l_extendedprice, lineitem.l_discount, partsupp.ps_supplycost, lineitem.l_quantity
                           Sort Key: nation.n_name, (date_part('year'::text, (orders.o_orderdate)::timestamp without time zone)) DESC
                           Sort Method: quicksort  Memory: 25kB
                           Node 16388: (actual time=82923.018..83630.674 rows=2176637 loops=3)
                             Worker 0: actual time=82858.495..83539.816 rows=2075033 loops=1
                             Worker 1: actual time=82937.892..83657.618 rows=2214338 loops=1
                           Node 16387: (actual time=83423.696..84132.566 rows=2176187 loops=3)
                             Worker 0: actual time=83464.924..84202.174 rows=2257062 loops=1
                             Worker 1: actual time=83426.934..84144.613 rows=2188984 loops=1
                           Node 16389: (actual time=84433.955..85159.555 rows=2175361 loops=3)
                             Worker 0: actual time=84432.977..85155.767 rows=2151096 loops=1
                             Worker 1: actual time=84421.594..85145.318 rows=2142382 loops=1
                           Node 16390: (actual time=84897.470..85611.244 rows=2175304 loops=3)
                             Worker 0: actual time=84856.419..85549.794 rows=2114852 loops=1
                             Worker 1: actual time=84877.384..85580.833 rows=2141926 loops=1
                           Node 16391: (actual time=86615.961..87352.403 rows=2175360 loops=3)
                             Worker 0: actual time=86630.388..87372.191 rows=2214897 loops=1
                             Worker 1: actual time=86544.788..87251.699 rows=2048999 loops=1
                           ->  Parallel Hash Join  (cost=16603093.21..19884198.99 rows=1 width=57) (actual time=0.050..0.054 rows=0 loops=1)
                                 Output: nation.n_name, date_part('year'::text, (orders.o_orderdate)::timestamp without time zone), lineitem.l_extendedprice, lineitem.l_discount, partsupp.ps_supplycost, lineitem.l_quantity
                                 Hash Cond: (orders.o_orderkey = lineitem.l_orderkey)
                                 Node 16388: (actual time=76169.387..80406.888 rows=2176637 loops=3)
                                   Worker 0: actual time=76163.684..80369.289 rows=2075033 loops=1
                                   Worker 1: actual time=76170.861..80444.150 rows=2214338 loops=1
                                 Node 16387: (actual time=76537.900..80821.944 rows=2176187 loops=3)
                                   Worker 0: actual time=76538.331..80798.547 rows=2257062 loops=1
                                   Worker 1: actual time=76530.321..80756.088 rows=2188984 loops=1
                                 Node 16389: (actual time=77249.906..81633.745 rows=2175361 loops=3)
                                   Worker 0: actual time=77242.272..81574.777 rows=2151096 loops=1
                                   Worker 1: actual time=77252.436..81594.900 rows=2142382 loops=1
                                 Node 16390: (actual time=77730.592..82166.986 rows=2175304 loops=3)
                                   Worker 0: actual time=77725.028..82120.453 rows=2114852 loops=1
                                   Worker 1: actual time=77731.715..82168.719 rows=2141926 loops=1
                                 Node 16391: (actual time=79758.670..83956.537 rows=2175360 loops=3)
                                   Worker 0: actual time=79752.920..83919.353 rows=2214897 loops=1
                                   Worker 1: actual time=79759.970..83976.827 rows=2048999 loops=1
                                 ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=8) (never executed)
                                       Output: orders.o_orderkey, orders.o_custkey, orders.o_orderstatus, orders.o_totalprice, orders.o_orderdate, orders.o_orderpriority, orders.o_clerk, orders.o_shippriority, orders.o_comment
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16388: (actual time=0.061..2159.166 rows=10001059 loops=3)
                                         Worker 0: actual time=0.070..2129.769 rows=9592038 loops=1
                                         Worker 1: actual time=0.062..2083.150 rows=10079975 loops=1
                                       Node 16387: (actual time=0.042..1946.083 rows=9998956 loops=3)
                                         Worker 0: actual time=0.037..1971.901 rows=10166968 loops=1
                                         Worker 1: actual time=0.060..1898.056 rows=9752262 loops=1
                                       Node 16389: (actual time=0.056..2130.731 rows=10000114 loops=3)
                                         Worker 0: actual time=0.061..1858.817 rows=8628868 loops=1
                                         Worker 1: actual time=0.056..2198.002 rows=10327948 loops=1
                                       Node 16390: (actual time=0.048..1702.765 rows=9999806 loops=3)
                                         Worker 0: actual time=0.065..1535.483 rows=9262512 loops=1
                                         Worker 1: actual time=0.044..1644.769 rows=9890942 loops=1
                                       Node 16391: (actual time=0.048..1975.623 rows=10000065 loops=3)
                                         Worker 0: actual time=0.056..1738.935 rows=9324062 loops=1
                                         Worker 1: actual time=0.056..1815.287 rows=9924388 loops=1
                                 ->  Parallel Hash  (cost=16603093.20..16603093.20 rows=1 width=53) (actual time=0.047..0.050 rows=0 loops=1)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_quantity, lineitem.l_orderkey, partsupp.ps_supplycost, nation.n_name
                                       Buckets: 1024  Batches: 1  Memory Usage: 8kB
                                       Node 16388: (actual time=70858.336..70858.349 rows=2176637 loops=3)
                                         Worker 0: actual time=70857.138..70857.148 rows=2062527 loops=1
                                         Worker 1: actual time=70857.246..70857.258 rows=2228686 loops=1
                                       Node 16387: (actual time=71349.273..71349.284 rows=2176187 loops=3)
                                         Worker 0: actual time=71348.053..71348.064 rows=2247446 loops=1
                                         Worker 1: actual time=71347.933..71347.943 rows=2204216 loops=1
                                       Node 16389: (actual time=71681.529..71681.544 rows=2175361 loops=3)
                                         Worker 0: actual time=71680.292..71680.301 rows=2151956 loops=1
                                         Worker 1: actual time=71680.314..71680.331 rows=2161415 loops=1
                                       Node 16390: (actual time=72218.929..72218.940 rows=2175304 loops=3)
                                         Worker 0: actual time=72217.703..72217.711 rows=2083625 loops=1
                                         Worker 1: actual time=72217.717..72217.727 rows=2103853 loops=1
                                       Node 16391: (actual time=73852.894..73852.912 rows=2175360 loops=3)
                                         Worker 0: actual time=73851.653..73851.678 rows=2094426 loops=1
                                         Worker 1: actual time=73851.670..73851.680 rows=2156517 loops=1
                                       ->  Parallel Hash Join  (cost=2655054.45..16603093.20 rows=1 width=53) (actual time=0.046..0.049 rows=0 loops=1)
                                             Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_quantity, lineitem.l_orderkey, partsupp.ps_supplycost, nation.n_name
                                             Hash Cond: ((supplier.s_suppkey = partsupp.ps_suppkey) AND (lineitem.l_partkey = partsupp.ps_partkey))
                                             Node 16388: (actual time=57717.634..69574.407 rows=2176637 loops=3)
                                               Worker 0: actual time=57721.296..69574.766 rows=2062527 loops=1
                                               Worker 1: actual time=57724.088..69590.898 rows=2228686 loops=1
                                             Node 16387: (actual time=58043.058..70072.827 rows=2176187 loops=3)
                                               Worker 0: actual time=58047.389..70085.602 rows=2247446 loops=1
                                               Worker 1: actual time=58047.531..70022.983 rows=2204216 loops=1
                                             Node 16389: (actual time=58533.739..70325.309 rows=2175361 loops=3)
                                               Worker 0: actual time=58517.754..70266.904 rows=2151956 loops=1
                                               Worker 1: actual time=58539.809..70346.998 rows=2161415 loops=1
                                             Node 16390: (actual time=58601.855..70834.065 rows=2175304 loops=3)
                                               Worker 0: actual time=58590.376..70789.267 rows=2083625 loops=1
                                               Worker 1: actual time=58605.988..70871.386 rows=2103853 loops=1
                                             Node 16391: (actual time=60093.510..72455.659 rows=2175360 loops=3)
                                               Worker 0: actual time=60080.799..72425.058 rows=2094426 loops=1
                                               Worker 1: actual time=60099.115..72460.617 rows=2156517 loops=1
                                             ->  Parallel Hash Join  (cost=31092.72..13976131.32 rows=400019 width=59) (never executed)
                                                   Output: supplier.s_suppkey, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_quantity, lineitem.l_suppkey, lineitem.l_partkey, lineitem.l_orderkey, nation.n_name
                                                   Hash Cond: (lineitem.l_suppkey = supplier.s_suppkey)
                                                   Node 16388: (actual time=18661.248..41387.951 rows=40004963 loops=3)
                                                     Worker 0: actual time=18648.121..41542.862 rows=37493244 loops=1
                                                     Worker 1: actual time=18668.056..41493.109 rows=41400590 loops=1
                                                   Node 16387: (actual time=17818.646..41310.048 rows=39999804 loops=3)
                                                     Worker 0: actual time=17825.440..41743.032 rows=39564151 loops=1
                                                     Worker 1: actual time=17805.851..41311.056 rows=38984733 loops=1
                                                   Node 16389: (actual time=18479.439..41781.952 rows=39999542 loops=3)
                                                     Worker 0: actual time=18485.837..42028.739 rows=38473947 loops=1
                                                     Worker 1: actual time=18486.270..41598.332 rows=39867694 loops=1
                                                   Node 16390: (actual time=17349.342..41075.824 rows=40003653 loops=3)
                                                     Worker 0: actual time=17355.430..40665.385 rows=37858833 loops=1
                                                     Worker 1: actual time=17337.666..41683.728 rows=39692086 loops=1
                                                   Node 16391: (actual time=18486.704..43516.689 rows=40004672 loops=3)
                                                     Worker 0: actual time=18493.653..44565.690 rows=36717646 loops=1
                                                     Worker 1: actual time=18473.685..43719.911 rows=40066950 loops=1
                                                   ->  Parallel Seq Scan on public.lineitem  (cost=0.00..13749196.87 rows=50002358 width=29) (never executed)
                                                         Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                         Remote node: 16389,16387,16390,16388,16391
                                                         Node 16388: (actual time=0.049..8988.034 rows=40004963 loops=3)
                                                           Worker 0: actual time=0.054..9075.280 rows=41004171 loops=1
                                                           Worker 1: actual time=0.045..8805.760 rows=38070399 loops=1
                                                         Node 16387: (actual time=0.053..7993.796 rows=39999804 loops=3)
                                                           Worker 0: actual time=0.065..7943.549 rows=40107101 loops=1
                                                           Worker 1: actual time=0.062..7834.772 rows=40029241 loops=1
                                                         Node 16389: (actual time=0.053..8734.640 rows=39999542 loops=3)
                                                           Worker 0: actual time=0.059..8451.804 rows=40642090 loops=1
                                                           Worker 1: actual time=0.051..8595.772 rows=40386849 loops=1
                                                         Node 16390: (actual time=0.051..7568.645 rows=40003653 loops=3)
                                                           Worker 0: actual time=0.057..7506.187 rows=40446757 loops=1
                                                           Worker 1: actual time=0.053..7518.593 rows=40401957 loops=1
                                                         Node 16391: (actual time=0.050..8959.233 rows=40004672 loops=3)
                                                           Worker 0: actual time=0.060..8878.533 rows=39322490 loops=1
                                                           Worker 1: actual time=0.054..8983.618 rows=40468283 loops=1
                                                   ->  Parallel Hash  (cost=30884.41..30884.41 rows=16665 width=30) (never executed)
                                                         Output: supplier.s_suppkey, nation.n_name
                                                         Node 16388: (actual time=427.884..427.886 rows=333333 loops=3)
                                                           Worker 0: actual time=427.854..427.857 rows=336254 loops=1
                                                           Worker 1: actual time=427.867..427.869 rows=325384 loops=1
                                                         Node 16387: (actual time=452.960..452.962 rows=333333 loops=3)
                                                           Worker 0: actual time=452.917..452.919 rows=345610 loops=1
                                                           Worker 1: actual time=452.987..452.990 rows=344608 loops=1
                                                         Node 16389: (actual time=370.319..370.322 rows=333333 loops=3)
                                                           Worker 0: actual time=370.272..370.273 rows=336018 loops=1
                                                           Worker 1: actual time=370.340..370.343 rows=327520 loops=1
                                                         Node 16390: (actual time=497.161..497.163 rows=333333 loops=3)
                                                           Worker 0: actual time=497.204..497.206 rows=338155 loops=1
                                                           Worker 1: actual time=497.077..497.080 rows=316147 loops=1
                                                         Node 16391: (actual time=493.304..493.307 rows=333333 loops=3)
                                                           Worker 0: actual time=493.254..493.257 rows=326825 loops=1
                                                           Worker 1: actual time=493.295..493.298 rows=332921 loops=1
                                                         ->  Cluster Reduce  (cost=6.31..30884.41 rows=16665 width=30) (never executed)
                                                               Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                               Node 16388: (actual time=254.865..287.924 rows=333333 loops=3)
                                                                 Worker 0: actual time=254.830..288.894 rows=336254 loops=1
                                                                 Worker 1: actual time=254.865..285.142 rows=325384 loops=1
                                                               Node 16387: (actual time=256.126..331.129 rows=333333 loops=3)
                                                                 Worker 0: actual time=256.106..330.928 rows=345610 loops=1
                                                                 Worker 1: actual time=256.123..330.749 rows=344608 loops=1
                                                               Node 16389: (actual time=210.706..249.913 rows=333333 loops=3)
                                                                 Worker 0: actual time=210.712..250.779 rows=336018 loops=1
                                                                 Worker 1: actual time=210.697..247.971 rows=327520 loops=1
                                                               Node 16390: (actual time=332.434..365.833 rows=333333 loops=3)
                                                                 Worker 0: actual time=332.427..367.068 rows=338155 loops=1
                                                                 Worker 1: actual time=332.442..361.783 rows=316147 loops=1
                                                               Node 16391: (actual time=269.663..347.439 rows=333333 loops=3)
                                                                 Worker 0: actual time=269.640..345.890 rows=326825 loops=1
                                                                 Worker 1: actual time=269.684..346.388 rows=332921 loops=1
                                                               ->  Hash Join  (cost=5.31..26607.81 rows=3333 width=30) (never executed)
                                                                     Output: supplier.s_suppkey, nation.n_name
                                                                     Inner Unique: true
                                                                     Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                                     Node 16388: (actual time=0.105..34.829 rows=66745 loops=3)
                                                                       Worker 0: actual time=0.117..43.240 rows=75326 loops=1
                                                                       Worker 1: actual time=0.123..60.234 rows=123549 loops=1
                                                                     Node 16387: (actual time=0.094..31.242 rows=66574 loops=3)
                                                                       Worker 0: actual time=0.109..8.753 rows=17956 loops=1
                                                                       Worker 1: actual time=0.114..82.846 rows=178145 loops=1
                                                                     Node 16389: (actual time=0.090..34.087 rows=66657 loops=3)
                                                                       Worker 0: actual time=0.085..25.647 rows=47204 loops=1
                                                                       Worker 1: actual time=0.096..75.735 rows=151545 loops=1
                                                                     Node 16390: (actual time=0.084..33.880 rows=66790 loops=3)
                                                                       Worker 0: actual time=0.096..30.747 rows=54013 loops=1
                                                                       Worker 1: actual time=0.089..70.136 rows=145267 loops=1
                                                                     Node 16391: (actual time=0.094..32.190 rows=66568 loops=3)
                                                                       Worker 0: actual time=0.106..31.523 rows=63385 loops=1
                                                                       Worker 1: actual time=0.093..62.312 rows=132128 loops=1
                                                                     ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                           Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                           Remote node: 16389,16387,16390,16388,16391
                                                                           Node 16388: (actual time=0.045..14.250 rows=66745 loops=3)
                                                                             Worker 0: actual time=0.051..20.101 rows=75326 loops=1
                                                                             Worker 1: actual time=0.059..22.089 rows=123549 loops=1
                                                                           Node 16387: (actual time=0.038..11.420 rows=66574 loops=3)
                                                                             Worker 0: actual time=0.042..3.585 rows=17956 loops=1
                                                                             Worker 1: actual time=0.051..29.629 rows=178145 loops=1
                                                                           Node 16389: (actual time=0.043..14.246 rows=66657 loops=3)
                                                                             Worker 0: actual time=0.051..11.435 rows=47204 loops=1
                                                                             Worker 1: actual time=0.059..30.854 rows=151545 loops=1
                                                                           Node 16390: (actual time=0.046..13.650 rows=66790 loops=3)
                                                                             Worker 0: actual time=0.060..14.077 rows=54013 loops=1
                                                                             Worker 1: actual time=0.051..26.485 rows=145267 loops=1
                                                                           Node 16391: (actual time=0.042..11.900 rows=66568 loops=3)
                                                                             Worker 0: actual time=0.042..11.977 rows=63385 loops=1
                                                                             Worker 1: actual time=0.052..22.309 rows=132128 loops=1
                                                                     ->  Hash  (cost=5.25..5.25 rows=5 width=30) (never executed)
                                                                           Output: nation.n_name, nation.n_nationkey
                                                                           Node 16388: (actual time=0.052..0.053 rows=25 loops=3)
                                                                             Worker 0: actual time=0.059..0.060 rows=25 loops=1
                                                                             Worker 1: actual time=0.058..0.059 rows=25 loops=1
                                                                           Node 16387: (actual time=0.047..0.048 rows=25 loops=3)
                                                                             Worker 0: actual time=0.059..0.060 rows=25 loops=1
                                                                             Worker 1: actual time=0.054..0.055 rows=25 loops=1
                                                                           Node 16389: (actual time=0.029..0.030 rows=25 loops=3)
                                                                             Worker 0: actual time=0.026..0.026 rows=25 loops=1
                                                                             Worker 1: actual time=0.030..0.031 rows=25 loops=1
                                                                           Node 16390: (actual time=0.030..0.031 rows=25 loops=3)
                                                                             Worker 0: actual time=0.028..0.029 rows=25 loops=1
                                                                             Worker 1: actual time=0.031..0.032 rows=25 loops=1
                                                                           Node 16391: (actual time=0.042..0.043 rows=25 loops=3)
                                                                             Worker 0: actual time=0.057..0.058 rows=25 loops=1
                                                                             Worker 1: actual time=0.032..0.032 rows=25 loops=1
                                                                           ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=30) (never executed)
                                                                                 Output: nation.n_name, nation.n_nationkey
                                                                                 Remote node: 16387,16388,16389,16390,16391
                                                                                 Node 16388: (actual time=0.039..0.043 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.047..0.051 rows=25 loops=1
                                                                                   Worker 1: actual time=0.046..0.049 rows=25 loops=1
                                                                                 Node 16387: (actual time=0.034..0.037 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.045..0.048 rows=25 loops=1
                                                                                   Worker 1: actual time=0.041..0.044 rows=25 loops=1
                                                                                 Node 16389: (actual time=0.016..0.020 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.014..0.017 rows=25 loops=1
                                                                                   Worker 1: actual time=0.017..0.021 rows=25 loops=1
                                                                                 Node 16390: (actual time=0.018..0.021 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.016..0.020 rows=25 loops=1
                                                                                   Worker 1: actual time=0.019..0.022 rows=25 loops=1
                                                                                 Node 16391: (actual time=0.029..0.033 rows=25 loops=3)
                                                                                   Worker 0: actual time=0.046..0.049 rows=25 loops=1
                                                                                   Worker 1: actual time=0.019..0.022 rows=25 loops=1
                                             ->  Parallel Hash  (cost=2623153.53..2623153.53 rows=53880 width=18) (actual time=0.003..0.004 rows=0 loops=1)
                                                   Output: part.p_partkey, partsupp.ps_supplycost, partsupp.ps_suppkey, partsupp.ps_partkey
                                                   Buckets: 65536  Batches: 2  Memory Usage: 512kB
                                                   Node 16388: (actual time=4262.711..4262.713 rows=1450643 loops=3)
                                                     Worker 0: actual time=4261.573..4261.575 rows=1435754 loops=1
                                                     Worker 1: actual time=4261.676..4261.678 rows=1455978 loops=1
                                                   Node 16387: (actual time=4195.230..4195.232 rows=1450643 loops=3)
                                                     Worker 0: actual time=4194.071..4194.073 rows=1480810 loops=1
                                                     Worker 1: actual time=4193.954..4193.956 rows=1458915 loops=1
                                                   Node 16389: (actual time=4310.908..4310.910 rows=1450643 loops=3)
                                                     Worker 0: actual time=4309.736..4309.738 rows=1467463 loops=1
                                                     Worker 1: actual time=4309.752..4309.755 rows=1486423 loops=1
                                                   Node 16390: (actual time=4215.841..4215.843 rows=1450643 loops=3)
                                                     Worker 0: actual time=4214.684..4214.685 rows=1475877 loops=1
                                                     Worker 1: actual time=4214.673..4214.675 rows=1474373 loops=1
                                                   Node 16391: (actual time=4192.967..4192.970 rows=1450643 loops=3)
                                                     Worker 0: actual time=4191.787..4191.790 rows=1466125 loops=1
                                                     Worker 1: actual time=4191.797..4191.799 rows=1490488 loops=1
                                                   ->  Cluster Reduce  (cost=514607.97..2623153.53 rows=53880 width=18) (actual time=0.001..0.001 rows=0 loops=1)
                                                         Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                         Node 16388: (actual time=3678.632..3815.547 rows=1450643 loops=3)
                                                           Worker 0: actual time=3677.494..3816.148 rows=1435754 loops=1
                                                           Worker 1: actual time=3677.576..3808.207 rows=1455978 loops=1
                                                         Node 16387: (actual time=3543.053..3737.243 rows=1450643 loops=3)
                                                           Worker 0: actual time=3541.873..3736.620 rows=1480810 loops=1
                                                           Worker 1: actual time=3541.809..3732.492 rows=1458915 loops=1
                                                         Node 16389: (actual time=3732.907..3864.892 rows=1450643 loops=3)
                                                           Worker 0: actual time=3731.731..3862.692 rows=1467463 loops=1
                                                           Worker 1: actual time=3731.741..3862.270 rows=1486423 loops=1
                                                         Node 16390: (actual time=3530.278..3765.765 rows=1450643 loops=3)
                                                           Worker 0: actual time=3529.123..3758.161 rows=1475877 loops=1
                                                           Worker 1: actual time=3529.106..3747.497 rows=1474373 loops=1
                                                         Node 16391: (actual time=3458.352..3761.082 rows=1450643 loops=3)
                                                           Worker 0: actual time=3457.189..3758.742 rows=1466125 loops=1
                                                           Worker 1: actual time=3457.186..3762.241 rows=1490488 loops=1
                                                         ->  Parallel Hash Join  (cost=514606.97..2609462.33 rows=10776 width=18) (never executed)
                                                               Output: part.p_partkey, partsupp.ps_supplycost, partsupp.ps_suppkey, partsupp.ps_partkey
                                                               Inner Unique: true
                                                               Hash Cond: (partsupp.ps_partkey = part.p_partkey)
                                                               Node 16388: (actual time=498.813..3297.212 rows=290308 loops=3)
                                                                 Worker 0: actual time=497.658..3278.795 rows=295651 loops=1
                                                                 Worker 1: actual time=497.832..3235.685 rows=294276 loops=1
                                                               Node 16387: (actual time=480.190..3267.270 rows=288765 loops=3)
                                                                 Worker 0: actual time=479.051..3257.490 rows=270931 loops=1
                                                                 Worker 1: actual time=478.949..3292.346 rows=299424 loops=1
                                                               Node 16389: (actual time=484.089..3455.093 rows=289719 loops=3)
                                                                 Worker 0: actual time=482.986..3495.516 rows=281527 loops=1
                                                                 Worker 1: actual time=482.877..3425.936 rows=278362 loops=1
                                                               Node 16390: (actual time=469.065..3194.001 rows=291676 loops=3)
                                                                 Worker 0: actual time=467.913..3159.087 rows=296904 loops=1
                                                                 Worker 1: actual time=467.917..3175.372 rows=291168 loops=1
                                                               Node 16391: (actual time=390.736..3163.791 rows=290175 loops=3)
                                                                 Worker 0: actual time=389.554..3168.468 rows=293042 loops=1
                                                                 Worker 1: actual time=389.556..3152.314 rows=300509 loops=1
                                                               ->  Parallel Seq Scan on public.partsupp  (cost=0.00..2077352.47 rows=6667769 width=14) (never executed)
                                                                     Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                                                     Remote node: 16389,16387,16390,16388,16391
                                                                     Node 16388: (actual time=0.034..1305.156 rows=5334251 loops=3)
                                                                       Worker 0: actual time=0.030..1246.572 rows=5422019 loops=1
                                                                       Worker 1: actual time=0.048..1179.111 rows=5420399 loops=1
                                                                     Node 16387: (actual time=0.030..1362.353 rows=5332192 loops=3)
                                                                       Worker 0: actual time=0.030..1376.062 rows=4983142 loops=1
                                                                       Worker 1: actual time=0.037..1313.058 rows=5548828 loops=1
                                                                     Node 16389: (actual time=0.033..1343.668 rows=5335869 loops=3)
                                                                       Worker 0: actual time=0.037..1309.918 rows=5192281 loops=1
                                                                       Worker 1: actual time=0.034..1307.255 rows=5127484 loops=1
                                                                     Node 16390: (actual time=0.037..1214.314 rows=5330264 loops=3)
                                                                       Worker 0: actual time=0.045..1150.364 rows=5424221 loops=1
                                                                       Worker 1: actual time=0.043..1125.103 rows=5328467 loops=1
                                                                     Node 16391: (actual time=0.028..1350.724 rows=5334091 loops=3)
                                                                       Worker 0: actual time=0.044..1311.100 rows=5368317 loops=1
                                                                       Worker 1: actual time=0.021..1351.719 rows=5531233 loops=1
                                                               ->  Parallel Hash  (cost=513765.23..513765.23 rows=67339 width=4) (never executed)
                                                                     Output: part.p_partkey
                                                                     Node 16388: (actual time=498.592..498.592 rows=72577 loops=3)
                                                                       Worker 0: actual time=497.592..497.592 rows=72341 loops=1
                                                                       Worker 1: actual time=497.676..497.677 rows=71256 loops=1
                                                                     Node 16387: (actual time=479.997..479.997 rows=72191 loops=3)
                                                                       Worker 0: actual time=478.966..478.967 rows=72296 loops=1
                                                                       Worker 1: actual time=478.865..478.866 rows=68478 loops=1
                                                                     Node 16389: (actual time=483.838..483.839 rows=72430 loops=3)
                                                                       Worker 0: actual time=482.804..482.805 rows=74829 loops=1
                                                                       Worker 1: actual time=482.804..482.805 rows=75049 loops=1
                                                                     Node 16390: (actual time=468.856..468.856 rows=72919 loops=3)
                                                                       Worker 0: actual time=467.816..467.816 rows=74636 loops=1
                                                                       Worker 1: actual time=467.806..467.807 rows=75211 loops=1
                                                                     Node 16391: (actual time=390.527..390.528 rows=72544 loops=3)
                                                                       Worker 0: actual time=389.484..389.485 rows=71698 loops=1
                                                                       Worker 1: actual time=389.485..389.485 rows=71047 loops=1
                                                                     ->  Parallel Seq Scan on public.part  (cost=0.00..513765.23 rows=67339 width=4) (never executed)
                                                                           Output: part.p_partkey
                                                                           Filter: ((part.p_name)::text ~~ '%green%'::text)
                                                                           Remote node: 16389,16387,16390,16388,16391
                                                                           Node 16388: (actual time=0.026..448.143 rows=72577 loops=3)
                                                                             Worker 0: actual time=0.032..442.112 rows=72341 loops=1
                                                                             Worker 1: actual time=0.030..443.373 rows=71256 loops=1
                                                                           Node 16387: (actual time=0.030..437.015 rows=72191 loops=3)
                                                                             Worker 0: actual time=0.022..440.140 rows=72296 loops=1
                                                                             Worker 1: actual time=0.036..428.862 rows=68478 loops=1
                                                                           Node 16389: (actual time=0.036..431.668 rows=72430 loops=3)
                                                                             Worker 0: actual time=0.042..424.853 rows=74829 loops=1
                                                                             Worker 1: actual time=0.042..425.288 rows=75049 loops=1
                                                                           Node 16390: (actual time=0.026..422.753 rows=72919 loops=3)
                                                                             Worker 0: actual time=0.032..417.877 rows=74636 loops=1
                                                                             Worker 1: actual time=0.032..416.885 rows=75211 loops=1
                                                                           Node 16391: (actual time=0.024..363.013 rows=72544 loops=3)
                                                                             Worker 0: actual time=0.027..362.388 rows=71698 loops=1
                                                                             Worker 1: actual time=0.026..362.535 rows=71047 loops=1
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
               Node 16390: (actual time=26364.988..26478.465 rows=20 loops=1)
               Node 16391: (actual time=26380.075..26494.343 rows=20 loops=1)
               Node 16387: (actual time=26272.707..26386.988 rows=20 loops=1)
               Node 16388: (actual time=26282.931..26389.576 rows=20 loops=1)
               Node 16389: (actual time=26480.943..26571.397 rows=20 loops=1)
               ->  Sort  (cost=18692781.62..18692782.21 rows=237 width=201) (actual time=0.006..0.008 rows=0 loops=1)
                     Output: customer.c_custkey, customer.c_name, (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), customer.c_acctbal, nation.n_name, customer.c_address, customer.c_phone, customer.c_comment
                     Sort Key: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))) DESC
                     Sort Method: quicksort  Memory: 25kB
                     Node 16390: (actual time=26364.987..26478.462 rows=20 loops=1)
                     Node 16391: (actual time=26380.073..26494.337 rows=20 loops=1)
                     Node 16387: (actual time=26272.705..26386.985 rows=20 loops=1)
                     Node 16388: (actual time=26282.929..26389.572 rows=20 loops=1)
                     Node 16389: (actual time=26480.942..26571.394 rows=20 loops=1)
                     ->  Finalize GroupAggregate  (cost=18692708.45..18692775.31 rows=237 width=201) (actual time=0.000..0.002 rows=0 loops=1)
                           Output: customer.c_custkey, customer.c_name, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))), customer.c_acctbal, nation.n_name, customer.c_address, customer.c_phone, customer.c_comment
                           Group Key: customer.c_custkey, nation.n_name
                           Node 16390: (actual time=24214.587..26196.934 rows=775283 loops=1)
                           Node 16391: (actual time=24202.282..26212.384 rows=776889 loops=1)
                           Node 16387: (actual time=24098.373..26104.627 rows=777636 loops=1)
                           Node 16388: (actual time=24065.939..26107.936 rows=776938 loops=1)
                           Node 16389: (actual time=24205.083..26289.264 rows=777472 loops=1)
                           ->  Gather Merge  (cost=18692708.45..18692767.60 rows=474 width=201) (never executed)
                                 Output: customer.c_custkey, nation.n_name, customer.c_name, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))), customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                 Workers Planned: 2
                                 Workers Launched: 0
                                 Node 16390: (actual time=24214.571..25301.281 rows=775283 loops=1)
                                 Node 16391: (actual time=24202.264..25313.324 rows=776889 loops=1)
                                 Node 16387: (actual time=24098.355..25205.236 rows=777636 loops=1)
                                 Node 16388: (actual time=24065.920..25207.280 rows=776938 loops=1)
                                 Node 16389: (actual time=24205.073..25384.512 rows=777472 loops=1)
                                 ->  Partial GroupAggregate  (cost=18691708.42..18691712.87 rows=237 width=201) (never executed)
                                       Output: customer.c_custkey, nation.n_name, customer.c_name, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))), customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                       Group Key: customer.c_custkey, nation.n_name
                                       Node 16390: (actual time=24197.788..24998.509 rows=258428 loops=3)
                                         Worker 0: actual time=24188.859..24964.951 rows=251001 loops=1
                                         Worker 1: actual time=24210.296..25067.236 rows=277120 loops=1
                                       Node 16391: (actual time=24189.814..24992.654 rows=258963 loops=3)
                                         Worker 0: actual time=24198.032..25022.631 rows=266372 loops=1
                                         Worker 1: actual time=24185.517..24976.871 rows=255528 loops=1
                                       Node 16387: (actual time=24090.749..24896.030 rows=259212 loops=3)
                                         Worker 0: actual time=24087.085..24890.456 rows=258040 loops=1
                                         Worker 1: actual time=24094.197..24908.078 rows=261344 loops=1
                                       Node 16388: (actual time=24052.513..24853.356 rows=258979 loops=3)
                                         Worker 0: actual time=24045.395..24834.300 rows=254985 loops=1
                                         Worker 1: actual time=24046.749..24821.169 rows=250176 loops=1
                                       Node 16389: (actual time=24186.092..24992.437 rows=259157 loops=3)
                                         Worker 0: actual time=24181.256..24962.371 rows=252357 loops=1
                                         Worker 1: actual time=24172.480..24928.271 rows=242918 loops=1
                                       ->  Sort  (cost=18691708.42..18691708.67 rows=99 width=181) (never executed)
                                             Output: customer.c_custkey, nation.n_name, customer.c_name, lineitem.l_extendedprice, lineitem.l_discount, customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                             Sort Key: customer.c_custkey, nation.n_name
                                             Node 16390: (actual time=24197.773..24354.241 rows=761318 loops=3)
                                               Worker 0: actual time=24188.842..24342.415 rows=737554 loops=1
                                               Worker 1: actual time=24210.282..24379.012 rows=816390 loops=1
                                             Node 16391: (actual time=24189.794..24344.941 rows=765516 loops=3)
                                               Worker 0: actual time=24198.016..24359.048 rows=787812 loops=1
                                               Worker 1: actual time=24185.498..24340.334 rows=754742 loops=1
                                             Node 16387: (actual time=24090.733..24247.197 rows=765223 loops=3)
                                               Worker 0: actual time=24087.067..24245.335 rows=761305 loops=1
                                               Worker 1: actual time=24094.185..24254.189 rows=771428 loops=1
                                             Node 16388: (actual time=24052.483..24207.842 rows=763646 loops=3)
                                               Worker 0: actual time=24045.362..24200.722 rows=752226 loops=1
                                               Worker 1: actual time=24046.731..24199.737 rows=737780 loops=1
                                             Node 16389: (actual time=24186.064..24343.787 rows=765353 loops=3)
                                               Worker 0: actual time=24181.230..24335.109 rows=744469 loops=1
                                               Worker 1: actual time=24172.452..24322.997 rows=718120 loops=1
                                             ->  Parallel Hash Join  (cost=18266901.78..18691705.14 rows=99 width=181) (never executed)
                                                   Output: customer.c_custkey, nation.n_name, customer.c_name, lineitem.l_extendedprice, lineitem.l_discount, customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment
                                                   Hash Cond: (customer.c_custkey = orders.o_custkey)
                                                   Node 16390: (actual time=22848.547..23542.089 rows=761318 loops=3)
                                                     Worker 0: actual time=22852.985..23578.011 rows=737554 loops=1
                                                     Worker 1: actual time=22835.547..23507.889 rows=816390 loops=1
                                                   Node 16391: (actual time=22881.766..23554.769 rows=765516 loops=3)
                                                     Worker 0: actual time=22886.467..23540.535 rows=787812 loops=1
                                                     Worker 1: actual time=22868.387..23547.374 rows=754742 loops=1
                                                   Node 16387: (actual time=22822.451..23491.075 rows=765223 loops=3)
                                                     Worker 0: actual time=22827.543..23502.206 rows=761305 loops=1
                                                     Worker 1: actual time=22809.228..23466.180 rows=771428 loops=1
                                                   Node 16388: (actual time=22823.348..23442.475 rows=763646 loops=3)
                                                     Worker 0: actual time=22811.581..23442.493 rows=752226 loops=1
                                                     Worker 1: actual time=22827.471..23444.568 rows=737780 loops=1
                                                   Node 16389: (actual time=22861.157..23568.978 rows=765353 loops=3)
                                                     Worker 0: actual time=22866.341..23574.842 rows=744469 loops=1
                                                     Worker 1: actual time=22868.740..23583.594 rows=718120 loops=1
                                                   ->  Hash Join  (cost=5.31..424621.09 rows=50001 width=169) (never executed)
                                                         Output: customer.c_custkey, customer.c_name, customer.c_acctbal, customer.c_address, customer.c_phone, customer.c_comment, nation.n_name
                                                         Inner Unique: true
                                                         Hash Cond: (customer.c_nationkey = nation.n_nationkey)
                                                         Node 16390: (actual time=0.221..583.299 rows=999249 loops=3)
                                                           Worker 0: actual time=0.299..600.986 rows=1035735 loops=1
                                                           Worker 1: actual time=0.286..583.829 rows=985308 loops=1
                                                         Node 16391: (actual time=0.214..577.515 rows=999974 loops=3)
                                                           Worker 0: actual time=0.275..578.819 rows=1021352 loops=1
                                                           Worker 1: actual time=0.310..565.592 rows=1001322 loops=1
                                                         Node 16387: (actual time=0.199..578.093 rows=999485 loops=3)
                                                           Worker 0: actual time=0.228..585.298 rows=1002317 loops=1
                                                           Worker 1: actual time=0.294..585.375 rows=977527 loops=1
                                                         Node 16388: (actual time=0.147..593.410 rows=1000754 loops=3)
                                                           Worker 0: actual time=0.218..591.102 rows=1018921 loops=1
                                                           Worker 1: actual time=0.127..585.094 rows=1010553 loops=1
                                                         Node 16389: (actual time=0.124..595.726 rows=1000538 loops=3)
                                                           Worker 0: actual time=0.107..587.988 rows=1029660 loops=1
                                                           Worker 1: actual time=0.194..588.147 rows=975631 loops=1
                                                         ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=147) (never executed)
                                                               Output: customer.c_custkey, customer.c_name, customer.c_address, customer.c_nationkey, customer.c_phone, customer.c_acctbal, customer.c_mktsegment, customer.c_comment
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16390: (actual time=0.048..258.441 rows=999249 loops=3)
                                                                 Worker 0: actual time=0.050..267.668 rows=1035735 loops=1
                                                                 Worker 1: actual time=0.066..257.352 rows=985308 loops=1
                                                               Node 16391: (actual time=0.043..255.095 rows=999974 loops=3)
                                                                 Worker 0: actual time=0.049..248.350 rows=1021352 loops=1
                                                                 Worker 1: actual time=0.067..243.548 rows=1001322 loops=1
                                                               Node 16387: (actual time=0.044..251.275 rows=999485 loops=3)
                                                                 Worker 0: actual time=0.041..244.996 rows=1002317 loops=1
                                                                 Worker 1: actual time=0.059..271.691 rows=977527 loops=1
                                                               Node 16388: (actual time=0.046..272.646 rows=1000754 loops=3)
                                                                 Worker 0: actual time=0.044..264.153 rows=1018921 loops=1
                                                                 Worker 1: actual time=0.062..260.667 rows=1010553 loops=1
                                                               Node 16389: (actual time=0.039..267.820 rows=1000538 loops=3)
                                                                 Worker 0: actual time=0.061..255.357 rows=1029660 loops=1
                                                                 Worker 1: actual time=0.033..256.258 rows=975631 loops=1
                                                         ->  Hash  (cost=5.25..5.25 rows=5 width=30) (never executed)
                                                               Output: nation.n_name, nation.n_nationkey
                                                               Node 16390: (actual time=0.048..0.049 rows=25 loops=3)
                                                                 Worker 0: actual time=0.054..0.054 rows=25 loops=1
                                                                 Worker 1: actual time=0.059..0.060 rows=25 loops=1
                                                               Node 16391: (actual time=0.047..0.047 rows=25 loops=3)
                                                                 Worker 0: actual time=0.056..0.056 rows=25 loops=1
                                                                 Worker 1: actual time=0.057..0.058 rows=25 loops=1
                                                               Node 16387: (actual time=0.043..0.044 rows=25 loops=3)
                                                                 Worker 0: actual time=0.054..0.054 rows=25 loops=1
                                                                 Worker 1: actual time=0.046..0.047 rows=25 loops=1
                                                               Node 16388: (actual time=0.040..0.041 rows=25 loops=3)
                                                                 Worker 0: actual time=0.044..0.044 rows=25 loops=1
                                                                 Worker 1: actual time=0.036..0.037 rows=25 loops=1
                                                               Node 16389: (actual time=0.031..0.032 rows=25 loops=3)
                                                                 Worker 0: actual time=0.027..0.028 rows=25 loops=1
                                                                 Worker 1: actual time=0.038..0.039 rows=25 loops=1
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.25 rows=5 width=30) (never executed)
                                                                     Output: nation.n_name, nation.n_nationkey
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     Node 16390: (actual time=0.035..0.038 rows=25 loops=3)
                                                                       Worker 0: actual time=0.040..0.044 rows=25 loops=1
                                                                       Worker 1: actual time=0.044..0.048 rows=25 loops=1
                                                                     Node 16391: (actual time=0.034..0.038 rows=25 loops=3)
                                                                       Worker 0: actual time=0.043..0.046 rows=25 loops=1
                                                                       Worker 1: actual time=0.045..0.048 rows=25 loops=1
                                                                     Node 16387: (actual time=0.031..0.034 rows=25 loops=3)
                                                                       Worker 0: actual time=0.041..0.045 rows=25 loops=1
                                                                       Worker 1: actual time=0.035..0.038 rows=25 loops=1
                                                                     Node 16388: (actual time=0.026..0.030 rows=25 loops=3)
                                                                       Worker 0: actual time=0.032..0.036 rows=25 loops=1
                                                                       Worker 1: actual time=0.022..0.026 rows=25 loops=1
                                                                     Node 16389: (actual time=0.020..0.023 rows=25 loops=3)
                                                                       Worker 0: actual time=0.016..0.019 rows=25 loops=1
                                                                       Worker 1: actual time=0.027..0.030 rows=25 loops=1
                                                   ->  Parallel Hash  (cost=18266865.58..18266865.58 rows=2471 width=16) (never executed)
                                                         Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount
                                                         Node 16390: (actual time=21872.867..21872.872 rows=761318 loops=3)
                                                           Worker 0: actual time=21871.610..21871.613 rows=764871 loops=1
                                                           Worker 1: actual time=21871.598..21871.601 rows=769962 loops=1
                                                         Node 16391: (actual time=21911.592..21911.596 rows=765516 loops=3)
                                                           Worker 0: actual time=21910.359..21910.362 rows=786096 loops=1
                                                           Worker 1: actual time=21910.345..21910.348 rows=771539 loops=1
                                                         Node 16387: (actual time=21870.466..21870.470 rows=765223 loops=3)
                                                           Worker 0: actual time=21869.267..21869.269 rows=746119 loops=1
                                                           Worker 1: actual time=21869.256..21869.260 rows=796172 loops=1
                                                         Node 16388: (actual time=21861.409..21861.412 rows=763646 loops=3)
                                                           Worker 0: actual time=21860.309..21860.311 rows=770248 loops=1
                                                           Worker 1: actual time=21860.055..21860.057 rows=765290 loops=1
                                                         Node 16389: (actual time=21873.773..21873.777 rows=765353 loops=3)
                                                           Worker 0: actual time=21872.635..21872.639 rows=766510 loops=1
                                                           Worker 1: actual time=21872.624..21872.627 rows=761510 loops=1
                                                         ->  Cluster Reduce  (cost=3860008.52..18266865.58 rows=2471 width=16) (never executed)
                                                               Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                               Node 16390: (actual time=21327.391..21649.538 rows=761318 loops=3)
                                                                 Worker 0: actual time=21326.130..21650.020 rows=764871 loops=1
                                                                 Worker 1: actual time=21326.119..21646.988 rows=769962 loops=1
                                                               Node 16391: (actual time=21620.101..21688.287 rows=765516 loops=3)
                                                                 Worker 0: actual time=21618.862..21687.666 rows=786096 loops=1
                                                                 Worker 1: actual time=21618.860..21685.686 rows=771539 loops=1
                                                               Node 16387: (actual time=20277.003..21636.898 rows=765223 loops=3)
                                                                 Worker 0: actual time=20275.783..21635.593 rows=746119 loops=1
                                                                 Worker 1: actual time=20275.812..21635.861 rows=796172 loops=1
                                                               Node 16388: (actual time=20452.152..21664.992 rows=763646 loops=3)
                                                                 Worker 0: actual time=20451.049..21663.926 rows=770248 loops=1
                                                                 Worker 1: actual time=20450.787..21662.677 rows=765290 loops=1
                                                               Node 16389: (actual time=20960.611..21645.670 rows=765353 loops=3)
                                                                 Worker 0: actual time=20959.458..21642.442 rows=766510 loops=1
                                                                 Worker 1: actual time=20959.460..21642.522 rows=761510 loops=1
                                                               ->  Parallel Hash Join  (cost=3860007.52..18266667.25 rows=2471 width=16) (never executed)
                                                                     Output: orders.o_custkey, lineitem.l_extendedprice, lineitem.l_discount
                                                                     Inner Unique: true
                                                                     Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                                     Node 16390: (actual time=17386.597..20720.011 rows=765273 loops=3)
                                                                       Worker 0: actual time=17390.707..20746.784 rows=788520 loops=1
                                                                       Worker 1: actual time=17374.080..20670.472 rows=740006 loops=1
                                                                     Node 16391: (actual time=17668.999..21044.654 rows=763141 loops=3)
                                                                       Worker 0: actual time=17674.788..20946.243 rows=782008 loops=1
                                                                       Worker 1: actual time=17654.322..21110.987 rows=808002 loops=1
                                                                     Node 16387: (actual time=16457.764..19667.510 rows=764599 loops=3)
                                                                       Worker 0: actual time=16462.271..19679.337 rows=768545 loops=1
                                                                       Worker 1: actual time=16445.444..19607.115 rows=729624 loops=1
                                                                     Node 16388: (actual time=16771.178..19845.762 rows=763117 loops=3)
                                                                       Worker 0: actual time=16758.565..19829.616 rows=758386 loops=1
                                                                       Worker 1: actual time=16775.325..19847.903 rows=748437 loops=1
                                                                     Node 16389: (actual time=17050.059..20448.543 rows=764928 loops=3)
                                                                       Worker 0: actual time=17055.403..20508.370 rows=782777 loops=1
                                                                       Worker 1: actual time=17035.952..20452.452 rows=766611 loops=1
                                                                     ->  Parallel Seq Scan on public.lineitem  (cost=0.00..14374226.33 rows=12355582 width=16) (never executed)
                                                                           Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                                           Filter: (lineitem.l_returnflag = 'R'::bpchar)
                                                                           Remote node: 16389,16387,16390,16388,16391
                                                                           Node 16390: (actual time=0.044..12588.126 rows=9873044 loops=3)
                                                                             Worker 0: actual time=0.059..12451.641 rows=10058640 loops=1
                                                                             Worker 1: actual time=0.041..12691.834 rows=9298165 loops=1
                                                                           Node 16391: (actual time=0.075..12781.933 rows=9872578 loops=3)
                                                                             Worker 0: actual time=0.133..12804.251 rows=9856634 loops=1
                                                                             Worker 1: actual time=0.066..12800.864 rows=9868276 loops=1
                                                                           Node 16387: (actual time=0.074..12185.232 rows=9869334 loops=3)
                                                                             Worker 0: actual time=0.142..12182.767 rows=9957864 loops=1
                                                                             Worker 1: actual time=0.056..12233.046 rows=9418637 loops=1
                                                                           Node 16388: (actual time=0.073..12140.767 rows=9870668 loops=3)
                                                                             Worker 0: actual time=0.120..12146.341 rows=10097901 loops=1
                                                                             Worker 1: actual time=0.067..12048.666 rows=9779309 loops=1
                                                                           Node 16389: (actual time=0.060..12361.637 rows=9870129 loops=3)
                                                                             Worker 0: actual time=0.065..12220.995 rows=10319186 loops=1
                                                                             Worker 1: actual time=0.061..12341.392 rows=10255749 loops=1
                                                                     ->  Parallel Hash  (cost=3859226.27..3859226.27 rows=62500 width=8) (never executed)
                                                                           Output: orders.o_custkey, orders.o_orderkey
                                                                           Node 16390: (actual time=2587.888..2587.889 rows=382630 loops=3)
                                                                             Worker 0: actual time=2586.730..2586.731 rows=375019 loops=1
                                                                             Worker 1: actual time=2586.756..2586.757 rows=369074 loops=1
                                                                           Node 16391: (actual time=2635.639..2635.640 rows=381690 loops=3)
                                                                             Worker 0: actual time=2634.508..2634.509 rows=403082 loops=1
                                                                             Worker 1: actual time=2634.503..2634.503 rows=371419 loops=1
                                                                           Node 16387: (actual time=2179.128..2179.129 rows=381947 loops=3)
                                                                             Worker 0: actual time=2178.020..2178.021 rows=374849 loops=1
                                                                             Worker 1: actual time=2178.053..2178.053 rows=384991 loops=1
                                                                           Node 16388: (actual time=2476.253..2476.253 rows=381602 loops=3)
                                                                             Worker 0: actual time=2475.251..2475.252 rows=381665 loops=1
                                                                             Worker 1: actual time=2475.008..2475.009 rows=374059 loops=1
                                                                           Node 16389: (actual time=2467.558..2467.559 rows=382256 loops=3)
                                                                             Worker 0: actual time=2466.537..2466.538 rows=386009 loops=1
                                                                             Worker 1: actual time=2466.540..2466.541 rows=383711 loops=1
                                                                           ->  Parallel Seq Scan on public.orders  (cost=0.00..3859226.27 rows=62500 width=8) (never executed)
                                                                                 Output: orders.o_custkey, orders.o_orderkey
                                                                                 Filter: (((orders.o_orderdate)::timestamp without time zone >= '1993-10-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone < '1994-01-01 00:00:00'::timestamp without time zone))
                                                                                 Remote node: 16389,16387,16390,16388,16391
                                                                                 Node 16390: (actual time=0.031..2369.479 rows=382630 loops=3)
                                                                                   Worker 0: actual time=0.027..2368.004 rows=375019 loops=1
                                                                                   Worker 1: actual time=0.032..2359.996 rows=369074 loops=1
                                                                                 Node 16391: (actual time=0.033..2454.733 rows=381690 loops=3)
                                                                                   Worker 0: actual time=0.030..2435.329 rows=403082 loops=1
                                                                                   Worker 1: actual time=0.030..2463.848 rows=371419 loops=1
                                                                                 Node 16387: (actual time=0.029..2017.491 rows=381947 loops=3)
                                                                                   Worker 0: actual time=0.021..2013.394 rows=374849 loops=1
                                                                                   Worker 1: actual time=0.032..2015.781 rows=384991 loops=1
                                                                                 Node 16388: (actual time=0.038..2276.830 rows=381602 loops=3)
                                                                                   Worker 0: actual time=0.029..2274.703 rows=381665 loops=1
                                                                                   Worker 1: actual time=0.031..2259.606 rows=374059 loops=1
                                                                                 Node 16389: (actual time=0.041..2267.613 rows=382256 loops=3)
                                                                                   Worker 0: actual time=0.035..2266.600 rows=386009 loops=1
                                                                                   Worker 1: actual time=0.051..2259.739 rows=383711 loops=1
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
         Node 16387: (actual time=4821.650..4823.789 rows=18445 loops=1)
         Node 16388: (actual time=5180.222..5182.252 rows=18371 loops=1)
         Node 16389: (actual time=5242.949..5245.089 rows=18727 loops=1)
         Node 16390: (actual time=4704.787..4706.883 rows=18577 loops=1)
         Node 16391: (actual time=4934.758..4937.114 rows=18578 loops=1)
         InitPlan 1 (returns $0)
           ->  Cluster Reduce  (cost=2131151.15..2131154.47 rows=1 width=32) (never executed)
                 Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                 Node 16387: (actual time=0.119..0.260 rows=1 loops=1)
                 Node 16388: (actual time=0.119..0.280 rows=1 loops=1)
                 Node 16389: (actual time=0.116..0.313 rows=1 loops=1)
                 Node 16390: (actual time=0.102..0.289 rows=1 loops=1)
                 Node 16391: (actual time=0.092..0.258 rows=1 loops=1)
                 ->  Finalize Aggregate  (cost=2131150.15..2131150.17 rows=1 width=32) (actual time=4054.994..4054.997 rows=1 loops=1)
                       Output: (sum((partsupp_1.ps_supplycost * "numeric"(partsupp_1.ps_availqty))) * 0.000001)
                       Node 16387: (actual time=0.000..0.140 rows=0 loops=1)
                       Node 16388: (actual time=0.001..0.154 rows=0 loops=1)
                       Node 16389: (actual time=0.000..0.184 rows=0 loops=1)
                       Node 16390: (actual time=0.000..0.162 rows=0 loops=1)
                       Node 16391: (actual time=0.000..0.137 rows=0 loops=1)
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
                                   Node 16387: (actual time=3038.288..3038.716 rows=3 loops=1)
                                   Node 16388: (actual time=3940.657..3941.113 rows=3 loops=1)
                                   Node 16389: (actual time=3619.027..3619.367 rows=3 loops=1)
                                   Node 16390: (actual time=3839.804..3840.467 rows=3 loops=1)
                                   Node 16391: (actual time=2671.983..2672.351 rows=3 loops=1)
                                   ->  Partial Aggregate  (cost=2130142.89..2130142.90 rows=1 width=32) (actual time=0.013..0.015 rows=1 loops=1)
                                         Output: PARTIAL sum((partsupp_1.ps_supplycost * "numeric"(partsupp_1.ps_availqty)))
                                         Node 16387: (actual time=3036.032..3036.035 rows=1 loops=3)
                                           Worker 0: actual time=3034.973..3034.975 rows=1 loops=1
                                           Worker 1: actual time=3035.082..3035.083 rows=1 loops=1
                                         Node 16388: (actual time=3938.449..3938.453 rows=1 loops=3)
                                           Worker 0: actual time=3937.482..3937.485 rows=1 loops=1
                                           Worker 1: actual time=3937.480..3937.482 rows=1 loops=1
                                         Node 16389: (actual time=3616.747..3616.754 rows=1 loops=3)
                                           Worker 0: actual time=3615.777..3615.789 rows=1 loops=1
                                           Worker 1: actual time=3615.710..3615.713 rows=1 loops=1
                                         Node 16390: (actual time=3837.170..3837.175 rows=1 loops=3)
                                           Worker 0: actual time=3835.926..3835.929 rows=1 loops=1
                                           Worker 1: actual time=3836.042..3836.045 rows=1 loops=1
                                         Node 16391: (actual time=2669.729..2669.734 rows=1 loops=3)
                                           Worker 0: actual time=2668.760..2668.763 rows=1 loops=1
                                           Worker 1: actual time=2668.709..2668.712 rows=1 loops=1
                                         ->  Parallel Hash Join  (cost=27483.91..2130062.88 rows=10668 width=10) (actual time=0.009..0.010 rows=0 loops=1)
                                               Output: partsupp_1.ps_supplycost, partsupp_1.ps_availqty
                                               Hash Cond: (partsupp_1.ps_suppkey = supplier_1.s_suppkey)
                                               Node 16387: (actual time=63.025..2956.607 rows=213803 loops=3)
                                                 Worker 0: actual time=62.006..2953.635 rows=220114 loops=1
                                                 Worker 1: actual time=62.005..2957.577 rows=209540 loops=1
                                               Node 16388: (actual time=64.713..3858.935 rows=213441 loops=3)
                                                 Worker 0: actual time=63.698..3853.569 rows=225622 loops=1
                                                 Worker 1: actual time=63.711..3855.126 rows=222355 loops=1
                                               Node 16389: (actual time=71.533..3537.422 rows=213612 loops=3)
                                                 Worker 0: actual time=70.533..3526.811 rows=239979 loops=1
                                                 Worker 1: actual time=70.527..3526.444 rows=240668 loops=1
                                               Node 16390: (actual time=67.267..3757.662 rows=213494 loops=3)
                                                 Worker 0: actual time=66.023..3760.834 rows=202569 loops=1
                                                 Worker 1: actual time=66.058..3754.150 rows=220698 loops=1
                                               Node 16391: (actual time=8.900..2590.600 rows=213516 loops=3)
                                                 Worker 0: actual time=7.886..2592.087 rows=207111 loops=1
                                                 Worker 1: actual time=7.896..2589.296 rows=215389 loops=1
                                               ->  Parallel Seq Scan on public.partsupp partsupp_1  (cost=0.00..2077352.47 rows=6667769 width=14) (never executed)
                                                     Output: partsupp_1.ps_partkey, partsupp_1.ps_suppkey, partsupp_1.ps_availqty, partsupp_1.ps_supplycost, partsupp_1.ps_comment
                                                     Remote node: 16389,16387,16390,16388,16391
                                                     Node 16387: (actual time=0.028..1237.348 rows=5332192 loops=3)
                                                       Worker 0: actual time=0.030..1240.920 rows=5496304 loops=1
                                                       Worker 1: actual time=0.030..1217.182 rows=5221640 loops=1
                                                     Node 16388: (actual time=0.038..1210.496 rows=5334251 loops=3)
                                                       Worker 0: actual time=0.049..1244.171 rows=5641540 loops=1
                                                       Worker 1: actual time=0.043..1190.019 rows=5572854 loops=1
                                                     Node 16389: (actual time=0.025..1197.180 rows=5335869 loops=3)
                                                       Worker 0: actual time=0.030..1304.695 rows=6002302 loops=1
                                                       Worker 1: actual time=0.028..1301.582 rows=6007162 loops=1
                                                     Node 16390: (actual time=0.047..1236.149 rows=5330264 loops=3)
                                                       Worker 0: actual time=0.048..1191.847 rows=5057334 loops=1
                                                       Worker 1: actual time=0.049..1265.558 rows=5516753 loops=1
                                                     Node 16391: (actual time=0.023..1151.941 rows=5334091 loops=3)
                                                       Worker 0: actual time=0.024..1117.216 rows=5184191 loops=1
                                                       Worker 1: actual time=0.025..1170.174 rows=5372743 loops=1
                                               ->  Parallel Hash  (cost=27442.22..27442.22 rows=3335 width=4) (actual time=0.003..0.004 rows=0 loops=1)
                                                     Output: supplier_1.s_suppkey
                                                     Buckets: 8192  Batches: 1  Memory Usage: 64kB
                                                     Node 16387: (actual time=62.872..62.873 rows=13348 loops=3)
                                                       Worker 0: actual time=61.824..61.825 rows=11026 loops=1
                                                       Worker 1: actual time=61.827..61.828 rows=9598 loops=1
                                                     Node 16388: (actual time=64.478..64.480 rows=13348 loops=3)
                                                       Worker 0: actual time=63.474..63.476 rows=11012 loops=1
                                                       Worker 1: actual time=63.472..63.473 rows=11459 loops=1
                                                     Node 16389: (actual time=71.368..71.374 rows=13348 loops=3)
                                                       Worker 0: actual time=70.340..70.351 rows=11216 loops=1
                                                       Worker 1: actual time=70.345..70.346 rows=12515 loops=1
                                                     Node 16390: (actual time=67.084..67.086 rows=13348 loops=3)
                                                       Worker 0: actual time=65.830..65.832 rows=11216 loops=1
                                                       Worker 1: actual time=65.840..65.842 rows=12683 loops=1
                                                     Node 16391: (actual time=8.754..8.756 rows=13348 loops=3)
                                                       Worker 0: actual time=7.723..7.725 rows=11068 loops=1
                                                       Worker 1: actual time=7.727..7.729 rows=9766 loops=1
                                                     ->  Cluster Reduce  (cost=6.33..27442.22 rows=3335 width=4) (actual time=0.001..0.002 rows=0 loops=1)
                                                           Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                           Node 16387: (actual time=35.684..54.824 rows=13348 loops=3)
                                                             Worker 0: actual time=53.512..54.455 rows=11026 loops=1
                                                             Worker 1: actual time=53.516..54.343 rows=9598 loops=1
                                                           Node 16388: (actual time=32.957..50.638 rows=13348 loops=3)
                                                             Worker 0: actual time=49.425..50.339 rows=11012 loops=1
                                                             Worker 1: actual time=49.424..50.399 rows=11459 loops=1
                                                           Node 16389: (actual time=37.468..57.366 rows=13348 loops=3)
                                                             Worker 0: actual time=56.188..57.088 rows=11216 loops=1
                                                             Worker 1: actual time=56.193..57.184 rows=12515 loops=1
                                                           Node 16390: (actual time=35.364..54.508 rows=13348 loops=3)
                                                             Worker 0: actual time=53.034..53.972 rows=11216 loops=1
                                                             Worker 1: actual time=53.034..54.041 rows=12683 loops=1
                                                           Node 16391: (actual time=0.020..1.129 rows=13348 loops=3)
                                                             Worker 0: actual time=0.017..0.934 rows=11068 loops=1
                                                             Worker 1: actual time=0.020..0.840 rows=9766 loops=1
                                                           ->  Hash Join  (cost=5.33..26607.82 rows=667 width=4) (never executed)
                                                                 Output: supplier_1.s_suppkey
                                                                 Inner Unique: true
                                                                 Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                 Node 16387: (actual time=0.058..57.989 rows=8018 loops=1)
                                                                 Node 16388: (actual time=0.081..58.804 rows=7995 loops=1)
                                                                 Node 16389: (actual time=0.072..55.508 rows=8129 loops=1)
                                                                 Node 16390: (actual time=0.070..57.363 rows=7961 loops=1)
                                                                 Node 16391: (actual time=0.071..71.594 rows=7942 loops=1)
                                                                 ->  Parallel Seq Scan on public.supplier supplier_1  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                                       Output: supplier_1.s_suppkey, supplier_1.s_name, supplier_1.s_address, supplier_1.s_nationkey, supplier_1.s_phone, supplier_1.s_acctbal, supplier_1.s_comment
                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                       Node 16387: (actual time=0.024..31.265 rows=199723 loops=1)
                                                                       Node 16388: (actual time=0.034..31.385 rows=200234 loops=1)
                                                                       Node 16389: (actual time=0.027..28.384 rows=199970 loops=1)
                                                                       Node 16390: (actual time=0.030..29.879 rows=200370 loops=1)
                                                                       Node 16391: (actual time=0.027..39.359 rows=199703 loops=1)
                                                                 ->  Hash  (cost=5.31..5.31 rows=1 width=4) (never executed)
                                                                       Output: nation_1.n_nationkey
                                                                       Node 16387: (actual time=0.023..0.024 rows=1 loops=1)
                                                                       Node 16388: (actual time=0.032..0.033 rows=1 loops=1)
                                                                       Node 16389: (actual time=0.031..0.033 rows=1 loops=1)
                                                                       Node 16390: (actual time=0.026..0.027 rows=1 loops=1)
                                                                       Node 16391: (actual time=0.027..0.028 rows=1 loops=1)
                                                                       ->  Seq Scan on public.nation nation_1  (cost=0.00..5.31 rows=1 width=4) (never executed)
                                                                             Output: nation_1.n_nationkey
                                                                             Filter: (nation_1.n_name = 'GERMANY'::bpchar)
                                                                             Remote node: 16387,16388,16389,16390,16391
                                                                             Node 16387: (actual time=0.017..0.018 rows=1 loops=1)
                                                                             Node 16388: (actual time=0.022..0.024 rows=1 loops=1)
                                                                             Node 16389: (actual time=0.021..0.022 rows=1 loops=1)
                                                                             Node 16390: (actual time=0.018..0.019 rows=1 loops=1)
                                                                             Node 16391: (actual time=0.017..0.018 rows=1 loops=1)
         ->  Finalize GroupAggregate  (cost=2131776.64..2139228.89 rows=8535 width=36) (actual time=0.000..0.001 rows=0 loops=1)
               Output: partsupp.ps_partkey, sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty)))
               Group Key: partsupp.ps_partkey
               Filter: (sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty))) > $0)
               Node 16387: (actual time=3877.902..4814.842 rows=18445 loops=1)
               Node 16388: (actual time=4251.718..5173.335 rows=18371 loops=1)
               Node 16389: (actual time=4289.395..5235.906 rows=18727 loops=1)
               Node 16390: (actual time=3766.618..4697.923 rows=18577 loops=1)
               Node 16391: (actual time=3989.700..4927.770 rows=18578 loops=1)
               ->  Gather Merge  (cost=2131776.64..2138140.72 rows=51208 width=36) (never executed)
                     Output: partsupp.ps_partkey, (PARTIAL sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty))))
                     Workers Planned: 2
                     Workers Launched: 0
                     Node 16387: (actual time=3877.521..4274.866 rows=605401 loops=1)
                     Node 16388: (actual time=4251.532..4637.770 rows=604548 loops=1)
                     Node 16389: (actual time=4289.190..4697.618 rows=604919 loops=1)
                     Node 16390: (actual time=3766.398..4159.773 rows=604275 loops=1)
                     Node 16391: (actual time=3989.473..4388.476 rows=604772 loops=1)
                     ->  Partial GroupAggregate  (cost=2130776.62..2131230.02 rows=25604 width=36) (never executed)
                           Output: partsupp.ps_partkey, PARTIAL sum((partsupp.ps_supplycost * "numeric"(partsupp.ps_availqty)))
                           Group Key: partsupp.ps_partkey
                           Node 16387: (actual time=3873.170..4121.399 rows=201800 loops=3)
                             Worker 0: actual time=3873.446..4136.176 rows=212122 loops=1
                             Worker 1: actual time=3873.158..4096.721 rows=181031 loops=1
                           Node 16388: (actual time=4242.360..4491.063 rows=201516 loops=3)
                             Worker 0: actual time=4245.830..4507.798 rows=211479 loops=1
                             Worker 1: actual time=4238.811..4512.692 rows=221822 loops=1
                           Node 16389: (actual time=4284.442..4531.898 rows=201640 loops=3)
                             Worker 0: actual time=4284.553..4541.499 rows=208948 loops=1
                             Worker 1: actual time=4284.483..4540.103 rows=207562 loops=1
                           Node 16390: (actual time=3760.232..4007.043 rows=201425 loops=3)
                             Worker 0: actual time=3757.049..3989.981 rows=189768 loops=1
                             Worker 1: actual time=3760.847..4019.354 rows=210586 loops=1
                           Node 16391: (actual time=3985.673..4234.218 rows=201591 loops=3)
                             Worker 0: actual time=3985.492..4242.020 rows=207170 loops=1
                             Worker 1: actual time=3982.776..4219.014 rows=191316 loops=1
                           ->  Sort  (cost=2130776.62..2130803.29 rows=10668 width=14) (never executed)
                                 Output: partsupp.ps_partkey, partsupp.ps_supplycost, partsupp.ps_availqty
                                 Sort Key: partsupp.ps_partkey
                                 Node 16387: (actual time=3873.153..3903.169 rows=213803 loops=3)
                                   Worker 0: actual time=3873.429..3905.363 rows=224826 loops=1
                                   Worker 1: actual time=3873.143..3899.837 rows=191729 loops=1
                                 Node 16388: (actual time=4242.333..4271.953 rows=213441 loops=3)
                                   Worker 0: actual time=4245.803..4276.615 rows=224040 loops=1
                                   Worker 1: actual time=4238.791..4271.073 rows=234934 loops=1
                                 Node 16389: (actual time=4284.421..4314.123 rows=213612 loops=3)
                                   Worker 0: actual time=4284.538..4315.236 rows=221315 loops=1
                                   Worker 1: actual time=4284.460..4315.394 rows=219930 loops=1
                                 Node 16390: (actual time=3760.216..3789.827 rows=213494 loops=3)
                                   Worker 0: actual time=3757.037..3784.909 rows=201217 loops=1
                                   Worker 1: actual time=3760.832..3791.865 rows=223240 loops=1
                                 Node 16391: (actual time=3985.654..4016.132 rows=213516 loops=3)
                                   Worker 0: actual time=3985.477..4016.849 rows=219416 loops=1
                                   Worker 1: actual time=3982.749..4011.696 rows=202659 loops=1
                                 ->  Parallel Hash Join  (cost=27483.91..2130062.88 rows=10668 width=14) (never executed)
                                       Output: partsupp.ps_partkey, partsupp.ps_supplycost, partsupp.ps_availqty
                                       Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                       Node 16387: (actual time=941.405..3799.385 rows=213803 loops=3)
                                         Worker 0: actual time=940.318..3796.284 rows=224826 loops=1
                                         Worker 1: actual time=940.321..3807.217 rows=191729 loops=1
                                       Node 16388: (actual time=39.263..4168.548 rows=213441 loops=3)
                                         Worker 0: actual time=38.103..4166.978 rows=224040 loops=1
                                         Worker 1: actual time=38.090..4158.400 rows=234934 loops=1
                                       Node 16389: (actual time=368.698..4211.821 rows=213612 loops=3)
                                         Worker 0: actual time=367.589..4209.282 rows=221315 loops=1
                                         Worker 1: actual time=367.667..4210.195 rows=219930 loops=1
                                       Node 16390: (actual time=142.941..3685.797 rows=213494 loops=3)
                                         Worker 0: actual time=141.682..3687.173 rows=201217 loops=1
                                         Worker 1: actual time=141.717..3682.773 rows=223240 loops=1
                                       Node 16391: (actual time=1338.052..3912.049 rows=213516 loops=3)
                                         Worker 0: actual time=1336.863..3910.238 rows=219416 loops=1
                                         Worker 1: actual time=1336.848..3912.610 rows=202659 loops=1
                                       ->  Parallel Seq Scan on public.partsupp  (cost=0.00..2077352.47 rows=6667769 width=18) (never executed)
                                             Output: partsupp.ps_partkey, partsupp.ps_suppkey, partsupp.ps_availqty, partsupp.ps_supplycost, partsupp.ps_comment
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16387: (actual time=0.026..1225.850 rows=5332192 loops=3)
                                               Worker 0: actual time=0.031..1244.579 rows=5607763 loops=1
                                               Worker 1: actual time=0.025..1180.763 rows=4769684 loops=1
                                             Node 16388: (actual time=0.029..1310.358 rows=5334251 loops=3)
                                               Worker 0: actual time=0.033..1370.594 rows=5607570 loops=1
                                               Worker 1: actual time=0.035..1300.414 rows=5864143 loops=1
                                             Node 16389: (actual time=0.025..1242.566 rows=5335869 loops=3)
                                               Worker 0: actual time=0.024..1246.314 rows=5523335 loops=1
                                               Worker 1: actual time=0.025..1246.939 rows=5510820 loops=1
                                             Node 16390: (actual time=0.033..1225.378 rows=5330264 loops=3)
                                               Worker 0: actual time=0.029..1176.850 rows=4993678 loops=1
                                               Worker 1: actual time=0.037..1251.422 rows=5595772 loops=1
                                             Node 16391: (actual time=0.030..1186.810 rows=5334091 loops=3)
                                               Worker 0: actual time=0.033..1195.077 rows=5465383 loops=1
                                               Worker 1: actual time=0.030..1180.481 rows=5073060 loops=1
                                       ->  Parallel Hash  (cost=27442.22..27442.22 rows=3335 width=4) (never executed)
                                             Output: supplier.s_suppkey
                                             Node 16387: (actual time=941.315..941.317 rows=13348 loops=3)
                                               Worker 0: actual time=940.245..940.247 rows=14059 loops=1
                                               Worker 1: actual time=940.240..940.242 rows=13252 loops=1
                                             Node 16388: (actual time=39.103..39.106 rows=13348 loops=3)
                                               Worker 0: actual time=37.967..37.970 rows=15113 loops=1
                                               Worker 1: actual time=37.972..37.975 rows=14108 loops=1
                                             Node 16389: (actual time=368.600..368.602 rows=13348 loops=3)
                                               Worker 0: actual time=367.518..367.520 rows=13263 loops=1
                                               Worker 1: actual time=367.581..367.583 rows=12449 loops=1
                                             Node 16390: (actual time=142.837..142.839 rows=13348 loops=3)
                                               Worker 0: actual time=141.610..141.612 rows=13954 loops=1
                                               Worker 1: actual time=141.612..141.614 rows=14039 loops=1
                                             Node 16391: (actual time=1337.956..1337.959 rows=13348 loops=3)
                                               Worker 0: actual time=1336.775..1336.778 rows=12546 loops=1
                                               Worker 1: actual time=1336.771..1336.774 rows=14227 loops=1
                                             ->  Cluster Reduce  (cost=6.33..27442.22 rows=3335 width=4) (never executed)
                                                   Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                   Node 16387: (actual time=24.472..933.321 rows=13348 loops=3)
                                                     Worker 0: actual time=23.384..932.293 rows=14059 loops=1
                                                     Worker 1: actual time=23.392..932.299 rows=13252 loops=1
                                                   Node 16388: (actual time=24.845..25.901 rows=13348 loops=3)
                                                     Worker 0: actual time=23.702..24.868 rows=15113 loops=1
                                                     Worker 1: actual time=23.702..24.798 rows=14108 loops=1
                                                   Node 16389: (actual time=26.396..353.530 rows=13348 loops=3)
                                                     Worker 0: actual time=25.302..352.432 rows=13263 loops=1
                                                     Worker 1: actual time=25.364..352.460 rows=12449 loops=1
                                                   Node 16390: (actual time=26.000..129.293 rows=13348 loops=3)
                                                     Worker 0: actual time=24.762..128.040 rows=13954 loops=1
                                                     Worker 1: actual time=24.759..128.003 rows=14039 loops=1
                                                   Node 16391: (actual time=24.973..1329.755 rows=13348 loops=3)
                                                     Worker 0: actual time=23.780..1328.843 rows=12546 loops=1
                                                     Worker 1: actual time=23.780..1328.411 rows=14227 loops=1
                                                   ->  Hash Join  (cost=5.33..26607.82 rows=667 width=4) (never executed)
                                                         Output: supplier.s_suppkey
                                                         Inner Unique: true
                                                         Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                         Node 16387: (actual time=0.051..21.273 rows=2673 loops=3)
                                                           Worker 0: actual time=0.051..20.343 rows=2600 loops=1
                                                           Worker 1: actual time=0.052..20.381 rows=2506 loops=1
                                                         Node 16388: (actual time=0.055..22.290 rows=2665 loops=3)
                                                           Worker 0: actual time=0.054..21.382 rows=2707 loops=1
                                                           Worker 1: actual time=0.055..21.412 rows=2649 loops=1
                                                         Node 16389: (actual time=0.049..23.212 rows=2710 loops=3)
                                                           Worker 0: actual time=0.046..22.580 rows=2628 loops=1
                                                           Worker 1: actual time=0.053..22.618 rows=2627 loops=1
                                                         Node 16390: (actual time=0.062..22.267 rows=2654 loops=3)
                                                           Worker 0: actual time=0.069..20.708 rows=2495 loops=1
                                                           Worker 1: actual time=0.066..20.918 rows=2580 loops=1
                                                         Node 16391: (actual time=0.051..22.194 rows=2647 loops=3)
                                                           Worker 0: actual time=0.048..21.114 rows=2724 loops=1
                                                           Worker 1: actual time=0.052..21.232 rows=2768 loops=1
                                                         ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=8) (never executed)
                                                               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16387: (actual time=0.022..12.288 rows=66574 loops=3)
                                                                 Worker 0: actual time=0.021..11.757 rows=63686 loops=1
                                                                 Worker 1: actual time=0.024..11.757 rows=63486 loops=1
                                                               Node 16388: (actual time=0.026..13.353 rows=66745 loops=3)
                                                                 Worker 0: actual time=0.029..12.423 rows=67142 loops=1
                                                                 Worker 1: actual time=0.031..12.486 rows=67259 loops=1
                                                               Node 16389: (actual time=0.023..14.222 rows=66657 loops=3)
                                                                 Worker 0: actual time=0.024..14.036 rows=63855 loops=1
                                                                 Worker 1: actual time=0.028..14.093 rows=63982 loops=1
                                                               Node 16390: (actual time=0.029..13.180 rows=66790 loops=3)
                                                                 Worker 0: actual time=0.033..11.962 rows=63678 loops=1
                                                                 Worker 1: actual time=0.034..12.059 rows=64691 loops=1
                                                               Node 16391: (actual time=0.026..12.597 rows=66568 loops=3)
                                                                 Worker 0: actual time=0.025..11.945 rows=68671 loops=1
                                                                 Worker 1: actual time=0.029..11.866 rows=69601 loops=1
                                                         ->  Hash  (cost=5.31..5.31 rows=1 width=4) (never executed)
                                                               Output: nation.n_nationkey
                                                               Node 16387: (actual time=0.017..0.018 rows=1 loops=3)
                                                                 Worker 0: actual time=0.015..0.016 rows=1 loops=1
                                                                 Worker 1: actual time=0.017..0.018 rows=1 loops=1
                                                               Node 16388: (actual time=0.021..0.021 rows=1 loops=3)
                                                                 Worker 0: actual time=0.018..0.019 rows=1 loops=1
                                                                 Worker 1: actual time=0.017..0.018 rows=1 loops=1
                                                               Node 16389: (actual time=0.018..0.018 rows=1 loops=3)
                                                                 Worker 0: actual time=0.016..0.016 rows=1 loops=1
                                                                 Worker 1: actual time=0.019..0.020 rows=1 loops=1
                                                               Node 16390: (actual time=0.022..0.023 rows=1 loops=3)
                                                                 Worker 0: actual time=0.023..0.024 rows=1 loops=1
                                                                 Worker 1: actual time=0.023..0.024 rows=1 loops=1
                                                               Node 16391: (actual time=0.017..0.018 rows=1 loops=3)
                                                                 Worker 0: actual time=0.016..0.017 rows=1 loops=1
                                                                 Worker 1: actual time=0.017..0.018 rows=1 loops=1
                                                               ->  Seq Scan on public.nation  (cost=0.00..5.31 rows=1 width=4) (never executed)
                                                                     Output: nation.n_nationkey
                                                                     Filter: (nation.n_name = 'GERMANY'::bpchar)
                                                                     Remote node: 16387,16388,16389,16390,16391
                                                                     Node 16387: (actual time=0.013..0.014 rows=1 loops=3)
                                                                       Worker 0: actual time=0.011..0.012 rows=1 loops=1
                                                                       Worker 1: actual time=0.013..0.014 rows=1 loops=1
                                                                     Node 16388: (actual time=0.015..0.017 rows=1 loops=3)
                                                                       Worker 0: actual time=0.013..0.015 rows=1 loops=1
                                                                       Worker 1: actual time=0.012..0.014 rows=1 loops=1
                                                                     Node 16389: (actual time=0.013..0.014 rows=1 loops=3)
                                                                       Worker 0: actual time=0.011..0.012 rows=1 loops=1
                                                                       Worker 1: actual time=0.014..0.015 rows=1 loops=1
                                                                     Node 16390: (actual time=0.017..0.018 rows=1 loops=3)
                                                                       Worker 0: actual time=0.018..0.019 rows=1 loops=1
                                                                       Worker 1: actual time=0.018..0.019 rows=1 loops=1
                                                                     Node 16391: (actual time=0.013..0.013 rows=1 loops=3)
                                                                       Worker 0: actual time=0.012..0.013 rows=1 loops=1
                                                                       Worker 1: actual time=0.013..0.014 rows=1 loops=1
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
               Node 16388: (actual time=23372.429..23520.743 rows=6 loops=1)
               Node 16390: (actual time=23041.398..23184.618 rows=6 loops=1)
               Node 16391: (actual time=24132.837..24280.631 rows=6 loops=1)
               Node 16387: (actual time=24084.818..24227.449 rows=6 loops=1)
               Node 16389: (actual time=25932.826..26082.208 rows=6 loops=1)
               ->  Sort  (cost=24161589.54..24161589.56 rows=7 width=27) (actual time=0.083..0.085 rows=0 loops=1)
                     Output: lineitem.l_shipmode, (PARTIAL sum(CASE WHEN ((orders.o_orderpriority = '1-URGENT'::bpchar) OR (orders.o_orderpriority = '2-HIGH'::bpchar)) THEN 1 ELSE 0 END)), (PARTIAL sum(CASE WHEN ((orders.o_orderpriority <> '1-URGENT'::bpchar) AND (orders.o_orderpriority <> '2-HIGH'::bpchar)) THEN 1 ELSE 0 END))
                     Sort Key: lineitem.l_shipmode
                     Sort Method: quicksort  Memory: 25kB
                     Node 16388: (actual time=23370.195..23370.231 rows=2 loops=3)
                       Worker 0: actual time=23369.284..23369.303 rows=2 loops=1
                       Worker 1: actual time=23369.327..23369.366 rows=2 loops=1
                     Node 16390: (actual time=23038.784..23038.818 rows=2 loops=3)
                       Worker 0: actual time=23037.722..23037.747 rows=2 loops=1
                       Worker 1: actual time=23037.630..23037.648 rows=2 loops=1
                     Node 16391: (actual time=24130.140..24130.193 rows=2 loops=3)
                       Worker 0: actual time=24128.643..24128.662 rows=2 loops=1
                       Worker 1: actual time=24129.240..24129.260 rows=2 loops=1
                     Node 16387: (actual time=24082.418..24082.551 rows=2 loops=3)
                       Worker 0: actual time=24081.387..24081.414 rows=2 loops=1
                       Worker 1: actual time=24081.487..24081.512 rows=2 loops=1
                     Node 16389: (actual time=25930.231..25930.275 rows=2 loops=3)
                       Worker 0: actual time=25929.080..25929.104 rows=2 loops=1
                       Worker 1: actual time=25929.322..25929.360 rows=2 loops=1
                     ->  Partial HashAggregate  (cost=24161589.38..24161589.45 rows=7 width=27) (actual time=0.078..0.081 rows=0 loops=1)
                           Output: lineitem.l_shipmode, PARTIAL sum(CASE WHEN ((orders.o_orderpriority = '1-URGENT'::bpchar) OR (orders.o_orderpriority = '2-HIGH'::bpchar)) THEN 1 ELSE 0 END), PARTIAL sum(CASE WHEN ((orders.o_orderpriority <> '1-URGENT'::bpchar) AND (orders.o_orderpriority <> '2-HIGH'::bpchar)) THEN 1 ELSE 0 END)
                           Group Key: lineitem.l_shipmode
                           Batches: 1  Memory Usage: 24kB
                           Node 16388: (actual time=23370.164..23370.201 rows=2 loops=3)
                             Worker 0: actual time=23369.242..23369.261 rows=2 loops=1
                             Worker 1: actual time=23369.295..23369.334 rows=2 loops=1
                           Node 16390: (actual time=23038.759..23038.793 rows=2 loops=3)
                             Worker 0: actual time=23037.691..23037.715 rows=2 loops=1
                             Worker 1: actual time=23037.601..23037.619 rows=2 loops=1
                           Node 16391: (actual time=24130.115..24130.169 rows=2 loops=3)
                             Worker 0: actual time=24128.614..24128.633 rows=2 loops=1
                             Worker 1: actual time=24129.210..24129.230 rows=2 loops=1
                           Node 16387: (actual time=24082.392..24082.526 rows=2 loops=3)
                             Worker 0: actual time=24081.352..24081.378 rows=2 loops=1
                             Worker 1: actual time=24081.456..24081.482 rows=2 loops=1
                           Node 16389: (actual time=25930.203..25930.246 rows=2 loops=3)
                             Worker 0: actual time=25929.047..25929.070 rows=2 loops=1
                             Worker 1: actual time=25929.286..25929.324 rows=2 loops=1
                           ->  Parallel Hash Join  (cost=3463721.91..24161583.81 rows=318 width=27) (actual time=0.077..0.079 rows=0 loops=1)
                                 Output: lineitem.l_shipmode, orders.o_orderpriority
                                 Inner Unique: true
                                 Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                 Node 16388: (actual time=20881.408..23292.137 rows=208004 loops=3)
                                   Worker 0: actual time=20870.282..23288.727 rows=213318 loops=1
                                   Worker 1: actual time=20885.403..23290.538 rows=212895 loops=1
                                 Node 16390: (actual time=20554.415..22959.988 rows=207863 loops=3)
                                   Worker 0: actual time=20543.306..22959.177 rows=207839 loops=1
                                   Worker 1: actual time=20557.854..22959.871 rows=206025 loops=1
                                 Node 16391: (actual time=21431.232..24051.680 rows=207578 loops=3)
                                   Worker 0: actual time=21434.931..24048.910 rows=211684 loops=1
                                   Worker 1: actual time=21435.501..24050.084 rows=209895 loops=1
                                 Node 16387: (actual time=21368.383..24004.031 rows=207265 loops=3)
                                   Worker 0: actual time=21357.023..24007.155 rows=196993 loops=1
                                   Worker 1: actual time=21372.693..24002.749 rows=208460 loops=1
                                 Node 16389: (actual time=22891.508..25851.757 rows=207737 loops=3)
                                   Worker 0: actual time=22877.902..25848.933 rows=212184 loops=1
                                   Worker 1: actual time=22897.846..25857.245 rows=191498 loops=1
                                 ->  Parallel Seq Scan on public.lineitem  (cost=0.00..20624521.00 rows=7963 width=15) (never executed)
                                       Output: lineitem.l_shipmode, lineitem.l_orderkey
                                       Filter: ((lineitem.l_shipmode = ANY ('{MAIL,SHIP}'::bpchar[])) AND ((lineitem.l_receiptdate)::timestamp without time zone >= '1994-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_receiptdate)::timestamp without time zone < '1995-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_commitdate)::timestamp without time zone < (lineitem.l_receiptdate)::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < (lineitem.l_commitdate)::timestamp without time zone))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16388: (actual time=0.165..14986.485 rows=208004 loops=3)
                                         Worker 0: actual time=0.155..14976.425 rows=215854 loops=1
                                         Worker 1: actual time=0.228..14979.309 rows=217626 loops=1
                                       Node 16390: (actual time=0.221..14946.347 rows=207863 loops=3)
                                         Worker 0: actual time=0.272..14946.796 rows=209843 loops=1
                                         Worker 1: actual time=0.270..14946.638 rows=210326 loops=1
                                       Node 16391: (actual time=0.178..15718.656 rows=207578 loops=3)
                                         Worker 0: actual time=0.112..15715.633 rows=207285 loops=1
                                         Worker 1: actual time=0.366..15715.897 rows=207687 loops=1
                                       Node 16387: (actual time=0.377..15770.605 rows=207265 loops=3)
                                         Worker 0: actual time=0.328..15765.853 rows=196833 loops=1
                                         Worker 1: actual time=0.200..15773.520 rows=209170 loops=1
                                       Node 16389: (actual time=0.164..17054.476 rows=207737 loops=3)
                                         Worker 0: actual time=0.133..17061.015 rows=202165 loops=1
                                         Worker 1: actual time=0.137..17035.360 rows=217050 loops=1
                                 ->  Parallel Hash  (cost=3234231.13..3234231.13 rows=12499902 width=20) (actual time=0.053..0.055 rows=0 loops=1)
                                       Output: orders.o_orderpriority, orders.o_orderkey
                                       Buckets: 65536  Batches: 512  Memory Usage: 512kB
                                       Node 16388: (actual time=5734.186..5734.187 rows=10001059 loops=3)
                                         Worker 0: actual time=5733.341..5733.342 rows=9695572 loops=1
                                         Worker 1: actual time=5733.353..5733.354 rows=10146099 loops=1
                                       Node 16390: (actual time=5459.002..5459.003 rows=9999806 loops=3)
                                         Worker 0: actual time=5457.972..5457.973 rows=9846505 loops=1
                                         Worker 1: actual time=5457.958..5457.959 rows=10010592 loops=1
                                       Node 16391: (actual time=5551.319..5551.319 rows=10000065 loops=3)
                                         Worker 0: actual time=5549.982..5549.983 rows=10205564 loops=1
                                         Worker 1: actual time=5550.567..5550.568 rows=10042138 loops=1
                                       Node 16387: (actual time=5436.452..5436.453 rows=9998956 loops=3)
                                         Worker 0: actual time=5435.529..5435.530 rows=9882500 loops=1
                                         Worker 1: actual time=5435.544..5435.545 rows=9877494 loops=1
                                       Node 16389: (actual time=5674.746..5674.747 rows=10000114 loops=3)
                                         Worker 0: actual time=5673.708..5673.708 rows=10058034 loops=1
                                         Worker 1: actual time=5673.802..5673.803 rows=9832011 loops=1
                                       ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=20) (actual time=0.053..0.053 rows=0 loops=1)
                                             Output: orders.o_orderpriority, orders.o_orderkey
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16388: (actual time=0.023..3059.039 rows=10001059 loops=3)
                                               Worker 0: actual time=0.020..3011.660 rows=9695572 loops=1
                                               Worker 1: actual time=0.025..3040.963 rows=10146099 loops=1
                                             Node 16390: (actual time=0.025..2758.632 rows=9999806 loops=3)
                                               Worker 0: actual time=0.026..2694.726 rows=9846505 loops=1
                                               Worker 1: actual time=0.027..2748.057 rows=10010592 loops=1
                                             Node 16391: (actual time=0.027..2905.321 rows=10000065 loops=3)
                                               Worker 0: actual time=0.024..2861.275 rows=10205564 loops=1
                                               Worker 1: actual time=0.026..2880.343 rows=10042138 loops=1
                                             Node 16387: (actual time=0.028..2830.451 rows=9998956 loops=3)
                                               Worker 0: actual time=0.026..2826.684 rows=9882500 loops=1
                                               Worker 1: actual time=0.027..2869.451 rows=9877494 loops=1
                                             Node 16389: (actual time=0.031..3082.749 rows=10000114 loops=3)
                                               Worker 0: actual time=0.022..3045.597 rows=10058034 loops=1
                                               Worker 1: actual time=0.028..3083.316 rows=9832011 loops=1
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
         Node 16390: (actual time=31459.335..31669.994 rows=12 loops=1)
         Node 16391: (actual time=31459.333..31663.345 rows=12 loops=1)
         Node 16387: (actual time=31459.288..31613.251 rows=9 loops=1)
         Node 16388: (actual time=31459.328..31712.061 rows=5 loops=1)
         Node 16389: (actual time=31501.812..31726.132 rows=7 loops=1)
         ->  Finalize GroupAggregate  (cost=5390188.34..5390190.24 rows=40 width=16) (actual time=0.000..0.003 rows=0 loops=1)
               Output: (count(orders.o_orderkey)), count(*)
               Group Key: (count(orders.o_orderkey))
               Node 16390: (actual time=31459.301..31669.972 rows=12 loops=1)
               Node 16391: (actual time=31459.299..31663.322 rows=12 loops=1)
               Node 16387: (actual time=31459.259..31613.231 rows=9 loops=1)
               Node 16388: (actual time=31459.300..31712.038 rows=5 loops=1)
               Node 16389: (actual time=31501.782..31726.110 rows=7 loops=1)
               ->  Sort  (cost=5390188.34..5390188.84 rows=200 width=16) (never executed)
                     Output: (count(orders.o_orderkey)), (PARTIAL count(*))
                     Sort Key: (count(orders.o_orderkey)) DESC
                     Node 16390: (actual time=31459.292..31669.953 rows=56 loops=1)
                     Node 16391: (actual time=31459.292..31663.306 rows=60 loops=1)
                     Node 16387: (actual time=31459.253..31613.218 rows=44 loops=1)
                     Node 16388: (actual time=31459.293..31712.027 rows=25 loops=1)
                     Node 16389: (actual time=31501.770..31726.092 rows=35 loops=1)
                     ->  Cluster Reduce  (cost=5390160.70..5390180.70 rows=200 width=16) (never executed)
                           Reduce: ('[0:4]={16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint8((count(orders.o_orderkey)))), 0)]
                           Node 16390: (actual time=31416.670..31669.933 rows=56 loops=1)
                           Node 16391: (actual time=31414.736..31663.282 rows=60 loops=1)
                           Node 16387: (actual time=31459.205..31613.204 rows=44 loops=1)
                           Node 16388: (actual time=31412.596..31712.005 rows=25 loops=1)
                           Node 16389: (actual time=31412.435..31726.073 rows=35 loops=1)
                           ->  Partial HashAggregate  (cost=5390159.70..5390161.70 rows=200 width=16) (never executed)
                                 Output: (count(orders.o_orderkey)), PARTIAL count(*)
                                 Group Key: count(orders.o_orderkey)
                                 Node 16390: (actual time=31416.521..31627.188 rows=44 loops=1)
                                 Node 16391: (actual time=31414.568..31618.588 rows=44 loops=1)
                                 Node 16387: (actual time=31459.033..31613.005 rows=45 loops=1)
                                 Node 16388: (actual time=31412.474..31665.214 rows=44 loops=1)
                                 Node 16389: (actual time=31412.282..31636.611 rows=43 loops=1)
                                 ->  Finalize GroupAggregate  (cost=5110319.78..5345158.83 rows=600012 width=12) (never executed)
                                       Output: customer.c_custkey, count(orders.o_orderkey)
                                       Group Key: customer.c_custkey
                                       Node 16390: (actual time=29551.100..31170.064 rows=3002261 loops=1)
                                       Node 16391: (actual time=29551.038..31162.667 rows=2999921 loops=1)
                                       Node 16387: (actual time=29593.273..31152.404 rows=3001614 loops=1)
                                       Node 16388: (actual time=29551.192..31206.028 rows=2998456 loops=1)
                                       Node 16389: (actual time=29550.899..31179.242 rows=2997748 loops=1)
                                       ->  Cluster Merge Reduce  (cost=5110319.78..5334259.76 rows=979790 width=12) (never executed)
                                             Reduce: ('[0:4]={16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(customer.c_custkey)), 0)]
                                             Sort Key: customer.c_custkey
                                             Node 16390: (actual time=29551.092..30062.026 rows=3002261 loops=1)
                                             Node 16391: (actual time=29551.028..30050.275 rows=2999921 loops=1)
                                             Node 16387: (actual time=29593.261..30044.211 rows=3001614 loops=1)
                                             Node 16388: (actual time=29551.184..30100.257 rows=2998456 loops=1)
                                             Node 16389: (actual time=29550.892..30072.423 rows=2997748 loops=1)
                                             ->  Gather Merge  (cost=5110318.72..5231983.96 rows=979790 width=12) (never executed)
                                                   Output: customer.c_custkey, (PARTIAL count(orders.o_orderkey))
                                                   Workers Planned: 2
                                                   Workers Launched: 0
                                                   Node 16390: (actual time=21985.879..25718.698 rows=2997748 loops=1)
                                                   Node 16391: (actual time=21900.807..25637.676 rows=2999921 loops=1)
                                                   Node 16387: (actual time=22228.968..26021.936 rows=2998456 loops=1)
                                                   Node 16388: (actual time=22111.318..25948.859 rows=3002261 loops=1)
                                                   Node 16389: (actual time=22690.463..26592.901 rows=3001614 loops=1)
                                                   ->  Partial GroupAggregate  (cost=5109318.69..5117891.86 rows=489895 width=12) (never executed)
                                                         Output: customer.c_custkey, PARTIAL count(orders.o_orderkey)
                                                         Group Key: customer.c_custkey
                                                         Node 16390: (actual time=21895.459..24732.756 rows=999249 loops=3)
                                                           Worker 0: actual time=21843.573..24617.521 rows=983574 loops=1
                                                           Worker 1: actual time=21981.899..24894.402 rows=1031545 loops=1
                                                         Node 16391: (actual time=21852.663..24680.948 rows=999974 loops=3)
                                                           Worker 0: actual time=21891.501..24757.784 rows=1016083 loops=1
                                                           Worker 1: actual time=21765.992..24505.023 rows=970876 loops=1
                                                         Node 16387: (actual time=22174.762..25022.301 rows=999485 loops=3)
                                                           Worker 0: actual time=22115.638..24906.024 rows=985561 loops=1
                                                           Worker 1: actual time=22179.969..24974.161 rows=985421 loops=1
                                                         Node 16388: (actual time=22058.025..24910.636 rows=1000754 loops=3)
                                                           Worker 0: actual time=22107.694..25006.929 rows=1020084 loops=1
                                                           Worker 1: actual time=22010.051..24804.089 rows=986265 loops=1
                                                         Node 16389: (actual time=22504.342..25338.563 rows=1000538 loops=3)
                                                           Worker 0: actual time=22412.303..25140.825 rows=970088 loops=1
                                                           Worker 1: actual time=22410.572..25139.554 rows=971093 loops=1
                                                         ->  Sort  (cost=5109318.69..5110543.43 rows=489895 width=8) (never executed)
                                                               Output: customer.c_custkey, orders.o_orderkey
                                                               Sort Key: customer.c_custkey
                                                               Node 16390: (actual time=21895.448..23251.199 rows=10217618 loops=3)
                                                                 Worker 0: actual time=21843.558..23178.933 rows=10048791 loops=1
                                                                 Worker 1: actual time=21981.887..23384.131 rows=10544865 loops=1
                                                               Node 16391: (actual time=21852.649..23207.385 rows=10227636 loops=3)
                                                                 Worker 0: actual time=21891.486..23268.873 rows=10392103 loops=1
                                                                 Worker 1: actual time=21765.977..23084.677 rows=9914424 loops=1
                                                               Node 16387: (actual time=22174.749..23538.692 rows=10214035 loops=3)
                                                                 Worker 0: actual time=22115.627..23460.070 rows=10082608 loops=1
                                                                 Worker 1: actual time=22179.953..23532.714 rows=10055687 loops=1
                                                               Node 16388: (actual time=22058.007..23424.965 rows=10236304 loops=3)
                                                                 Worker 0: actual time=22107.673..23509.520 rows=10440295 loops=1
                                                                 Worker 1: actual time=22010.036..23358.097 rows=10084737 loops=1
                                                               Node 16389: (actual time=22504.332..23853.800 rows=10231922 loops=3)
                                                                 Worker 0: actual time=22412.297..23722.188 rows=9921072 loops=1
                                                                 Worker 1: actual time=22410.561..23719.161 rows=9926615 loops=1
                                                               ->  Parallel Hash Left Join  (cost=4545851.67..5056319.44 rows=489895 width=8) (never executed)
                                                                     Output: customer.c_custkey, orders.o_orderkey
                                                                     Hash Cond: (customer.c_custkey = orders.o_custkey)
                                                                     Node 16390: (actual time=13427.393..17654.201 rows=10217618 loops=3)
                                                                       Worker 0: actual time=13430.245..17699.598 rows=10048791 loops=1
                                                                       Worker 1: actual time=13417.917..17558.982 rows=10544865 loops=1
                                                                     Node 16391: (actual time=13517.948..17666.323 rows=10227636 loops=3)
                                                                       Worker 0: actual time=13507.243..17613.092 rows=10392103 loops=1
                                                                       Worker 1: actual time=13521.694..17769.360 rows=9914424 loops=1
                                                                     Node 16387: (actual time=13781.242..17979.615 rows=10214035 loops=3)
                                                                       Worker 0: actual time=13771.188..18055.400 rows=10082608 loops=1
                                                                       Worker 1: actual time=13784.634..17972.622 rows=10055687 loops=1
                                                                     Node 16388: (actual time=13659.253..17889.978 rows=10236304 loops=3)
                                                                       Worker 0: actual time=13663.656..17821.591 rows=10440295 loops=1
                                                                       Worker 1: actual time=13662.621..17963.943 rows=10084737 loops=1
                                                                     Node 16389: (actual time=13680.573..18320.345 rows=10231922 loops=3)
                                                                       Worker 0: actual time=13684.349..18346.674 rows=9921072 loops=1
                                                                       Worker 1: actual time=13684.273..18429.628 rows=9926615 loops=1
                                                                     ->  Parallel Seq Scan on public.customer  (cost=0.00..420778.20 rows=1250024 width=4) (never executed)
                                                                           Output: customer.c_custkey
                                                                           Remote node: 16389,16387,16390,16388,16391
                                                                           Node 16390: (actual time=0.051..312.025 rows=999249 loops=3)
                                                                             Worker 0: actual time=0.065..311.374 rows=1009493 loops=1
                                                                             Worker 1: actual time=0.049..312.736 rows=978781 loops=1
                                                                           Node 16391: (actual time=0.052..312.066 rows=999974 loops=3)
                                                                             Worker 0: actual time=0.056..312.579 rows=999499 loops=1
                                                                             Worker 1: actual time=0.056..310.811 rows=1007254 loops=1
                                                                           Node 16387: (actual time=0.047..323.523 rows=999485 loops=3)
                                                                             Worker 0: actual time=0.071..329.612 rows=963597 loops=1
                                                                             Worker 1: actual time=0.042..327.129 rows=995416 loops=1
                                                                           Node 16388: (actual time=0.060..364.905 rows=1000754 loops=3)
                                                                             Worker 0: actual time=0.069..370.555 rows=960660 loops=1
                                                                             Worker 1: actual time=0.057..361.427 rows=1045411 loops=1
                                                                           Node 16389: (actual time=0.048..328.874 rows=1000538 loops=3)
                                                                             Worker 0: actual time=0.047..328.538 rows=991070 loops=1
                                                                             Worker 1: actual time=0.045..320.578 rows=1051661 loops=1
                                                                     ->  Parallel Hash  (cost=4344917.42..4344917.42 rows=12247380 width=8) (never executed)
                                                                           Output: orders.o_orderkey, orders.o_custkey
                                                                           Node 16390: (actual time=12844.425..12844.426 rows=9884326 loops=3)
                                                                             Worker 0: actual time=12843.180..12843.181 rows=9914528 loops=1
                                                                             Worker 1: actual time=12843.411..12843.412 rows=9832000 loops=1
                                                                           Node 16391: (actual time=12924.339..12924.340 rows=9894514 loops=3)
                                                                             Worker 0: actual time=12923.402..12923.403 rows=9829130 loops=1
                                                                             Worker 1: actual time=12923.424..12923.425 rows=9928556 loops=1
                                                                           Node 16387: (actual time=13164.766..13164.767 rows=9880427 loops=3)
                                                                             Worker 0: actual time=13163.818..13163.819 rows=9883475 loops=1
                                                                             Worker 1: actual time=13163.826..13163.827 rows=9955340 loops=1
                                                                           Node 16388: (actual time=12992.287..12992.288 rows=9902857 loops=3)
                                                                             Worker 0: actual time=12991.336..12991.337 rows=9535297 loops=1
                                                                             Worker 1: actual time=12991.328..12991.329 rows=10096472 loops=1
                                                                           Node 16389: (actual time=13052.038..13052.039 rows=9898664 loops=3)
                                                                             Worker 0: actual time=13051.112..13051.113 rows=9782252 loops=1
                                                                             Worker 1: actual time=13051.116..13051.117 rows=9916740 loops=1
                                                                           ->  Cluster Reduce  (cost=1.00..4344917.42 rows=12247380 width=8) (never executed)
                                                                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                                                 Node 16390: (actual time=10334.837..11189.050 rows=9884326 loops=3)
                                                                                   Worker 0: actual time=10333.586..11185.883 rows=9914528 loops=1
                                                                                   Worker 1: actual time=10333.778..11191.734 rows=9832000 loops=1
                                                                                 Node 16391: (actual time=10420.450..11246.269 rows=9894514 loops=3)
                                                                                   Worker 0: actual time=10419.494..11245.403 rows=9829130 loops=1
                                                                                   Worker 1: actual time=10419.503..11248.014 rows=9928556 loops=1
                                                                                 Node 16387: (actual time=10636.603..11477.342 rows=9880427 loops=3)
                                                                                   Worker 0: actual time=10635.630..11445.655 rows=9883475 loops=1
                                                                                   Worker 1: actual time=10635.644..11500.822 rows=9955340 loops=1
                                                                                 Node 16388: (actual time=10441.615..11286.843 rows=9902857 loops=3)
                                                                                   Worker 0: actual time=10440.627..11271.404 rows=9535297 loops=1
                                                                                   Worker 1: actual time=10440.597..11266.859 rows=10096472 loops=1
                                                                                 Node 16389: (actual time=10544.984..11367.954 rows=9898664 loops=3)
                                                                                   Worker 0: actual time=10544.026..11340.586 rows=9782252 loops=1
                                                                                   Worker 1: actual time=10544.026..11348.441 rows=9916740 loops=1
                                                                                 ->  Parallel Seq Scan on public.orders  (cost=0.00..3390479.92 rows=12247380 width=8) (never executed)
                                                                                       Output: orders.o_orderkey, orders.o_custkey
                                                                                       Filter: ((orders.o_comment)::text !~~ '%special%requests%'::text)
                                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                                       Node 16390: (actual time=0.038..4568.127 rows=9891880 loops=3)
                                                                                         Worker 0: actual time=0.041..4566.570 rows=10009408 loops=1
                                                                                         Worker 1: actual time=0.035..4501.120 rows=9346775 loops=1
                                                                                       Node 16391: (actual time=0.033..4860.390 rows=9892364 loops=3)
                                                                                         Worker 0: actual time=0.024..4744.968 rows=9877256 loops=1
                                                                                         Worker 1: actual time=0.032..4828.091 rows=10284882 loops=1
                                                                                       Node 16387: (actual time=0.030..4635.350 rows=9891408 loops=3)
                                                                                         Worker 0: actual time=0.030..4583.438 rows=9456142 loops=1
                                                                                         Worker 1: actual time=0.032..4610.375 rows=9835776 loops=1
                                                                                       Node 16388: (actual time=0.025..4875.480 rows=9893131 loops=3)
                                                                                         Worker 0: actual time=0.025..4807.160 rows=9586888 loops=1
                                                                                         Worker 1: actual time=0.021..5121.652 rows=10593285 loops=1
                                                                                       Node 16389: (actual time=0.035..4776.145 rows=9892004 loops=3)
                                                                                         Worker 0: actual time=0.030..4750.637 rows=9878886 loops=1
                                                                                         Worker 1: actual time=0.033..4744.938 rows=9853806 loops=1
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
               Node 16390: (actual time=13413.223..13456.268 rows=3 loops=1)
               Node 16391: (actual time=13418.993..13461.940 rows=3 loops=1)
               Node 16387: (actual time=13451.843..13500.131 rows=3 loops=1)
               Node 16388: (actual time=13463.063..13513.690 rows=3 loops=1)
               Node 16389: (actual time=13481.153..13518.072 rows=3 loops=1)
               ->  Partial Aggregate  (cost=16808855.73..16808855.74 rows=1 width=40) (actual time=0.034..0.035 rows=1 loops=1)
                     Output: PARTIAL sum(CASE WHEN ((part.p_type)::text ~~ 'PROMO%'::text) THEN int4((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) ELSE 0 END), PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Node 16390: (actual time=13410.341..13410.376 rows=1 loops=3)
                       Worker 0: actual time=13408.814..13408.823 rows=1 loops=1
                       Worker 1: actual time=13409.396..13409.405 rows=1 loops=1
                     Node 16391: (actual time=13415.964..13415.998 rows=1 loops=3)
                       Worker 0: actual time=13414.794..13414.802 rows=1 loops=1
                       Worker 1: actual time=13414.506..13414.513 rows=1 loops=1
                     Node 16387: (actual time=13449.450..13449.491 rows=1 loops=3)
                       Worker 0: actual time=13448.370..13448.379 rows=1 loops=1
                       Worker 1: actual time=13448.488..13448.494 rows=1 loops=1
                     Node 16388: (actual time=13460.529..13460.564 rows=1 loops=3)
                       Worker 0: actual time=13459.738..13459.745 rows=1 loops=1
                       Worker 1: actual time=13459.176..13459.184 rows=1 loops=1
                     Node 16389: (actual time=13478.923..13478.977 rows=1 loops=3)
                       Worker 0: actual time=13477.578..13477.586 rows=1 loops=1
                       Worker 1: actual time=13478.438..13478.444 rows=1 loops=1
                     ->  Parallel Hash Join  (cost=525160.23..16808636.15 rows=8783 width=33) (actual time=0.031..0.031 rows=0 loops=1)
                           Output: part.p_type, lineitem.l_extendedprice, lineitem.l_discount
                           Inner Unique: true
                           Hash Cond: (lineitem.l_partkey = part.p_partkey)
                           Node 16390: (actual time=12638.520..13126.218 rows=499027 loops=3)
                             Worker 0: actual time=12632.140..13120.258 rows=506766 loops=1
                             Worker 1: actual time=12640.015..13128.444 rows=493498 loops=1
                           Node 16391: (actual time=12599.584..13131.736 rows=499304 loops=3)
                             Worker 0: actual time=12592.634..13125.550 rows=508383 loops=1
                             Worker 1: actual time=12601.368..13127.069 rows=504690 loops=1
                           Node 16387: (actual time=12651.671..13165.829 rows=498651 loops=3)
                             Worker 0: actual time=12653.703..13160.224 rows=506417 loops=1
                             Worker 1: actual time=12644.675..13159.860 rows=507395 loops=1
                           Node 16388: (actual time=12653.517..13176.610 rows=498875 loops=3)
                             Worker 0: actual time=12646.724..13185.063 rows=482876 loops=1
                             Worker 1: actual time=12655.511..13172.186 rows=504207 loops=1
                           Node 16389: (actual time=12643.844..13194.767 rows=498897 loops=3)
                             Worker 0: actual time=12645.761..13193.179 rows=499154 loops=1
                             Worker 1: actual time=12645.904..13193.729 rows=500121 loops=1
                           ->  Cluster Reduce  (cost=1.00..16268984.63 rows=250012 width=16) (never executed)
                                 Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_partkey)), 0)]
                                 Node 16390: (actual time=0.136..11697.028 rows=499027 loops=3)
                                   Worker 0: actual time=0.150..11686.972 rows=495099 loops=1
                                   Worker 1: actual time=0.125..11703.501 rows=501756 loops=1
                                 Node 16391: (actual time=0.188..11642.614 rows=499304 loops=3)
                                   Worker 0: actual time=0.095..11650.844 rows=503334 loops=1
                                   Worker 1: actual time=0.247..11632.649 rows=505505 loops=1
                                 Node 16387: (actual time=0.249..11734.434 rows=498651 loops=3)
                                   Worker 0: actual time=0.366..11730.286 rows=498906 loops=1
                                   Worker 1: actual time=0.241..11729.202 rows=499370 loops=1
                                 Node 16388: (actual time=0.107..11724.053 rows=498875 loops=3)
                                   Worker 0: actual time=0.087..11732.603 rows=494367 loops=1
                                   Worker 1: actual time=0.101..11719.630 rows=498772 loops=1
                                 Node 16389: (actual time=0.111..11710.424 rows=498897 loops=3)
                                   Worker 0: actual time=0.094..11699.837 rows=503126 loops=1
                                   Worker 1: actual time=0.111..11698.008 rows=508107 loops=1
                                 ->  Parallel Seq Scan on public.lineitem  (cost=0.00..16249314.73 rows=250012 width=16) (never executed)
                                       Output: lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_partkey
                                       Filter: (((lineitem.l_shipdate)::timestamp without time zone >= '1995-09-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < '1995-10-01 00:00:00'::timestamp without time zone))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16390: (actual time=0.084..9761.601 rows=499733 loops=3)
                                         Worker 0: actual time=0.117..9729.690 rows=480368 loops=1
                                         Worker 1: actual time=0.077..9761.232 rows=513616 loops=1
                                       Node 16391: (actual time=0.069..10728.838 rows=498453 loops=3)
                                         Worker 0: actual time=0.059..10710.801 rows=519612 loops=1
                                         Worker 1: actual time=0.081..10661.183 rows=528719 loops=1
                                       Node 16387: (actual time=0.052..10009.425 rows=498584 loops=3)
                                         Worker 0: actual time=0.062..9928.114 rows=499274 loops=1
                                         Worker 1: actual time=0.060..9908.754 rows=501399 loops=1
                                       Node 16388: (actual time=0.063..10680.763 rows=498833 loops=3)
                                         Worker 0: actual time=0.056..10527.384 rows=475689 loops=1
                                         Worker 1: actual time=0.070..10736.029 rows=498548 loops=1
                                       Node 16389: (actual time=0.077..10466.853 rows=499150 loops=3)
                                         Worker 0: actual time=0.060..10274.461 rows=521126 loops=1
                                         Worker 1: actual time=0.074..10580.629 rows=544371 loops=1
                           ->  Parallel Hash  (cost=492932.18..492932.18 rows=1666644 width=25) (actual time=0.007..0.007 rows=0 loops=1)
                                 Output: part.p_type, part.p_partkey
                                 Buckets: 65536  Batches: 128  Memory Usage: 512kB
                                 Node 16390: (actual time=722.476..722.477 rows=1332566 loops=3)
                                   Worker 0: actual time=721.307..721.307 rows=1358547 loops=1
                                   Worker 1: actual time=721.278..721.279 rows=1338482 loops=1
                                 Node 16391: (actual time=729.838..729.839 rows=1333523 loops=3)
                                   Worker 0: actual time=728.662..728.663 rows=1347569 loops=1
                                   Worker 1: actual time=728.670..728.671 rows=1342649 loops=1
                                 Node 16387: (actual time=712.280..712.281 rows=1333048 loops=3)
                                   Worker 0: actual time=711.260..711.261 rows=1328983 loops=1
                                   Worker 1: actual time=711.259..711.259 rows=1326230 loops=1
                                 Node 16388: (actual time=718.897..718.898 rows=1333563 loops=3)
                                   Worker 0: actual time=717.849..717.850 rows=1328581 loops=1
                                   Worker 1: actual time=717.838..717.838 rows=1306453 loops=1
                                 Node 16389: (actual time=720.204..720.205 rows=1333967 loops=3)
                                   Worker 0: actual time=719.240..719.241 rows=1398750 loops=1
                                   Worker 1: actual time=719.434..719.435 rows=1337512 loops=1
                                 ->  Parallel Seq Scan on public.part  (cost=0.00..492932.18 rows=1666644 width=25) (actual time=0.005..0.005 rows=0 loops=1)
                                       Output: part.p_type, part.p_partkey
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16390: (actual time=0.009..402.527 rows=1332566 loops=3)
                                         Worker 0: actual time=0.008..388.609 rows=1358547 loops=1
                                         Worker 1: actual time=0.007..387.131 rows=1338482 loops=1
                                       Node 16391: (actual time=0.011..402.704 rows=1333523 loops=3)
                                         Worker 0: actual time=0.011..399.150 rows=1347569 loops=1
                                         Worker 1: actual time=0.013..398.974 rows=1342649 loops=1
                                       Node 16387: (actual time=0.011..405.124 rows=1333048 loops=3)
                                         Worker 0: actual time=0.013..405.543 rows=1328983 loops=1
                                         Worker 1: actual time=0.012..405.576 rows=1326230 loops=1
                                       Node 16388: (actual time=0.009..405.926 rows=1333563 loops=3)
                                         Worker 0: actual time=0.006..398.271 rows=1328581 loops=1
                                         Worker 1: actual time=0.007..402.326 rows=1306453 loops=1
                                       Node 16389: (actual time=0.007..401.926 rows=1333967 loops=3)
                                         Worker 0: actual time=0.004..387.144 rows=1398750 loops=1
                                         Worker 1: actual time=0.006..386.529 rows=1337512 loops=1
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
         Node 16388: (actual time=16750.098..16750.187 rows=0 loops=1)
         Node 16389: (actual time=16677.832..16677.915 rows=0 loops=1)
         Node 16390: (actual time=16753.172..16753.272 rows=0 loops=1)
         Node 16391: (actual time=16747.615..16747.702 rows=0 loops=1)
         Node 16387: (actual time=16799.881..16800.002 rows=1 loops=1)
         InitPlan 1 (returns $0)
           ->  Cluster Reduce  (cost=16404776.49..16404779.80 rows=1 width=32) (never executed)
                 Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                 Node 16388: (actual time=0.076..0.152 rows=1 loops=1)
                 Node 16389: (actual time=0.080..0.154 rows=1 loops=1)
                 Node 16390: (actual time=0.079..0.179 rows=1 loops=1)
                 Node 16391: (actual time=0.061..0.154 rows=1 loops=1)
                 Node 16387: (actual time=0.092..0.191 rows=1 loops=1)
                 ->  Finalize Aggregate  (cost=16404775.49..16404775.50 rows=1 width=32) (actual time=16648.624..16648.626 rows=1 loops=1)
                       Output: max((sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))))
                       Node 16388: (actual time=0.001..0.068 rows=0 loops=1)
                       Node 16389: (actual time=0.000..0.062 rows=0 loops=1)
                       Node 16390: (actual time=0.000..0.080 rows=0 loops=1)
                       Node 16391: (actual time=0.000..0.065 rows=0 loops=1)
                       Node 16387: (actual time=0.001..0.099 rows=0 loops=1)
                       ->  Cluster Reduce  (cost=16404770.97..16404775.48 rows=5 width=32) (actual time=0.033..16648.610 rows=6 loops=1)
                             Reduce: '12338'::oid
                             Node 16388: (never executed)
                             Node 16389: (never executed)
                             Node 16390: (never executed)
                             Node 16391: (never executed)
                             Node 16387: (never executed)
                             ->  Partial Aggregate  (cost=16404769.97..16404769.98 rows=1 width=32) (actual time=0.006..0.007 rows=1 loops=1)
                                   Output: PARTIAL max((sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))))
                                   Node 16388: (actual time=1967.228..1967.296 rows=1 loops=1)
                                   Node 16389: (actual time=1919.734..1919.795 rows=1 loops=1)
                                   Node 16390: (actual time=1804.779..1804.858 rows=1 loops=1)
                                   Node 16391: (actual time=2275.738..2275.802 rows=1 loops=1)
                                   Node 16387: (actual time=2674.263..2674.362 rows=1 loops=1)
                                   ->  Finalize GroupAggregate  (cost=16277004.94..16399139.71 rows=90084 width=36) (actual time=0.000..0.001 rows=0 loops=1)
                                         Output: lineitem_1.l_suppkey, sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))
                                         Group Key: lineitem_1.l_suppkey
                                         Node 16388: (actual time=178.522..1949.105 rows=200234 loops=1)
                                         Node 16389: (actual time=121.493..1901.690 rows=199970 loops=1)
                                         Node 16390: (actual time=0.099..1786.707 rows=200370 loops=1)
                                         Node 16391: (actual time=495.584..2257.741 rows=199703 loops=1)
                                         Node 16387: (actual time=890.135..2656.212 rows=199723 loops=1)
                                         ->  Cluster Merge Reduce  (cost=16277004.94..16394263.47 rows=500024 width=36) (never executed)
                                               Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem_1.l_suppkey)), 0)]
                                               Sort Key: lineitem_1.l_suppkey
                                               Node 16388: (actual time=178.500..567.120 rows=2340289 loops=1)
                                               Node 16389: (actual time=121.478..530.455 rows=2337989 loops=1)
                                               Node 16390: (actual time=0.080..405.615 rows=2342349 loops=1)
                                               Node 16391: (actual time=495.565..891.382 rows=2335708 loops=1)
                                               Node 16387: (actual time=890.111..1293.108 rows=2334528 loops=1)
                                               ->  Gather Merge  (cost=16277003.88..16340969.36 rows=500024 width=36) (never executed)
                                                     Output: lineitem_1.l_suppkey, (PARTIAL sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount))))
                                                     Workers Planned: 2
                                                     Workers Launched: 0
                                                     Node 16388: (actual time=11117.162..13343.145 rows=2339461 loops=1)
                                                     Node 16389: (actual time=11171.715..13276.060 rows=2336840 loops=1)
                                                     Node 16390: (actual time=11019.258..13279.782 rows=2336540 loops=1)
                                                     Node 16391: (actual time=10561.342..12908.023 rows=2339221 loops=1)
                                                     Node 16387: (actual time=10238.651..12482.634 rows=2338801 loops=1)
                                                     ->  Partial GroupAggregate  (cost=16276003.86..16282254.16 rows=250012 width=36) (never executed)
                                                           Output: lineitem_1.l_suppkey, PARTIAL sum((lineitem_1.l_extendedprice * ('1'::numeric - lineitem_1.l_discount)))
                                                           Group Key: lineitem_1.l_suppkey
                                                           Node 16388: (actual time=11107.323..12633.119 rows=779820 loops=3)
                                                             Worker 0: actual time=11100.952..12583.777 rows=771984 loops=1
                                                             Worker 1: actual time=11104.067..12596.200 rows=775794 loops=1
                                                           Node 16389: (actual time=11161.375..12685.325 rows=778947 loops=3)
                                                             Worker 0: actual time=11164.426..12695.806 rows=784985 loops=1
                                                             Worker 1: actual time=11168.517..12722.738 rows=791693 loops=1
                                                           Node 16390: (actual time=11013.084..12556.916 rows=778847 loops=3)
                                                             Worker 0: actual time=11008.173..12522.708 rows=780071 loops=1
                                                             Worker 1: actual time=11012.012..12509.013 rows=759407 loops=1
                                                           Node 16391: (actual time=10555.151..12120.047 rows=779740 loops=3)
                                                             Worker 0: actual time=10557.894..12090.363 rows=785849 loops=1
                                                             Worker 1: actual time=10549.803..12044.783 rows=776520 loops=1
                                                           Node 16387: (actual time=10235.630..11768.691 rows=779600 loops=3)
                                                             Worker 0: actual time=10235.163..11745.455 rows=777180 loops=1
                                                             Worker 1: actual time=10234.849..11743.661 rows=776339 loops=1
                                                           ->  Sort  (cost=16276003.86..16276628.89 rows=250012 width=16) (never executed)
                                                                 Output: lineitem_1.l_suppkey, lineitem_1.l_extendedprice, lineitem_1.l_discount
                                                                 Sort Key: lineitem_1.l_suppkey
                                                                 Node 16388: (actual time=11107.302..11378.801 rows=1512404 loops=3)
                                                                   Worker 0: actual time=11100.940..11365.016 rows=1476764 loops=1
                                                                   Worker 1: actual time=11104.047..11367.335 rows=1493845 loops=1
                                                                 Node 16389: (actual time=11161.354..11430.444 rows=1512864 loops=3)
                                                                   Worker 0: actual time=11164.409..11435.541 rows=1537910 loops=1
                                                                   Worker 1: actual time=11168.499..11443.162 rows=1571763 loops=1
                                                                 Node 16390: (actual time=11013.066..11287.575 rows=1512555 loops=3)
                                                                   Worker 0: actual time=11008.153..11278.871 rows=1514676 loops=1
                                                                   Worker 1: actual time=11012.000..11275.018 rows=1425944 loops=1
                                                                 Node 16391: (actual time=10555.129..10834.716 rows=1511070 loops=3)
                                                                   Worker 0: actual time=10557.876..10833.072 rows=1541478 loops=1
                                                                   Worker 1: actual time=10549.779..10815.528 rows=1494741 loops=1
                                                                 Node 16387: (actual time=10235.612..10509.299 rows=1513274 loops=3)
                                                                   Worker 0: actual time=10235.153..10503.010 rows=1503372 loops=1
                                                                   Worker 1: actual time=10234.822..10504.625 rows=1499144 loops=1
                                                                 ->  Parallel Seq Scan on public.lineitem lineitem_1  (cost=0.00..16249314.73 rows=250012 width=16) (never executed)
                                                                       Output: lineitem_1.l_suppkey, lineitem_1.l_extendedprice, lineitem_1.l_discount
                                                                       Filter: (((lineitem_1.l_shipdate)::timestamp without time zone >= '1996-01-01 00:00:00'::timestamp without time zone) AND ((lineitem_1.l_shipdate)::timestamp without time zone < '1996-04-01 00:00:00'::timestamp without time zone))
                                                                       Remote node: 16389,16387,16390,16388,16391
                                                                       Node 16388: (actual time=0.064..10359.485 rows=1512404 loops=3)
                                                                         Worker 0: actual time=0.079..10363.561 rows=1476764 loops=1
                                                                         Worker 1: actual time=0.041..10373.360 rows=1493845 loops=1
                                                                       Node 16389: (actual time=0.043..10423.059 rows=1512864 loops=3)
                                                                         Worker 0: actual time=0.033..10404.294 rows=1537910 loops=1
                                                                         Worker 1: actual time=0.054..10402.966 rows=1571763 loops=1
                                                                       Node 16390: (actual time=0.068..10251.656 rows=1512555 loops=3)
                                                                         Worker 0: actual time=0.108..10235.317 rows=1514676 loops=1
                                                                         Worker 1: actual time=0.039..10277.683 rows=1425944 loops=1
                                                                       Node 16391: (actual time=0.042..9807.558 rows=1511070 loops=3)
                                                                         Worker 0: actual time=0.035..9791.712 rows=1541478 loops=1
                                                                         Worker 1: actual time=0.037..9807.335 rows=1494741 loops=1
                                                                       Node 16387: (actual time=0.052..9468.680 rows=1513274 loops=3)
                                                                         Worker 0: actual time=0.042..9453.503 rows=1503372 loops=1
                                                                         Worker 1: actual time=0.081..9452.416 rows=1499144 loops=1
         ->  Hash Join  (cost=16402140.92..16434845.92 rows=90 width=103) (actual time=0.008..0.010 rows=0 loops=1)
               Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_phone, revenue0.total_revenue
               Inner Unique: true
               Hash Cond: (supplier.s_suppkey = revenue0.supplier_no)
               Node 16388: (actual time=16750.085..16750.106 rows=0 loops=1)
               Node 16389: (actual time=16677.824..16677.845 rows=0 loops=1)
               Node 16390: (actual time=16753.162..16753.182 rows=0 loops=1)
               Node 16391: (actual time=16747.610..16747.631 rows=0 loops=1)
               Node 16387: (actual time=16749.034..16799.893 rows=1 loops=1)
               ->  Seq Scan on public.supplier  (cost=0.00..32180.00 rows=200000 width=71) (never executed)
                     Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                     Remote node: 16389,16387,16390,16388,16391
                     Node 16388: (never executed)
                     Node 16389: (never executed)
                     Node 16390: (never executed)
                     Node 16391: (never executed)
                     Node 16387: (actual time=0.046..30.701 rows=199723 loops=1)
               ->  Hash  (cost=16402112.77..16402112.77 rows=2252 width=36) (actual time=0.003..0.004 rows=0 loops=1)
                     Output: revenue0.total_revenue, revenue0.supplier_no
                     Buckets: 4096  Batches: 1  Memory Usage: 32kB
                     Node 16388: (actual time=16750.076..16750.096 rows=0 loops=1)
                     Node 16389: (actual time=16677.815..16677.835 rows=0 loops=1)
                     Node 16390: (actual time=16753.151..16753.170 rows=0 loops=1)
                     Node 16391: (actual time=16747.600..16747.620 rows=0 loops=1)
                     Node 16387: (actual time=16747.072..16747.093 rows=1 loops=1)
                     ->  Subquery Scan on revenue0  (cost=16277004.94..16402112.77 rows=2252 width=36) (actual time=0.002..0.003 rows=0 loops=1)
                           Output: revenue0.total_revenue, revenue0.supplier_no
                           Node 16388: (actual time=16750.074..16750.093 rows=0 loops=1)
                           Node 16389: (actual time=16677.813..16677.833 rows=0 loops=1)
                           Node 16390: (actual time=16753.149..16753.168 rows=0 loops=1)
                           Node 16391: (actual time=16747.599..16747.619 rows=0 loops=1)
                           Node 16387: (actual time=14998.959..16747.089 rows=1 loops=1)
                           ->  Finalize GroupAggregate  (cost=16277004.94..16402090.25 rows=450 width=36) (actual time=0.000..0.001 rows=0 loops=1)
                                 Output: lineitem.l_suppkey, sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                                 Group Key: lineitem.l_suppkey
                                 Filter: (sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))) = $0)
                                 Node 16388: (actual time=16750.071..16750.089 rows=0 loops=1)
                                 Node 16389: (actual time=16677.811..16677.831 rows=0 loops=1)
                                 Node 16390: (actual time=16753.147..16753.166 rows=0 loops=1)
                                 Node 16391: (actual time=16747.597..16747.617 rows=0 loops=1)
                                 Node 16387: (actual time=14998.958..16747.086 rows=1 loops=1)
                                 ->  Cluster Merge Reduce  (cost=16277004.94..16394263.47 rows=500024 width=36) (never executed)
                                       Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(lineitem.l_suppkey)), 0)]
                                       Sort Key: lineitem.l_suppkey
                                       Node 16388: (actual time=14978.759..15367.347 rows=2340147 loops=1)
                                       Node 16389: (actual time=14924.237..15322.673 rows=2337019 loops=1)
                                       Node 16390: (actual time=14999.145..15398.714 rows=2340878 loops=1)
                                       Node 16391: (actual time=14983.408..15370.413 rows=2334905 loops=1)
                                       Node 16387: (actual time=14983.278..15380.226 rows=2334301 loops=1)
                                       ->  Gather Merge  (cost=16277003.88..16340969.36 rows=500024 width=36) (never executed)
                                             Output: lineitem.l_suppkey, (PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount))))
                                             Workers Planned: 2
                                             Workers Launched: 0
                                             Node 16388: (actual time=10748.221..12896.322 rows=2337340 loops=1)
                                             Node 16389: (actual time=10932.546..13335.878 rows=2334949 loops=1)
                                             Node 16390: (actual time=10804.155..13021.987 rows=2338168 loops=1)
                                             Node 16391: (actual time=11138.274..13461.168 rows=2338061 loops=1)
                                             Node 16387: (actual time=10360.319..12633.580 rows=2338732 loops=1)
                                             ->  Partial GroupAggregate  (cost=16276003.86..16282254.16 rows=250012 width=36) (never executed)
                                                   Output: lineitem.l_suppkey, PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                                                   Group Key: lineitem.l_suppkey
                                                   Node 16388: (actual time=10734.594..12262.346 rows=779113 loops=3)
                                                     Worker 0: actual time=10720.822..12163.941 rows=759722 loops=1
                                                     Worker 1: actual time=10734.957..12243.482 rows=780204 loops=1
                                                   Node 16389: (actual time=10919.061..12499.203 rows=778316 loops=3)
                                                     Worker 0: actual time=10929.248..12496.091 rows=795279 loops=1
                                                     Worker 1: actual time=10928.143..12486.094 rows=792836 loops=1
                                                   Node 16390: (actual time=10789.938..12462.283 rows=779389 loops=3)
                                                     Worker 0: actual time=10800.382..12467.100 rows=774031 loops=1
                                                     Worker 1: actual time=10782.746..12511.835 rows=772680 loops=1
                                                   Node 16391: (actual time=11096.866..12645.890 rows=779354 loops=3)
                                                     Worker 0: actual time=11078.398..12579.498 rows=777039 loops=1
                                                     Worker 1: actual time=11074.159..12560.473 rows=774168 loops=1
                                                   Node 16387: (actual time=10356.542..11889.743 rows=779577 loops=3)
                                                     Worker 0: actual time=10356.056..11866.987 rows=778182 loops=1
                                                     Worker 1: actual time=10357.192..11871.358 rows=778624 loops=1
                                                   ->  Sort  (cost=16276003.86..16276628.89 rows=250012 width=16) (never executed)
                                                         Output: lineitem.l_suppkey, lineitem.l_extendedprice, lineitem.l_discount
                                                         Sort Key: lineitem.l_suppkey
                                                         Node 16388: (actual time=10734.573..11005.446 rows=1512404 loops=3)
                                                           Worker 0: actual time=10720.810..10975.990 rows=1425435 loops=1
                                                           Worker 1: actual time=10734.920..11001.951 rows=1515224 loops=1
                                                         Node 16389: (actual time=10919.038..11199.594 rows=1512864 loops=3)
                                                           Worker 0: actual time=10929.230..11207.624 rows=1586037 loops=1
                                                           Worker 1: actual time=10928.118..11203.842 rows=1576730 loops=1
                                                         Node 16390: (actual time=10789.913..11085.424 rows=1512555 loops=3)
                                                           Worker 0: actual time=10800.362..11095.600 rows=1490096 loops=1
                                                           Worker 1: actual time=10782.716..11087.937 rows=1479742 loops=1
                                                         Node 16391: (actual time=11096.852..11372.743 rows=1511070 loops=3)
                                                           Worker 0: actual time=11078.389..11345.670 rows=1501173 loops=1
                                                           Worker 1: actual time=11074.142..11336.447 rows=1486652 loops=1
                                                         Node 16387: (actual time=10356.523..10628.390 rows=1513274 loops=3)
                                                           Worker 0: actual time=10356.029..10623.170 rows=1505533 loops=1
                                                           Worker 1: actual time=10357.179..10625.985 rows=1508502 loops=1
                                                         ->  Parallel Seq Scan on public.lineitem  (cost=0.00..16249314.73 rows=250012 width=16) (never executed)
                                                               Output: lineitem.l_suppkey, lineitem.l_extendedprice, lineitem.l_discount
                                                               Filter: (((lineitem.l_shipdate)::timestamp without time zone >= '1996-01-01 00:00:00'::timestamp without time zone) AND ((lineitem.l_shipdate)::timestamp without time zone < '1996-04-01 00:00:00'::timestamp without time zone))
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16388: (actual time=0.052..9988.043 rows=1512404 loops=3)
                                                                 Worker 0: actual time=0.043..10014.334 rows=1425435 loops=1
                                                                 Worker 1: actual time=0.042..9978.527 rows=1515224 loops=1
                                                               Node 16389: (actual time=0.130..10178.877 rows=1512864 loops=3)
                                                                 Worker 0: actual time=0.107..10143.525 rows=1586037 loops=1
                                                                 Worker 1: actual time=0.248..10147.323 rows=1576730 loops=1
                                                               Node 16390: (actual time=0.077..10032.856 rows=1512555 loops=3)
                                                                 Worker 0: actual time=0.076..10033.773 rows=1490096 loops=1
                                                                 Worker 1: actual time=0.097..10038.265 rows=1479742 loops=1
                                                               Node 16391: (actual time=0.057..10340.850 rows=1511070 loops=3)
                                                                 Worker 0: actual time=0.060..10335.509 rows=1501173 loops=1
                                                                 Worker 1: actual time=0.059..10358.785 rows=1486652 loops=1
                                                               Node 16387: (actual time=0.041..9598.593 rows=1513274 loops=3)
                                                                 Worker 0: actual time=0.049..9584.136 rows=1505533 loops=1
                                                                 Worker 1: actual time=0.042..9590.143 rows=1508502 loops=1
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
         Node 16387: (actual time=22490.530..22490.824 rows=4640 loops=1)
         Node 16388: (actual time=23505.748..23506.152 rows=5800 loops=1)
         Node 16390: (actual time=23434.380..23434.920 rows=6960 loops=1)
         Node 16391: (actual time=23521.841..23522.234 rows=5800 loops=1)
         Node 16389: (actual time=22512.367..22512.682 rows=4640 loops=1)
         ->  GroupAggregate  (cost=3799140.08..3800088.92 rows=35955 width=44) (actual time=0.000..0.002 rows=0 loops=1)
               Output: part.p_brand, part.p_type, part.p_size, count(DISTINCT partsupp.ps_suppkey)
               Group Key: part.p_brand, part.p_type, part.p_size
               Node 16387: (actual time=20936.182..22486.297 rows=4640 loops=1)
               Node 16388: (actual time=21562.711..23500.316 rows=5800 loops=1)
               Node 16390: (actual time=21097.184..23427.811 rows=6960 loops=1)
               Node 16391: (actual time=21571.733..23516.372 rows=5800 loops=1)
               Node 16389: (actual time=20941.050..22508.091 rows=4640 loops=1)
               ->  Sort  (cost=3799140.08..3799257.94 rows=47143 width=40) (never executed)
                     Output: part.p_brand, part.p_type, part.p_size, partsupp.ps_suppkey
                     Sort Key: part.p_brand, part.p_type, part.p_size
                     Node 16387: (actual time=20935.842..21813.339 rows=1979721 loops=1)
                     Node 16388: (actual time=21562.319..22660.083 rows=2472701 loops=1)
                     Node 16390: (actual time=21096.778..22418.002 rows=2973168 loops=1)
                     Node 16391: (actual time=21571.377..22675.645 rows=2473947 loops=1)
                     Node 16389: (actual time=20940.650..21834.727 rows=1981807 loops=1)
                     ->  Cluster Reduce  (cost=959418.10..3795480.68 rows=47143 width=40) (never executed)
                           Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashbpchar(part.p_brand)), 0)]
                           Node 16387: (actual time=1645.775..17110.519 rows=1979721 loops=1)
                           Node 16388: (actual time=1615.353..16702.752 rows=2472701 loops=1)
                           Node 16390: (actual time=1668.441..15140.258 rows=2973168 loops=1)
                           Node 16391: (actual time=1601.006..16712.150 rows=2473947 loops=1)
                           Node 16389: (actual time=1609.389..17061.814 rows=1981807 loops=1)
                           ->  Hash Join  (cost=959417.10..3791664.97 rows=47143 width=40) (never executed)
                                 Output: part.p_brand, part.p_type, part.p_size, partsupp.ps_suppkey
                                 Inner Unique: true
                                 Hash Cond: (partsupp.ps_partkey = part.p_partkey)
                                 Node 16387: (actual time=1645.552..12000.977 rows=2376812 loops=1)
                                 Node 16388: (actual time=1615.184..12060.107 rows=2371844 loops=1)
                                 Node 16390: (actual time=1668.274..12030.035 rows=2377674 loops=1)
                                 Node 16391: (actual time=1600.212..12023.620 rows=2374647 loops=1)
                                 Node 16389: (actual time=1609.237..12345.203 rows=2380367 loops=1)
                                 ->  Seq Scan on public.partsupp  (cost=37856.25..2781985.65 rows=8001323 width=8) (never executed)
                                       Output: partsupp.ps_suppkey, partsupp.ps_partkey
                                       Filter: (NOT (hashed SubPlan 1))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16387: (actual time=0.310..5451.897 rows=15988844 loops=1)
                                       Node 16388: (actual time=0.333..5554.050 rows=15995149 loops=1)
                                       Node 16390: (actual time=0.328..5518.173 rows=15983160 loops=1)
                                       Node 16391: (actual time=0.312..5488.064 rows=15994616 loops=1)
                                       Node 16389: (actual time=0.377..5493.088 rows=15999911 loops=1)
                                       SubPlan 1
                                         ->  Cluster Reduce  (cost=1.00..37831.00 rows=10100 width=4) (never executed)
                                               Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                               Node 16387: (actual time=0.029..0.164 rows=479 loops=1)
                                               Node 16388: (actual time=0.033..0.163 rows=479 loops=1)
                                               Node 16390: (actual time=0.026..0.173 rows=479 loops=1)
                                               Node 16391: (actual time=0.037..0.151 rows=479 loops=1)
                                               Node 16389: (actual time=0.030..0.156 rows=479 loops=1)
                                               ->  Seq Scan on public.supplier  (cost=0.00..34680.00 rows=2020 width=4) (never executed)
                                                     Output: supplier.s_suppkey
                                                     Filter: ((supplier.s_comment)::text ~~ '%Customer%Complaints%'::text)
                                                     Remote node: 16389,16387,16390,16388,16391
                                                     Node 16387: (actual time=0.365..67.324 rows=107 loops=1)
                                                     Node 16388: (actual time=0.082..70.166 rows=96 loops=1)
                                                     Node 16390: (actual time=0.457..67.488 rows=84 loops=1)
                                                     Node 16391: (actual time=1.391..65.709 rows=90 loops=1)
                                                     Node 16389: (actual time=0.864..69.732 rows=102 loops=1)
                                 ->  Hash  (cost=909593.10..909593.10 rows=589180 width=40) (never executed)
                                       Output: part.p_brand, part.p_type, part.p_size, part.p_partkey
                                       Node 16387: (actual time=1644.134..1644.134 rows=594498 loops=1)
                                       Node 16388: (actual time=1613.062..1613.062 rows=593250 loops=1)
                                       Node 16390: (actual time=1667.028..1667.030 rows=594690 loops=1)
                                       Node 16391: (actual time=1599.318..1599.319 rows=593932 loops=1)
                                       Node 16389: (actual time=1608.210..1608.212 rows=595379 loops=1)
                                       ->  Seq Scan on public.part  (cost=0.00..909593.10 rows=589180 width=40) (never executed)
                                             Output: part.p_brand, part.p_type, part.p_size, part.p_partkey
                                             Filter: ((part.p_brand <> 'Brand#45'::bpchar) AND ((part.p_type)::text !~~ 'MEDIUM POLISHED%'::text) AND (part.p_size = ANY ('{49,14,23,45,19,3,36,9}'::integer[])))
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16387: (actual time=0.020..1483.082 rows=594498 loops=1)
                                             Node 16388: (actual time=0.017..1451.525 rows=593250 loops=1)
                                             Node 16390: (actual time=0.015..1510.652 rows=594690 loops=1)
                                             Node 16391: (actual time=0.016..1435.735 rows=593932 loops=1)
                                             Node 16389: (actual time=0.017..1436.135 rows=595379 loops=1)
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
               Node 16387: (actual time=1210718.085..1210718.087 rows=1 loops=1)
               Node 16389: (actual time=1219775.664..1219775.667 rows=1 loops=1)
               Node 16388: (actual time=1211628.392..1211628.395 rows=1 loops=1)
               Node 16391: (actual time=1256287.761..1256287.763 rows=1 loops=1)
               Node 16390: (actual time=1244987.927..1244987.930 rows=1 loops=1)
               ->  Hash Join  (cost=710932.43..269811347.17 rows=1211 width=8) (actual time=1574.119..1107535.461 rows=9028 loops=1)
                     Output: lineitem.l_extendedprice
                     Inner Unique: true
                     Hash Cond: (lineitem.l_partkey = part.p_partkey)
                     Join Filter: (lineitem.l_quantity < (SubPlan 1))
                     Rows Removed by Join Filter: 91424
                     Node 16387: (actual time=145330.622..1210709.865 rows=8872 loops=1)
                     Node 16389: (actual time=142145.986..1219765.671 rows=8834 loops=1)
                     Node 16388: (actual time=131338.960..1211619.386 rows=8983 loops=1)
                     Node 16391: (actual time=139493.060..1256277.755 rows=9262 loops=1)
                     Node 16390: (actual time=156124.563..1244977.104 rows=8864 loops=1)
                     ->  Cluster Reduce  (cost=1.00..55360537.28 rows=100004715 width=17) (actual time=0.286..24537.203 rows=100000053 loops=1)
                           Reduce: ('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(6, hashint4(lineitem.l_partkey)), 0)]
                           Node 16387: (actual time=110090.236..122719.106 rows=100004065 loops=1)
                           Node 16389: (actual time=100044.464..114302.847 rows=99985015 loops=1)
                           Node 16388: (actual time=130471.603..144378.900 rows=100069311 loops=1)
                           Node 16391: (actual time=97640.355..111776.948 rows=99898013 loops=1)
                           Node 16390: (actual time=129129.427..141731.664 rows=100081445 loops=1)
                           ->  Seq Scan on public.lineitem  (cost=0.00..17249361.88 rows=120005658 width=17) (actual time=0.007..0.007 rows=0 loops=1)
                                 Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                 Remote node: 16389,16387,16390,16388,16391
                                 Node 16387: (actual time=0.013..16307.062 rows=119999412 loops=1)
                                 Node 16389: (actual time=0.016..16832.343 rows=119998625 loops=1)
                                 Node 16388: (actual time=0.015..16956.833 rows=120014889 loops=1)
                                 Node 16391: (actual time=0.014..18922.861 rows=120014017 loops=1)
                                 Node 16390: (actual time=0.022..19053.433 rows=120010959 loops=1)
                     ->  Hash  (cost=710888.36..710888.36 rows=3446 width=4) (actual time=1497.653..1497.655 rows=3338 loops=1)
                           Output: part.p_partkey
                           Buckets: 4096  Batches: 1  Memory Usage: 150kB
                           Node 16387: (actual time=35229.170..35229.170 rows=3287 loops=1)
                           Node 16389: (actual time=42004.302..42004.302 rows=3315 loops=1)
                           Node 16388: (actual time=813.309..813.310 rows=3331 loops=1)
                           Node 16391: (actual time=41808.681..41808.682 rows=3432 loops=1)
                           Node 16390: (actual time=26886.973..26886.974 rows=3328 loops=1)
                           ->  Cluster Reduce  (cost=1.00..710888.36 rows=3446 width=4) (actual time=0.512..1497.190 rows=3338 loops=1)
                                 Reduce: ('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])[COALESCE(hash_combin_mod(6, hashint4(part.p_partkey)), 0)]
                                 Node 16387: (actual time=814.343..35228.666 rows=3287 loops=1)
                                 Node 16389: (actual time=800.535..42003.705 rows=3315 loops=1)
                                 Node 16388: (actual time=812.502..812.894 rows=3331 loops=1)
                                 Node 16391: (actual time=862.560..41808.109 rows=3432 loops=1)
                                 Node 16390: (actual time=814.343..26886.463 rows=3328 loops=1)
                                 ->  Seq Scan on public.part  (cost=0.00..709595.86 rows=4135 width=4) (actual time=0.015..0.015 rows=0 loops=1)
                                       Output: part.p_partkey
                                       Filter: ((part.p_brand = 'Brand#23'::bpchar) AND (part.p_container = 'MED BOX'::bpchar))
                                       Remote node: 16389,16387,16390,16388,16391
                                       Node 16387: (actual time=0.346..801.582 rows=4001 loops=1)
                                       Node 16389: (actual time=0.119..786.825 rows=3988 loops=1)
                                       Node 16388: (actual time=0.055..793.823 rows=4042 loops=1)
                                       Node 16391: (actual time=0.277..848.773 rows=4036 loops=1)
                                       Node 16390: (actual time=0.245..796.157 rows=3964 loops=1)
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
                                         Node 16387: (actual time=0.013..47303.469 rows=600037902 loops=1)
                                         Node 16389: (actual time=0.013..54216.148 rows=600037902 loops=1)
                                         Node 16388: (actual time=0.016..48990.576 rows=600037902 loops=1)
                                         Node 16391: (actual time=0.016..51726.578 rows=600037902 loops=1)
                                         Node 16390: (actual time=0.015..47711.098 rows=600037902 loops=1)
                                         ->  Seq Scan on public.lineitem lineitem_1  (cost=0.00..17249361.88 rows=120005658 width=9) (actual time=0.019..0.019 rows=0 loops=1)
                                               Output: lineitem_1.l_quantity, lineitem_1.l_partkey
                                               Remote node: 16389,16387,16390,16388,16391
                                               Node 16387: (actual time=0.056..27228.971 rows=119999412 loops=1)
                                               Node 16389: (actual time=0.028..25538.465 rows=119998625 loops=1)
                                               Node 16388: (actual time=0.305..25697.075 rows=120014889 loops=1)
                                               Node 16391: (actual time=0.030..24995.839 rows=120014017 loops=1)
                                               Node 16390: (actual time=0.033..29349.647 rows=120010959 loops=1)
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
               Node 16389: (actual time=130936.163..130936.239 rows=100 loops=1)
               Node 16391: (actual time=130944.804..130944.896 rows=100 loops=1)
               Node 16387: (actual time=130952.308..130952.394 rows=100 loops=1)
               Node 16390: (actual time=130958.811..130958.894 rows=100 loops=1)
               Node 16388: (actual time=130962.333..130962.413 rows=100 loops=1)
               ->  Sort  (cost=46470874.13..46470885.23 rows=4439 width=71) (actual time=0.007..0.009 rows=0 loops=1)
                     Output: customer.c_name, customer.c_custkey, orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, (sum(lineitem.l_quantity))
                     Sort Key: orders.o_totalprice DESC, orders.o_orderdate
                     Sort Method: quicksort  Memory: 25kB
                     Node 16389: (actual time=130936.162..130936.230 rows=100 loops=1)
                     Node 16391: (actual time=130944.802..130944.886 rows=100 loops=1)
                     Node 16387: (actual time=130952.306..130952.385 rows=100 loops=1)
                     Node 16390: (actual time=130958.809..130958.884 rows=100 loops=1)
                     Node 16388: (actual time=130962.331..130962.405 rows=100 loops=1)
                     ->  GroupAggregate  (cost=46470604.61..46470704.48 rows=4439 width=71) (actual time=0.000..0.002 rows=0 loops=1)
                           Output: customer.c_name, customer.c_custkey, orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, sum(lineitem.l_quantity)
                           Group Key: customer.c_custkey, orders.o_orderkey
                           Node 16389: (actual time=130932.028..130935.580 rows=1341 loops=1)
                           Node 16391: (actual time=130940.941..130944.258 rows=1253 loops=1)
                           Node 16387: (actual time=130948.276..130951.735 rows=1302 loops=1)
                           Node 16390: (actual time=130955.087..130958.283 rows=1203 loops=1)
                           Node 16388: (actual time=130958.272..130961.741 rows=1299 loops=1)
                           ->  Sort  (cost=46470604.61..46470615.71 rows=4439 width=44) (never executed)
                                 Output: customer.c_custkey, orders.o_orderkey, customer.c_name, orders.o_orderdate, orders.o_totalprice, lineitem.l_quantity
                                 Sort Key: customer.c_custkey, orders.o_orderkey
                                 Node 16389: (actual time=130932.008..130932.702 rows=9387 loops=1)
                                 Node 16391: (actual time=130940.922..130941.562 rows=8771 loops=1)
                                 Node 16387: (actual time=130948.253..130948.927 rows=9114 loops=1)
                                 Node 16390: (actual time=130955.070..130955.692 rows=8421 loops=1)
                                 Node 16388: (actual time=130958.255..130958.945 rows=9093 loops=1)
                                 ->  Hash Join  (cost=28751010.89..46470335.71 rows=4439 width=44) (never executed)
                                       Output: customer.c_custkey, orders.o_orderkey, customer.c_name, orders.o_orderdate, orders.o_totalprice, lineitem.l_quantity
                                       Inner Unique: true
                                       Hash Cond: (orders.o_custkey = customer.c_custkey)
                                       Node 16389: (actual time=100819.409..130928.802 rows=9387 loops=1)
                                       Node 16391: (actual time=102175.922..130937.918 rows=8771 loops=1)
                                       Node 16387: (actual time=103708.968..130945.018 rows=9114 loops=1)
                                       Node 16390: (actual time=102330.960..130952.099 rows=8421 loops=1)
                                       Node 16388: (actual time=101421.744..130954.111 rows=9093 loops=1)
                                       ->  Cluster Reduce  (cost=28187651.28..45889034.83 rows=22194 width=25) (never executed)
                                             Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                             Node 16389: (actual time=96672.497..129430.196 rows=9387 loops=1)
                                             Node 16391: (actual time=98036.636..129333.616 rows=8771 loops=1)
                                             Node 16387: (actual time=97506.830..129403.154 rows=9114 loops=1)
                                             Node 16390: (actual time=101116.386..129455.706 rows=8421 loops=1)
                                             Node 16388: (actual time=96203.702..129395.497 rows=9093 loops=1)
                                             ->  Hash Join  (cost=28187650.28..45887255.31 rows=22194 width=25) (never executed)
                                                   Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey, lineitem.l_quantity
                                                   Hash Cond: (lineitem.l_orderkey = orders.o_orderkey)
                                                   Node 16389: (actual time=96672.331..124710.626 rows=8736 loops=1)
                                                   Node 16391: (actual time=98036.343..126054.745 rows=9233 loops=1)
                                                   Node 16387: (actual time=97506.634..125825.627 rows=9002 loops=1)
                                                   Node 16390: (actual time=101116.193..129436.413 rows=9219 loops=1)
                                                   Node 16388: (actual time=96184.419..124870.693 rows=8596 loops=1)
                                                   ->  Seq Scan on public.lineitem  (cost=0.00..17249361.88 rows=120005658 width=9) (never executed)
                                                         Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                                         Remote node: 16389,16387,16390,16388,16391
                                                         Node 16389: (actual time=0.037..14851.855 rows=119998625 loops=1)
                                                         Node 16391: (actual time=0.043..15023.460 rows=120014017 loops=1)
                                                         Node 16387: (actual time=0.062..15559.046 rows=119999412 loops=1)
                                                         Node 16390: (actual time=0.039..15406.137 rows=120010959 loops=1)
                                                         Node 16388: (actual time=0.033..15765.565 rows=120014889 loops=1)
                                                   ->  Hash  (cost=28187303.52..28187303.52 rows=27741 width=24) (never executed)
                                                         Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey, lineitem_1.l_orderkey
                                                         Node 16389: (actual time=96649.030..96649.091 rows=1248 loops=1)
                                                         Node 16391: (actual time=98022.403..98022.479 rows=1319 loops=1)
                                                         Node 16387: (actual time=97503.206..97503.277 rows=1286 loops=1)
                                                         Node 16390: (actual time=101114.151..101114.218 rows=1317 loops=1)
                                                         Node 16388: (actual time=96180.211..96180.275 rows=1228 loops=1)
                                                         ->  Hash Join  (cost=23645059.81..28187303.52 rows=27741 width=24) (never executed)
                                                               Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey, lineitem_1.l_orderkey
                                                               Inner Unique: true
                                                               Hash Cond: (orders.o_orderkey = lineitem_1.l_orderkey)
                                                               Node 16389: (actual time=82518.158..96648.012 rows=1248 loops=1)
                                                               Node 16391: (actual time=83464.059..98021.335 rows=1319 loops=1)
                                                               Node 16387: (actual time=83078.167..97502.100 rows=1286 loops=1)
                                                               Node 16390: (actual time=87341.154..101112.767 rows=1317 loops=1)
                                                               Node 16388: (actual time=82230.595..96179.438 rows=1228 loops=1)
                                                               ->  Seq Scan on public.orders  (cost=0.00..4109224.32 rows=29999766 width=20) (never executed)
                                                                     Output: orders.o_orderkey, orders.o_orderdate, orders.o_totalprice, orders.o_custkey
                                                                     Remote node: 16389,16387,16390,16388,16391
                                                                     Node 16389: (actual time=0.105..6505.127 rows=30000342 loops=1)
                                                                     Node 16391: (actual time=0.069..6889.767 rows=30000195 loops=1)
                                                                     Node 16387: (actual time=0.133..6772.606 rows=29996867 loops=1)
                                                                     Node 16390: (actual time=0.125..6230.928 rows=29999419 loops=1)
                                                                     Node 16388: (actual time=0.056..6179.302 rows=30003177 loops=1)
                                                               ->  Hash  (cost=23633680.88..23633680.88 rows=693515 width=4) (never executed)
                                                                     Output: lineitem_1.l_orderkey
                                                                     Node 16389: (actual time=82412.587..82412.647 rows=1248 loops=1)
                                                                     Node 16391: (actual time=83413.728..83413.803 rows=1319 loops=1)
                                                                     Node 16387: (actual time=83077.703..83077.772 rows=1286 loops=1)
                                                                     Node 16390: (actual time=87315.558..87315.625 rows=1317 loops=1)
                                                                     Node 16388: (actual time=82212.390..82212.453 rows=1228 loops=1)
                                                                     ->  Finalize GroupAggregate  (cost=22707978.12..23626745.73 rows=138703 width=4) (never executed)
                                                                           Output: lineitem_1.l_orderkey
                                                                           Group Key: lineitem_1.l_orderkey
                                                                           Filter: (sum(lineitem_1.l_quantity) > '300'::numeric)
                                                                           Node 16389: (actual time=29482.206..82411.242 rows=1248 loops=1)
                                                                           Node 16391: (actual time=29208.263..83412.016 rows=1319 loops=1)
                                                                           Node 16387: (actual time=29605.703..83075.954 rows=1286 loops=1)
                                                                           Node 16390: (actual time=29374.121..87313.923 rows=1317 loops=1)
                                                                           Node 16388: (actual time=29103.121..82211.365 rows=1228 loops=1)
                                                                           ->  Gather Merge  (cost=22707978.12..23589295.90 rows=4161092 width=36) (never executed)
                                                                                 Output: lineitem_1.l_orderkey, (PARTIAL sum(lineitem_1.l_quantity))
                                                                                 Workers Planned: 2
                                                                                 Workers Launched: 0
                                                                                 Node 16389: (actual time=29437.540..56824.662 rows=31526490 loops=1)
                                                                                 Node 16391: (actual time=28959.430..57825.581 rows=31525929 loops=1)
                                                                                 Node 16387: (actual time=29604.838..57456.868 rows=31527121 loops=1)
                                                                                 Node 16390: (actual time=29306.391..61725.589 rows=31528775 loops=1)
                                                                                 Node 16388: (actual time=29054.110..56565.398 rows=31538388 loops=1)
                                                                                 ->  Partial GroupAggregate  (cost=22706978.10..23108002.61 rows=2080546 width=36) (never executed)
                                                                                       Output: lineitem_1.l_orderkey, PARTIAL sum(lineitem_1.l_quantity)
                                                                                       Group Key: lineitem_1.l_orderkey
                                                                                       Node 16389: (actual time=29112.127..48277.246 rows=10508830 loops=3)
                                                                                         Worker 0: actual time=29197.493..48751.427 rows=10668196 loops=1
                                                                                         Worker 1: actual time=28701.633..47147.054 rows=10052663 loops=1
                                                                                       Node 16391: (actual time=28876.139..48005.383 rows=10508643 loops=3)
                                                                                         Worker 0: actual time=28928.800..48371.574 rows=10635121 loops=1
                                                                                         Worker 1: actual time=28740.513..47762.792 rows=10403486 loops=1
                                                                                       Node 16387: (actual time=29267.027..48474.914 rows=10509040 loops=3)
                                                                                         Worker 0: actual time=29214.143..48275.876 rows=10415598 loops=1
                                                                                         Worker 1: actual time=28982.355..47817.325 rows=10300296 loops=1
                                                                                       Node 16390: (actual time=28990.390..48209.169 rows=10509592 loops=3)
                                                                                         Worker 0: actual time=28688.352..47501.481 rows=10252216 loops=1
                                                                                         Worker 1: actual time=28976.755..48286.658 rows=10521304 loops=1
                                                                                       Node 16388: (actual time=28844.998..48027.673 rows=10512796 loops=3)
                                                                                         Worker 0: actual time=28627.856..47433.932 rows=10255172 loops=1
                                                                                         Worker 1: actual time=28853.328..48116.705 rows=10485787 loops=1
                                                                                       ->  Sort  (cost=22706978.10..22831984.00 rows=50002358 width=9) (never executed)
                                                                                             Output: lineitem_1.l_orderkey, lineitem_1.l_quantity
                                                                                             Sort Key: lineitem_1.l_orderkey
                                                                                             Node 16389: (actual time=29112.107..34412.095 rows=39999542 loops=3)
                                                                                               Worker 0: actual time=29197.474..34601.927 rows=40594378 loops=1
                                                                                               Worker 1: actual time=28701.607..33813.696 rows=38251950 loops=1
                                                                                             Node 16391: (actual time=28876.122..34151.149 rows=40004672 loops=3)
                                                                                               Worker 0: actual time=28928.777..34291.951 rows=40494571 loops=1
                                                                                               Worker 1: actual time=28740.501..33988.997 rows=39605512 loops=1
                                                                                             Node 16387: (actual time=29266.999..34550.197 rows=39999804 loops=3)
                                                                                               Worker 0: actual time=29214.087..34497.280 rows=39591349 loops=1
                                                                                               Worker 1: actual time=28982.337..34185.433 rows=39168634 loops=1
                                                                                             Node 16390: (actual time=28990.367..34339.534 rows=40003653 loops=3)
                                                                                               Worker 0: actual time=28688.329..33906.405 rows=38989265 loops=1
                                                                                               Worker 1: actual time=28976.732..34334.490 rows=40008074 loops=1
                                                                                             Node 16388: (actual time=28844.977..34175.089 rows=40004963 loops=3)
                                                                                               Worker 0: actual time=28627.826..33853.900 rows=39009206 loops=1
                                                                                               Worker 1: actual time=28853.307..34233.277 rows=39884395 loops=1
                                                                                             ->  Parallel Seq Scan on public.lineitem lineitem_1  (cost=0.00..13749196.87 rows=50002358 width=9) (never executed)
                                                                                                   Output: lineitem_1.l_orderkey, lineitem_1.l_quantity
                                                                                                   Remote node: 16389,16387,16390,16388,16391
                                                                                                   Node 16389: (actual time=0.022..9802.088 rows=39999542 loops=3)
                                                                                                     Worker 0: actual time=0.029..9627.908 rows=40594378 loops=1
                                                                                                     Worker 1: actual time=0.026..10326.283 rows=38251950 loops=1
                                                                                                   Node 16391: (actual time=0.035..9419.737 rows=40004672 loops=3)
                                                                                                     Worker 0: actual time=0.044..9418.849 rows=40494571 loops=1
                                                                                                     Worker 1: actual time=0.044..9457.856 rows=39605512 loops=1
                                                                                                   Node 16387: (actual time=0.014..9930.786 rows=39999804 loops=3)
                                                                                                     Worker 0: actual time=0.015..9933.783 rows=39591349 loops=1
                                                                                                     Worker 1: actual time=0.015..10202.549 rows=39168634 loops=1
                                                                                                   Node 16390: (actual time=0.028..9501.296 rows=40003653 loops=3)
                                                                                                     Worker 0: actual time=0.031..9734.652 rows=38989265 loops=1
                                                                                                     Worker 1: actual time=0.032..9452.704 rows=40008074 loops=1
                                                                                                   Node 16388: (actual time=0.037..9551.023 rows=40004963 loops=3)
                                                                                                     Worker 0: actual time=0.044..9755.401 rows=39009206 loops=1
                                                                                                     Worker 1: actual time=0.044..9600.148 rows=39884395 loops=1
                                       ->  Hash  (cost=508279.89..508279.89 rows=3000058 width=23) (never executed)
                                             Output: customer.c_name, customer.c_custkey
                                             Node 16389: (actual time=1236.735..1236.735 rows=3001614 loops=1)
                                             Node 16391: (actual time=1335.232..1335.232 rows=2999921 loops=1)
                                             Node 16387: (actual time=1262.165..1262.166 rows=2998456 loops=1)
                                             Node 16390: (actual time=1214.112..1214.113 rows=2997748 loops=1)
                                             Node 16388: (actual time=1271.610..1271.611 rows=3002261 loops=1)
                                             ->  Seq Scan on public.customer  (cost=0.00..508279.89 rows=3000058 width=23) (never executed)
                                                   Output: customer.c_name, customer.c_custkey
                                                   Remote node: 16389,16387,16390,16388,16391
                                                   Node 16389: (actual time=0.019..636.072 rows=3001614 loops=1)
                                                   Node 16391: (actual time=0.019..726.561 rows=2999921 loops=1)
                                                   Node 16387: (actual time=0.016..678.973 rows=2998456 loops=1)
                                                   Node 16390: (actual time=0.021..609.675 rows=2997748 loops=1)
                                                   Node 16388: (actual time=0.021..683.085 rows=3002261 loops=1)
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
               Node 16388: (actual time=15533.642..15534.903 rows=3 loops=1)
               Node 16389: (actual time=16592.675..16594.767 rows=3 loops=1)
               Node 16387: (actual time=16721.623..16723.260 rows=3 loops=1)
               Node 16391: (actual time=17375.049..17376.888 rows=3 loops=1)
               Node 16390: (actual time=17572.252..17574.036 rows=3 loops=1)
               ->  Partial Aggregate  (cost=19520957.10..19520957.11 rows=1 width=32) (actual time=0.071..0.073 rows=1 loops=1)
                     Output: PARTIAL sum((lineitem.l_extendedprice * ('1'::numeric - lineitem.l_discount)))
                     Node 16388: (actual time=15531.031..15531.033 rows=1 loops=3)
                       Worker 0: actual time=15529.998..15530.001 rows=1 loops=1
                       Worker 1: actual time=15530.009..15530.010 rows=1 loops=1
                     Node 16389: (actual time=16589.907..16589.910 rows=1 loops=3)
                       Worker 0: actual time=16588.758..16588.760 rows=1 loops=1
                       Worker 1: actual time=16588.811..16588.813 rows=1 loops=1
                     Node 16387: (actual time=16719.208..16719.210 rows=1 loops=3)
                       Worker 0: actual time=16718.192..16718.195 rows=1 loops=1
                       Worker 1: actual time=16718.291..16718.294 rows=1 loops=1
                     Node 16391: (actual time=17372.373..17372.376 rows=1 loops=3)
                       Worker 0: actual time=17371.237..17371.239 rows=1 loops=1
                       Worker 1: actual time=17371.330..17371.333 rows=1 loops=1
                     Node 16390: (actual time=17569.673..17569.676 rows=1 loops=3)
                       Worker 0: actual time=17568.681..17568.684 rows=1 loops=1
                       Worker 1: actual time=17568.595..17568.597 rows=1 loops=1
                     ->  Parallel Hash Join  (cost=769136.47..19520956.86 rows=32 width=12) (actual time=0.068..0.069 rows=0 loops=1)
                           Output: lineitem.l_extendedprice, lineitem.l_discount
                           Inner Unique: true
                           Hash Cond: (lineitem.l_partkey = part.p_partkey)
                           Join Filter: (((part.p_brand = 'Brand#12'::bpchar) AND (part.p_container = ANY ('{"SM CASE","SM BOX","SM PACK","SM PKG"}'::bpchar[])) AND (lineitem.l_quantity >= '1'::numeric) AND (lineitem.l_quantity <= '11'::numeric) AND (part.p_size <= 5)) OR ((part.p_brand = 'Brand#23'::bpchar) AND (part.p_container = ANY ('{"MED BAG","MED BOX","MED PKG","MED PACK"}'::bpchar[])) AND (lineitem.l_quantity >= '10'::numeric) AND (lineitem.l_quantity <= '20'::numeric) AND (part.p_size <= 10)) OR ((part.p_brand = 'Brand#34'::bpchar) AND (part.p_container = ANY ('{"LG CASE","LG BOX","LG PACK","LG PKG"}'::bpchar[])) AND (lineitem.l_quantity >= '20'::numeric) AND (lineitem.l_quantity <= '30'::numeric) AND (part.p_size <= 15)))
                           Node 16388: (actual time=548.129..15529.343 rows=765 loops=3)
                             Worker 0: actual time=536.217..15528.326 rows=801 loops=1
                             Worker 1: actual time=560.862..15528.492 rows=722 loops=1
                           Node 16389: (actual time=588.035..16587.599 rows=763 loops=3)
                             Worker 0: actual time=571.532..16586.752 rows=724 loops=1
                             Worker 1: actual time=605.715..16586.199 rows=804 loops=1
                           Node 16387: (actual time=575.918..16717.040 rows=748 loops=3)
                             Worker 0: actual time=580.575..16715.979 rows=743 loops=1
                             Worker 1: actual time=569.663..16716.153 rows=719 loops=1
                           Node 16391: (actual time=586.360..17370.114 rows=745 loops=3)
                             Worker 0: actual time=578.394..17369.031 rows=716 loops=1
                             Worker 1: actual time=587.797..17369.004 rows=730 loops=1
                           Node 16390: (actual time=584.330..17567.425 rows=752 loops=3)
                             Worker 0: actual time=587.333..17566.186 rows=776 loops=1
                             Worker 1: actual time=592.335..17566.625 rows=683 loops=1
                           ->  Parallel Seq Scan on public.lineitem  (cost=0.00..18749432.60 rows=909635 width=21) (never executed)
                                 Output: lineitem.l_orderkey, lineitem.l_partkey, lineitem.l_suppkey, lineitem.l_linenumber, lineitem.l_quantity, lineitem.l_extendedprice, lineitem.l_discount, lineitem.l_tax, lineitem.l_returnflag, lineitem.l_linestatus, lineitem.l_shipdate, lineitem.l_commitdate, lineitem.l_receiptdate, lineitem.l_shipinstruct, lineitem.l_shipmode, lineitem.l_comment
                                 Filter: ((lineitem.l_shipmode = ANY ('{AIR,"AIR REG"}'::bpchar[])) AND (lineitem.l_shipinstruct = 'DELIVER IN PERSON'::bpchar) AND (((lineitem.l_quantity >= '1'::numeric) AND (lineitem.l_quantity <= '11'::numeric)) OR ((lineitem.l_quantity >= '10'::numeric) AND (lineitem.l_quantity <= '20'::numeric)) OR ((lineitem.l_quantity >= '20'::numeric) AND (lineitem.l_quantity <= '30'::numeric))))
                                 Remote node: 16389,16387,16390,16388,16391
                                 Node 16388: (actual time=0.081..14657.518 rows=857638 loops=3)
                                   Worker 0: actual time=0.076..14651.338 rows=862840 loops=1
                                   Worker 1: actual time=0.128..14657.014 rows=855210 loops=1
                                 Node 16389: (actual time=0.063..15524.143 rows=856860 loops=3)
                                   Worker 0: actual time=0.042..15456.790 rows=802515 loops=1
                                   Worker 1: actual time=0.066..15573.494 rows=888141 loops=1
                                 Node 16387: (actual time=0.061..15653.963 rows=857428 loops=3)
                                   Worker 0: actual time=0.059..15582.329 rows=852161 loops=1
                                   Worker 1: actual time=0.081..15690.526 rows=864749 loops=1
                                 Node 16391: (actual time=0.063..16333.129 rows=857331 loops=3)
                                   Worker 0: actual time=0.093..16368.532 rows=854648 loops=1
                                   Worker 1: actual time=0.053..16230.591 rows=836871 loops=1
                                 Node 16390: (actual time=0.066..16414.705 rows=856888 loops=3)
                                   Worker 0: actual time=0.053..16425.184 rows=877206 loops=1
                                   Worker 1: actual time=0.075..16339.928 rows=801789 loops=1
                           ->  Parallel Hash  (cost=768886.78..768886.78 rows=19975 width=30) (actual time=0.003..0.004 rows=0 loops=1)
                                 Output: part.p_partkey, part.p_brand, part.p_container, part.p_size
                                 Buckets: 65536  Batches: 1  Memory Usage: 512kB
                                 Node 16388: (actual time=534.496..534.496 rows=16062 loops=3)
                                   Worker 0: actual time=533.503..533.504 rows=14322 loops=1
                                   Worker 1: actual time=533.518..533.518 rows=15035 loops=1
                                 Node 16389: (actual time=568.321..568.322 rows=16062 loops=3)
                                   Worker 0: actual time=567.208..567.209 rows=16460 loops=1
                                   Worker 1: actual time=567.208..567.209 rows=16202 loops=1
                                 Node 16387: (actual time=569.830..569.831 rows=16062 loops=3)
                                   Worker 0: actual time=568.862..568.863 rows=17501 loops=1
                                   Worker 1: actual time=568.872..568.873 rows=17192 loops=1
                                 Node 16391: (actual time=570.542..570.543 rows=16062 loops=3)
                                   Worker 0: actual time=569.439..569.439 rows=13312 loops=1
                                   Worker 1: actual time=569.456..569.457 rows=17141 loops=1
                                 Node 16390: (actual time=570.183..570.183 rows=16062 loops=3)
                                   Worker 0: actual time=569.160..569.161 rows=16966 loops=1
                                   Worker 1: actual time=569.160..569.161 rows=16879 loops=1
                                 ->  Cluster Reduce  (cost=1.00..768886.78 rows=19975 width=30) (actual time=0.001..0.001 rows=0 loops=1)
                                       Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                       Node 16388: (actual time=522.527..523.995 rows=16062 loops=3)
                                         Worker 0: actual time=521.529..522.776 rows=14322 loops=1
                                         Worker 1: actual time=521.528..522.853 rows=15035 loops=1
                                       Node 16389: (actual time=435.301..561.938 rows=16062 loops=3)
                                         Worker 0: actual time=434.176..560.845 rows=16460 loops=1
                                         Worker 1: actual time=434.176..560.895 rows=16202 loops=1
                                       Node 16387: (actual time=498.788..561.302 rows=16062 loops=3)
                                         Worker 0: actual time=497.821..560.369 rows=17501 loops=1
                                         Worker 1: actual time=497.817..560.302 rows=17192 loops=1
                                       Node 16391: (actual time=497.401..561.957 rows=16062 loops=3)
                                         Worker 0: actual time=496.295..560.647 rows=13312 loops=1
                                         Worker 1: actual time=496.303..560.827 rows=17141 loops=1
                                       Node 16390: (actual time=493.943..561.603 rows=16062 loops=3)
                                         Worker 0: actual time=492.905..560.440 rows=16966 loops=1
                                         Worker 1: actual time=492.906..560.786 rows=16879 loops=1
                                       ->  Parallel Seq Scan on public.part  (cost=0.00..763761.78 rows=3995 width=30) (never executed)
                                             Output: part.p_partkey, part.p_brand, part.p_container, part.p_size
                                             Filter: ((part.p_size >= 1) AND (((part.p_brand = 'Brand#12'::bpchar) AND (part.p_container = ANY ('{"SM CASE","SM BOX","SM PACK","SM PKG"}'::bpchar[])) AND (part.p_size <= 5)) OR ((part.p_brand = 'Brand#23'::bpchar) AND (part.p_container = ANY ('{"MED BAG","MED BOX","MED PKG","MED PACK"}'::bpchar[])) AND (part.p_size <= 10)) OR ((part.p_brand = 'Brand#34'::bpchar) AND (part.p_container = ANY ('{"LG CASE","LG BOX","LG PACK","LG PKG"}'::bpchar[])) AND (part.p_size <= 15))))
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16388: (actual time=0.163..511.238 rows=3216 loops=3)
                                               Worker 0: actual time=0.363..512.185 rows=3291 loops=1
                                               Worker 1: actual time=0.093..510.409 rows=3095 loops=1
                                             Node 16389: (actual time=0.119..427.475 rows=3251 loops=3)
                                               Worker 0: actual time=0.187..426.601 rows=3263 loops=1
                                               Worker 1: actual time=0.074..426.653 rows=3244 loops=1
                                             Node 16387: (actual time=0.182..489.047 rows=3221 loops=3)
                                               Worker 0: actual time=0.037..490.081 rows=3179 loops=1
                                               Worker 1: actual time=0.393..489.916 rows=3222 loops=1
                                             Node 16391: (actual time=0.110..487.820 rows=3213 loops=3)
                                               Worker 0: actual time=0.184..486.332 rows=3331 loops=1
                                               Worker 1: actual time=0.118..486.798 rows=2823 loops=1
                                             Node 16390: (actual time=0.178..484.849 rows=3161 loops=3)
                                               Worker 0: actual time=0.310..484.516 rows=3298 loops=1
                                               Worker 1: actual time=0.037..484.304 rows=3326 loops=1
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
                                                   Remote node: 16389,16387,16390,16388,16391
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
                                                               Remote node: 16389,16387,16390,16388,16391
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
                                                                                             Remote node: 16389,16387,16390,16388,16391
                                                                                       ->  Parallel Hash  (cost=2823520.05..2823520.05 rows=10714 width=12)
                                                                                             Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                             ->  Parallel Seq Scan on public.orders  (cost=0.00..2823520.05 rows=10714 width=12)
                                                                                                   Output: orders.o_orderdate, orders.o_orderkey, orders.o_custkey
                                                                                                   Filter: (((orders.o_orderdate)::timestamp without time zone >= '1995-01-01 00:00:00'::timestamp without time zone) AND ((orders.o_orderdate)::timestamp without time zone <= '1996-12-31 00:00:00'::timestamp without time zone))
                                                                                                   Remote node: 16389,16387,16390,16388,16391
                                                                           ->  Parallel Hash  (cost=23246.53..23246.53 rows=800 width=30)
                                                                                 Output: supplier.s_suppkey, n2.n_name
                                                                                 ->  Parallel Hash Join  (cost=5.13..23246.53 rows=800 width=30)
                                                                                       Output: supplier.s_suppkey, n2.n_name
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (supplier.s_nationkey = n2.n_nationkey)
                                                                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..23180.00 rows=20000 width=8)
                                                                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                             Remote node: 16389,16387,16390,16388,16391
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
                           Node 16387: (actual time=91371.144..93096.726 rows=58093 loops=1)
                           Node 16388: (actual time=94004.714..94949.825 rows=57941 loops=1)
                           Node 16389: (actual time=95220.219..96443.745 rows=57833 loops=1)
                           Node 16390: (actual time=89532.983..90853.269 rows=57753 loops=1)
                           Node 16391: (actual time=89176.205..90599.894 rows=57915 loops=1)
                           ->  Partial GroupAggregate  (cost=49856397.51..49856397.53 rows=1 width=34) (actual time=0.212..0.215 rows=0 loops=1)
                                 Output: supplier.s_name, PARTIAL count(*)
                                 Group Key: supplier.s_name
                                 Node 16387: (actual time=91367.702..91379.329 rows=19364 loops=3)
                                   Worker 0: actual time=91366.712..91378.078 rows=19435 loops=1
                                   Worker 1: actual time=91365.782..91376.762 rows=18449 loops=1
                                 Node 16388: (actual time=94000.588..94011.914 rows=19314 loops=3)
                                   Worker 0: actual time=93998.783..94009.334 rows=18613 loops=1
                                   Worker 1: actual time=93998.776..94009.666 rows=19105 loops=1
                                 Node 16389: (actual time=95216.200..95227.755 rows=19278 loops=3)
                                   Worker 0: actual time=95216.508..95228.637 rows=20179 loops=1
                                   Worker 1: actual time=95213.666..95224.378 rows=18204 loops=1
                                 Node 16390: (actual time=89529.284..89541.485 rows=19251 loops=3)
                                   Worker 0: actual time=89526.567..89537.519 rows=18264 loops=1
                                   Worker 1: actual time=89529.156..89542.172 rows=19856 loops=1
                                 Node 16391: (actual time=89172.766..89185.071 rows=19305 loops=3)
                                   Worker 0: actual time=89172.344..89184.742 rows=19749 loops=1
                                   Worker 1: actual time=89172.092..89184.447 rows=19400 loops=1
                                 ->  Sort  (cost=49856397.51..49856397.52 rows=1 width=26) (actual time=0.211..0.214 rows=0 loops=1)
                                       Output: supplier.s_name
                                       Sort Key: supplier.s_name
                                       Sort Method: quicksort  Memory: 25kB
                                       Node 16387: (actual time=91367.689..91370.445 rows=26491 loops=3)
                                         Worker 0: actual time=91366.699..91369.178 rows=26768 loops=1
                                         Worker 1: actual time=91365.771..91368.453 rows=24663 loops=1
                                       Node 16388: (actual time=94000.579..94003.075 rows=26402 loops=3)
                                         Worker 0: actual time=93998.772..94000.934 rows=25049 loops=1
                                         Worker 1: actual time=93998.766..94001.003 rows=26016 loops=1
                                       Node 16389: (actual time=95216.190..95218.928 rows=26341 loops=3)
                                         Worker 0: actual time=95216.498..95219.373 rows=28165 loops=1
                                         Worker 1: actual time=95213.655..95216.203 rows=24235 loops=1
                                       Node 16390: (actual time=89529.273..89532.634 rows=26341 loops=3)
                                         Worker 0: actual time=89526.554..89529.256 rows=24454 loops=1
                                         Worker 1: actual time=89529.145..89533.039 rows=27370 loops=1
                                       Node 16391: (actual time=89172.756..89176.187 rows=26459 loops=3)
                                         Worker 0: actual time=89172.337..89175.751 rows=27215 loops=1
                                         Worker 1: actual time=89172.080..89175.524 rows=26820 loops=1
                                       ->  Parallel Hash Anti Join  (cost=46182470.09..49856397.50 rows=1 width=26) (actual time=0.204..0.207 rows=0 loops=1)
                                             Output: supplier.s_name
                                             Hash Cond: (l1.l_orderkey = l3.l_orderkey)
                                             Join Filter: (l3.l_suppkey <> l1.l_suppkey)
                                             Node 16387: (actual time=84980.672..91344.807 rows=26491 loops=3)
                                               Worker 0: actual time=84985.214..91343.701 rows=26768 loops=1
                                               Worker 1: actual time=84985.705..91344.365 rows=24663 loops=1
                                             Node 16388: (actual time=87637.861..93978.093 rows=26402 loops=3)
                                               Worker 0: actual time=87643.513..93977.305 rows=25049 loops=1
                                               Worker 1: actual time=87641.844..93977.171 rows=26016 loops=1
                                             Node 16389: (actual time=88521.320..95193.718 rows=26341 loops=3)
                                               Worker 0: actual time=88508.111..95192.290 rows=28165 loops=1
                                               Worker 1: actual time=88526.847..95193.140 rows=24235 loops=1
                                             Node 16390: (actual time=83261.138..89506.879 rows=26341 loops=3)
                                               Worker 0: actual time=83266.038..89506.150 rows=24454 loops=1
                                               Worker 1: actual time=83248.334..89505.448 rows=27370 loops=1
                                             Node 16391: (actual time=83029.744..89149.926 rows=26459 loops=3)
                                               Worker 0: actual time=83034.331..89148.775 rows=27215 loops=1
                                               Worker 1: actual time=83034.620..89148.762 rows=26820 loops=1
                                             ->  Parallel Hash Semi Join  (cost=30284733.67..33893550.46 rows=36 width=34) (actual time=0.090..0.092 rows=0 loops=1)
                                                   Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey
                                                   Hash Cond: (orders.o_orderkey = l2.l_orderkey)
                                                   Join Filter: (l2.l_suppkey <> l1.l_suppkey)
                                                   Node 16387: (actual time=53624.657..63574.922 rows=470208 loops=3)
                                                     Worker 0: actual time=53628.360..63570.514 rows=491199 loops=1
                                                     Worker 1: actual time=53630.397..63585.713 rows=428953 loops=1
                                                   Node 16388: (actual time=56658.712..66738.484 rows=469836 loops=3)
                                                     Worker 0: actual time=56649.910..66744.421 rows=452342 loops=1
                                                     Worker 1: actual time=56663.033..66739.358 rows=469886 loops=1
                                                   Node 16389: (actual time=57115.153..67763.171 rows=469473 loops=3)
                                                     Worker 0: actual time=57119.667..67755.460 rows=489629 loops=1
                                                     Worker 1: actual time=57106.052..67771.182 rows=445260 loops=1
                                                   Node 16390: (actual time=52625.068..62600.908 rows=469686 loops=3)
                                                     Worker 0: actual time=52616.108..62613.143 rows=438301 loops=1
                                                     Worker 1: actual time=52629.448..62596.600 rows=484294 loops=1
                                                   Node 16391: (actual time=52745.873..62499.071 rows=470140 loops=3)
                                                     Worker 0: actual time=52750.368..62499.101 rows=484261 loops=1
                                                     Worker 1: actual time=52750.266..62497.749 rows=481401 loops=1
                                                   ->  Parallel Hash Join  (cost=15715185.33..19128630.63 rows=2612 width=38) (never executed)
                                                         Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey, orders.o_orderkey
                                                         Hash Cond: (orders.o_orderkey = l1.l_orderkey)
                                                         Node 16387: (actual time=29248.727..30982.825 rows=487956 loops=3)
                                                           Worker 0: actual time=29252.450..30949.541 rows=500146 loops=1
                                                           Worker 1: actual time=29241.063..31055.049 rows=469629 loops=1
                                                         Node 16388: (actual time=32843.960..34610.798 rows=487530 loops=3)
                                                           Worker 0: actual time=32835.726..34609.509 rows=480743 loops=1
                                                           Worker 1: actual time=32848.118..34606.816 rows=479466 loops=1
                                                         Node 16389: (actual time=33484.618..35214.408 rows=487146 loops=3)
                                                           Worker 0: actual time=33488.812..35207.715 rows=499147 loops=1
                                                           Worker 1: actual time=33476.109..35218.896 rows=483862 loops=1
                                                         Node 16390: (actual time=29206.414..30907.019 rows=487363 loops=3)
                                                           Worker 0: actual time=29198.926..30913.582 rows=478704 loops=1
                                                           Worker 1: actual time=29210.166..30903.715 rows=489103 loops=1
                                                         Node 16391: (actual time=29243.687..30940.017 rows=487895 loops=3)
                                                           Worker 0: actual time=29247.498..30910.193 rows=487877 loops=1
                                                           Worker 1: actual time=29247.498..30918.882 rows=489658 loops=1
                                                         ->  Parallel Seq Scan on public.orders  (cost=0.00..3390479.92 rows=6121202 width=4) (never executed)
                                                               Output: orders.o_orderkey, orders.o_custkey, orders.o_orderstatus, orders.o_totalprice, orders.o_orderdate, orders.o_orderpriority, orders.o_clerk, orders.o_shippriority, orders.o_comment
                                                               Filter: (orders.o_orderstatus = 'F'::bpchar)
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16387: (actual time=0.045..2647.767 rows=4870065 loops=3)
                                                                 Worker 0: actual time=0.061..2664.721 rows=4917637 loops=1
                                                                 Worker 1: actual time=0.041..2644.171 rows=4717183 loops=1
                                                               Node 16388: (actual time=0.048..2691.096 rows=4873162 loops=3)
                                                                 Worker 0: actual time=0.051..2733.477 rows=4764453 loops=1
                                                                 Worker 1: actual time=0.053..2676.722 rows=4803211 loops=1
                                                               Node 16389: (actual time=0.047..2782.852 rows=4870473 loops=3)
                                                                 Worker 0: actual time=0.045..2799.200 rows=4871666 loops=1
                                                                 Worker 1: actual time=0.058..2765.310 rows=4784621 loops=1
                                                               Node 16390: (actual time=0.059..2642.910 rows=4872896 loops=3)
                                                                 Worker 0: actual time=0.073..2745.791 rows=4625451 loops=1
                                                                 Worker 1: actual time=0.064..2573.138 rows=4920667 loops=1
                                                               Node 16391: (actual time=0.044..2546.488 rows=4870905 loops=3)
                                                                 Worker 0: actual time=0.043..2417.164 rows=5067741 loops=1
                                                                 Worker 1: actual time=0.043..2487.648 rows=5104259 loops=1
                                                         ->  Parallel Hash  (cost=15714851.98..15714851.98 rows=26668 width=34) (never executed)
                                                               Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey
                                                               Node 16387: (actual time=25443.888..25443.892 rows=1010537 loops=3)
                                                                 Worker 0: actual time=25443.963..25443.967 rows=1043895 loops=1
                                                                 Worker 1: actual time=25443.761..25443.765 rows=940927 loops=1
                                                               Node 16388: (actual time=29001.634..29001.639 rows=1009452 loops=3)
                                                                 Worker 0: actual time=29001.496..29001.500 rows=1125137 loops=1
                                                                 Worker 1: actual time=29001.705..29001.709 rows=920180 loops=1
                                                               Node 16389: (actual time=29559.469..29559.473 rows=1008880 loops=3)
                                                                 Worker 0: actual time=29559.578..29559.581 rows=988703 loops=1
                                                                 Worker 1: actual time=29559.339..29559.343 rows=1069071 loops=1
                                                               Node 16390: (actual time=25415.810..25415.815 rows=1009629 loops=3)
                                                                 Worker 0: actual time=25415.866..25415.871 rows=803705 loops=1
                                                                 Worker 1: actual time=25415.888..25415.893 rows=1108117 loops=1
                                                               Node 16391: (actual time=25465.643..25465.647 rows=1010403 loops=3)
                                                                 Worker 0: actual time=25465.720..25465.724 rows=1054972 loops=1
                                                                 Worker 1: actual time=25465.720..25465.724 rows=1052984 loops=1
                                                               ->  Parallel Hash Join  (cost=27507.91..15714851.98 rows=26668 width=34) (never executed)
                                                                     Output: supplier.s_name, l1.l_suppkey, l1.l_orderkey
                                                                     Hash Cond: (l1.l_suppkey = supplier.s_suppkey)
                                                                     Node 16387: (actual time=45.270..24928.322 rows=1010537 loops=3)
                                                                       Worker 0: actual time=45.290..24912.846 rows=1043895 loops=1
                                                                       Worker 1: actual time=45.323..24961.609 rows=940927 loops=1
                                                                     Node 16388: (actual time=1014.303..28476.790 rows=1009452 loops=3)
                                                                       Worker 0: actual time=1014.358..28404.847 rows=1125137 loops=1
                                                                       Worker 1: actual time=1014.289..28515.787 rows=920180 loops=1
                                                                     Node 16389: (actual time=1298.259..28986.998 rows=1008880 loops=3)
                                                                       Worker 0: actual time=1298.247..29062.173 rows=988703 loops=1
                                                                       Worker 1: actual time=1298.277..28896.286 rows=1069071 loops=1
                                                                     Node 16390: (actual time=1590.563..24894.769 rows=1009629 loops=3)
                                                                       Worker 0: actual time=1590.524..24970.131 rows=803705 loops=1
                                                                       Worker 1: actual time=1590.590..24859.977 rows=1108117 loops=1
                                                                     Node 16391: (actual time=1719.608..24942.830 rows=1010403 loops=3)
                                                                       Worker 0: actual time=1719.606..24923.644 rows=1054972 loops=1
                                                                       Worker 1: actual time=1719.574..24934.009 rows=1052984 loops=1
                                                                     ->  Parallel Seq Scan on public.lineitem l1  (cost=0.00..15624285.27 rows=16667452 width=8) (never executed)
                                                                           Output: l1.l_orderkey, l1.l_partkey, l1.l_suppkey, l1.l_linenumber, l1.l_quantity, l1.l_extendedprice, l1.l_discount, l1.l_tax, l1.l_returnflag, l1.l_linestatus, l1.l_shipdate, l1.l_commitdate, l1.l_receiptdate, l1.l_shipinstruct, l1.l_shipmode, l1.l_comment
                                                                           Filter: ((l1.l_receiptdate)::timestamp without time zone > (l1.l_commitdate)::timestamp without time zone)
                                                                           Remote node: 16389,16387,16390,16388,16391
                                                                           Node 16387: (actual time=0.008..13433.108 rows=25288296 loops=3)
                                                                             Worker 0: actual time=0.009..13659.511 rows=26093698 loops=1
                                                                             Worker 1: actual time=0.008..12976.612 rows=23579584 loops=1
                                                                           Node 16388: (actual time=0.010..13708.548 rows=25294532 loops=3)
                                                                             Worker 0: actual time=0.016..14861.201 rows=28178892 loops=1
                                                                             Worker 1: actual time=0.007..12979.500 rows=23070834 loops=1
                                                                           Node 16389: (actual time=0.016..13592.701 rows=25286180 loops=3)
                                                                             Worker 0: actual time=0.020..13045.083 rows=24751876 loops=1
                                                                             Worker 1: actual time=0.010..15486.756 rows=26791542 loops=1
                                                                           Node 16390: (actual time=0.013..12942.750 rows=25290584 loops=3)
                                                                             Worker 0: actual time=0.018..11461.838 rows=20150303 loops=1
                                                                             Worker 1: actual time=0.008..13568.917 rows=27752455 loops=1
                                                                           Node 16391: (actual time=0.010..13321.885 rows=25292566 loops=3)
                                                                             Worker 0: actual time=0.012..13509.731 rows=26386020 loops=1
                                                                             Worker 1: actual time=0.009..13524.900 rows=26379359 loops=1
                                                                     ->  Parallel Hash  (cost=27466.22..27466.22 rows=3335 width=30) (never executed)
                                                                           Output: supplier.s_name, supplier.s_suppkey
                                                                           Node 16387: (actual time=45.171..45.172 rows=13318 loops=3)
                                                                             Worker 0: actual time=45.161..45.164 rows=14322 loops=1
                                                                             Worker 1: actual time=45.189..45.191 rows=12685 loops=1
                                                                           Node 16388: (actual time=1014.229..1014.232 rows=13318 loops=3)
                                                                             Worker 0: actual time=1014.252..1014.255 rows=14547 loops=1
                                                                             Worker 1: actual time=1014.223..1014.225 rows=11594 loops=1
                                                                           Node 16389: (actual time=1298.200..1298.202 rows=13318 loops=3)
                                                                             Worker 0: actual time=1298.191..1298.193 rows=12276 loops=1
                                                                             Worker 1: actual time=1298.225..1298.228 rows=14418 loops=1
                                                                           Node 16390: (actual time=1590.504..1590.506 rows=13318 loops=3)
                                                                             Worker 0: actual time=1590.459..1590.462 rows=10230 loops=1
                                                                             Worker 1: actual time=1590.518..1590.520 rows=14268 loops=1
                                                                           Node 16391: (actual time=1719.548..1719.551 rows=13318 loops=3)
                                                                             Worker 0: actual time=1719.544..1719.546 rows=14322 loops=1
                                                                             Worker 1: actual time=1719.542..1719.544 rows=12953 loops=1
                                                                           ->  Cluster Reduce  (cost=6.33..27466.22 rows=3335 width=30) (never executed)
                                                                                 Reduce: unnest('[0:4]={16387,16388,16389,16390,16391}'::oid[])
                                                                                 Node 16387: (actual time=27.878..29.176 rows=13318 loops=3)
                                                                                   Worker 0: actual time=27.858..29.265 rows=14322 loops=1
                                                                                   Worker 1: actual time=27.907..29.077 rows=12685 loops=1
                                                                                 Node 16388: (actual time=26.434..995.365 rows=13318 loops=3)
                                                                                   Worker 0: actual time=26.443..995.568 rows=14547 loops=1
                                                                                   Worker 1: actual time=26.434..995.210 rows=11594 loops=1
                                                                                 Node 16389: (actual time=29.274..1278.744 rows=13318 loops=3)
                                                                                   Worker 0: actual time=29.266..1278.641 rows=12276 loops=1
                                                                                   Worker 1: actual time=29.293..1278.876 rows=14418 loops=1
                                                                                 Node 16390: (actual time=28.270..1576.040 rows=13318 loops=3)
                                                                                   Worker 0: actual time=28.227..1575.506 rows=10230 loops=1
                                                                                   Worker 1: actual time=28.282..1576.381 rows=14268 loops=1
                                                                                 Node 16391: (actual time=27.139..1705.501 rows=13318 loops=3)
                                                                                   Worker 0: actual time=27.136..1705.630 rows=14322 loops=1
                                                                                   Worker 1: actual time=27.136..1705.482 rows=12953 loops=1
                                                                                 ->  Hash Join  (cost=5.33..26607.82 rows=667 width=30) (never executed)
                                                                                       Output: supplier.s_name, supplier.s_suppkey
                                                                                       Inner Unique: true
                                                                                       Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                                                       Node 16387: (actual time=0.082..23.557 rows=2643 loops=3)
                                                                                         Worker 0: actual time=0.101..23.671 rows=2886 loops=1
                                                                                         Worker 1: actual time=0.072..23.620 rows=2327 loops=1
                                                                                       Node 16388: (actual time=0.076..23.342 rows=2670 loops=3)
                                                                                         Worker 0: actual time=0.114..23.168 rows=2358 loops=1
                                                                                         Worker 1: actual time=0.072..23.376 rows=2752 loops=1
                                                                                       Node 16389: (actual time=0.068..25.916 rows=2721 loops=3)
                                                                                         Worker 0: actual time=0.076..26.596 rows=2978 loops=1
                                                                                         Worker 1: actual time=0.086..25.180 rows=2157 loops=1
                                                                                       Node 16390: (actual time=0.070..24.544 rows=2609 loops=3)
                                                                                         Worker 0: actual time=0.067..23.853 rows=2660 loops=1
                                                                                         Worker 1: actual time=0.078..25.100 rows=2602 loops=1
                                                                                       Node 16391: (actual time=0.081..23.776 rows=2674 loops=3)
                                                                                         Worker 0: actual time=0.080..23.556 rows=2811 loops=1
                                                                                         Worker 1: actual time=0.089..23.696 rows=2723 loops=1
                                                                                       ->  Parallel Seq Scan on public.supplier  (cost=0.00..26346.67 rows=83333 width=34) (never executed)
                                                                                             Output: supplier.s_suppkey, supplier.s_name, supplier.s_address, supplier.s_nationkey, supplier.s_phone, supplier.s_acctbal, supplier.s_comment
                                                                                             Remote node: 16389,16387,16390,16388,16391
                                                                                             Node 16387: (actual time=0.033..14.836 rows=66574 loops=3)
                                                                                               Worker 0: actual time=0.049..14.448 rows=70702 loops=1
                                                                                               Worker 1: actual time=0.034..15.768 rows=60042 loops=1
                                                                                             Node 16388: (actual time=0.029..14.197 rows=66745 loops=3)
                                                                                               Worker 0: actual time=0.046..15.046 rows=58371 loops=1
                                                                                               Worker 1: actual time=0.037..13.829 rows=69991 loops=1
                                                                                             Node 16389: (actual time=0.029..15.982 rows=66657 loops=3)
                                                                                               Worker 0: actual time=0.041..16.505 rows=74733 loops=1
                                                                                               Worker 1: actual time=0.042..15.418 rows=53505 loops=1
                                                                                             Node 16390: (actual time=0.025..15.047 rows=66790 loops=3)
                                                                                               Worker 0: actual time=0.017..14.582 rows=66383 loops=1
                                                                                               Worker 1: actual time=0.041..15.408 rows=68244 loops=1
                                                                                             Node 16391: (actual time=0.036..14.625 rows=66568 loops=3)
                                                                                               Worker 0: actual time=0.041..14.083 rows=68519 loops=1
                                                                                               Worker 1: actual time=0.045..14.190 rows=69119 loops=1
                                                                                       ->  Hash  (cost=5.31..5.31 rows=1 width=4) (never executed)
                                                                                             Output: nation.n_nationkey
                                                                                             Node 16387: (actual time=0.028..0.029 rows=1 loops=3)
                                                                                               Worker 0: actual time=0.017..0.018 rows=1 loops=1
                                                                                               Worker 1: actual time=0.026..0.026 rows=1 loops=1
                                                                                             Node 16388: (actual time=0.025..0.026 rows=1 loops=3)
                                                                                               Worker 0: actual time=0.031..0.032 rows=1 loops=1
                                                                                               Worker 1: actual time=0.019..0.020 rows=1 loops=1
                                                                                             Node 16389: (actual time=0.029..0.030 rows=1 loops=3)
                                                                                               Worker 0: actual time=0.025..0.026 rows=1 loops=1
                                                                                               Worker 1: actual time=0.034..0.035 rows=1 loops=1
                                                                                             Node 16390: (actual time=0.033..0.034 rows=1 loops=3)
                                                                                               Worker 0: actual time=0.040..0.041 rows=1 loops=1
                                                                                               Worker 1: actual time=0.026..0.027 rows=1 loops=1
                                                                                             Node 16391: (actual time=0.029..0.030 rows=1 loops=3)
                                                                                               Worker 0: actual time=0.027..0.028 rows=1 loops=1
                                                                                               Worker 1: actual time=0.028..0.028 rows=1 loops=1
                                                                                             ->  Seq Scan on public.nation  (cost=0.00..5.31 rows=1 width=4) (never executed)
                                                                                                   Output: nation.n_nationkey
                                                                                                   Filter: (nation.n_name = 'SAUDI ARABIA'::bpchar)
                                                                                                   Remote node: 16387,16388,16389,16390,16391
                                                                                                   Node 16387: (actual time=0.020..0.021 rows=1 loops=3)
                                                                                                     Worker 0: actual time=0.014..0.014 rows=1 loops=1
                                                                                                     Worker 1: actual time=0.016..0.017 rows=1 loops=1
                                                                                                   Node 16388: (actual time=0.018..0.019 rows=1 loops=3)
                                                                                                     Worker 0: actual time=0.021..0.023 rows=1 loops=1
                                                                                                     Worker 1: actual time=0.014..0.015 rows=1 loops=1
                                                                                                   Node 16389: (actual time=0.022..0.023 rows=1 loops=3)
                                                                                                     Worker 0: actual time=0.018..0.019 rows=1 loops=1
                                                                                                     Worker 1: actual time=0.025..0.026 rows=1 loops=1
                                                                                                   Node 16390: (actual time=0.027..0.027 rows=1 loops=3)
                                                                                                     Worker 0: actual time=0.031..0.031 rows=1 loops=1
                                                                                                     Worker 1: actual time=0.023..0.023 rows=1 loops=1
                                                                                                   Node 16391: (actual time=0.023..0.023 rows=1 loops=3)
                                                                                                     Worker 0: actual time=0.021..0.022 rows=1 loops=1
                                                                                                     Worker 1: actual time=0.022..0.022 rows=1 loops=1
                                                   ->  Parallel Hash  (cost=13749196.87..13749196.87 rows=50002358 width=8) (actual time=0.001..0.002 rows=0 loops=1)
                                                         Output: l2.l_orderkey, l2.l_suppkey
                                                         Buckets: 131072  Batches: 2048  Memory Usage: 1024kB
                                                         Node 16387: (actual time=22293.771..22293.772 rows=39999804 loops=3)
                                                           Worker 0: actual time=22294.025..22294.026 rows=39202159 loops=1
                                                           Worker 1: actual time=22293.138..22293.138 rows=40890134 loops=1
                                                         Node 16388: (actual time=21821.984..21821.984 rows=40004963 loops=3)
                                                           Worker 0: actual time=21822.264..21822.264 rows=40696071 loops=1
                                                           Worker 1: actual time=21822.281..21822.281 rows=38378661 loops=1
                                                         Node 16389: (actual time=21683.366..21683.367 rows=39999542 loops=3)
                                                           Worker 0: actual time=21683.704..21683.705 rows=40394746 loops=1
                                                           Worker 1: actual time=21683.631..21683.632 rows=38056816 loops=1
                                                         Node 16390: (actual time=21489.672..21489.673 rows=40003653 loops=3)
                                                           Worker 0: actual time=21489.988..21489.989 rows=38223374 loops=1
                                                           Worker 1: actual time=21489.958..21489.959 rows=40608087 loops=1
                                                         Node 16391: (actual time=21485.785..21485.785 rows=40004672 loops=3)
                                                           Worker 0: actual time=21486.084..21486.084 rows=40554757 loops=1
                                                           Worker 1: actual time=21486.085..21486.085 rows=40463518 loops=1
                                                         ->  Parallel Seq Scan on public.lineitem l2  (cost=0.00..13749196.87 rows=50002358 width=8) (actual time=0.001..0.001 rows=0 loops=1)
                                                               Output: l2.l_orderkey, l2.l_suppkey
                                                               Remote node: 16389,16387,16390,16388,16391
                                                               Node 16387: (actual time=0.011..12225.684 rows=39999804 loops=3)
                                                                 Worker 0: actual time=0.012..12302.449 rows=39202159 loops=1
                                                                 Worker 1: actual time=0.007..11957.714 rows=40890134 loops=1
                                                               Node 16388: (actual time=0.009..11910.743 rows=40004963 loops=3)
                                                                 Worker 0: actual time=0.008..11722.382 rows=40696071 loops=1
                                                                 Worker 1: actual time=0.012..12191.909 rows=38378661 loops=1
                                                               Node 16389: (actual time=0.021..11527.729 rows=39999542 loops=3)
                                                                 Worker 0: actual time=0.027..11484.924 rows=40394746 loops=1
                                                                 Worker 1: actual time=0.028..12008.811 rows=38056816 loops=1
                                                               Node 16390: (actual time=0.012..11372.659 rows=40003653 loops=3)
                                                                 Worker 0: actual time=0.016..11924.460 rows=38223374 loops=1
                                                                 Worker 1: actual time=0.008..11025.735 rows=40608087 loops=1
                                                               Node 16391: (actual time=0.009..11468.153 rows=40004672 loops=3)
                                                                 Worker 0: actual time=0.009..11393.682 rows=40554757 loops=1
                                                                 Worker 1: actual time=0.007..11394.772 rows=40463518 loops=1
                                             ->  Parallel Hash  (cost=15624285.27..15624285.27 rows=16667452 width=8) (actual time=0.010..0.010 rows=0 loops=1)
                                                   Output: l3.l_orderkey, l3.l_suppkey
                                                   Buckets: 131072  Batches: 1024  Memory Usage: 1024kB
                                                   Node 16387: (actual time=21228.009..21228.009 rows=25288296 loops=3)
                                                     Worker 0: actual time=21227.200..21227.200 rows=25183841 loops=1
                                                     Worker 1: actual time=21227.222..21227.222 rows=25504412 loops=1
                                                   Node 16388: (actual time=20731.997..20731.998 rows=25294532 loops=3)
                                                     Worker 0: actual time=20731.175..20731.176 rows=25751439 loops=1
                                                     Worker 1: actual time=20731.201..20731.202 rows=24405258 loops=1
                                                   Node 16389: (actual time=20586.911..20586.911 rows=25286180 loops=3)
                                                     Worker 0: actual time=20586.040..20586.040 rows=25295647 loops=1
                                                     Worker 1: actual time=20586.024..20586.024 rows=24481584 loops=1
                                                   Node 16390: (actual time=20483.500..20483.500 rows=25290584 loops=3)
                                                     Worker 0: actual time=20482.580..20482.580 rows=24076071 loops=1
                                                     Worker 1: actual time=20482.597..20482.598 rows=25718346 loops=1
                                                   Node 16391: (actual time=20357.849..20357.850 rows=25292566 loops=3)
                                                     Worker 0: actual time=20356.942..20356.943 rows=25507357 loops=1
                                                     Worker 1: actual time=20356.936..20356.937 rows=25550825 loops=1
                                                   ->  Parallel Seq Scan on public.lineitem l3  (cost=0.00..15624285.27 rows=16667452 width=8) (actual time=0.007..0.007 rows=0 loops=1)
                                                         Output: l3.l_orderkey, l3.l_suppkey
                                                         Filter: ((l3.l_receiptdate)::timestamp without time zone > (l3.l_commitdate)::timestamp without time zone)
                                                         Remote node: 16389,16387,16390,16388,16391
                                                         Node 16387: (actual time=0.026..14779.721 rows=25288296 loops=3)
                                                           Worker 0: actual time=0.030..14760.147 rows=25183841 loops=1
                                                           Worker 1: actual time=0.030..14627.934 rows=25504412 loops=1
                                                         Node 16388: (actual time=0.021..14276.484 rows=25294532 loops=3)
                                                           Worker 0: actual time=0.032..14069.028 rows=25751439 loops=1
                                                           Worker 1: actual time=0.010..14466.251 rows=24405258 loops=1
                                                         Node 16389: (actual time=0.024..13925.788 rows=25286180 loops=3)
                                                           Worker 0: actual time=0.028..13908.285 rows=25295647 loops=1
                                                           Worker 1: actual time=0.034..14123.309 rows=24481584 loops=1
                                                         Node 16390: (actual time=0.013..13870.349 rows=25290584 loops=3)
                                                           Worker 0: actual time=0.012..14287.123 rows=24076071 loops=1
                                                           Worker 1: actual time=0.012..13552.523 rows=25718346 loops=1
                                                         Node 16391: (actual time=0.011..13784.173 rows=25292566 loops=3)
                                                           Worker 0: actual time=0.010..13675.349 rows=25507357 loops=1
                                                           Worker 1: actual time=0.008..13741.547 rows=25550825 loops=1
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
         Node 16388: (actual time=14757.395..14916.761 rows=2 loops=1)
         Node 16387: (actual time=14731.285..14896.738 rows=2 loops=1)
         Node 16389: (actual time=14815.043..14962.541 rows=1 loops=1)
         Node 16390: (actual time=14794.358..14945.924 rows=1 loops=1)
         Node 16391: (actual time=14766.832..14937.197 rows=1 loops=1)
         InitPlan 1 (returns $0)
           ->  Cluster Reduce  (cost=523450.26..523453.57 rows=1 width=32) (never executed)
                 Reduce: unnest('[0:5]={12338,16387,16388,16389,16390,16391}'::oid[])
                 Node 16388: (actual time=45.882..45.943 rows=1 loops=1)
                 Node 16387: (actual time=19.823..19.870 rows=1 loops=1)
                 Node 16389: (actual time=62.718..62.790 rows=1 loops=1)
                 Node 16390: (actual time=43.509..43.598 rows=1 loops=1)
                 Node 16391: (actual time=14.446..14.529 rows=1 loops=1)
                 ->  Finalize Aggregate  (cost=523449.26..523449.27 rows=1 width=32) (actual time=825.015..825.016 rows=1 loops=1)
                       Output: avg(customer_1.c_acctbal)
                       Node 16388: (actual time=0.000..0.053 rows=0 loops=1)
                       Node 16387: (actual time=0.000..0.047 rows=0 loops=1)
                       Node 16389: (actual time=0.000..0.058 rows=0 loops=1)
                       Node 16390: (actual time=0.000..0.058 rows=0 loops=1)
                       Node 16391: (actual time=0.000..0.056 rows=0 loops=1)
                       ->  Cluster Reduce  (cost=523443.00..523449.21 rows=10 width=32) (actual time=0.033..824.992 rows=16 loops=1)
                             Reduce: '12338'::oid
                             Node 16388: (never executed)
                             Node 16387: (never executed)
                             Node 16389: (never executed)
                             Node 16390: (never executed)
                             Node 16391: (never executed)
                             ->  Gather  (cost=523442.00..523442.21 rows=2 width=32) (actual time=0.028..0.030 rows=1 loops=1)
                                   Output: (PARTIAL avg(customer_1.c_acctbal))
                                   Workers Planned: 2
                                   Workers Launched: 0
                                   Node 16388: (actual time=778.645..778.784 rows=3 loops=1)
                                   Node 16387: (actual time=804.467..804.580 rows=3 loops=1)
                                   Node 16389: (actual time=761.853..761.990 rows=3 loops=1)
                                   Node 16390: (actual time=782.372..782.510 rows=3 loops=1)
                                   Node 16391: (actual time=810.047..810.213 rows=3 loops=1)
                                   ->  Partial Aggregate  (cost=522442.00..522442.01 rows=1 width=32) (actual time=0.027..0.028 rows=1 loops=1)
                                         Output: PARTIAL avg(customer_1.c_acctbal)
                                         Node 16388: (actual time=776.702..776.703 rows=1 loops=3)
                                           Worker 0: actual time=775.781..775.782 rows=1 loops=1
                                           Worker 1: actual time=775.857..775.858 rows=1 loops=1
                                         Node 16387: (actual time=802.538..802.539 rows=1 loops=3)
                                           Worker 0: actual time=801.576..801.576 rows=1 loops=1
                                           Worker 1: actual time=801.770..801.771 rows=1 loops=1
                                         Node 16389: (actual time=759.571..759.572 rows=1 loops=3)
                                           Worker 0: actual time=758.516..758.516 rows=1 loops=1
                                           Worker 1: actual time=758.525..758.526 rows=1 loops=1
                                         Node 16390: (actual time=780.136..780.137 rows=1 loops=3)
                                           Worker 0: actual time=779.093..779.094 rows=1 loops=1
                                           Worker 1: actual time=779.106..779.106 rows=1 loops=1
                                         Node 16391: (actual time=807.786..807.787 rows=1 loops=3)
                                           Worker 0: actual time=806.755..806.756 rows=1 loops=1
                                           Worker 1: actual time=806.756..806.757 rows=1 loops=1
                                         ->  Parallel Seq Scan on public.customer customer_1  (cost=0.00..522342.66 rows=39734 width=6) (actual time=0.022..0.023 rows=0 loops=1)
                                               Output: customer_1.c_custkey, customer_1.c_name, customer_1.c_address, customer_1.c_nationkey, customer_1.c_phone, customer_1.c_acctbal, customer_1.c_mktsegment, customer_1.c_comment
                                               Filter: ((customer_1.c_acctbal > 0.00) AND ("substring"((customer_1.c_phone)::text, 1, 2) = ANY ('{13,31,23,29,30,18,17}'::text[])))
                                               Remote node: 16389,16387,16390,16388,16391
                                               Node 16388: (actual time=0.030..742.327 rows=254597 loops=3)
                                                 Worker 0: actual time=0.032..742.340 rows=247186 loops=1
                                                 Worker 1: actual time=0.032..741.522 rows=254564 loops=1
                                               Node 16387: (actual time=0.038..768.216 rows=254437 loops=3)
                                                 Worker 0: actual time=0.037..766.941 rows=257137 loops=1
                                                 Worker 1: actual time=0.041..767.077 rows=257355 loops=1
                                               Node 16389: (actual time=0.034..725.199 rows=254875 loops=3)
                                                 Worker 0: actual time=0.035..724.100 rows=255475 loops=1
                                                 Worker 1: actual time=0.038..724.495 rows=251867 loops=1
                                               Node 16390: (actual time=0.042..745.907 rows=254171 loops=3)
                                                 Worker 0: actual time=0.037..744.491 rows=257291 loops=1
                                                 Worker 1: actual time=0.041..744.229 rows=258735 loops=1
                                               Node 16391: (actual time=0.040..773.332 rows=254977 loops=3)
                                                 Worker 0: actual time=0.031..772.254 rows=255259 loops=1
                                                 Worker 1: actual time=0.041..773.074 rows=248821 loops=1
         ->  Sort  (cost=4986773.94..4986781.91 rows=3188 width=72) (never executed)
               Output: ("substring"((customer.c_phone)::text, 1, 2)), (PARTIAL count(*)), (PARTIAL sum(customer.c_acctbal))
               Sort Key: ("substring"((customer.c_phone)::text, 1, 2))
               Node 16388: (actual time=14757.374..14916.677 rows=30 loops=1)
               Node 16387: (actual time=14731.257..14896.652 rows=30 loops=1)
               Node 16389: (actual time=14815.014..14962.453 rows=15 loops=1)
               Node 16390: (actual time=14794.328..14945.836 rows=15 loops=1)
               Node 16391: (actual time=14766.798..14937.108 rows=15 loops=1)
               ->  Cluster Reduce  (cost=4985972.63..4986588.43 rows=3188 width=72) (never executed)
                     Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashtext(("substring"((customer.c_phone)::text, 1, 2)))), 0)]
                     Node 16388: (actual time=14636.917..14916.600 rows=30 loops=1)
                     Node 16387: (actual time=14730.850..14896.544 rows=30 loops=1)
                     Node 16389: (actual time=14270.377..14962.374 rows=15 loops=1)
                     Node 16390: (actual time=14494.835..14945.769 rows=15 loops=1)
                     Node 16391: (actual time=14460.784..14937.015 rows=15 loops=1)
                     ->  Gather  (cost=4985971.63..4986318.33 rows=3188 width=72) (never executed)
                           Output: ("substring"((customer.c_phone)::text, 1, 2)), (PARTIAL count(*)), (PARTIAL sum(customer.c_acctbal))
                           Workers Planned: 2
                           Params Evaluated: $0
                           Workers Launched: 0
                           Node 16388: (actual time=14636.824..14796.531 rows=21 loops=1)
                           Node 16387: (actual time=14730.742..14896.407 rows=21 loops=1)
                           Node 16389: (actual time=14270.294..14417.957 rows=21 loops=1)
                           Node 16390: (actual time=14494.731..14646.711 rows=21 loops=1)
                           Node 16391: (actual time=14460.688..14631.402 rows=21 loops=1)
                           ->  Partial HashAggregate  (cost=4984971.63..4984999.53 rows=1594 width=72) (never executed)
                                 Output: ("substring"((customer.c_phone)::text, 1, 2)), PARTIAL count(*), PARTIAL sum(customer.c_acctbal)
                                 Group Key: "substring"((customer.c_phone)::text, 1, 2)
                                 Node 16388: (actual time=14588.413..14588.452 rows=7 loops=3)
                                   Worker 0: actual time=14587.289..14587.321 rows=7 loops=1
                                   Worker 1: actual time=14587.382..14587.420 rows=7 loops=1
                                 Node 16387: (actual time=14708.440..14708.480 rows=7 loops=3)
                                   Worker 0: actual time=14707.387..14707.423 rows=7 loops=1
                                   Worker 1: actual time=14707.404..14707.445 rows=7 loops=1
                                 Node 16389: (actual time=14205.006..14205.048 rows=7 loops=3)
                                   Worker 0: actual time=14203.917..14203.953 rows=7 loops=1
                                   Worker 1: actual time=14203.917..14203.957 rows=7 loops=1
                                 Node 16390: (actual time=14448.405..14448.445 rows=7 loops=3)
                                   Worker 0: actual time=14447.309..14447.353 rows=7 loops=1
                                   Worker 1: actual time=14447.358..14447.395 rows=7 loops=1
                                 Node 16391: (actual time=14443.531..14443.577 rows=7 loops=3)
                                   Worker 0: actual time=14442.368..14442.412 rows=7 loops=1
                                   Worker 1: actual time=14442.402..14442.442 rows=7 loops=1
                                 ->  Parallel Hash Anti Join  (cost=4413422.56..4984959.68 rows=1594 width=38) (never executed)
                                       Output: "substring"((customer.c_phone)::text, 1, 2), customer.c_acctbal
                                       Hash Cond: (customer.c_custkey = orders.o_custkey)
                                       Node 16388: (actual time=11944.862..14575.792 rows=42473 loops=3)
                                         Worker 0: actual time=11948.233..14575.111 rows=41281 loops=1
                                         Worker 1: actual time=11934.055..14574.250 rows=43889 loops=1
                                       Node 16387: (actual time=12465.476..14695.732 rows=42562 loops=3)
                                         Worker 0: actual time=12469.012..14694.535 rows=43407 loops=1
                                         Worker 1: actual time=12468.817..14694.457 rows=43200 loops=1
                                       Node 16389: (actual time=11889.761..14192.347 rows=42434 loops=3)
                                         Worker 0: actual time=11879.310..14191.026 rows=43055 loops=1
                                         Worker 1: actual time=11893.392..14191.227 rows=42845 loops=1
                                       Node 16390: (actual time=11998.041..14435.722 rows=42442 loops=3)
                                         Worker 0: actual time=12001.571..14434.519 rows=43023 loops=1
                                         Worker 1: actual time=11987.629..14435.072 rows=41002 loops=1
                                       Node 16391: (actual time=11954.300..14430.861 rows=42338 loops=3)
                                         Worker 0: actual time=11958.761..14430.729 rows=39110 loops=1
                                         Worker 1: actual time=11943.250..14429.393 rows=43421 loops=1
                                       ->  Parallel Seq Scan on public.customer  (cost=0.00..522342.66 rows=14584 width=26) (never executed)
                                             Output: customer.c_phone, customer.c_acctbal, customer.c_custkey
                                             Filter: ((customer.c_acctbal > $0) AND ("substring"((customer.c_phone)::text, 1, 2) = ANY ('{13,31,23,29,30,18,17}'::text[])))
                                             Remote node: 16389,16387,16390,16388,16391
                                             Node 16388: (actual time=0.108..604.582 rows=127265 loops=3)
                                               Worker 0: actual time=0.141..606.087 rows=129012 loops=1
                                               Worker 1: actual time=0.150..602.840 rows=120646 loops=1
                                             Node 16387: (actual time=0.132..628.077 rows=127238 loops=3)
                                               Worker 0: actual time=0.143..626.110 rows=130650 loops=1
                                               Worker 1: actual time=0.175..626.849 rows=130406 loops=1
                                             Node 16389: (actual time=0.098..584.154 rows=127579 loops=3)
                                               Worker 0: actual time=0.112..584.999 rows=128189 loops=1
                                               Worker 1: actual time=0.095..583.207 rows=127189 loops=1
                                             Node 16390: (actual time=0.084..609.585 rows=127110 loops=3)
                                               Worker 0: actual time=0.124..614.146 rows=125678 loops=1
                                               Worker 1: actual time=0.083..605.881 rows=129333 loops=1
                                             Node 16391: (actual time=0.129..629.687 rows=127364 loops=3)
                                               Worker 0: actual time=0.146..623.668 rows=129512 loops=1
                                               Worker 1: actual time=0.190..632.425 rows=126005 loops=1
                                       ->  Parallel Hash  (cost=4208345.78..4208345.78 rows=12499902 width=4) (never executed)
                                             Output: orders.o_custkey
                                             Node 16388: (actual time=11205.694..11205.694 rows=10010593 loops=3)
                                               Worker 0: actual time=11204.799..11204.800 rows=10084228 loops=1
                                               Worker 1: actual time=11204.782..11204.783 rows=9758862 loops=1
                                             Node 16387: (actual time=11714.386..11714.387 rows=9988141 loops=3)
                                               Worker 0: actual time=11713.519..11713.519 rows=9925402 loops=1
                                               Worker 1: actual time=11713.516..11713.517 rows=10039721 loops=1
                                             Node 16389: (actual time=11184.986..11184.986 rows=10006856 loops=3)
                                               Worker 0: actual time=11184.063..11184.063 rows=10063309 loops=1
                                               Worker 1: actual time=11184.072..11184.072 rows=9980940 loops=1
                                             Node 16390: (actual time=11260.074..11260.075 rows=9991966 loops=3)
                                               Worker 0: actual time=11259.103..11259.103 rows=10160815 loops=1
                                               Worker 1: actual time=11259.086..11259.087 rows=10046056 loops=1
                                             Node 16391: (actual time=11184.566..11184.567 rows=10002444 loops=3)
                                               Worker 0: actual time=11183.498..11183.498 rows=9734178 loops=1
                                               Worker 1: actual time=11183.594..11183.595 rows=10252531 loops=1
                                             ->  Cluster Reduce  (cost=1.00..4208345.78 rows=12499902 width=4) (never executed)
                                                   Reduce: ('[0:4]={16389,16387,16390,16388,16391}'::oid[])[COALESCE(hash_combin_mod(5, hashint4(orders.o_custkey)), 0)]
                                                   Node 16388: (actual time=8402.082..9655.522 rows=10010593 loops=3)
                                                     Worker 0: actual time=8401.162..9666.149 rows=10084228 loops=1
                                                     Worker 1: actual time=8401.159..9626.626 rows=9758862 loops=1
                                                   Node 16387: (actual time=9293.625..10142.203 rows=9988141 loops=3)
                                                     Worker 0: actual time=9292.732..10129.413 rows=9925402 loops=1
                                                     Worker 1: actual time=9292.724..10138.976 rows=10039721 loops=1
                                                   Node 16389: (actual time=8723.564..9606.846 rows=10006856 loops=3)
                                                     Worker 0: actual time=8722.622..9608.743 rows=10063309 loops=1
                                                     Worker 1: actual time=8722.623..9600.134 rows=9980940 loops=1
                                                   Node 16390: (actual time=8837.760..9656.169 rows=9991966 loops=3)
                                                     Worker 0: actual time=8836.757..9672.850 rows=10160815 loops=1
                                                     Worker 1: actual time=8836.768..9676.121 rows=10046056 loops=1
                                                   Node 16391: (actual time=8740.811..9596.244 rows=10002444 loops=3)
                                                     Worker 0: actual time=8739.703..9600.584 rows=9734178 loops=1
                                                     Worker 1: actual time=8739.834..9601.804 rows=10252531 loops=1
                                                   ->  Parallel Seq Scan on public.orders  (cost=0.00..3234231.13 rows=12499902 width=4) (never executed)
                                                         Output: orders.o_custkey
                                                         Remote node: 16389,16387,16390,16388,16391
                                                         Node 16388: (actual time=0.021..2510.304 rows=10001059 loops=3)
                                                           Worker 0: actual time=0.023..2452.800 rows=9472626 loops=1
                                                           Worker 1: actual time=0.023..2697.353 rows=10346136 loops=1
                                                         Node 16387: (actual time=0.030..2573.262 rows=9998956 loops=3)
                                                           Worker 0: actual time=0.029..2742.244 rows=10268375 loops=1
                                                           Worker 1: actual time=0.032..2675.501 rows=10175233 loops=1
                                                         Node 16389: (actual time=0.022..2169.543 rows=10000114 loops=3)
                                                           Worker 0: actual time=0.023..2184.560 rows=10015798 loops=1
                                                           Worker 1: actual time=0.024..2259.557 rows=10542433 loops=1
                                                         Node 16390: (actual time=0.028..2434.435 rows=9999806 loops=3)
                                                           Worker 0: actual time=0.032..2431.072 rows=10302688 loops=1
                                                           Worker 1: actual time=0.034..2515.310 rows=10026091 loops=1
                                                         Node 16391: (actual time=0.022..2653.456 rows=10000065 loops=3)
                                                           Worker 0: actual time=0.021..2446.285 rows=9601081 loops=1
                                                           Worker 1: actual time=0.024..2926.798 rows=10551767 loops=1
 Planning Time: 1.089 ms
 Execution Time: 15751.630 ms
(212 rows)
  
-- end
select now();

