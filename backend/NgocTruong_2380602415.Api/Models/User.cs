using Microsoft.AspNetCore.Identity;

namespace NgocTruong_2380602415.Api.Models;

public class User : IdentityUser
{
    public string? Initials { get; set; }
}
