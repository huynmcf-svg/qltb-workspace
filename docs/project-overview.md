# Tổng quan dự án QLTB

## Dự án này là gì

QLTB là hệ thống quản lý thiết bị nội bộ: theo dõi **thiết bị nào đang ở đâu, do ai giữ, tình trạng ra sao, và đã qua những gì**.

Bốn nhóm nghiệp vụ chính:

| Nhóm | Việc |
|---|---|
| **Hồ sơ thiết bị** | Đăng ký thiết bị mới (mã, tên, loại, hãng, model, serial, ngày mua, giá, bảo hành), sửa thông tin, thanh lý |
| **Phân bổ** | Cấp thiết bị cho đơn vị / phòng ban / cá nhân, thu hồi, luân chuyển giữa các bên |
| **Bảo trì** | Ghi nhận sự cố, lập phiếu bảo trì / sửa chữa, theo dõi tiến độ, chi phí |
| **Báo cáo** | Kiểm kê, thống kê theo loại / đơn vị / tình trạng, lịch sử một thiết bị |

## Hai điểm cốt lõi cần hiểu trước khi đọc code

1. **Lịch sử thiết bị là append-only.** Mỗi lần cấp, thu hồi, luân chuyển, bảo trì là **một dòng mới** trong `device_history`, không sửa dòng cũ. Trạng thái hiện tại của thiết bị (`devices.status`, `devices.holder_*`) là *projection* từ lịch sử — sửa projection mà không ghi lịch sử là làm sai lệch kiểm kê về sau.

2. **Trạng thái thiết bị là một máy trạng thái, không phải một cột tự do.** Chuyển trạng thái phải qua service, service kiểm tra chuyển hợp lệ:

```
IN_STOCK ──cấp──▶ IN_USE ──thu hồi──▶ IN_STOCK
   │                 │
   │ hỏng            │ hỏng
   ▼                 ▼
UNDER_MAINTENANCE ──xong──▶ IN_STOCK
   │
   │ không sửa được
   ▼
DISPOSED (terminal)
```

`DISPOSED` là trạng thái cuối, không quay lại. Thiết bị `IN_USE` không được thanh lý thẳng — phải thu hồi trước, để hồ sơ ghi nhận rõ ai đang giữ lúc thanh lý.

## Người dùng

| Vai trò | Nhịp làm việc |
|---|---|
| **Quản trị thiết bị** (admin) | Vào theo việc: nhập thiết bị mới, cấp phát, lập phiếu bảo trì, kiểm kê |
| **Trưởng đơn vị** | Xem thiết bị của đơn vị mình, xác nhận nhận / trả |
| **Người dùng** | Xem thiết bị mình đang giữ, báo hỏng |

Phân quyền chưa có ở khung này — nhưng thiết kế DTO / service phải để sau này gắn được `tenant_id` / `actor` từ token mà không viết lại.

## Mô hình dữ liệu tối thiểu

```
device_categories   loại thiết bị (laptop, màn hình, máy in...)
devices             hồ sơ thiết bị — mỗi thiết bị một dòng, `code` unique
device_history      append-only: ASSIGN / RETURN / TRANSFER / MAINTENANCE_START / MAINTENANCE_END / DISPOSE
```

Chi tiết cột và ràng buộc ở `qltb-service/src/db/schema/`. Hợp đồng REST ở [`api-contracts.md`](api-contracts.md).
