using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using NgocTruong_2380602415.Api.Models;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Controllers;

public class OtpRequestModel
{
    public string Username { get; set; } = string.Empty;
}

[ApiController]
[Route("api/[controller]")]
public class AuthenticateController : ControllerBase
{
    private readonly UserManager<User> _userManager;
    private readonly RoleManager<IdentityRole> _roleManager;
    private readonly IConfiguration _configuration;
    private readonly IOtpService _otpService;
    private readonly ILogger<AuthenticateController> _logger;

    public AuthenticateController(
        UserManager<User> userManager,
        RoleManager<IdentityRole> roleManager,
        IConfiguration configuration,
        IOtpService otpService,
        ILogger<AuthenticateController> logger)
    {
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

        // 1. Kiểm tra password trước
        if (user == null || !await _userManager.CheckPasswordAsync(user, model.Password))
        {
            return Unauthorized(new
            {
                Status = false,
                Message = "Invalid username or password"
            });
        }

        // 2. Bắt buộc OTP cho luồng đăng nhập username/password: kiểm tra password trước, kiểm tra OTP sau
        if (string.IsNullOrWhiteSpace(model.Otp))
        {
            return BadRequest(new
            {
                Status = false,
                Message = "Vui lòng nhập mã OTP xác thực đăng nhập."
            });
        }

        // 3. Kiểm tra OTP: ExpirationTime, AttemptsCount, Single-use
        var (isValid, otpError) = _otpService.ValidateOtp(user.UserName!, model.Otp.Trim());
        if (!isValid)
        {
            return BadRequest(new
            {
                Status = false,
                Message = otpError
            });
        }

        // Cấp JWT chỉ khi cả hai hợp lệ
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

        return Ok(new
        {
            Status = true,
            Message = "Logged in successfully",
            Token = token,
            Role = userRoles.FirstOrDefault() ?? "User"
        });
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
