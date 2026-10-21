using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NgocTruong_2380602415.Api.Contracts;
using NgocTruong_2380602415.Api.Data;
using NgocTruong_2380602415.Api.Models;

namespace NgocTruong_2380602415.Api.Controllers;

[ApiController]
[Route("api/posts")]
public sealed class PostsController(ApplicationDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<Post>>> GetAll([FromQuery] string? search, CancellationToken cancellationToken)
    {
        var query = db.Posts.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(post => post.Title.Contains(term) || post.Body.Contains(term));
        }
        return await query.OrderBy(post => post.Id).ToListAsync(cancellationToken);
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Post>> GetById(int id, CancellationToken cancellationToken)
    {
        var post = await db.Posts.AsNoTracking().SingleOrDefaultAsync(post => post.Id == id, cancellationToken);
        return post is null ? NotFound() : Ok(post);
    }

    [HttpPost]
    [ProducesResponseType<Post>(StatusCodes.Status201Created)]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<Post>> Create(PostInput input, CancellationToken cancellationToken)
    {
        var post = new Post { UserId = input.UserId, Title = input.Title, Body = input.Body };
        db.Posts.Add(post);
        await db.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = post.Id }, post);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Post>> Update(int id, PostInput input, CancellationToken cancellationToken)
    {
        var post = await db.Posts.FindAsync([id], cancellationToken);
        if (post is null) return NotFound();
        post.UserId = input.UserId;
        post.Title = input.Title;
        post.Body = input.Body;
        await db.SaveChangesAsync(cancellationToken);
        return Ok(post);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        var post = await db.Posts.FindAsync([id], cancellationToken);
        if (post is null) return NotFound();
        db.Posts.Remove(post);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }
}
