import { router, protectedProcedure } from '../init';
import { z } from 'zod';
import { db } from '@/db';
import { latexDocuments } from '@/db/schema';
import { eq, and } from 'drizzle-orm';

export const projectRouter = router({
  getProjectCode: protectedProcedure
    .input(z.object({
      projectId: z.string(),
      filePath: z.string().default('main.tex'),
    }))
    .query(async ({ input }) => {
      const [doc] = await db
        .select()
        .from(latexDocuments)
        .where(
          and(
            eq(latexDocuments.projectId, input.projectId),
            eq(latexDocuments.filePath, input.filePath)
          )
        )
        .limit(1);

      if (!doc) {
        return {
          projectId: input.projectId,
          filePath: input.filePath,
          rawCode: null,
          updatedAt: null,
        };
      }

      return {
        projectId: doc.projectId,
        filePath: doc.filePath,
        rawCode: doc.rawCode,
        updatedAt: doc.updatedAt ? new Date(doc.updatedAt).toISOString() : null,
      };
    }),

  saveProjectCode: protectedProcedure
    .input(z.object({
      projectId: z.string(),
      filePath: z.string().default('main.tex'),
      rawCode: z.string(),
    }))
    .mutation(async ({ input }) => {
      const [existing] = await db
        .select({ id: latexDocuments.id })
        .from(latexDocuments)
        .where(
          and(
            eq(latexDocuments.projectId, input.projectId),
            eq(latexDocuments.filePath, input.filePath)
          )
        )
        .limit(1);

      if (existing) {
        await db
          .update(latexDocuments)
          .set({ rawCode: input.rawCode, updatedAt: new Date() })
          .where(eq(latexDocuments.id, existing.id));
      } else {
        await db.insert(latexDocuments).values({
          id: `${input.projectId}_${input.filePath}`,
          projectId: input.projectId,
          filePath: input.filePath,
          rawCode: input.rawCode,
          updatedAt: new Date(),
        });
      }

      try {
        const backendUrl = 'http://localhost:8000';
        await fetch(`${backendUrl}/api/compile`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            latex_code: input.rawCode,
            project_id: input.projectId,
          }),
        });
      } catch (compileErr) {
        console.warn('Background auto-compile trigger note:', compileErr);
      }

      return {
        success: true,
        projectId: input.projectId,
        filePath: input.filePath,
      };
    }),
});
