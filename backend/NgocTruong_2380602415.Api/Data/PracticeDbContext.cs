using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Data;

public class PracticeDbContext(DbContextOptions<PracticeDbContext> options) : DbContext(options)
{
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<Product> Products => Set<Product>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Post>(entity =>
        {
            entity.Property(post => post.Title).HasMaxLength(200).IsRequired();
            entity.Property(post => post.Body).HasMaxLength(5000).IsRequired();
        });
        modelBuilder.Entity<Product>(entity =>
        {
            entity.Property(product => product.Name).HasMaxLength(200).IsRequired();
            entity.Property(product => product.Description).HasMaxLength(2000).IsRequired();
            entity.Property(product => product.Price).HasPrecision(38, 9);
        });
    }
}
