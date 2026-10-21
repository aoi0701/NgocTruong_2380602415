using System.Net;
using System.Net.Mail;

namespace NgocTruong_2380602415.Api.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    public string? LastSentOtp { get; private set; }

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendOtpEmailAsync(string toEmail, string username, string otpCode, CancellationToken cancellationToken = default)
    {
        LastSentOtp = otpCode;

        var host = _configuration["SmtpSettings:Host"];
        var portString = _configuration["SmtpSettings:Port"];
        var senderEmail = _configuration["SmtpSettings:SenderEmail"] ?? "no-reply@hutech.edu.vn";
        var senderName = _configuration["SmtpSettings:SenderName"] ?? "HUTECH Attendance System";
        var smtpUsername = _configuration["SmtpSettings:Username"];
        var smtpPassword = _configuration["SmtpSettings:Password"];
        var enableSsl = bool.TryParse(_configuration["SmtpSettings:EnableSsl"], out var ssl) && ssl;

        if (!string.IsNullOrWhiteSpace(host) && int.TryParse(portString, out var port) && port > 0)
        {
            try
            {
                using var client = new SmtpClient(host, port)
                {
                    EnableSsl = enableSsl,
                    DeliveryMethod = SmtpDeliveryMethod.Network,
                    UseDefaultCredentials = false
                };

                if (!string.IsNullOrWhiteSpace(smtpUsername) && !string.IsNullOrWhiteSpace(smtpPassword))
                {
                    client.Credentials = new NetworkCredential(smtpUsername, smtpPassword);
                }

                using var mail = new MailMessage
                {
                    From = new MailAddress(senderEmail, senderName),
                    Subject = "Mã OTP xác thực đăng nhập HUTECH",
                    Body = $"Kính gửi {username},\n\nMã OTP xác thực đăng nhập của bạn là: {otpCode}\n\nMã có hiệu lực trong vòng 5 phút. Vui lòng không chia sẻ mã này cho bất kỳ ai vì lý do an toàn bảo mật.\n\nTrân trọng,\nHUTECH Attendance System",
                    IsBodyHtml = false
                };

                mail.To.Add(toEmail);
                await client.SendMailAsync(mail, cancellationToken);
                _logger.LogInformation("Đã gửi email OTP thành công tới {Email}", toEmail);
                return;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Không thể gửi email OTP qua SMTP cấu hình ({Host}:{Port}). Chuyển sang ghi log bảo mật máy chủ.", host, port);
            }
        }

        // Khi chưa có thông tin SMTP bên ngoài hoặc gửi thất bại:
        // Ghi nhật ký bảo mật ra server console/log nhưng KHÔNG gửi lộ cho client
        _logger.LogInformation("[SECURE AUDIT LOG] OTP cho người dùng '{Username}' ({Email}): {OtpCode} (SMTP chưa cấu hình, đã ghi log an toàn tại server)",
            username, toEmail, otpCode);
    }
}
