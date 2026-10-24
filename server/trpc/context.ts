import { SELFHOST_SESSION, SELFHOST_USER } from '@/lib/get-server-session';

export const createContext = async () => {
  return {
    session: SELFHOST_SESSION,
    user: SELFHOST_USER,
  };
};

export type Context = Awaited<ReturnType<typeof createContext>>;
