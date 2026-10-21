using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Tests;

public class LocalOtpTests
{
    private static OtpService Create(string environment, bool enabled = true) => new(
        new FailingEmailService(), NullLogger<OtpService>.Instance,
        new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["LocalOtp:Enabled"] = enabled.ToString(),
            ["LocalOtp:Codes:0"] = "123456",
            ["LocalOtp:Codes:1"] = "234567",
            ["LocalOtp:Codes:2"] = "345678",
            ["LocalOtp:Codes:3"] = "456789",
            ["LocalOtp:Codes:4"] = "567890"
        }).Build(), new TestEnvironment { EnvironmentName = environment });

    [Theory]
    [InlineData("123456")]
    [InlineData("234567")]
    [InlineData("345678")]
    [InlineData("456789")]
    [InlineData("567890")]
    public async Task Local_codes_require_request_and_are_single_use(string code)
    {
        var service = Create(Environments.Development);
        var username = "local_" + Guid.NewGuid().ToString("N");
        Assert.False(service.ValidateOtp(username, code).IsValid);
        await service.GenerateAndSendOtpAsync(username, "test@example.com");
        Assert.False(service.ValidateOtp(username, "000000").IsValid);
        Assert.True(service.ValidateOtp(username, code).IsValid);
        Assert.False(service.ValidateOtp(username, "123456").IsValid);
    }

    [Theory]
    [InlineData("Production", true)]
    [InlineData("Development", false)]
    public async Task Other_modes_still_require_real_email(string environment, bool enabled)
    {
        var service = Create(environment, enabled);
        Assert.False(service.IsLocalMode);
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            service.GenerateAndSendOtpAsync("normal_" + Guid.NewGuid(), "test@example.com"));
    }

    private sealed class TestEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "";
        public string ApplicationName { get; set; } = "Test";
        public string ContentRootPath { get; set; } = "";
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
