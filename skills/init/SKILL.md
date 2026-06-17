---
name: init
description: "Scaffolds a complete runnable fullstack project from an empty directory. Invocable via `/nob:init` directly or through the Nob hub. Triggers on: 'nob init', 'initialize project', 'scaffold project'."
---

# Nob — Init Agent

## Overview
Bootstrap a new fullstack project from scratch. Understand what the user is building, recommend the right tech stack, scaffold working boilerplate, install dependencies, and write project config so the project is immediately ready for `/nob implement`.

---

## Inputs

Provided by the hub in the `[INPUTS]` block:
- `Working directory` — absolute path to the target project directory
- `User intent` — the user's original message (e.g., "nob init")

---

## Setup

Extract `Working directory` from the `[INPUTS]` block. Store it as WORKING_DIR. All Bash commands and Write tool calls in this skill use WORKING_DIR as the base path (e.g., `ls -A {WORKING_DIR}`, `mkdir -p {WORKING_DIR}/apps/frontend/src/app`).

## Mode 0: Mode Detection

Check whether an `[INPUTS]` block is present in the current context.

- **Hub-dispatched mode** (`[INPUTS]` present): all required values are provided in that block. Follow the steps below using those values — do not prompt the user.
- **Standalone mode** (`[INPUTS]` absent): you have been invoked directly. Use the current working directory as the working directory and the user's message as the intent. No prior agent output needed — proceed to Step 1.

## Step 1: Check directory is empty

Run via Bash: `ls -A {WORKING_DIR}`

If any files exist other than `.git` and `.gitignore`: stop immediately and emit:

```
[INIT OUTPUT]
Status: aborted
Reason: Directory is not empty. /nob init is for fresh projects only.
To work on an existing project, run: /nob implement <spec-file>
[/INIT OUTPUT]
```

If the directory is empty (or contains only `.git` / `.gitignore`): proceed to Step 2.

---

## Step 2: Understand the project

Ask the user:

> "Describe what you're building in a few sentences — what it does, who uses it, and any scale or performance requirements you have in mind."

Wait for the user's answer. Store it as PROJECT_DESCRIPTION.

If the description is a single word or obviously too vague to make a stack recommendation (e.g., "app", "website"), ask one follow-up before continuing:

> "Can you tell me more about who uses it and what the main actions are? (e.g., 'users upload files and share them with teammates')"

Append any follow-up answer to PROJECT_DESCRIPTION. Do not ask more than one follow-up.

---

## Step 3: Recommend a stack

Based on PROJECT_DESCRIPTION, select the best option per layer using these rules:

**Frontend:**
- Web app with SEO, marketing pages, or server rendering needs → `next` (Next.js 14)
- Web app, SPA, dashboard, no SSR needed → `react-vite` (React + Vite)
- Team prefers Vue or description mentions Vue → `vue` (Vue 3 + Vite)
- Mobile app, iOS/Android, or cross-platform → `flutter` (Flutter 3)

**Backend:**
- JavaScript/TypeScript team, or frontend is Next.js/React/Vue with no other signal → `express` (Node.js + Express)
- Data science, ML pipeline, Python team, or description mentions Python → `fastapi` (Python + FastAPI)
- Performance-critical, high-concurrency, systems-level, or description mentions Go → `go` (Go + Gin)

**Database:**
- Any relational data, user accounts, multi-user, or production use → `postgres` (PostgreSQL)
- Local-only tool, CLI, prototype, no external DB → `sqlite` (SQLite)

Present the recommendation in this format and wait for the user's response:

```
Recommended stack for your project:

Frontend:  [framework + version + styling]
Backend:   [language + framework]
Database:  [database + ORM, e.g. "PostgreSQL + Prisma ORM" or "PostgreSQL + Alembic"]
Packages:  shared/core ([ORM name] schema + [TypeScript contracts | OpenAPI spec])

Why: [2–3 sentences tying the recommendation to what the user described]

Does this stack work for you? Or would you like to change any layer?
(e.g. "use Python for backend", "use SQLite instead of PostgreSQL", "use Drizzle instead of Prisma")
```

