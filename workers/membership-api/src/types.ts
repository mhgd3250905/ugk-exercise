export interface Env {
  DB: D1Database;
  AVATAR_BUCKET: R2Bucket;
  GOOGLE_CLIENT_ID: string;
  SESSION_SECRET: string;
  REVENUECAT_WEBHOOK_SECRET: string;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUD: string;
}

export interface GoogleUser {
  sub: string;
  email: string;
  emailVerified: boolean;
  name: string;
  picture?: string;
}
