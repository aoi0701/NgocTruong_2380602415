using System.ComponentModel.DataAnnotations;

namespace NgocTruong_2380602415.Api.Models;

public class LoginModel
{
    [Required]
    public string Username { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}