Parse the user's response:
- "yes" / "looks good" / "proceed" / no changes → confirm as recommended
- Override for a layer (e.g., "use Python") → update that layer only, keep others
- Request for unsupported stack → respond: "[Option] isn't supported yet. I can use [closest supported option], or scaffold the directory structure only for that layer and you configure it manually. Which do you prefer?" Wait for answer.

Store confirmed values:
- FRONTEND_TYPE: `next` | `react-vite` | `vue` | `flutter`
- BACKEND_TYPE: `express` | `fastapi` | `go`
- DATABASE_TYPE: `postgres` | `sqlite`
- ORM_TYPE: determined by rules below

Determine ORM_TYPE from confirmed stack:
- BACKEND_TYPE = `express` (any DATABASE_TYPE) → `prisma` (default). If user says "use Drizzle" → `drizzle`. If user says "use Kysely" → `kysely`. Any other Node ORM override → `other-node-orm`.
- BACKEND_TYPE = `fastapi` → `alembic`
- BACKEND_TYPE = `go` → `goose`

Extract PROJECT_NAME from PROJECT_DESCRIPTION: 2–3 words, title case (e.g., "Task Tracker", "File Sharing Platform").

---

## Step 4: Scaffold files

Use the Write tool to create all files below for the confirmed stack. Before writing each file, run `mkdir -p <parent-dir>` via Bash if the directory might not exist.

### Root files (always created)

Write `.gitignore`:
```
node_modules/
.env
dist/
.next/
out/
.nob/
__pycache__/
*.pyc
.venv/
*.exe
vendor/
.flutter-plugins
.flutter-plugins-dependencies
```

---

### If FRONTEND_TYPE = `next`

Run: `mkdir -p apps/frontend/src/app frontend/src/lib`

Write `apps/frontend/package.json`:
```json
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  },
  "dependencies": {
    "next": "14.2.0",
    "react": "^18",
    "react-dom": "^18"
  },
  "devDependencies": {
    "typescript": "^5",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "tailwindcss": "^3",
    "postcss": "^8",
    "autoprefixer": "^10"
  }
}
```

Write `apps/frontend/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

Write `apps/frontend/tailwind.config.ts`:
```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: { extend: {} },
  plugins: [],
}

export default config
```

Write `apps/frontend/postcss.config.js`:
```javascript
module.exports = {
  plugins: { tailwindcss: {}, autoprefixer: {} },
}
```

Write `apps/frontend/next.config.js`:
```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {}
module.exports = nextConfig
```

Write `apps/frontend/src/app/globals.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

Write `apps/frontend/src/app/layout.tsx`:
```tsx
import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'My App',
  description: 'Generated by nob init',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
```

Write `apps/frontend/src/app/page.tsx`:
```tsx
'use client'

import { useEffect, useState } from 'react'
import { fetchItems } from '@/lib/api'

export default function Home() {
  const [items, setItems] = useState<string[]>([])
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchItems()
      .then(setItems)
      .catch((e: Error) => setError(e.message))
  }, [])

  return (
    <main className="p-8">
      <h1 className="text-2xl font-bold mb-4">My App</h1>
      {error && <p className="text-red-500">{error}</p>}
      <ul className="list-disc pl-4">
        {items.map((item, i) => <li key={i}>{item}</li>)}
      </ul>
    </main>
  )
}
```

Write `apps/frontend/src/lib/api.ts`:
```typescript
const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:3001'

export async function fetchItems(): Promise<string[]> {
  const res = await fetch(`${API_BASE}/api/v1/items`)
  if (!res.ok) throw new Error(`API error: ${res.status}`)
  const data = await res.json() as { items: string[] }
  return data.items
}
```

Write `apps/frontend/.env.example`:
```
NEXT_PUBLIC_API_URL=http://localhost:3001
```

---

### If FRONTEND_TYPE = `react-vite`

Run: `mkdir -p apps/frontend/src/lib`

Write `apps/frontend/package.json`:
```json
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18",
    "react-dom": "^18"
  },
  "devDependencies": {
    "typescript": "^5",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "@vitejs/plugin-react": "^4",
    "vite": "^5",
    "tailwindcss": "^3",
    "postcss": "^8",
    "autoprefixer": "^10"
  }
}
```

Write `apps/frontend/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true
  },
  "include": ["src"]
}
```

