import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

import {
  isoNow,
  sanitizeText,
  stableId
} from '../../Domain/Models/sceneContracts.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DEFAULT_MIGRATIONS_DIR = resolve(__dirname, '../Migrations');

function listMigrationFiles(migrationsDir) {
  return readdirSync(migrationsDir)
    .filter((name) => /^\d+_.+\.sql$/.test(name))
    .sort((left, right) => left.localeCompare(right, 'en'));
}

export class LocalBackendDatabase {
  constructor({ dbPath, migrationsDir = DEFAULT_MIGRATIONS_DIR }) {
    this.dbPath = dbPath;
    this.migrationsDir = migrationsDir;
    mkdirSync(dirname(dbPath), { recursive: true });
    this.db = new DatabaseSync(dbPath);
    this.schemaReady = false;
    this.ensureSchema();
  }

  ensureSchema() {
    if (this.schemaReady) {
      return;
    }

    this.db.exec(
      `CREATE TABLE IF NOT EXISTS local_backend_migrations (
        id TEXT PRIMARY KEY,
        migration_name TEXT NOT NULL UNIQUE,
        applied_at TEXT NOT NULL
      )`
    );

    const applied = new Set(
      this.db
        .prepare('SELECT migration_name FROM local_backend_migrations ORDER BY migration_name ASC')
        .all()
        .map((row) => row.migration_name)
    );

    for (const migrationName of listMigrationFiles(this.migrationsDir)) {
      if (applied.has(migrationName)) {
        continue;
      }

      const sql = readFileSync(resolve(this.migrationsDir, migrationName), 'utf8');
      const appliedAt = isoNow();
      const migrationId = stableId('local-backend-migration', migrationName, appliedAt);

      this.db.exec(sql);
      this.db
        .prepare(
          `INSERT INTO local_backend_migrations (id, migration_name, applied_at)
           VALUES (?, ?, ?)`
        )
        .run(migrationId, migrationName, appliedAt);
    }

    this.schemaReady = true;
  }

  withTransaction(work) {
    this.db.exec('BEGIN');
    try {
      const result = work();
      this.db.exec('COMMIT');
      return result;
    } catch (error) {
      this.db.exec('ROLLBACK');
      throw error;
    }
  }

  inspectDatabaseStatus() {
    const tableRows = this.db
      .prepare(
        `SELECT name
         FROM sqlite_master
         WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
         ORDER BY name ASC`
      )
      .all();
    const migrations = this.db
      .prepare(
        `SELECT migration_name, applied_at
         FROM local_backend_migrations
         ORDER BY migration_name ASC`
      )
      .all();

    return {
      dbPath: this.dbPath,
      tableCount: tableRows.length,
      tables: tableRows.map((row) => sanitizeText(row.name)),
      migrations
    };
  }

  close() {
    this.db.close();
  }
}
