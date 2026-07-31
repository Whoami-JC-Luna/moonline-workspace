-- ============================================================
-- V1__init_schema.sql
-- Initial schema for Moonline Workspace
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "vector";     -- pgvector, for conversation_summary.embedding

-- Enums
CREATE TYPE user_role AS ENUM ('USER');
CREATE TYPE plan_type AS ENUM ('FREE');
CREATE TYPE task_status AS ENUM ('PENDING', 'IN_PROGRESS', 'DONE');
CREATE TYPE task_priority AS ENUM ('LOW', 'MEDIUM', 'HIGH');
CREATE TYPE chat_sender AS ENUM ('USER', 'ASSISTANT');

-- ============================================================
-- app_user
-- ============================================================
CREATE TABLE app_user (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username            VARCHAR(100) NOT NULL,
    first_name          VARCHAR(50)  NOT NULL,
    last_name           VARCHAR(50)  NOT NULL,
    email               VARCHAR(100) NOT NULL,
    password            VARCHAR(255) NOT NULL,
    birth_date          DATE,
    role                user_role    NOT NULL DEFAULT 'USER',
    verified             BOOLEAN     NOT NULL DEFAULT FALSE,
    verification_code   VARCHAR(100),
    avatar_url          TEXT,
    biography           TEXT,
    last_login_at       TIMESTAMP,
    created_at          TIMESTAMP    NOT NULL DEFAULT now(),
    updated_at          TIMESTAMP    NOT NULL DEFAULT now(),
    CONSTRAINT uq_app_user_email    UNIQUE (email),
    CONSTRAINT uq_app_user_username UNIQUE (username)
);

-- ============================================================
-- user_plan (1:1 with app_user)
-- ============================================================
CREATE TABLE user_plan (
    user_id                 UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
    plan                    plan_type NOT NULL DEFAULT 'FREE',
    tokens_month_max        INTEGER   NOT NULL DEFAULT 100000,
    storage_max_bytes       BIGINT    NOT NULL DEFAULT 2147483648, -- 2GB
    reset_at                TIMESTAMP NOT NULL DEFAULT now(),
    created_at              TIMESTAMP NOT NULL DEFAULT now(),
    updated_at              TIMESTAMP NOT NULL DEFAULT now()
);

-- ============================================================
-- assistant
-- ============================================================
CREATE TABLE assistant (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_assistant_user_id ON assistant(user_id);

-- ============================================================
-- assistant_config (1:1 with assistant)
-- ============================================================
CREATE TABLE assistant_config (
    id                   BIGSERIAL PRIMARY KEY,
    assistant_id         UUID NOT NULL REFERENCES assistant(id) ON DELETE CASCADE,
    personality_prompt   TEXT,
    created_at           TIMESTAMP NOT NULL DEFAULT now(),
    updated_at           TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_assistant_config_assistant UNIQUE (assistant_id)
);

-- ============================================================
-- conversation
-- ============================================================
CREATE TABLE conversation (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assistant_id  UUID NOT NULL REFERENCES assistant(id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    title         VARCHAR(200),
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_conversation_assistant_id ON conversation(assistant_id);
CREATE INDEX idx_conversation_user_id ON conversation(user_id);

-- ============================================================
-- chat_message
-- ============================================================
CREATE TABLE chat_message (
    id               BIGSERIAL PRIMARY KEY,
    conversation_id  UUID NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
    content          TEXT NOT NULL,
    sender           chat_sender NOT NULL,
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_chat_message_conversation_id ON chat_message(conversation_id);

-- ============================================================
-- conversation_summary (RAG memory)
-- ============================================================
CREATE TABLE conversation_summary (
    id               BIGSERIAL PRIMARY KEY,
    conversation_id  UUID NOT NULL REFERENCES conversation(id) ON DELETE CASCADE,
    summary_content  TEXT NOT NULL,
    embedding        vector(1536),
    generated_at     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_conversation_summary_conversation_id ON conversation_summary(conversation_id);

-- ============================================================
-- document
-- ============================================================
CREATE TABLE document (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    assistant_id  UUID REFERENCES assistant(id) ON DELETE CASCADE,
    title         VARCHAR(200) NOT NULL,
    path          TEXT NOT NULL,
    size_bytes    INTEGER NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMP
);

CREATE INDEX idx_document_user_id ON document(user_id);
CREATE INDEX idx_document_assistant_id ON document(assistant_id);

-- ============================================================
-- note
-- ============================================================
CREATE TABLE note (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    assistant_id  UUID REFERENCES assistant(id) ON DELETE CASCADE,
    content       TEXT NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMP
);

CREATE INDEX idx_note_user_id ON note(user_id);
CREATE INDEX idx_note_assistant_id ON note(assistant_id);

-- ============================================================
-- event
-- ============================================================
CREATE TABLE event (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    assistant_id  UUID REFERENCES assistant(id) ON DELETE CASCADE,
    title         VARCHAR(200) NOT NULL,
    description   TEXT,
    event_date    DATE NOT NULL,
    event_time    TIME,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMP
);

CREATE INDEX idx_event_user_id ON event(user_id);
CREATE INDEX idx_event_assistant_id ON event(assistant_id);

-- ============================================================
-- task
-- ============================================================
CREATE TABLE task (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    assistant_id  UUID REFERENCES assistant(id) ON DELETE CASCADE,
    title         VARCHAR(150) NOT NULL,
    description   TEXT,
    status        task_status   NOT NULL DEFAULT 'PENDING',
    priority      task_priority NOT NULL DEFAULT 'MEDIUM',
    due_date      DATE,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_user_id ON task(user_id);
CREATE INDEX idx_task_assistant_id ON task(assistant_id);

-- ============================================================
-- tag (private per user)
-- ============================================================
CREATE TABLE tag (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    name        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT uq_tag_user_name UNIQUE (user_id, name)
);

CREATE INDEX idx_tag_user_id ON tag(user_id);

-- ============================================================
-- document_tag / note_tag (join tables)
-- ============================================================
CREATE TABLE document_tag (
    document_id  UUID NOT NULL REFERENCES document(id) ON DELETE CASCADE,
    tag_id       UUID NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
    PRIMARY KEY (document_id, tag_id)
);

CREATE TABLE note_tag (
    note_id  UUID NOT NULL REFERENCES note(id) ON DELETE CASCADE,
    tag_id   UUID NOT NULL REFERENCES tag(id) ON DELETE CASCADE,
    PRIMARY KEY (note_id, tag_id)
);

-- ============================================================
-- integration
-- ============================================================
CREATE TABLE integration (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    assistant_id    UUID NOT NULL REFERENCES assistant(id) ON DELETE CASCADE,
    type            VARCHAR(100) NOT NULL,
    encrypted_token TEXT NOT NULL, -- encrypted at application level, never plain text
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    updated_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_integration_user_id ON integration(user_id);
CREATE INDEX idx_integration_assistant_id ON integration(assistant_id);

-- ============================================================
-- ai_usage
-- ============================================================
CREATE TABLE ai_usage (
    id                 BIGSERIAL PRIMARY KEY,
    user_id            UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
    assistant_id       UUID NOT NULL REFERENCES assistant(id) ON DELETE CASCADE,
    prompt_tokens      INTEGER NOT NULL,
    completion_tokens  INTEGER NOT NULL,
    total_tokens       INTEGER NOT NULL,
    created_at         TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_ai_usage_user_id ON ai_usage(user_id);
CREATE INDEX idx_ai_usage_assistant_id ON ai_usage(assistant_id);
