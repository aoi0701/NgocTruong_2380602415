# NgocTruong_2380602415

Dự án Flutter hiện tại: chuyển đổi đơn vị, bấm giờ, báo thức, dịch thuật, thông tin nhóm/cá nhân và phần luyện bài 6–7.

## Chạy dự án

Mở chính thư mục này trong VS Code hoặc Android Studio, chọn thiết bị Android rồi chạy:

```powershell
flutter pub get
flutter run
```

Nếu chưa có thiết bị, mở máy ảo từ Android Studio Device Manager. Máy này có máy ảo `OnTap_Bai6_7`, có thể mở bằng `flutter emulators --launch OnTap_Bai6_7`.

## Cấu trúc

- `lib/`: toàn bộ mã nguồn; `lib/main.dart` vẫn là điểm khởi động gốc.
- `lib/practice/`: phần luyện bài 6–7 tích hợp trong cùng ứng dụng.
- `backend/`: Web API C# và kiểm thử backend phục vụ chính ứng dụng này; mở bằng Visual Studio.
- `assets/`, `image/`: tài nguyên ứng dụng.
- `android/`, `ios/`, `windows/`, `linux/`, `macos/`, `web/`: cấu hình các nền tảng của cùng dự án Flutter.
- `test/`, `integration_test/`: kiểm thử tự động.
- `pubspec.yaml`, `pubspec.lock`: thư viện và phiên bản đã khóa.
- `.git/`, `.gitignore`, `.metadata`, `analysis_options.yaml`, `.idea/`: quản lý mã nguồn, Flutter và cấu hình công cụ.

`build/`, `.dart_tool/` và `.flutter-plugins-dependencies` là dữ liệu sinh tự động. Chúng có thể xuất hiện lại khi chạy Flutter; đây không phải dự án khác.

## Mở phần luyện bài 6–7

Chọn biểu tượng mũ tốt nghiệp **Bài 6–7** trên thanh điều hướng. Có năm mục: bài viết, yêu thích, ghi chú SQLite, cài đặt và sản phẩm. Bài viết và sản phẩm có thêm/sửa/xóa trên máy chủ, tìm theo ID; sản phẩm có tìm tên qua API. Các phần API/JSON, Provider, sắp xếp, yêu thích và giao diện tối dùng chung trong module. Nút quay lại đưa về ứng dụng gốc.

Nguồn mặc định `https://jsonplaceholder.typicode.com/posts` và dữ liệu mẫu chỉ dùng đọc/luyện yêu thích. Chọn backend của dự án để thử ghi dữ liệu bền vào SQL Server.

## Chạy backend và Swagger

1. Mở `backend/NgocTruong_2380602415.sln` bằng Visual Studio có hỗ trợ .NET 10. Chọn `NgocTruong_2380602415.Api` làm Startup Project, profile **http**, rồi F5. Máy hiện tại đã có SDK .NET 10 và SQL Server instance `MSSQLSERVER01`.
2. Mở `http://localhost:5186/swagger`. Chọn một dòng GET/POST/PUT/DELETE → **Try it out** → nhập dữ liệu → **Execute**.
3. Chạy Flutter trên máy ảo Android. Vào **Bài 6–7 → Cài đặt → Backend máy ảo**. Nút này lưu `http://10.0.2.2:5186/api/posts`; app tự suy ra `/api/products` cùng máy chủ.
4. Thử tạo bài viết, sửa và xóa; sang **Sản phẩm** thêm/sửa/xóa, tìm tên và tìm ID. Tải lại để kiểm tra dữ liệu từ server.

Cũng có thể chạy backend bằng terminal tại thư mục gốc:

```powershell
dotnet run --project backend/NgocTruong_2380602415.Api --launch-profile http
```

Kết nối mặc định trong `backend/NgocTruong_2380602415.Api/appsettings.json` dùng Windows Authentication tới `.\MSSQLSERVER01`. Backend chỉ khởi tạo database `NgocTruong_2380602415_Practice`, thêm ba bài viết và ba sản phẩm khi tạo database lần đầu. Xóa hết dữ liệu rồi khởi động lại sẽ không tự thêm mẫu lại. Không cần tạo bảng thủ công. Nếu đổi máy, sửa tên SQL Server instance trong chuỗi kết nối; giữ tên database luyện tập này.

