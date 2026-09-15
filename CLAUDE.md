# CLAUDE.md — qltb-workspace

Entry point cho LLM agent làm việc trên dự án QLTB — hệ thống quản lý thiết bị.

## Cấu trúc

Đây là **mono-workspace, không phải monorepo**. Hai sub-repo độc lập git/deploy/dependency:

```
quan-ly-thiet-bi/
├── qltb-workspace/        ← bạn đang ở đây: CHỈ docs và convention, không có code
│   ├── docs/
│   │   └── rules/         ← cấu trúc bắt buộc cho backend / frontend
│   └── plans/
├── qltb-service/          ← repo riêng, NestJS 11 + Drizzle. Script DB, .env ở đây
└── qltb-web/              ← repo riêng, Next.js 16 + shadcn
```

Ba thư mục nằm **cạnh nhau**, mỗi cái một git riêng. Code, script, `.env` chỉ nằm trong `qltb-service/` và `qltb-web/` — **không đưa vào workspace**. Commit trong sub-repo là commit của repo đó.

## Đọc gì trước khi làm

| Bạn định làm gì | Đọc trước |
|---|---|
| Bất cứ việc gì | `docs/project-overview.md` |
| Backend | `docs/rules/backend-structure.md` + `docs/api-contracts.md` |
| Frontend | `docs/rules/frontend-structure.md` + `docs/api-contracts.md` |
| Đổi REST contract | `docs/api-contracts.md` — sửa cả 2 repo trong cùng một đợt, đừng lệch |
| Thêm endpoint mới | `docs/conventions.md` mục "Swagger" — mô tả tiếng Việt + ví dụ req/res là **bắt buộc**, có test ép |
| Thêm bảng / sửa schema | `docs/rules/backend-structure.md` mục "Database" |

## Điều dễ làm sai nhất

**Envelope là hợp đồng.** Mọi response REST — kể cả lỗi 500 — bọc `{ request_id, data, error }`. Web đọc `error.code` để rẽ nhánh, **không** parse `error.message`. Ngoại lệ duy nhất là `/health`.

**Field JSON giữ `snake_case`**, enum giữ `UPPER_SNAKE_CASE`. Web không map sang camelCase — lúc debug người ta so response trong DevTools với type trong code.

**Nghiệp vụ ở service, không ở controller.** Controller chỉ map DTO và gọi service. Truy vấn DB ở repository.

**Lịch sử là append-only.** `device_history` (luân chuyển, bảo trì) và `audit_logs` (khi làm tới) không `UPDATE` / `DELETE` — đặt trigger chặn ở tầng DB, không chỉ ở code.

**`actor` lấy từ token, không bao giờ từ body** (khi có auth). Thiết kế DTO ngay từ đầu không nhận `created_by` / `updated_by` từ client.

**Idempotency cho POST có side effect** — chưa có ở khung này, nhưng đừng viết endpoint theo cách sau này không gắn `Idempotency-Key` được (ví dụ dựa vào `SELECT` rồi `INSERT` thay vì unique constraint).

**Secret chỉ ở `.env` của từng repo.** `.env.example` chỉ có placeholder / giá trị dev local. Workspace không có `.env`.

## Quy ước

- Branch: `feature/{mô-tả}` → `develop` → `main`
- File: kebab-case cho TS/JS/shell
- Commit: conventional commits, tiếng Việt không dấu hoặc tiếng Anh, không nhắc tới AI
- Port dev: service `3400`, web `3401`

## Không được làm

- Commit `.env`, `.env.local`, hay bất kỳ credential nào
- Sửa `components/ui/` trong web (shadcn generated) — cần khác thì bọc ở `components/common/`
- `fetch` trực tiếp trong component — mọi lời gọi API đi qua `lib/api/`
- Thêm mã lỗi mới mà không sửa `docs/api-contracts.md` và `types/api.ts` bên web
- Trả response không bọc envelope cho endpoint nghiệp vụ
