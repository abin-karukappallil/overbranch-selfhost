import { drizzle } from 'drizzle-orm/libsql';
import { createClient } from '@libsql/client';
import * as schema from './schema';
import path from 'path';

function createDbClient() {
  const absPath = path.resolve(process.cwd(), 'overbranch.db');
  // Normalize Windows backslashes to forward slashes for the file: URL
  const normalizedPath = absPath.replace(/\\/g, '/');
  const client = createClient({
    url: `file:${normalizedPath}`,
  });

  return drizzle(client, { schema });
}

let _dbClient: ReturnType<typeof createDbClient> | null = null;

export const getDb = () => {
  if (!_dbClient) {
    _dbClient = createDbClient();
  }
  return _dbClient;
};

export const db = new Proxy({} as ReturnType<typeof createDbClient>, {
  get(_target, prop) {
    const d = getDb();
    const val = (d as any)[prop];
    return typeof val === 'function' ? val.bind(d) : val;
  },
  has(_target, prop) {
    const d = getDb();
    return prop in d;
  },
});