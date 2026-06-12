# Deploy With GitHub + Render

This project is prepared for a two-part Render deployment:

- `gt7-coach-web`: static frontend
- `gt7-coach-api`: Node backend

The Render blueprint file is already included at `render.yaml`.

## 1. Create a GitHub repository

On your own PC terminal inside the project root:

```bash
git init
git add .
git commit -m "Prepare GT7 Coach for Render deployment"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

If this folder is already a git repo, just use:

```bash
git add .
git commit -m "Prepare GT7 Coach for Render deployment"
git push
```

## 2. Deploy on Render

1. Go to [render.com](https://render.com)
2. Sign in with GitHub
3. Click `New +`
4. Choose `Blueprint`
5. Select your GitHub repository
6. Render will detect `render.yaml`
7. Create the two services:
   - `gt7-coach-api`
   - `gt7-coach-web`

## 3. Check the generated URLs

Render usually gives URLs like:

- `https://gt7-coach-api.onrender.com`
- `https://gt7-coach-web.onrender.com`

If Render gives different names, update `render.yaml` to match the actual generated URLs:

- `ALLOWED_ORIGIN`
- `VITE_API_BASE_URL`
- `VITE_WS_URL`

Then push the updated file to GitHub and Render will redeploy.

## 4. Recommended final values

If your service names stay the same, these values should work:

Backend:

- `NODE_ENV=production`
- `ENABLE_UDP_TELEMETRY=false`
- `ALLOWED_ORIGIN=https://gt7-coach-web.onrender.com`

Frontend:

- `VITE_API_BASE_URL=https://gt7-coach-api.onrender.com`
- `VITE_WS_URL=wss://gt7-coach-api.onrender.com/ws`

## 5. Verify after deploy

Open:

- frontend site URL
- backend health URL: `https://YOUR-API-URL/health`

You should see a health response similar to:

```json
{
  "ok": true,
  "websocketPath": "/ws",
  "udpTelemetryEnabled": false
}
```

## 6. Important GT7 telemetry note

The public hosted version works for:

- tune generation
- track browsing
- update showcase
- demo telemetry

Real live GT7 telemetry from a PS5 usually still needs local-network access, so your hosted site should be treated as the public app, while local bridge mode remains the best path for actual console telemetry.

## 7. Optional custom domain

After deployment, you can add a real domain in Render:

- `app.yourdomain.com` -> frontend
- `api.yourdomain.com` -> backend

If you do that, update:

- `ALLOWED_ORIGIN`
- `VITE_API_BASE_URL`
- `VITE_WS_URL`

to use your domain instead of `onrender.com`.
