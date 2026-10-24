export interface ServerUser {
  id: string;
  name: string;
  email: string;
  emailVerified: boolean;
  image?: string | null;
  role?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ServerSession {
  user: ServerUser;
  session: {
    id: string;
    token: string;
    userId: string;
    expiresAt: Date;
    createdAt: Date;
    updatedAt: Date;
    ipAddress?: string | null;
    userAgent?: string | null;
  };
}

export const SELFHOST_USER: ServerUser = {
  id: "selfhost-user",
  name: "Local Author",
  email: "author@local",
  emailVerified: true,
  image: null,
  role: "admin",
  createdAt: new Date(0),
  updatedAt: new Date(0),
};

export const SELFHOST_SESSION: ServerSession = {
  user: SELFHOST_USER,
  session: {
    id: "selfhost-session",
    token: "selfhost-token",
    userId: "selfhost-user",
    expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365),
    createdAt: new Date(0),
    updatedAt: new Date(0),
  },
};

export async function getServerSession(): Promise<ServerSession> {
  return SELFHOST_SESSION;
}
