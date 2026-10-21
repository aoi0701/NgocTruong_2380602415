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
        var host = _configuration["SmtpSettings:Host"];
        var portString = _configuration["SmtpSettings:Port"];
        var senderEmail = _configuration["SmtpSettings:SenderEmail"] ?? "no-reply@hutech.edu.vn";
        var senderName = _configuration["SmtpSettings:SenderName"] ?? "HUTECH Attendance System";
        var smtpUsername = _configuration["SmtpSettings:Username"];
        var smtpPassword = _configuration["SmtpSettings:Password"];
        var enableSsl = bool.TryParse(_configuration["SmtpSettings:EnableSsl"], out var ssl) && ssl;

        // Nếu SMTP chưa được cấu hình đúng: BẮT BUỘC ném lỗi thật, tuyệt đối không ghi log giả lập thành công
        if (string.IsNullOrWhiteSpace(host) || !int.TryParse(portString, out var port) || port <= 0)
        {
            _logger.LogError("Dịch vụ SMTP chưa được cấu hình hoặc cấu hình không hợp lệ trong appsettings.json (Host: '{Host}', Port: '{Port}')", host, portString);
            throw new InvalidOperationException("Dịch vụ email chưa được cấu hình SMTP. Vui lòng kiểm tra cấu hình SmtpSettings trong appsettings.json.");
        }

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
            LastSentOtp = otpCode;
            _logger.LogInformation("Đã gửi email OTP thành công tới {Email}", toEmail);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Lỗi xảy ra khi gửi email OTP qua máy chủ SMTP ({Host}:{Port})", host, port);
            throw new InvalidOperationException("Gặp sự cố khi gửi email qua máy chủ SMTP.", ex);
        }
    }
}