Trên **máy Android thật hoặc qua Internet**, chạy backend bằng Visual Studio và lấy URL HTTPS của Conveyor. Trong Cài đặt của app, nhập đầy đủ `https://<địa-chỉ-conveyor>/api/posts` rồi lưu. App tự suy ra `/api/products`; cần backend có cả hai endpoint. Không dùng `localhost` trên điện thoại để trỏ về máy tính. Cấu hình HTTP cục bộ chỉ cho phép máy ảo `10.0.2.2` và loopback; các máy chủ khác cần HTTPS. Kết nối Conveyor phải thử riêng sau khi mở tunnel; kiểm thử cục bộ không chứng minh tunnel đang hoạt động.

| API | Mục đích |
|---|---|
| `GET /api/posts`, `GET /api/posts/{id}` | Danh sách/chi tiết bài viết; danh sách hỗ trợ `?search=` |
| `POST /api/posts`, `PUT /api/posts/{id}`, `DELETE /api/posts/{id}` | Thêm/sửa/xóa bài viết |
| `GET /api/products?name=Trà`, `GET /api/products/{id}` | Tìm sản phẩm theo tên/ID |
| `POST /api/products`, `PUT /api/products/{id}`, `DELETE /api/products/{id}` | Thêm/sửa/xóa sản phẩm |

JSON bài viết gồm `id`, `userId`, `title`, `body`; sản phẩm gồm `id`, `name`, `description`, `price`. Khi POST/PUT gửi các trường trừ `id`; ID nằm trên URL khi sửa. Swagger có schema và biểu mẫu thử sẵn. Backend luyện tập hiện chưa có đăng nhập/phân quyền.

## Kiểm tra và build

```powershell
flutter analyze
flutter test
flutter build apk --debug
dotnet test backend/NgocTruong_2380602415.sln
```

APK được tạo tại `build/app/outputs/flutter-apk/app-debug.apk`. Kiểm thử thiết bị: `flutter test integration_test/practice_smoke_test.dart -d <device-id>`.

Kiểm thử Android với backend thật (khởi động backend trước): `flutter test integration_test/backend_crud_smoke_test.dart -d emulator-5554`. Kiểm thử này tạo dữ liệu riêng, thử UI và đọc lại qua API rồi dọn dữ liệu vừa tạo; không xóa dữ liệu mẫu. Chạy kiểm thử sẽ cài bản ứng dụng phục vụ kiểm thử lên thiết bị. Sau đó dùng `flutter run` để mở lại bản chạy thông thường.

Provider quản lý trạng thái khi chạy; SharedPreferences lưu cài đặt/yêu thích, SQLite lưu ghi chú, SQL Server lưu bài viết/sản phẩm của backend. Các kiểm thử Flutter tự động dùng dữ liệu cô lập; kiểm thử backend dùng SQLite quan hệ và không cần sửa database SQL Server của bạn.

## Luồng cần hiểu

```text
URL trong Cài đặt
    → PostsProvider.load(endpoint)
    → PostApi.fetchPosts(endpoint)
    → HTTP GET → JSON → Post.fromJson
    → Provider.notifyListeners
    → màn hình danh sách/chi tiết

Bấm trái tim → FavoritesProvider (nguồn + ID) → PreferencesStore → SharedPreferences
Thêm/sửa/xóa ghi chú → NotesProvider → NotesRepository → SQLite
Đổi giao diện/URL → SettingsProvider → PreferencesStore → SharedPreferences
```

Provider giữ trạng thái và thông báo giao diện. SharedPreferences/SQLite mới là nơi giữ dữ liệu sau khi đóng app. Đọc được hai luồng này thì khi đề đổi đối tượng dữ liệu, bạn biết thay ở đâu.

## Bản đồ code

