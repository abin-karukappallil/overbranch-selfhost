"use client";

export const SELFHOST_CLIENT_USER = {
  id: "selfhost-user",
  name: "Local Author",
  email: "author@local",
  image: null,
  role: "admin",
};

const mockOk = async (_opts?: any) => ({ error: null, data: { user: SELFHOST_CLIENT_USER } });

export const authClient: any = {
  useSession: () => ({
    data: {
      user: SELFHOST_CLIENT_USER,
      session: {
        id: "selfhost-session",
        token: "selfhost-token",
        userId: "selfhost-user",
        expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365),
      },
    },
    isPending: false,
    error: null,
  }),
  getSession: async () => ({
    data: {
      user: SELFHOST_CLIENT_USER,
      session: {
        id: "selfhost-session",
        token: "selfhost-token",
        userId: "selfhost-user",
        expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365),
      },
    },
    error: null,
  }),
  signOut: mockOk,
  signIn: Object.assign(mockOk, {
    email: mockOk,
    social: mockOk,
  }),
  signUp: Object.assign(mockOk, {
    email: mockOk,
    social: mockOk,
  }),
};