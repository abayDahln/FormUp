using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace FormUpAPI.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "FormStatus",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    status = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__FormStat__3213E83FE1FFAC60", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "FormType",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    type = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__FormType__3213E83FE1FFAC61", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "GeminiApiKey",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    label = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    api_key = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    code_hash = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    is_active = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    redeemed_count = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeminiApiKey", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "QuestionType",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    type = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Question__3213E83F5563C7FF", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "RegistrationOtp",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    email = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    otp = table.Column<string>(type: "nvarchar(6)", maxLength: 6, nullable: false),
                    expires_at = table.Column<DateTime>(type: "datetime", nullable: false),
                    is_used = table.Column<bool>(type: "bit", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: false, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_RegistrationOtp", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "ResponseStatus",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    status = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Response__3213E83F3C285B45", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "User",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    fullname = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    username = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    email = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    password = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    role = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false, defaultValue: "USER"),
                    birthdate = table.Column<DateOnly>(type: "date", nullable: true),
                    profile_image = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    is_active = table.Column<bool>(type: "bit", nullable: true, defaultValue: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    deleted_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__User__3213E83F660F0712", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "Form",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    status_id = table.Column<int>(type: "int", nullable: false),
                    title = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false),
                    description = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    description_format = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    banner_image = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    form_link = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    deleted_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    taken_down_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Form__3213E83F3D69895B", x => x.id);
                    table.ForeignKey(
                        name: "FK__Form__status_id__49C3F6B7",
                        column: x => x.status_id,
                        principalTable: "FormStatus",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK__Form__user_id__48CFD27E",
                        column: x => x.user_id,
                        principalTable: "User",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "GeminiApiKeyRedemption",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    key_id = table.Column<int>(type: "int", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    redeemed_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GeminiApiKeyRedemption", x => x.id);
                    table.ForeignKey(
                        name: "FK_GeminiApiKeyRedemption_GeminiApiKey_key_id",
                        column: x => x.key_id,
                        principalTable: "GeminiApiKey",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GeminiApiKeyRedemption_User_user_id",
                        column: x => x.user_id,
                        principalTable: "User",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PasswordResetToken",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    user_id = table.Column<int>(type: "int", nullable: false),
                    otp = table.Column<string>(type: "nvarchar(6)", maxLength: 6, nullable: false),
                    expires_at = table.Column<DateTime>(type: "datetime", nullable: false),
                    is_used = table.Column<bool>(type: "bit", nullable: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: false, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PasswordResetToken", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PasswordResetToken_User_user_id",
                        column: x => x.user_id,
                        principalTable: "User",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "FormAttemptAllowance",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    form_id = table.Column<int>(type: "int", nullable: false),
                    respondent_id = table.Column<int>(type: "int", nullable: true),
                    respondent_name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    extra_attempts = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    is_reopened = table.Column<bool>(type: "bit", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_FormAttemptAllowance", x => x.id);
                    table.ForeignKey(
                        name: "FK_FormAttemptAllowance_Form_form_id",
                        column: x => x.form_id,
                        principalTable: "Form",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_FormAttemptAllowance_User_respondent_id",
                        column: x => x.respondent_id,
                        principalTable: "User",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "FormSetting",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    form_id = table.Column<int>(type: "int", nullable: false),
                    form_type_id = table.Column<int>(type: "int", nullable: false),
                    show_score = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    randomize_questions = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    form_token = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    timer_duration = table.Column<int>(type: "int", nullable: true),
                    one_response = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    required_login = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    open_form_time = table.Column<DateTime>(type: "datetime", nullable: true),
                    close_form_time = table.Column<DateTime>(type: "datetime", nullable: true),
                    is_exam_mode = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    disable_copy_paste = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    detect_tab_switch = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    auto_submit_on_tab_switch = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    max_tab_switch = table.Column<int>(type: "int", nullable: true),
                    theme_primary_color = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    theme_background_color = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    theme_config = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__FormSett__3213E83F0D306CE3", x => x.id);
                    table.ForeignKey(
                        name: "FK_FormSetting_FormType_form_type_id",
                        column: x => x.form_type_id,
                        principalTable: "FormType",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK__FormSetti__form___5165187F",
                        column: x => x.form_id,
                        principalTable: "Form",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Question",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    form_id = table.Column<int>(type: "int", nullable: false),
                    type_id = table.Column<int>(type: "int", nullable: false),
                    question = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    question_format = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    question_order = table.Column<int>(type: "int", nullable: false),
                    question_image = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    question_audio = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    is_required = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    correct_answer = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    randomize_options = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    points = table.Column<int>(type: "int", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    deleted_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Question__3213E83F23B2E249", x => x.id);
                    table.ForeignKey(
                        name: "FK__Question__form_i__571DF1D5",
                        column: x => x.form_id,
                        principalTable: "Form",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK__Question__type_i__5812160E",
                        column: x => x.type_id,
                        principalTable: "QuestionType",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "Response",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    form_id = table.Column<int>(type: "int", nullable: false),
                    respondent_id = table.Column<int>(type: "int", nullable: true),
                    respondent_name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    status_id = table.Column<int>(type: "int", nullable: false),
                    submitted_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    tab_switch_count = table.Column<int>(type: "int", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Response__3213E83F3BCBD39E", x => x.id);
                    table.ForeignKey(
                        name: "FK__Response__form_i__60A75C0F",
                        column: x => x.form_id,
                        principalTable: "Form",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK__Response__respon__619B8048",
                        column: x => x.respondent_id,
                        principalTable: "User",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK__Response__status__628FA481",
                        column: x => x.status_id,
                        principalTable: "ResponseStatus",
                        principalColumn: "id");
                });

            migrationBuilder.CreateTable(
                name: "OptionQuestion",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    question_id = table.Column<int>(type: "int", nullable: false),
                    option_order = table.Column<int>(type: "int", nullable: false),
                    option_text = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    option_image = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: true),
                    is_correct = table.Column<bool>(type: "bit", nullable: true, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__OptionQu__3213E83F6E9D36B3", x => x.id);
                    table.ForeignKey(
                        name: "FK__OptionQue__quest__5CD6CB2B",
                        column: x => x.question_id,
                        principalTable: "Question",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ExamSession",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    form_id = table.Column<int>(type: "int", nullable: false),
                    session_id = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    respondent_id = table.Column<int>(type: "int", nullable: true),
                    respondent_name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    submitted_response_id = table.Column<int>(type: "int", nullable: true),
                    started_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    last_seen_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__ExamSession__3213E83F0D306CE", x => x.id);
                    table.ForeignKey(
                        name: "FK__ExamSession__form_id",
                        column: x => x.form_id,
                        principalTable: "Form",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK__ExamSession__respondent_id",
                        column: x => x.respondent_id,
                        principalTable: "User",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK__ExamSession__response_id",
                        column: x => x.submitted_response_id,
                        principalTable: "Response",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "Feedback",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    form_id = table.Column<int>(type: "int", nullable: false),
                    user_id = table.Column<int>(type: "int", nullable: true),
                    response_id = table.Column<int>(type: "int", nullable: true),
                    reason = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    description = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Feedback__3213E83F3D69895B", x => x.id);
                    table.ForeignKey(
                        name: "FK_Feedback_Form",
                        column: x => x.form_id,
                        principalTable: "Form",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Feedback_Response",
                        column: x => x.response_id,
                        principalTable: "Response",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_Feedback_User",
                        column: x => x.user_id,
                        principalTable: "User",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "RespondentAnswer",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    response_id = table.Column<int>(type: "int", nullable: false),
                    question_id = table.Column<int>(type: "int", nullable: false),
                    option_id = table.Column<int>(type: "int", nullable: true),
                    answer_value = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    manual_score = table.Column<double>(type: "float", nullable: true),
                    is_correct_override = table.Column<bool>(type: "bit", nullable: true),
                    override_note = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())"),
                    updated_at = table.Column<DateTime>(type: "datetime", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__Responde__3213E83F515219BC", x => x.id);
                    table.ForeignKey(
                        name: "FK__Responden__optio__68487DD7",
                        column: x => x.option_id,
                        principalTable: "OptionQuestion",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK__Responden__quest__6754599E",
                        column: x => x.question_id,
                        principalTable: "Question",
                        principalColumn: "id");
                    table.ForeignKey(
                        name: "FK__Responden__respo__66603565",
                        column: x => x.response_id,
                        principalTable: "Response",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ExamViolationLog",
                columns: table => new
                {
                    id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    exam_session_id = table.Column<int>(type: "int", nullable: false),
                    response_id = table.Column<int>(type: "int", nullable: true),
                    violation_type = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    occurred_at = table.Column<DateTime>(type: "datetime", nullable: true),
                    created_at = table.Column<DateTime>(type: "datetime", nullable: true, defaultValueSql: "(getutcdate())")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK__ExamViolationLog__3213E83F0D306CF", x => x.id);
                    table.ForeignKey(
                        name: "FK__ExamViolationLog__response_id",
                        column: x => x.response_id,
                        principalTable: "Response",
                        principalColumn: "id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK__ExamViolationLog__session_id",
                        column: x => x.exam_session_id,
                        principalTable: "ExamSession",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "FormStatus",
                columns: new[] { "id", "status" },
                values: new object[,]
                {
                    { 1, "Draft" },
                    { 2, "Published" },
                    { 3, "Closed" }
                });

            migrationBuilder.InsertData(
                table: "FormType",
                columns: new[] { "id", "type" },
                values: new object[,]
                {
                    { 1, "Single Page" },
                    { 2, "Multi Page" }
                });

            migrationBuilder.InsertData(
                table: "QuestionType",
                columns: new[] { "id", "type" },
                values: new object[,]
                {
                    { 1, "Essay" },
                    { 2, "Multiple Choice" },
                    { 3, "Checkbox" },
                    { 4, "Date Time" },
                    { 5, "True False" }
                });

            migrationBuilder.InsertData(
                table: "ResponseStatus",
                columns: new[] { "id", "status" },
                values: new object[,]
                {
                    { 1, "new" },
                    { 5, "submitted" }
                });

            migrationBuilder.CreateIndex(
                name: "IX__ExamSession__form_lastseen",
                table: "ExamSession",
                columns: new[] { "form_id", "last_seen_at" });

            migrationBuilder.CreateIndex(
                name: "IX_ExamSession_respondent_id",
                table: "ExamSession",
                column: "respondent_id");

            migrationBuilder.CreateIndex(
                name: "IX_ExamSession_submitted_response_id",
                table: "ExamSession",
                column: "submitted_response_id");

            migrationBuilder.CreateIndex(
                name: "UQ__ExamSession__Form_Session",
                table: "ExamSession",
                columns: new[] { "form_id", "session_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX__ExamViolationLog__response_id",
                table: "ExamViolationLog",
                column: "response_id");

            migrationBuilder.CreateIndex(
                name: "IX__ExamViolationLog__session_id",
                table: "ExamViolationLog",
                column: "exam_session_id");

            migrationBuilder.CreateIndex(
                name: "IX__Feedback__form_id",
                table: "Feedback",
                column: "form_id");

            migrationBuilder.CreateIndex(
                name: "IX__Feedback__response_id",
                table: "Feedback",
                column: "response_id");

            migrationBuilder.CreateIndex(
                name: "IX__Feedback__user_id",
                table: "Feedback",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX__Form__user_deleted",
                table: "Form",
                columns: new[] { "user_id", "deleted_at" });

            migrationBuilder.CreateIndex(
                name: "IX_Form_status_id",
                table: "Form",
                column: "status_id");

            migrationBuilder.CreateIndex(
                name: "UQ__Form__12EAC3A5F2FF2D7C",
                table: "Form",
                column: "form_link",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX__FormAttemptAllowance__form_name",
                table: "FormAttemptAllowance",
                columns: new[] { "form_id", "respondent_name" });

            migrationBuilder.CreateIndex(
                name: "IX__FormAttemptAllowance__form_user",
                table: "FormAttemptAllowance",
                columns: new[] { "form_id", "respondent_id" });

            migrationBuilder.CreateIndex(
                name: "IX_FormAttemptAllowance_respondent_id",
                table: "FormAttemptAllowance",
                column: "respondent_id");

            migrationBuilder.CreateIndex(
                name: "IX_FormSetting_form_type_id",
                table: "FormSetting",
                column: "form_type_id");

            migrationBuilder.CreateIndex(
                name: "UQ__FormSett__190E16C8852D4A97",
                table: "FormSetting",
                column: "form_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX__GeminiApiKeyRedemption__key_user",
                table: "GeminiApiKeyRedemption",
                columns: new[] { "key_id", "user_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_GeminiApiKeyRedemption_user_id",
                table: "GeminiApiKeyRedemption",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX_OptionQuestion_question_id",
                table: "OptionQuestion",
                column: "question_id");

            migrationBuilder.CreateIndex(
                name: "IX__PasswordResetToken__user_id",
                table: "PasswordResetToken",
                column: "user_id");

            migrationBuilder.CreateIndex(
                name: "IX__Question__form_deleted",
                table: "Question",
                columns: new[] { "form_id", "deleted_at" });

            migrationBuilder.CreateIndex(
                name: "IX_Question_type_id",
                table: "Question",
                column: "type_id");

            migrationBuilder.CreateIndex(
                name: "IX__RegistrationOtp__email",
                table: "RegistrationOtp",
                column: "email");

            migrationBuilder.CreateIndex(
                name: "IX__RespondentAnswer__question_id",
                table: "RespondentAnswer",
                column: "question_id");

            migrationBuilder.CreateIndex(
                name: "IX__RespondentAnswer__response_id",
                table: "RespondentAnswer",
                column: "response_id");

            migrationBuilder.CreateIndex(
                name: "IX_RespondentAnswer_option_id",
                table: "RespondentAnswer",
                column: "option_id");

            migrationBuilder.CreateIndex(
                name: "IX__Response__form_submitted",
                table: "Response",
                columns: new[] { "form_id", "submitted_at" });

            migrationBuilder.CreateIndex(
                name: "IX__Response__respondent_id",
                table: "Response",
                column: "respondent_id");

            migrationBuilder.CreateIndex(
                name: "IX_Response_status_id",
                table: "Response",
                column: "status_id");

            migrationBuilder.CreateIndex(
                name: "UQ__User__AB6E6164EA4F3FA3",
                table: "User",
                column: "email",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ__User__F3DBC572C6AD5753",
                table: "User",
                column: "username",
                unique: true,
                filter: "[username] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ExamViolationLog");

            migrationBuilder.DropTable(
                name: "Feedback");

            migrationBuilder.DropTable(
                name: "FormAttemptAllowance");

            migrationBuilder.DropTable(
                name: "FormSetting");

            migrationBuilder.DropTable(
                name: "GeminiApiKeyRedemption");

            migrationBuilder.DropTable(
                name: "PasswordResetToken");

            migrationBuilder.DropTable(
                name: "RegistrationOtp");

            migrationBuilder.DropTable(
                name: "RespondentAnswer");

            migrationBuilder.DropTable(
                name: "ExamSession");

            migrationBuilder.DropTable(
                name: "FormType");

            migrationBuilder.DropTable(
                name: "GeminiApiKey");

            migrationBuilder.DropTable(
                name: "OptionQuestion");

            migrationBuilder.DropTable(
                name: "Response");

            migrationBuilder.DropTable(
                name: "Question");

            migrationBuilder.DropTable(
                name: "ResponseStatus");

            migrationBuilder.DropTable(
                name: "Form");

            migrationBuilder.DropTable(
                name: "QuestionType");

            migrationBuilder.DropTable(
                name: "FormStatus");

            migrationBuilder.DropTable(
                name: "User");
        }
    }
}
