# SnapVerify API Examples

## Base URL
`http://localhost:3000`

## Authentication Endpoints

### Send OTP
**POST** `/auth/send-otp`
```json
{
  "phone": "+251912345678"
}
```
**Response (200 OK)**
```json
{
  "message": "OTP sent successfully"
}
```

### Verify OTP
**POST** `/auth/verify-otp`
```json
{
  "phone": "+251912345678",
  "code": "123456",
  "organizationId": "550e8400-e29b-41d4-a716-446655440000"
}
```
**Response (200 OK)**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "a1b2c3d4e5f6g7h8i9j0..."
}
```

### Create Business
**POST** `/auth/create-business`
```json
{
  "name": "Awesome Restaurant",
  "phone": "+251912345678",
  "email": "info@awesomerestaurant.com",
  "address": "Bole Road, Addis Ababa"
}
```
**Response (201 Created)**
```json
{
  "organization": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Awesome Restaurant",
    "phone": "+251912345678",
    "email": "info@awesomerestaurant.com",
    "address": "Bole Road, Addis Ababa"
  },
  "user": {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "phone": "+251912345678",
    "role": "OWNER"
  },
  "tokens": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "a1b2c3d4e5f6g7h8i9j0..."
  }
}
```

### Refresh Token
**POST** `/auth/refresh-token`
```json
{
  "refreshToken": "a1b2c3d4e5f6g7h8i9j0..."
}
```
**Response (200 OK)**
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "new-refresh-token..."
}
```

### Logout
**POST** `/auth/logout`
```json
{
  "refreshToken": "a1b2c3d4e5f6g7h8i9j0..."
}
```
**Response (200 OK)**
```json
{
  "message": "Logged out successfully"
}
```
