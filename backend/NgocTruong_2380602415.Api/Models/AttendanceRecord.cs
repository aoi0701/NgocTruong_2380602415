using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace NgocTruong_2380602415.Api.Models;

[Table("AttendanceRecords", Schema = "dbo")]
public class AttendanceRecord
{
    [Key]
    public int Id { get; set; }

    [Required]
    public string UserId { get; set; } = string.Empty;

    [ForeignKey(nameof(UserId))]
    [JsonIgnore]
    public User? User { get; set; }

    public DateTime CheckInTime { get; set; }

    public DateTime? CheckOutTime { get; set; }

    [Required]
    [MaxLength(50)]
    public string Method { get; set; } = "GPS"; // QR, GPS, Face, Biometric

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    [MaxLength(255)]
    public string? LocationName { get; set; }

    [MaxLength(255)]
    public string? DeviceInfo { get; set; }

    [Required]
    [MaxLength(50)]
    public string Status { get; set; } = "Valid"; // Valid, OutsideRadius, Late, Approved

    [MaxLength(1000)]
    public string? Notes { get; set; }

    [MaxLength(50)]
    public string? FeedbackMood { get; set; }

    [MaxLength(500)]
    public string? FeedbackNote { get; set; }

    public DateTime? FeedbackTime { get; set; }
}
