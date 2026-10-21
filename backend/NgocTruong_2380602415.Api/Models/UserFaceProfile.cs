using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace NgocTruong_2380602415.Api.Models;

[Table("UserFaceProfiles", Schema = "dbo")]
public class UserFaceProfile
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string UserId { get; set; } = string.Empty;

    [ForeignKey(nameof(UserId))]
    [JsonIgnore]
    public User? User { get; set; }

    [Required]
    public string FaceVectorJson { get; set; } = string.Empty;

    public DateTime EnrolledAt { get; set; }

    [MaxLength(100)]
    public string? UpdatedBy { get; set; }
}