Write `apps/frontend/vite.config.ts`:
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': { target: 'http://localhost:3001', changeOrigin: true },
    },
  },
})
```

Write `apps/frontend/tailwind.config.ts`:
```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: { extend: {} },
  plugins: [],
}

export default config
```

Write `apps/frontend/postcss.config.js`:
```javascript
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } }
```

Write `apps/frontend/index.html`:
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>My App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

Write `apps/frontend/src/main.tsx`:
```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode><App /></React.StrictMode>
)
```

Write `apps/frontend/src/index.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

Write `apps/frontend/src/App.tsx`:
```tsx
import { useEffect, useState } from 'react'
import { fetchItems } from './lib/api'

export default function App() {
  const [items, setItems] = useState<string[]>([])
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetchItems()
      .then(setItems)
      .catch((e: Error) => setError(e.message))
  }, [])

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-4">My App</h1>
      {error && <p className="text-red-500">{error}</p>}
      <ul className="list-disc pl-4">
        {items.map((item, i) => <li key={i}>{item}</li>)}
      </ul>
    </div>
  )
}
```

Write `apps/frontend/src/lib/api.ts`:
```typescript
const API_BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:3001'

export async function fetchItems(): Promise<string[]> {
  const res = await fetch(`${API_BASE}/api/v1/items`)
  if (!res.ok) throw new Error(`API error: ${res.status}`)
  const data = await res.json() as { items: string[] }
  return data.items
}
```

Write `apps/frontend/.env.example`:
```
VITE_API_URL=http://localhost:3001
```

---

### If FRONTEND_TYPE = `vue`

Run: `mkdir -p apps/frontend/src/lib`

Write `apps/frontend/package.json`:
```json
{
  "name": "frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "vite",
    "build": "vue-tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.4.0"
  },
  "devDependencies": {
    "typescript": "^5",
    "@vitejs/plugin-vue": "^5",
    "vite": "^5",
    "vue-tsc": "^2",
    "tailwindcss": "^3",
    "postcss": "^8",
    "autoprefixer": "^10"
  }
}
```

Write `apps/frontend/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["src/**/*.ts", "src/**/*.d.ts", "src/**/*.tsx", "src/**/*.vue"]
}
```

Write `apps/frontend/vite.config.ts`:
```typescript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    proxy: {
      '/api': { target: 'http://localhost:3001', changeOrigin: true },
    },
  },
})
```

Write `apps/frontend/tailwind.config.ts`:
```typescript
import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./index.html', './src/**/*.{vue,ts}'],
  theme: { extend: {} },
  plugins: [],
}

export default config
```

Write `apps/frontend/postcss.config.js`:
```javascript
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } }
```

Write `apps/frontend/index.html`:
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>My App</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
```

Write `apps/frontend/src/main.ts`:
```typescript
import { createApp } from 'vue'
import App from './App.vue'
import './index.css'

createApp(App).mount('#app')
```

Write `apps/frontend/src/index.css`:
```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

Write `apps/frontend/src/App.vue`:
```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { fetchItems } from './lib/api'

const items = ref<string[]>([])
const error = ref<string | null>(null)

onMounted(async () => {
  try {
    items.value = await fetchItems()
  } catch (e) {
    error.value = (e as Error).message
  }
})
</script>

<template>
  <div class="p-8">
    <h1 class="text-2xl font-bold mb-4">My App</h1>
    <p v-if="error" class="text-red-500">{{ error }}</p>
    <ul class="list-disc pl-4">
      <li v-for="(item, i) in items" :key="i">{{ item }}</li>
    </ul>
  </div>
</template>
```

Write `apps/frontend/src/lib/api.ts`:
```typescript
const API_BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:3001'

export async function fetchItems(): Promise<string[]> {
  const res = await fetch(`${API_BASE}/api/v1/items`)
  if (!res.ok) throw new Error(`API error: ${res.status}`)
  const data = await res.json() as { items: string[] }
  return data.items
}
```

Write `apps/frontend/.env.example`:
```
VITE_API_URL=http://localhost:3001
```

---

### If FRONTEND_TYPE = `flutter`

Run: `mkdir -p apps/frontend/lib/screens frontend/lib/services`

