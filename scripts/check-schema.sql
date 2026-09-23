-- Cek apakah schema DB lama sudah setara versi migrasi terbaru.
-- Jalankan: sqlcmd -S localhost -U sa -P <password> -C -i check-schema.sql
USE [FormUpDb];
GO
SELECT
    CASE WHEN OBJECT_ID(N'dbo.FormStatus',           N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_FormStatus,
    CASE WHEN OBJECT_ID(N'dbo.Feedback',             N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_Feedback,
    CASE WHEN OBJECT_ID(N'dbo.RegistrationOtp',      N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_RegistrationOtp,
    CASE WHEN COL_LENGTH(N'dbo.Question', N'points')            IS NOT NULL THEN 1 ELSE 0 END AS has_Question_points,
    CASE WHEN COL_LENGTH(N'dbo.FormSetting', N'is_exam_mode')   IS NOT NULL THEN 1 ELSE 0 END AS has_FormSetting_is_exam_mode,
    CASE WHEN OBJECT_ID(N'dbo.ExamSession',          N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_ExamSession,
    CASE WHEN OBJECT_ID(N'dbo.ExamViolationLog',     N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_ExamViolationLog,
    CASE WHEN OBJECT_ID(N'dbo.FormAttemptAllowance', N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_FormAttemptAllowance,
    CASE WHEN COL_LENGTH(N'dbo.FormAttemptAllowance', N'is_reopened') IS NOT NULL THEN 1 ELSE 0 END AS has_FormAttemptAllowance_is_reopened,
    (SELECT COUNT(*) FROM [dbo].[__EFMigrationsHistory]) AS history_rows;
GO