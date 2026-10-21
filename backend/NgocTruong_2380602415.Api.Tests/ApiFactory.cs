using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection.Extensions;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Tests;

public class TestEmailService : IEmailService
{
    public string? LastSentOtp { get; private set; }
    public Task SendOtpEmailAsync(string toEmail, string username, string otpCode, CancellationToken cancellationToken = default)
    {
        LastSentOtp = otpCode;
        return Task.CompletedTask;
    }
}

public class FailingEmailService : IEmailService
{
    public Task SendOtpEmailAsync(string toEmail, string username, string otpCode, CancellationToken cancellationToken = default)
    {
        throw new InvalidOperationException("Dịch vụ email chưa được cấu hình SMTP. Vui lòng kiểm tra cấu hình SmtpSettings trong appsettings.json.");
    }
}

internal sealed class ApiFactory(string databasePath) : WebApplicationFactory<Program>
{
    public bool SimulateEmailFailure { get; set; } = false;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureAppConfiguration((_, configuration) =>
            configuration.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["LocalOtp:Enabled"] = "false"
            }));
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<ApplicationDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<ApplicationDbContext>>();
            services.RemoveAll<ApplicationDbContext>();
            services.AddDbContext<ApplicationDbContext>(options =>
            {
                options.UseSqlite($"Data Source={databasePath};Pooling=False");
                options.ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning));
            });

            services.RemoveAll<IEmailService>();
            if (SimulateEmailFailure)
            {
                services.AddSingleton<IEmailService, FailingEmailService>();
            }
            else
            {
                services.AddSingleton<IEmailService, TestEmailService>();
            }
        });
    }

    private static readonly SemaphoreSlim _authLock = new(1, 1);

    public async Task<HttpClient> CreateAuthenticatedClientAsync(string username = "admin", string password = "Admin@123456")
    {
        await _authLock.WaitAsync();
        try
        {
            var client = CreateClient();
            var otpService = Services.GetRequiredService<IOtpService>();
            otpService.ResetCooldownForTesting(username);
            var reqOtpRes = await client.PostAsJsonAsync("/api/Authenticate/request-otp", new { username });
            var otp = otpService.GetActiveOtpForTesting(username);
            var response = await client.PostAsJsonAsync("/api/Authenticate/login", new { username, password, otp });
            response.EnsureSuccessStatusCode();
            var json = await response.Content.ReadFromJsonAsync<JsonElement>();
            var token = json.GetProperty("token").GetString();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
            return client;
        }
        finally
        {
            _authLock.Release();
        }
    }
}

internal sealed class TestDatabase : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"ngoctruong-api-{Guid.NewGuid():N}.db");
    public ApiFactory Open(bool simulateEmailFailure = false)
    {
        var factory = new ApiFactory(Path) { SimulateEmailFailure = simulateEmailFailure };
        return factory;
    }
    public void Dispose()
    {
        foreach (var path in new[] { Path, Path + "-shm", Path + "-wal" })
            if (File.Exists(path)) File.Delete(path);
    }
}
