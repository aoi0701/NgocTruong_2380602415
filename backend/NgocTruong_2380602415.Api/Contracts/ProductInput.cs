using System.ComponentModel.DataAnnotations;

namespace NgocTruong_2380602415.Api.Contracts;

public sealed class ProductInput
{
    private string _name = "";
    [Required, StringLength(200, MinimumLength = 1)]
    public string Name { get => _name; init => _name = value?.Trim() ?? ""; }

    private string _description = "";
    [StringLength(2000)]
    public string Description { get => _description; init => _description = value?.Trim() ?? ""; }

    [Range(typeof(decimal), "0", "79228162514264337593543950335")]
    public decimal Price { get; init; }
}
