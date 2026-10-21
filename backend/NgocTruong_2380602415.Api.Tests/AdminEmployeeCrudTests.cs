using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Tests;

public sealed class AdminEmployeeCrudTests
{
    private static async Task<JsonElement> Read(HttpResponseMessage response)
    {
        Assert.True(
            response.IsSuccessStatusCode ||
            response.StatusCode == HttpStatusCode.BadRequest ||
            response.StatusCode == HttpStatusCode.NotFound ||
            response.StatusCode == HttpStatusCode.Forbidden,
            $"Expected status handled; received HTTP {(int)response.StatusCode}.");
        return JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Admin_can_create_employee_with_default_staff_role()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. Tạo nhân viên không truyền role -> Mặc định là Staff
        var response = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "newstaff1",
            email = "newstaff1@example.com",
            password = "Password@123456",
            initials = "NST"
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await Read(response);
        Assert.True(body.GetProperty("status").GetBoolean());
        Assert.Equal("Staff", body.GetProperty("role").GetString());
        Assert.Equal("newstaff1", body.GetProperty("userName").GetString());
        Assert.Equal("newstaff1@example.com", body.GetProperty("email").GetString());
        var createdId = body.GetProperty("id").GetString();
        Assert.False(string.IsNullOrEmpty(createdId));

        // Không trả về mật khẩu hay password hash
        Assert.False(body.TryGetProperty("password", out _));
        Assert.False(body.TryGetProperty("passwordHash", out _));

        // Kiểm tra trong database
        using var scope = app.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var userInDb = await userManager.FindByNameAsync("newstaff1");
        Assert.NotNull(userInDb);
        var roles = await userManager.GetRolesAsync(userInDb);
        Assert.Contains("Staff", roles);
    }

