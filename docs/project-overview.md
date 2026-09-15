# Tổng quan dự án QLTB

Nguồn: [`spec/qltb-spec.md`](spec/qltb-spec.md) (đặc tả gốc). File này diễn giải đặc tả thành mô hình để đọc code — đặc tả nói gì thì đặc tả thắng.

## Dự án này là gì

QLTB quản lý **thiết bị được bán / cấp cho doanh nghiệp** (ví dụ văn phòng công chứng và các chi nhánh) và theo dõi **sản lượng sử dụng** của từng máy. Nhà cung cấp (quản trị viên hệ thống) nhập máy vào kho, gán cho doanh nghiệp, cấp sản lượng theo gói; thiết bị ngoài hiện trường báo lượt sử dụng về, sản lượng trừ dần; hết sản lượng hoặc hết thời gian gói thì máy bị khoá. Kèm theo là bảo hành, đổi trả máy, cảnh báo, thông báo, dashboard, báo cáo và nhật ký kiểm toán.

Bốn nhóm nghiệp vụ chính:

| Nhóm | Việc |
|---|---|
| **Doanh nghiệp & người dùng** | Doanh nghiệp cha – chi nhánh (tự tham chiếu `parent_id`), mỗi doanh nghiệp tối đa `max_users` tài khoản (mặc định 10). Vai trò – quyền N-N |
| **Thiết bị & bảo hành** | Nhập kho, gán / thu hồi cho doanh nghiệp, kích hoạt bảo hành khi bán, gia hạn, đổi trả máy (chuyển bảo hành sang máy mới) |
| **Sản lượng (quota)** | Cấp sản lượng cho máy (`quota_grants`, cộng dồn), phân bổ từ cha xuống chi nhánh (`quota_allocations`), ghi lượt sử dụng (`usage_logs`, trừ dần), khoá / mở khoá máy |
| **Giám sát** | Cảnh báo theo ngưỡng (sản lượng < 20 % / < 10 % / hết; bảo hành còn 30 / 15 / 7 ngày / hết hạn; máy offline) → thông báo tới người dùng; dashboard cho admin và cho doanh nghiệp; xuất báo cáo; audit log |

## Ba điểm cốt lõi cần hiểu trước khi đọc code

1. **`device_quotas` là projection, lịch sử là sự thật.** Tổng / đã dùng / còn lại trên `device_quotas` phải bằng `Σ quota_grants − Σ usage_logs` (cộng phân bổ nhận, trừ phân bổ cho đi). Mọi thay đổi sản lượng đi qua **một transaction**: ghi dòng lịch sử **và** cập nhật projection. Sửa projection tay là sai kiểm kê không lần lại được.

2. **Lượt sử dụng từ thiết bị có thể đến trễ, trùng, lệch thứ tự.** `POST /usage-logs` do máy ngoài hiện trường gọi — mất mạng rồi gửi bù là chuyện thường. Mỗi lượt mang `client_ref` (id do thiết bị sinh) làm khoá idempotent; unique constraint ở DB, gặp trùng thì trả kết quả cũ, không trừ hai lần. Sản lượng còn lại **không được âm**: vượt trần thì ghi lượt với `rejected = true` và phát cảnh báo, không im lặng bỏ.

3. **Phạm vi dữ liệu theo doanh nghiệp.** Người dùng có `enterprise_id` chỉ thấy dữ liệu của doanh nghiệp mình **và các chi nhánh con**; `enterprise_id = NULL` là quản trị viên hệ thống, thấy tất cả. Mọi repository nhận `scope` từ token, không phải từ query string.

## Máy trạng thái thiết bị

Đặc tả chưa liệt kê giá trị `status`; bộ dưới đây suy từ các endpoint `assign` / `unassign` / `lock` / `unlock` / `device-exchanges` — **cần chốt** (xem cuối file).

```
IN_STOCK ──assign──▶ ACTIVE ──lock────▶ LOCKED
   ▲                   │  ▲               │
   │ unassign          │  └───unlock──────┘
   └───────────────────┴───────────────────┘   (unassign từ cả ACTIVE lẫn LOCKED)
ACTIVE / LOCKED ──exchange approved──▶ EXCHANGED (terminal, máy cũ)
IN_STOCK ──retire──▶ RETIRED (terminal)
```

- `LOCKED` do hết sản lượng / hết gói / khoá tay; **không** đổi `enterprise_id`.
- `unassign` xoá `enterprise_id`, bảo hành đang `ACTIVE` chuyển `VOID`? — **cần chốt**.
- Máy cũ trong đổi trả sang `EXCHANGED`; máy mới nhận bảo hành còn lại (`warranties.source = EXCHANGE`).
- "Offline" **không** phải `status`: suy từ `last_seen_at` quá ngưỡng (mặc định 24 h), để không nhân đôi nguồn sự thật.

## Người dùng

| Vai trò (mặc định) | `enterprise_id` | Thấy gì |
|---|---|---|
| `SYSTEM_ADMIN` | NULL | Toàn hệ thống: nhập máy, gán, cấp sản lượng, duyệt đổi trả, báo cáo |
| `ENTERPRISE_ADMIN` | có | Doanh nghiệp mình + chi nhánh: người dùng, thiết bị, phân bổ sản lượng xuống chi nhánh, tạo yêu cầu đổi trả |
| `ENTERPRISE_USER` | có | Xem thiết bị, sản lượng, thông báo của doanh nghiệp mình |

Vai trò là **dữ liệu** (`roles` ↔ `permissions` N-N), ba vai trò trên chỉ là seed.

## Mô hình dữ liệu

Tên bảng theo đúng đặc tả. Cụm trong `qltb-service/src/db/schema/`:

| Cụm | Bảng |
|---|---|
| `system.ts` | `enterprises` · `users` · `roles` · `permissions` · `users_roles` · `roles_permissions` · `audit_logs` |
| `device.ts` | `devices` · `warranties` · `device_exchanges` |
| `quota.ts` | `device_quotas` · `quota_grants` · `quota_allocations` · `usage_logs` |
| `alert.ts` | `alerts` · `notifications` |

Append-only (trigger chặn UPDATE/DELETE): `quota_grants` · `quota_allocations` · `usage_logs` · `audit_logs`.

## Còn phải chốt

- Đơn vị của "sản lượng": lượt / trang / phút? Code gọi chung là `amount` (số nguyên), mỗi `usage_log` mặc định 1.
- Bộ giá trị `devices.status` ở trên, và `unassign` có huỷ bảo hành không.
- Thiết bị gọi `POST /usage-logs` xác thực bằng gì (API key theo máy? token doanh nghiệp?) — quyết định này ảnh hưởng schema `devices` (cần cột `api_key_hash`).
- Ngưỡng "offline" (24 h?) và ai chạy job quét cảnh báo (cron trong service hay job ngoài).
