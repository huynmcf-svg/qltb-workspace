# Hợp đồng REST giữa `qltb-service` và `qltb-web`

Nguồn sự thật của hợp đồng. Danh sách endpoint lấy từ [`spec/qltb-spec.md`](spec/qltb-spec.md); file này thêm hình dạng request / response, mã lỗi và quy tắc. Swagger `/docs` sinh từ code và phải khớp file này; lệch là lỗi.

Cột **Trạng thái**: ✅ đã có · ⬜ chưa làm.

## Tổng quát

| | |
|---|---|
| Base URL dev | `http://localhost:3400/api/v1` |
| Content-Type | `application/json; charset=utf-8` |
| Timestamp | RFC 3339, UTC. Ngày không giờ: `YYYY-MM-DD` |
| Field | `snake_case` |
| Enum | `UPPER_SNAKE_CASE` |
| Id | UUID. Đặc tả viết `:id`, hợp đồng dùng tên rõ: `{device_id}`, `{enterprise_id}`… |
| Header | `X-Request-Id` — service sinh nếu client không gửi, trả lại ở header và trong envelope |
| Auth | `Authorization: Bearer <access_token>` cho mọi endpoint trừ `/auth/login`, `/auth/forgot-password`, `/auth/reset-password`, `/auth/refresh-token`, `/health` |

`/health`, `/health/ready` nằm **ngoài** prefix, body trần.

## Envelope

Mọi response, kể cả lỗi:

```json
{ "request_id": "a3f1c9e4-...", "data": { ... }, "error": null }
{ "request_id": "a3f1c9e4-...", "data": null, "error": { "code": "RESOURCE_NOT_FOUND", "message": "Không tìm thấy thiết bị", "details": { "resource": "device", "id": "..." } } }
```

Web đọc `error` trước, `data` sau. Rẽ nhánh theo `error.code`, **không** parse `error.message`. Endpoint `204` không có body.

## Mã lỗi

| `code` | HTTP | Khi nào |
|---|---|---|
| `INVALID_PAYLOAD` | 400 | Body / query sai kiểu, thiếu field, có field lạ. `details.violations` |
| `AUTHENTICATION_FAILED` | 401 | Thiếu / sai token, sai mật khẩu (không nói rõ sai user hay pass) |
| `AUTHORIZATION_FAILED` | 403 | Không đủ quyền hoặc ngoài phạm vi doanh nghiệp. `details.missing_permissions` |
| `RESOURCE_NOT_FOUND` | 404 | Không có bản ghi, **hoặc** thuộc doanh nghiệp khác (cố ý gộp để không lộ id) |
| `DEVICE_SERIAL_CONFLICT` | 409 | Serial đã tồn tại |
| `DEVICE_STATE_CONFLICT` | 409 | Chuyển trạng thái thiết bị không hợp lệ. `details.current_status`, `details.attempted_action` |
| `ENTERPRISE_CODE_CONFLICT` | 409 | Mã doanh nghiệp đã tồn tại |
| `USERNAME_CONFLICT` | 409 | Tên đăng nhập đã tồn tại |
| `EXCHANGE_STATE_CONFLICT` | 409 | Duyệt / từ chối / sửa yêu cầu đổi trả không còn `PENDING` |
| `IDEMPOTENCY_KEY_CONFLICT` | 409 | Cùng key, khác body |
| `ENTERPRISE_USER_LIMIT` | 422 | Doanh nghiệp đã đủ `max_users` tài khoản |
| `QUOTA_INSUFFICIENT` | 422 | Phân bổ / trừ vượt sản lượng còn lại. `details.remaining`, `details.requested` |
| `DEVICE_LOCKED` | 422 | Ghi lượt sử dụng vào máy đang `LOCKED` |
| `RATE_LIMITED` | 429 | Vượt rate-limit |
| `INTERNAL_ERROR` | 500 | Lỗi không lường. `message` cố định "Lỗi hệ thống" |

Thêm mã là đổi hợp đồng: sửa bảng này, `common/errors/error-code.ts` bên service và `types/api.ts` bên web trong cùng một đợt.

## Phân trang & lọc

Cursor, không offset: `?limit=50&cursor=...`. `limit` mặc định 50, tối đa 200.

```json
{ "items": [ ... ], "next_cursor": "eyJ0cyI6..." }
```

