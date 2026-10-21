using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using NgocTruong_2380602415.Api.Controllers;

namespace NgocTruong_2380602415.Api.Tests;

public sealed class AttendanceCheckoutValidationTests
{
    [Theory]
    [InlineData(null)]
    [InlineData(" ")]
    [InlineData("unrecognized-qr")]
    [InlineData("HUTECH_ATTENDANCE_QR_")]
    public async Task Invalid_qr_checkout_keeps_shift_open(string? qrToken)
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        var id = await OpenShift(client);

        var response = await client.PostAsJsonAsync("/api/Attendance/check-out", new { method = "QR", qrToken });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        await AssertShiftState(client, id, false);
    }

    [Fact]
    public async Task Valid_qr_checkout_closes_existing_shift_and_rejects_second_checkout()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        var id = await OpenShift(client);
        var qrResponse = await client.GetAsync("/api/Attendance/active-qr");
        qrResponse.EnsureSuccessStatusCode();
        var qr = await Read(qrResponse);

        var response = await client.PostAsJsonAsync("/api/Attendance/check-out", new
        {
            method = " qr ", qrToken = qr.GetProperty("token").GetString(), notes = "Shift completed"
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        await AssertShiftState(client, id, true);
        var data = (await Read(response)).GetProperty("data");
        Assert.Equal("Dashboard", data.GetProperty("method").GetString());
        Assert.Equal("Shift opened; Shift completed", data.GetProperty("notes").GetString());
        var repeated = await client.PostAsJsonAsync("/api/Attendance/check-out", new
        {
            method = "QR", qrToken = qr.GetProperty("token").GetString()
        });
        Assert.Equal(HttpStatusCode.BadRequest, repeated.StatusCode);
        await AssertShiftState(client, id, true);
    }

    [Fact]
    public async Task Expired_registered_qr_checkout_keeps_shift_open()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        var id = await OpenShift(client);
        var token = $"expired-{Guid.NewGuid():N}";
        AttendanceController.ActiveQrCodes[token] = new QrCodeItem
        {
            Token = token, CreatedAt = DateTime.UtcNow.AddDays(-2), ExpiresAt = DateTime.UtcNow.AddDays(-1)
        };
        try
        {
            var response = await client.PostAsJsonAsync("/api/Attendance/check-out", new { method = "QR", qrToken = token });
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            await AssertShiftState(client, id, false);
        }
        finally
        {
            AttendanceController.ActiveQrCodes.TryRemove(token, out _);
        }
    }

    [Theory]
    [InlineData(null)]
    [InlineData(" ")]
    public async Task Face_checkout_requires_proof_before_closing_shift(string? faceProof)
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        var id = await OpenShift(client);

        var rejected = await client.PostAsJsonAsync("/api/Attendance/check-out", new { method = "Face", faceProof });
        Assert.Equal(HttpStatusCode.BadRequest, rejected.StatusCode);
        await AssertShiftState(client, id, false);

        var accepted = await client.PostAsJsonAsync("/api/Attendance/check-out", new
        {
            method = " face ", faceProof = "recognized-face-proof"
        });
        Assert.Equal(HttpStatusCode.OK, accepted.StatusCode);
        await AssertShiftState(client, id, true);
    }

    private static async Task<int> OpenShift(HttpClient client)
    {
        var response = await client.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "Dashboard", notes = "Shift opened"
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await Read(response)).GetProperty("data").GetProperty("id").GetInt32();
    }

    private static async Task AssertShiftState(HttpClient client, int id, bool closed)
    {
        var response = await client.GetAsync("/api/Attendance/my-history");
        response.EnsureSuccessStatusCode();
        var records = await Read(response);
        var record = Assert.Single(records.EnumerateArray(), item => item.GetProperty("id").GetInt32() == id);
        Assert.Equal(closed, record.GetProperty("checkOutTime").ValueKind != JsonValueKind.Null);
    }

    private static async Task<JsonElement> Read(HttpResponseMessage response) =>
        await response.Content.ReadFromJsonAsync<JsonElement>();
}
