using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Services;

namespace NgocTruong_2380602415.Api.Tests;

internal sealed class ApiFactory(string databasePath) : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
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

            services.RemoveAll<DbContextOptions<PracticeDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<PracticeDbContext>>();
            services.RemoveAll<PracticeDbContext>();
            services.AddDbContext<PracticeDbContext>(options =>
            {
                options.UseSqlite($"Data Source={databasePath};Pooling=False");
                options.ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning));
            });
        });
    }

    public async Task<HttpClient> CreateAuthenticatedClientAsync(string username = "admin", string password = "Admin@123456")
    {
        var client = CreateClient();
        await client.PostAsJsonAsync("/api/Authenticate/request-otp", new { username });
        var otpService = Services.GetRequiredService<IOtpService>();
        var otp = otpService.GetActiveOtpForTesting(username);
        var response = await client.PostAsJsonAsync("/api/Authenticate/login", new { username, password, otp });
        response.EnsureSuccessStatusCode();
        var json = await response.Content.ReadFromJsonAsync<JsonElement>();
        var token = json.GetProperty("token").GetString();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }
}

internal sealed class TestDatabase : IDisposable
{
    public string Path { get; } = System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"ngoctruong-api-{Guid.NewGuid():N}.db");
    public ApiFactory Open() => new(Path);
    public void Dispose()
    {
        foreach (var path in new[] { Path, Path + "-shm", Path + "-wal" })
            if (File.Exists(path)) File.Delete(path);
    }
}
