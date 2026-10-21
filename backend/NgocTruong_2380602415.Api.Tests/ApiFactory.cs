using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using NgocTruong_2380602415.Api.Data;

namespace NgocTruong_2380602415.Api.Tests;

internal sealed class ApiFactory(string databasePath) : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<PracticeDbContext>>();
            services.RemoveAll<IDbContextOptionsConfiguration<PracticeDbContext>>();
            services.RemoveAll<PracticeDbContext>();
            services.AddDbContext<PracticeDbContext>(options => options.UseSqlite($"Data Source={databasePath};Pooling=False"));
        });
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
