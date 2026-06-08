# Teradata to Snowflake Migration - BTEQ to Stored Procedures

A practical guide to migrating Teradata BTEQ scripts to Snowflake Stored Procedures, documenting common patterns, challenges, and the improvements gained through modernization.

---

## Background

BTEQ (Basic Teradata Query) is Teradata's proprietary scripting tool used to execute SQL workloads against a Teradata database. Unlike pure SQL, BTEQ runs on the client machine and acts as both a SQL executor and a workflow controller - managing execution flow, error handling, and session state through its own command set.

This dual nature is what makes BTEQ migration non-trivial. Moving to Snowflake isn't just a SQL dialect translation - it requires decomposing BTEQ into its constituent parts: SQL logic, flow control, and orchestration, and mapping each to the appropriate modern equivalent.

---

## What This Repo Covers

This repository demonstrates common BTEQ patterns and their equivalent implementation in Snowflake Stored Procedures. Starting from a basic single-step load with error handling, the constructs progressively cover conditional execution, dynamic SQL with loops, multi-step transactions, and audit logging. Each construct highlights not just the syntax translation, but the underlying challenges of the BTEQ pattern and how Snowflake's execution model addresses them.

---

## Migration Patterns

### Construct 1 - Basic Load with Error Handling
The simplest BTEQ pattern: insert from a staging table and exit with a success or failure code. In BTEQ, error handling is linear - after every critical statement, the script manually checks `ERRORCODE` and jumps to an exit label via `.GOTO`. The Snowflake equivalent is a Stored Procedure with structured exception handling - `EXCEPTION WHEN OTHER THEN RAISE` replaces the entire `.IF ERRORCODE / .GOTO / .QUIT` pattern, resulting in cleaner, more maintainable code.

| BTEQ | Snowflake SP |
|---|---|
| `.LOGON` | Managed by Airflow connection |
| `BT / ET` | Implicit transaction in `BEGIN / END` |
| `.IF ERRORCODE <> 0 THEN .GOTO` | `EXCEPTION WHEN OTHER THEN` |
| `.QUIT 12` | `RAISE` - surfaces failure to Airflow |
| `.QUIT 0` | `RETURN 'Loaded x rows'` |

---

### Construct 2 - Conditional Execution Flow
In BTEQ, conditional logic is implemented through error code checks and `.GOTO` branching - execution jumps to different labels based on the outcome of each statement. This non-linear flow becomes difficult to trace as scripts grow. In Snowflake Stored Procedures, the same logic is expressed through structured `IF / ELSEIF / ELSE` blocks, making execution flow explicit, readable, and easier to maintain.

---

### Construct 3 - Loops and Dynamic SQL
In telecom environments, backfill processes often need to run the same logic linearly for each date in a range - particularly when SCD or history handling is involved. BTEQ has no native loop construct, so this was typically handled by external shell scripts calling BTEQ repeatedly for each date, opening a new session each time. Snowflake Stored Procedures solve this natively with `WHILE` loops and `EXECUTE IMMEDIATE` for dynamic SQL - the entire backfill runs in a single SP call with one session, accumulating row counts across all iterations.

---

### Construct 4 - Multi-Step Transactions
Multi-step BTEQ scripts use separate `BT / ET` blocks per step, committing each independently. While this avoids full rollback on failure, it leaves data in an inconsistent state when a later step fails - earlier steps are already committed with no automatic cleanup. In Snowflake, each step is wrapped in its own transaction block with structured exception handling, and failed steps roll back cleanly while preserving the execution context for debugging.

---

### Construct 5 - Audit Logging
BTEQ execution details are written to flat log files - useful for manual inspection but not queryable or aggregatable. In operational environments this adds overhead, as diagnosing failures requires opening and reading log files manually. This construct introduces a structured `procedure_audit_log` table that captures procedure name, run ID, step ID, status, rows processed, and error messages per run. This transforms execution history into a queryable dataset - enabling trend analysis, faster debugging, and integration with monitoring tools.

---

## Key Takeaways

Migrating from BTEQ to Snowflake Stored Procedures is not a line-by-line translation. It is a decomposition of three concerns that BTEQ conflates into a single file:

- **SQL execution** → Snowflake SQL dialect
- **Flow control** → Snowflake Scripting exception handling
- **Orchestration** → Apache Airflow

The migration also presents an opportunity to improve what existed before - structured exception handling replaces brittle `.GOTO` chains, native loops eliminate external shell dependencies, and audit tables replace unqueryable flat log files.

---

## How to Use This Repo

Each construct is numbered and paired - a BTEQ or shell script in the `bteq/` folder and its Snowflake equivalent in the `snowflake/` folder. Start with `00_setup.sql` in the `snowflake/` folder to create the required audit table before running any procedures. Constructs are independent and can be read in any order, though sequential reading is recommended to follow the migration complexity arc.

```
bteq/
├── 01_basic_load.bteq
├── 02_conditional_logic.bteq
├── 03_loop_dynamic_sql.sh
├── 04_multi_step_transaction.bteq
└── 05_audit_logging.bteq

snowflake/
├── 00_setup.sql
├── 01_basic_load.sql
├── 02_conditional_logic.sql
├── 03_loop_dynamic_sql.sql
├── 04_multi_step_transaction.sql
└── 05_audit_logging.sql
```

---

## Author

Built by a Data Engineer with 7+ years of experience in Teradata-based data warehousing, documenting real-world migration patterns from legacy on-premise Teradata environments to modern cloud-based Snowflake architecture.