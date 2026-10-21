using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Controllers;

public class UpdateRoleRequest
{
    public string Role { get; set; } = string.Empty;
}

public class CreateEmployeeRequest
{
    [Required(ErrorMessage = "Tên đăng nhập không được để trống.")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email không được để trống.")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "Mật khẩu không được để trống.")]
    [MinLength(6, ErrorMessage = "Mật khẩu phải có ít nhất 6 ký tự.")]
    public string Password { get; set; } = string.Empty;

    public string? Role { get; set; }

    public string? Initials { get; set; }
}

public class UpdateEmployeeRequest
{
    [Required(ErrorMessage = "Tên đăng nhập không được để trống.")]
    public string Username { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email không được để trống.")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
    public string Email { get; set; } = string.Empty;

    public string? Role { get; set; }

    public string? Initials { get; set; }
}

[Authorize(Roles = "Admin")]
[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<User> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;
    private readonly ILogger<AdminController> _logger;

    public AdminController(
        ApplicationDbContext context,
        UserManager<User> userManager,
        RoleManager<IdentityRole> roleManager,
        ILogger<AdminController> logger)
    {
        _context = context;
        _userManager = userManager;
        _roleManager = roleManager;
        _logger = logger;
    }

    [HttpGet("employees")]
    public async Task<IActionResult> GetEmployees()
    {
        var users = await _userManager.Users.ToListAsync();
        var openShiftsList = await _context.AttendanceRecords
            .Where(a => a.CheckOutTime == null)
            .ToListAsync();
        var openShifts = openShiftsList
            .GroupBy(a => a.UserId)
            .ToDictionary(g => g.Key, g => g.First());

        var employeeList = new List<object>();

        foreach (var user in users)
        {
            var roles = await _userManager.GetRolesAsync(user);
            openShifts.TryGetValue(user.Id, out var openShift);

            employeeList.Add(new
            {
                id = user.Id,
                userName = user.UserName,
                email = user.Email,
                initials = user.Initials,
                roles = roles,
                hasOpenShift = openShift != null,
                currentShift = openShift != null ? new
                {
                    id = openShift.Id,
                    checkInTime = openShift.CheckInTime,
                    method = openShift.Method,
                    locationName = openShift.LocationName,
                    status = openShift.Status
                } : null
            });
        }

        return Ok(employeeList);
    }

    [HttpPost("employees")]
    public async Task<IActionResult> CreateEmployee([FromBody] CreateEmployeeRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { status = false, message = "Dữ liệu yêu cầu không hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(request.Username))
        {
            return BadRequest(new { status = false, message = "Tên đăng nhập không được để trống." });
        }

        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { status = false, message = "Email không được để trống." });
        }

        if (!new EmailAddressAttribute().IsValid(request.Email.Trim()))
        {
            return BadRequest(new { status = false, message = "Email không đúng định dạng hợp lệ." });
        }

        if (string.IsNullOrWhiteSpace(request.Password))
        {
            return BadRequest(new { status = false, message = "Mật khẩu không được để trống." });
        }

        var targetRole = string.IsNullOrWhiteSpace(request.Role) ? "Staff" : request.Role.Trim();
        var validRoles = new[] { "Admin", "Staff", "User" };
        var matchedRole = validRoles.FirstOrDefault(r => string.Equals(r, targetRole, StringComparison.OrdinalIgnoreCase));
        if (matchedRole == null)
        {
            return BadRequest(new { status = false, message = $"Vai trò '{targetRole}' không hợp lệ. Chỉ chấp nhận Admin, Staff, User." });
        }

        var username = request.Username.Trim();
        var email = request.Email.Trim();

        var existingByName = await _userManager.FindByNameAsync(username);
        if (existingByName != null)
        {
            return BadRequest(new { status = false, message = "Tên đăng nhập đã tồn tại trong hệ thống." });
        }

        var existingByEmail = await _userManager.FindByEmailAsync(email);
        if (existingByEmail != null)
        {
            return BadRequest(new { status = false, message = "Email đã tồn tại trong hệ thống." });
        }

        var rawInitials = !string.IsNullOrWhiteSpace(request.Initials)
            ? request.Initials.Trim()
            : (username.Length <= 3 ? username.ToUpperInvariant() : username[..3].ToUpperInvariant());
        var initials = rawInitials.Length > 5 ? rawInitials[..5] : rawInitials;

        var user = new User
        {
            UserName = username,
            Email = email,
            Initials = initials,
            EmailConfirmed = true
        };

        var result = await _userManager.CreateAsync(user, request.Password);
        if (!result.Succeeded)
        {
            return BadRequest(new
            {
                status = false,
                message = string.Join("; ", result.Errors.Select(e => e.Description))
            });
        }

        if (!await _roleManager.RoleExistsAsync(matchedRole))
        {
            await _roleManager.CreateAsync(new IdentityRole(matchedRole));
        }
        await _userManager.AddToRoleAsync(user, matchedRole);

        _logger.LogInformation("Admin đã tạo tài khoản nhân viên mới {Username} với vai trò {Role}", user.UserName, matchedRole);

        return StatusCode(StatusCodes.Status201Created, new
        {
            status = true,
            message = "Tạo tài khoản nhân viên thành công.",
            id = user.Id,
            userId = user.Id,
            userName = user.UserName,
            email = user.Email,
            initials = user.Initials,
            role = matchedRole,
            data = new
            {
                id = user.Id,
                userName = user.UserName,
                email = user.Email,
                initials = user.Initials,
                role = matchedRole
            }
        });
    }

