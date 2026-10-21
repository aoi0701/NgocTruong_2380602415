using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace NgocTruong_2380602415.Api.Tests;

public sealed class ApiContractTests
{
    private static async Task<HttpClient> GetClient(ApiFactory app, string? resource = null)
    {
        return resource == "products" ? await app.CreateAuthenticatedClientAsync() : app.CreateClient();
    }

    [Theory]
    [InlineData("posts")]
    [InlineData("products")]
    public async Task Crud_generates_identity_trims_values_and_persists_across_restart(string resource)
    {
        using var database = new TestDatabase();
        int id;
        using (var app = database.Open())
        using (var client = await GetClient(app, resource))
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
        using (var client = await GetClient(app, resource))
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
        using (var client = await GetClient(app, resource))
            Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/{resource}/{id}")).StatusCode);
    }

    [Theory]
    [InlineData("posts")]
    [InlineData("products")]
    public async Task Missing_id_is_404_for_get_put_and_delete(string resource)
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = await GetClient(app, resource);
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
        using var client = await GetClient(app, resource);
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
        using var client = await GetClient(app, resource);
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
        {
            foreach (var resource in new[] { "posts", "products" })
            {
                using var client = await GetClient(app, resource);
                var items = await Read(await client.GetAsync($"/api/{resource}"));
                Assert.True(items.GetArrayLength() > 0);
                foreach (var item in items.EnumerateArray())
                    Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/{resource}/{item.GetProperty("id").GetInt32()}")).StatusCode);
            }
        }
        using (var app = database.Open())
        {
            foreach (var resource in new[] { "posts", "products" })
            {
                using var client = await GetClient(app, resource);
                Assert.Equal(0, (await Read(await client.GetAsync($"/api/{resource}"))).GetArrayLength());
            }
        }
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

    [Fact]
    public async Task Authenticate_register_login_and_roles_work()
    {
        using var database = new TestDatabase();
        using var app = database.Open();
        using var client = app.CreateClient();

        // Register new user
        var regResponse = await client.PostAsJsonAsync("/api/Authenticate/register", new
        {
            username = "teststudent",
            email = "student@example.com",
            password = "Student@123456",
            initials = "STU",
            role = "User"
        });
        var regBody = await regResponse.Content.ReadAsStringAsync();
        Assert.True(regResponse.IsSuccessStatusCode, $"Register failed: {regBody}");

        // Duplicate registration returns 400
        var dupResponse = await client.PostAsJsonAsync("/api/Authenticate/register", new
        {
            username = "teststudent",
            email = "student2@example.com",
            password = "Student@123456",
            initials = "STU",
            role = "User"
        });
        Assert.Equal(HttpStatusCode.BadRequest, dupResponse.StatusCode);

        // Login with valid credentials
        var loginResponse = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "teststudent",
            password = "Student@123456"
        });
        Assert.Equal(HttpStatusCode.OK, loginResponse.StatusCode);
        var loginBody = await Read(loginResponse);
        Assert.True(loginBody.GetProperty("status").GetBoolean());
        var token = loginBody.GetProperty("token").GetString();
        Assert.NotNull(token);
        Assert.NotEmpty(token!);
        Assert.Equal("User", loginBody.GetProperty("role").GetString());

        // Login with wrong password returns 401
        var wrongPass = await client.PostAsJsonAsync("/api/Authenticate/login", new
        {
            username = "teststudent",
            password = "WrongPassword123"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, wrongPass.StatusCode);
    }

    [Fact]
    public async Task Categories_crud_authorization_and_product_setnull_work()
    {
        using var database = new TestDatabase();
        using var app = database.Open();

        // 1. Unauthenticated cannot POST category
        using (var anonClient = app.CreateClient())
        {
            var res = await anonClient.PostAsJsonAsync("/api/Categories", new { name = "Hàng mới" });
            Assert.Equal(HttpStatusCode.Unauthorized, res.StatusCode);
        }

        // 2. Regular User (role = User) cannot POST category (Forbidden)
        using (var userClient = await app.CreateAuthenticatedClientAsync("user", "User@123456"))
        {
            var res = await userClient.PostAsJsonAsync("/api/Categories", new { name = "Hàng mới" });
            Assert.Equal(HttpStatusCode.Forbidden, res.StatusCode);
        }

        // 3. Admin can CRUD category
        using (var adminClient = await app.CreateAuthenticatedClientAsync("admin", "Admin@123456"))
        {
            // Create Category
            var createRes = await adminClient.PostAsJsonAsync("/api/Categories", new
            {
                name = "Văn phòng phẩm",
                description = "Bút thước vở"
            });
            Assert.Equal(HttpStatusCode.Created, createRes.StatusCode);
            var cat = await Read(createRes);
            var catId = cat.GetProperty("id").GetInt32();
            Assert.True(catId > 0);

            // Create Product belonging to this category
            var prodRes = await adminClient.PostAsJsonAsync("/api/ProductApi", new
            {
                name = "Bút bi",
                price = 5000m,
                description = "Bút bi xanh",
                categoryId = catId
            });
            Assert.Equal(HttpStatusCode.Created, prodRes.StatusCode);
            var prod = await Read(prodRes);
            var prodId = prod.GetProperty("id").GetInt32();
            Assert.Equal(catId, prod.GetProperty("categoryId").GetInt32());

            // Delete Category
            var deleteRes = await adminClient.DeleteAsync($"/api/Categories/{catId}");
            Assert.Equal(HttpStatusCode.NoContent, deleteRes.StatusCode);

            // Verify category is deleted
            var getCatRes = await adminClient.GetAsync($"/api/Categories/{catId}");
            Assert.Equal(HttpStatusCode.NotFound, getCatRes.StatusCode);

            // QUAN TRỌNG: Verify Product STILL EXISTS and CategoryId became null!
            var getProdRes = await adminClient.GetAsync($"/api/ProductApi/{prodId}");
            Assert.Equal(HttpStatusCode.OK, getProdRes.StatusCode);
            var updatedProd = await Read(getProdRes);
            Assert.True(updatedProd.GetProperty("categoryId").ValueKind == JsonValueKind.Null);
            Assert.Equal("Bút bi", updatedProd.GetProperty("name").GetString());
        }
    }

    [Fact]
    public async Task ProductApi_requires_authorization_and_supports_both_routes()
    {
        using var database = new TestDatabase();
        using var app = database.Open();

        // Anonymous call to /api/ProductApi is 401 Unauthorized
        using (var anonClient = app.CreateClient())
        {
            var anonRes = await anonClient.GetAsync("/api/ProductApi");
            Assert.Equal(HttpStatusCode.Unauthorized, anonRes.StatusCode);

            var anonProductsRes = await anonClient.GetAsync("/api/products");
            Assert.Equal(HttpStatusCode.Unauthorized, anonProductsRes.StatusCode);
        }

        // Authenticated call to /api/ProductApi and /api/products returns 200 OK
        using (var userClient = await app.CreateAuthenticatedClientAsync("user", "User@123456"))
        {
            var res1 = await userClient.GetAsync("/api/ProductApi");
            Assert.Equal(HttpStatusCode.OK, res1.StatusCode);
            var list1 = await Read(res1);
            Assert.True(list1.GetArrayLength() > 0);

            var res2 = await userClient.GetAsync("/api/products");
            Assert.Equal(HttpStatusCode.OK, res2.StatusCode);
            var list2 = await Read(res2);
            Assert.True(list2.GetArrayLength() > 0);
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
