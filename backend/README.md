# DevPulse Backend

Node.js + Express API for DevPulse uptime monitoring.

## Setup
1. Copy `.env.example` to `.env` and fill in real values
2. `npm install`
3. `npm run dev`

## Env Vars
- MONGODB_URI - MongoDB Atlas connection string
- CLERK_SECRET_KEY - from Clerk dashboard
- PORT - default 5000
- FRONTEND_ORIGIN - deployed/local frontend URL for CORS
