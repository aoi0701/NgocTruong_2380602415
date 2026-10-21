using System.ComponentModel.DataAnnotations;

namespace NgocTruong_2380602415.Api.Contracts;

public sealed class PostInput
{
    [Range(1, int.MaxValue)]
    public int UserId { get; init; }

    private string _title = "";
    [Required, StringLength(200, MinimumLength = 1)]
    public string Title { get => _title; init => _title = value?.Trim() ?? ""; }

    private string _body = "";
    [Required, StringLength(5000, MinimumLength = 1)]
    public string Body { get => _body; init => _body = value?.Trim() ?? ""; }
}
