using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NgocTruong_2380602415.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddAttendanceFeedbackFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FeedbackMood",
                schema: "dbo",
                table: "AttendanceRecords",
                type: "nvarchar(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FeedbackNote",
                schema: "dbo",
                table: "AttendanceRecords",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "FeedbackTime",
                schema: "dbo",
                table: "AttendanceRecords",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "FeedbackMood",
                schema: "dbo",
                table: "AttendanceRecords");

            migrationBuilder.DropColumn(
                name: "FeedbackNote",
                schema: "dbo",
                table: "AttendanceRecords");

            migrationBuilder.DropColumn(
                name: "FeedbackTime",
                schema: "dbo",
                table: "AttendanceRecords");
        }
    }
}
