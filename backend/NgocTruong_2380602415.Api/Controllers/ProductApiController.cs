using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using NgocTruong_2380602415.Api.Models;
using NgocTruong_2380602415.Api.Repositories;

namespace NgocTruong_2380602415.Api.Controllers;

[ApiController]
[Route("api/products")]
[Route("api/[controller]")]
[Authorize]
public class ProductApiController : ControllerBase
{
    private readonly IProductRepository _productRepository;

    public ProductApiController(IProductRepository productRepository)
    {
        _productRepository = productRepository;
    }

    [HttpGet]
    public async Task<IActionResult> GetProducts([FromQuery] string? name = null)
    {
        var products = string.IsNullOrWhiteSpace(name)
            ? await _productRepository.GetProductsAsync()
            : await _productRepository.GetProductsAsync(name);
        return Ok(products);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetProductById(int id)
    {
        var product = await _productRepository.GetProductByIdAsync(id);
        if (product == null)
            return NotFound();
        return Ok(product);
    }

    [HttpPost]
    public async Task<IActionResult> AddProduct([FromBody] Product product)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        product.Id = 0;
        await _productRepository.AddProductAsync(product);
        var path = Request.Path.Value?.TrimEnd('/') ?? "/api/products";
        return Created($"{path}/{product.Id}", product);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateProduct(int id, [FromBody] Product product)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var existing = await _productRepository.GetProductByIdAsync(id);
        if (existing == null)
            return NotFound();

        product.Id = id;
        await _productRepository.UpdateProductAsync(product);
        return Ok(product);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteProduct(int id)
    {
        var existing = await _productRepository.GetProductByIdAsync(id);
        if (existing == null)
            return NotFound();

        await _productRepository.DeleteProductAsync(id);
        return NoContent();
    }
}
