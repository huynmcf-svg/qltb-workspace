# qltb-workspace

Workspace của **QLTB** — hệ thống quản lý thiết bị: hồ sơ thiết bị, phân bổ cho đơn vị / người dùng, bảo trì, và lịch sử luân chuyển.

## Đây không phải monorepo

Workspace này chỉ chứa **docs, convention và scripts**. Hai repo code nằm **cạnh** nó (`../qltb-service`, `../qltb-web`), độc lập về git, deploy và dependency. Commit trong `qltb-service/` là commit của repo đó, không liên quan workspace.

| Repo | Vai trò | Stack | Port dev |
|---|---|---|---|
| `qltb-service` | Backend REST API | NestJS 11 · Drizzle · PostgreSQL 16 | 3400 |
| `qltb-web` | Web quản trị | Next.js 16 · shadcn/ui · Tailwind v4 | 3401 |

## Bắt đầu

Workspace này **không có code, không có `.env`, không có script** — chỉ tài liệu và quy ước. Mỗi repo tự chạy được:

```bash
# Backend
cd ../qltb-service
cp .env.example .env      # Postgres local: host/port/user/pass/db
npm install
npm run db:setup          # bật postgresql, tạo role + database (cần sudo)
npm run db:migrate
npm run db:seed           # loại thiết bị mẫu
npm run start:dev         # http://localhost:3400 — swagger /docs

# Frontend
cd ../qltb-web
cp .env.example .env.local
npm install
npm run dev               # http://localhost:3401
```

Cần Node 22 (`.nvmrc` ở mỗi repo) và PostgreSQL 16 chạy local. `.env` / `.env.local` **không commit**.

## Tài liệu

| Tài liệu | Ở đâu |
|---|---|
| Tổng quan dự án, nghiệp vụ | [`docs/project-overview.md`](docs/project-overview.md) |
| Quy ước branch, commit, đặt tên, Swagger | [`docs/conventions.md`](docs/conventions.md) |
| Contract REST giữa service và web | [`docs/api-contracts.md`](docs/api-contracts.md) |
| Rules structure cho backend | [`docs/rules/backend-structure.md`](docs/rules/backend-structure.md) |
| Rules structure cho frontend | [`docs/rules/frontend-structure.md`](docs/rules/frontend-structure.md) |
| Kế hoạch triển khai | [`plans/`](plans/) |

## Trạng thái

**Khung dự án: đã dựng.**

| | Có gì |
|---|---|
| `qltb-service` | Pipeline REST (envelope `{ request_id, data, error }`, ValidationPipe, exception filter, Swagger `/docs` có test ép mô tả tiếng Việt), Drizzle + migration, `/health`, module `device` mẫu (list / get / create) |
| `qltb-web` | Next.js App Router + shadcn/ui + Tailwind v4, lớp gọi API duy nhất `lib/api/client.ts`, TanStack Query, màn danh sách thiết bị mẫu |

Chưa có: xác thực & phân quyền, idempotency, audit log, CI/CD. Xem [`plans/`](plans/).