`next_cursor` mờ — web không parse, không tự sinh. `null` khi hết. Tham số lọc chung: `q` (tìm gần đúng), `from` / `to` (khoảng thời gian, RFC 3339), `enterprise_id`.

## Phạm vi doanh nghiệp

Token mang `enterprise_id` (NULL = quản trị hệ thống). Mọi endpoint danh sách / chi tiết tự lọc theo doanh nghiệp của người gọi **và chi nhánh con**; `?enterprise_id=` chỉ thu hẹp thêm, không mở rộng. Gọi vào bản ghi ngoài phạm vi → 404.

---

## 1. Auth — `/auth`

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `POST` | `/auth/login` | Đăng nhập | Body `{ username, password }` → `LoginResponse` |
| ✅ | `POST` | `/auth/forgot-password` | Quên mật khẩu | Body `{ username }` hoặc `{ email }`. **Luôn 204** dù có tài khoản hay không |
| ✅ | `POST` | `/auth/reset-password` | Đặt lại mật khẩu | Body `{ token, new_password }`. 401 khi token sai / hết hạn |
| ✅ | `GET` | `/auth/me` | Người đang đăng nhập | → `SessionUser` kèm `roles[]`, `permissions[]` |
| ✅ | `PUT` | `/auth/change-password` | Đổi mật khẩu | Body `{ current_password, new_password }` → 204. Sai `current_password` → 401 |
| ✅ | `PUT` | `/auth/profile` | Sửa hồ sơ cá nhân | Body `{ full_name?, email?, phone? }` → `SessionUser` |
| ✅ | `POST` | `/auth/refresh-token` | Cấp access token mới | Refresh token trong cookie httpOnly → `{ access_token, expires_in }` |

```json
// LoginResponse
{
  "access_token": "eyJhbGciOi...",
  "expires_in": 900,
  "user": {
    "user_id": "...", "username": "admin", "full_name": "Nguyễn Văn A",
    "enterprise_id": null, "enterprise_name": null,
    "email": null, "phone": null,
    "roles": ["SYSTEM_ADMIN"], "permissions": ["device.read", "device.assign", "..."],
    "must_change_password": false
  }
}
```

Web giữ `access_token` **trong bộ nhớ**, không `localStorage`. Sau F5 web gọi `refresh-token` một lần để dựng lại phiên. Guard nạp lại quyền từ DB mỗi request — khoá tài khoản / đình chỉ doanh nghiệp có hiệu lực ngay, không đợi token hết hạn. Sai mật khẩu 5 lần → khoá tạm 15 phút.

## 2. User & Role — `/users`, `/roles`, `/permissions`

### Resource `User`

```json
{
  "user_id": "0e53c527-...", "username": "ketoan.dongdanh", "email": "kt@vpcc.vn",
  "full_name": "Trần Thị B", "phone": "+84912345678",
  "enterprise_id": "7c9e6679-...", "enterprise_name": "VPCC Đông Anh",
  "roles": [{ "role_id": "...", "code": "ENTERPRISE_USER", "name": "Nhân viên doanh nghiệp" }],
  "status": "ACTIVE", "must_change_password": false,
  "last_login_at": "2026-09-15T02:48:10.000Z",
  "created_at": "...", "updated_at": "..."
}
```

