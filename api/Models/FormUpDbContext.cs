using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace FormUpAPI.Models;

public partial class FormUpDbContext : DbContext
{
    public FormUpDbContext()
    {
    }

    public FormUpDbContext(DbContextOptions<FormUpDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Form> Forms { get; set; }

    public virtual DbSet<FormSetting> FormSettings { get; set; }

    public virtual DbSet<FormStatus> FormStatuses { get; set; }

    public virtual DbSet<OptionQuestion> OptionQuestions { get; set; }

    public virtual DbSet<Question> Questions { get; set; }

    public virtual DbSet<QuestionType> QuestionTypes { get; set; }

    public virtual DbSet<RespondentAnswer> RespondentAnswers { get; set; }

    public virtual DbSet<Response> Responses { get; set; }

    public virtual DbSet<ResponseStatus> ResponseStatuses { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<PasswordResetToken> PasswordResetTokens { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Form>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__Form__3213E83F3D69895B");

            entity.ToTable("Form");

            entity.HasIndex(e => e.FormLink, "UQ__Form__12EAC3A5F2FF2D7C").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.BannerImage)
                .HasMaxLength(255)
                .HasColumnName("banner_image");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.DeletedAt)
                .HasColumnType("datetime")
                .HasColumnName("deleted_at");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.FormLink)
                .HasMaxLength(100)
                .HasColumnName("form_link");
            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.Title)
                .HasMaxLength(255)
                .HasColumnName("title");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Status).WithMany(p => p.Forms)
                .HasForeignKey(d => d.StatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Form__status_id__49C3F6B7");

            entity.HasOne(d => d.User).WithMany(p => p.Forms)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Form__user_id__48CFD27E");
        });

        modelBuilder.Entity<FormSetting>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__FormSett__3213E83F0D306CE3");

            entity.ToTable("FormSetting");

            entity.HasIndex(e => e.FormId, "UQ__FormSett__190E16C8852D4A97").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CloseFormTime)
                .HasColumnType("datetime")
                .HasColumnName("close_form_time");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.FormId).HasColumnName("form_id");
            entity.Property(e => e.FormToken)
                .HasMaxLength(50)
                .HasColumnName("form_token");
            entity.Property(e => e.OneResponse)
                .HasDefaultValue(false)
                .HasColumnName("one_response");
            entity.Property(e => e.RandomizeQuestions)
                .HasDefaultValue(false)
                .HasColumnName("randomize_questions");
            entity.Property(e => e.ShowScore)
                .HasDefaultValue(false)
                .HasColumnName("show_score");
            entity.Property(e => e.TimerDuration).HasColumnName("timer_duration");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Form).WithOne(p => p.FormSetting)
                .HasForeignKey<FormSetting>(d => d.FormId)
                .HasConstraintName("FK__FormSetti__form___5165187F");
        });

        modelBuilder.Entity<FormStatus>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__FormStat__3213E83FE1FFAC60");

            entity.ToTable("FormStatus");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.Status)
                .HasMaxLength(50)
                .HasColumnName("status");
        });

        modelBuilder.Entity<OptionQuestion>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__OptionQu__3213E83F6E9D36B3");

            entity.ToTable("OptionQuestion");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.IsCorrect)
                .HasDefaultValue(false)
                .HasColumnName("is_correct");
            entity.Property(e => e.OptionImage)
                .HasMaxLength(255)
                .HasColumnName("option_image");
            entity.Property(e => e.OptionOrder).HasColumnName("option_order");
            entity.Property(e => e.OptionText).HasColumnName("option_text");
            entity.Property(e => e.QuestionId).HasColumnName("question_id");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Question).WithMany(p => p.OptionQuestions)
                .HasForeignKey(d => d.QuestionId)
                .HasConstraintName("FK__OptionQue__quest__5CD6CB2B");
        });

        modelBuilder.Entity<Question>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__Question__3213E83F23B2E249");

            entity.ToTable("Question");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CorrectAnswer).HasColumnName("correct_answer");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.DeletedAt)
                .HasColumnType("datetime")
                .HasColumnName("deleted_at");
            entity.Property(e => e.FormId).HasColumnName("form_id");
            entity.Property(e => e.IsRequired)
                .HasDefaultValue(false)
                .HasColumnName("is_required");
            entity.Property(e => e.Question1).HasColumnName("question");
            entity.Property(e => e.QuestionAudio)
                .HasMaxLength(255)
                .HasColumnName("question_audio");
            entity.Property(e => e.QuestionImage)
                .HasMaxLength(255)
                .HasColumnName("question_image");
            entity.Property(e => e.QuestionOrder).HasColumnName("question_order");
            entity.Property(e => e.RandomizeOptions)
                .HasDefaultValue(false)
                .HasColumnName("randomize_options");
            entity.Property(e => e.TypeId).HasColumnName("type_id");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Form).WithMany(p => p.Questions)
                .HasForeignKey(d => d.FormId)
                .HasConstraintName("FK__Question__form_i__571DF1D5");

            entity.HasOne(d => d.Type).WithMany(p => p.Questions)
                .HasForeignKey(d => d.TypeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Question__type_i__5812160E");
        });

        modelBuilder.Entity<QuestionType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__Question__3213E83F5563C7FF");

            entity.ToTable("QuestionType");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .HasColumnName("type");
        });

        modelBuilder.Entity<RespondentAnswer>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__Responde__3213E83F515219BC");

            entity.ToTable("RespondentAnswer");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.AnswerValue).HasColumnName("answer_value");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.OptionId).HasColumnName("option_id");
            entity.Property(e => e.QuestionId).HasColumnName("question_id");
            entity.Property(e => e.ResponseId).HasColumnName("response_id");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Option).WithMany(p => p.RespondentAnswers)
                .HasForeignKey(d => d.OptionId)
                .HasConstraintName("FK__Responden__optio__68487DD7");

            entity.HasOne(d => d.Question).WithMany(p => p.RespondentAnswers)
                .HasForeignKey(d => d.QuestionId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Responden__quest__6754599E");

            entity.HasOne(d => d.Response).WithMany(p => p.RespondentAnswers)
                .HasForeignKey(d => d.ResponseId)
                .HasConstraintName("FK__Responden__respo__66603565");
        });

        modelBuilder.Entity<Response>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__Response__3213E83F3BCBD39E");

            entity.ToTable("Response");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.FormId).HasColumnName("form_id");
            entity.Property(e => e.RespondentId).HasColumnName("respondent_id");
            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.SubmittedAt)
                .HasColumnType("datetime")
                .HasColumnName("submitted_at");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Form).WithMany(p => p.Responses)
                .HasForeignKey(d => d.FormId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Response__form_i__60A75C0F");

            entity.HasOne(d => d.Respondent).WithMany(p => p.Responses)
                .HasForeignKey(d => d.RespondentId)
                .HasConstraintName("FK__Response__respon__619B8048");

            entity.HasOne(d => d.Status).WithMany(p => p.Responses)
                .HasForeignKey(d => d.StatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Response__status__628FA481");
        });

        modelBuilder.Entity<ResponseStatus>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__Response__3213E83F3C285B45");

            entity.ToTable("ResponseStatus");

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.Status)
                .HasMaxLength(50)
                .HasColumnName("status");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__User__3213E83F660F0712");

            entity.ToTable("User");

            entity.HasIndex(e => e.Email, "UQ__User__AB6E6164EA4F3FA3").IsUnique();

            entity.HasIndex(e => e.Username, "UQ__User__F3DBC572C6AD5753").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.Birthdate).HasColumnName("birthdate");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_at");
            entity.Property(e => e.DeletedAt)
                .HasColumnType("datetime")
                .HasColumnName("deleted_at");
            entity.Property(e => e.Email)
                .HasMaxLength(100)
                .HasColumnName("email");
            entity.Property(e => e.Fullname)
                .HasMaxLength(100)
                .HasColumnName("fullname");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.Password)
                .HasMaxLength(255)
                .HasColumnName("password");
            entity.Property(e => e.ProfileImage)
                .HasMaxLength(255)
                .HasColumnName("profile_image");
            entity.Property(e => e.Role)
                .HasMaxLength(20)
                .HasDefaultValue("USER")
                .HasColumnName("role");
            entity.Property(e => e.UpdatedAt)
                .HasColumnType("datetime")
                .HasColumnName("updated_at");
            entity.Property(e => e.Username)
                .HasMaxLength(50)
                .HasColumnName("username");
        });

        modelBuilder.Entity<PasswordResetToken>(entity =>
        {
            entity.ToTable("PasswordResetToken");

            entity.HasKey(e => e.Id);

            entity.Property(e => e.Otp)
                .HasMaxLength(6)
                .IsRequired();

            entity.Property(e => e.ExpiresAt)
                .HasColumnType("datetime")
                .IsRequired();

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime");

            entity.HasOne(e => e.User)
                .WithMany()
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
