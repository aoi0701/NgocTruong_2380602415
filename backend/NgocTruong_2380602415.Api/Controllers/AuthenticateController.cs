using System.Collections.Concurrent;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using NgocTruong_2380602415.Api.Models;

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

    // Lưu trữ OTP tạm thời trong bộ nhớ kèm thời hạn 5 phút
    private static readonly ConcurrentDictionary<string, (string Code, DateTime Expiry)> _otpStore = new(StringComparer.OrdinalIgnoreCase);

    public AuthenticateController(
        UserManager<User> userManager,
        RoleManager<IdentityRole> roleManager,
        IConfiguration configuration)
    {
        _userManager = userManager;
        _roleManager = roleManager;
        _configuration = configuration;
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

        // Sinh mã OTP 6 chữ số ngẫu nhiên
        var otpCode = Random.Shared.Next(100000, 999999).ToString();
        var expiry = DateTime.UtcNow.AddMinutes(5);
        _otpStore[user.UserName!] = (otpCode, expiry);

        return Ok(new
        {
            Status = true,
            Message = $"Mã OTP đã được gửi thành công: {otpCode}",
            Otp = otpCode,
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

        var role = string.IsNullOrWhiteSpace(model.Role) ? "User" : model.Role.Trim();
        if (!await _roleManager.RoleExistsAsync(role))
        {
            await _roleManager.CreateAsync(new IdentityRole(role));
        }
        await _userManager.AddToRoleAsync(user, role);

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

        var user = await _userManager.FindByNameAsync(model.Username) ?? await _userManager.FindByEmailAsync(model.Username);
        if (user == null || !await _userManager.CheckPasswordAsync(user, model.Password))
        {
            return Unauthorized(new
            {
                Status = false,
                Message = "Invalid username or password"
            });
        }

        // Kiểm tra OTP nếu người dùng gửi kèm mã OTP
        if (!string.IsNullOrWhiteSpace(model.Otp))
        {
            var otp = model.Otp.Trim();
            var valid = false;

            // Chấp nhận mã master test '123456' hoặc mã OTP đã sinh trong _otpStore
            if (otp == "123456")
            {
                valid = true;
            }
            else if (_otpStore.TryGetValue(user.UserName!, out var stored) && stored.Expiry > DateTime.UtcNow && stored.Code == otp)
            {
                valid = true;
                _otpStore.TryRemove(user.UserName!, out _);
            }

            if (!valid)
            {
                return BadRequest(new
                {
                    Status = false,
                    Message = "Mã OTP không chính xác hoặc đã hết hạn (Thử dùng mã 123456 hoặc bấm Gửi OTP)."
                });
            }
        }

        var userRoles = await _userManager.GetRolesAsync(user);

        var authClaims = new List<Claim>
        {
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