`status`: `ACTIVE` · `DISABLED`.

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/users` | Danh sách | Lọc `enterprise_id`, `role_code`, `status`, `q` (username / full_name / email) |
| ✅ | `POST` | `/users` | Tạo tài khoản | Body `{ username, full_name, email?, phone?, enterprise_id?, role_ids[], password? }`. Không gửi `password` thì server sinh và trả **một lần** ở `data.temporary_password`. 422 `ENTERPRISE_USER_LIMIT`, 409 `USERNAME_CONFLICT` |
| ✅ | `GET` | `/users/{user_id}` | Chi tiết | |
| ✅ | `PUT` | `/users/{user_id}` | Sửa | `full_name`, `email`, `phone`. Không đổi `username` |
| ✅ | `PUT` | `/users/{user_id}/disable` | Khoá | Body `{ disabled: true \| false }` — một endpoint cho cả khoá và mở. Khoá thì huỷ mọi phiên |
| ✅ | `PUT` | `/users/{user_id}/roles` | Gán vai trò | Body `{ role_ids: [] }` — **thay thế** toàn bộ, không cộng dồn |
| ✅ | `DELETE` | `/users/{user_id}` | Xoá | Soft delete (`deleted_at`). Không xoá được chính mình |
| ✅ | `GET` | `/roles` | Danh sách vai trò | |
| ✅ | `POST` | `/roles` | Tạo | `{ code, name, description?, permission_codes[] }` |
| ✅ | `GET` | `/roles/{role_id}` | Chi tiết | kèm `permissions[]` |
| ✅ | `PUT` | `/roles/{role_id}` | Sửa | `name`, `description`. `is_system = true` thì 403 |
| ✅ | `GET` | `/roles/{role_id}/permissions` | Quyền của vai trò | `{ items: Permission[] }` |
| ✅ | `PUT` | `/roles/{role_id}/permissions` | Cập nhật quyền | `{ permission_codes: [] }` — thay thế toàn bộ |
| ✅ | `DELETE` | `/roles/{role_id}` | Xoá | 422 nếu còn người dùng đang gán |
| ✅ | `GET` | `/permissions` | Toàn bộ quyền | `{ items: [{ code, name, group }] }` — group: `auth` · `user` · `enterprise` · `device` · `warranty` · `quota` · `alert` · `exchange` · `report` · `audit` |

## 3. Enterprises — `/enterprises`

### Resource `Enterprise`

```json
{
  "enterprise_id": "7c9e6679-...", "parent_id": null, "code": "VPCC-DA",
  "name": "VPCC Đông Anh", "tax_code": "0101234567", "address": "…", "phone": "…", "email": "…",
  "contact_name": "…", "status": "ACTIVE", "max_users": 10,
  "user_count": 4, "device_count": 12, "branch_count": 2,
  "created_at": "...", "updated_at": "..."
}
```

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/enterprises` | Danh sách | Lọc `status`, `parent_id` (`null` = chỉ doanh nghiệp gốc), `q` |
| ✅ | `POST` | `/enterprises` | Tạo | `{ code, name, parent_id?, tax_code?, address?, phone?, email?, contact_name?, max_users? }`. 409 `ENTERPRISE_CODE_CONFLICT`. Chi nhánh không được có chi nhánh (tối đa 2 cấp) → 422 |
| ✅ | `GET` | `/enterprises/{enterprise_id}` | Chi tiết | |
| ✅ | `PUT` | `/enterprises/{enterprise_id}` | Sửa | Không đổi `code`, `parent_id` |
| ✅ | `PUT` | `/enterprises/{enterprise_id}/status` | Đổi trạng thái | `{ status: "ACTIVE" \| "SUSPENDED", reason? }`. `SUSPENDED` áp cả chi nhánh con; người dùng của DN không đăng nhập được |
| ✅ | `GET` | `/enterprises/{enterprise_id}/branches` | Chi nhánh con | `{ items: Enterprise[] }` |
| ✅ | `GET` | `/enterprises/{enterprise_id}/users` | Người dùng | như `/users?enterprise_id=` |
| ✅ | `GET` | `/enterprises/{enterprise_id}/devices` | Thiết bị | như `/devices?enterprise_id=` |
| ✅ | `DELETE` | `/enterprises/{enterprise_id}` | Xoá | 422 nếu còn thiết bị đang gán hoặc chi nhánh |

## 4. Devices — `/devices`

### Resource `Device`

```json
{
  "device_id": "3f2b7c14-...", "serial_number": "QLTB-24-000123",
  "device_type": "SIGNPAD", "model": "SP-200", "name": "Máy ký số quầy 1", "firmware_version": "1.4.2",
  "enterprise_id": "7c9e6679-...", "enterprise_name": "VPCC Đông Anh",
  "status": "ACTIVE", "sold_at": "2026-01-15", "assigned_at": "2026-01-15T03:00:00.000Z",
  "last_seen_at": "2026-09-15T06:20:00.000Z", "is_online": true,
  "notes": null, "created_at": "...", "updated_at": "..."
}
```

`status`: `IN_STOCK` · `ACTIVE` · `LOCKED` · `EXCHANGED` · `RETIRED` (máy trạng thái ở [`project-overview.md`](project-overview.md)). `is_online` = `last_seen_at` trong 24 h. `device_type` là mã tự do (`SIGNPAD`, `PRINTER`…) — danh mục cứng trong code, **cần chốt**.

