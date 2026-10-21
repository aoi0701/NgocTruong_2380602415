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
    public async Task OtpService_failed_three_times_invalidates_code()
    {
        var emailService = new EmailService(
            new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build(),
            NullLogger<EmailService>.Instance);
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
        var emailService = new EmailService(
            new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build(),
            NullLogger<EmailService>.Instance);
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
        var emailService = new EmailService(
            new Microsoft.Extensions.Configuration.ConfigurationBuilder().Build(),
            NullLogger<EmailService>.Instance);
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
    }
}
