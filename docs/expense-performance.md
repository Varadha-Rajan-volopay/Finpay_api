# Expense Filtering and Pagination Performance

## Composite Index

The expense listing query filters by user, status, and incurred date, and sorts by created_at and id.

The composite index is:

    CREATE INDEX index_expenses_on_user_status_incurred_on
    ON expenses (user_id, status, incurred_on);

This index supports filtering by user, status, and incurred date.

## Benchmark

A synthetic benchmark was performed using a temporary table containing 100,000 generated rows.

The benchmark used EXPLAIN (ANALYZE, BUFFERS).

| Measurement | Before index | After index |
|---|---:|---:|
| Execution time | 6.971 ms | 0.101 ms |
| Scan strategy | Sequential scan | Bitmap index scan and bitmap heap scan |
| Composite index used | No | Yes |
| Sort required | Yes | Yes |

The measured execution time decreased by approximately 98.6% in this synthetic test.

The query returned no matching rows for the selected filter values. These results demonstrate index selection and filtering behavior, not production performance or performance for a result set containing 50 matching records.

The benchmark is environment-specific and is not a production performance guarantee.

## Sorting

The composite index filters using user_id, status, and incurred_on.

The query sorts using created_at DESC and id DESC.

The composite index does not fully satisfy this ordering, so PostgreSQL still performs a sort.

## Pagination

Offset pagination is straightforward for the first pages. However, deep offsets can become inefficient because PostgreSQL may need to scan and skip many earlier rows.

Keyset pagination uses the (created_at, id) ordering and a cursor to continue from the last returned record. This avoids an increasingly large offset.

The pagination implementation also limits page size to a maximum of 100 records.
