using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace SampleApi.Tests;

public class UsersEndpointTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public UsersEndpointTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task Health_ReturnsOk()
    {
        var response = await _client.GetAsync("/health");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task PostUser_ThenGetUsers_ReturnsCreatedUser()
    {
        // Create a user
        var createResponse = await _client.PostAsJsonAsync("/users", new
        {
            Name = "Test User",
            Email = "test@example.com"
        });
        Assert.Equal(HttpStatusCode.Created, createResponse.StatusCode);

        // Get all users
        var users = await _client.GetFromJsonAsync<List<UserDto>>("/users");
        Assert.NotNull(users);
        Assert.Contains(users, u => u.Name == "Test User" && u.Email == "test@example.com");
    }

    private record UserDto(int Id, string Name, string Email);
}
