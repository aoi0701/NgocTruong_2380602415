using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace NgocTruong_2380602415.Api.Tests;

public sealed class ApiContractTests
{
    [Theory]
    [InlineData("posts")]
    [InlineData("products")]
    public async Task Crud_generates_identity_trims_values_and_persists_across_restart(string resource)
    {
        using var database = new TestDatabase();
        int id;
        using (var app = database.Open())
        using (var client = app.CreateClient())
        {
            var created = await client.PostAsJsonAsync($"/api/{resource}", Input(resource, false));
            Assert.Equal(HttpStatusCode.Created, created.StatusCode);
            var item = await Read(created);
            id = item.GetProperty("id").GetInt32();
            Assert.True(id > 0);
            Assert.NotEqual(999999, id);
            Assert.NotNull(created.Headers.Location);
            Assert.Equal($"/api/{resource}/{id}", new Uri(client.BaseAddress!, created.Headers.Location).AbsolutePath);
            Assert.Equal(resource == "posts" ? "Bài viết mới" : "Cà phê sữa", item.GetProperty(resource == "posts" ? "title" : "name").GetString());
            Assert.Equal(resource == "posts" ? "Nội dung bài viết" : "Mô tả", item.GetProperty(resource == "posts" ? "body" : "description").GetString());
            Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/{resource}/{id}")).StatusCode);
            var updated = await client.PutAsJsonAsync($"/api/{resource}/{id}", Input(resource, true));
            Assert.Equal(HttpStatusCode.OK, updated.StatusCode);
            Assert.Equal(id, (await Read(updated)).GetProperty("id").GetInt32());
        }
        using (var app = database.Open())
        using (var client = app.CreateClient())
        {
            var stored = await Read(await client.GetAsync($"/api/{resource}/{id}"));
            Assert.Equal(resource == "posts" ? "Đã sửa" : "Trà xanh", stored.GetProperty(resource == "posts" ? "title" : "name").GetString());
            Assert.Equal(resource == "posts" ? "Nội dung đã sửa" : "Mô tả đã sửa", stored.GetProperty(resource == "posts" ? "body" : "description").GetString());
            if (resource == "products") Assert.Equal(25.75m, stored.GetProperty("price").GetDecimal());
            else Assert.Equal(8, stored.GetProperty("userId").GetInt32());
            var deleted = await client.DeleteAsync($"/api/{resource}/{id}");
            Assert.Equal(HttpStatusCode.NoContent, deleted.StatusCode);
            Assert.Equal("", await deleted.Content.ReadAsStringAsync());
            Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/{resource}/{id}")).StatusCode);
        }
        using (var app = database.Open())
        using (var client = app.CreateClient())
            Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/{resource}/{id}")).StatusCode);
    }

