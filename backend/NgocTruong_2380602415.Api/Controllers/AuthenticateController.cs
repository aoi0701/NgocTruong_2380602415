using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Controllers;

public class OtpRequestModel
{
    public string Username { get; set; } = string.Empty;
}

public class FaceLoginRequest
{
    public string Username { get; set; } = string.Empty;
    public Dictionary<string, double>? Features { get; set; }
    public string? FaceVectorJson { get; set; }
}

[ApiController]
[Route("api/[controller]")]
public class AuthenticateController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly UserManager<User> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;
    private readonly IConfiguration _configuration;
    private readonly IOtpService _otpService;
    private readonly ILogger<AuthenticateController> _logger;

    public AuthenticateController(
        ApplicationDbContext context,
        UserManager<User> userManager,
        RoleManager<IdentityRole> roleManager,
        IConfiguration configuration,
        IOtpService otpService,
        ILogger<AuthenticateController> logger)
    {
        _context = context;
        _userManager = userManager;
        _roleManager = roleManager;
        _configuration = configuration;
        _otpService = otpService;
        _logger = logger;
    }

    [HttpPost("request-otp")]
    public async Task<IActionResult> RequestOtp([FromBody] OtpRequestModel model)
    {
        if (string.IsNullOrWhiteSpace(model.Username))
        {
            return BadRequest(new { Status = false, Message = "Vui lòng cung cấp tên đăng nhập hoặc email." });
        }

        var username = model.Username.Trim();
        var user = await _userManager.FindByNameAsync(username) ?? await _userManager.FindByEmailAsync(username);
        if (user == null)
        {
            return NotFound(new { Status = false, Message = "Không tìm thấy tài khoản với tên đăng nhập này." });
        }

        var (canSend, errorMessage, cooldown) = _otpService.CheckCooldown(user.UserName!);
        if (!canSend)
        {
            return StatusCode(StatusCodes.Status429TooManyRequests, new
            {
                Status = false,
                Message = errorMessage,
                CooldownRemaining = cooldown
            });
        }

        var email = string.IsNullOrWhiteSpace(user.Email) ? $"{user.UserName}@example.com" : user.Email;
        try
        {
            await _otpService.GenerateAndSendOtpAsync(user.UserName!, email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi gửi email OTP cho tài khoản '{Username}'", user.UserName);
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                status = false,
                message = "Không thể gửi email OTP: Dịch vụ email chưa được cấu hình hoặc gặp sự cố kết nối SMTP. Vui lòng kiểm tra cấu hình SmtpSettings trong appsettings.json."
            });
        }

        // KHÔNG trả mã OTP trong JSON response (chỉ trả message thông báo đã gửi)
        return Ok(new
        {
            Status = true,
            Message = _otpService.IsLocalMode
                ? "Đã tạo yêu cầu OTP. Vui lòng nhập mã xác thực để đăng nhập."
                : "Mã xác thực OTP đã được gửi đến email đăng ký của bạn. Vui lòng kiểm tra hộp thư.",
            ExpiresInSeconds = 300
        });
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegistrationModel model)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var userExists = await _userManager.FindByNameAsync(model.Username);
        if (userExists != null)
        {
            return StatusCode(StatusCodes.Status400BadRequest, new
            {
                Status = false,
                Message = "User already exists"
            });
        }

        var user = new User
        {
            UserName = model.Username,
            Email = model.Email,
            Initials = model.Initials
        };

        var result = await _userManager.CreateAsync(user, model.Password);
        if (!result.Succeeded)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new
            {
                Status = false,
                Message = string.Join("; ", result.Errors.Select(e => e.Description))
            });
        }

        // Đăng ký công khai chỉ cấp role User.
        // Chặn tuyệt đối việc đăng ký tự cấp Admin hoặc Staff (nếu client gửi Admin hoặc Staff, bắt buộc đặt là User)
        const string role = "User";
        if (!await _roleManager.RoleExistsAsync(role))
        {
            await _roleManager.CreateAsync(new IdentityRole(role));
        }
        await _userManager.AddToRoleAsync(user, role);

        if (!string.IsNullOrWhiteSpace(model.Role) && !string.Equals(model.Role.Trim(), "User", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("Tài khoản {Username} đã yêu cầu vai trò '{RequestedRole}', hệ thống đã ép về vai trò an toàn '{Role}'.",
                model.Username, model.Role, role);
        }

        return Ok(new
        {
            Status = true,
            Message = "User created successfully"
        });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginModel model)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var identifier = model.Username.Trim();
        var user = await _userManager.FindByNameAsync(identifier) ?? await _userManager.FindByEmailAsync(identifier);

        // Bước 1: Xác thực username/email và mật khẩu với _userManager.CheckPasswordAsync(user, model.Password)
        if (user == null || !await _userManager.CheckPasswordAsync(user, model.Password))
        {
            return Unauthorized(new
            {
                Status = false,
                Message = "Invalid username or password"
            });
        }

        // Bước 2: Lấy vai trò thật từ Identity bằng _userManager.GetRolesAsync(user)
        var userRoles = await _userManager.GetRolesAsync(user);
        var isAdmin = userRoles.Any(r => string.Equals(r, "Admin", StringComparison.OrdinalIgnoreCase));

        // Bước 3: Nếu user có vai trò Admin -> Bỏ qua kiểm tra OTP
        // Bước 4: Nếu user là Staff hoặc User -> Bắt buộc phải có OTP
        if (!isAdmin)
        {
            if (string.IsNullOrWhiteSpace(model.Otp))
            {
                return BadRequest(new
                {
                    status = false,
                    code = "OTP_REQUIRED",
                    requiresOtp = true,
                    message = "Tài khoản của bạn yêu cầu xác thực mã OTP gửi về email."
                });
            }

            // Kiểm tra OTP: ExpirationTime, AttemptsCount, Single-use
            var (isValid, otpError) = _otpService.ValidateOtp(user.UserName!, model.Otp.Trim());
            if (!isValid)
            {
                return BadRequest(new
                {
                    status = false,
                    message = otpError
                });
            }
        }

        // Cấp JWT chỉ khi thông tin hợp lệ
        var authClaims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Name, user.UserName ?? string.Empty),
            new Claim(JwtRegisteredClaimNames.Sub, user.UserName ?? string.Empty),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        foreach (var userRole in userRoles)
        {
            authClaims.Add(new Claim(ClaimTypes.Role, userRole));
            authClaims.Add(new Claim("role", userRole));
        }

        var token = GenerateToken(authClaims);
        var primaryRole = isAdmin
            ? "Admin"
            : (userRoles.FirstOrDefault(r => string.Equals(r, "Staff", StringComparison.OrdinalIgnoreCase)) ?? userRoles.FirstOrDefault() ?? "User");

        return Ok(new
        {
            Status = true,
            Message = "Logged in successfully",
            Token = token,
            Role = primaryRole
        });
    }

    [AllowAnonymous]
    [HttpPost("login-face")]
    public async Task<IActionResult> LoginFace([FromBody] FaceLoginRequest request)
    {
        if (request == null || string.IsNullOrWhiteSpace(request.Username) ||
            ((request.Features == null || request.Features.Count == 0) && string.IsNullOrWhiteSpace(request.FaceVectorJson)))
        {
            return BadRequest(new
            {
                status = false,
                message = "Vui lòng cung cấp tên đăng nhập và dữ liệu đặc trưng khuôn mặt."
            });
        }

        var username = request.Username.Trim();
        var user = await _userManager.FindByNameAsync(username) ?? await _userManager.FindByEmailAsync(username);
        if (user == null)
        {
            return NotFound(new
            {
                status = false,
                message = "Không tìm thấy tài khoản với tên đăng nhập này."
            });
        }

        var profile = await _context.UserFaceProfiles.FirstOrDefaultAsync(p => p.UserId == user.Id);
        if (profile == null || string.IsNullOrWhiteSpace(profile.FaceVectorJson))
        {
            return NotFound(new
            {
                status = false,
                code = "NO_FACE_PROFILE",
                message = "Tài khoản chưa đăng ký mẫu khuôn mặt. Vui lòng đăng nhập bằng mật khẩu để đăng ký mẫu trước."
            });
        }

        var inputFeatures = ExtractFeatures(request.Features, request.FaceVectorJson);
        if (inputFeatures == null || !FeatureKeys.Any(k => inputFeatures.ContainsKey(k)))
        {
            return BadRequest(new
            {
                status = false,
                message = "Dữ liệu đặc trưng khuôn mặt không hợp lệ."
            });
        }

        var registeredFeatures = ExtractFeatures(null, profile.FaceVectorJson);
        if (registeredFeatures == null || !FeatureKeys.Any(k => registeredFeatures.ContainsKey(k)))
        {
            return NotFound(new
            {
                status = false,
                code = "NO_FACE_PROFILE",
                message = "Tài khoản chưa đăng ký mẫu khuôn mặt. Vui lòng đăng nhập bằng mật khẩu để đăng ký mẫu trước."
            });
        }

        var similarity = CalculateSimilarity(inputFeatures, registeredFeatures);
        if (similarity < 0.65)
        {
            return BadRequest(new
            {
                status = false,
                message = "Khuôn mặt không khớp với mẫu đã đăng ký của tài khoản."
            });
        }

        var userRoles = await _userManager.GetRolesAsync(user);
        var authClaims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id),
            new Claim(ClaimTypes.Name, user.UserName ?? string.Empty),
            new Claim(JwtRegisteredClaimNames.Sub, user.UserName ?? string.Empty),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        foreach (var userRole in userRoles)
        {
            authClaims.Add(new Claim(ClaimTypes.Role, userRole));
            authClaims.Add(new Claim("role", userRole));
        }

        var token = GenerateToken(authClaims);
        var primaryRole = userRoles.FirstOrDefault(r => string.Equals(r, "Admin", StringComparison.OrdinalIgnoreCase))
            ?? userRoles.FirstOrDefault(r => string.Equals(r, "Staff", StringComparison.OrdinalIgnoreCase))
            ?? userRoles.FirstOrDefault()
            ?? "User";

        return Ok(new
        {
            status = true,
            message = "Đăng nhập bằng khuôn mặt thành công",
            token = token,
            role = primaryRole
        });
    }

    private static readonly string[] FeatureKeys = ["boxAspect", "eyeDistRatio", "eyeToNoseRatio", "noseToMouthRatio"];

    private static Dictionary<string, double>? ExtractFeatures(Dictionary<string, double>? dict, string? jsonStr)
    {
        if (dict != null && dict.Count > 0)
        {
            return new Dictionary<string, double>(dict, StringComparer.OrdinalIgnoreCase);
        }

        if (string.IsNullOrWhiteSpace(jsonStr))
        {
            return null;
        }

        try
        {
            using var doc = JsonDocument.Parse(jsonStr);
            var root = doc.RootElement;
            var result = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);

            if (root.ValueKind == JsonValueKind.Object)
            {
                foreach (var prop in root.EnumerateObject())
                {
                    if (prop.Value.TryGetDouble(out var val))
                    {
                        result[prop.Name] = val;
                    }
                }
                return result;
            }
            else if (root.ValueKind == JsonValueKind.Array)
            {
                var arr = root.EnumerateArray().ToList();
                for (int i = 0; i < Math.Min(arr.Count, FeatureKeys.Length); i++)
                {
                    if (arr[i].TryGetDouble(out var val))
                    {
                        result[FeatureKeys[i]] = val;
                    }
                }
                return result;
            }
        }
        catch
        {
            return null;
        }

        return null;
    }

    private static double CalculateSimilarity(
        IReadOnlyDictionary<string, double> sample1,
        IReadOnlyDictionary<string, double> sample2)
    {
        double diff = 0.0;
        int count = 0;

        foreach (var key in FeatureKeys)
        {
            if (sample1.TryGetValue(key, out var v1) && sample2.TryGetValue(key, out var v2))
            {
                diff += Math.Abs(v1 - v2);
                count++;
            }
        }

        if (count == 0) return 0.0;
        var avgDiff = diff / count;
        return Math.Clamp(1.0 - (avgDiff * 3.0), 0.0, 1.0);
    }

    private string GenerateToken(IEnumerable<Claim> claims)
    {
        var jwtSettings = _configuration.GetSection("JWTKey");
        var secret = jwtSettings["Secret"]
            ?? throw new InvalidOperationException("JWTKey:Secret is not configured.");
        var authSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));

        var expiryHours = 24.0;
        if (double.TryParse(jwtSettings["TokenExpiryTimeInHour"], out var parsedExpiry))
        {
            expiryHours = parsedExpiry;
        }

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = DateTime.UtcNow.AddHours(expiryHours),
            Issuer = jwtSettings["ValidIssuer"],
            Audience = jwtSettings["ValidAudience"],
            SigningCredentials = new SigningCredentials(authSigningKey, SecurityAlgorithms.HmacSha256)
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);
        return tokenHandler.WriteToken(token);
    }
}
