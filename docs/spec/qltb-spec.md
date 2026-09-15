# Hệ thống quản lý thiết bị — Mô tả quan hệ dữ liệu và API spec

> Chuyển từ `qltb.docx` (bản gốc của dự án, 15/09/2026). Đây là **đặc tả nghiệp vụ gốc** — nguồn sự thật về bảng, quan hệ và danh sách endpoint. Khi sửa đặc tả thì sửa file này, không commit `.docx`.

## Các quan hệ

- **enterprises 1 - N enterprises** — Một doanh nghiệp cha có thể có nhiều chi nhánh con, nhưng mỗi chi nhánh chỉ trực thuộc một doanh nghiệp cha — quan hệ tự tham chiếu qua parent_id, ví dụ VPCC Đông Anh có chi nhánh Kim Chung, chi nhánh Nguyên Khê
- **enterprises 1 - N users** — Một doanh nghiệp có nhiều người dùng (kế toán, nhân viên…), nhưng mỗi người dùng chỉ thuộc một doanh nghiệp. enterprise_id để trống nghĩa là quản trị viên hệ thống, không thuộc doanh nghiệp nào. Mỗi doanh nghiệp được miễn phí 10 tài khoản theo max_users
- **users N - N roles** — Một người dùng có thể được gán nhiều vai trò và một vai trò có thể gán cho nhiều người dùng — mối quan hệ nhiều nhiều sẽ tạo ra 1 bảng mới users_roles
- **roles N - N permissions** — Một vai trò gồm nhiều quyền và một quyền có thể thuộc nhiều vai trò — mối quan hệ nhiều nhiều sẽ tạo ra 1 bảng mới roles_permissions
- **enterprises 1 - N devices** — Một doanh nghiệp có thể sở hữu nhiều thiết bị, nhưng mỗi thiết bị tại một thời điểm chỉ thuộc một doanh nghiệp. enterprise_id để trống nghĩa là thiết bị chưa được gán, còn trong kho
- **devices 1 - N warranties** — Một thiết bị có thể có nhiều lượt bảo hành, nhưng mỗi lượt bảo hành chỉ thuộc về một thiết bị. Bảo hành được kích hoạt ngay khi bán máy; khi đổi trả máy sẽ sinh thêm một dòng bảo hành mới
- **devices 1 - 1 device_quotas** — Mỗi thiết bị có một bản ghi sản lượng tương ứng và mỗi bản ghi sản lượng chỉ thuộc về một thiết bị — lưu tổng quota, đã dùng, còn lại, ngưỡng cảnh báo, thời gian gói và trạng thái khóa
- **devices 1 - N quota_grants** — Một thiết bị có thể được cấp sản lượng nhiều lần, nhưng mỗi lượt cấp chỉ dành cho một thiết bị — đây là lịch sử LƯỢT CẤP, cộng dồn vào tổng quota của thiết bị
- **users (granted_by) 1 - N quota_grants** — Một quản trị viên có thể thực hiện nhiều lượt cấp sản lượng, nhưng mỗi lượt cấp chỉ do một người thực hiện
- **devices 1 - N usage_logs** — Một thiết bị phát sinh nhiều bản ghi sử dụng, nhưng mỗi bản ghi chỉ thuộc về một thiết bị — đây là lịch sử LƯỢT SỬ DỤNG, trừ dần sản lượng còn lại
- **enterprises 1 - N quota_allocations** — Một doanh nghiệp cha có thể phân bổ sản lượng nhiều lần, nhưng mỗi lần phân bổ chỉ có một doanh nghiệp cấp (from_enterprise_id) và một chi nhánh con nhận (to_enterprise_id)
- **devices 1 - N quota_allocations** — Một thiết bị có thể nhận sản lượng từ nhiều lần phân bổ, nhưng mỗi lần phân bổ chỉ áp cho một thiết bị
- **users (allocated_by) 1 - N quota_allocations** — Một người dùng có thể thực hiện nhiều lần phân bổ sản lượng, nhưng mỗi lần phân bổ chỉ do một người thực hiện
- **devices 1 - N alerts** — Một thiết bị có thể phát sinh nhiều cảnh báo, nhưng mỗi cảnh báo chỉ liên quan đến một thiết bị: sản lượng còn dưới 20%, dưới 10%, hết quota, bảo hành còn 30/15/7 ngày hoặc đã hết hạn
- **enterprises 1 - N alerts** — Một doanh nghiệp có thể có nhiều cảnh báo, nhưng mỗi cảnh báo chỉ thuộc về một doanh nghiệp — dùng để lọc cảnh báo theo doanh nghiệp
- **alerts 1 - N notifications** — Một cảnh báo được gửi tới nhiều người nhận nên sinh ra nhiều thông báo, nhưng mỗi thông báo chỉ phát sinh từ một cảnh báo
- **users 1 - N notifications** — Một người dùng nhận được nhiều thông báo, nhưng mỗi thông báo chỉ gửi tới một người dùng — trạng thái đã đọc/chưa đọc lưu ở read_at để hiển thị chuông thông báo
- **enterprises 1 - N device_exchanges** — Một doanh nghiệp có thể có nhiều yêu cầu đổi trả máy, nhưng mỗi yêu cầu đổi trả chỉ thuộc về một doanh nghiệp
- **devices 1 - N device_exchanges** — Một thiết bị có thể xuất hiện trong nhiều yêu cầu đổi trả, nhưng mỗi yêu cầu chỉ gắn với một máy cũ (old_device_id) và một máy mới (new_device_id). Máy mới để trống khi yêu cầu chưa được duyệt
- **users 1 - N device_exchanges** — Một người dùng có thể tạo hoặc duyệt nhiều yêu cầu đổi trả, nhưng mỗi yêu cầu chỉ có một người gửi (requested_by) và một người duyệt (approved_by)
- **users 1 - N audit_logs** — Một người dùng có thể tạo ra nhiều bản ghi nhật ký, nhưng mỗi bản ghi nhật ký chỉ thuộc về một người dùng — kiểm tra ai đã sửa dữ liệu gì thông qua old_values và new_values
- **enterprises 1 - N audit_logs** — Một doanh nghiệp có nhiều bản ghi nhật ký liên quan, nhưng mỗi bản ghi chỉ gắn với một doanh nghiệp bị tác động — người dùng doanh nghiệp chỉ xem được nhật ký của doanh nghiệp mình

