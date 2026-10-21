namespace NgocTruong_2380602415.Api.Services;

public interface IOtpService
{
    (bool CanSend, string? ErrorMessage, int? CooldownRemainingSeconds) CheckCooldown(string username);
    Task<string> GenerateAndSendOtpAsync(string username, string email, CancellationToken cancellationToken = default);
    (bool IsValid, string ErrorMessage) ValidateOtp(string username, string otpCode);
    string? GetActiveOtpForTesting(string username);
    void ResetCooldownForTesting(string username);
}
