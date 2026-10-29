# Social Network API

The API uses Express and MongoDB. Start it from this directory after creating a
`.env` file with `MONGO_URI` and a long, private `JWT_SECRET`:

```text
MONGO_URI=mongodb://127.0.0.1:27017/foodiehub
JWT_SECRET=replace-with-a-long-random-secret
PORT=3000
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your-smtp-username
SMTP_PASS=your-smtp-password
SMTP_FROM=Social Network <no-reply@example.com>
```

Install packages and start the server:

```powershell
npm install
npm run dev
```

The API listens on port `3000` by default (or the `PORT` set in `.env`), and uploaded post images are stored in the
backend's `uploads` directory and served from `/uploads`.

New accounts register a unique username (3-24 lowercase letters, digits, or
underscores) and sign in with their email address and password. The API also
continues to accept usernames for existing clients.

Password recovery emails a six-digit verification code. Configure `SMTP_HOST`,
`SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASS`, and `SMTP_FROM` in the
backend environment before using forgot password. Codes expire after 10
minutes, allow up to five attempts, and can only be requested once per minute.

Authenticated endpoints support profile updates, post create/read/update/delete,
post reactions and comments, and chat conversations. Chat messages and in-app
notifications are stored in MongoDB; chat and post images accept JPG, PNG,
WEBP, or GIF files up to 10 MB. Search posts with `GET /api/posts?q=...`,
`sort=recent|popular`, and `location=true`. Chat contacts, conversations,
messages, and notifications are available under `/api/chat`. Profile updates
accept optional `profileImage` and `bannerImage` multipart image fields.

Flutter uses `http://10.0.2.2:3000/api` on the Android emulator and
`http://127.0.0.1:3000/api` on web and iOS simulators. For a physical phone,
connect the phone and computer to the same network and set the computer's
reachable address when launching Flutter:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api
```

Replace that example address with the computer's LAN IP and allow inbound
connections to port 3000 in its firewall. The Android manifest permits
cleartext HTTP for local development; use HTTPS and persistent protected media
storage when deploying the API publicly.
