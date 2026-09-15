# Hợp đồng REST giữa `qltb-service` và `qltb-web`

Nguồn sự thật của hợp đồng. Swagger `/docs` sinh từ code và phải khớp file này; lệch là lỗi.

## Tổng quát

| | |
|---|---|
| Base URL dev | `http://localhost:3400/api/v1` |
| Content-Type | `application/json; charset=utf-8` |
| Timestamp | RFC 3339, UTC |
| Field | `snake_case` |
| Enum | `UPPER_SNAKE_CASE` |
| Header | `X-Request-Id` — service sinh nếu client không gửi, trả lại ở response header và trong envelope |

`/health` và `/health/ready` nằm **ngoài** prefix, body trần (không envelope).

## Envelope

Mọi response, kể cả lỗi:

```json
{ "request_id": "a3f1c9e4-...", "data": { ... }, "error": null }
{ "request_id": "a3f1c9e4-...", "data": null, "error": { "code": "RESOURCE_NOT_FOUND", "message": "Không tìm thấy thiết bị", "details": { "resource": "device", "id": "..." } } }
```

Web đọc `error` trước, `data` sau. Rẽ nhánh theo `error.code`, **không** parse `error.message`.

Endpoint `204` không có body.

## Mã lỗi

| `code` | HTTP | Khi nào |
|---|---|---|
| `INVALID_PAYLOAD` | 400 | Body / query sai kiểu, thiếu field, có field lạ. `details.violations` liệt kê từng lỗi |
| `AUTHENTICATION_FAILED` | 401 | Thiếu / sai token (khi có auth) |
| `AUTHORIZATION_FAILED` | 403 | Không đủ quyền. `details.missing_permissions` |
| `RESOURCE_NOT_FOUND` | 404 | Không có bản ghi. `details.resource`, `details.id` |
| `DEVICE_CODE_CONFLICT` | 409 | Mã thiết bị đã tồn tại |
| `DEVICE_STATE_CONFLICT` | 409 | Chuyển trạng thái không hợp lệ (ví dụ thanh lý thiết bị đang `IN_USE`). `details.current_status`, `details.attempted_action` |
| `IDEMPOTENCY_KEY_CONFLICT` | 409 | Cùng key, khác body (khi có idempotency) |
| `RATE_LIMITED` | 429 | Vượt rate-limit |
| `INTERNAL_ERROR` | 500 | Lỗi không lường. `message` cố định "Lỗi hệ thống", chi tiết chỉ ở log |

Thêm mã là đổi hợp đồng: sửa bảng này, `common/errors/error-code.ts` bên service và `types/api.ts` bên web trong cùng một đợt.

## Phân trang

Cursor, không offset: `?limit=50&cursor=...`. `limit` mặc định 50, tối đa 200.

```json
{ "items": [ ... ], "next_cursor": "eyJ0cyI6..." }
```

`next_cursor` là chuỗi mờ — web không parse, không tự sinh. `null` khi hết dữ liệu.

## Thiết bị — `/devices`

### Resource `Device`

```json
{
  "device_id": "3f2b7c14-9d8e-4a55-b0c1-6e2f8a9d3b47",
  "code": "LT-0001",
  "name": "Laptop Dell Latitude 5540",
  "category_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "category_name": "Laptop",
  "brand": "Dell",
  "model": "Latitude 5540",
  "serial_number": "5CG3210XYZ",
  "status": "IN_STOCK",
  "holder_name": null,
  "holder_unit": null,
  "purchased_at": "2026-01-15",
  "warranty_until": "2029-01-15",
  "purchase_price": 25000000,
  "notes": null,
  "created_at": "2026-09-15T06:30:00.000Z",
  "updated_at": "2026-09-15T06:30:00.000Z"
}
```

`status`: `IN_STOCK` · `IN_USE` · `UNDER_MAINTENANCE` · `DISPOSED`. Máy trạng thái ở [`project-overview.md`](project-overview.md).

### Endpoint

| Method | Path | Việc | Ghi chú |
|---|---|---|---|
| `GET` | `/devices` | Danh sách | Query: `limit`, `cursor`, `status`, `category_id`, `q` (tìm theo `code` / `name` / `serial_number`) |
| `GET` | `/devices/{device_id}` | Chi tiết | 404 `RESOURCE_NOT_FOUND` |
| `POST` | `/devices` | Đăng ký thiết bị mới | 201. Body: `code`, `name`, `category_id`, `brand?`, `model?`, `serial_number?`, `purchased_at?`, `warranty_until?`, `purchase_price?`, `notes?`. 409 `DEVICE_CODE_CONFLICT` |
| `PATCH` | `/devices/{device_id}` | Sửa thông tin hồ sơ | **Không** đổi được `status` / `holder_*` qua đây — đi qua action bên dưới |
| `POST` | `/devices/{device_id}/assign` | Cấp phát | *chưa có* — `IN_STOCK → IN_USE`, ghi `device_history` |
| `POST` | `/devices/{device_id}/return` | Thu hồi | *chưa có* — `IN_USE → IN_STOCK` |
| `POST` | `/devices/{device_id}/dispose` | Thanh lý | *chưa có* — chỉ từ `IN_STOCK` / `UNDER_MAINTENANCE` |
| `GET` | `/devices/{device_id}/history` | Lịch sử | *chưa có* — cursor, mới nhất trước |

## Loại thiết bị — `/device-categories`

*Chưa có.* `GET` danh sách, `POST` tạo. Resource: `category_id`, `code`, `name`, `description`.

## Còn phải chốt

- Auth: access token qua `Authorization: Bearer` + refresh cookie httpOnly (như eTB4G), hay session cookie đơn giản hơn vì đây là hệ nội bộ? **Chốt trước khi viết lớp auth ở cả hai repo.**
- Có multi-tenant (`tenant_id`) hay không. Nếu có thì mọi bảng nghiệp vụ cần cột đó ngay từ migration đầu — thêm sau đau hơn nhiều.
