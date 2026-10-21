using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Data;

public class ApplicationDbContext : IdentityDbContext<User>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    // Historical tables remain mapped to preserve the existing SQL schema and migration history.
    // They have no application endpoints and receive no demo seed data.
    public DbSet<Product> Products { get; set; } = null!;
    public DbSet<Post> Posts { get; set; } = null!;
    public DbSet<Category> Categories { get; set; } = null!;
    public DbSet<AttendanceRecord> AttendanceRecords { get; set; } = null!;
    public DbSet<UserFaceProfile> UserFaceProfiles { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.HasDefaultSchema("identity");
        builder.Entity<User>().Property(u => u.Initials).HasMaxLength(5);

        builder.Entity<Product>(entity =>
        {
            entity.ToTable("Products", "dbo");
            entity.Property(product => product.Name).HasMaxLength(200);
            entity.Property(product => product.Description).HasMaxLength(2000);
            entity.Property(product => product.Price).HasPrecision(38, 9);
            entity.HasOne(product => product.Category)
                  .WithMany()
                  .HasForeignKey(product => product.CategoryId)
                  .OnDelete(DeleteBehavior.SetNull);
        });

        builder.Entity<Category>(entity =>
        {
            entity.ToTable("Categories", "dbo");
            entity.Property(category => category.Name).HasMaxLength(200).IsRequired();
            entity.Property(category => category.Description).HasMaxLength(2000);
        });

        builder.Entity<Post>(entity =>
        {
            entity.ToTable("Posts", "dbo");
            entity.Property(post => post.Title).HasMaxLength(200).IsRequired();
            entity.Property(post => post.Body).HasMaxLength(5000).IsRequired();
        });

        builder.Entity<AttendanceRecord>(entity =>
        {
            entity.ToTable("AttendanceRecords", "dbo");
            entity.HasKey(a => a.Id);
            entity.Property(a => a.UserId).IsRequired();
            entity.Property(a => a.Method).HasMaxLength(50).IsRequired();
            entity.Property(a => a.LocationName).HasMaxLength(255);
            entity.Property(a => a.DeviceInfo).HasMaxLength(255);
            entity.Property(a => a.Status).HasMaxLength(50).IsRequired();
            entity.Property(a => a.Notes).HasMaxLength(1000);
            entity.Property(a => a.FeedbackMood).HasMaxLength(50);
            entity.Property(a => a.FeedbackNote).HasMaxLength(500);
            entity.HasOne(a => a.User)
                  .WithMany()
                  .HasForeignKey(a => a.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });

        builder.Entity<UserFaceProfile>(entity =>
        {
            entity.ToTable("UserFaceProfiles", "dbo");
            entity.HasKey(f => f.Id);
            entity.Property(f => f.UserId).IsRequired();
            entity.Property(f => f.FaceVectorJson).IsRequired();
            entity.Property(f => f.UpdatedBy).HasMaxLength(100);
            entity.HasOne(f => f.User)
                  .WithMany()
                  .HasForeignKey(f => f.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