    [HttpPut("employees/{userId}")]
    public async Task<IActionResult> UpdateEmployee(string userId, [FromBody] UpdateEmployeeRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { status = false, message = "Dữ liệu yêu cầu không hợp lệ." });
        }

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { status = false, message = "Không tìm thấy nhân viên với UserId đã chỉ định." });
        }

        if (string.IsNullOrWhiteSpace(request.Username))
        {
            return BadRequest(new { status = false, message = "Tên đăng nhập không được để trống." });
        }

        if (string.IsNullOrWhiteSpace(request.Email))
        {
            return BadRequest(new { status = false, message = "Email không được để trống." });
        }

        if (!new EmailAddressAttribute().IsValid(request.Email.Trim()))
        {
            return BadRequest(new { status = false, message = "Email không đúng định dạng hợp lệ." });
        }

        var username = request.Username.Trim();
        var email = request.Email.Trim();

        var existingByName = await _userManager.FindByNameAsync(username);
        if (existingByName != null && existingByName.Id != user.Id)
        {
            return BadRequest(new { status = false, message = "Tên đăng nhập đã được sử dụng bởi tài khoản khác." });
        }

        var existingByEmail = await _userManager.FindByEmailAsync(email);
        if (existingByEmail != null && existingByEmail.Id != user.Id)
        {
            return BadRequest(new { status = false, message = "Email đã được sử dụng bởi tài khoản khác." });
        }

        string? matchedRole = null;
        if (!string.IsNullOrWhiteSpace(request.Role))
        {
            var targetRole = request.Role.Trim();
            var validRoles = new[] { "Admin", "Staff", "User" };
            matchedRole = validRoles.FirstOrDefault(r => string.Equals(r, targetRole, StringComparison.OrdinalIgnoreCase));
            if (matchedRole == null)
            {
                return BadRequest(new { status = false, message = $"Vai trò '{targetRole}' không hợp lệ. Chỉ chấp nhận Admin, Staff, User." });
            }
        }

        user.UserName = username;
        user.Email = email;
        if (!string.IsNullOrWhiteSpace(request.Initials))
        {
            var inits = request.Initials.Trim();
            user.Initials = inits.Length > 5 ? inits[..5] : inits;
        }

        var updateResult = await _userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return BadRequest(new
            {
                status = false,
                message = string.Join("; ", updateResult.Errors.Select(e => e.Description))
            });
        }

        if (matchedRole != null)
        {
            if (!await _roleManager.RoleExistsAsync(matchedRole))
            {
                await _roleManager.CreateAsync(new IdentityRole(matchedRole));
            }
            var currentRoles = await _userManager.GetRolesAsync(user);
            await _userManager.RemoveFromRolesAsync(user, currentRoles);
            await _userManager.AddToRoleAsync(user, matchedRole);
        }

        var finalRoles = await _userManager.GetRolesAsync(user);
        var activeRole = finalRoles.FirstOrDefault() ?? "User";

        _logger.LogInformation("Admin đã cập nhật thông tin nhân viên {Username} ({UserId})", user.UserName, user.Id);

        return Ok(new
        {
            status = true,
            message = "Cập nhật thông tin nhân viên thành công.",
            id = user.Id,
            userId = user.Id,
            userName = user.UserName,
            email = user.Email,
            initials = user.Initials,
            role = activeRole,
            data = new
            {
                id = user.Id,
                userName = user.UserName,
                email = user.Email,
                initials = user.Initials,
                role = activeRole
            }
        });
    }

    [HttpDelete("employees/{userId}")]
    public async Task<IActionResult> DeleteEmployee(string userId)
    {
        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { status = false, message = "Không tìm thấy tài khoản cần xóa." });
        }

        // Không cho Admin xóa chính tài khoản đang đăng nhập
        var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var currentUserName = User.Identity?.Name;
        if (string.Equals(currentUserId, userId, StringComparison.OrdinalIgnoreCase) ||
            string.Equals(currentUserName, user.UserName, StringComparison.OrdinalIgnoreCase))
        {
            return BadRequest(new { status = false, message = "Admin không thể tự xóa tài khoản của chính mình." });
        }

        // Kiểm tra nếu tài khoản đã có lịch sử chấm công
        var hasAttendance = await _context.AttendanceRecords.AnyAsync(a => a.UserId == userId);
        if (hasAttendance)
        {
            return BadRequest(new
            {
                status = false,
                message = "Không thể xóa tài khoản đã có lịch sử chấm công. Vui lòng giữ lại để đảm bảo dữ liệu chấm công."
            });
        }

        // Dọn dẹp UserFaceProfiles nếu có (tránh lỗi khóa ngoại)
        var faceProfiles = await _context.UserFaceProfiles.Where(f => f.UserId == userId).ToListAsync();
        if (faceProfiles.Count > 0)
        {
            _context.UserFaceProfiles.RemoveRange(faceProfiles);
            await _context.SaveChangesAsync();
        }

        var deleteResult = await _userManager.DeleteAsync(user);
        if (!deleteResult.Succeeded)
        {
            return BadRequest(new
            {
                status = false,
                message = string.Join("; ", deleteResult.Errors.Select(e => e.Description))
            });
        }

        _logger.LogInformation("Admin đã xóa tài khoản nhân viên {Username} ({UserId})", user.UserName, userId);

        return Ok(new
        {
            status = true,
            message = "Đã xóa tài khoản thành công."
        });
    }

    [HttpPost("employees/{userId}/role")]
    public async Task<IActionResult> ChangeUserRole(string userId, [FromBody] UpdateRoleRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.Role))
        {
            return BadRequest(new { status = false, message = "Vui lòng chỉ định vai trò (role) cần cấp." });
        }

        var targetRole = request.Role.Trim();
        var validRoles = new[] { "Admin", "Staff", "User" };
        var matchedRole = validRoles.FirstOrDefault(r => string.Equals(r, targetRole, StringComparison.OrdinalIgnoreCase));

        if (matchedRole == null)
        {
            return BadRequest(new { status = false, message = $"Vai trò '{targetRole}' không hợp lệ. Chỉ chấp nhận Admin, Staff, User." });
        }

        var user = await _userManager.FindByIdAsync(userId);
        if (user == null)
        {
            return NotFound(new { status = false, message = "Không tìm thấy nhân viên với UserId đã chỉ định." });
        }

        if (!await _roleManager.RoleExistsAsync(matchedRole))
        {
            await _roleManager.CreateAsync(new IdentityRole(matchedRole));
        }

        var currentRoles = await _userManager.GetRolesAsync(user);
        await _userManager.RemoveFromRolesAsync(user, currentRoles);
        await _userManager.AddToRoleAsync(user, matchedRole);

        _logger.LogInformation("Admin đã đổi vai trò của người dùng {Username} ({UserId}) thành {Role}", user.UserName, userId, matchedRole);

        return Ok(new
        {
            status = true,
            message = $"Cập nhật vai trò cho nhân viên '{user.UserName}' thành '{matchedRole}' thành công.",
            userId = user.Id,
            userName = user.UserName,
            role = matchedRole
        });
    }
}