Write `apps/frontend/pubspec.yaml`:
```yaml
name: frontend
description: A Flutter app
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

Write `apps/frontend/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

Write `apps/frontend/lib/screens/home_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<String>> _items;

  @override
  void initState() {
    super.initState();
    _items = ApiService().fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My App')),
      body: FutureBuilder<List<String>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(title: Text(items[i])),
          );
        },
      ),
    );
  }
}
```

Write `apps/frontend/lib/services/api_service.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _base = 'http://localhost:3001';

  Future<List<String>> fetchItems() async {
    final response = await http.get(Uri.parse('$_base/api/v1/items'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load items: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<String>.from(data['items'] as List);
  }
}
```

---

### If BACKEND_TYPE = `express`

Run: `mkdir -p apps/backend/src/routes backend/src/middleware`

Write `apps/backend/package.json`:
```json
{
  "name": "backend",
  "version": "0.1.0",
  "scripts": {
    "dev": "ts-node-dev --respawn --transpile-only src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "typescript": "^5",
    "@types/express": "^4",
    "@types/cors": "^2",
    "@types/node": "^20",
    "ts-node-dev": "^2",
    "jest": "^29",
    "@types/jest": "^29",
    "ts-jest": "^29",
    "supertest": "^6",
    "@types/supertest": "^2"
  }
}
```

Write `apps/backend/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

Write `apps/backend/jest.config.js`:
```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
}
```

Write `apps/backend/src/index.ts`:
```typescript
import express from 'express'
import cors from 'cors'
import dotenv from 'dotenv'
import { errorHandler } from './middleware/errorHandler'
import routes from './routes'

dotenv.config()

const app = express()
const PORT = Number(process.env.PORT ?? 3001)

app.use(cors())
app.use(express.json())
app.use(routes)
app.use(errorHandler)

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`)
})

export default app
```

Write `apps/backend/src/routes/index.ts`:
```typescript
import { Router } from 'express'
import healthRouter from './health'
import itemsRouter from './items'

const router = Router()

router.use(healthRouter)
router.use('/api/v1', itemsRouter)

export default router
```

Write `apps/backend/src/routes/health.ts`:
```typescript
import { Router, Request, Response } from 'express'

const router = Router()

router.get('/health', (_req: Request, res: Response) => {
  res.json({ status: 'ok' })
})

export default router
```

Write `apps/backend/src/routes/items.ts`:
```typescript
import { Router, Request, Response } from 'express'

const router = Router()

router.get('/items', (_req: Request, res: Response) => {
  res.json({ items: ['item-1', 'item-2', 'item-3'] })
})

export default router
```

Write `apps/backend/src/middleware/errorHandler.ts`:
```typescript
import { Request, Response, NextFunction } from 'express'

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction
): void {
  console.error(err.stack)
  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: err.message },
  })
}
```

Write `apps/backend/.env.example`:
```
PORT=3001
DATABASE_URL=postgresql://localhost:5432/myapp
```

---

### If BACKEND_TYPE = `fastapi`

Run: `mkdir -p apps/backend/routes`

Write `apps/backend/requirements.txt`:
```
fastapi==0.110.0
uvicorn[standard]==0.27.1
python-dotenv==1.0.1
httpx==0.27.0
pytest==8.1.1
pytest-asyncio==0.23.5
```

Write `apps/backend/main.py`:
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from routes import health, items

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(items.router, prefix="/api/v1")
```

Write `apps/backend/routes/__init__.py`:
```python
```

Write `apps/backend/routes/health.py`:
```python
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health_check():
    return {"status": "ok"}
```

Write `apps/backend/routes/items.py`:
```python
from fastapi import APIRouter

router = APIRouter()

@router.get("/items")
def get_items():
    return {"items": ["item-1", "item-2", "item-3"]}
```

Write `apps/backend/.env.example`:
```
DATABASE_URL=postgresql://localhost:5432/myapp
```

**If BACKEND_TYPE = `fastapi`:** After writing all backend files, also update the frontend `.env.example`:
- If FRONTEND_TYPE = `next`: overwrite `apps/frontend/.env.example` with `NEXT_PUBLIC_API_URL=http://localhost:8000`
- If FRONTEND_TYPE = `react-vite` or `vue`: overwrite `apps/frontend/.env.example` with `VITE_API_URL=http://localhost:8000`
- If FRONTEND_TYPE = `flutter`: update the `_base` constant in `apps/frontend/lib/services/api_service.dart` from `http://localhost:3001` to `http://localhost:8000`

