# Rules — cấu trúc backend (`qltb-service`)

## Stack

| | |
|---|---|
| Framework | NestJS 11 |
| Node | 22 LTS |
| ORM | Drizzle |
| DB | PostgreSQL 16 — database `qltb`, local |
| Validation | `class-validator` + `class-transformer`, `whitelist` + `forbidNonWhitelisted` |
| Docs | `@nestjs/swagger` ở `/docs`, có test ép |

## Cây thư mục

```
src/
├── main.ts                 # bootstrap: prefix /api/v1, helmet, CORS, swagger
├── app.module.ts           # đăng ký pipe / interceptor / filter toàn cục
├── swagger.ts              # cấu hình Swagger, tách ra để test dựng được
├── common/                 # dùng chung: envelope, filter, decorator, logger
│   ├── decorators/
│   ├── dto/                # envelope.dto, pagination.dto
│   ├── errors/             # error-code (bảng mã hợp đồng), app.exception
│   ├── filters/
│   ├── interceptors/
│   ├── logger/
│   ├── swagger/            # api-envelope (decorator ví dụ có envelope), example-values
│   └── request-context.ts
├── config/                 # configuration.ts (đọc env), env.validation.ts (fail-fast)
├── db/
│   ├── drizzle.module.ts   # một Pool duy nhất, @Global
│   ├── migrate.ts
│   ├── schema/             # Drizzle schema theo cụm (docs/project-overview.md):
│   │   ├── system.ts       #   enterprises · users · roles · permissions · users_roles · roles_permissions · audit_logs
│   │   ├── device.ts       #   devices · warranties · device_exchanges
│   │   ├── quota.ts        #   device_quotas · quota_grants · quota_allocations · usage_logs
│   │   └── alert.ts        #   alerts · notifications
│   ├── migrations/         # 0000 sinh bởi drizzle-kit; 0001 viết tay: CHECK, partial unique, trigger
│   └── seed.ts             # quyền (permission.catalog) · 3 vai trò · admin đầu tiên
└── modules/                # nghiệp vụ — một thư mục một nhóm endpoint của đặc tả
    ├── health/
    ├── permission/         # permission.catalog.ts — danh mục quyền, nguồn sự thật
    └── device/
        ├── device.module.ts
        ├── device.controller.ts     # route + map DTO, không nghiệp vụ
        ├── device.service.ts        # nghiệp vụ, máy trạng thái
        ├── device.repository.ts     # truy vấn Drizzle
        └── dto/
            ├── device.dto.ts        # class-validator + @ApiProperty
            └── device.examples.ts   # ví dụ Swagger
```

## Đặt code ở đâu

| Việc | Chỗ |
|---|---|
| Route REST, mapping DTO | `modules/<x>/<x>.controller.ts` |
| Nghiệp vụ, kiểm tra chuyển trạng thái | `modules/<x>/<x>.service.ts` |
| Truy vấn DB | `modules/<x>/<x>.repository.ts` |
| Schema bảng | `db/schema/<cụm>.ts` |
| Thứ dùng ở ≥2 module | `common/` |
| Ví dụ Swagger | `modules/<x>/dto/<x>.examples.ts` |

## Request pipeline REST

```
(Guard — khi có auth)
  → ValidationPipe (whitelist: true, forbidNonWhitelisted: true, transform: true)
    → Controller → Service → Repository
      → ResponseInterceptor (bọc envelope request_id/data/error)
        → AllExceptionsFilter (map sang error code chuẩn)
```

`/health` nằm **ngoài** prefix và **ngoài** guard, gắn `@NoEnvelope()`.

## Lỗi

- Ném `AppException` với mã từ `ErrorCode`, **không** ném `BadRequestException` / `NotFoundException` trần — filter sẽ phải đoán mã, đoán sai là web rẽ nhánh sai.
- Lỗi 500: `message` cố định "Lỗi hệ thống", stack chỉ ở log. Lỗi driver DB hay lộ tên bảng, tên cột.
- Thêm mã mới = sửa `docs/api-contracts.md` + `error-code.ts` + `types/api.ts` bên web.