Chi tiết (`GET /devices/{device_id}`) trả thêm `quota` (= resource `DeviceQuota`) và `warranty` (bảo hành đang `ACTIVE`, hoặc `null`).

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/devices` | Danh sách | Lọc `enterprise_id`, `device_type`, `status`, `q` (serial / name / model) |
| ✅ | `POST` | `/devices` | Nhập máy vào kho | `{ serial_number, device_type, model?, name?, firmware_version?, notes? }`. Luôn `IN_STOCK`, tự tạo `device_quotas` rỗng. 409 `DEVICE_SERIAL_CONFLICT` |
| ✅ | `GET` | `/devices/{device_id}` | Chi tiết | kèm `quota`, `warranty` |
| ✅ | `PUT` | `/devices/{device_id}` | Sửa hồ sơ | `model`, `name`, `firmware_version`, `notes`. **Không** đổi `serial_number`, `status`, `enterprise_id` |
| ✅ | `PUT` | `/devices/{device_id}/assign` | Gán cho doanh nghiệp | `{ enterprise_id, sold_at, warranty_months }`. `IN_STOCK → ACTIVE`, tạo `warranties` (`source = SALE`). 409 `DEVICE_STATE_CONFLICT` |
| ✅ | `PUT` | `/devices/{device_id}/unassign` | Thu hồi | `{ reason }`. `ACTIVE \| LOCKED → IN_STOCK`, xoá `enterprise_id` |
| ✅ | `PUT` | `/devices/{device_id}/status` | Đổi trạng thái tay | `{ status, reason }` — chỉ `RETIRED` từ `IN_STOCK`, hoặc `LOCKED ↔ ACTIVE` (tương đương `/quotas/.../lock`) |
| ✅ | `GET` | `/devices/{device_id}/usage` | Lịch sử lượt dùng | `from`, `to`, cursor → `{ items: UsageLog[] }` |
| ✅ | `DELETE` | `/devices/{device_id}` | Xoá | Chỉ khi `IN_STOCK` và chưa có `usage_logs` / `quota_grants`; ngược lại 422 — dùng `RETIRED` |

## 5. Warranties — `/warranties`

### Resource `Warranty`

```json
{
  "warranty_id": "c5ffa5a2-...", "device_id": "3f2b7c14-...", "serial_number": "QLTB-24-000123",
  "enterprise_id": "7c9e6679-...", "start_date": "2026-01-15", "end_date": "2027-01-15",
  "status": "ACTIVE", "source": "SALE", "days_remaining": 122, "notes": null,
  "created_at": "...", "updated_at": "..."
}
```

`status`: `ACTIVE` · `EXPIRED` · `TRANSFERRED` (đã chuyển sang máy mới khi đổi trả) · `VOID`. `source`: `SALE` · `EXCHANGE` · `EXTENSION`.

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/warranties` | Danh sách | Lọc `status`, `enterprise_id`, `expiring_within_days`; **mặc định sắp theo `end_date` tăng dần** (sắp hết trước) |
| ✅ | `POST` | `/warranties` | Tạo lượt bảo hành | `{ device_id, start_date, end_date, source?, notes? }`. Máy đang có `ACTIVE` thì lượt cũ → `VOID`? — **cần chốt**; tạm 422 |
| ✅ | `GET` | `/warranties/{warranty_id}` | Chi tiết | |
| ✅ | `PUT` | `/warranties/{warranty_id}` | Sửa / gia hạn | `{ end_date?, notes? }`. Gia hạn ghi audit với `old_values.end_date` |
| ✅ | `GET` | `/devices/{device_id}/warranties` | Lịch sử bảo hành của máy | `{ items: Warranty[] }` mới nhất trước |
| ✅ | `GET` | `/warranties/expiring` | Sắp hết hạn | `?days=30\|15\|7` (mặc định 30) → `{ items: Warranty[] }`. **Khai route này TRƯỚC `/warranties/{warranty_id}`** kẻo `expiring` bị hiểu là id |

## 6. Quota — `/quotas`, `/usage-logs`

### Resource `DeviceQuota`

```json
{
  "device_id": "3f2b7c14-...", "serial_number": "QLTB-24-000123", "enterprise_id": "7c9e6679-...",
  "quota_total": 10000, "quota_used": 8250, "quota_remaining": 1750, "remaining_pct": 17.5,
  "warn_threshold_pct": 20,
  "package_start_at": "2026-01-15T00:00:00.000Z", "package_end_at": "2027-01-15T00:00:00.000Z",
  "is_locked": false, "locked_reason": null, "locked_at": null,
  "updated_at": "..."
}
```

