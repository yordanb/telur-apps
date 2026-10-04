# Endog Web Dashboard

React + Vite + TypeScript + Tailwind + React Router. Basis tema TailAdmin, aksen oranye Endog.

## Dev lokal

```bash
cp .env.example .env   # VITE_API_URL=https://egg.mibt.my.id/api
npm install
npm run dev            # http://localhost:5173
```

Login memakai `POST {VITE_API_URL}/auth/login` (form-urlencoded) → JWT di
`localStorage`, lalu `GET {VITE_API_URL}/auth/me`.

## Docker (lifecycle terpisah dari backend)

```bash
cd web
docker compose up -d --build   # egg-web di 8801:80
```

Routing satu domain (di `mibt-nginx` VPS, manual): `/` → `127.0.0.1:8801`,
`/api/ /docs /openapi.json /uploads/` → `127.0.0.1:8800`, lalu
`docker exec mibt-nginx nginx -s reload`.
