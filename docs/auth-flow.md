# SnapVerify Authentication Flow

## Step-by-Step OTP Authentication Flow

1. **User Enters Phone Number**
   - User provides their phone number on the login screen
   - Flutter app sends `POST /auth/send-otp` with phone number
   - Rate limiting applied (3 requests per minute)

2. **System Sends OTP**
   - Backend generates 6-digit random OTP
   - OTP is stored in `Otp` table with 5-minute expiration
   - OTP is sent to user's phone (via Twilio or mock service)
   - For development, OTP is logged to console

3. **User Enters OTP**
   - User enters the received OTP in the app
   - App sends `POST /auth/verify-otp` with phone and OTP
   - Optionally includes `organizationId` if joining existing business

4. **Verify OTP and Authenticate**
   - Backend verifies OTP (expiry, usage, attempts)
   - If valid, marks OTP as used
   - Checks if user exists
   - If user doesn't exist and orgId provided, creates new user
   - Issues JWT tokens (access token: 15 mins, refresh token: 7 days)
   - Tokens stored in `RefreshToken` table and returned to app

5. **Token Refresh**
   - When access token expires, app sends `POST /auth/refresh-token` with refresh token
   - Backend validates refresh token
   - Issues new pair of tokens
   - Invalidates old refresh token

6. **Logout**
   - User taps logout button
   - App sends `POST /auth/logout` with refresh token
   - Backend deletes refresh token from database
   - App clears local storage
