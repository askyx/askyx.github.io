# 执行计划

```sql

set enable_mergejoin=off;
set enable_nestloop=off;

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
-----------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=3351813.70..3351813.71 rows=5 width=0)
   ->  Cluster Merge Gather  (cost=3351813.70..3351813.71 rows=5 width=0)
         Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
         ->  Limit  (cost=3350813.60..3350813.61 rows=1 width=193)
               ->  Sort  (cost=3350813.60..3350813.61 rows=0 width=193)
                     Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
                     ->  Hash Join  (cost=745359.38..3350813.59 rows=0 width=193)
                           Hash Cond: ((partsupp.ps_partkey = part.p_partkey) AND (partsupp.ps_supplycost = (SubPlan 1)))
                           ->  Hash Join  (cost=35483.36..2640803.16 rows=25603 width=173)
                                 Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                                 ->  Seq Scan on partsupp  (cost=0.00..2544033.48 rows=16001650 width=14)
                                 ->  Hash  (cost=35383.36..35383.36 rows=8000 width=167)
                                       ->  Cluster Reduce  (cost=3.36..35383.36 rows=8000 width=167)
                                             ->  Hash Join  (cost=2.36..33012.36 rows=1600 width=167)
                                                   Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                                   ->  Seq Scan on supplier  (cost=0.00..32180.00 rows=200000 width=145)
                                                   ->  Hash  (cost=2.35..2.35 rows=1 width=30)
                                                         ->  Hash Join  (cost=1.07..2.35 rows=1 width=30)
                                                               Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                               ->  Seq Scan on nation  (cost=0.00..1.25 rows=5 width=34)
                                                               ->  Hash  (cost=1.06..1.06 rows=1 width=4)
                                                                     ->  Seq Scan on region  (cost=0.00..1.06 rows=1 width=4)
                                                                           Filter: (r_name = 'EUROPE'::bpchar)
                           ->  Hash  (cost=709609.29..709609.29 rows=17782 width=30)
                                 ->  Seq Scan on part  (cost=0.00..709609.29 rows=17782 width=30)
                                       Filter: (((p_type)::text ~~ '%BRASS'::text) AND (p_size = 15))
                                 SubPlan 1
                                   ->  Materialize  (cost=28851255.69..28851255.71 rows=1 width=32)
                                         ->  Aggregate  (cost=28851255.69..28851255.70 rows=1 width=32)
                                               ->  Hash Join  (cost=35610.36..28851255.69 rows=1 width=6)
                                                     Hash Cond: (partsupp_1.ps_suppkey = supplier_1.s_suppkey)
                                                     ->  Reduce Scan  (cost=1.00..28509214.73 rows=80008250 width=10)
                                                           Filter: (part.p_partkey = ps_partkey)
                                                           ->  Cluster Reduce  (cost=1.00..27718507.48 rows=80008250 width=14)
                                                                 ->  Seq Scan on partsupp partsupp_1  (cost=0.00..2544033.48 rows=16001650 width=14)
                                                     ->  Hash  (cost=35509.36..35509.36 rows=8000 width=4)
                                                           ->  Cluster Reduce  (cost=3.36..35509.36 rows=8000 width=4)
                                                                 ->  Hash Join  (cost=2.36..33012.36 rows=1600 width=4)
                                                                       Hash Cond: (supplier_1.s_nationkey = nation_1.n_nationkey)
                                                                       ->  Seq Scan on supplier supplier_1  (cost=0.00..32180.00 rows=200000 width=8)
                                                                       ->  Hash  (cost=2.35..2.35 rows=1 width=4)
                                                                             ->  Hash Join  (cost=1.07..2.35 rows=1 width=4)
                                                                                   Hash Cond: (nation_1.n_regionkey = region_1.r_regionkey)
                                                                                   ->  Seq Scan on nation nation_1  (cost=0.00..1.25 rows=5 width=8)
                                                                                   ->  Hash  (cost=1.06..1.06 rows=1 width=4)
                                                                                         ->  Seq Scan on region region_1  (cost=0.00..1.06 rows=1 width=4)
                                                                                               Filter: (r_name = 'EUROPE'::bpchar)
(47 rows)


                                                         QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=85.86..85.87 rows=1 width=716)
   ->  Sort  (cost=85.86..85.87 rows=1 width=716)
         Sort Key: supplier.s_acctbal DESC, nation.n_name, supplier.s_name, part.p_partkey
         ->  Hash Join  (cost=48.95..85.73 rows=1 width=716)
               Hash Cond: ((part.p_partkey = partsupp.ps_partkey) AND ((SubPlan 1) = partsupp.ps_supplycost))
               ->  Seq Scan on part  (cost=0.00..12.40 rows=1 width=108)
                     Filter: (((p_type)::text ~~ '%BRASS'::text) AND (p_size = 15))
               ->  Hash  (cost=48.93..48.93 rows=1 width=630)
                     ->  Hash Join  (cost=36.58..48.93 rows=1 width=630)
                           Hash Cond: (partsupp.ps_suppkey = supplier.s_suppkey)
                           ->  Seq Scan on partsupp  (cost=0.00..11.70 rows=170 width=26)
                           ->  Hash  (cost=36.57..36.57 rows=1 width=612)
                                 ->  Hash Join  (cost=24.50..36.57 rows=1 width=612)
                                       Hash Cond: (supplier.s_nationkey = nation.n_nationkey)
                                       ->  Seq Scan on supplier  (cost=0.00..11.50 rows=150 width=512)
                                       ->  Hash  (cost=24.48..24.48 rows=1 width=108)
                                             ->  Hash Join  (cost=12.14..24.48 rows=1 width=108)
                                                   Hash Cond: (nation.n_regionkey = region.r_regionkey)
                                                   ->  Seq Scan on nation  (cost=0.00..11.70 rows=170 width=112)
                                                   ->  Hash  (cost=12.12..12.12 rows=1 width=4)
                                                         ->  Seq Scan on region  (cost=0.00..12.12 rows=1 width=4)
                                                               Filter: (r_name = 'EUROPE'::bpchar)
               SubPlan 1
                 ->  Aggregate  (cost=48.72..48.73 rows=1 width=32)
                       ->  Hash Join  (cost=36.36..48.72 rows=1 width=18)
                             Hash Cond: (nation_1.n_regionkey = region_1.r_regionkey)
                             ->  Hash Join  (cost=24.22..36.57 rows=1 width=22)
                                   Hash Cond: (nation_1.n_nationkey = supplier_1.s_nationkey)
                                   ->  Seq Scan on nation nation_1  (cost=0.00..11.70 rows=170 width=8)
                                   ->  Hash  (cost=24.21..24.21 rows=1 width=22)
                                         ->  Hash Join  (cost=12.14..24.21 rows=1 width=22)
                                               Hash Cond: (supplier_1.s_suppkey = partsupp_1.ps_suppkey)
                                               ->  Seq Scan on supplier supplier_1  (cost=0.00..11.50 rows=150 width=8)
                                               ->  Hash  (cost=12.12..12.12 rows=1 width=22)
                                                     ->  Seq Scan on partsupp partsupp_1  (cost=0.00..12.12 rows=1 width=22)
                                                           Filter: (part.p_partkey = ps_partkey)
                             ->  Hash  (cost=12.12..12.12 rows=1 width=4)
                                   ->  Seq Scan on region region_1  (cost=0.00..12.12 rows=1 width=4)
                                         Filter: (r_name = 'EUROPE'::bpchar)
(39 rows)

```

