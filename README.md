# Moonline-workspace

Moonline is a personal workspace where your notes, tasks, events and calendar live together with AI assistants: each one is a chat with its own prompt and personality, configured by you, with context only from what you link to it (documents, tasks, notes, events) — each assistant with its own separate context.

Instead of a generic chatbot, Moonline is a workspace with AI that aims to help you in your day to day.


## Project status

Actively under construction. This repo starts the **Auth** module in Spring Boot from scratch; the remaining modules (tasks, notes, events, documents) will be added here as the roadmap progresses. The AI part (chat, RAG, function calling) lives in a separate FastAPI/Python service.

## Project idea

Moonline isn't trying to replace ChatGPT. Each assistant has its own workspace with:

- Conversational AI chat
- Documents (upload and view)
- Notes
- Tasks
- Events / calendar

The goal is for the assistant to **actively use** that context (via RAG and function calling), not just store it.

## Architecture

Polyglot architecture, split by responsibility — not by whim:

```
┌─────────────┐      ┌──────────────────┐      ┌──────────────────┐
│   Frontend   │─────▶│  Spring Boot     │◀────▶│  FastAPI         │
│  React+Vite  │      │  (core/critical) │ HTTP │  (AI service)    │
└─────────────┘      └──────────────────┘      └──────────────────┘
                             │                          │
                             ▼                          ▼
                        PostgreSQL                  OpenAI API
                        (Flyway)
```

**Spring Boot — core/critical** (this repo)
- Authentication and authorization (JWT + Google OAuth2)
- Users
- Tasks, notes, events, documents (CRUD + ownership)
- Rate limiting
- Single source of truth for business data

**FastAPI — AI service** (separate repo)
- Chat with the LLM and its history
- Function calling (orchestrates actions, but executes them by calling Spring Boot)
- RAG over documents/notes
- Usage/token tracking per user

The two services talk over HTTP through internal endpoints (`/internal/**`), authenticated with a service JWT (`role=SERVICE`) independent of the user's JWT.

## Tech stack

| Area | Technology |
|---|---|
| Language | Java 17+ |
| Framework | Spring Boot 3.5 |
| Security | Spring Security, JJWT (JWT), BCrypt |
| Persistence | Spring Data JPA + PostgreSQL |
| Migrations | Flyway |
| Mapping | MapStruct |
| Validation | Jakarta Validation |
| Testing | JUnit5, Mockito, H2 (tests) |
| Infra | VPS (IONOS), Nginx, Certbot, Cloudflare, UFW, Fail2Ban |

## Security principles applied

- Role always assigned server-side on registration (never from the request body)
- Generic error messages on login/registration (no user enumeration)
- Passwords hashed with BCrypt, never manual hash comparison
- Secrets (JWT, DB credentials) always in environment variables, never in code
- `SessionCreationPolicy.STATELESS`, no server-side sessions
- Resource ownership checked on every endpoint — accessing someone else's resource returns 404, not 403
- Schema migrations versioned with Flyway, never `ddl-auto=update` in production

## Roadmap

- [ ] Auth: registration, login, JWT, security filter, exception handling
- [ ] Refresh token + rate limiting on login
- [ ] Google login (OAuth2)
- [ ] CRUD: tasks, notes, events, documents (with ownership)
- [ ] Internal endpoint contract for the AI service
- [ ] CI/CD (GitHub Actions)
- [ ] VPS deployment
- [ ] Telegram integration (create tasks and receive reminders from chat)

## About this repo

This code is the backend of a personal product deployed at [moonline.es](https://moonline.es) — it is not meant to be cloned and self-hosted as a generic tool. It's public so the code and technical approach can be inspected, not as a self-hosted project.

## License

No license — all rights reserved. The code is public for reading, not for reuse.
