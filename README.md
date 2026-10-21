# App chấm công — NgocTruong_2380602415

Ứng dụng Flutter và Web API ASP.NET Core nằm trong cùng dự án này.

## Chức năng giữ lại

- Đăng ký bằng tên đăng nhập, email, mật khẩu; tài khoản mới có quyền User.
- Đăng nhập bằng tên đăng nhập/email, mật khẩu và OTP gửi qua email.
- Phân quyền Admin, Staff, User và điều hướng đến trang tương ứng.
- Nhân viên vào/ra ca, xem lịch sử chấm công; quản trị viên xem, điều chỉnh, xóa bản ghi và đổi vai trò nhân viên.
- Chấm công bằng khuôn mặt, vị trí GPS, quét QR bằng camera hoặc ảnh; tạo QR và chia sẻ vị trí.
- Sau khi ra ca: chọn cảm xúc, ghi chú hoặc bỏ qua; cảm xúc đã lưu hiển thị trong lịch sử.

Đã gỡ chợ sản phẩm, danh mục, bảng tin, bài luyện 6–7 và các tiện ích cũ. Các bảng/migration cũ trong backend được giữ để bảo toàn cơ sở dữ liệu hiện có; chúng không còn API hoặc màn hình sử dụng.

## Chạy backend trong VS Code hoặc Visual Studio

Yêu cầu .NET SDK 10 và SQL Server theo chuỗi kết nối của máy bạn. Không đưa mật khẩu SMTP/JWT lên Git.

Từ thư mục gốc:

```powershell
dotnet run --project backend/NgocTruong_2380602415.Api --launch-profile http
```

Nếu lệnh báo không tìm thấy SDK trên máy hiện tại:

```powershell
& "$env:USERPROFILE\.dotnet\dotnet.exe" run --project backend/NgocTruong_2380602415.Api --launch-profile http
```

Swagger: http://localhost:5186/swagger. Nếu cổng đang được sử dụng, kiểm tra server đã chạy trước đó; không chạy hai bản cùng cổng. Sau khi sửa backend, dừng bản cũ bằng Ctrl+C trong terminal của nó và chạy lại.

Visual Studio: mở `backend/NgocTruong_2380602415.sln`, chọn API làm startup project.

CSDL hiện tại: `NgocTruong_2380602415_Practice`. Giữ nguyên dữ liệu và migration đã áp dụng. OTP cần cấu hình SMTP hợp lệ trong cấu hình riêng của backend; không thể kiểm tra nhận email chỉ bằng việc mở Swagger.

## Chạy app trong Android Studio

Mở chính thư mục dự án này, khởi động máy ảo rồi chạy `lib/main.dart`.

```powershell
flutter pub get
flutter run
```

`lib/config/config_url.dart` đọc `BASE_URL` từ `.env`; mặc định là `http://10.0.2.2:5186/api/` cho máy ảo Android. Với điện thoại thật, dùng địa chỉ backend điện thoại truy cập được hoặc URL HTTPS Conveyor, kết thúc bằng `/api/`, rồi khởi động lại app.

Tài khoản tự đăng ký là User. Admin cấp quyền Staff để test Dashboard nhân viên. Đăng ký mẫu khuôn mặt thực hiện sau khi đăng nhập; camera, GPS và QR cần quyền tương ứng trên thiết bị.

Khuôn mặt có hai nút **Check-in · Vào ca** và **Check-out · Ra ca**. Camera trước nhận diện trực tiếp trong app; nhìn thẳng và mỉm cười hoặc chớp mắt để xác nhận. Cần đăng ký mẫu trước lần đầu chấm công. Không chọn ảnh từ thư viện để nhận diện khuôn mặt.

QR có lựa chọn **Check-in** / **Check-out** trước khi quét. Chọn thao tác, đưa QR trước camera hoặc chọn ảnh QR. Sau mỗi lần xử lý, chọn lại thao tác nếu muốn quét tiếp để tránh gửi trùng. Sau Check-out thành công vẫn có đánh giá cảm xúc.

## Kiểm tra nhanh

1. Đăng ký email thật → gửi OTP → đăng nhập; thử OTP sai và thiếu OTP.
2. Kiểm tra từng quyền; Admin mở quản lý nhân viên và chấm công.
3. Staff vào ca → ra ca → chọn cảm xúc/ghi chú → xem lại trong lịch sử; thử Bỏ qua ở ca khác.
4. Đăng ký mẫu khuôn mặt và thử chấm công; kiểm tra vị trí GPS và chia sẻ bản đồ; thử QR bằng camera hoặc ảnh.
5. Admin điều chỉnh/xóa một bản ghi thử nghiệm, đổi vai trò tài khoản thử nghiệm.

Các lần test dữ liệu thật có thể tạo hoặc sửa bản ghi, nên dùng tài khoản thử nghiệm.

```powershell
flutter analyze --no-pub
flutter test --no-pub
& "$env:USERPROFILE\.dotnet\dotnet.exe" test backend/NgocTruong_2380602415.sln --artifacts-path "$env:TEMP\attendance-tests" -p:NuGetAudit=false
```

Backend tests dùng cơ sở dữ liệu SQLite riêng của bộ test, không ghi vào SQL Server đang dùng.

## OTP local để thử nghiệm

Máy hiện tại có thể bật `LocalOtp:Enabled` trong .NET User Secrets, kèm `LocalOtp:Codes` gồm 5 mã khác nhau, mỗi mã 6 chữ số. Chỉ môi trường Development sử dụng cấu hình này; mã không hiện trên app và không trả về API. Đây là chế độ thử nghiệm, không gửi email.

Nhập tài khoản → bấm Gửi OTP → tự nhập một mã đã cấu hình → đăng nhập. Vẫn kiểm tra mật khẩu, giới hạn 3 lần nhập sai, thời hạn 5 phút và hủy toàn bộ mã của yêu cầu sau khi đăng nhập thành công. Lần đăng nhập kế tiếp cần bấm Gửi OTP lại.

Muốn dùng email thật, chạy `backend/CAU_HINH_EMAIL.ps1` để nhập cấu hình Gmail; công cụ cũng tắt LocalOtp. Khởi động lại backend sau khi thay đổi cấu hình.
