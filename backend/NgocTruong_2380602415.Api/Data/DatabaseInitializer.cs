using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
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

    }
}
