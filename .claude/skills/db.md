# db

## Schema Design
- Primary key: `id` (uuid or auto-increment)
- Timestamps: `created_at`, `updated_at`
- Soft delete: `deleted_at` (if needed)
- Foreign keys: `{table}_id`
- Indexes on: FKs, frequently queried, unique constraints

## Naming
- Tables: plural, snake_case (`user_profiles`)
- Columns: singular, snake_case (`first_name`)
- Indexes: `idx_{table}_{columns}`
- Constraints: `{table}_{type}_{columns}`

## Migration Rules
- One concern per migration
- Always provide rollback (down)
- Never modify released migrations
- Test both up and down
- Data migrations separate from schema

## Migration Template
```sql
-- Up
ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active';
CREATE INDEX idx_users_status ON users(status);

-- Down
DROP INDEX idx_users_status;
ALTER TABLE users DROP COLUMN status;
```

## Query Optimization
- Select only needed columns
- Use LIMIT for unbounded queries
- Avoid SELECT *
- Use EXPLAIN to analyze
- Index columns in WHERE/JOIN/ORDER BY
- Avoid N+1: use JOIN or batch

## Anti-patterns
- ❌ Storing JSON for queryable data
- ❌ No indexes on foreign keys
- ❌ Unbounded queries
- ❌ Business logic in DB
- ❌ Circular foreign keys

## Commands
```bash
# Create migration
npm run migrate:create {name}

# Run migrations
npm run migrate:up

# Rollback
npm run migrate:down
```
