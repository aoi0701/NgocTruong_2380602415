using System.ComponentModel.DataAnnotations;

namespace NgocTruong_2380602415.Api.Models;

// Historical schema entity retained for existing databases and EF migrations only.
public class Product
{
    public int Id { get; set; }

    private string? _name;
    [Required, StringLength(200, MinimumLength = 1)]
    public string? Name
    {
        get => _name;
        set => _name = value is null ? null : (string.IsNullOrWhiteSpace(value) ? "" : value.Trim());
    }

    [Range(typeof(decimal), "0", "79228162514264337593543950335")]
    public decimal Price { get; set; }

    public string? Image { get; set; }

    private string? _description;
    [StringLength(2000)]
    public string? Description
    {
        get => _description;
        set => _description = value?.Trim();
    }

    public int? CategoryId { get; set; }
    public Category? Category { get; set; }
}
