using System.Data.Common;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.IdentityModel.Tokens;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;
using NgocTruong_2380602415.Api.Repositories;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddScoped<IProductRepository, ProductRepository>();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? builder.Configuration.GetConnectionString("PracticeDatabase")
    ?? throw new InvalidOperationException("Configure ConnectionStrings:PracticeDatabase or DefaultConnection in appsettings.json.");

builder.Services.AddDbContext<ApplicationDbContext>(options =>
{
    options.UseSqlServer(connectionString, b => b.MigrationsHistoryTable("__EFMigrationsHistory", "dbo"));
    options.ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning));
});

builder.Services.AddIdentity<User, IdentityRole>(options =>
{
    options.Password.RequireDigit = false;
    options.Password.RequireLowercase = false;
    options.Password.RequireUppercase = false;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequiredLength = 6;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

var jwtSettings = builder.Configuration.GetSection("JWTKey");
var jwtSecret = jwtSettings["Secret"] ?? "AReallyLongSecretKeyForYourJWTTokenSigning!NgocTruong2380602415SecureKey";
var jwtKey = Encoding.UTF8.GetBytes(jwtSecret);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.SaveToken = true;
    options.RequireHttpsMetadata = false;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["ValidIssuer"] ?? "NgocTruongApi",
        ValidAudience = jwtSettings["ValidAudience"] ?? "NgocTruongClient",
        IssuerSigningKey = new SymmetricSecurityKey(jwtKey)
    };
});

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("MyAllowOrigins", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});



builder.Services.AddProblemDetails();

var app = builder.Build();

app.UseExceptionHandler(handler => handler.Run(async context =>
{
    var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    var databaseError = exception is DbException or DbUpdateException;
    await Results.Problem(
        statusCode: databaseError ? StatusCodes.Status503ServiceUnavailable : StatusCodes.Status500InternalServerError,
        title: databaseError ? "Database is unavailable. Check SQL Server and try again." : "The request could not be completed.",
        detail: exception?.ToString())
        .ExecuteAsync(context);
}));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("MyAllowOrigins");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

try
{
    await using var scope = app.Services.CreateAsyncScope();
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole>>();
    var userManager = scope.ServiceProvider.GetRequiredService<UserManager<User>>();
    await DatabaseInitializer.InitializeAsync(db, roleManager, userManager);
}
catch (Exception exception)
{
    Console.WriteLine($"[CRITICAL ERROR DURING INITIALIZATION]: {exception}");
    app.Logger.LogCritical(exception, "Database initialization failed. Start SQL Server and check ConnectionStrings:PracticeDatabase. " +
        "The database must be named NgocTruong_2380602415_Practice. No other database will be initialized.");
    Environment.ExitCode = 1;
    if (!app.Environment.IsDevelopment()) return;
    throw;
}

await app.RunAsync();
public partial class Program;
