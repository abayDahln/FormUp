-- Baseline: tandai 27 migrasi sebagai sudah diterapkan, TANPA mengubah data.
-- HANYA jalankan setelah check-schema.sql menunjukkan semua kolom/tabel = 1.
-- Jalankan: sqlcmd -S localhost -U sa -P <password> -C -i baseline-migrations.sql

USE [FormUpDb];
GO

IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[__EFMigrationsHistory] (
        [MigrationId]    nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32)  NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END
GO

INSERT INTO [dbo].[__EFMigrationsHistory] ([MigrationId], [ProductVersion])
SELECT v.[MigrationId], v.[ProductVersion]
FROM (VALUES
    ('20260726111729_InitialCreate', '8.0.29'),
    ('20260730050344_AddFeedbackTables', '8.0.29'),
    ('20260730130019_AddFeedbackTable', '8.0.29'),
    ('20260731142941_AddOtpTypeToPasswordResetToken', '8.0.29'),
    ('20260731144504_SplitOtpIntoSeparateTables', '8.0.29'),
    ('20260801105503_MakeUsernameNullable', '8.0.29'),
    ('20260801111455_MakeRoleRequired', '8.0.29'),
    ('20260801114247_UseJakartaTime', '8.0.29'),
    ('20260802052335_AddSecurityConcepts', '8.0.29'),
    ('20260802055503_RemoveRefreshTokenTable', '8.0.29'),
    ('20260805072902_AddRespondentNameToResponse', '8.0.29'),
    ('20260805074937_AddRequiredLoginToFormSetting', '8.0.29'),
    ('20260805082708_AddOpenFormTimeToFormSetting', '8.0.29'),
    ('20260805090910_AddGuestTokenToResponse', '8.0.29'),
    ('20260806032052_AddRichTextContentFormat', '8.0.29'),
    ('20260806032152_BackfillRichTextContentFormat', '8.0.29'),
    ('20260808081220_AddRespondentIp', '8.0.29'),
    ('20260808102131_RemoveGuestTokenAndRespondentIp', '8.0.29'),
    ('20260827144016_AddPointsToQuestion', '8.0.29'),
    ('20260830045202_FeedbackAnonAndUtc', '8.0.29'),
    ('20260903012955_AddExamModeThemeAndScoreOverride', '8.0.29'),
    ('20260904043805_AddExamMonitoring', '8.0.29'),
    ('20260911065056_AddG1PerformanceIndexes', '8.0.29'),
    ('20260916015245_AddFormAttemptAllowance', '8.0.29'),
    ('20260918123822_SeedResponseStatusCanonical', '8.0.29'),
    ('20260918123911_BackfillSubmittedStatusForLegacyResponses', '8.0.29'),
    ('20260919032418_AddRetakeTokenToAttemptAllowance', '8.0.29')
) AS v([MigrationId], [ProductVersion])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[__EFMigrationsHistory] h WHERE h.[MigrationId] = v.[MigrationId]
);
GO

SELECT COUNT(*) AS history_rows FROM [dbo].[__EFMigrationsHistory];
GO