| File | Vai trò | Khi nào sửa? |
|---|---|---|
| `lib/main.dart` | Điểm khởi động ứng dụng gốc, `Alarm.init()` | Khởi tạo dịch vụ dùng cho toàn bộ app |
| `lib/HomeScreen.dart` | GNav của ứng dụng gốc, mở route **Bài 6–7** | Đổi mục mở module, giữ các tab gốc |
| `lib/practice/practice_entry.dart` | Khởi tạo SharedPreferences, SQLite và dependency khi vào phần luyện tập | Thêm dependency của module, xử lý lỗi khởi tạo |
| `lib/practice/app.dart` | Cung cấp Provider, theme, điều hướng năm mục, đồng bộ nguồn yêu thích/sản phẩm | Thêm màn hình/tab hoặc trạng thái dùng chung |
| `lib/practice/features/posts/post.dart` | Model, `fromJson`, `toJson` | Đề đổi dữ liệu hoặc tên trường |
| `lib/practice/features/posts/post_api.dart` | HTTP GET/POST/PUT/DELETE, JSON, timeout, lỗi | Đổi hợp đồng API |
| `lib/practice/features/posts/posts_provider.dart` | Tải, lọc, sắp xếp, chống phản hồi cũ | Thêm bộ lọc, phân trang, thống kê |
| `lib/practice/screens/posts_screen.dart` | Danh sách, chi tiết, yêu thích, trạng thái tải/lỗi/rỗng | Thay bố cục hoặc thêm thao tác |
| `lib/practice/screens/post_editor_screen.dart` | Biểu mẫu tạo/sửa bài viết, kiểm tra dữ liệu | Thêm trường hoặc quy tắc nhập |
| `lib/practice/features/products/` | Model, HTTP, Provider, màn hình và form sản phẩm | Đổi trường dữ liệu, tìm kiếm hoặc thao tác sản phẩm |
| `backend/NgocTruong_2380602415.Api/Controllers/` | Endpoint bài viết/sản phẩm và tìm kiếm SQL | Thêm API nâng cao |
| `lib/practice/features/settings/preferences_store.dart` | Đọc/ghi cài đặt và snapshots theo nguồn | Thêm cài đặt hoặc dữ liệu nhỏ mới |
| `lib/practice/features/settings/favorites_provider.dart` | Yêu thích của nguồn đang chọn, `setSource` | Đổi quy tắc yêu thích |
| `lib/practice/features/settings/settings_provider.dart` | Giao diện và endpoint | Thêm cài đặt dùng chung |
| `lib/practice/features/settings/settings_screen.dart` | Biểu mẫu đổi cài đặt | Thêm lựa chọn cho người dùng |
| `lib/practice/features/notes/note.dart` | Model ghi chú/Map SQLite | Đổi trường dữ liệu ghi chú |
| `lib/practice/features/notes/notes_repository.dart` | Tạo bảng và SQL helpers CRUD | Đổi bảng, thêm truy vấn |
| `lib/practice/features/notes/notes_provider.dart` | Điều phối SQLite và giao diện | Thêm logic ghi chú |
| `lib/practice/features/notes/notes_screen.dart` | Danh sách và biểu mẫu ghi chú | Đổi form hoặc cách trình bày |

Các kiểm thử nằm trong `test/practice/`; smoke test Android ở `integration_test/practice_smoke_test.dart`. Import mã của module bằng `package:Nhom_3_nguoi/practice/...`. Hướng dẫn được gộp trong README.md này.

## Yêu thích theo nguồn

`FavoritesProvider` bắt đầu từ endpoint đã lưu. Khi đổi nguồn bài viết, `app.dart` gọi `setSource(endpoint)` hoặc `setSource('sample://posts')`. Mỗi nguồn có snapshots riêng trong SharedPreferences; đổi nguồn không xóa các nguồn khác. `toggle` giữ nguồn tại thời điểm bấm kể cả khi thao tác phải chờ ghi. Nếu sửa đối tượng dữ liệu hoặc quy tắc định danh, giữ cả nguồn và ID để không trộn bài từ hai backend.

## Đề thay đối tượng dữ liệu

Sản phẩm `id`, `name`, `price`, `description` đã có ở `features/products/` và backend. Nếu đề đổi sang đối tượng khác, dùng quy trình:

1. Tạo model Product với đúng kiểu, `fromJson`/`toJson`; không chỉ đổi tên lớp Post.
2. Sửa service đọc đúng JSON server cung cấp. Nếu phản hồi bọc trong `data`, lấy đúng mảng bên trong.
3. Sửa Provider từ `List<Post>` sang loại mới; đổi tìm kiếm/sắp xếp cho trường sản phẩm.
4. Sửa danh sách và chi tiết hiển thị `name`, `price`, `description`.
5. Nếu lưu yêu thích, sửa phần lưu/đọc snapshot tương ứng; dùng key lưu trữ mới để không trộn dữ liệu cũ.
6. Chạy analyze và test; thử cả dữ liệu rỗng, lỗi mạng và giá trị thiếu.

