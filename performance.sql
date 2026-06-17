Dear AWS Customer,

Thank you for your response.

- Please find the below queries.

Performance Tuning and Monitoring Scripts
=========================================
Below are PostgreSQL scripts organized by monitoring category to assist with performance tuning and operational management:

1. Connection and Session Monitoring
-- Active connections by state
SELECT state, count(*) 
FROM pg_stat_activity 
GROUP BY state 
ORDER BY count DESC;

-- Long-running queries (> 5 minutes)
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes'
AND state != 'idle'
ORDER BY duration DESC;

-- Blocked queries
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement,
       blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;


2. Table and Index Health

-- Tables needing vacuum (bloat detection)
SELECT schemaname, relname, n_live_tup, n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_pct,
       last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;

-- Unused indexes
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_relation_size(indexrelid) DESC;

-- Index hit rate (should be > 99%)
SELECT relname,
       CASE WHEN idx_scan + seq_scan = 0 THEN 0
            ELSE ROUND(100.0 * idx_scan / (idx_scan + seq_scan), 2) END AS idx_hit_pct,
       seq_scan, idx_scan, n_live_tup
FROM pg_stat_user_tables
WHERE n_live_tup > 10000
ORDER BY idx_hit_pct ASC
LIMIT 20;

3. Transaction ID Wraparound Monitoring

-- Monitor transaction ID age 
SELECT datname, age(datfrozenxid),
       ROUND(100.0 * age(datfrozenxid) / 2147483647, 2) AS pct_towards_wraparound
FROM pg_database
ORDER BY age(datfrozenxid) DESC;

-- Tables closest to wraparound
SELECT schemaname, relname, age(relfrozenxid),
       ROUND(100.0 * age(relfrozenxid) / 2147483647, 2) AS pct_towards_wraparound
FROM pg_stat_user_tables
ORDER BY age(relfrozenxid) DESC
LIMIT 20;


4. Replication Slot Monitoring 

-- Check replication slots
SELECT slot_name, slot_type, database, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS slot_lag
FROM pg_replication_slots
ORDER BY pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) DESC;

-- Drop inactive/stale replication slots if no longer needed
-- SELECT pg_drop_replication_slot('slot_name');
```

5. pg_stat_statements Analysis (Top Queries)

-- Top queries by total time
SELECT queryid, calls, total_exec_time/1000 AS total_sec,
       mean_exec_time AS avg_ms, rows,
       ROUND(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 2) AS hit_pct,
       LEFT(query, 100) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Top queries by calls (most frequent)
SELECT queryid, calls, total_exec_time/1000 AS total_sec,
       mean_exec_time AS avg_ms,
       LEFT(query, 100) AS query_preview
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 20;

-- Queries with poor cache hit ratio
SELECT queryid, calls, shared_blks_hit, shared_blks_read,
       ROUND(100.0 * shared_blks_hit / NULLIF(shared_blks_hit + shared_blks_read, 0), 2) AS hit_pct,
       LEFT(query, 100) AS query_preview
FROM pg_stat_statements
WHERE shared_blks_hit + shared_blks_read > 1000
ORDER BY hit_pct ASC
LIMIT 20;


6. Cache and Buffer Performance
-- Buffer cache hit ratio by table
SELECT schemaname, relname,
       heap_blks_read, heap_blks_hit,
       ROUND(100.0 * heap_blks_hit / NULLIF(heap_blks_hit + heap_blks_read, 0), 2) AS cache_hit_pct
FROM pg_statio_user_tables
WHERE heap_blks_hit + heap_blks_read > 100
ORDER BY cache_hit_pct ASC
LIMIT 20;

7. Database Size and Growth

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database 
ORDER BY pg_database_size(datname) DESC;

-- Largest tables
SELECT schemaname, tablename,
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
       pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
       pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename::regclass)) AS index_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

Out Of Scope
============
Please allow me to set the correct expectations here. Workload optimisation or Query tuning is outside the scope of support. 

AWS Premium Support works on the shared responsibility model, where workload optimization comes under customer responsibility.

- https://aws.amazon.com/compliance/shared-responsibility-model/  
- https://aws.amazon.com/blogs/database/part-1-role-of-the-dba-when-moving-to-amazon-rds-responsibilities/  


**************************************
REFERENCES
**************************************
[1] Essential concepts for RDS for PostgreSQL tuning
https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/PostgreSQL.Tuning.concepts.html  

[2] Optimizing and tuning queries in Amazon RDS PostgreSQL based on native and external tools
https://aws.amazon.com/blogs/database/optimizing-and-tuning-queries-in-amazon-rds-postgresql-based-on-native-and-external-tools/ 

I hope that the information shared above is of assistance. Should you have any queries or concerns regarding the above, or should the above not resolve the issue, please do not hesitate to let me know and I will be glad to assist wherever possible.
Wishing you a great day ahead.
Soliciting your cooperation.

