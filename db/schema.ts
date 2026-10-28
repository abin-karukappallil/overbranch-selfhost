import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const user = sqliteTable("user", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  emailVerified: integer("email_verified", { mode: "boolean" }).notNull().default(true),
  image: text("image"),
  role: text("role").default("admin"),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const session = sqliteTable("session", {
  id: text("id").primaryKey(),
  expiresAt: integer("expires_at", { mode: "timestamp" }).notNull(),
  token: text("token").notNull().unique(),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  ipAddress: text("ip_address"),
  userAgent: text("user_agent"),
  userId: text("user_id").notNull().references(() => user.id, { onDelete: "cascade" })
});

export const account = sqliteTable("account", {
  id: text("id").primaryKey(),
  accountId: text("account_id").notNull(),
  providerId: text("provider_id").notNull(),
  userId: text("user_id").notNull().references(() => user.id, { onDelete: "cascade" }),
  accessToken: text("access_token"),
  refreshToken: text("refresh_token"),
  idToken: text("id_token"),
  accessTokenExpiresAt: integer("access_token_expires_at", { mode: "timestamp" }),
  refreshTokenExpiresAt: integer("refresh_token_expires_at", { mode: "timestamp" }),
  scope: text("scope"),
  password: text("password"),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const verification = sqliteTable("verification", {
  id: text("id").primaryKey(),
  identifier: text("identifier").notNull(),
  value: text("value").notNull(),
  expiresAt: integer("expires_at", { mode: "timestamp" }).notNull(),
  createdAt: integer("created_at", { mode: "timestamp" }).$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).$defaultFn(() => new Date())
});

export const projects = sqliteTable("projects", {
  id: text("id").primaryKey(),
  ownerId: text("owner_id").notNull().default("selfhost-user"),
  name: text("name").notNull(),
  description: text("description"),
  repository: text("repository"),
  defaultBranch: text("default_branch").notNull().default("main.tex"),
  language: text("language").notNull().default("latex"),
  status: text("status").notNull().default("active"),
  isPublic: integer("is_public", { mode: "boolean" }).notNull().default(false),
  isFavorite: integer("is_favorite", { mode: "boolean" }).notNull().default(false),
  template: text("template").notNull().default("IEEEtran"),
  starsCount: integer("stars_count").notNull().default(0),
  lastActiveAt: integer("last_active_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const projectMembers = sqliteTable("project_members", {
  id: text("id").primaryKey(),
  projectId: text("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
  userId: text("user_id").notNull(),
  role: text("role").notNull().default("Owner"),
  joinedAt: integer("joined_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const projectInvitations = sqliteTable("project_invitations", {
  id: text("id").primaryKey(),
  projectId: text("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
  senderId: text("sender_id").notNull(),
  receiverId: text("receiver_id").notNull(),
  email: text("email").notNull(),
  role: text("role").notNull().default("Editor"),
  status: text("status").notNull().default("Accepted"),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const notifications = sqliteTable("notifications", {
  id: text("id").primaryKey(),
  receiverId: text("receiver_id").notNull(),
  senderId: text("sender_id"),
  projectId: text("project_id").references(() => projects.id, { onDelete: "cascade" }),
  type: text("type").notNull().default("System"),
  title: text("title").notNull(),
  message: text("message").notNull(),
  isRead: integer("is_read", { mode: "boolean" }).notNull().default(false),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const comments = sqliteTable("comments", {
  id: text("id").primaryKey(),
  projectId: text("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
  authorId: text("author_id").notNull(),
  content: text("content").notNull(),
  resolved: integer("resolved", { mode: "boolean" }).notNull().default(false),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const templates = sqliteTable("templates", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  category: text("category").notNull(),
  description: text("description").notNull(),
  fileExtension: text("file_extension").notNull().default("cls"),
  isFeatured: integer("is_featured", { mode: "boolean" }).notNull().default(false),
  usageCount: integer("usage_count").notNull().default(0),
  content: text("content")
});

export const userPreferences = sqliteTable("user_preferences", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().unique(),
  theme: text("theme").notNull().default("dark"),
  emailNotifications: integer("email_notifications", { mode: "boolean" }).notNull().default(false),
  securityAlerts: integer("security_alerts", { mode: "boolean" }).notNull().default(false),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const editorPreferences = sqliteTable("editor_preferences", {
  id: text("id").primaryKey(),
  userId: text("user_id").notNull().unique(),
  fontSize: integer("font_size").notNull().default(14),
  tabSize: integer("tab_size").notNull().default(2),
  wordWrap: integer("word_wrap", { mode: "boolean" }).notNull().default(true),
  autoCompile: integer("auto_compile", { mode: "boolean" }).notNull().default(true),
  engine: text("engine").notNull().default("pdfLaTeX"),
  lineNumbers: integer("line_numbers", { mode: "boolean" }).notNull().default(true)
});

export const latexDocuments = sqliteTable("latex_documents", {
  id: text("id").primaryKey(),
  projectId: text("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
  filePath: text("file_path").notNull(),
  rawCode: text("raw_code").notNull(),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const documentVectors = sqliteTable("document_vectors", {
  id: text("id").primaryKey(),
  projectId: text("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
  filePath: text("file_path").notNull(),
  chunkId: text("chunk_id").notNull(),
  title: text("title"),
  content: text("content").notNull(),
  embedding: text("embedding"), // JSON array of float embeddings
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export const guestSessions = sqliteTable("guest_sessions", {
  id: text("id").primaryKey(),
  fingerprintHash: text("fingerprint_hash"),
  tokenHash: text("token_hash"),
  conversionsUsed: integer("conversions_used").default(0),
  lastConversionAt: integer("last_conversion_at", { mode: "timestamp" }),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date()),
  expiresAt: integer("expires_at", { mode: "timestamp" })
});

export const guestProjects = sqliteTable("guest_projects", {
  id: text("id").primaryKey(),
  guestSessionId: text("guest_session_id"),
  projectId: text("project_id"),
  migratedToUserId: text("migrated_to_user_id"),
  migratedAt: integer("migrated_at", { mode: "timestamp" }),
  expiresAt: integer("expires_at", { mode: "timestamp" }),
  createdAt: integer("created_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export type User = typeof user.$inferSelect;
export type Project = typeof projects.$inferSelect;
export type ProjectMember = typeof projectMembers.$inferSelect;
export type ProjectInvitation = typeof projectInvitations.$inferSelect;
export type Notification = typeof notifications.$inferSelect;
export type Comment = typeof comments.$inferSelect;
export type Template = typeof templates.$inferSelect;
export type LatexDocument = typeof latexDocuments.$inferSelect;
export type DocumentVector = typeof documentVectors.$inferSelect;

export const collabDocState = sqliteTable("collab_doc_state", {
  projectId: text("project_id").primaryKey().references(() => projects.id, { onDelete: "cascade" }),
  stateB64: text("state_b64").notNull(),
  updatedAt: integer("updated_at", { mode: "timestamp" }).notNull().$defaultFn(() => new Date())
});

export type CollabDocState = typeof collabDocState.$inferSelect;
export type GuestSession = typeof guestSessions.$inferSelect;
export type GuestProject = typeof guestProjects.$inferSelect;
