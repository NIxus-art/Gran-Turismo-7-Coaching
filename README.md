# GT7 Driving Coach App

A coaching app for Gran Turismo 7 with real-time telemetry, track guides, and car tuning.

## Features
- Real-time GT7 telemetry integration (UDP ports 33739/33740)
- Detailed track maps with braking/acceleration zones
- Perfect car tunes for every track
- Subscription plans: €9.99/month or €99.99/year

## Run locally

### Frontend
```bash
cd frontend
npm install
npm run dev
```

### Backend
```bash
cd backend
npm install
npm start
```

## Deploy online

This project is now prepared for web hosting:

- `frontend` uses environment-based API and WebSocket URLs instead of hardcoded `localhost`
- `backend` uses `PORT`, `ALLOWED_ORIGIN`, and optional hosted-mode UDP disabling
- `render.yaml` is included for one-click deployment on Render

### Recommended hosting

- Frontend: Render Static Site
- Backend: Render Web Service

### Render deployment

1. Push this project to GitHub.
2. Create a new Render Blueprint deployment from the repository.
3. Render will read `render.yaml` and create:
   - `gt7-coach-web`
   - `gt7-coach-api`
4. Update the generated service URLs in `render.yaml` if your final Render subdomains differ.

### Environment files

- Frontend example: `frontend/.env.example`
- Backend example: `backend/.env.example`

## Important note about GT7 telemetry

The hosted web version works well for:

- tune generation
- track guides
- demo telemetry
- subscriptions and app UI

Real GT7 console telemetry is still best handled locally on the same network as the console. Hosted cloud servers usually cannot receive the PS5 local UDP telemetry directly, so the online deployment should be treated as the public app experience, while local bridge mode remains the path for real live GT7 telemetry.
