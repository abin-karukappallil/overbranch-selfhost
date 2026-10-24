import { SELFHOST_SESSION } from "./get-server-session";

export const auth = {
  api: {
    getSession: async (_opts?: any) => SELFHOST_SESSION,
  },
  handler: async (_req: any) => new Response(JSON.stringify(SELFHOST_SESSION)),
};