FastAPI serves on port 8000 by default (`uvicorn main:app --reload`). Mismatched ports cause silent CORS failures.

---

### If BACKEND_TYPE = `go`

Run: `mkdir -p apps/backend/handlers`

Slugify PROJECT_NAME to lowercase hyphenated form (e.g., "Task Tracker" → "task-tracker"). Store as MODULE_NAME. The full Go module path is `example.com/[MODULE_NAME]` — use this in go.mod and all import paths.

Write `apps/backend/go.mod`:
```
module example.com/[MODULE_NAME]

go 1.22

require (
	github.com/gin-gonic/gin v1.9.1
	github.com/joho/godotenv v1.5.1
)
```

Write `apps/backend/main.go`:
```go
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"example.com/[MODULE_NAME]/handlers"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	port := os.Getenv("PORT")
	if port == "" {
		port = "3001"
	}

	r := gin.Default()
	r.Use(corsMiddleware())

	r.GET("/health", handlers.Health)
	r.GET("/api/v1/items", handlers.GetItems)

	log.Printf("Server running on port %s", port)
	if err := r.Run(fmt.Sprintf(":%s", port)); err != nil {
		log.Fatal(err)
	}
}

func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
```

Write `apps/backend/handlers/health.go`:
```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
```

Write `apps/backend/handlers/items.go`:
```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func GetItems(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"items": []string{"item-1", "item-2", "item-3"},
	})
}
```

Write `apps/backend/.env.example`:
```
PORT=3001
DATABASE_URL=postgresql://localhost:5432/myapp
```

After writing all Go files, run from `apps/backend/`: `go mod tidy`

---

### shared/core (always created)

Run: `mkdir -p shared/core/contracts shared/core/schema`

**If FRONTEND_TYPE is `next`, `react-vite`, or `vue`, OR BACKEND_TYPE is `express`** (any JS/TS app):

Derive PROJECT_SLUG from PROJECT_NAME: lowercase, spaces replaced with hyphens (e.g. "Task Tracker" → "task-tracker").

Write `pnpm-workspace.yaml`:
```yaml
packages:
  - 'apps/*'
  - 'shared/*'
```

Write `package.json` (root):
```json
{
  "name": "[PROJECT_SLUG]",
  "private": true,
  "scripts": {
    "dev:frontend": "pnpm --filter frontend dev",
    "dev:backend": "pnpm --filter backend dev"
  }
}
```

Write `shared/core/package.json`:
```json
{
  "name": "@[PROJECT_SLUG]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts"
}
```

Write `shared/core/contracts/index.ts`:
```typescript
export interface ApiResponse<T> {
  data: T
  error?: { code: string; message: string }
}

export interface Item {
  id: string
  name: string
}
```

**If BACKEND_TYPE = `fastapi` or `go`:**

Write `shared/core/contracts/openapi.yml`:
```yaml
openapi: 3.0.0
info:
  title: [PROJECT_NAME] API
  version: 0.1.0
paths:
  /health:
    get:
      summary: Health check
      responses:
        '200':
          description: OK
  /api/v1/items:
    get:
      summary: List items
      responses:
        '200':
          description: OK
```

**If ORM_TYPE = `prisma`:**

Determine Prisma provider: DATABASE_TYPE = `postgres` → `postgresql`; DATABASE_TYPE = `sqlite` → `sqlite`.

Write `shared/core/schema/schema.prisma`:
```prisma
datasource db {
  provider = "[postgresql | sqlite]"
  url      = env("DATABASE_URL")
}

generator client {
  provider        = "prisma-client-js"
  output          = "../../../node_modules/.prisma/client"
}

model Item {
  id        String   @id @default(cuid())
  name      String
  createdAt DateTime @default(now())
}
```

