import { initTRPC, TRPCError } from '@trpc/server';
import superjson from 'superjson';
import { db } from '@/db';
import { projects } from '@/db/schema';
import { eq } from 'drizzle-orm';
import { z } from 'zod';
import { SELFHOST_SESSION, SELFHOST_USER } from '@/lib/get-server-session';

export const createContext = async () => {
  return {
    session: SELFHOST_SESSION,
    user: SELFHOST_USER,
    rawCookieHeader: '',
    sessionToken: 'selfhost-token',
    guestToken: null,
    guestSessionId: null,
  };
};

const t = initTRPC.context<typeof createContext>().create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;

export const protectedProcedure = t.procedure.use(({ ctx, next }) => {
  return next({
    ctx: {
      ...ctx,
      session: SELFHOST_SESSION,
      user: SELFHOST_USER,
    },
  });
});

export const projectProcedure = protectedProcedure
  .input(z.object({ projectId: z.string().min(1) }).passthrough())
  .use(async ({ ctx, input, next }) => {
    const projectId = input.projectId;
    const [project] = await db.select().from(projects).where(eq(projects.id, projectId));
    if (!project) {
      throw new TRPCError({ code: 'NOT_FOUND', message: 'Project not found' });
    }

    return next({
      ctx: {
        ...ctx,
        project,
        memberRole: 'Owner' as 'Owner' | 'Editor' | 'Viewer',
      },
    });
  });

export const ownerProcedure = protectedProcedure
  .input(z.object({ projectId: z.string().min(1) }).passthrough())
  .use(async ({ ctx, input, next }) => {
    const projectId = input.projectId;
    const [project] = await db.select().from(projects).where(eq(projects.id, projectId));
    if (!project) {
      throw new TRPCError({ code: 'NOT_FOUND', message: 'Project not found' });
    }

    return next({
      ctx: {
        ...ctx,
        project,
        memberRole: 'Owner' as const,
      },
    });
  });