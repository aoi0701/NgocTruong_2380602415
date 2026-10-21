using System.ComponentModel.DataAnnotations;

namespace NgocTruong_2380602415.Api.Models;

// Historical schema entity retained for existing databases and EF migrations only.
public class Category
{
    public int Id { get; set; }

    private string _name = string.Empty;
    [Required, StringLength(200, MinimumLength = 1)]
    public string Name
    {
        get => _name;
        set => _name = value?.Trim() ?? string.Empty;
    }

    private string? _description;
    [StringLength(2000)]
    public string? Description
    {
        get => _description;
        set => _description = value?.Trim();
    }
}