Đơn vị `amount`: số nguyên ≥ 1 (**cần chốt** là lượt hay trang). Bất biến: `quota_remaining = quota_total − quota_used ≥ 0`.

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/quotas` | Sản lượng từng máy | Lọc `enterprise_id`, `is_locked`, `below_pct` |
| ✅ | `GET` | `/quotas/{device_id}` | Chi tiết | |
| ✅ | `PUT` | `/quotas/{device_id}` | Sửa ngưỡng / gói | `{ warn_threshold_pct?, package_start_at?, package_end_at? }` |
| ✅ | `POST` | `/quotas/{device_id}/grants` | Cấp sản lượng | `{ amount, note? }` + `Idempotency-Key`. Transaction: insert `quota_grants` + `quota_total += amount`. Máy `LOCKED` vì hết sản lượng thì **tự mở khoá** |
| ✅ | `GET` | `/quotas/{device_id}/grants` | Lịch sử cấp | cursor, mới nhất trước |
| ✅ | `PUT` | `/quotas/{device_id}/lock` | Khoá máy | `{ reason }`. `ACTIVE → LOCKED`, `is_locked = true` |
| ✅ | `PUT` | `/quotas/{device_id}/unlock` | Mở khoá | 422 `QUOTA_INSUFFICIENT` nếu `quota_remaining = 0` hoặc hết gói |
| ✅ | `POST` | `/quotas/allocations` | Phân bổ cha → chi nhánh | `{ from_enterprise_id, to_enterprise_id, device_id, amount, note? }` + `Idempotency-Key`. `to` phải là chi nhánh của `from`; `device_id` thuộc `to`. Trừ ở "quỹ" của cha — **cần chốt** cha giữ quỹ ở đâu (đặc tả chỉ có quota theo máy) |
| ✅ | `GET` | `/quotas/allocations` | Lịch sử phân bổ | Lọc `from_enterprise_id`, `to_enterprise_id`, `device_id`, `from`, `to` |
| ✅ | `POST` | `/usage-logs` | Thiết bị ghi lượt dùng | `{ device_id, client_ref, amount?, used_at, meta? }`. Idempotent theo `(device_id, client_ref)`: trùng → trả lại kết quả cũ, 200. Vượt còn lại → 422 `QUOTA_INSUFFICIENT` **và** vẫn ghi dòng `rejected = true`. Máy `LOCKED` → 422 `DEVICE_LOCKED`. Cập nhật `last_seen_at`. Xác thực thiết bị: **cần chốt** |
| ✅ | `GET` | `/usage-logs` | Danh sách lượt dùng | Lọc `device_id`, `enterprise_id`, `from`, `to`, `rejected` |

```json
// UsageLog
{ "usage_id": "...", "device_id": "...", "client_ref": "dev-000123-20260915-0042", "amount": 1,
  "used_at": "2026-09-15T06:20:00.000Z", "received_at": "2026-09-15T06:20:03.000Z",
  "rejected": false, "remaining_after": 1749, "meta": {} }
```

## 7. Alerts & Notifications — `/alerts`, `/notifications`

### Resource `Alert`

```json
{
  "alert_id": "...", "device_id": "...", "serial_number": "QLTB-24-000123",
  "enterprise_id": "...", "enterprise_name": "VPCC Đông Anh",
  "type": "QUOTA_BELOW_20", "severity": "WARNING",
  "message": "Sản lượng còn 17,5 % (1.750 / 10.000)", "payload": { "remaining_pct": 17.5 },
  "occurred_at": "...", "resolved_at": null
}
```

`type`: `QUOTA_BELOW_20` · `QUOTA_BELOW_10` · `QUOTA_EXHAUSTED` · `WARRANTY_30D` · `WARRANTY_15D` · `WARRANTY_7D` · `WARRANTY_EXPIRED` · `DEVICE_OFFLINE`. `severity`: `INFO` · `WARNING` · `CRITICAL`. Mỗi `(device_id, type)` chỉ phát **một lần cho một chu kỳ** (`dedupe_key` = ngày hết hạn / mốc gói) — không spam mỗi lần job chạy.

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/alerts` | Danh sách | Lọc `group` (`QUOTA` \| `WARRANTY` \| `DEVICE`), `severity`, `enterprise_id`, `from`, `to`, `resolved` |
| ✅ | `GET` | `/alerts/{alert_id}` | Chi tiết | |
| ✅ | `GET` | `/notifications` | Thông báo của tôi | cursor, mới nhất trước; `?unread=true` |
| ✅ | `GET` | `/notifications/unread-count` | Đếm chưa đọc | `{ count: 3 }` |
| ✅ | `PUT` | `/notifications/{notification_id}/read` | Đã đọc một | → 204. Của người khác → 404 |
| ✅ | `PUT` | `/notifications/read-all` | Đã đọc tất cả | → `{ updated: 12 }`. **Khai TRƯỚC `/{notification_id}/read`** |

