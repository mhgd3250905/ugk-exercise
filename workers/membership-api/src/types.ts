export interface Env {
  DB: D1Database;
  GOOGLE_CLIENT_ID: string;
  SESSION_SECRET: string;
  REVENUECAT_WEBHOOK_AUTH: string;
}

export interface GoogleUser {
  sub: string;
  email: string;
  emailVerified: boolean;
  name: string;
  picture?: string;
}
