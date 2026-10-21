using System.ComponentModel.DataAnnotations;

namespace NgocTruong_2380602415.Api.Models;

public class LoginModel
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;

    /// <summary>
    /// Mã OTP xác thực đăng nhập (hỗ trợ xác thực 2 lớp)
    /// </summary>
    public string? Otp { get; set; }
}