    [Theory]
    [InlineData("posts")]
    [InlineData("products")]
    public async Task Missing_id_is_404_for_get_put_and_delete(string resource)
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/{resource}/999999")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.PutAsJsonAsync($"/api/{resource}/999999", Input(resource, false))).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.DeleteAsync($"/api/{resource}/999999")).StatusCode);
    }

    public static IEnumerable<object[]> InvalidInputs()
    {
        yield return ["posts", new { userId = 0, title = "ok", body = "ok" }];
        yield return ["posts", new { userId = 1, title = "   ", body = "ok" }];
        yield return ["posts", new { userId = 1, title = "ok", body = "   " }];
        yield return ["posts", new { userId = 1, title = new string('a', 201), body = "ok" }];
        yield return ["posts", new { userId = 1, title = "ok", body = new string('a', 5001) }];
        yield return ["posts", new { userId = 1, title = (string?)null, body = "ok" }];
        yield return ["products", new { name = "   ", description = "", price = 0 }];
        yield return ["products", new { name = new string('a', 201), description = "", price = 0 }];
        yield return ["products", new { name = "ok", description = new string('a', 2001), price = 0 }];
        yield return ["products", new { name = "ok", description = "", price = -0.01m }];
        yield return ["products", new { name = (string?)null, description = "", price = 0 }];
    }

    [Theory]
    [MemberData(nameof(InvalidInputs))]
    public async Task Invalid_input_returns_validation_problem_without_creating_or_updating(string resource, object input)
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();
        var before = await Read(await client.GetAsync($"/api/{resource}"));
        var id = before[0].GetProperty("id").GetInt32();
        foreach (var response in new[] {
            await client.PostAsJsonAsync($"/api/{resource}", input),
            await client.PutAsJsonAsync($"/api/{resource}/{id}", input) })
        {
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
            Assert.True((await Read(response)).GetProperty("errors").EnumerateObject().Any());
        }
        var after = await Read(await client.GetAsync($"/api/{resource}"));
        Assert.Equal(before.GetRawText(), after.GetRawText());
    }

    [Theory]
    [InlineData("products", "name")]
    [InlineData("posts", "search")]
    public async Task Contains_search_handles_Unicode_quotes_and_SQL_as_data(string resource, string query)
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();
        const string text = "Đặc biệt ' OR 1=1; DROP TABLE Products; -- 100%_[x]";
        object input = resource == "posts" ? new { userId = 1, title = text, body = "Nội dung" } : new { name = text, description = "", price = 0 };
        var created = await client.PostAsJsonAsync($"/api/{resource}", input);
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var id = (await Read(created)).GetProperty("id").GetInt32();
        foreach (var term in new[] { "Đặc biệt", "' OR 1=1; DROP TABLE Products; --", "%_[x]" })
        {
            var result = await client.GetAsync($"/api/{resource}?{query}={Uri.EscapeDataString(term)}");
            Assert.Equal(HttpStatusCode.OK, result.StatusCode);
            var items = await Read(result);
            Assert.Equal(1, items.GetArrayLength());
            Assert.Equal(id, items[0].GetProperty("id").GetInt32());
        }
        Assert.Equal(0, (await Read(await client.GetAsync($"/api/{resource}?{query}=absent-xyz"))).GetArrayLength());
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync($"/api/{resource}")).StatusCode);
    }

    [Fact]
    public async Task Deleting_all_seed_rows_does_not_reseed_on_restart()
    {
        using var database = new TestDatabase();
        using (var app = database.Open())
        using (var client = app.CreateClient())
            foreach (var resource in new[] { "posts", "products" })
            {
                var items = await Read(await client.GetAsync($"/api/{resource}"));
                Assert.True(items.GetArrayLength() > 0);
                foreach (var item in items.EnumerateArray())
                    Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/{resource}/{item.GetProperty("id").GetInt32()}")).StatusCode);
            }
        using (var app = database.Open())
        using (var client = app.CreateClient())
            foreach (var resource in new[] { "posts", "products" })
                Assert.Equal(0, (await Read(await client.GetAsync($"/api/{resource}"))).GetArrayLength());
    }

    [Fact]
    public async Task Swagger_exposes_all_CRUD_operations()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/swagger/index.html")).StatusCode);
        var document = await Read(await client.GetAsync("/swagger/v1/swagger.json"));
        foreach (var resource in new[] { "posts", "products" })
        {
            var paths = document.GetProperty("paths");
            Assert.True(paths.GetProperty($"/api/{resource}").TryGetProperty("get", out _));
            Assert.True(paths.GetProperty($"/api/{resource}").TryGetProperty("post", out _));
            foreach (var method in new[] { "get", "put", "delete" })
                Assert.True(paths.GetProperty($"/api/{resource}/{{id}}").TryGetProperty(method, out _));
        }
    }

    private static object Input(string resource, bool updated) => resource == "posts"
        ? new { id = 999999, userId = updated ? 8 : 7, title = updated ? " Đã sửa " : " Bài viết mới ", body = updated ? " Nội dung đã sửa " : " Nội dung bài viết " }
        : new { id = 999999, name = updated ? " Trà xanh " : " Cà phê sữa ", description = updated ? " Mô tả đã sửa " : " Mô tả ", price = updated ? 25.75m : 12.5m };

    private static async Task<JsonElement> Read(HttpResponseMessage response)
    {
        Assert.True(response.IsSuccessStatusCode || response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected JSON response; received HTTP {(int)response.StatusCode}.");
        return JsonSerializer.Deserialize<JsonElement>(await response.Content.ReadAsStringAsync());
    }
}
