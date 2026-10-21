using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Controllers;

public class CheckInRequest
{
    public string Method { get; set; } = "GPS"; // GPS, QR, Face, Biometric
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? LocationName { get; set; }
    public string? DeviceInfo { get; set; }
    public string? Notes { get; set; }
    public string? QrToken { get; set; }
}

public class CheckOutRequest
{
    public string? Method { get; set; }
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public string? LocationName { get; set; }
    public string? DeviceInfo { get; set; }
    public string? Notes { get; set; }
    public string? QrToken { get; set; }
}

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AttendanceController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<User> _userManager;
    private readonly ILogger<AttendanceController> _logger;

    // Tọa độ chuẩn HUTECH Campus E1: Khu Công nghệ cao TP.HCM (Quận 9 / TP. Thủ Đức)
    private const double HutechCampusE1Lat = 10.8552;
    private const double HutechCampusE1Lng = 106.7856;
    private const double MaxAllowedRadiusMeters = 500.0;

    public AttendanceController(
        ApplicationDbContext context,
        UserManager<User> userManager,
        ILogger<AttendanceController> logger)
    {
        _context = context;
        _userManager = userManager;
        _logger = logger;
    }

    [HttpPost("check-in")]
    public async Task<IActionResult> CheckIn([FromBody] CheckInRequest request)
    {
        var userId = await GetCurrentUserIdAsync();
        if (string.IsNullOrEmpty(userId))
        {
            return Unauthorized(new { status = false, message = "Không xác định được danh tính người dùng từ token." });
        }

        // Chống ghi trùng: nếu đã check-in trong vòng 5 phút, trả 409 Conflict
        var fiveMinutesAgo = DateTime.UtcNow.AddMinutes(-5);
        var recentCheckIn = await _context.AttendanceRecords
            .Where(a => a.UserId == userId && a.CheckInTime >= fiveMinutesAgo)
            .OrderByDescending(a => a.CheckInTime)
            .FirstOrDefaultAsync();

        if (recentCheckIn != null)
        {
            return StatusCode(StatusCodes.Status409Conflict, new
            {
                status = false,
                message = "Bạn đã thực hiện check-in trong vòng 5 phút trước. Vui lòng không gửi yêu cầu trùng lặp."
            });
        }

        var method = string.IsNullOrWhiteSpace(request.Method) ? "GPS" : request.Method.Trim();
        var isGps = string.Equals(method, "GPS", StringComparison.OrdinalIgnoreCase);

        var status = "Valid";
        if (isGps)
        {
            if (!request.Latitude.HasValue || !request.Longitude.HasValue)
            {
                return BadRequest(new
                {
                    status = false,
                    message = "Phương thức GPS yêu cầu cung cấp đầy đủ tọa độ kinh độ và vĩ độ."
                });
            }

            var distance = CalculateDistanceMeters(
                HutechCampusE1Lat,
                HutechCampusE1Lng,
                request.Latitude.Value,
                request.Longitude.Value
            );

            if (distance > MaxAllowedRadiusMeters)
            {
                return BadRequest(new
                {
                    status = false,
                    message = $"Vị trí nằm ngoài bán kính cho phép ({distance:F1}m > {MaxAllowedRadiusMeters}m so với HUTECH Campus E1)."
                });
            }

            status = "Valid";
        }

        var record = new AttendanceRecord
        {
            UserId = userId,
            CheckInTime = DateTime.UtcNow,
            CheckOutTime = null,
            Method = method,
            Latitude = request.Latitude,
            Longitude = request.Longitude,
            LocationName = request.LocationName ?? (isGps ? "HUTECH Campus E1" : null),
            DeviceInfo = request.DeviceInfo,
            Status = status,
            Notes = request.Notes
        };

        _context.AttendanceRecords.Add(record);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Người dùng {UserId} đã check-in thành công qua {Method} (Status: {Status})", userId, method, status);

        return Ok(new
        {
            status = true,
            message = "Chấm công vào ca (Check-in) thành công!",
            data = record
        });
    }

    [HttpPost("check-out")]
    public async Task<IActionResult> CheckOut([FromBody] CheckOutRequest? request)
    {
        var userId = await GetCurrentUserIdAsync();
        if (string.IsNullOrEmpty(userId))
        {
            return Unauthorized(new { status = false, message = "Không xác định được danh tính người dùng từ token." });
        }

        // Tìm bản ghi check-in gần nhất trong ngày chưa check-out của user đó
        var todayUtc = DateTime.UtcNow.Date;
        var record = await _context.AttendanceRecords
            .Where(a => a.UserId == userId && a.CheckInTime >= todayUtc && a.CheckOutTime == null)
            .OrderByDescending(a => a.CheckInTime)
            .FirstOrDefaultAsync();

        if (record == null)
        {
            // Dự phòng cho ca làm việc xuyên ngày (trong vòng 24 giờ qua chưa check-out)
            var last24h = DateTime.UtcNow.AddHours(-24);
            record = await _context.AttendanceRecords
                .Where(a => a.UserId == userId && a.CheckInTime >= last24h && a.CheckOutTime == null)
                .OrderByDescending(a => a.CheckInTime)
                .FirstOrDefaultAsync();
        }

        if (record == null)
        {
            return BadRequest(new
            {
                status = false,
                message = "Không tìm thấy bản ghi vào ca (check-in) chưa ra ca trong ngày để thực hiện check-out."
            });
        }

        record.CheckOutTime = DateTime.UtcNow;
        if (!string.IsNullOrWhiteSpace(request?.Notes))
        {
            record.Notes = string.IsNullOrWhiteSpace(record.Notes)
                ? request.Notes
                : $"{record.Notes}; {request.Notes}";
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("Người dùng {UserId} đã check-out thành công cho bản ghi Id {RecordId}", userId, record.Id);

        return Ok(new
        {
            status = true,
            message = "Chấm công ra ca (Check-out) thành công!",
            data = record
        });
    }

    [HttpGet("my-history")]
    public async Task<IActionResult> GetMyHistory()
    {
        var userId = await GetCurrentUserIdAsync();
        if (string.IsNullOrEmpty(userId))
        {
            return Unauthorized(new { status = false, message = "Không xác định được danh tính người dùng." });
        }

        var history = await _context.AttendanceRecords
            .Where(a => a.UserId == userId)
            .OrderByDescending(a => a.CheckInTime)
            .ToListAsync();

        return Ok(history);
    }

    [HttpGet("all")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll()
    {
        var allRecords = await _context.AttendanceRecords
            .Include(a => a.User)
            .OrderByDescending(a => a.CheckInTime)
            .Select(a => new
            {
                id = a.Id,
                userId = a.UserId,
                userName = a.User != null ? a.User.UserName : null,
                email = a.User != null ? a.User.Email : null,
                initials = a.User != null ? a.User.Initials : null,
                checkInTime = a.CheckInTime,
                checkOutTime = a.CheckOutTime,
                method = a.Method,
                latitude = a.Latitude,
                longitude = a.Longitude,
                locationName = a.LocationName,
                deviceInfo = a.DeviceInfo,
                status = a.Status,
                notes = a.Notes
            })
            .ToListAsync();

        return Ok(allRecords);
    }

    private async Task<string?> GetCurrentUserIdAsync()
    {
        var userIdClaim = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (!string.IsNullOrEmpty(userIdClaim))
        {
            return userIdClaim;
        }

        var username = User.FindFirstValue(ClaimTypes.Name)
            ?? User.FindFirst(ClaimTypes.Name)?.Value
            ?? User.Identity?.Name;

        if (!string.IsNullOrEmpty(username))
        {
            var user = await _userManager.FindByNameAsync(username);
            return user?.Id;
        }

        return null;
    }

    private static double CalculateDistanceMeters(double lat1, double lon1, double lat2, double lon2)
    {
        const double r = 6371000.0; // Bán kính Trái Đất (mét)
        var dLat = (lat2 - lat1) * Math.PI / 180.0;
        var dLon = (lon2 - lon1) * Math.PI / 180.0;
        var lat1Rad = lat1 * Math.PI / 180.0;
        var lat2Rad = lat2 * Math.PI / 180.0;

        var a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                Math.Cos(lat1Rad) * Math.Cos(lat2Rad) *
                Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
        var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
        return r * c;
    }
}
