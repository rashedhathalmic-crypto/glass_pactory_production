# Glass CNC Tools — secure email OTP backend

This folder contains the Google Apps Script web-app backend used only for the generator login gate.

## Security model

1. The browser first signs in to Firebase with the existing password.
2. The Apps Script backend verifies the resulting Firebase ID token with Google Identity Toolkit.
3. Only the Firebase account `rashedhathalmic@gmail.com` is accepted.
4. The backend generates a fresh six-digit OTP and sends it only to `rashedhathalmic@gmail.com`.
5. OTP validity is 10 minutes, with a maximum of five attempts.
6. OTP requests are rate-limited.
7. OTP and poll tokens are stored only as SHA-256 hashes with a server-side pepper.
8. The browser does not persist approval. Reloading the site requires password + a new OTP again.

## One-time deployment

Use the existing Apps Script project behind the current `/exec` URL so the application URL does not need to change.

1. Open the existing Google Apps Script project.
2. Replace `Code.gs` with the full contents of `generator_access_otp.gs`.
3. Click **Deploy → Manage deployments**.
4. Edit the existing Web app deployment.
5. Select **New version**.
6. Execute as: **Me**.
7. Who has access: **Anyone** (the script itself still rejects every request without a valid Firebase password session and owner OTP).
8. Click **Deploy** and grant Mail/UrlFetch permissions when Google asks.
9. Keep the same `/exec` deployment URL.

Health check after deployment:

`<YOUR_EXEC_URL>?action=health`

Expected JSON includes:

```json
{"status":"healthy","ok":true,"version":"email-otp-v2"}
```

## Important

Do not put Gmail passwords, app passwords, Firebase admin keys, or any other secret in this repository. The only configured Firebase value here is the public web API key, which is already shipped to browsers by Firebase client applications.
