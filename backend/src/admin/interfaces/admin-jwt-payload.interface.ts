export interface AdminJwtPayload {
  sub: string;        // Admin user ID
  email: string;
  role: string;
  iat: number;
  exp: number;
}

export interface AdminAuthContext {
  sub: string;
  email: string;
  role: string;
}