## Database

### Ràng buộc bắt buộc enforce ở DB, không chỉ ở code

- **Append-only**: `quota_grants` · `quota_allocations` · `usage_logs` · `audit_logs`. Trigger chặn `UPDATE` / `DELETE` ở migration viết tay. Code sai còn sửa được; dữ liệu mất thì không.
- **Unique** trên `devices.serial_number`, `enterprises.code`, `users.username`, `(usage_logs.device_id, client_ref)`. Kiểm bằng unique constraint + bắt lỗi `23505` → mã 409 tương ứng, **không** `SELECT` rồi `INSERT` — hai request song song lọt cả hai.
- **Bất biến sản lượng** `quota_remaining = quota_total − quota_used ≥ 0` là `CHECK` ở DB. Mọi thay đổi sản lượng: một transaction ghi lịch sử + cập nhật projection.
- **Partial unique**: một bảo hành `ACTIVE` mỗi máy; một yêu cầu đổi trả `PENDING` mỗi máy.
- `status` là `text` có `CHECK` liệt kê giá trị hợp lệ. Không dùng `pg enum` — đổi enum trong Postgres là migration khó chịu. CHECK `devices_enterprise_by_status_check` ép: trong kho thì không có doanh nghiệp, đang gán thì phải có.
- Mọi bảng có `created_at` / `updated_at` `timestamptz NOT NULL`; trigger `touch_updated_at` tự cập nhật.
- `used_at` (giờ thiết bị) ≠ `received_at` (giờ server) trên `usage_logs` — hai cột riêng, cả hai `NOT NULL`.

### Migration

- `npm run db:generate` sinh SQL từ schema. **drizzle-kit không sinh trigger** — trigger viết tay ở file riêng và thêm vào `meta/_journal.json`.
- Sau mỗi lần generate, kiểm tra migration mới không drop trigger cũ.
- `npm run db:migrate` chạy migrator của drizzle-orm (đọc journal, chạy cả file sinh lẫn file viết tay).

### Trạng thái thiết bị

Máy trạng thái nằm ở **một chỗ** — `modules/device/device-state.ts` (`nextStatus`). Mọi đường đổi `status` (assign / unassign / lock / unlock / exchange / retire) đi qua đó, và `repository.transition()` kiểm `from_status` ở `WHERE` để hai request song song không cùng thắng. Đổi `status` bằng `PUT` hồ sơ là lỗi thiết kế.

### Phạm vi doanh nghiệp

Repository nhận `scope` (`enterprise_id` của người gọi + chi nhánh con, hoặc `null` = toàn hệ thống) từ service, service lấy từ token. Không bao giờ lấy phạm vi từ query string.

## Swagger

Mọi endpoint phải có `summary` + `description` tiếng Việt và ví dụ request/response bọc envelope — luật đầy đủ ở [`../conventions.md`](../conventions.md). `test/swagger.spec.ts` ép.

Dùng `ApiEnvelopeResponse` / `ApiEnvelopeError` / `ApiNotFoundError` từ `common/swagger/api-envelope.ts`. **Đừng** khai `@ApiResponse({ type: SomeClass })` rồi coi là xong — kiểu trả về của controller là dữ liệu trần, envelope do interceptor thêm lúc chạy.

## Log

- Structured JSON, một dòng một sự kiện, qua `AppLogger`.
- Mọi log có `request_id`; liên quan thiết bị thêm `device_id`.
- **Không log** mật khẩu, token, secret. `redact()` trong logger là lưới cuối, không phải giấy phép ném cả object vào log.

## Health

`GET /health` — liveness, luôn 200 khi tiến trình sống.
`GET /health/ready` — readiness, 503 khi DB không `select 1` được.