Update `shared/core/package.json` to add Prisma dependency:
```json
{
  "name": "@[PROJECT_SLUG]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts",
  "dependencies": {
    "@prisma/client": "^5.0.0"
  },
  "devDependencies": {
    "prisma": "^5.0.0"
  }
}
```

**If ORM_TYPE = `drizzle`:**

Write `shared/core/schema/schema.ts`:
```typescript
import { pgTable, text, timestamp } from 'drizzle-orm/pg-core'

export const items = pgTable('items', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  createdAt: timestamp('created_at').defaultNow(),
})
```

Write `shared/core/schema/drizzle.config.ts`:
```typescript
import type { Config } from 'drizzle-kit'

export default {
  schema: './shared/core/schema/schema.ts',
  out: './shared/core/schema/migrations',
  driver: 'pg',
} satisfies Config
```

Update `shared/core/package.json` to add Drizzle dependency:
```json
{
  "name": "@[PROJECT_SLUG]/core",
  "version": "0.1.0",
  "main": "./contracts/index.ts",
  "types": "./contracts/index.ts",
  "dependencies": {
    "drizzle-orm": "^0.30.0"
  },
  "devDependencies": {
    "drizzle-kit": "^0.20.0"
  }
}
```

**If ORM_TYPE = `alembic` (FastAPI):**

Run: `mkdir -p shared/core/schema/migrations`

Write `shared/core/schema/migrations/README.md`:
```markdown
# Database Migrations

Managed by Alembic. Initialize from apps/backend/:

    alembic init alembic
    alembic revision --autogenerate -m "initial"
    alembic upgrade head
```

Write `shared/core/__init__.py`:
(empty file — makes this a Python package)

Write `shared/core/pyproject.toml`:
```toml
[build-system]
requires = ["setuptools"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "core"
version = "0.1.0"
```

**If ORM_TYPE = `goose` (Go):**

Run: `mkdir -p shared/core/schema/migrations`

Write `shared/core/schema/migrations/README.md`:
```markdown
# Database Migrations

Managed by goose. Run from the repo root:

    goose -dir shared/core/schema/migrations postgres "$DATABASE_URL" up
    goose -dir shared/core/schema/migrations postgres "$DATABASE_URL" create migration_name sql
```

**If BACKEND_TYPE = `go`:**

Write `go.work`:
```
go 1.22

use (
	./apps/backend
)
```

---

## Step 5: Generate CLAUDE.md

Write `CLAUDE.md` at the working directory root. Use confirmed stack values — no placeholder text.

Determine frontend start command:
- `next` → `cd apps/frontend && npm run dev`
- `react-vite` → `cd apps/frontend && npm run dev`
- `vue` → `cd apps/frontend && npm run dev`
- `flutter` → `cd apps/frontend && flutter run`

Determine backend start command:
- `express` → `cd apps/backend && npm run dev`
- `fastapi` → `cd apps/backend && uvicorn main:app --reload`
- `go` → `cd apps/backend && go run main.go`

Write `CLAUDE.md`:

```markdown
# Project: [PROJECT_NAME]

## Stack
- Frontend: [full description, e.g., "Next.js 14, TypeScript, Tailwind CSS"]
- Backend: [full description, e.g., "Node.js, Express, TypeScript"]
- Database: [PostgreSQL | SQLite]

## Folder Structure
- apps/frontend/ — [framework] app. Deployable target. No business logic.
- apps/backend/ — [framework] API. Deployable target. No shared contracts here.
- shared/core/contracts/ — Source of truth for types and API shapes.
- shared/core/schema/ — Source of truth for database schema and migrations.

## AI Agent Rules
- Feature work → edit apps/
- Shared types or API shape changes → edit shared/core/contracts/
- Database changes → edit shared/core/schema/
- Adding a new domain → create shared/[domain]/contracts/ and shared/[domain]/schema/
- Never put app-specific logic in shared/
- Never put shared contracts inside apps/

## API Conventions
- Base URL: /api/v1
- Error format: `{ "error": { "code": "string", "message": "string" } }`

## Frontend Conventions
[if next/react-vite/vue:]
- Components: functional, hooks only
- API client: /apps/frontend/src/lib/api.ts
[if flutter:]
- API client: /apps/frontend/lib/services/api_service.dart

## Backend Conventions
[if express:]
- Routes: /apps/backend/src/routes/ — one Router file per resource
- Error handler: /apps/backend/src/middleware/errorHandler.ts
- Tests: Jest + Supertest — run `npm test` from /apps/backend
[if fastapi:]
- Routes: /apps/backend/routes/ — one file per resource
- Tests: pytest — run `pytest` from /apps/backend
[if go:]
- Handlers: /apps/backend/handlers/ — one file per resource
- Tests: go test — run `go test ./...` from /apps/backend

## Dev Commands
- Start backend:  [backend start command]
- Start frontend: [frontend start command]
```

