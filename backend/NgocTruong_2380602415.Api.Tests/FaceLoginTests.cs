using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Tests;

public sealed class FaceLoginTests
{
    private static async Task<JsonElement> Read(HttpResponseMessage response)
    {
        return JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task LoginFace_missing_data_returns_400()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        // 1. Username rỗng
        var res1 = await client.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "",
            features = new Dictionary<string, double> { ["boxAspect"] = 1.0 }
        });
        Assert.Equal(HttpStatusCode.BadRequest, res1.StatusCode);
        var json1 = await Read(res1);
        Assert.False(json1.GetProperty("status").GetBoolean());

        // 2. Features và FaceVectorJson đều null/rỗng
        var res2 = await client.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff"
        });
        Assert.Equal(HttpStatusCode.BadRequest, res2.StatusCode);
        var json2 = await Read(res2);
        Assert.False(json2.GetProperty("status").GetBoolean());

        // 3. User có profile nhưng gửi features không chứa đặc trưng hợp lệ
        using (var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456"))
        {
            await staffClient.PostAsJsonAsync("/api/Attendance/enroll-face", new
            {
                faceVectorJson = JsonSerializer.Serialize(new Dictionary<string, double>
                {
                    ["boxAspect"] = 1.0,
                    ["eyeDistRatio"] = 0.35,
                    ["eyeToNoseRatio"] = 0.25,
                    ["noseToMouthRatio"] = 0.20
                })
            });
        }

        var res3 = await client.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff",
            features = new Dictionary<string, double> { ["invalidKey"] = 123.45 }
        });
        Assert.Equal(HttpStatusCode.BadRequest, res3.StatusCode);
    }

    [Fact]
    public async Task LoginFace_user_not_found_returns_404()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        var res = await client.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "nonexistent_employee",
            features = new Dictionary<string, double>
            {
                ["boxAspect"] = 1.0,
                ["eyeDistRatio"] = 0.35,
                ["eyeToNoseRatio"] = 0.25,
                ["noseToMouthRatio"] = 0.20
            }
        });

        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
        var json = await Read(res);
        Assert.False(json.GetProperty("status").GetBoolean());
        Assert.Equal("Không tìm thấy tài khoản với tên đăng nhập này.", json.GetProperty("message").GetString());
    }

    [Fact]
    public async Task LoginFace_no_face_profile_returns_404_with_NO_FACE_PROFILE_code()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        // Tài khoản 'staff' tồn tại nhưng chưa đăng ký mẫu khuôn mặt
        var res = await client.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff",
            features = new Dictionary<string, double>
            {
                ["boxAspect"] = 1.0,
                ["eyeDistRatio"] = 0.35,
                ["eyeToNoseRatio"] = 0.25,
                ["noseToMouthRatio"] = 0.20
            }
        });

        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);
        var json = await Read(res);
        Assert.False(json.GetProperty("status").GetBoolean());
        Assert.Equal("NO_FACE_PROFILE", json.GetProperty("code").GetString());
        Assert.Contains("chưa đăng ký mẫu khuôn mặt", json.GetProperty("message").GetString()!);
    }

    [Fact]
    public async Task LoginFace_mismatch_face_returns_400()
    {
        using var database = new TestDatabase();
        using var app = database.Open();

        // Đăng ký mẫu chuẩn cho staff
        using (var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456"))
        {
            var enrollRes = await staffClient.PostAsJsonAsync("/api/Attendance/enroll-face", new
            {
                faceVectorJson = JsonSerializer.Serialize(new Dictionary<string, double>
                {
                    ["boxAspect"] = 1.0,
                    ["eyeDistRatio"] = 0.35,
                    ["eyeToNoseRatio"] = 0.25,
                    ["noseToMouthRatio"] = 0.20
                })
            });
            Assert.Equal(HttpStatusCode.OK, enrollRes.StatusCode);
        }

        // Thử login với khuôn mặt khác biệt lớn (similarity < 0.65)
        using var anonClient = app.CreateClient();
        var failRes = await anonClient.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff",
            features = new Dictionary<string, double>
            {
                ["boxAspect"] = 1.8,
                ["eyeDistRatio"] = 0.8,
                ["eyeToNoseRatio"] = 0.7,
                ["noseToMouthRatio"] = 0.6
            }
        });

        Assert.Equal(HttpStatusCode.BadRequest, failRes.StatusCode);
        var json = await Read(failRes);
        Assert.False(json.GetProperty("status").GetBoolean());
        Assert.Equal("Khuôn mặt không khớp với mẫu đã đăng ký của tài khoản.", json.GetProperty("message").GetString());
    }

    [Fact]
    public async Task LoginFace_matching_face_returns_jwt_and_correct_role_and_allows_authenticated_calls()
    {
        using var database = new TestDatabase();
        using var app = database.Open();

        var registeredVector = new Dictionary<string, double>
        {
            ["boxAspect"] = 1.0,
            ["eyeDistRatio"] = 0.35,
            ["eyeToNoseRatio"] = 0.25,
            ["noseToMouthRatio"] = 0.20
        };

        // 1. Staff đăng ký mẫu khuôn mặt
        using (var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456"))
        {
            var enrollRes = await staffClient.PostAsJsonAsync("/api/Attendance/enroll-face", new
            {
                faceVectorJson = JsonSerializer.Serialize(registeredVector)
            });
            Assert.Equal(HttpStatusCode.OK, enrollRes.StatusCode);
        }

        // 2. Staff đăng nhập bằng khuôn mặt khớp hoàn toàn
        using var anonClient = app.CreateClient();
        var successRes = await anonClient.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff",
            features = registeredVector
        });

        Assert.Equal(HttpStatusCode.OK, successRes.StatusCode);
        var successJson = await Read(successRes);
        Assert.True(successJson.GetProperty("status").GetBoolean());
        Assert.Equal("Đăng nhập bằng khuôn mặt thành công", successJson.GetProperty("message").GetString());
        Assert.Equal("Staff", successJson.GetProperty("role").GetString());
        var token = successJson.GetProperty("token").GetString();
        Assert.False(string.IsNullOrWhiteSpace(token));

        // 3. Sử dụng token nhận diện khuôn mặt để gọi API yêu cầu xác thực
        using var faceAuthClient = app.CreateClient();
        faceAuthClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var myHistoryRes = await faceAuthClient.GetAsync("/api/Attendance/my-history");
        Assert.Equal(HttpStatusCode.OK, myHistoryRes.StatusCode);

        // 4. Đăng nhập bằng email của user thay vì username
        var emailLoginRes = await anonClient.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff@example.com",
            features = registeredVector
        });
        Assert.Equal(HttpStatusCode.OK, emailLoginRes.StatusCode);

        // 5. Đăng nhập truyền faceVectorJson dạng chuỗi JSON
        var jsonVectorRes = await anonClient.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff",
            faceVectorJson = JsonSerializer.Serialize(registeredVector)
        });
        Assert.Equal(HttpStatusCode.OK, jsonVectorRes.StatusCode);

        // 6. Đăng nhập với độ lệch nhỏ trong ngưỡng chấp nhận (similarity >= 0.65)
        var slightVariation = new Dictionary<string, double>
        {
            ["boxAspect"] = 1.03,
            ["eyeDistRatio"] = 0.36,
            ["eyeToNoseRatio"] = 0.24,
            ["noseToMouthRatio"] = 0.21
        };
        var closeRes = await anonClient.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "staff",
            features = slightVariation
        });
        Assert.Equal(HttpStatusCode.OK, closeRes.StatusCode);
    }

    [Fact]
    public async Task LoginFace_admin_face_login_returns_admin_role()
    {
        using var database = new TestDatabase();
        using var app = database.Open();

        var adminVector = new Dictionary<string, double>
        {
            ["boxAspect"] = 1.15,
            ["eyeDistRatio"] = 0.38,
            ["eyeToNoseRatio"] = 0.26,
            ["noseToMouthRatio"] = 0.22
        };

        // Đăng ký mẫu cho Admin
        using (var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456"))
        {
            var enrollRes = await adminClient.PostAsJsonAsync("/api/Attendance/enroll-face", new
            {
                faceVectorJson = JsonSerializer.Serialize(adminVector)
            });
            Assert.Equal(HttpStatusCode.OK, enrollRes.StatusCode);
        }

        // Đăng nhập khuôn mặt Admin
        using var anonClient = app.CreateClient();
        var res = await anonClient.PostAsJsonAsync("/api/Authenticate/login-face", new
        {
            username = "admin",
            features = adminVector
        });

        Assert.Equal(HttpStatusCode.OK, res.StatusCode);
        var json = await Read(res);
        Assert.True(json.GetProperty("status").GetBoolean());
        Assert.Equal("Admin", json.GetProperty("role").GetString());
        var token = json.GetProperty("token").GetString();
        Assert.False(string.IsNullOrWhiteSpace(token));

        // Token Admin có thể truy cập endpoint Admin: GET /api/Attendance/all
        using var faceAdminClient = app.CreateClient();
        faceAdminClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        var allRes = await faceAdminClient.GetAsync("/api/Attendance/all");
        Assert.Equal(HttpStatusCode.OK, allRes.StatusCode);
    }
}
