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
| **Đặc tả gốc**: quan hệ dữ liệu + danh sách API (từ `qltb.docx`) | [`docs/spec/qltb-spec.md`](docs/spec/qltb-spec.md) |
| Tổng quan dự án, nghiệp vụ | [`docs/project-overview.md`](docs/project-overview.md) |
| Quy ước branch, commit, đặt tên, Swagger | [`docs/conventions.md`](docs/conventions.md) |
| Contract REST giữa service và web | [`docs/api-contracts.md`](docs/api-contracts.md) |
| Rules structure cho backend | [`docs/rules/backend-structure.md`](docs/rules/backend-structure.md) |
| Rules structure cho frontend | [`docs/rules/frontend-structure.md`](docs/rules/frontend-structure.md) |
| Kế hoạch triển khai | [`plans/`](plans/) |

## Trạng thái

**Đủ chức năng theo đặc tả** (86 endpoint, 18 màn web). Cột ✅ trong [`docs/api-contracts.md`](docs/api-contracts.md); các điểm đặc tả chưa nói được chốt ở mục "Đã chốt" cuối file đó.

| | Có gì |
|---|---|
| `qltb-service` | Auth (JWT + refresh cookie xoay, quên/đặt lại mật khẩu), phân quyền theo ma trận trong DB, phạm vi doanh nghiệp + chi nhánh, idempotency, audit append-only; users / roles / enterprises / devices (gán, thu hồi, khoá, API key) / warranties / quota (cấp, phân bổ, lượt dùng từ thiết bị) / alerts + notifications (job cron) / exchanges / dashboard / reports xlsx / audit-logs. 34 test |
| `qltb-web` | Đăng nhập, tổng quan có biểu đồ, và màn cho từng nhóm: thiết bị (chi tiết + tab), doanh nghiệp (chi tiết + tab), người dùng, vai trò (ma trận quyền), sản lượng, bảo hành, đổi trả, cảnh báo, thông báo, nhật ký, báo cáo, tài khoản |

Chưa có: kênh gửi email/SMS, báo cáo PDF, CI/CD, rate-limit.