pg单机执行计划和antdb分布式执行计划大致一样，和之前gp的结论有

* join两边的字段都是分布键，没有数据重分布操作
  1. 如果使用条件，则对表达式进行hash计算执行节点，如果能计算到一个执行节点，则限定一个节点执行
* 大表join大表
  1. 其中一个join字段是分布键，另一个不是，此时非分布键的表会被重分布。
  2. 都不是分区键，两表都需要重分布
  3. 如果join字段使用条件，则对表达式进行hash计算执行节点，如果能计算到一个执行节点，则限定一个节点执行，重分布的motion还是继续在多个节点执行
* 小表join大表
  1. 小表用了分布键，小表广播
  2. 大表用了分布键，小表重分布
  3. 都不是分布键，小表广播
  4. 如果join字段使用条件，则对表达式进行hash计算执行节点，如果能计算到一个执行节点，则限定一个节点执行，重分布的motion还是继续在多个节点执行，这里需要考虑大表。

对于antdb的数据重分布，分为下面几种
1. 重分布
2. 聚集

对于重分布，主要是使用 `Cluster Reduce` 算子，按功能可以细分为
1. 广播
  执行计划中算子表现为 `Reduce: unnest('[0:1]={16386,16387}'::oid[])`
2. hash重分布
  执行计划中算子表现为 `Reduce: ('[0:1]={16386,16387}'::oid[])[COALESCE(hash_combin_mod(2, hashint4(t2.c2)), 0)]`