## Các dạng nâng cao có thể luyện từ nền này

Đây là bài luyện, không phải dự đoán đề thầy.

| Yêu cầu | Nơi sửa | Điều cần kiểm tra |
|---|---|---|
| Lọc theo userId hoặc trạng thái | PostsProvider, thêm lựa chọn ở PostsScreen | Bỏ lọc trả lại dữ liệu, kết hợp tìm kiếm không sai |
| Phân trang | PostApi + PostsProvider + list | Không tải trùng, hết dữ liệu, tải thêm lỗi |
| Thống kê tổng/đã hoàn thành | NotesProvider + NotesScreen | Cập nhật sau thêm/sửa/xóa/toggle |
| Tìm kiếm ghi chú | NotesProvider hoặc repository | Giữ nguyên danh sách gốc, xử lý từ khóa rỗng |
| Mở rộng CRUD server với trường mới | Model + backend + PostApi/ProductApi + form + Provider | Đúng URL/body/header và mã thành công; chỉ sửa UI khi server xác nhận |
| Ghi chú có hạn hoàn thành | Note + schema DB + form | Tăng version DB và viết `onUpgrade`; không xóa DB để giả lập migration |
| Lưu lịch sử API/offline cache | Repository mới + PostsProvider | Phân biệt dữ liệu đã lưu với dữ liệu đang mới tải |
| Đổi đơn vị nhiệt độ | Model/provider thời tiết + UI | Giữ giá trị gốc, chuyển đổi khi hiển thị để tránh đổi qua lại bị sai |

Khi thêm POST/PUT: `toJson()` tạo Map; `jsonEncode()` tạo chuỗi để gửi. Khi nhận: `jsonDecode()` tạo Map/List; `fromJson()` tạo model. Thêm header `Content-Type: application/json` khi server yêu cầu. Không mặc định mọi thao tác đều trả HTTP 200: POST có thể trả 201, DELETE có thể trả 204 không có body; làm theo hợp đồng backend.

JSONPlaceholder là API thử nghiệm; thao tác ghi của dịch vụ này không tạo kho dữ liệu bền cho app. Muốn kiểm tra CRUD server bền, dùng backend của bạn hoặc SQLite cho CRUD cục bộ.

## Tự luyện khoảng 30–45 phút

1. Chạy app, giải thích được `load()` đi qua những file nào.
2. Lưu hai bài yêu thích, thoát module rồi vào lại, sau đó đóng hẳn app và mở lại để kiểm tra. Thử đổi nguồn API/mẫu rồi đổi về; yêu thích từng nguồn phải còn.
3. Thêm ghi chú có dấu tiếng Việt và dấu nháy, sửa nội dung, đánh dấu xong, hủy xóa rồi xác nhận xóa.
4. Thêm bộ lọc theo userId hoặc thêm thống kê số ghi chú đã hoàn thành.
5. Nhập URL HTTPS sai endpoint, quan sát lỗi; dùng dữ liệu mẫu và thử tải API lại.
6. Đổi giao diện tối, gõ một URL chưa lưu rồi đổi theme; bản nháp phải còn.

Bạn cần biết sửa và giải thích code, vì đề có thể thay model, API hoặc cách quản lý trạng thái bắt buộc. Nếu thầy bắt buộc BLoC/GetX/Firebase, phần Provider hiện tại cần chuyển theo yêu cầu; bản này không triển khai ba thư viện trạng thái cùng lúc.

## Tài liệu chính thức

- [Flutter: HTTP và JSON](https://docs.flutter.dev/cookbook/networking/fetch-data)
- [Flutter: quản lý trạng thái Provider](https://docs.flutter.dev/data-and-backend/state-mgmt/simple)
- [SharedPreferences](https://pub.dev/packages/shared_preferences): API legacy dùng ở đây để khớp cú pháp bài học; plugin còn có API async mới. Không dùng làm kho dữ liệu quan trọng.
- [sqflite](https://pub.dev/packages/sqflite), [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi).
