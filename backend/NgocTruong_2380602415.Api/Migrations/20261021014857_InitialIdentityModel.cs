using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NgocTruong_2380602415.Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialIdentityModel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            if (migrationBuilder.ActiveProvider == "Microsoft.EntityFrameworkCore.SqlServer")
            {
                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'identity')
                        EXEC('CREATE SCHEMA [identity]');
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetRoles' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetRoles] (
                            [Id] nvarchar(450) NOT NULL,
                            [Name] nvarchar(256) NULL,
                            [NormalizedName] nvarchar(256) NULL,
                            [ConcurrencyStamp] nvarchar(max) NULL,
                            CONSTRAINT [PK_AspNetRoles] PRIMARY KEY ([Id])
                        );
                        CREATE UNIQUE INDEX [RoleNameIndex] ON [identity].[AspNetRoles] ([NormalizedName]) WHERE [NormalizedName] IS NOT NULL;
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetUsers' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetUsers] (
                            [Id] nvarchar(450) NOT NULL,
                            [Initials] nvarchar(5) NULL,
                            [UserName] nvarchar(256) NULL,
                            [NormalizedUserName] nvarchar(256) NULL,
                            [Email] nvarchar(256) NULL,
                            [NormalizedEmail] nvarchar(256) NULL,
                            [EmailConfirmed] bit NOT NULL,
                            [PasswordHash] nvarchar(max) NULL,
                            [SecurityStamp] nvarchar(max) NULL,
                            [ConcurrencyStamp] nvarchar(max) NULL,
                            [PhoneNumber] nvarchar(max) NULL,
                            [PhoneNumberConfirmed] bit NOT NULL,
                            [TwoFactorEnabled] bit NOT NULL,
                            [LockoutEnd] datetimeoffset NULL,
                            [LockoutEnabled] bit NOT NULL,
                            [AccessFailedCount] int NOT NULL,
                            CONSTRAINT [PK_AspNetUsers] PRIMARY KEY ([Id])
                        );
                        CREATE INDEX [EmailIndex] ON [identity].[AspNetUsers] ([NormalizedEmail]);
                        CREATE UNIQUE INDEX [UserNameIndex] ON [identity].[AspNetUsers] ([NormalizedUserName]) WHERE [NormalizedUserName] IS NOT NULL;
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Categories' AND schema_id = SCHEMA_ID('dbo'))
                    BEGIN
                        CREATE TABLE [dbo].[Categories] (
                            [Id] int NOT NULL IDENTITY(1,1),
                            [Name] nvarchar(200) NOT NULL,
                            [Description] nvarchar(2000) NULL,
                            CONSTRAINT [PK_Categories] PRIMARY KEY ([Id])
                        );
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Posts' AND schema_id = SCHEMA_ID('dbo'))
                    BEGIN
                        CREATE TABLE [dbo].[Posts] (
                            [Id] int NOT NULL IDENTITY(1,1),
                            [UserId] int NOT NULL,
                            [Title] nvarchar(200) NOT NULL,
                            [Body] nvarchar(max) NOT NULL,
                            CONSTRAINT [PK_Posts] PRIMARY KEY ([Id])
                        );
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetRoleClaims' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetRoleClaims] (
                            [Id] int NOT NULL IDENTITY(1,1),
                            [RoleId] nvarchar(450) NOT NULL,
                            [ClaimType] nvarchar(max) NULL,
                            [ClaimValue] nvarchar(max) NULL,
                            CONSTRAINT [PK_AspNetRoleClaims] PRIMARY KEY ([Id]),
                            CONSTRAINT [FK_AspNetRoleClaims_AspNetRoles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [identity].[AspNetRoles] ([Id]) ON DELETE CASCADE
                        );
                        CREATE INDEX [IX_AspNetRoleClaims_RoleId] ON [identity].[AspNetRoleClaims] ([RoleId]);
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetUserClaims' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetUserClaims] (
                            [Id] int NOT NULL IDENTITY(1,1),
                            [UserId] nvarchar(450) NOT NULL,
                            [ClaimType] nvarchar(max) NULL,
                            [ClaimValue] nvarchar(max) NULL,
                            CONSTRAINT [PK_AspNetUserClaims] PRIMARY KEY ([Id]),
                            CONSTRAINT [FK_AspNetUserClaims_AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [identity].[AspNetUsers] ([Id]) ON DELETE CASCADE
                        );
                        CREATE INDEX [IX_AspNetUserClaims_UserId] ON [identity].[AspNetUserClaims] ([UserId]);
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetUserLogins' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetUserLogins] (
                            [LoginProvider] nvarchar(450) NOT NULL,
                            [ProviderKey] nvarchar(450) NOT NULL,
                            [ProviderDisplayName] nvarchar(max) NULL,
                            [UserId] nvarchar(450) NOT NULL,
                            CONSTRAINT [PK_AspNetUserLogins] PRIMARY KEY ([LoginProvider], [ProviderKey]),
                            CONSTRAINT [FK_AspNetUserLogins_AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [identity].[AspNetUsers] ([Id]) ON DELETE CASCADE
                        );
                        CREATE INDEX [IX_AspNetUserLogins_UserId] ON [identity].[AspNetUserLogins] ([UserId]);
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetUserRoles' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetUserRoles] (
                            [UserId] nvarchar(450) NOT NULL,
                            [RoleId] nvarchar(450) NOT NULL,
                            CONSTRAINT [PK_AspNetUserRoles] PRIMARY KEY ([UserId], [RoleId]),
                            CONSTRAINT [FK_AspNetUserRoles_AspNetRoles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [identity].[AspNetRoles] ([Id]) ON DELETE CASCADE,
                            CONSTRAINT [FK_AspNetUserRoles_AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [identity].[AspNetUsers] ([Id]) ON DELETE CASCADE
                        );
                        CREATE INDEX [IX_AspNetUserRoles_RoleId] ON [identity].[AspNetUserRoles] ([RoleId]);
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AspNetUserTokens' AND schema_id = SCHEMA_ID('identity'))
                    BEGIN
                        CREATE TABLE [identity].[AspNetUserTokens] (
                            [UserId] nvarchar(450) NOT NULL,
                            [LoginProvider] nvarchar(450) NOT NULL,
                            [Name] nvarchar(450) NOT NULL,
                            [Value] nvarchar(max) NULL,
                            CONSTRAINT [PK_AspNetUserTokens] PRIMARY KEY ([UserId], [LoginProvider], [Name]),
                            CONSTRAINT [FK_AspNetUserTokens_AspNetUsers_UserId] FOREIGN KEY ([UserId]) REFERENCES [identity].[AspNetUsers] ([Id]) ON DELETE CASCADE
                        );
                    END
                ");

                migrationBuilder.Sql(@"
                    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Products' AND schema_id = SCHEMA_ID('dbo'))
                    BEGIN
                        CREATE TABLE [dbo].[Products] (
                            [Id] int NOT NULL IDENTITY(1,1),
                            [Name] nvarchar(200) NOT NULL,
                            [Price] decimal(38,9) NOT NULL,
                            [Image] nvarchar(max) NULL,
                            [Description] nvarchar(2000) NULL,
                            [CategoryId] int NULL,
                            CONSTRAINT [PK_Products] PRIMARY KEY ([Id]),
                            CONSTRAINT [FK_Products_Categories_CategoryId] FOREIGN KEY ([CategoryId]) REFERENCES [dbo].[Categories] ([Id]) ON DELETE SET NULL
                        );
                        CREATE INDEX [IX_Products_CategoryId] ON [dbo].[Products] ([CategoryId]);
                    END
                    ELSE
                    BEGIN
                        IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Products') AND name = 'Image')
                        BEGIN
                            ALTER TABLE [dbo].[Products] ADD [Image] nvarchar(max) NULL;
                        END

                        IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Products') AND name = 'CategoryId')
                        BEGIN
                            ALTER TABLE [dbo].[Products] ADD [CategoryId] int NULL;
                        END

                        IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_Products_Categories_CategoryId')
                        BEGIN
                            ALTER TABLE [dbo].[Products] WITH CHECK ADD CONSTRAINT [FK_Products_Categories_CategoryId] 
                            FOREIGN KEY([CategoryId]) REFERENCES [dbo].[Categories] ([Id]) ON DELETE SET NULL;
                        END

                        IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Products') AND name = 'IX_Products_CategoryId')
                        BEGIN
                            CREATE INDEX [IX_Products_CategoryId] ON [dbo].[Products] ([CategoryId]);
                        END
                    END
                ");
            }
            else
            {
                migrationBuilder.EnsureSchema(name: "identity");
                migrationBuilder.EnsureSchema(name: "dbo");

                migrationBuilder.CreateTable(
                    name: "AspNetRoles",
                    schema: "identity",
                    columns: table => new
                    {
                        Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        Name = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                        NormalizedName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                        ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetRoles", x => x.Id);
                    });

                migrationBuilder.CreateTable(
                    name: "AspNetUsers",
                    schema: "identity",
                    columns: table => new
                    {
                        Id = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        Initials = table.Column<string>(type: "nvarchar(5)", maxLength: 5, nullable: true),
                        UserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                        NormalizedUserName = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                        Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                        NormalizedEmail = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: true),
                        EmailConfirmed = table.Column<bool>(type: "bit", nullable: false),
                        PasswordHash = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        SecurityStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        ConcurrencyStamp = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        PhoneNumber = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        PhoneNumberConfirmed = table.Column<bool>(type: "bit", nullable: false),
                        TwoFactorEnabled = table.Column<bool>(type: "bit", nullable: false),
                        LockoutEnd = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                        LockoutEnabled = table.Column<bool>(type: "bit", nullable: false),
                        AccessFailedCount = table.Column<int>(type: "int", nullable: false)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetUsers", x => x.Id);
                    });

                migrationBuilder.CreateTable(
                    name: "Categories",
                    schema: "dbo",
                    columns: table => new
                    {
                        Id = table.Column<int>(type: "int", nullable: false)
                            .Annotation("SqlServer:Identity", "1, 1"),
                        Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                        Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_Categories", x => x.Id);
                    });

                migrationBuilder.CreateTable(
                    name: "Posts",
                    schema: "dbo",
                    columns: table => new
                    {
                        Id = table.Column<int>(type: "int", nullable: false)
                            .Annotation("SqlServer:Identity", "1, 1"),
                        UserId = table.Column<int>(type: "int", nullable: false),
                        Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                        Body = table.Column<string>(type: "nvarchar(max)", maxLength: 5000, nullable: false)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_Posts", x => x.Id);
                    });

                migrationBuilder.CreateTable(
                    name: "AspNetRoleClaims",
                    schema: "identity",
                    columns: table => new
                    {
                        Id = table.Column<int>(type: "int", nullable: false)
                            .Annotation("SqlServer:Identity", "1, 1"),
                        RoleId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetRoleClaims", x => x.Id);
                        table.ForeignKey(
                            name: "FK_AspNetRoleClaims_AspNetRoles_RoleId",
                            column: x => x.RoleId,
                            principalSchema: "identity",
                            principalTable: "AspNetRoles",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.Cascade);
                    });

                migrationBuilder.CreateTable(
                    name: "AspNetUserClaims",
                    schema: "identity",
                    columns: table => new
                    {
                        Id = table.Column<int>(type: "int", nullable: false)
                            .Annotation("SqlServer:Identity", "1, 1"),
                        UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        ClaimType = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        ClaimValue = table.Column<string>(type: "nvarchar(max)", nullable: true)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetUserClaims", x => x.Id);
                        table.ForeignKey(
                            name: "FK_AspNetUserClaims_AspNetUsers_UserId",
                            column: x => x.UserId,
                            principalSchema: "identity",
                            principalTable: "AspNetUsers",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.Cascade);
                    });

                migrationBuilder.CreateTable(
                    name: "AspNetUserLogins",
                    schema: "identity",
                    columns: table => new
                    {
                        LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        ProviderKey = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        ProviderDisplayName = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        UserId = table.Column<string>(type: "nvarchar(450)", nullable: false)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetUserLogins", x => new { x.LoginProvider, x.ProviderKey });
                        table.ForeignKey(
                            name: "FK_AspNetUserLogins_AspNetUsers_UserId",
                            column: x => x.UserId,
                            principalSchema: "identity",
                            principalTable: "AspNetUsers",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.Cascade);
                    });

                migrationBuilder.CreateTable(
                    name: "AspNetUserRoles",
                    schema: "identity",
                    columns: table => new
                    {
                        UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        RoleId = table.Column<string>(type: "nvarchar(450)", nullable: false)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetUserRoles", x => new { x.UserId, x.RoleId });
                        table.ForeignKey(
                            name: "FK_AspNetUserRoles_AspNetRoles_RoleId",
                            column: x => x.RoleId,
                            principalSchema: "identity",
                            principalTable: "AspNetRoles",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.Cascade);
                        table.ForeignKey(
                            name: "FK_AspNetUserRoles_AspNetUsers_UserId",
                            column: x => x.UserId,
                            principalSchema: "identity",
                            principalTable: "AspNetUsers",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.Cascade);
                    });

                migrationBuilder.CreateTable(
                    name: "AspNetUserTokens",
                    schema: "identity",
                    columns: table => new
                    {
                        UserId = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        LoginProvider = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        Name = table.Column<string>(type: "nvarchar(450)", nullable: false),
                        Value = table.Column<string>(type: "nvarchar(max)", nullable: true)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_AspNetUserTokens", x => new { x.UserId, x.LoginProvider, x.Name });
                        table.ForeignKey(
                            name: "FK_AspNetUserTokens_AspNetUsers_UserId",
                            column: x => x.UserId,
                            principalSchema: "identity",
                            principalTable: "AspNetUsers",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.Cascade);
                    });

                migrationBuilder.CreateTable(
                    name: "Products",
                    schema: "dbo",
                    columns: table => new
                    {
                        Id = table.Column<int>(type: "int", nullable: false)
                            .Annotation("SqlServer:Identity", "1, 1"),
                        Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                        Price = table.Column<decimal>(type: "decimal(38,9)", precision: 38, scale: 9, nullable: false),
                        Image = table.Column<string>(type: "nvarchar(max)", nullable: true),
                        Description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                        CategoryId = table.Column<int>(type: "int", nullable: true)
                    },
                    constraints: table =>
                    {
                        table.PrimaryKey("PK_Products", x => x.Id);
                        table.ForeignKey(
                            name: "FK_Products_Categories_CategoryId",
                            column: x => x.CategoryId,
                            principalSchema: "dbo",
                            principalTable: "Categories",
                            principalColumn: "Id",
                            onDelete: ReferentialAction.SetNull);
                    });

                migrationBuilder.CreateIndex(
                    name: "IX_AspNetRoleClaims_RoleId",
                    schema: "identity",
                    table: "AspNetRoleClaims",
                    column: "RoleId");

                migrationBuilder.CreateIndex(
                    name: "RoleNameIndex",
                    schema: "identity",
                    table: "AspNetRoles",
                    column: "NormalizedName",
                    unique: true,
                    filter: "[NormalizedName] IS NOT NULL");

                migrationBuilder.CreateIndex(
                    name: "IX_AspNetUserClaims_UserId",
                    schema: "identity",
                    table: "AspNetUserClaims",
                    column: "UserId");

                migrationBuilder.CreateIndex(
                    name: "IX_AspNetUserLogins_UserId",
                    schema: "identity",
                    table: "AspNetUserLogins",
                    column: "UserId");

                migrationBuilder.CreateIndex(
                    name: "IX_AspNetUserRoles_RoleId",
                    schema: "identity",
                    table: "AspNetUserRoles",
                    column: "RoleId");

                migrationBuilder.CreateIndex(
                    name: "EmailIndex",
                    schema: "identity",
                    table: "AspNetUsers",
                    column: "NormalizedEmail");

                migrationBuilder.CreateIndex(
                    name: "UserNameIndex",
                    schema: "identity",
                    table: "AspNetUsers",
                    column: "NormalizedUserName",
                    unique: true,
                    filter: "[NormalizedUserName] IS NOT NULL");

                migrationBuilder.CreateIndex(
                    name: "IX_Products_CategoryId",
                    schema: "dbo",
                    table: "Products",
                    column: "CategoryId");
            }
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AspNetRoleClaims",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "AspNetUserClaims",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "AspNetUserLogins",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "AspNetUserRoles",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "AspNetUserTokens",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "Posts",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "Products",
                schema: "dbo");

            migrationBuilder.DropTable(
                name: "AspNetRoles",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "AspNetUsers",
                schema: "identity");

            migrationBuilder.DropTable(
                name: "Categories",
                schema: "dbo");
        }
    }
}