对于聚集，主要使用 `Cluster Gather` 算子，可以细分为
1. 非排序聚集
  执行计划中算子表现为 `Cluster Gather` ，主要是数据向cn聚集
2. 排序聚集
  执行计划中算子表现为 `Cluster Merge Gather`，主要是数据向cn聚集，但是聚集的数据要求有序，输出的数据也是有序的

还有一种独立于上面两种的算子 `Reduce Scan`，具备重分布和聚集操作

## 执行计划的实现

相比于单机，分布式就是需要把数据按照语句的语义进行数据重分布





# 执行器



pg_plan_query 执行计划入口

planner 实际执行计划调用
  这里提供一个planner_hook，以供自定义执行计划使用

standard_planner 默认planner hook
  入口处，判断SQL是否是可以并行查询的
    判断条件
    (cursorOptions & CURSOR_OPT_PARALLEL_OK) != 0 && 当前游标允许并行查询
    IsUnderPostmaster && 当前是直接调用的用户进程（postmaster的子进程），
    parse->commandType == CMD_SELECT && 当前是select
    !parse->hasModifyingCTE && 当前CTE是不可变集合
    max_parallel_workers_per_gather > 0 && parallel worker 设置大于0
    !IsParallelWorker() 当前不是worker的执行进程

    之后判定 glob->parallelModeNeeded = glob->parallelModeOK &&
    (force_parallel_mode != FORCE_PARALLEL_OFF);
    如果启用了force_parallel_mode，但查询不支持并行查询，则依然不使用并行查询
    如果使用了CURSOR_OPT_FAST_PLAN
      处理 tuple_fraction
      如果tuple_fraction>= 1 则设置为0
      如果tuple_fraction <=0 设置为 1e-10;
    否则 tuple_fraction=0

    之后执行subquery_planner 获取执行计划

    fetch_upper_rel 获取上层releation
    get_cheapest_fractional_path  选取最佳执行路径
    create_plan 创建执行计划

    对于CURSOR_OPT_SCROLL
      如果不支持后台执行ExecSupportsBackwardScan
      则附加一个物化查询计划 materialize_finished_plan

    对于可以并行的查询，这里处理gather进行可行性测试（不实际执行，但需要验证gather可以创建）
      创建gather
        执行列表
        worker数量
        并行执行计划
        gather->plan.startup_cost = top_plan->startup_cost + parallel_setup_cost;
        gather->plan.total_cost = top_plan->total_cost + parallel_setup_cost + parallel_tuple_cost * top_plan->plan_rows;
        执行代价计算
    最后执行一系列赋值，完成plan

  subquery_planner
    子查询计划，所有查询都是子查询迭代，这个函数处理实际的plan
    
    如果存在cte定义，则设置入SS_process_ctes
    如果没有from定义，使用replace_empty_jointree设置一个空值
    对于ANY以及 EXISTS ，执行pull_up_sublinks，也就是执行查询而非下推到子查询
    对于可以预先处理的函数，执行inline_set_returning_functions 设置为inline状态
    检查并合并所有可以合并的子查询pull_up_subqueries
    对于union all，执行flatten_simple_union_all合并到append rel。

    处理join的情况，逐个表进行迭代，根据rtekind进行判断
      RTE_RELATION
        如果设置了inh，检查是否为有子查询的项目，如果没有，清理inh标记
      RTE_JOIN
        如果是外查询，则设置外查询标记
      RTE_RESULT
        如果是结果，设置hasResultRTEs为true，这是执行计划全局设置
      如果设了lateral，则hasLateralRTEs为true
      
      最后设置安全查询级别

    执行RowMark的前置任务 preprocess_rowmarks

    如果设置了having 设置hasHavingQual标记

    清理hasPseudoConstantQuals标记，
      
    处理preprocess_expression表达式

    对于hasTargetSRFs默认为true(函数会返回一组返回值的情况），通过expression_returns_set计算得到其实际是否存在

    对于使用了WITH CHECK OPTION的情况，使用WithCheckOption处理所有表达式的qual到withCheckOptions

    计算returningList的返回情况，确定其返回单值还是list

    preprocess_qual_conditions逐个计算所有子查询的qual（约束）

    preprocess_expression计算当前查询的havingQual

    对于所有的windows调用
      设置windows起点
      设置window终点
    
    设置limit的offset和count

    对于设置了onConflict的情况
      处理设定的可能冲突的参数，冲突where条件，set操作，以及set关联的where条件

    初始化append_rel_list（根据当前append_rel_list预计算计算表达式）

    处理所有子表的RTE表达式
      RTE_RELATION 对象是表 设置为简单表查询
      RTE_SUBQUERY 对象是子查询 处理子查询的别名问题
      RTE_FUNCTION 对象是函数 直接调用preprocess_expression处理
      RTE_TABLEFUNC 对象是表函数（列的列表）直接调用preprocess_expression处理
      RTE_VALUES 对象是values列表，使用preprocess_expression处理
      
      最后处理安全设置rte->securityQuals

    对于存在hasJoinRTEs的情况，清理掉所有joinaliasvars（前面已经通过表达式预处理处理掉了别名的情况）

    尝试处理having操作到where条件里面
      对于
        包含子查询
        存在group set
        存在函数计算
        存在统计计算
      的条件，不处理
      对于没有group set的情况，处理having条件到where 
      其他条件having和where都复制一份
    
    去掉不必要的grouping列 remove_useless_groupby_columns

    reduce_outer_joins尝试去掉外查询，变成内联查询
    remove_useless_result_rtes 尝试删除没有被用到的结果表达式

    对于继承表执行inheritance_planner
    默认执行grouping_planner
    
    SS_identify_outer_params找到所需要外层传入的参数

    SS_charge_for_initplans 修改init计划
      重新计算initplan_cost： 每个子查询的initsubplan->startup_cost + initsubplan->per_call_cost;
      当前path->startup_cost，path->total_cost都会加上initplan_cost
    set_cheapest 最终确认当前是最优执行计划
      逐个检查所有执行路径，比较选择出来最小代价path
  
  grouping_planner 实际执行planner的内部
    设置limit和offset，对于offset没有设置的话，默认为0
    对于UNION/INTERSECT/EXCEPT 
      对于sortClause 存在sort的情况，设置tuple_fraction=0.0

      plan_set_operations
        使用最左（第一个）查询的列作为顺序
        对于递归union
          生成递归路径 generate_recursion_path ？ 
        默认执行 recurse_set_operations？
      检查是否可以并行is_parallel_safe(root, (Node *) final_target->exprs);
      这里再次检查不允许使用for update，for share关键字（语法层已经检查，这里再检查一遍）
      最后设置排序的顺序make_pathkeys_for_sortclauses
    对于grouping设置了sets的情况
      执行preprocess_grouping_sets预先处理
    否则正常处理group语法 preprocess_groupclause

    设置查询目标列表，方便上层使用 preprocess_targetlist

    处理执行代价
      get_agg_clause_costs

    对于windows函数
      find_window_functions找到所有函数，之后select_active_windows设置到activeWindows

    对于max，min计算，执行preprocess_minmax_aggregates （这里代码与query_planner重复，如果需要变更min、max逻辑，则需要两边一起改）

    确认是否有写死的limit_tuples以及非例外，如果有，采用写死的limit_tuples（例外为这些： group，group set，distinct，aggregation（聚合操作），windows函数，having条件，函数调用     设置root->limit_tuples = -1.0）

    设置windows回调activeWindows以及group回调groupClause，包括rollups

    执行query_planner standard_qp_callback 处理执行路径，并处理sort，distinct的情况

    转换processed_tlist到final_target create_pathtarget

    对于order by判断是否可以跳过排序阶段 make_sort_input_target
      比如distinct，union的情况
    对于windows函数，判断是否可以跳过group聚合操作 make_window_input_target
      如果已经有预先的处理
    对于having group（包括having，group，聚合函数，group set的情况）
      规划是否需要计算
    对于返回集合的函数 SRF set-returning functions
      切割出来stfs split_pathtarget_at_srfs
        final_target
        sort_input_target
        grouping_target
        scanjoin_target
    apply_scanjoin_target_to_paths 处理所有scan，join 表，并遍历其子代生成最终的扫描目标

    保存对象信息
      root->upper_targets[UPPERREL_FINAL] = final_target;
      root->upper_targets[UPPERREL_ORDERED] = final_target;
      root->upper_targets[UPPERREL_DISTINCT] = sort_input_target;
      root->upper_targets[UPPERREL_WINDOW] = sort_input_target;
      root->upper_targets[UPPERREL_GROUP_AGG] = grouping_target;
    
    create_grouping_paths创建grouping路径，对于SRF单独处理adjust_paths_for_srfs

    create_window_paths创建windows执行路径，对于SRF单独处理adjust_paths_for_srfs

    create_distinct_paths创建distinct执行路径，对于srf单独处理adjust_paths_for_srfs

    create_ordered_paths创建order by执行路径，对于srf单独处理adjust_paths_for_srfs

    获取上层rel fetch_upper_rel
      如果上层允许并行，则此处允许并行
      final_rel->consider_parallel = true;
    开始处理最终查询 遍历当前所有path
      对于for update，share 创建create_lockrows_path
      设置limit create_limit_path
      对于非select（insert，update，delete）新增ModifyTable节点 parse->commandType != CMD_SELECT && !inheritance_update
        使用索引
        检查check option withCheckOptionLists
        返回列表 returningLists
        行标记（加锁） rowMarks
        对于分区表单独标记 rootRelation

        创建create_modifytable_path 新增ModifyTable节点

        新增到执行path
    处理partial add_partial_path
      对于并行查询认为并不安全，单独处理
    
    记录额外信息
      extra.limit_needed = limit_needed(parse);
      extra.limit_tuples = limit_tuples;
      extra.count_est = count_est;
      extra.offset_est = offset_est;
    
    对于fdw
      GetForeignUpperPaths 新增fdw执行路径

    create_upper_paths_hook
      最后执行其他hook



  is_parallel_safe 并行是否安全
    对于参数来源为本查询，或者上层查询的情况，认为可以并行查询
    max_parallel_hazard_walker
      调用函数是自己节点上的，安全
      对于max min来说，并行查询是安全的
      proparallel
        PROPARALLEL_SAFE：false
        PROPARALLEL_RESTRICTED 返回 context->max_interesting == proparallel 
        PROPARALLEL_UNSAFE false context->max_hazard = proparallel;
      CoerceToDomain允许并行 domain类型不建议使用不可并行化的函数
      对于获取序列下一个号的情况，认为不安全
      windows函数认为是安全的
      SubLink（any之类）安全 //目前应该不会有这个执行路径
      对于子查询，只有安全的子查询才会被标记为可并行
      参数来自本查询，认为安全，如果是不可控，认为不安全
      for update、share 认为不安全
      如果以上情况都未命中，迭代检查子查询，以及参数


  apply_scanjoin_target_to_paths
    处理所有scan，join 表，并遍历其子代生成最终的扫描目标
    对于分区表，重新生成扫描对象
    对于不可以并行的查询，关闭并行查询
    逐个处理不涉及SRF的扫描
      对于tlist_same_exprs（表达式应用于当前对象）
        仅增加sort group 避免额外的执行计划创建代价
        否则 create_projection_path
          创建一个预测执行path，
    对于partial进行同样处理
    对于srf，逐个处理adjust_paths_for_srfs
    设置当前对象为最终的scan/join目标（即便是SRF）
    
    对于分区表
      生成Append scan、join发生在append下而非其上，最终聚合到单独的result处理
      逐个分区遍历
        把每个分区的扫描路径设置为分区路径而非表路径
          PathTarget *target = lfirst_node(PathTarget, lc);
          target = copy_pathtarget(target);
        附加扫描点到child_scanjoin_targets
        apply_scanjoin_target_to_paths替换原先的执行路径
        add_paths_to_append_rel新增执行路径
        apply_scanjoin_target_to_paths此处向内迭代
        live_children 仅处理实际存在的子分区（有可能是dummy对象）
    对于可以并行的查询（对象不是外查询对象）
      generate_gather_paths生成并行查询计划
        create_gather_path生成simple_gather_path
        对于每个path内的列表
          生成create_gather_merge_path
    最后重新选取代价最低的执行计划
      set_cheapest

  query_planner
    处理执行路径
  create_pathtarget
    创建执行路径
  get_agg_clause_costs 计算聚合代价
  create_projection_path 创建执行预测path
  make_sort_input_target 判断是否可以跳过sort
  make_window_input_target 判断是否可以跳过grouping操作    


新建节点和已有节点，其中一方启动成本和总成本都更优，且其pathkeys也更优，那么删除另外一个

新建节点和所有已有节点的启动成本和总成本两方面的对比不一致（如总成本高但启动成本较低，或反过来），且新建节点总成本较低，则会全部保留并添加到RelOptInfo->pathlist中。

新节点和已有节点，其中一方启动成和总成本都更优，但其pathkeys不够，则两者都保留，由上层Path节点来判断

当新建节点和已有节点成本相同时，则对比两者的pathkeys，选择保留更优pathkeys的节点

pathkeys：
      排序属性，语句中，如果查询需要有序，则在大多数时候，查询key是否有序也是需要考虑的维度之一
https://www.bookstack.cn/read/aliyun-rds-core/4db84d3c10fdb1b8.md



https://www.bookstack.cn/read/aliyun-rds-core/c3e73d0a666188d4.md
无锁算法是利用CPU的原子操作实现的数据结构和算法来解决原来只能用锁才能解决的并发控制问题
* CAS
* Fetch-and-add
* Test-and-set

内存屏障

内存屏障相关函数，包括 compiler barrier 和 read/write barrier
语义上的布尔值（PG代码里叫flag，具体实现上可能映射到一个字节，或一个整数）的原子操作，包括：
      pg_atomic_init_flag，初始化一个flag
      pg_atomic_test_set_flag, Test-And-Set，这也是flag的唯一支持的原子 操作函数
      pg_atomic_unlocked_test_flag，检查flag是否没有被设置
      pg_atomic_clear_flag，清除已设置的flag
32位无符号整数的原子操作，包括：
      pg_atomic_init_u32, pg_atomic_read_u32, pg_atomic_write_u32，初始化、读、写操作
      pg_atomic_exchange_u32，给原子变量赋值并返回原值
      pg_atomic_compare_exchange_u32, 32位无符号整数的CAS操作，比较原子变量和另一个变量的值， 如果相等就赋一个新值到原子变量里，返回一个布尔值标识是否进行了赋值操作
      pg_atomic_fetch_add_u32, pg_atomic_fetch_sub_u32, pg_atomic_fetch_and_u32, pg_atomic_fetch_or_u32 对某个原子变量进行加、减、与、或操作，并返回变量改变之前的值
      pg_atomic_add_fetch_u32, pg_atomic_sub_fetch_u32 对某个原子变量进行加、减操作，并返回变量改变之后的值
64位无符号整数的原子操作，与32位的实现的操作函数相似，只是实现的是64位版本，这里需要注意的是， 64位版本并不保证所有平台的都支持，目前在PostgreSQL的源代码中还没有被使用。

实际案例：
      pg中事务在结束之后，需要设置 PGPROC 中的事务id，此时会使用 ProcArrayLock 尝试对 ProcArray 加排他锁，此时锁竞争严重，后来对此进行优化，使用无锁编程技术，批量进行xid的重置，具体函数为  ProcArrayEndTransaction  ProcArrayGroupClearXid
      大意为:
            如果竞争锁失败，则把 xid 加入一个数组中，有 leader 进行此数组的 xid  的重置工作，此过程没有加锁

[PGPROC数据结构](https://blog.csdn.net/jackgo73/article/details/121628739)

PGPROC 在共享内存中以 数组的形式组织，ProcArrayStruct 中 pgprocnos 字段记录映射关系，对应 PGPROC 中的 pgprocno 字段

```
(gdb) p * arrayP
$35 = {
  numProcs = 3,
  maxProcs = 122,
  maxKnownAssignedXids = 7930,
  numKnownAssignedXids = 0,
  tailKnownAssignedXids = 0,
  headKnownAssignedXids = 0,
  known_assigned_xids_lck = 0 '\000',
  lastOverflowedXid = 0,
  replication_slot_xmin = 0,
  replication_slot_catalog_xmin = 0,
  pgprocnos = 0x7fe4b541c928
}
(gdb) p  arrayP->pgprocnos[0]
$36 = 99
(gdb) p  arrayP->pgprocnos[1]
$37 = 103
(gdb) p  arrayP->pgprocnos[2]
$38 = 111
(gdb) p allProcs[99]
$40 = {
  links = {
    prev = 0x0,
    next = 0x0
  },
  procgloballist = 0x7fe4b5400fa8,
  sem = 0x7fe4ac86d1b8,
  waitStatus = PROC_WAIT_STATUS_OK,
  procLatch = {
    is_set = 0,
    maybe_sleeping = 0,
    is_shared = true,
    owner_pid = 6629
  },
  xid = 0,
  xmin = 0,
  lxid = 92,
  pid = 6629,
  pgxactoff = 0,
  pgprocno = 99,
  backendId = 3,
  databaseId = 16384,
  roleId = 10,
  tempNamespaceId = 0,
  isBackgroundWorker = false,
  recoveryConflictPending = false,
  lwWaiting = false,
  lwWaitMode = 0 '\000',
```



https://github.com/xitu/gold-miner/blob/master/TODO/postgres-atomicity.md

