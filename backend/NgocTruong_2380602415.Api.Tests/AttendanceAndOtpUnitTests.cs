using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Tests;

public class AttendanceAndOtpUnitTests
{
    [Fact]
    public async Task EmailService_unconfigured_throws_exception()
    {
        var emailService = new EmailService(
            new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build(),
            NullLogger<EmailService>.Instance);

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            emailService.SendOtpEmailAsync("user@example.com", "testuser", "123456"));
    }

    [Fact]
    public async Task OtpService_when_email_fails_does_not_store_otp()
    {
        var failingEmailService = new FailingEmailService();
        var otpService = new OtpService(failingEmailService, NullLogger<OtpService>.Instance);
        var user = "user_failing_email";

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            otpService.GenerateAndSendOtpAsync(user, "test@example.com"));

        // Tuyệt đối không tạo OTP hợp lệ cho client và không lưu vào memory khi gửi mail lỗi
        var activeOtp = otpService.GetActiveOtpForTesting(user);
        Assert.Null(activeOtp);
    }

    [Fact]
    public async Task RequestOtp_when_email_service_fails_returns_503()
    {
        using var database = new TestDatabase();
        using var app = database.Open(simulateEmailFailure: true);
        using var client = app.CreateClient();

        var response = await client.PostAsJsonAsync("/api/Authenticate/request-otp", new { username = "admin" });
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);

        var body = JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync());
        Assert.False(body.GetProperty("status").GetBoolean());
        Assert.Equal(
            "Không thể gửi email OTP: Dịch vụ email chưa được cấu hình hoặc gặp sự cố kết nối SMTP. Vui lòng kiểm tra cấu hình SmtpSettings trong appsettings.json.",
            body.GetProperty("message").GetString());

        var otpService = app.Services.GetRequiredService<IOtpService>();
        Assert.Null(otpService.GetActiveOtpForTesting("admin"));
    }

    [Fact]
    public async Task OtpService_race_condition_concurrency_lock_single_winner()
    {
        var emailService = new TestEmailService();
        var otpService = new OtpService(emailService, NullLogger<OtpService>.Instance);
        var user = "race_user";
        var code = await otpService.GenerateAndSendOtpAsync(user, "race@example.com");

        // Chạy 10 luồng đồng thời cố gắng xác thực cùng mã OTP
        var tasks = Enumerable.Range(0, 10)
            .Select(_ => Task.Run(() => otpService.ValidateOtp(user, code)))
            .ToArray();

        var results = await Task.WhenAll(tasks);
        var successCount = results.Count(r => r.IsValid);
        var failCount = results.Count(r => !r.IsValid);

        // Duy nhất 1 luồng thành công, 9 luồng còn lại bị từ chối do OTP đã bị hủy ngay lập tức
        Assert.Equal(1, successCount);
        Assert.Equal(9, failCount);
    }

    [Fact]
    public async Task OtpService_failed_three_times_invalidates_code()
    {
        var emailService = new TestEmailService();
        var otpService = new OtpService(emailService, NullLogger<OtpService>.Instance);

        var user = "testuser_maxattempts";
        var generatedCode = await otpService.GenerateAndSendOtpAsync(user, "test@example.com");

        // Attempt 1: wrong
        var (v1, msg1) = otpService.ValidateOtp(user, "000000");
        Assert.False(v1);
        Assert.Contains("2 lần", msg1);

        // Attempt 2: wrong
        var (v2, msg2) = otpService.ValidateOtp(user, "000000");
        Assert.False(v2);
        Assert.Contains("1 lần", msg2);

        // Attempt 3: wrong -> should invalidate
        var (v3, msg3) = otpService.ValidateOtp(user, "000000");
        Assert.False(v3);
        Assert.Contains("vô hiệu hóa", msg3);

        // Attempt 4: even with correct code now, should fail because invalidated
        var (v4, msg4) = otpService.ValidateOtp(user, generatedCode);
        Assert.False(v4);
        Assert.Contains("không tồn tại", msg4);
    }

    [Fact]
    public async Task OtpService_cooldown_sixty_seconds_enforced()
    {
        var emailService = new TestEmailService();
        var otpService = new OtpService(emailService, NullLogger<OtpService>.Instance);

        var user = "testuser_cooldown";
        await otpService.GenerateAndSendOtpAsync(user, "test@example.com");

        var (canSend, errorMsg, cooldownSec) = otpService.CheckCooldown(user);
        Assert.False(canSend);
        Assert.NotNull(cooldownSec);
        Assert.True(cooldownSec > 0 && cooldownSec <= 60);
        Assert.Contains("đợi", errorMsg);
    }

    [Fact]
    public async Task OtpService_single_use_consumed_immediately()
    {
        var emailService = new TestEmailService();
        var otpService = new OtpService(emailService, NullLogger<OtpService>.Instance);

        var user = "testuser_singleuse";
        var code = await otpService.GenerateAndSendOtpAsync(user, "test@example.com");

        // First verification: success
        var (v1, _) = otpService.ValidateOtp(user, code);
        Assert.True(v1);

        // Second verification with same code: fails (single use)
        var (v2, msg2) = otpService.ValidateOtp(user, code);
        Assert.False(v2);
        Assert.Contains("không tồn tại", msg2);
    }

    [Fact]
    public async Task Attendance_cannot_have_two_open_shifts_returns_409()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // Check-in ca 1
        var res1 = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        Assert.Equal(HttpStatusCode.OK, res1.StatusCode);

        // Check-in ca 2 khi ca 1 chưa check out -> 409 Conflict
        var res2 = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        Assert.Equal(HttpStatusCode.Conflict, res2.StatusCode);
        var body2 = JsonSerializer.Deserialize<JsonElement>(await res2.Content.ReadAsStringAsync());
        Assert.False(body2.GetProperty("status").GetBoolean());
        Assert.Equal(
            "Bạn đang có một ca làm việc chưa kết thúc. Vui lòng check-out ca hiện tại trước khi vào ca mới.",
            body2.GetProperty("message").GetString());

        // Check-out ca 1
        var checkOut = await staffClient.PostAsJsonAsync("/api/Attendance/check-out", new { method = "GPS" });
        Assert.Equal(HttpStatusCode.OK, checkOut.StatusCode);

        // Sau khi đã check-out ca trước, được phép check-in ca mới
        var res3 = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        Assert.Equal(HttpStatusCode.OK, res3.StatusCode);
    }

    [Fact]
    public async Task Attendance_invalid_method_rejected_with_400()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        var res = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "NFC_CARD",
            notes = "Thử dùng thẻ từ NFC"
        });
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        var body = JsonSerializer.Deserialize<JsonElement>(await res.Content.ReadAsStringAsync());
        Assert.False(body.GetProperty("status").GetBoolean());
        Assert.Contains("không hợp lệ", body.GetProperty("message").GetString());
    }

    [Fact]
    public async Task Attendance_qr_method_validation_and_admin_generation()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. QR thiếu qrToken -> 400
        var noTokenRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "QR",
            qrToken = ""
        });
        Assert.Equal(HttpStatusCode.BadRequest, noTokenRes.StatusCode);

        // 2. QR token giả mạo -> 400
        var fakeTokenRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "QR",
            qrToken = "RANDOM_FORGED_QR_TOKEN"
        });
        Assert.Equal(HttpStatusCode.BadRequest, fakeTokenRes.StatusCode);

        // 3. Admin sinh mã QR hợp lệ -> 200
        var genQrRes = await adminClient.PostAsync("/api/Attendance/generate-qr", null);
        Assert.Equal(HttpStatusCode.OK, genQrRes.StatusCode);
        var qrBody = JsonSerializer.Deserialize<JsonElement>(await genQrRes.Content.ReadAsStringAsync());
        var validToken = qrBody.GetProperty("token").GetString();
        Assert.NotNull(validToken);
        Assert.StartsWith("HUTECH_ATTENDANCE_QR_", validToken);

        // 4. Nhân viên check-in với mã QR đã sinh -> 200 OK
        var validQrRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "QR",
            qrToken = validToken
        });
        Assert.Equal(HttpStatusCode.OK, validQrRes.StatusCode);
    }

    [Fact]
    public async Task Attendance_face_method_validation()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // 1. Thiếu FaceProof -> 400
        var missingProofRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "Face",
            faceProof = ""
        });
        Assert.Equal(HttpStatusCode.BadRequest, missingProofRes.StatusCode);

        // 2. Có FaceProof hợp lệ -> 200 OK
        var validFaceRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "Face",
            faceProof = "LIVE_FACE_EMBEDDING_VECTOR_128D_OK"
        });
        Assert.Equal(HttpStatusCode.OK, validFaceRes.StatusCode);
    }

    [Fact]
    public async Task Attendance_checkout_without_prior_checkin_returns_400()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // Check out when there is no check-in record
        var checkOutRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-out", new
        {
            method = "GPS",
            notes = "Thử check-out mà chưa check-in"
        });

        Assert.Equal(HttpStatusCode.BadRequest, checkOutRes.StatusCode);
        var body = JsonSerializer.Deserialize<JsonElement>(await checkOutRes.Content.ReadAsStringAsync());
        Assert.False(body.GetProperty("status").GetBoolean());
        Assert.Equal(
            "Không tìm thấy ca làm việc đang mở để check-out. Vui lòng check-in vào ca trước.",
            body.GetProperty("message").GetString());
    }

    [Fact]
    public async Task Admin_adjust_attendance_with_reason_audit_persisted()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        var checkInRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        var rec = JsonSerializer.Deserialize<JsonElement>(await checkInRes.Content.ReadAsStringAsync()).GetProperty("data");
        var id = rec.GetProperty("id").GetInt32();

        // Staff không có quyền điều chỉnh -> 403 Forbidden
        var staffAdjustRes = await staffClient.PutAsJsonAsync($"/api/Attendance/{id}", new
        {
            reason = "Tự sửa giờ"
        });
        Assert.Equal(HttpStatusCode.Forbidden, staffAdjustRes.StatusCode);

        // Admin không cung cấp lý do (reason) -> 400 Bad Request
        var noReasonRes = await adminClient.PutAsJsonAsync($"/api/Attendance/{id}", new
        {
            reason = ""
        });
        Assert.Equal(HttpStatusCode.BadRequest, noReasonRes.StatusCode);

        // Admin điều chỉnh kèm lý do -> 200 OK
        var adjustRes = await adminClient.PutAsJsonAsync($"/api/Attendance/{id}", new
        {
            reason = "Quên bấm check out khi đổi ca",
            checkOutTime = DateTime.UtcNow
        });
        Assert.Equal(HttpStatusCode.OK, adjustRes.StatusCode);
        var updatedRec = JsonSerializer.Deserialize<JsonElement>(await adjustRes.Content.ReadAsStringAsync()).GetProperty("data");
        var notes = updatedRec.GetProperty("notes").GetString();
        Assert.Contains("[ĐIỀU CHỈNH bởi admin lúc", notes);
        Assert.Contains("Quên bấm check out khi đổi ca", notes);

        // Admin xóa bản ghi chấm công sai sót -> 200 OK
        var deleteRes = await adminClient.DeleteAsync($"/api/Attendance/{id}");
        Assert.Equal(HttpStatusCode.OK, deleteRes.StatusCode);
    }

    [Fact]
    public async Task Admin_get_employees_and_change_role_works()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // Staff không được xem danh sách admin -> 403
        var forbiddenRes = await staffClient.GetAsync("/api/Admin/employees");
        Assert.Equal(HttpStatusCode.Forbidden, forbiddenRes.StatusCode);

        // Admin xem danh sách nhân viên
        var empRes = await adminClient.GetAsync("/api/Admin/employees");
        Assert.Equal(HttpStatusCode.OK, empRes.StatusCode);
        var employees = JsonSerializer.Deserialize<JsonElement>(await empRes.Content.ReadAsStringAsync());
        Assert.True(employees.GetArrayLength() > 0);

        // Lấy user "user" và đổi vai trò thành "Staff"
        using var scope = app.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<Microsoft.AspNetCore.Identity.UserManager<NgocTruong_2380602415.Api.Models.User>>();
        var targetUser = await userManager.FindByNameAsync("user");
        Assert.NotNull(targetUser);

        var changeRoleRes = await adminClient.PostAsJsonAsync($"/api/Admin/employees/{targetUser.Id}/role", new
        {
            role = "Staff"
        });
        Assert.Equal(HttpStatusCode.OK, changeRoleRes.StatusCode);

        var roles = await userManager.GetRolesAsync(targetUser);
        Assert.Contains("Staff", roles);
    }

    [Fact]
    public async Task Attendance_face_enrollment_and_retrieval_works()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // 1. Đăng ký mẫu khuôn mặt
        var enrollRes = await staffClient.PostAsJsonAsync("/api/Attendance/enroll-face", new
        {
            faceVectorJson = "[0.123, -0.456, 0.789, 0.012]"
        });
        Assert.Equal(HttpStatusCode.OK, enrollRes.StatusCode);

        // 2. Lấy mẫu khuôn mặt để đối chiếu
        var getProfileRes = await staffClient.GetAsync("/api/Attendance/face-profile/staff");
        Assert.Equal(HttpStatusCode.OK, getProfileRes.StatusCode);
        var profile = JsonSerializer.Deserialize<JsonElement>(await getProfileRes.Content.ReadAsStringAsync());
        Assert.True(profile.GetProperty("status").GetBoolean());
        Assert.Equal("[0.123, -0.456, 0.789, 0.012]", profile.GetProperty("faceVectorJson").GetString());
    }

    [Fact]
    public async Task Attendance_anonymous_access_returns_401()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var anonClient = app.CreateClient();

        Assert.Equal(HttpStatusCode.Unauthorized, (await anonClient.GetAsync("/api/Attendance/my-history")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonClient.GetAsync("/api/Attendance/all")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonClient.PostAsJsonAsync("/api/Attendance/check-in", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonClient.PostAsJsonAsync("/api/Attendance/check-out", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonClient.PostAsJsonAsync("/api/Attendance/1/feedback", new { mood = "😄 Rất tốt" })).StatusCode);
    }

    [Fact]
    public async Task Attendance_submit_feedback_without_mood_returns_400()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // 1. Check in
        var checkInRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        Assert.Equal(HttpStatusCode.OK, checkInRes.StatusCode);
        var checkInData = JsonSerializer.Deserialize<JsonElement>(await checkInRes.Content.ReadAsStringAsync());
        int recordId = checkInData.GetProperty("data").GetProperty("id").GetInt32();

        // 2. Check out
        var checkOutRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-out", new { method = "GPS" });
        Assert.Equal(HttpStatusCode.OK, checkOutRes.StatusCode);

        // 3. Gửi feedback rỗng mood -> phải báo lỗi 400
        var emptyFeedbackRes = await staffClient.PostAsJsonAsync($"/api/Attendance/{recordId}/feedback", new
        {
            mood = "",
            notes = "Ca này ổn"
        });
        Assert.Equal(HttpStatusCode.BadRequest, emptyFeedbackRes.StatusCode);
    }

    [Fact]
    public async Task Attendance_submit_feedback_saves_mood_and_notes_and_retrieves_in_history()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // 1. Check-in
        var checkInRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856
        });
        Assert.Equal(HttpStatusCode.OK, checkInRes.StatusCode);
        var checkInData = JsonSerializer.Deserialize<JsonElement>(await checkInRes.Content.ReadAsStringAsync());
        int recordId = checkInData.GetProperty("data").GetProperty("id").GetInt32();

        // 2. Check-out
        var checkOutRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-out", new { method = "GPS" });
        Assert.Equal(HttpStatusCode.OK, checkOutRes.StatusCode);

        // 3. Gửi feedback hợp lệ: "😓 Mệt", "Hôm nay đông khách"
        var feedbackRes = await staffClient.PostAsJsonAsync($"/api/Attendance/{recordId}/feedback", new
        {
            mood = "😓 Mệt",
            notes = "Hôm nay đông khách"
        });
        Assert.Equal(HttpStatusCode.OK, feedbackRes.StatusCode);
        var feedbackData = JsonSerializer.Deserialize<JsonElement>(await feedbackRes.Content.ReadAsStringAsync());
        Assert.True(feedbackData.GetProperty("status").GetBoolean());
        Assert.Equal("😓 Mệt", feedbackData.GetProperty("data").GetProperty("feedbackMood").GetString());
        Assert.Equal("Hôm nay đông khách", feedbackData.GetProperty("data").GetProperty("feedbackNote").GetString());
        Assert.NotNull(feedbackData.GetProperty("data").GetProperty("feedbackTime").GetString());

        // 4. Lấy lịch sử cá nhân (my-history) -> kiểm tra feedback đã được lưu trong DB
        var historyRes = await staffClient.GetAsync("/api/Attendance/my-history");
        Assert.Equal(HttpStatusCode.OK, historyRes.StatusCode);
        var historyList = JsonSerializer.Deserialize<JsonElement>(await historyRes.Content.ReadAsStringAsync());
        Assert.True(historyList.GetArrayLength() > 0);

        var firstRecord = historyList[0];
        Assert.Equal("😓 Mệt", firstRecord.GetProperty("feedbackMood").GetString());
        Assert.Equal("Hôm nay đông khách", firstRecord.GetProperty("feedbackNote").GetString());
    }
}
