# SnapVerify Database Schema

## ER Diagram Explanation

The database follows a **multi-tenant SaaS architecture** where each organization (business) is isolated. Below are all the tables:

### 1. `organizations`
- Represents a business/organization
- Fields:
  - `id` (UUID, PK)
  - `name`
  - `type`
  - `phone`
  - `email` (nullable)
  - `address` (nullable)
  - `city` (nullable)
  - `country` (nullable)
  - `logoUrl` (nullable)
  - `subscriptionPlan` (nullable)
  - `status`
  - `createdAt`
  - `updatedAt`
- Relations:
  - 1-to-many with `users`
  - 1-to-many with `branches`
  - 1-to-many with `payments`
  - 1-to-many with `verification_logs`
  - 1-to-many with `subscriptions`
  - 1-to-many with `activity_logs`
  - 1-to-many with `devices`

### 2. `users`
- Represents a user (owner, staff, etc.) within an organization
- Fields:
  - `id` (UUID, PK)
  - `organizationId` (FK)
  - `fullName` (nullable)
  - `phone`
  - `email` (nullable)
  - `passwordHash` (nullable)
  - `role` (enum: OWNER, MANAGER, CASHIER, WAITER)
  - `status`
  - `createdAt`
  - `updatedAt`
- Relations:
  - Many-to-1 with `organizations`
  - 1-to-many with `devices`
  - 1-to-many with `refresh_tokens`
  - 1-to-many with `payments`
  - 1-to-many with `verification_logs`
  - 1-to-many with `activity_logs`
- Unique constraint: `(organizationId, phone)`

### 3. `otp_codes`
- Stores OTPs for authentication
- Fields:
  - `id` (UUID, PK)
  - `phone`
  - `code`
  - `expiresAt`
  - `isUsed` (default: false)
  - `createdAt`

### 4. `refresh_tokens`
- Stores refresh tokens for long-lived sessions
- Fields:
  - `id` (UUID, PK)
  - `userId` (FK)
  - `token` (unique)
  - `expiresAt`
  - `deviceInfo` (nullable)
  - `ipAddress` (nullable)
  - `createdAt`
- Relations: Many-to-1 with `users`

### 5. `devices`
- Represents a device a user has logged in from
- Fields:
  - `id` (UUID, PK)
  - `userId` (FK)
  - `organizationId` (FK)
  - `deviceFingerprint`
  - `deviceName` (nullable)
  - `isActive` (default: true)
  - `lastLoginAt`
  - `createdAt`
- Relations:
  - Many-to-1 with `users`
  - Many-to-1 with `organizations`
- Unique constraint: `(userId, deviceFingerprint)`

### 6. `branches`
- Represents a branch/location of an organization
- Fields:
  - `id` (UUID, PK)
  - `organizationId` (FK)
  - `name`
  - `address` (nullable)
  - `latitude` (nullable, Decimal)
  - `longitude` (nullable, Decimal)
  - `phone` (nullable)
  - `createdAt`
  - `updatedAt`
- Relations: Many-to-1 with `organizations`

### 7. `payments`
- Represents a payment transaction
- Fields:
  - `id` (UUID, PK)
  - `organizationId` (FK)
  - `userId` (FK, nullable)
  - `amount` (Decimal)
  - `currency` (default: "ETB")
  - `paymentMethod`
  - `transactionId`
  - `senderName` (nullable)
  - `receiverName` (nullable)
  - `status` (enum: PENDING, VERIFIED, REJECTED, FAILED)
  - `riskScore` (nullable)
  - `rawData` (nullable, JSON)
  - `createdAt`
  - `updatedAt`
- Relations:
  - Many-to-1 with `organizations`
  - Many-to-1 with `users`
  - 1-to-many with `verification_logs`

### 8. `verification_logs`
- Represents a log of payment verification attempts
- Fields:
  - `id` (UUID, PK)
  - `organizationId` (FK, nullable)
  - `paymentId` (FK, nullable)
  - `userId` (FK, nullable)
  - `action`
  - `reason` (nullable)
  - `riskScore` (nullable)
  - `createdAt`
- Relations:
  - Many-to-1 with `organizations`
  - Many-to-1 with `payments`
  - Many-to-1 with `users`

### 9. `subscriptions`
- Represents a subscription for an organization
- Fields:
  - `id` (UUID, PK)
  - `organizationId` (FK)
  - `planName`
  - `status` (enum: ACTIVE, INACTIVE, CANCELLED, EXPIRED)
  - `startDate`
  - `endDate` (nullable)
  - `maxUsers` (nullable)
  - `maxDevices` (nullable)
  - `createdAt`
  - `updatedAt`
- Relations: Many-to-1 with `organizations`

### 10. `activity_logs`
- Represents an activity log entry
- Fields:
  - `id` (UUID, PK)
  - `organizationId` (FK)
  - `userId` (FK, nullable)
  - `action`
  - `metadata` (nullable, JSON)
  - `ipAddress` (nullable)
  - `createdAt`
- Relations:
  - Many-to-1 with `organizations`
  - Many-to-1 with `users`
