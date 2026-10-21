using System.Collections.Concurrent;
using System.Security.Cryptography;

namespace NgocTruong_2380602415.Api.Services;

public class OtpItem
{
    public string Code { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public int FailedAttempts { get; set; }
    public DateTime LastSentAt { get; set; }
}

public class OtpService : IOtpService
{
    private static readonly ConcurrentDictionary<string, OtpItem> _otpStore = new(StringComparer.OrdinalIgnoreCase);
    private static readonly object _validateLock = new();
    private readonly IEmailService _emailService;
    private readonly ILogger<OtpService> _logger;

    public OtpService(IEmailService emailService, ILogger<OtpService> logger)
    {
        _emailService = emailService;
        _logger = logger;
    }

    public (bool CanSend, string? ErrorMessage, int? CooldownRemainingSeconds) CheckCooldown(string username)
    {
        if (string.IsNullOrWhiteSpace(username))
            return (false, "Tên người dùng không hợp lệ.", null);

        var key = username.Trim();
        if (_otpStore.TryGetValue(key, out var existing))
        {
            var elapsedSeconds = (DateTime.UtcNow - existing.LastSentAt).TotalSeconds;
            if (elapsedSeconds < 60)
            {
                var remaining = (int)Math.Ceiling(60 - elapsedSeconds);
                return (false, $"Vui lòng đợi {remaining} giây trước khi yêu cầu gửi lại mã OTP.", remaining);
            }
        }

        return (true, null, null);
    }

    public async Task<string> GenerateAndSendOtpAsync(string username, string email, CancellationToken cancellationToken = default)
    {
        var key = username.Trim();

        // Tạo mã số OTP 6 chữ số ngẫu nhiên bằng bộ sinh số an toàn
        var otpCode = RandomNumberGenerator.GetInt32(100000, 1000000).ToString("D6");
        var now = DateTime.UtcNow;

        // BẮT BUỘC: Gửi email trước. Nếu email thất bại (ném exception), OTP TUYỆT ĐỐI KHÔNG được lưu vào bộ nhớ!
        await _emailService.SendOtpEmailAsync(email, key, otpCode, cancellationToken);

        var item = new OtpItem
        {
            Code = otpCode,
            CreatedAt = now,
            ExpiresAt = now.AddMinutes(5), // Hạn sử dụng 5 phút
            FailedAttempts = 0,
            LastSentAt = now
        };

        lock (_validateLock)
        {
            _otpStore[key] = item;
        }

        _logger.LogInformation("Đã gửi email OTP thành công và khởi tạo OTP mới cho tài khoản '{Username}', hết hạn lúc {ExpiresAt}", key, item.ExpiresAt);

        return otpCode;
    }

    public (bool IsValid, string ErrorMessage) ValidateOtp(string username, string otpCode)
    {
        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(otpCode))
        {
            return (false, "Vui lòng nhập đầy đủ tên đăng nhập và mã OTP.");
        }

        var key = username.Trim();
        var code = otpCode.Trim();

        // Sử dụng lock để chống race condition khi có nhiều request đồng thời xác thực cùng lúc
        lock (_validateLock)
        {
            if (!_otpStore.TryGetValue(key, out var item))
            {
                return (false, "Mã OTP không tồn tại hoặc chưa được yêu cầu. Vui lòng bấm Gửi OTP trước khi đăng nhập.");
            }

            // Kiểm tra thời gian hết hạn (5 phút)
            if (DateTime.UtcNow > item.ExpiresAt)
            {
                _otpStore.TryRemove(key, out _);
                return (false, "Mã OTP đã hết hạn (quá 5 phút). Vui lòng yêu cầu mã OTP mới.");
            }

            // Kiểm tra mã OTP khớp hay sai
            if (!string.Equals(item.Code, code, StringComparison.Ordinal))
            {
                item.FailedAttempts++;
                if (item.FailedAttempts >= 3)
                {
                    // Vượt quá 3 lần thử sai -> vô hiệu hóa mã OTP
                    _otpStore.TryRemove(key, out _);
                    return (false, "Mã OTP không chính xác. Bạn đã nhập sai 3 lần, mã OTP đã bị vô hiệu hóa.");
                }

                var remaining = 3 - item.FailedAttempts;
                return (false, $"Mã OTP không chính xác. Bạn còn {remaining} lần thử.");
            }

            // Mã chính xác -> Single-use: Hủy OTP ngay sau khi xác thực thành công
            _otpStore.TryRemove(key, out _);
            _logger.LogInformation("Xác thực OTP thành công cho tài khoản '{Username}'. Mã OTP đã được giải phóng (single-use).", key);

            return (true, string.Empty);
        }
    }

    public string? GetActiveOtpForTesting(string username)
    {
        if (string.IsNullOrWhiteSpace(username)) return null;
        lock (_validateLock)
        {
            if (_otpStore.TryGetValue(username.Trim(), out var item))
            {
                if (DateTime.UtcNow <= item.ExpiresAt)
                {
                    return item.Code;
                }
            }
        }
        return null;
    }

    public void ResetCooldownForTesting(string username)
    {
        if (string.IsNullOrWhiteSpace(username)) return;
        lock (_validateLock)
        {
            _otpStore.TryRemove(username.Trim(), out _);
        }
    }
}
