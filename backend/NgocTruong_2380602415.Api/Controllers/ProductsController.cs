using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Contracts;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Controllers;

[ApiController]
[Route("api/products")]
public sealed class ProductsController(PracticeDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<Product>>> GetAll([FromQuery] string? name, CancellationToken cancellationToken)
    {
        var query = db.Products.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(name))
        {
            var term = name.Trim();
            query = query.Where(product => product.Name.Contains(term));
        }
        return await query.OrderBy(product => product.Id).ToListAsync(cancellationToken);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Product>> GetById(int id, CancellationToken cancellationToken)
    {
        var product = await db.Products.AsNoTracking().SingleOrDefaultAsync(product => product.Id == id, cancellationToken);
        return product is null ? NotFound() : Ok(product);
    }

    [HttpPost]
    [ProducesResponseType<Product>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<Product>> Create(ProductInput input, CancellationToken cancellationToken)
    {
        var product = new Product { Name = input.Name, Description = input.Description, Price = input.Price };
        db.Products.Add(product);
        await db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Product>> Update(int id, ProductInput input, CancellationToken cancellationToken)
    {
        var product = await db.Products.FindAsync([id], cancellationToken);
        if (product is null) return NotFound();
        product.Name = input.Name;
        product.Description = input.Description;
        product.Price = input.Price;
        await db.SaveChangesAsync(cancellationToken);
        return Ok(product);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var product = await db.Products.FindAsync([id], cancellationToken);
        if (product is null) return NotFound();
        db.Products.Remove(product);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }
}
