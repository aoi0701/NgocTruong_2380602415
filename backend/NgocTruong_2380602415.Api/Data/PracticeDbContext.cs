using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;

namespace NgocTruong_2380602415.Api.Data;

public class PracticeDbContext : ApplicationDbContext
{
    public PracticeDbContext(DbContextOptions<PracticeDbContext> options)
        : base(ChangeOptions(options))
    {
    }

    private static DbContextOptions<ApplicationDbContext> ChangeOptions(DbContextOptions<PracticeDbContext> options)
    {
        var builder = new DbContextOptionsBuilder<ApplicationDbContext>();
        foreach (var extension in options.Extensions)
        {
            ((IDbContextOptionsBuilderInfrastructure)builder).AddOrUpdateExtension(extension);
        }
        return builder.Options;
    }
}
