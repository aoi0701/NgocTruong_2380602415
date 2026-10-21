namespace NgocTruong_2380602415.Api.Services;

public interface IEmailService
{
    Task SendOtpEmailAsync(string toEmail, string username, string otpCode, CancellationToken cancellationToken = default);
}
