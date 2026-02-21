using Dapper;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

var connStr = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? "Host=localhost;Port=5432;Database=sampledb;Username=testuser;Password=testpass";

builder.Services.AddScoped<NpgsqlConnection>(_ => new NpgsqlConnection(connStr));

var app = builder.Build();

// Auto-create table on startup
using (var conn = new NpgsqlConnection(connStr))
{
    await conn.OpenAsync();
    await conn.ExecuteAsync("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL
        )
    """);
}

app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.MapGet("/users", async (NpgsqlConnection db) =>
{
    await db.OpenAsync();
    var users = await db.QueryAsync<User>("SELECT id, name, email FROM users");
    return Results.Ok(users);
});

app.MapPost("/users", async (NpgsqlConnection db, CreateUserRequest request) =>
{
    await db.OpenAsync();
    var id = await db.QuerySingleAsync<int>(
        "INSERT INTO users (name, email) VALUES (@Name, @Email) RETURNING id",
        new { request.Name, request.Email });
    return Results.Created($"/users/{id}", new { id, request.Name, request.Email });
});

app.Run();

public record User(int Id, string Name, string Email);
public record CreateUserRequest(string Name, string Email);

// Make Program accessible for WebApplicationFactory
public partial class Program { }