    [Fact]
    public async Task Admin_create_employee_validates_required_fields_and_uniqueness()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. Thiếu username -> 400
        var emptyUserRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "",
            email = "user@test.com",
            password = "Password@123"
        });
        Assert.Equal(HttpStatusCode.BadRequest, emptyUserRes.StatusCode);

        // 2. Thiếu email -> 400
        var emptyEmailRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "validuser",
            email = "",
            password = "Password@123"
        });
        Assert.Equal(HttpStatusCode.BadRequest, emptyEmailRes.StatusCode);

        // 3. Email sai định dạng -> 400
        var invalidEmailRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "validuser",
            email = "not-an-email",
            password = "Password@123"
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalidEmailRes.StatusCode);

        // 4. Thiếu password -> 400
        var emptyPassRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "validuser",
            email = "valid@test.com",
            password = ""
        });
        Assert.Equal(HttpStatusCode.BadRequest, emptyPassRes.StatusCode);

        // 5. Role không hợp lệ -> 400
        var invalidRoleRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "validuser",
            email = "valid@test.com",
            password = "Password@123",
            role = "SuperAdmin"
        });
        Assert.Equal(HttpStatusCode.BadRequest, invalidRoleRes.StatusCode);

        // 6. Trùng Username đã có trong hệ thống (admin) -> 400
        var dupUserRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "admin",
            email = "other@example.com",
            password = "Password@123"
        });
        Assert.Equal(HttpStatusCode.BadRequest, dupUserRes.StatusCode);
        var dupUserBody = await Read(dupUserRes);
        Assert.False(dupUserBody.GetProperty("status").GetBoolean());

        // 7. Trùng Email đã có trong hệ thống (admin@example.com) -> 400
        var dupEmailRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "otheruser",
            email = "admin@example.com",
            password = "Password@123"
        });
        Assert.Equal(HttpStatusCode.BadRequest, dupEmailRes.StatusCode);
    }

    [Fact]
    public async Task Admin_can_update_employee_information_and_role()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. Tạo nhân viên
        var createRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "updateme",
            email = "updateme@example.com",
            password = "Password@123456",
            role = "User"
        });
        Assert.Equal(HttpStatusCode.Created, createRes.StatusCode);
        var createBody = await Read(createRes);
        var userId = createBody.GetProperty("id").GetString()!;

        // 2. Cập nhật thông tin và nâng lên Staff (không cần password)
        var updateRes = await adminClient.PutAsJsonAsync($"/api/Admin/employees/{userId}", new
        {
            username = "updateduser",
            email = "updateduser@example.com",
            initials = "UPD",
            role = "Staff"
        });
        Assert.Equal(HttpStatusCode.OK, updateRes.StatusCode);
        var updateBody = await Read(updateRes);
        Assert.True(updateBody.GetProperty("status").GetBoolean());
        Assert.Equal("updateduser", updateBody.GetProperty("userName").GetString());
        Assert.Equal("updateduser@example.com", updateBody.GetProperty("email").GetString());
        Assert.Equal("Staff", updateBody.GetProperty("role").GetString());

        // 3. Cập nhật với userId không tồn tại -> 404
        var notFoundRes = await adminClient.PutAsJsonAsync("/api/Admin/employees/non-existent-id", new
        {
            username = "anyone",
            email = "anyone@example.com"
        });
        Assert.Equal(HttpStatusCode.NotFound, notFoundRes.StatusCode);

        // 4. Cập nhật trùng username của tài khoản khác (admin) -> 400
        var dupNameRes = await adminClient.PutAsJsonAsync($"/api/Admin/employees/{userId}", new
        {
            username = "admin",
            email = "updateduser@example.com"
        });
        Assert.Equal(HttpStatusCode.BadRequest, dupNameRes.StatusCode);

        // 5. Cập nhật trùng email của tài khoản khác (admin@example.com) -> 400
        var dupEmailRes = await adminClient.PutAsJsonAsync($"/api/Admin/employees/{userId}", new
        {
            username = "updateduser",
            email = "admin@example.com"
        });
        Assert.Equal(HttpStatusCode.BadRequest, dupEmailRes.StatusCode);
    }

    [Fact]
    public async Task Admin_delete_employee_success_when_no_attendance_records()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. Tạo nhân viên mới chưa từng chấm công
        var createRes = await adminClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "todelete",
            email = "todelete@example.com",
            password = "Password@123456"
        });
        Assert.Equal(HttpStatusCode.Created, createRes.StatusCode);
        var createBody = await Read(createRes);
        var userId = createBody.GetProperty("id").GetString()!;

        // 2. Xóa tài khoản -> 200 OK
        var deleteRes = await adminClient.DeleteAsync($"/api/Admin/employees/{userId}");
        Assert.Equal(HttpStatusCode.OK, deleteRes.StatusCode);
        var deleteBody = await Read(deleteRes);
        Assert.True(deleteBody.GetProperty("status").GetBoolean());
        Assert.Equal("Đã xóa tài khoản thành công.", deleteBody.GetProperty("message").GetString());

        // 3. Kiểm tra user không còn trong database
        using var scope = app.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var deletedUser = await userManager.FindByIdAsync(userId);
        Assert.Null(deletedUser);

        // 4. Xóa lại lần nữa -> 404 NotFound
        var deleteAgainRes = await adminClient.DeleteAsync($"/api/Admin/employees/{userId}");
        Assert.Equal(HttpStatusCode.NotFound, deleteAgainRes.StatusCode);
    }

    [Fact]
    public async Task Admin_cannot_delete_self()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // Lấy admin userId từ DB
        using var scope = app.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var adminUser = await userManager.FindByNameAsync("admin");
        Assert.NotNull(adminUser);

        // Admin cố xóa chính mình -> 400 BadRequest
        var deleteSelfRes = await adminClient.DeleteAsync($"/api/Admin/employees/{adminUser.Id}");
        Assert.Equal(HttpStatusCode.BadRequest, deleteSelfRes.StatusCode);
        var body = await Read(deleteSelfRes);
        Assert.False(body.GetProperty("status").GetBoolean());
        Assert.Contains("Admin không thể tự xóa tài khoản của chính mình", body.GetProperty("message").GetString()!);
    }

    [Fact]
    public async Task Admin_cannot_delete_employee_with_attendance_history()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");
        using var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456");

        // 1. Staff thực hiện check-in để tạo dữ liệu lịch sử chấm công
        var checkInRes = await staffClient.PostAsJsonAsync("/api/Attendance/check-in", new
        {
            method = "GPS",
            latitude = 10.8552,
            longitude = 106.7856,
            locationName = "HUTECH Khu E"
        });
        Assert.Equal(HttpStatusCode.OK, checkInRes.StatusCode);

        // 2. Lấy Id của staff
        using var scope = app.Services.CreateScope();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
        var staffUser = await userManager.FindByNameAsync("staff");
        Assert.NotNull(staffUser);

        // 3. Admin cố gắng xóa tài khoản staff -> Phải bị từ chối 400 BadRequest
        var deleteRes = await adminClient.DeleteAsync($"/api/Admin/employees/{staffUser.Id}");
        Assert.Equal(HttpStatusCode.BadRequest, deleteRes.StatusCode);
        var deleteBody = await Read(deleteRes);
        Assert.False(deleteBody.GetProperty("status").GetBoolean());
        Assert.Equal("Không thể xóa tài khoản đã có lịch sử chấm công. Vui lòng giữ lại để đảm bảo dữ liệu chấm công.",
            deleteBody.GetProperty("message").GetString());

        // 4. Đảm bảo user staff vẫn tồn tại nguyên vẹn trong DB
        var staffStillExists = await userManager.FindByIdAsync(staffUser.Id);
        Assert.NotNull(staffStillExists);
    }

    [Fact]
    public async Task Non_admin_cannot_access_employee_crud()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var staffClient = await app.CreateAuthenticatedClientAsync("staff", "Staff@123456");

        // POST /api/Admin/employees -> 403 Forbidden
        var postRes = await staffClient.PostAsJsonAsync("/api/Admin/employees", new
        {
            username = "test",
            email = "test@example.com",
            password = "Password@123"
        });
        Assert.Equal(HttpStatusCode.Forbidden, postRes.StatusCode);

        // PUT /api/Admin/employees/123 -> 403 Forbidden
        var putRes = await staffClient.PutAsJsonAsync("/api/Admin/employees/123", new
        {
            username = "test",
            email = "test@example.com"
        });
        Assert.Equal(HttpStatusCode.Forbidden, putRes.StatusCode);

        // DELETE /api/Admin/employees/123 -> 403 Forbidden
        var deleteRes = await staffClient.DeleteAsync("/api/Admin/employees/123");
        Assert.Equal(HttpStatusCode.Forbidden, deleteRes.StatusCode);
    }
}
