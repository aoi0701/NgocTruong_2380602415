using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Storage;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Data;

public static class DatabaseInitializer
{
    public static async Task InitializeAsync(
        ApplicationDbContext db,
        RoleManager<IdentityRole> roleManager,
        UserManager<User> userManager,
        CancellationToken cancellationToken = default)
    {
        if (db.Database.IsSqlServer())
        {
            if (db.Database.GetDbConnection().Database != "NgocTruong_2380602415_Practice")
                throw new InvalidOperationException("Only NgocTruong_2380602415_Practice may be initialized by this application.");
        }

        var existed = await db.GetService<IRelationalDatabaseCreator>().ExistsAsync(cancellationToken);

        if (db.Database.IsSqlServer())
        {
            await db.Database.MigrateAsync(cancellationToken);
        }
        else
        {
            await db.Database.EnsureCreatedAsync(cancellationToken);
        }

        var roles = new[] { "Admin", "User", "Staff" };
        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole(role));
            }
        }

        const string adminUserName = "admin";
        var adminUser = await userManager.FindByNameAsync(adminUserName);
        if (adminUser == null)
        {
            adminUser = new User
            {
                UserName = adminUserName,
                Email = "admin@example.com",
                Initials = "ADM",
                EmailConfirmed = true
            };
            var result = await userManager.CreateAsync(adminUser, "Admin@123456");
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(adminUser, "Admin");
            }
        }

        const string staffUserName = "staff";
        var staffUser = await userManager.FindByNameAsync(staffUserName);
        if (staffUser == null)
        {
            staffUser = new User
            {
                UserName = staffUserName,
                Email = "staff@example.com",
                Initials = "STF",
                EmailConfirmed = true
            };
            var result = await userManager.CreateAsync(staffUser, "Staff@123456");
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(staffUser, "Staff");
            }
        }

        const string regularUserName = "user";
        var regularUser = await userManager.FindByNameAsync(regularUserName);
        if (regularUser == null)
        {
            regularUser = new User
            {
                UserName = regularUserName,
                Email = "user@example.com",
                Initials = "USR",
                EmailConfirmed = true
            };
            var result = await userManager.CreateAsync(regularUser, "User@123456");
            if (result.Succeeded)
            {
                await userManager.AddToRoleAsync(regularUser, "User");
            }
        }

        if (existed) return;

        db.Posts.AddRange(
            new Post { UserId = 1, Title = "Chào mừng đến bảng tin", Body = "Ứng dụng luyện thi của Ngọc Trường — xem, thêm, sửa và xóa bài viết." },
            new Post { UserId = 2, Title = "Ôn tập REST API", Body = "Thực hành GET theo ID, POST, PUT và DELETE với SQL Server." },
            new Post { UserId = 1, Title = "Kết nối Android", Body = "Dùng địa chỉ 10.0.2.2:5186 cho máy ảo Android hoặc URL HTTPS Conveyor." });

        var drinkCategory = new Category { Name = "Đồ uống", Description = "Các loại trà, cà phê và nước giải khát" };
        var foodCategory = new Category { Name = "Đồ ăn", Description = "Bánh mì và các món ăn nhanh" };
        db.Categories.AddRange(drinkCategory, foodCategory);
        await db.SaveChangesAsync(cancellationToken);

        db.Products.AddRange(
            new Product { Name = "Cà phê sữa", Description = "Cà phê Việt Nam", Price = 25000m, Category = drinkCategory },
            new Product { Name = "Trà đào", Description = "Trà đào tươi", Price = 30000m, Category = drinkCategory },
            new Product { Name = "Bánh mì", Description = "Bánh mì nóng", Price = 20000m, Category = foodCategory });
        await db.SaveChangesAsync(cancellationToken);
    }
}
