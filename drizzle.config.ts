import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './db/schema.ts',
  out: './drizzle',
  dialect: 'sqlite',
  dbCredentials: {
    url: `file:${process.env.OVERBRANCH_DATA_DIR || '.'}/overbranch.db`,
  },
});