---

## Step 6: Generate .nob.yml

Determine backend unit type value:
- `express` → `node`
- `fastapi` → `python`
- `go` → `go`

Determine frontend unit type value:
- `next` → `next`
- `react-vite` → `react`
- `vue` → `vue`
- `flutter` → `flutter`

Write `.nob.yml`:

```yaml
units:
  - name: web
    type: [next | react | vue | flutter]  # node | python | go | java | ruby | react | vue | next | flutter | android | ios | react-native | generic
    path: apps/frontend/
  - name: api
    type: [node | python | go]  # node | python | go | java | ruby | react | vue | next | flutter | android | ios | react-native | generic
    path: apps/backend/

docs:
  enabled: true
  specs: docs/specs
  bugs: docs/bugs

structure:
  check: false

agents:
  enabled:
    - pm
    - tech-lead
    - dev
    - reviewer
    - ideation
  models:
    dev: sonnet
    tech-lead: sonnet
    pm: haiku
    reviewer: haiku
    init: sonnet
  max_parallel_slices: 3
  checkpoint:
    enabled: true
    path: .nob/
```

---

## Step 7: Install dependencies

Run the install commands below. Capture exit codes. Continue on failure — do not stop.

**If any JS/TS app exists (FRONTEND_TYPE is `next`, `react-vite`, or `vue`, OR BACKEND_TYPE is `express`):**
Run from repo root: `pnpm install`
This installs all `apps/*` and `shared/*` workspaces in one command.

**If FRONTEND_TYPE = `flutter`:**
Run from `apps/frontend/`: `flutter pub get`

**If BACKEND_TYPE = `fastapi`:**
Run from `apps/backend/`: `python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`

**If BACKEND_TYPE = `go`:**
Run from `apps/backend/`: `go mod tidy` (already run in Step 4; skip if already done)

For each command that fails (non-zero exit code): record `{layer}: FAILED — {error summary}`. Collect all failures for the output block.

---

## Step 8: Output

Emit:

```
[INIT OUTPUT]
Status: [complete | partial | aborted]
Project: [PROJECT_NAME]
Database: [DATABASE_TYPE]
Units:
  - web ([next | react | vue | flutter]) → apps/frontend/
  - api ([node | python | go]) → apps/backend/

Files created:
- [list every file path written, one per line, relative to working dir]

Installs:
  [if JS/TS stack: pnpm install (root) ✓ | pnpm install (root) ✗]
  [if Python backend: apps/backend pip install ✓ | apps/backend pip install ✗]
  [if Go backend: apps/backend go mod tidy ✓ | apps/backend go mod tidy ✗]
  [if Flutter frontend: apps/frontend flutter pub get ✓ | apps/frontend flutter pub get ✗]

[if any failures:]
Install errors — run manually:
  [exact retry command with correct directory]

web start command: [command]
web directory: apps/frontend/
api start command: [command]
api directory: apps/backend/
[/INIT OUTPUT]
```

---

## Error Handling

| Condition | Response |
|---|---|
| Directory not empty | Stop at Step 1 — emit INIT-AGENT OUTPUT with Status: aborted |
| Install fails | Record failure, continue — emit with Status: partial, list retry commands |
| User requests unsupported stack | Offer closest supported option or scaffold structure only for that layer |
| Description too vague | Ask one follow-up at Step 2, then proceed |
| go mod tidy fails due to missing network | Note in output: "Run `go mod tidy` manually after network is available" |

---

## Status

End your response with exactly one of:
- `STATUS: DONE`
- `STATUS: DONE_WITH_CONCERNS: <brief description>`
- `STATUS: BLOCKED: <brief description>`
