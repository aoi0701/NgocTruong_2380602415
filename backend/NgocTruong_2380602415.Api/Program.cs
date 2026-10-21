using System.Data.Common;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Data;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddProblemDetails();
builder.Services.AddDbContext<PracticeDbContext>(options => options.UseSqlServer(
    builder.Configuration.GetConnectionString("PracticeDatabase")
    ?? throw new InvalidOperationException("Configure ConnectionStrings:PracticeDatabase in appsettings.json or user secrets.")));

var app = builder.Build();
app.UseExceptionHandler(handler => handler.Run(async context =>
{
    var exception = context.Features.Get<IExceptionHandlerFeature>()?.Error;
    var databaseError = exception is DbException or DbUpdateException;
    await Results.Problem(
        statusCode: databaseError ? StatusCodes.Status503ServiceUnavailable : StatusCodes.Status500InternalServerError,
        title: databaseError ? "Database is unavailable. Check SQL Server and try again." : "The request could not be completed.")
        .ExecuteAsync(context);
}));

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}
app.MapControllers();

try
{
    await using var scope = app.Services.CreateAsyncScope();
    await DatabaseInitializer.InitializeAsync(scope.ServiceProvider.GetRequiredService<PracticeDbContext>());
}
catch (Exception exception) when (exception is DbException or InvalidOperationException or DbUpdateException)
{
    app.Logger.LogCritical("Database initialization failed. Start SQL Server and check ConnectionStrings:PracticeDatabase. " +
        "The database must be named NgocTruong_2380602415_Practice. No other database will be initialized.");
    Environment.ExitCode = 1;
    return;
}

await app.RunAsync();
public partial class Program;