## Các API Spec

### 1. Auth

| Method | API | Mô tả |
| --- | --- | --- |
| POST | /auth/login | Đăng nhập |
| POST | /auth/forgot-password | Quên mật khẩu |
| POST | /auth/reset-password | Đặt lại mật khẩu |
| GET | /auth/me | Lấy thông tin người dùng đang đăng nhập kèm vai trò và quyền |
| PUT | /auth/change-password | Đổi mật khẩu khi đang đăng nhập |
| PUT | /auth/profile | Cập nhật thông tin cá nhân |
| POST | /auth/refresh-token | Cấp token mới |

### 2. User và Role

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /users | Lấy danh sách người dùng, lọc theo doanh nghiệp, vai trò, trạng thái và tìm kiếm |
| POST | /users | Tạo mới tài khoản người dùng, kiểm tra giới hạn 10 tài khoản của doanh nghiệp |
| GET | /users/:id | Lấy thông tin chi tiết của người dùng |
| PUT | /users/:id | Cập nhật thông tin người dùng |
| PUT | /users/:id/disable | Khóa hoặc vô hiệu hóa người dùng |
| PUT | /users/:id/roles | Gán hoặc cập nhật vai trò cho người dùng |
| DELETE | /users/:id | Xóa người dùng |
| GET | /roles | Lấy danh sách vai trò |
| POST | /roles | Tạo vai trò |
| GET | /roles/:id | Xem chi tiết vai trò |
| PUT | /roles/:id | Cập nhật vai trò |
| GET | /roles/:id/permissions | Lấy danh sách các quyền của vai trò |
| PUT | /roles/:id/permissions | Cập nhật quyền của vai trò |
| DELETE | /roles/:id | Xóa vai trò |
| GET | /permissions | Lấy danh sách toàn bộ quyền của hệ thống |

### 3. Enterprises

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /enterprises | Lấy danh sách doanh nghiệp, lọc theo trạng thái, doanh nghiệp cha và tìm kiếm |
| POST | /enterprises | Thêm mới doanh nghiệp |
| GET | /enterprises/:id | Lấy thông tin chi tiết của doanh nghiệp |
| PUT | /enterprises/:id | Cập nhật thông tin doanh nghiệp |
| PUT | /enterprises/:id/status | Thay đổi trạng thái hoạt động của doanh nghiệp |
| GET | /enterprises/:id/branches | Lấy danh sách chi nhánh con của doanh nghiệp |
| GET | /enterprises/:id/users | Lấy danh sách người dùng thuộc doanh nghiệp |
| GET | /enterprises/:id/devices | Lấy danh sách thiết bị doanh nghiệp đang sở hữu |
| DELETE | /enterprises/:id | Xóa doanh nghiệp |

### 4. Devices

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /devices | Lấy danh sách thiết bị, lọc theo doanh nghiệp, loại thiết bị, trạng thái và tìm kiếm theo serial |
| POST | /devices | Thêm mới thiết bị vào hệ thống |
| GET | /devices/:id | Lấy thông tin chi tiết của thiết bị kèm sản lượng và bảo hành |
| PUT | /devices/:id | Cập nhật thông tin thiết bị |
| PUT | /devices/:id/assign | Gán thiết bị cho doanh nghiệp, ghi nhận ngày bán và kích hoạt bảo hành |
| PUT | /devices/:id/unassign | Thu hồi thiết bị khỏi doanh nghiệp |
| PUT | /devices/:id/status | Cập nhật trạng thái thiết bị |
| GET | /devices/:id/usage | Lấy lịch sử lượt sử dụng của thiết bị theo khoảng thời gian |
| DELETE | /devices/:id | Xóa thiết bị |

