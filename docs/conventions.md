# Quy ước làm việc

## Branch

```
feature/{mô-tả-ngắn}   →  develop  →  main
hotfix/{mô-tả}         →  main
```

| Branch | Ý nghĩa |
|---|---|
| `main` | Production — không push thẳng, chỉ merge |
| `develop` | **Default branch.** Nhánh tích hợp |

Vòng đời: tạo branch → làm → MR → merge → xoá branch.

## Commit

Conventional commits, không nhắc tới AI trong message.

```
feat(device): them API cap phat thiet bi
fix(device): khong cho thanh ly thiet bi dang IN_USE
chore(deps): nang drizzle-orm
docs: bo sung api-contracts cho device_history
```

Scope theo module lớn: `device` · `category` · `history` · `maintenance` · `auth` · `report` · `system` · `ci` · `docs`.

## Đặt tên file

| Loại | Quy ước | Ví dụ |
|---|---|---|
| TS / JS / shell | kebab-case | `device-history.repository.ts` |
| React component | PascalCase cho tên component, kebab-case cho file | `device-table.tsx` export `DeviceTable` |
| NestJS | theo chuẩn Nest | `device.controller.ts`, `device.service.ts`, `device.module.ts` |
| Drizzle schema | theo cụm | `system.ts`, `device.ts` |
| Route Next.js | tiếng Việt không dấu, kebab-case | `app/(dashboard)/thiet-bi/page.tsx` |

Tên dài mà tự mô tả tốt hơn tên ngắn khó đoán — file name là thứ agent đọc đầu tiên khi grep.

## Đặt tên trong JSON

- Field trong REST giữ `snake_case`: `device_id`, `purchased_at`, `holder_name`.
- Enum `UPPER_SNAKE_CASE`: `IN_STOCK`, `UNDER_MAINTENANCE`.
- Timestamp RFC 3339 UTC: `2026-09-15T06:30:00.000Z`. Web tự đổi sang giờ Việt Nam khi hiển thị.
- Web **không** map sang camelCase.

## Kích thước file

Quá **200 dòng** thì cân nhắc tách. Không phải luật cứng, nhưng file 600 dòng là dấu hiệu đang gộp nhiều việc. Không áp dụng cho markdown, file cấu hình, migration sinh tự động.

## Secret

- Chỉ nằm ở `.env` (local). **Không bao giờ commit**
- `.env.example` chỉ có placeholder hoặc giá trị dev local vô hại
- Trước commit đầu ở repo mới: `git ls-files | grep -iE '\.env$|secret|credential|\.pem$|\.key$'` phải rỗng

## Swagger — luật, không phải khuyến nghị

`/docs` của `qltb-service` là tài liệu cho người làm web và cho người tích hợp về sau. Họ không đọc TypeScript.

| Luật | |
|---|---|
| Mọi endpoint có `@ApiOperation` với `summary` **và** `description` **tiếng Việt** | Không có ngoại lệ, kể cả `/health` |
| Mọi endpoint có **ví dụ request và ví dụ response** | Người ta đọc ví dụ trước, đọc schema sau |
| Ví dụ response **bọc envelope** `{ request_id, data, error }` | Đó là thứ client thực sự nhận; ví dụ trần là ví dụ sai |
| Ví dụ request và response của cùng endpoint **nói về cùng một bản ghi** | Hai ví dụ lệch nhau bắt người đọc tự đoán |
| Nêu cả **mã lỗi** hay gặp, kèm `error.code` cụ thể | Máy đọc `code`, không parse `message` |
| **Không dùng `@ApiExcludeController`** | Ẩn khỏi tài liệu không bảo vệ được endpoint |

`description` phải nói điều người gọi **chưa biết**: hệ quả phụ, thứ tự thao tác không đảo được, cái bẫy. Chép lại tên hàm thì thà không viết.

Luật này **ép bằng test**: `test/swagger.spec.ts` dựng tài liệu thật rồi kiểm từng điều trên, chạy trong `npm test` và không cần database. Thêm endpoint mà quên mô tả là test đỏ ngay.

Hạ tầng có sẵn, dùng lại: `common/swagger/api-envelope.ts` (`ApiEnvelopeResponse`, `ApiEnvelopeError`, `ApiNotFoundError`) và `common/swagger/example-values.ts` (bộ id dùng chung). Ví dụ để ở `dto/<module>.examples.ts`, không nhét vào controller.

> Swagger **không** phải nguồn sự thật của hợp đồng — nó sinh từ code. Nguồn sự thật là [`api-contracts.md`](api-contracts.md). Hai bên lệch nhau là **một lỗi cần sửa**.

## Plan

```
plans/{YYMMDD-HHMM}-{slug}/
├── plan.md                 # overview, dưới 80 dòng
├── phase-01-....md
└── ...
plans/reports/              # brainstorm, research
```

## Trước khi mở MR

- [ ] Lint sạch (`npm run lint` ở web, `npm run typecheck` ở cả hai)
- [ ] Test pass — không bỏ qua test hỏng để cho build xanh
- [ ] Thêm endpoint thì có `summary` + `description` tiếng Việt + ví dụ req/res
- [ ] Không commit secret
- [ ] Đổi REST contract thì đã sửa `docs/api-contracts.md`, `types/` bên web, và cả hai repo
- [ ] Đổi schema DB thì có migration, và migration không làm mất trigger append-only
- [ ] Branch đã rebase/merge `develop` mới nhất
