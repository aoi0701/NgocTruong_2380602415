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