### 5. Warranties

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /warranties | Lấy danh sách bảo hành, lọc theo trạng thái và ưu tiên hiển thị thiết bị sắp hết hạn |
| POST | /warranties | Tạo mới lượt bảo hành cho thiết bị |
| GET | /warranties/:id | Lấy thông tin chi tiết của lượt bảo hành |
| PUT | /warranties/:id | Cập nhật thông tin bảo hành, gia hạn ngày hết hạn |
| GET | /devices/:id/warranties | Lấy toàn bộ lịch sử bảo hành của một thiết bị |
| GET | /warranties/expiring | Lấy danh sách thiết bị sắp hết bảo hành theo mốc 30/15/7 ngày |

### 6. Quota

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /quotas | Lấy danh sách sản lượng theo từng thiết bị, lọc theo doanh nghiệp và trạng thái khóa |
| GET | /quotas/:deviceId | Lấy chi tiết sản lượng của một thiết bị: tổng quota, đã dùng, còn lại, thời gian gói |
| PUT | /quotas/:deviceId | Cập nhật ngưỡng cảnh báo và thời gian gói của thiết bị |
| POST | /quotas/:deviceId/grants | Cấp thêm sản lượng cho thiết bị và ghi nhận lịch sử lượt cấp |
| GET | /quotas/:deviceId/grants | Lấy lịch sử lượt cấp sản lượng của thiết bị |
| PUT | /quotas/:deviceId/lock | Khóa thiết bị khi hết sản lượng hoặc hết thời gian gói |
| PUT | /quotas/:deviceId/unlock | Mở khóa thiết bị |
| POST | /quotas/allocations | Phân bổ sản lượng từ doanh nghiệp cha xuống chi nhánh con |
| GET | /quotas/allocations | Lấy lịch sử phân bổ sản lượng giữa các doanh nghiệp |
| POST | /usage-logs | Ghi nhận lượt sử dụng từ thiết bị và trừ dần sản lượng còn lại |
| GET | /usage-logs | Lấy danh sách lượt sử dụng, lọc theo thiết bị, doanh nghiệp và khoảng thời gian |

### 7. Alerts và Notifications

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /alerts | Lấy danh sách cảnh báo, lọc theo nhóm cảnh báo, mức độ, doanh nghiệp và khoảng thời gian |
| GET | /alerts/:id | Lấy thông tin chi tiết của cảnh báo |
| GET | /notifications | Lấy danh sách thông báo của người dùng đang đăng nhập |
| GET | /notifications/unread-count | Đếm số thông báo chưa đọc để hiển thị trên chuông thông báo |
| PUT | /notifications/:id/read | Đánh dấu một thông báo là đã đọc |
| PUT | /notifications/read-all | Đánh dấu tất cả thông báo là đã đọc |

### 8. Device Exchanges

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /device-exchanges | Lấy danh sách yêu cầu đổi trả máy, lọc theo trạng thái duyệt và doanh nghiệp |
| POST | /device-exchanges | Tạo yêu cầu đổi trả máy, khai báo máy cũ và lý do đổi trả |
| GET | /device-exchanges/:id | Lấy thông tin chi tiết của yêu cầu đổi trả |
| PUT | /device-exchanges/:id | Cập nhật thông tin yêu cầu đổi trả khi chưa duyệt |
| PUT | /device-exchanges/:id/approve | Duyệt yêu cầu đổi trả, gán máy mới và chuyển bảo hành sang máy mới |
| PUT | /device-exchanges/:id/reject | Từ chối yêu cầu đổi trả kèm lý do |
| DELETE | /device-exchanges/:id | Xóa yêu cầu đổi trả khi chưa duyệt |

### 9. Dashboard

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /dashboard/admin | Thống kê tổng quan cho quản trị viên: tổng doanh nghiệp, tổng thiết bị, tổng sản lượng đã sử dụng, thiết bị sắp hết sản lượng, thiết bị sắp hết bảo hành, thiết bị offline |
| GET | /dashboard/business | Thống kê tổng quan cho doanh nghiệp: thiết bị đang sở hữu, sản lượng còn lại của từng thiết bị, sản lượng đã sử dụng và thông báo mới |
| GET | /dashboard/usage-chart | Lấy dữ liệu biểu đồ sản lượng sử dụng theo thời gian |
| GET | /dashboard/expiring-devices | Lấy danh sách thiết bị sắp hết sản lượng hoặc sắp hết bảo hành |

### 10. Report

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /reports/devices | Xuất danh sách thiết bị ra file Excel hoặc PDF |
| GET | /reports/quota | Xuất báo cáo sản lượng (lượt cấp và lượt sử dụng) ra file Excel hoặc PDF |
| GET | /reports/enterprises | Xuất danh sách doanh nghiệp ra file Excel hoặc PDF |

### 11. Audit Logs

| Method | API | Mô tả |
| --- | --- | --- |
| GET | /audit-logs | Lấy danh sách nhật ký thao tác của người dùng, hỗ trợ lọc theo người dùng, doanh nghiệp, nhóm chức năng, hành động và khoảng thời gian |
| GET | /audit-logs/:id | Xem chi tiết một bản ghi nhật ký kèm giá trị trước và sau khi thay đổ |
