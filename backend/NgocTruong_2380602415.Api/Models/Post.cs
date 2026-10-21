namespace NgocTruong_2380602415.Api.Models;

// Historical schema entity retained for existing databases and EF migrations only.
public sealed class Post
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
}
