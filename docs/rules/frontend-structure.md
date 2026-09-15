# Rules — cấu trúc frontend (`qltb-web`)

## Stack

| | |
|---|---|
| Framework | Next.js 16 (App Router) |
| Node | 22 LTS |
| UI | shadcn/ui · Tailwind v4 · lucide-react |
| Data | TanStack Query v5 |
| Form | react-hook-form + zod |
| Test | vitest + testing-library |

## Cây thư mục

```
src/
├── app/
│   ├── (auth)/                  # login, quen-mat-khau, dat-lai-mat-khau — không có shell
│   ├── (dashboard)/             # layout.tsx: guard phiên + sidebar + header
│   │   ├── tong-quan/ thiet-bi/[deviceId] doanh-nghiep/[enterpriseId] nguoi-dung/ vai-tro/
│   │   └── san-luong/ bao-hanh/ doi-tra/ canh-bao/ thong-bao/ nhat-ky/ bao-cao/ tai-khoan/
│   ├── layout.tsx               # root: font, providers, toaster
│   ├── icon.svg                 # favicon
│   └── globals.css              # token màu, theme
├── components/
│   ├── ui/                      # shadcn generated — KHÔNG sửa tay
│   ├── common/                  # dùng chung: data-table, page-header, stat-card, confirm-dialog,
│   │                            #   status-badge (MỌI nhãn/màu trạng thái), quota-bar, secret-reveal, field
│   └── <feature>/               # riêng một màn: devices/, enterprises/, users/, roles/, quotas/…
├── lib/
│   ├── api/                     # client.ts + một module một file; reports.ts tải file
│   ├── auth/                    # session (RAM), refresh (single-flight)
│   ├── nav.ts                   # menu + quyền cần có — sidebar và tiêu đề header đọc từ đây
│   └── utils/                   # cn, errors, date
├── hooks/                       # use-<module>.ts — bọc TanStack Query, gom cache key
└── types/                       # api.ts (envelope, mã lỗi) + một file một resource — khớp api-contracts.md
```

Route đặt tên tiếng Việt không dấu, kebab-case: `/thiet-bi`, `/loai-thiet-bi`.

## Component đặt ở đâu

| Dùng ở | Chỗ |
|---|---|
| Chỉ một màn | `components/<feature>/` |
| Từ hai màn trở lên | `components/common/` |
| shadcn sinh ra | `components/ui/` — **không sửa tay**, cần khác thì bọc ở `common/` |

Thêm component shadcn: `npx shadcn@latest add <tên>` — `components.json` đã cấu hình alias.

## Bắt buộc

- Type của response **khớp** [`api-contracts.md`](../api-contracts.md). Đổi contract thì sửa cả hai repo.
- Giữ nguyên `snake_case` của API trong type. Không map sang camelCase.
- Mọi lời gọi API đi qua `lib/api/client.ts` → `lib/api/<module>.ts`. Không `fetch` rải rác trong component.
- Đọc `error.code` để rẽ nhánh, **không** so khớp `error.message`. Đổi mã lỗi thành câu tiếng Việt ở **một chỗ**: `lib/utils/errors.ts`.
- Component gọi hook trong `hooks/`, không gọi `lib/api/` trực tiếp — để cache key và invalidate gom về một chỗ.
- Ẩn/hiện nút theo `can('permission.code')` từ `useSession()` — server vẫn là nơi quyết định, web chỉ tránh cho bấm rồi nhận 403.
- Dialog: state form nằm trong component **con** render bên trong `DialogContent` (Radix unmount khi đóng → tự reset), **không** `setState` trong `useEffect` để reset — React Compiler lint chặn.
- Bí mật hiện một lần (API key, mật khẩu tạm) dùng `SecretReveal`, hộp thoại không tự đóng.
- Biến `NEXT_PUBLIC_*` nhúng vào bundle **lúc build**. Đọc qua `lib/api/config.ts`, không `process.env` rải rác.

## Trạng thái thiết bị

`status` có bốn giá trị và một máy trạng thái (xem [`project-overview.md`](../project-overview.md)). Giao diện phải **phản ánh máy trạng thái**, không để người dùng bấm rồi mới nhận 409:

- Nút "Thanh lý" **disable** khi `status = IN_USE`, kèm lý do "thu hồi trước".
- Nút "Cấp phát" chỉ hiện khi `IN_STOCK`.
- Gặp `409 DEVICE_STATE_CONFLICT` thì **tải lại bản ghi và nói rõ có người vừa thao tác** — đừng im lặng retry.

Badge trạng thái ở `components/common/status-badge.tsx`, màu gom một chỗ — bốn trạng thái là bốn màu cố định, không tự chọn màu ở từng màn.

## Danh sách dài

API dùng cursor pagination. Dùng `useInfiniteQuery`, không tự dựng phân trang số trang. **Không** parse hay tự sinh `cursor`.

## Đặt tên

| | |
|---|---|
| File | kebab-case — `device-status-badge.tsx` |
| Component | PascalCase — `DeviceStatusBadge` |
| Hook | `use-` + kebab-case — `use-devices.ts` |
| Type | PascalCase, khớp tên resource trong API — `Device` |

## Không làm

- Sửa `components/ui/`
- `fetch` trực tiếp trong component
- Rẽ nhánh logic theo `error.message`
- Map `snake_case` sang `camelCase`
- Hard-code chuỗi tiếng Việt lặp ở nhiều nơi — gom về một chỗ (ví dụ nhãn trạng thái ở `status-badge.tsx`)
- Đưa token vào `localStorage` (khi có auth) — chốt cơ chế ở `api-contracts.md` mục "Còn phải chốt" trước
