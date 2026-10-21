using System.Collections.Concurrent;
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
    public string? FaceProof { get; set; }
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
    public string? FaceProof { get; set; }
}

public class AttendanceAdjustmentRequest
{
    public DateTime? CheckInTime { get; set; }
    public DateTime? CheckOutTime { get; set; }
    public string? Status { get; set; }
    public string Reason { get; set; } = string.Empty;
}

public class FaceEnrollmentRequest
{
    public string FaceVectorJson { get; set; } = string.Empty;
}

public class AttendanceFeedbackRequest
{
    public string Mood { get; set; } = string.Empty;
    public string? Notes { get; set; }
}

public class QrCodeItem
{
    public string Token { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
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

    // Quản lý mã QR hợp lệ trong hệ thống (thời hạn 24 giờ)
    public static readonly ConcurrentDictionary<string, QrCodeItem> ActiveQrCodes = new(StringComparer.OrdinalIgnoreCase);

    // Chống race condition khi check-in đồng thời cho cùng một user
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> _userLocks = new();

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

        var semaphore = _userLocks.GetOrAdd(userId, _ => new SemaphoreSlim(1, 1));
        await semaphore.WaitAsync();

        try
        {
            // QUY TẮC SINGLE OPEN SHIFT: Kiểm tra xem nhân viên có ca làm nào đang mở không (CheckOutTime == null)
            var hasOpenShift = await _context.AttendanceRecords
                .AnyAsync(a => a.UserId == userId && a.CheckOutTime == null);

            if (hasOpenShift)
            {
                return StatusCode(StatusCodes.Status409Conflict, new
                {
                    status = false,
                    message = "Bạn đang có một ca làm việc chưa kết thúc. Vui lòng check-out ca hiện tại trước khi vào ca mới."
                });
            }

            // BẢO MẬT & XÁC THỰC METHOD: Chỉ chấp nhận ["GPS", "QR", "Face", "Biometric"]
            var validMethods = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "GPS", "QR", "Face", "Biometric" };
            var rawMethod = string.IsNullOrWhiteSpace(request?.Method) ? "GPS" : request.Method.Trim();
            if (!validMethods.Contains(rawMethod))
            {
                return BadRequest(new
                {
                    status = false,
                    message = $"Phương thức chấm công '{request?.Method}' không hợp lệ. Chỉ chấp nhận GPS, QR, Face, Biometric."
                });
            }

            string normalizedMethod = rawMethod.ToUpperInvariant() switch
            {
                "GPS" => "GPS",
                "QR" => "QR",
                "FACE" => "Face",
                "BIOMETRIC" => "Biometric",
                _ => rawMethod
            };

            // Xác thực chi tiết theo từng phương thức
            if (normalizedMethod == "GPS")
            {
                if (!request!.Latitude.HasValue || !request.Longitude.HasValue)
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
            }
            else if (normalizedMethod == "QR")
            {
                if (string.IsNullOrWhiteSpace(request?.QrToken))
                {
                    return BadRequest(new
                    {
                        status = false,
                        message = "Phương thức QR yêu cầu cung cấp qrToken."
                    });
                }

                var token = request.QrToken.Trim();
                var isValidQr = false;

                if (ActiveQrCodes.TryGetValue(token, out var activeItem) && activeItem.ExpiresAt >= DateTime.UtcNow)
                {
                    isValidQr = true;
                }
                else if (token.StartsWith("HUTECH_ATTENDANCE_QR_", StringComparison.OrdinalIgnoreCase) && token.Length > "HUTECH_ATTENDANCE_QR_".Length)
                {
                    isValidQr = true;
                }

                if (!isValidQr)
                {
                    return BadRequest(new
                    {
                        status = false,
                        message = "Mã QR không hợp lệ hoặc đã hết hạn."
                    });
                }
            }
            else if (normalizedMethod == "Face")
            {
                if (string.IsNullOrWhiteSpace(request?.FaceProof))
                {
                    return BadRequest(new
                    {
                        status = false,
                        message = "Phương thức Face yêu cầu dữ liệu FaceProof hợp lệ sau khi nhận diện."
                    });
                }
            }

            var record = new AttendanceRecord
            {
                UserId = userId,
                CheckInTime = DateTime.UtcNow,
                CheckOutTime = null,
                Method = normalizedMethod,
                Latitude = request?.Latitude,
                Longitude = request?.Longitude,
                LocationName = request?.LocationName ?? (normalizedMethod == "GPS" ? "HUTECH Campus E1" : null),
                DeviceInfo = request?.DeviceInfo,
                Status = "Valid",
                Notes = request?.Notes
            };

            _context.AttendanceRecords.Add(record);
            await _context.SaveChangesAsync();

            _logger.LogInformation("Người dùng {UserId} đã check-in thành công qua {Method}", userId, normalizedMethod);

            return Ok(new
            {
                status = true,
                message = "Chấm công vào ca (Check-in) thành công!",
                data = record
            });
        }
        finally
        {
            semaphore.Release();
        }
    }

    [HttpPost("check-out")]
    public async Task<IActionResult> CheckOut([FromBody] CheckOutRequest? request)
    {
        var userId = await GetCurrentUserIdAsync();
        if (string.IsNullOrEmpty(userId))
        {
            return Unauthorized(new { status = false, message = "Không xác định được danh tính người dùng từ token." });
        }

        // Tìm ca mở duy nhất của nhân viên (CheckOutTime == null)
        var record = await _context.AttendanceRecords
            .Where(a => a.UserId == userId && a.CheckOutTime == null)
            .OrderByDescending(a => a.CheckInTime)
            .FirstOrDefaultAsync();

        if (record == null)
        {
            return BadRequest(new
            {
                status = false,
                message = "Không tìm thấy ca làm việc đang mở để check-out. Vui lòng check-in vào ca trước."
            });
        }

        if (!string.IsNullOrWhiteSpace(request?.Method))
        {
            var validMethods = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { "GPS", "QR", "Face", "Biometric" };
            if (!validMethods.Contains(request.Method.Trim()))
            {
                return BadRequest(new
                {
                    status = false,
                    message = $"Phương thức chấm công '{request.Method}' không hợp lệ. Chỉ chấp nhận GPS, QR, Face, Biometric."
                });
            }
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

    [HttpPost("{id}/feedback")]
    public async Task<IActionResult> SubmitFeedback(int id, [FromBody] AttendanceFeedbackRequest? request)
    {
        if (string.IsNullOrWhiteSpace(request?.Mood))
        {
            return BadRequest(new
            {
                status = false,
                message = "Vui lòng chọn cảm nhận sau ca làm việc trước khi gửi."
            });
        }

        var userId = await GetCurrentUserIdAsync();
        if (string.IsNullOrEmpty(userId))
        {
            return Unauthorized(new { status = false, message = "Không xác định được danh tính người dùng." });
        }

        var record = await _context.AttendanceRecords.FindAsync(id);
        if (record == null)
        {
            return NotFound(new
            {
                status = false,
                message = "Không tìm thấy ca làm việc cần gửi cảm nhận."
            });
        }

        var isAdmin = User.IsInRole("Admin");
        if (record.UserId != userId && !isAdmin)
        {
            return Forbid();
        }

        record.FeedbackMood = request.Mood.Trim();
        record.FeedbackNote = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim();
        record.FeedbackTime = DateTime.UtcNow;

        await _context.SaveChangesAsync();
        _logger.LogInformation("Người dùng {UserId} đã gửi cảm nhận cho ca làm Id {RecordId}: {Mood}", userId, id, record.FeedbackMood);

        return Ok(new
        {
            status = true,
            message = "Gửi cảm nhận sau ca làm thành công! Cảm ơn bạn.",
            data = record
        });
    }

    [HttpGet("active-qr")]
    public IActionResult GetActiveQr()
    {
        var now = DateTime.UtcNow;
        var valid = ActiveQrCodes.Values
            .Where(q => q.ExpiresAt > now)
            .OrderByDescending(q => q.CreatedAt)
            .FirstOrDefault();

        if (valid == null)
        {
            // Tự động khởi tạo mã QR địa điểm chuẩn mặc định có hiệu lực 24 giờ
            var token = $"HUTECH_ATTENDANCE_QR_CAMPUS_E1_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
            valid = new QrCodeItem
            {
                Token = token,
                CreatedAt = now,
                ExpiresAt = now.AddHours(24),
                CreatedBy = "System"
            };
            ActiveQrCodes[token] = valid;
        }

        return Ok(new
        {
            status = true,
            token = valid.Token,
            createdAt = valid.CreatedAt,
            expiresAt = valid.ExpiresAt
        });
    }

    [HttpPost("generate-qr")]
    [Authorize(Roles = "Admin")]
    public IActionResult GenerateQr()
    {
        var adminName = User.FindFirstValue(ClaimTypes.Name) ?? User.Identity?.Name ?? "Admin";
        var now = DateTime.UtcNow;
        var token = $"HUTECH_ATTENDANCE_QR_{Guid.NewGuid():N}_{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";

        var item = new QrCodeItem
        {
            Token = token,
            CreatedAt = now,
            ExpiresAt = now.AddHours(24), // Thời hạn 24 giờ
            CreatedBy = adminName
        };

        ActiveQrCodes[token] = item;
        _logger.LogInformation("Admin {Admin} đã tạo mã QR chấm công mới: {Token}", adminName, token);

        return Ok(new
        {
            status = true,
            message = "Sinh mã QR chấm công thành công (có hiệu lực 24 giờ).",
            token = token,
            expiresAt = item.ExpiresAt
        });
    }

    [HttpPost("enroll-face")]
    public async Task<IActionResult> EnrollFace([FromBody] FaceEnrollmentRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.FaceVectorJson))
        {
            return BadRequest(new { status = false, message = "Dữ liệu mẫu khuôn mặt (faceVectorJson) không được để trống." });
        }

        var userId = await GetCurrentUserIdAsync();
        if (string.IsNullOrEmpty(userId))
        {
            return Unauthorized(new { status = false, message = "Không xác định được danh tính người dùng." });
        }

        var currentUsername = User.FindFirstValue(ClaimTypes.Name) ?? User.Identity?.Name ?? "User";
        var profile = await _context.UserFaceProfiles.FirstOrDefaultAsync(p => p.UserId == userId);

        if (profile == null)
        {
            profile = new UserFaceProfile
            {
                UserId = userId,
                FaceVectorJson = request.FaceVectorJson.Trim(),
                EnrolledAt = DateTime.UtcNow,
                UpdatedBy = currentUsername
            };
            _context.UserFaceProfiles.Add(profile);
        }
        else
        {
            profile.FaceVectorJson = request.FaceVectorJson.Trim();
            profile.EnrolledAt = DateTime.UtcNow;
            profile.UpdatedBy = currentUsername;
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("Người dùng {UserId} ({Username}) đã đăng ký/cập nhật mẫu khuôn mặt thành công.", userId, currentUsername);

        return Ok(new
        {
            status = true,
            message = "Đăng ký mẫu khuôn mặt thành công!",
            enrolledAt = profile.EnrolledAt
        });
    }

    [HttpGet("face-profile/{username}")]
    public async Task<IActionResult> GetFaceProfile(string username)
    {
        if (string.IsNullOrWhiteSpace(username))
        {
            return BadRequest(new { status = false, message = "Vui lòng cung cấp tên đăng nhập." });
        }

        var user = await _userManager.FindByNameAsync(username.Trim());
        if (user == null)
        {
            return NotFound(new { status = false, message = "Không tìm thấy người dùng." });
        }

        var profile = await _context.UserFaceProfiles.FirstOrDefaultAsync(p => p.UserId == user.Id);
        if (profile == null)
        {
            return NotFound(new { status = false, message = "Người dùng chưa đăng ký mẫu khuôn mặt." });
        }

        return Ok(new
        {
            status = true,
            userId = profile.UserId,
            username = user.UserName,
            faceVectorJson = profile.FaceVectorJson,
            enrolledAt = profile.EnrolledAt,
            updatedBy = profile.UpdatedBy
        });
    }

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> AdjustAttendanceRecord(int id, [FromBody] AttendanceAdjustmentRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.Reason))
        {
            return BadRequest(new
            {
                status = false,
                message = "Bắt buộc cung cấp lý do (reason) điều chỉnh ca làm việc."
            });
        }

        var record = await _context.AttendanceRecords.FindAsync(id);
        if (record == null)
        {
            return NotFound(new
            {
                status = false,
                message = "Không tìm thấy bản ghi chấm công cần điều chỉnh."
            });
        }

        var adminUsername = User.FindFirstValue(ClaimTypes.Name) ?? User.Identity?.Name ?? "Admin";

        if (request.CheckInTime.HasValue)
        {
            record.CheckInTime = request.CheckInTime.Value;
        }

        if (request.CheckOutTime.HasValue)
        {
            record.CheckOutTime = request.CheckOutTime.Value;
        }

        if (!string.IsNullOrWhiteSpace(request.Status))
        {
            record.Status = request.Status.Trim();
        }

        var auditNote = $"[ĐIỀU CHỈNH bởi {adminUsername} lúc {DateTime.UtcNow:yyyy-MM-dd HH:mm:ss} UTC: {request.Reason.Trim()}]";
        record.Notes = string.IsNullOrWhiteSpace(record.Notes)
            ? auditNote
            : $"{record.Notes}\n{auditNote}";

        await _context.SaveChangesAsync();
        _logger.LogInformation("Admin {Admin} đã điều chỉnh bản ghi {Id}. Lý do: {Reason}", adminUsername, id, request.Reason);

        return Ok(new
        {
            status = true,
            message = "Điều chỉnh bản ghi ca làm việc thành công.",
            data = record
        });
    }

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteAttendanceRecord(int id)
    {
        var record = await _context.AttendanceRecords.FindAsync(id);
        if (record == null)
        {
            return NotFound(new
            {
                status = false,
                message = "Không tìm thấy bản ghi chấm công cần xóa."
            });
        }

        _context.AttendanceRecords.Remove(record);
        await _context.SaveChangesAsync();
        _logger.LogInformation("Admin đã xóa bản ghi chấm công {Id}", id);

        return Ok(new
        {
            status = true,
            message = "Đã xóa bản ghi chấm công sai sót thành công."
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
                notes = a.Notes,
                feedbackMood = a.FeedbackMood,
                feedbackNote = a.FeedbackNote,
                feedbackTime = a.FeedbackTime
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
