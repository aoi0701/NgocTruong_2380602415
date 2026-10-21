using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Tests;

public sealed class ApiContractTests
{
    [Fact]
    public async Task Swagger_exposes_only_auth_admin_and_attendance_including_feedback()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/swagger/index.html")).StatusCode);
        var document = await Read(await client.GetAsync("/swagger/v1/swagger.json"));
        var paths = document.GetProperty("paths");
        var controllers = paths.EnumerateObject()
            .Select(path => path.Name.Split('/')[2]).Distinct().Order().ToArray();
        Assert.Equal(new[] { "Admin", "Attendance", "Authenticate" }, controllers);
        Assert.True(paths.GetProperty("/api/Attendance/{id}/feedback").TryGetProperty("post", out _));
        Assert.True(paths.GetProperty("/api/Attendance/enroll-face").TryGetProperty("post", out _));
        Assert.True(paths.GetProperty("/api/Attendance/generate-qr").TryGetProperty("post", out _));
        Assert.True(paths.GetProperty("/api/Attendance/check-in").TryGetProperty("post", out _));
        Assert.True(paths.GetProperty("/api/Authenticate/request-otp").TryGetProperty("post", out _));
    }

    [Fact]
    public async Task Authenticate_register_login_and_roles_work()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        // Register new user
        var regResponse = await client.PostAsJsonAsync("/api/Authenticate/register", new
        {
            username = "teststudent",
            email = "student@example.com",
            password = "Student@123456",
            initials = "STU",
            role = "User"
        });
        var regBody = await regResponse.Content.ReadAsStringAsync();
        Assert.True(regResponse.IsSuccessStatusCode, $"Register failed: {regBody}");

        // Duplicate registration returns 400
        var dupResponse = await client.PostAsJsonAsync("/api/Authenticate/register", new
        {
            username = "teststudent",
            email = "student2@example.com",
            password = "Student@123456",
            initials = "STU",
            role = "User"
        });
        Assert.Equal(HttpStatusCode.BadRequest, dupResponse.StatusCode);

        // Yêu cầu OTP cho tài khoản
        var otpReqRes = await client.PostAsJsonAsync("/api/Authenticate/request-otp", new { username = "teststudent" });
        Assert.Equal(HttpStatusCode.OK, otpReqRes.StatusCode);
        var otpReqBody = await Read(otpReqRes);
        Assert.True(otpReqBody.GetProperty("status").GetBoolean());
        // Bảo mật: không lộ trường 'otp' trong response JSON
        Assert.False(otpReqBody.TryGetProperty("otp", out _));

        var otpService = app.Services.GetRequiredService<IOtpService>();
        var validOtp = otpService.GetActiveOtpForTesting("teststudent");
        Assert.NotNull(validOtp);

        // Login with valid credentials and OTP
        var loginResponse = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "teststudent",
            password = "Student@123456",
            otp = validOtp
        });
        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
        var loginBody = await Read(loginResponse);
        Assert.True(loginBody.GetProperty("status").GetBoolean());
        var token = loginBody.GetProperty("token").GetString();
        Assert.NotNull(token);
        Assert.NotEmpty(token!);
        Assert.Equal("User", loginBody.GetProperty("role").GetString());

        // Login with wrong password returns 401
        var wrongPass = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "teststudent",
            password = "WrongPassword123",
            otp = "999999"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, wrongPass.StatusCode);
    }

    [Fact]
    public async Task Register_cannot_self_assign_admin_or_staff_role()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        // 1. Cố ý đăng ký tài khoản với vai trò Admin -> Thành công nhưng chỉ được cấp vai trò User
        var adminRegRes = await client.PostAsJsonAsync("/api/Authenticate/register", new
        {
            username = "hackadmin",
            email = "hackadmin@example.com",
            password = "Hacked@123456",
            initials = "HCK",
            role = "Admin"
        });
        Assert.True(adminRegRes.IsSuccessStatusCode);

        // 2. Cố ý đăng ký với vai trò Staff -> Thành công nhưng chỉ được cấp vai trò User
        var staffRegRes = await client.PostAsJsonAsync("/api/Authenticate/register", new
        {
            username = "validstaff",
            email = "staffmember@example.com",
            password = "Staff@123456",
            initials = "STF",
            role = "Staff"
        });
        Assert.True(staffRegRes.IsSuccessStatusCode);

        // Kiểm tra trong DB: Cả hai tài khoản đều chỉ có vai trò User
        using var scope = app.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<Microsoft.AspNetCore.Identity.UserManager<NgocTruong_2380602415.Api.Models.User>>();

        var hackAdmin = await userManager.FindByNameAsync("hackadmin");
        Assert.NotNull(hackAdmin);
        var adminRoles = await userManager.GetRolesAsync(hackAdmin);
        Assert.Contains("User", adminRoles);
        Assert.DoesNotContain("Admin", adminRoles);

        var validStaff = await userManager.FindByNameAsync("validstaff");
        Assert.NotNull(validStaff);
        var staffRoles = await userManager.GetRolesAsync(validStaff);
        Assert.Contains("User", staffRoles);
        Assert.DoesNotContain("Staff", staffRoles);
    }

    [Fact]
    public async Task Login_missing_or_invalid_otp_is_rejected()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        // 1. Đăng nhập đúng user/pass nhưng THIẾU OTP -> 400 BadRequest
        var noOtpRes = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "admin",
            password = "Admin@123456"
        });
        Assert.Equal(HttpStatusCode.BadRequest, noOtpRes.StatusCode);

        // 2. Yêu cầu sinh mã OTP hợp lệ
        await client.PostAsJsonAsync("/api/Authenticate/request-otp", new { username = "admin" });

        // 3. Đăng nhập với SAI OTP -> 400 BadRequest
        var wrongOtpRes = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "admin",
            password = "Admin@123456",
            otp = "000000"
        });
        Assert.Equal(HttpStatusCode.BadRequest, wrongOtpRes.StatusCode);

        // 4. Đăng nhập với sai password -> 401 Unauthorized
        var wrongPassRes = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "admin",
            password = "IncorrectPassword",
            otp = "000000"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, wrongPassRes.StatusCode);
    }

    [Fact]
    public async Task Attendance_gps_checkin_outside_radius_is_rejected()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // 1. Tọa độ nằm ở Quận 1 TP.HCM (~15km so với HUTECH Khu E Quận 9) -> Bị từ chối 400 BadRequest
        var outsideRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.7769,
            longitude = 106.7009,
            notes = "Đang ở Nhà thờ Đức Bà"
        });
        Assert.Equal(HttpStatusCode.BadRequest, outsideRes.StatusCode);
        var outsideBody = await Read(outsideRes);
        Assert.False(outsideBody.GetProperty("status").GetBoolean());
        Assert.Contains("bán kính", outsideBody.GetProperty("message").GetString()!);

        // 2. Thiếu tọa độ kinh/vĩ độ khi method là GPS -> 400 BadRequest
        var missingCoordRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = (double?)null,
            longitude = (double?)null
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingCoordRes.StatusCode);
    }

    [Fact]
    public async Task Attendance_valid_checkin_persists_and_readable_via_my_history_and_checkout_and_all()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. Check-in hợp lệ ngay tại HUTECH Campus E1 (10.8552, 106.7856) -> 200 OK
        var checkInRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856,
            locationName = "HUTECH Campus E1",
            deviceInfo = "Flutter Test Runner",
            notes = "Ca sáng đúng giờ"
        });
        Assert.Equal(HttpStatusCode.OK, checkInRes.StatusCode);
        var checkInBody = await Read(checkInRes);
        Assert.True(checkInBody.GetProperty("status").GetBoolean());
        var recordData = checkInBody.GetProperty("data");
        var recordId = recordData.GetProperty("id").GetInt32();
        Assert.True(recordId > 0);
        Assert.Equal("Valid", recordData.GetProperty("status").GetString());

        // 2. Chống ghi trùng: Check-in lần 2 ngay lập tức trong vòng 5 phút -> 409 Conflict
        var dupCheckInRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        Assert.Equal(HttpStatusCode.Conflict, dupCheckInRes.StatusCode);

        // 3. Đọc lại lịch sử qua GET /api/Attendance/my-history
        var historyRes = await staffClient.GetAsync("/api/Attendance/my-history");
        Assert.Equal(HttpStatusCode.OK, historyRes.StatusCode);
        var historyItems = await Read(historyRes);
        Assert.True(historyItems.GetArrayLength() > 0);
        var firstItem = historyItems[0];
        Assert.Equal(recordId, firstItem.GetProperty("id").GetInt32());
        Assert.Equal("GPS", firstItem.GetProperty("method").GetString());

        // 4. Check-out ra ca: POST /api/Attendance/check-out -> 200 OK
        var checkOutRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-out", new
        {
            method = "GPS",
            notes = "Hoàn thành ca làm việc"
        });
        Assert.Equal(HttpStatusCode.OK, checkOutRes.StatusCode);
        var checkOutBody = await Read(checkOutRes);
        Assert.True(checkOutBody.GetProperty("status").GetBoolean());
        var updatedRecord = checkOutBody.GetProperty("data");
        Assert.NotNull(updatedRecord.GetProperty("checkOutTime").GetString());

        // 5. Admin gọi GET /api/Attendance/all -> 200 OK kèm thông tin user (username, email, initials)
        var allRes = await adminClient.GetAsync("/api/Attendance/all");
        Assert.Equal(HttpStatusCode.OK, allRes.StatusCode);
        var allList = await Read(allRes);
        Assert.True(allList.GetArrayLength() > 0);
        var adminViewItem = allList[0];
        Assert.Equal("staff", adminViewItem.GetProperty("userName").GetString());
        Assert.Equal("staff@example.com", adminViewItem.GetProperty("email").GetString());
        Assert.Equal("STF", adminViewItem.GetProperty("initials").GetString());

        // 6. User thông thường gọi GET /api/Attendance/all -> 403 Forbidden
        var forbiddenRes = await staffClient.GetAsync("/api/Attendance/all");
        Assert.Equal(HttpStatusCode.Forbidden, forbiddenRes.StatusCode);
    }

    private static async Task<JsonElement> Read(HttpResponseMessage response)
    {
        Assert.True(response.IsSuccessStatusCode || response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected JSON response; received HTTP {(int)response.StatusCode}.");
        return JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync());
    }
}