```json
// Notification
{ "notification_id": "...", "alert_id": "...", "title": "Sản lượng sắp hết", "body": "…",
  "alert": { "type": "QUOTA_BELOW_20", "severity": "WARNING", "device_id": "..." },
  "read_at": null, "created_at": "..." }
```

## 8. Device Exchanges — `/device-exchanges`

### Resource `DeviceExchange`

```json
{
  "exchange_id": "...", "enterprise_id": "...", "enterprise_name": "VPCC Đông Anh",
  "old_device_id": "...", "old_serial_number": "QLTB-24-000123",
  "new_device_id": null, "new_serial_number": null,
  "reason": "Màn hình cảm ứng liệt", "status": "PENDING",
  "requested_by": "...", "requested_by_name": "Trần Thị B", "requested_at": "...",
  "approved_by": null, "approved_by_name": null, "approved_at": null, "reject_reason": null,
  "created_at": "...", "updated_at": "..."
}
```

`status`: `PENDING` · `APPROVED` · `REJECTED`.

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/device-exchanges` | Danh sách | Lọc `status`, `enterprise_id` |
| ✅ | `POST` | `/device-exchanges` | Tạo yêu cầu | `{ old_device_id, reason }` + `Idempotency-Key`. Máy cũ phải `ACTIVE`/`LOCKED` và thuộc DN của người gọi; đã có yêu cầu `PENDING` cho máy đó → 409 `EXCHANGE_STATE_CONFLICT` |
| ✅ | `GET` | `/device-exchanges/{exchange_id}` | Chi tiết | |
| ✅ | `PUT` | `/device-exchanges/{exchange_id}` | Sửa | `{ reason }`. Chỉ khi `PENDING` |
| ✅ | `PUT` | `/device-exchanges/{exchange_id}/approve` | Duyệt | `{ new_device_id, note? }`. Transaction: máy mới `IN_STOCK → ACTIVE` với `enterprise_id` của DN; máy cũ → `EXCHANGED`; bảo hành `ACTIVE` của máy cũ → `TRANSFERRED`, tạo bảo hành mới cho máy mới cùng `end_date`, `source = EXCHANGE`; **sản lượng còn lại chuyển sang máy mới** (ghi `quota_grants` cho máy mới, `usage_logs`… — **cần chốt** cách ghi) |
| ✅ | `PUT` | `/device-exchanges/{exchange_id}/reject` | Từ chối | `{ reject_reason }` |
| ✅ | `DELETE` | `/device-exchanges/{exchange_id}` | Xoá | Chỉ khi `PENDING`, chỉ người tạo hoặc admin |

## 9. Dashboard — `/dashboard`

| TT | Method | Path | Việc | Response |
|---|---|---|---|---|
| ✅ | `GET` | `/dashboard/admin` | Tổng quan quản trị | `{ enterprise_count, device_count, devices_by_status: {…}, quota_used_total, devices_quota_low, devices_warranty_expiring, devices_offline }` |
| ✅ | `GET` | `/dashboard/business` | Tổng quan doanh nghiệp | `{ device_count, devices: [{ device_id, serial_number, quota_remaining, remaining_pct, is_online }], quota_used_total, unread_notifications }` |
| ✅ | `GET` | `/dashboard/usage-chart` | Biểu đồ sản lượng | `?from&to&granularity=day\|week\|month&enterprise_id&device_id` → `{ points: [{ bucket: "2026-09-15", amount: 120 }] }` |
| ✅ | `GET` | `/dashboard/expiring-devices` | Sắp hết sản lượng / bảo hành | `{ quota_low: DeviceQuota[], warranty_expiring: Warranty[] }` |

## 10. Report — `/reports`

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/reports/devices` | Xuất danh sách thiết bị | `?format=xlsx\|pdf` + bộ lọc như `/devices`. Trả file, **không envelope**, `Content-Disposition: attachment` |
| ✅ | `GET` | `/reports/quota` | Báo cáo sản lượng | `?format&from&to&enterprise_id` — gồm lượt cấp và lượt dùng |
| ✅ | `GET` | `/reports/enterprises` | Xuất danh sách doanh nghiệp | `?format` |

