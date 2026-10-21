using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Data;

public static class DatabaseInitializer
{
    public static async Task InitializeAsync(PracticeDbContext db, CancellationToken cancellationToken = default)
    {
        // Guard the initialization target even if a connection string is accidentally replaced.
        if (db.Database.IsSqlServer() && db.Database.GetDbConnection().Database != "NgocTruong_2380602415_Practice")
            throw new InvalidOperationException("Only NgocTruong_2380602415_Practice may be initialized by this application.");

        var existed = await db.GetService<IRelationalDatabaseCreator>().ExistsAsync(cancellationToken);
        await db.Database.EnsureCreatedAsync(cancellationToken);
        if (existed) return;

        db.Posts.AddRange(
            new Post { UserId = 1, Title = "Chào mừng đến bảng tin", Body = "Ứng dụng luyện thi của Ngọc Trường — xem, thêm, sửa và xóa bài viết." },
            new Post { UserId = 2, Title = "Ôn tập REST API", Body = "Thực hành GET theo ID, POST, PUT và DELETE với SQL Server." },
            new Post { UserId = 1, Title = "Kết nối Android", Body = "Dùng địa chỉ 10.0.2.2:5186 cho máy ảo Android hoặc URL HTTPS Conveyor." });
        db.Products.AddRange(
            new Product { Name = "Cà phê sữa", Description = "Cà phê Việt Nam", Price = 25000m },
            new Product { Name = "Trà đào", Description = "Trà đào tươi", Price = 30000m },
            new Product { Name = "Bánh mì", Description = "Bánh mì nóng", Price = 20000m });
        await db.SaveChangesAsync(cancellationToken);
    }
}
