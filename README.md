# SnapVerify

A full-stack SaaS application for payment verification, built with:
- **Backend**: NestJS, TypeScript, Prisma ORM, PostgreSQL
- **Frontend**: Flutter (Android-first), Riverpod for state management

## Project Structure

```
SnapVerify/
├── backend/                # NestJS backend
│   ├── src/
│   │   ├── auth/          # Auth module
│   │   ├── otp/           # OTP module
│   │   ├── prisma/        # Prisma service and module
│   │   ├── app.module.ts
│   │   └── main.ts
│   ├── prisma/            # Prisma schema
│   └── package.json
├── frontend/              # Flutter frontend
│   └── lib/
│       ├── core/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── docs/                  # Documentation
    ├── api-examples.md
    ├── auth-flow.md
    └── database-schema.md
```

## Getting Started

### Backend Setup

1. Navigate to backend directory:
   ```bash
   cd backend
   ```

2. Copy environment variables:
   ```bash
   cp .env.example .env
   ```

3. Update `.env` with your PostgreSQL credentials:
   ```env
   DATABASE_URL="postgresql://user:password@localhost:5432/snapverify?schema=public"
   JWT_ACCESS_SECRET="your-super-secret-key"
   ```

4. Run Prisma migrations:
   ```bash
   npx prisma migrate dev
   ```

5. Start the server:
   ```bash
   npm run start:dev
   ```

### Frontend Setup

1. Navigate to frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Features

- Phone OTP authentication
- Multi-tenant SaaS architecture
- JWT-based authentication (access + refresh tokens)
- Role-based access control (Owner, Manager, Cashier, Waiter)
- Secure password hashing
- Rate limiting