## 11. Audit Logs — `/audit-logs`

```json
{
  "audit_id": "...", "enterprise_id": "...", "actor_user_id": "...", "actor_username": "admin",
  "module": "device", "action": "DEVICE_ASSIGN", "resource_type": "device", "resource_id": "...",
  "old_values": { "status": "IN_STOCK", "enterprise_id": null },
  "new_values": { "status": "ACTIVE", "enterprise_id": "..." },
  "request_id": "...", "ip": "…", "occurred_at": "..."
}
```

| TT | Method | Path | Việc | Ghi chú |
|---|---|---|---|---|
| ✅ | `GET` | `/audit-logs` | Danh sách | Lọc `actor_user_id`, `enterprise_id`, `module`, `action`, `from`, `to`. Người dùng DN chỉ thấy của DN mình |
| ✅ | `GET` | `/audit-logs/{audit_id}` | Chi tiết | kèm `old_values` / `new_values` đầy đủ |

`actor_*` LUÔN lấy từ token, không bao giờ từ body.

---

## Đã chốt (quyết định lúc triển khai — đổi được, nhưng phải đổi cả code)

| # | Câu hỏi | Quyết định |
|---|---|---|
| 1 | Đơn vị `amount` | Số nguyên ≥ 1, gọi là **lượt**; mỗi `usage_log` mặc định 1 |
| 2 | `devices.status` | `IN_STOCK · ACTIVE · LOCKED · EXCHANGED · RETIRED`. `unassign` → bảo hành ACTIVE chuyển `VOID`, sản lượng còn lại **giữ trên máy** |
| 3 | Quỹ sản lượng của DN cha | Không có quỹ riêng — phân bổ là **chuyển từ máy của cha sang máy của chi nhánh** (`from_device_id` → `device_id`) |
| 4 | Thiết bị xác thực `POST /usage-logs` | Header `X-Device-Key`, key cấp lúc `assign` (hiện một lần), lưu hash; `POST /devices/{id}/api-key` cấp lại; `unassign` thu hồi |
| 5 | Chuyển sản lượng khi duyệt đổi trả | Hai dòng đối ứng: `usage_logs` (meta `EXCHANGE_TRANSFER`) trừ hết máy cũ + `quota_grants` cộng máy mới; bảo hành → `TRANSFERRED` + lượt mới `source = EXCHANGE` giữ `end_date` |
| 6 | Refresh token | Cookie httpOnly `qltb_rt`, xoay mỗi lần dùng, dùng lại thẻ cũ → huỷ cả phiên |
| 7 | Danh mục `device_type` | Cố định trong code (`device-type.catalog.ts`), phát qua `GET /devices/types` |
| 8 | Quên mật khẩu | Chưa có kênh gửi: dev ghi mã ra log server; quản trị đặt lại trực tiếp qua `PUT /users/{id}/reset-password` |
| 9 | Ngưỡng offline | 24 h (`DEVICE_OFFLINE_AFTER_HOURS`), job quét mỗi 10 phút |
| 10 | Báo cáo PDF | Chưa — chỉ `xlsx` (PDF cần font tiếng Việt nhúng) |

## Endpoint ngoài đặc tả (bổ sung khi triển khai)

| Method | Path | Vì sao |
|---|---|---|
| `POST` | `/auth/logout` | Đặc tả không có; web cần huỷ phiên |
| `GET` | `/devices/types` | Danh mục loại thiết bị cho select |
| `POST` | `/devices/{id}/api-key` | Cấp lại key thiết bị |
| `PUT` | `/users/{id}/reset-password` | Quản trị đặt lại mật khẩu khi chưa có email |
| `POST` | `/alerts/scan` | Chạy job quét tay |
