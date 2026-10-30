import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  schema: './db/schema.ts',
  out: './drizzle',
  dialect: 'sqlite',
  dbCredentials: {
    url: `file:${process.env.OVERBRANCH_DATA_DIR || '.'}/overbranch.db`,
  },
});the TeX base image (first, and the slowest step)
- On GitHub, go to Actions → texlive-base → Run workflow. It also triggers on its own when you push to main.
- Expect roughly 1–3 hours. amd64 and arm64 build in parallel on separate runners.
- Likely first failures:
  - Disk: the arm64 runner's free disk is unknown. The log prints df -h before and after, so read it if the job fails.
  - Fonts: the strict font gate may reject a family that doesn't exist, in which case move that name to the INFO list in docker/check-fonts.sh.