# qltb-workspace

Workspace của **QLTB** — hệ thống quản lý thiết bị: hồ sơ thiết bị, phân bổ cho đơn vị / người dùng, bảo trì, và lịch sử luân chuyển.

## Đây không phải monorepo

Workspace này chỉ chứa **docs, convention và scripts**. Hai repo code nằm **cạnh** nó (`../qltb-service`, `../qltb-web`), độc lập về git, deploy và dependency. Commit trong `qltb-service/` là commit của repo đó, không liên quan workspace.

| Repo | Vai trò | Stack | Port dev |
|---|---|---|---|
| `qltb-service` | Backend REST API | NestJS 11 · Drizzle · PostgreSQL 16 | 3400 |
| `qltb-web` | Web quản trị | Next.js 16 · shadcn/ui · Tailwind v4 | 3401 |

## Bắt đầu

```bash
cp .env.example .env         # kiểm tra port và bộ DB_*
./scripts/db-setup.sh        # bật Postgres local, tạo role + database
./scripts/install-all.sh     # npm install cho từng repo
./scripts/db-migrate.sh      # chạy migration
./scripts/start-all.sh       # chạy service + web
```

Cần Node 22 (`.nvmrc` ở mỗi repo) và PostgreSQL 16 chạy local.

`.env` ở workspace và `.env` ở từng repo **không commit**. Bộ giá trị dev mặc định trong `.env.example` chỉ dùng cho máy local.

## Scripts

| Lệnh | Việc |
|---|---|
| `./scripts/db-setup.sh` | Bật `postgresql`, tạo role `DB_USER` và database `DB_NAME` nếu chưa có |
| `./scripts/db-migrate.sh` | `npm run db:migrate` trong service |
| `./scripts/install-all.sh` | `npm install` / `npm ci` cho từng repo |
| `./scripts/start-all.sh` | Chạy service + web, log vào `scripts/logs/` |
| `./scripts/start-service.sh` · `start-web.sh` | Chạy riêng từng cái |
| `./scripts/stop-all.sh` | Dừng theo PID đã ghi |

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
