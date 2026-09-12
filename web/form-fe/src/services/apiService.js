const envUrl = import.meta.env.VITE_API_BASE_URL;
const API_BASE_URL = (envUrl !== undefined && envUrl !== '')
    ? envUrl 
    : (import.meta.env.DEV ? '' : 'https://api.formup.my.id');

export const getToken = () => {
    if (typeof window === 'undefined') return null;
    const local = localStorage.getItem('token');
    if (local) return local;
    const session = sessionStorage.getItem('token');
    if (session) return session;

    if (typeof document !== 'undefined') {
        const match = document.cookie.match(/(?:^|;\s*)formup_token=([^;]+)/);
        if (match && match[1]) {
            localStorage.setItem('token', match[1]);
            return match[1];
        }
    }
    return null;
};

// Upload gambar untuk opsi jawaban tertentu
export const uploadOptionImage = (formId, questionId, optionId, file, onProgress) => {
    return new Promise((resolve) => {
        const token = getToken();
        const form = new FormData();
        form.append('file', file);
        const xhr = new XMLHttpRequest();
        if (typeof onProgress === 'function') {
            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
            });
        }
        xhr.onload = () => {
            try {
                const data = JSON.parse(xhr.responseText);
                resolve({ ok: xhr.status >= 200 && xhr.status < 300, status: xhr.status, data: data?.data ?? data, message: data?.message });
            } catch {
                resolve({ ok: false, status: xhr.status, message: 'Response parse error' });
            }
        };
        xhr.onerror = () => resolve({ ok: false, status: 0, message: 'Network error' });
        xhr.open('POST', `${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/options/${optionId}/upload-image`);
        if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        xhr.send(form);
    });
};

const authHeaders = () => {
    const headers = { 'Content-Type': 'application/json' };
    const token = getToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;
    return headers;
};

const parseResponse = async (res) => {
    let body;
    try { body = await res.json(); } catch { body = {}; }
    const serverDown = res.status === 502 || res.status === 503 || res.status === 504;
    return {
        ok: res.ok,
        status: body.status ?? res.status,
        message: body.message ?? (res.ok ? 'OK' : (serverDown ? 'Server sedang tidak aktif. Silakan coba lagi beberapa saat kemudian.' : 'Error')),
        data: body.data ?? null,
    };
};

// ── Auth Endpoints ────────────────────────────────────────────────────────────
export const login = async (email, password) => {
    const res = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
    });
    return parseResponse(res);
};

export const register = async (fullname, username, email, password, birthdate) => {
    const res = await fetch(`${API_BASE_URL}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullname, username, email, password, birthdate }),
    });
    return parseResponse(res);
};

export const verifyRegistration = async (fullname, username, email, password, birthdate, otp) => {
    const res = await fetch(`${API_BASE_URL}/api/auth/verify-registration`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullname, username, email, password, birthdate, otp }),
    });
    return parseResponse(res);
};

export const refreshToken = async () => {
    const res = await fetch(`${API_BASE_URL}/api/auth/refresh`, {
        method: 'POST',
        headers: authHeaders(),
    });
    return parseResponse(res);
};

export const forgotPassword = async (email) => {
    const res = await fetch(`${API_BASE_URL}/api/auth/forgot-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
    });
    return parseResponse(res);
};

export const resetPassword = async (email, otp, newPassword) => {
    const res = await fetch(`${API_BASE_URL}/api/auth/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otp, newPassword }),
    });
    return parseResponse(res);
};

// ── User Profile Endpoints ────────────────────────────────────────────────────
export const getMyProfile = async () => parseResponse(await fetch(`${API_BASE_URL}/api/users/me`, { headers: authHeaders() }));

export const updateProfile = async (payload) => {
    const res = await fetch(`${API_BASE_URL}/api/users/me`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify(payload),
    });
    return parseResponse(res);
};

export const changePassword = async (currentPassword, newPassword) => {
    const res = await fetch(`${API_BASE_URL}/api/users/change-password`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ currentPassword, newPassword }),
    });
    return parseResponse(res);
};

export const uploadProfileImage = async (file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    const res = await fetch(`${API_BASE_URL}/api/users/me/profile-image`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
    return parseResponse(res);
};

export const getMyStats = async () => parseResponse(await fetch(`${API_BASE_URL}/api/users/me/stats`, { headers: authHeaders() }));
export const getMySubmittedResponses = async () => parseResponse(await fetch(`${API_BASE_URL}/api/users/me/responses`, { headers: authHeaders() }));

// ── Reference Endpoints ──────────────────────────────────────────────────────
export const getFormTypes = async () => parseResponse(await fetch(`${API_BASE_URL}/api/references/form-types`, { headers: authHeaders() }));
export const getFormStatuses = async () => parseResponse(await fetch(`${API_BASE_URL}/api/references/form-statuses`, { headers: authHeaders() }));
export const getQuestionTypes = async () => parseResponse(await fetch(`${API_BASE_URL}/api/references/question-types`, { headers: authHeaders() }));

// ── Form Endpoints ────────────────────────────────────────────────────────────
export const getMyForms = async () => parseResponse(await fetch(`${API_BASE_URL}/api/forms`, { headers: authHeaders() }));

export const getFormById = async (id) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${id}`, { headers: authHeaders() }));

export const createForm = async ({ title, description, descriptionFormat }) => {
    const res = await fetch(`${API_BASE_URL}/api/forms`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ title, description, descriptionFormat }),
    });
    return parseResponse(res);
};

export const updateForm = async (id, payload) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${id}`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify(payload),
    });
    return parseResponse(res);
};

export const deleteForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${id}`, { method: 'DELETE', headers: authHeaders() });
    return parseResponse(res);
};

export const bulkDeleteForms = async (formIds) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/bulk-delete`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ formIds }),
    });
    return parseResponse(res);
};

export const togglePublishForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${id}/publish`, { method: 'POST', headers: authHeaders() });
    return parseResponse(res);
};

export const updateFormSettings = async (id, settings) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${id}/settings`, {
        method: 'PATCH',
        headers: authHeaders(),
        body: JSON.stringify(settings),
    });
    return parseResponse(res);
};

export const getFormShare = async (id) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${id}/share`, { headers: authHeaders() }));

export const uploadFormBanner = async (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/banner`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
    return parseResponse(res);
};

// ── Question Endpoints ────────────────────────────────────────────────────────
export const getQuestions = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/questions`, { headers: authHeaders() }));

export const saveQuestions = async (formId, questions) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ questions }),
    });
    return parseResponse(res);
};

export const addQuestions = async (formId, questions) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ questions }),
    });
    return parseResponse(res);
};

export const deleteQuestion = async (formId, questionId) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}`, {
        method: 'DELETE',
        headers: authHeaders(),
    });
    return parseResponse(res);
};

export const importQuestions = async (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/import`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
    return parseResponse(res);
};

// B1: Use XMLHttpRequest for upload progress support
export const uploadQuestionImage = (formId, questionId, file, onProgress) => {
    return new Promise((resolve) => {
        const token = getToken();
        const form = new FormData();
        form.append('file', file);
        const xhr = new XMLHttpRequest();
        if (typeof onProgress === 'function') {
            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
            });
        }
        xhr.onload = () => {
            try {
                const data = JSON.parse(xhr.responseText);
                resolve({ ok: xhr.status >= 200 && xhr.status < 300, status: xhr.status, data: data?.data ?? data, message: data?.message });
            } catch {
                resolve({ ok: false, status: xhr.status, message: 'Response parse error' });
            }
        };
        xhr.onerror = () => resolve({ ok: false, status: 0, message: 'Network error' });
        xhr.open('POST', `${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-image`);
        if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        xhr.send(form);
    });
};

// B1: Use XMLHttpRequest for upload progress support
export const uploadQuestionAudio = (formId, questionId, file, onProgress) => {
    return new Promise((resolve) => {
        const token = getToken();
        const form = new FormData();
        form.append('file', file);
        const xhr = new XMLHttpRequest();
        if (typeof onProgress === 'function') {
            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) onProgress(Math.round((e.loaded / e.total) * 100));
            });
        }
        xhr.onload = () => {
            try {
                const data = JSON.parse(xhr.responseText);
                resolve({ ok: xhr.status >= 200 && xhr.status < 300, status: xhr.status, data: data?.data ?? data, message: data?.message });
            } catch {
                resolve({ ok: false, status: xhr.status, message: 'Response parse error' });
            }
        };
        xhr.onerror = () => resolve({ ok: false, status: 0, message: 'Network error' });
        xhr.open('POST', `${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-audio`);
        if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`);
        xhr.send(form);
    });
};

// ── Response Endpoints (Owner) ────────────────────────────────────────────────
export const getFormResponses = async (formId, { page, pageSize } = {}) => {
    const params = new URLSearchParams();
    if (page != null) params.set('page', page);
    if (pageSize != null) params.set('pageSize', pageSize);
    const qs = params.toString() ? `?${params}` : '';
    return parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/responses${qs}`, { headers: authHeaders() }));
};
export const getResponseDetail = async (formId, responseId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/responses/${responseId}`, { headers: authHeaders() }));

// GET /api/forms/{formId}/responses/{id}/result — scored result for owner view
export const getResponseResult = async (formId, responseId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/responses/${responseId}/result`, { headers: authHeaders() }));

// GET /api/forms/{formId}/responses/{id}/attempts — all attempts by same respondent
export const getResponseAttempts = async (formId, responseId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/responses/${responseId}/attempts`, { headers: authHeaders() }));

export const updateResponseStatus = async (responseId, statusId) => {
    const res = await fetch(`${API_BASE_URL}/api/responses/${responseId}/status`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ statusId }),
    });
    return parseResponse(res);
};

// Helper: Resolve answer key per question according to specification
export const resolveAnswerKey = (q) => {
    if (!q) return '';
    const typeId = q.typeId ?? q.type_id;
    const typeName = String(q.type || q.questionType?.type || '').toLowerCase();

    // Untuk tipe soal Essay atau Benar-Salah: ambil dari q.CorrectAnswer
    if (typeId === 1 || typeId === 5 || typeName.includes('essay') || typeName.includes('benar') || typeName.includes('true') || typeName.includes('false')) {
        return q.correctAnswer || q.CorrectAnswer || '';
    }

    // Untuk tipe soal PG atau Checkbox: gabungkan teks opsi yang IsCorrect == true, dipisah "; "
    const options = q.options || q.optionQuestions || q.OptionQuestions || [];
    if (Array.isArray(options) && options.length > 0) {
        const correctOpts = options
            .filter(o => o.isCorrect === true || o.IsCorrect === true)
            .map(o => o.optionText || o.OptionText || '')
            .filter(Boolean);
        if (correctOpts.length > 0) {
            return correctOpts.join('; ');
        }
    }

    return q.correctAnswer || q.CorrectAnswer || '';
};
export const ResolveAnswerKey = resolveAnswerKey;

// Helper: Bersihkan notasi KaTeX/LaTeX jadi teks/unicode biasa (A5)
export const stripMathNotation = (text) => {
    if (text === null || text === undefined) return '';
    let str = String(text);

    // Iterative replacement for fractions: \frac{a}{b} -> a/b
    for (let i = 0; i < 5; i++) {
        const next = str.replace(/\\frac\{([^{}]+)\}\{([^{}]+)\}/g, '$1/$2');
        if (next === str) break;
        str = next;
    }

    // Square roots: \sqrt[n]{x} -> n√(x), \sqrt{x} -> √(x)
    str = str.replace(/\\sqrt\[([^\]]+)\]\{([^{}]+)\}/g, '$1√($2)');
    str = str.replace(/\\sqrt\{([^{}]+)\}/g, '√($1)');

    // Common LaTeX math symbols to unicode
    const mathReplacements = [
        [/\\times\b/g, '×'],
        [/\\div\b/g, '÷'],
        [/\\pm\b/g, '±'],
        [/\\mp\b/g, '∓'],
        [/\\le(q)?\b/g, '≤'],
        [/\\ge(q)?\b/g, '≥'],
        [/\\ne(q)?\b/g, '≠'],
        [/\\approx\b/g, '≈'],
        [/\\sim\b/g, '~'],
        [/\\infty\b/g, '∞'],
        [/\\cdot\b/g, '·'],
        [/\\bullet\b/g, '•'],
        [/\\circ\b/g, '°'],
        [/\\degree\b/g, '°'],
        [/\\alpha\b/g, 'α'],
        [/\\beta\b/g, 'β'],
        [/\\gamma\b/g, 'γ'],
        [/\\delta\b/g, 'δ'],
        [/\\Delta\b/g, 'Δ'],
        [/\\pi\b/g, 'π'],
        [/\\theta\b/g, 'θ'],
        [/\\lambda\b/g, 'λ'],
        [/\\sigma\b/g, 'σ'],
        [/\\omega\b/g, 'ω'],
        [/\\sum\b/g, 'Σ'],
        [/\\prod\b/g, '∏'],
        [/\\rightarrow\b/g, '→'],
        [/\\leftarrow\b/g, '←'],
        [/\\leftrightarrow\b/g, '↔'],
    ];

    for (const [pattern, replacement] of mathReplacements) {
        str = str.replace(pattern, replacement);
    }

    // Text wrappers: \text{...}, \mathrm{...}, etc.
    str = str.replace(/\\(?:text|mathrm|mathbf|mathit|textbf|textit)\{([^{}]+)\}/g, '$1');

    // Remove $ and $$ delimiters
    str = str.replace(/\$\$([\s\S]*?)\$\$/g, '$1');
    str = str.replace(/\$([^$]+)\$/g, '$1');

    // Remove remaining escaped braces: \{ -> {, \} -> }
    str = str.replace(/\\([{}])/g, '$1');

    // Clean up residual backslashes before alpha words
    str = str.replace(/\\[a-zA-Z]+/g, '');

    // Strip html tags
    str = str.replace(/<[^>]*>/g, '');

    return str.trim();
};

export const exportUrl = (formId, format = 'csv', includeAnswerKey = true) => {
    const token = getToken();
    const params = new URLSearchParams();
    if (format) params.set('format', format);
    if (includeAnswerKey !== undefined) params.set('includeAnswerKey', includeAnswerKey);
    if (token) params.set('token', token);
    const qs = params.toString() ? `?${params}` : '';
    return `${API_BASE_URL}/api/forms/${formId}/responses/export${qs}`;
};

export const exportFormResponses = async (formId, format = 'csv', includeAnswerKey = true) => {
    const token = getToken();
    const fmt = (format || 'csv').toLowerCase();
    const params = new URLSearchParams();
    params.set('format', fmt);
    if (includeAnswerKey !== undefined) {
        params.set('includeAnswerKey', includeAnswerKey);
    }

    try {
        const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/responses/export?${params.toString()}`, {
            headers: token ? { Authorization: `Bearer ${token}` } : {},
        });

        if (!res.ok) {
            let msg = 'Gagal mengekspor data respons';
            let errDetail = '';
            try {
                const err = await res.json();
                msg = err.message || msg;
                errDetail = JSON.stringify(err);
            } catch {
                try {
                    errDetail = await res.text();
                } catch {}
            }

            if (fmt === 'pdf' && res.status === 500) {
                // TODO: Backend PDF generator (ResponsesController.ExportPdf using QuestPDF / DinkToPdf)
                // throws 500 when question text or answer text contains raw math notation (KaTeX/LaTeX).
                // Backend requires math sanitization before PDF layout compilation.
                console.error('[Export PDF 500 Error] Server failed generating PDF:', res.status, errDetail);
                msg = 'Export PDF gagal, kemungkinan karena konten matematika pada soal. Coba export CSV/Excel sementara, atau hubungi admin.';
            }

            return { ok: false, message: msg };
        }

        const blob = await res.blob();
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        const ext = fmt === 'xlsx' ? 'xlsx' : fmt === 'pdf' ? 'pdf' : 'csv';
        a.download = `responses-form-${formId}.${ext}`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        window.URL.revokeObjectURL(url);
        return { ok: true };
    } catch (networkErr) {
        console.error('[Export Responses Network Error]:', networkErr);
        return {
            ok: false,
            message: fmt === 'pdf'
                ? 'Export PDF gagal, kemungkinan karena konten matematika pada soal. Coba export CSV/Excel sementara, atau hubungi admin.'
                : 'Terjadi kesalahan jaringan saat mengekspor data respons.'
        };
    }
};

// ── Feedback Endpoints ────────────────────────────────────────────────────────
export const submitFeedback = async (formId, { reason, description, responseId = null }) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/feedback`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ reason, description, responseId }),
    });
    return parseResponse(res);
};

export const getMyFeedback = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/feedback`, { headers: authHeaders() }));
export const getFormFeedbacks = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/feedbacks`, { headers: authHeaders() }));

// ── Template Endpoints ────────────────────────────────────────────────────────
export const templateDownloadUrl = (format = 'csv') =>
    `${API_BASE_URL}/api/templates/import-questions?format=${format}`;

// ── Analytics Endpoints ───────────────────────────────────────────────────────
export const getFormAnalytics = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/analytics`, { headers: authHeaders() }));

// ── Public Form Flow (Responden) ──────────────────────────────────────────────

// Step 1: Get public form metadata & requirements (no questions)
export const getPublicFormByLink = async (formLink) => {
    const res = await fetch(`${API_BASE_URL}/api/public/forms/${formLink}`);
    return parseResponse(res);
};

// Step 2: Request public questions after token/login validation
export const getPublicFormQuestions = async (formLink, { token, name } = {}) => {
    const headers = authHeaders();
    const res = await fetch(`${API_BASE_URL}/api/public/forms/${formLink}/questions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ token: token || null, name: name || null }),
    });
    return parseResponse(res);
};

// Step 3: Submit public form responses
export const submitPublicFormResponse = async (formLink, payload) => {
    const headers = authHeaders();
    const res = await fetch(`${API_BASE_URL}/api/public/forms/${formLink}/responses`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
    });
    return parseResponse(res);
};

// Step 4: Get public response result (for respondent view)
export const getPublicResponseResult = async (formLink, responseId, guestToken) => {
    const url = guestToken
        ? `${API_BASE_URL}/api/public/forms/${formLink}/responses/${responseId}?token=${encodeURIComponent(guestToken)}`
        : `${API_BASE_URL}/api/public/forms/${formLink}/responses/${responseId}`;
    const res = await fetch(url, { headers: authHeaders() });
    return parseResponse(res);
};

// ── Exam Monitoring Endpoints ────────────────────────────────────────────────
// Backend: [HttpPost("api/public/forms/{formLink}/exam-events")] in ExamMonitoringController.cs
export const postExamEvent = async (formLink, eventData) => {
    const headers = authHeaders();
    const res = await fetch(`${API_BASE_URL}/api/public/forms/${formLink}/exam-events`, {
        method: 'POST',
        headers,
        body: JSON.stringify(eventData),
    });
    return parseResponse(res);
};

// Backend: [HttpGet("api/forms/{formId}/exam-monitoring")] in ExamMonitoringController.cs
export const getExamMonitoring = async (formId) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/exam-monitoring`, {
        headers: authHeaders(),
    });
    return parseResponse(res);
};

export const ExamProctorActions = {
    ForceSubmitByProctor: 'FORCE_SUBMIT_BY_PROCTOR',
};

// Backend: [HttpPost("api/forms/{formId}/exam-monitoring/sessions/{sessionId}/force-submit")]
export const forceSubmitExamSession = async (formId, sessionId) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/exam-monitoring/sessions/${encodeURIComponent(sessionId)}/force-submit`, {
        method: 'POST',
        headers: authHeaders(),
    });
    return parseResponse(res);
};

// Backend: [HttpPost("api/forms/{formId}/exam-monitoring/sessions/{sessionId}/reset")]
export const resetExamSession = async (formId, sessionId) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/exam-monitoring/sessions/${encodeURIComponent(sessionId)}/reset`, {
        method: 'POST',
        headers: authHeaders(),
    });
    return parseResponse(res);
};

// Backend: [HttpPost("api/public/forms/{formLink}/exam-sessions/{sessionId}/sync-answers")]
export const syncExamAnswers = async (formLink, sessionId, { answers, respondentName }) => {
    const res = await fetch(`${API_BASE_URL}/api/public/forms/${encodeURIComponent(formLink)}/exam-sessions/${encodeURIComponent(sessionId)}/sync-answers`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ answers, respondentName }),
    });
    return parseResponse(res);
};

// ── Score Override Endpoints ─────────────────────────────────────────────────
// Backend: [HttpPut("api/responses/{id}/answers/{answerId}/score")] in ResponsesController.cs
export const overrideAnswerScore = async (responseId, answerId, payload) => {
    const res = await fetch(`${API_BASE_URL}/api/responses/${responseId}/answers/${answerId}/score`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify(payload),
    });
    return parseResponse(res);
};

// Backend: [HttpPut("api/responses/{id}/scores")] in ResponsesController.cs
export const bulkOverrideAnswerScores = async (responseId, overrides) => {
    const res = await fetch(`${API_BASE_URL}/api/responses/${responseId}/scores`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ overrides }),
    });
    return parseResponse(res);
};

// ── Admin Endpoints ───────────────────────────────────────────────────────────
export const adminGetUsers = async () => parseResponse(await fetch(`${API_BASE_URL}/api/admin/users`, { headers: authHeaders() }));
export const adminGetUserDetail = async (id) => parseResponse(await fetch(`${API_BASE_URL}/api/admin/users/${id}`, { headers: authHeaders() }));
export const adminGetForms = async () => parseResponse(await fetch(`${API_BASE_URL}/api/admin/forms`, { headers: authHeaders() }));
export const adminGetFormDetail = async (id) => parseResponse(await fetch(`${API_BASE_URL}/api/admin/forms/${id}`, { headers: authHeaders() }));
export const adminGetFeedback = async () => parseResponse(await fetch(`${API_BASE_URL}/api/admin/feedback`, { headers: authHeaders() }));

export const adminBanUser = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/users/${id}/ban`, { method: 'PUT', headers: authHeaders() });
    return parseResponse(res);
};
export const adminActivateUser = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/users/${id}/activate`, { method: 'PUT', headers: authHeaders() });
    return parseResponse(res);
};
export const adminDeleteUser = async (id) => {
    // Backend endpoint: [HttpDelete("users/{id}")] in AdminController.cs
    const res = await fetch(`${API_BASE_URL}/api/admin/users/${id}`, { method: 'DELETE', headers: authHeaders() });
    return parseResponse(res);
};
export const adminTakedownForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/forms/${id}/takedown`, { method: 'POST', headers: authHeaders() });
    return parseResponse(res);
};
export const adminRestoreForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/forms/${id}/restore`, { method: 'POST', headers: authHeaders() });
    return parseResponse(res);
};
export const adminDeleteForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/forms/${id}`, { method: 'DELETE', headers: authHeaders() });
    return parseResponse(res);
};
export const adminDeleteFeedback = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/feedback/${id}`, { method: 'DELETE', headers: authHeaders() });
    return parseResponse(res);
};
export const adminTakedownFormFromFeedback = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/feedback/${id}/takedown`, { method: 'POST', headers: authHeaders() });
    return parseResponse(res);
};
export const adminRestoreFormFromFeedback = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/admin/feedback/${id}/restore`, { method: 'POST', headers: authHeaders() });
    return parseResponse(res);
};

// ── Session Helpers ───────────────────────────────────────────────────────────
export const saveSession = (authData, rememberMe = true) => {
    const storage = rememberMe ? localStorage : sessionStorage;
    const altStorage = rememberMe ? sessionStorage : localStorage;
    altStorage.removeItem('token');
    altStorage.removeItem('user');

    if (authData.token) {
        storage.setItem('token', authData.token);
        // Set cookie with appropriate expiration
        const maxAge = rememberMe ? 60 * 60 * 24 * 30 : ''; // 30 days or session
        const cookieStr = `formup_token=${authData.token}; path=/; SameSite=Lax${maxAge ? `; max-age=${maxAge}` : ''}`;
        if (typeof document !== 'undefined') {
            document.cookie = cookieStr;
        }
    }

    if (authData.user) {
        storage.setItem('user', JSON.stringify(authData.user));
    }

    if (rememberMe) {
        localStorage.setItem('rememberMe', 'true');
    } else {
        localStorage.removeItem('rememberMe');
    }
};

export const clearSession = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    localStorage.removeItem('rememberMe');
    sessionStorage.removeItem('token');
    sessionStorage.removeItem('user');
    if (typeof document !== 'undefined') {
        document.cookie = 'formup_token=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; SameSite=Lax';
        document.cookie = 'formup_token=; path=/; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT';
        document.cookie = 'formup_token=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT';
    }
};

export const isAuthenticated = () => !!getToken();

export const getLocalUser = () => {
    try {
        const u = localStorage.getItem('user') || sessionStorage.getItem('user');
        return u ? JSON.parse(u) : {};
    } catch {
        return {};
    }
};

export const assetUrl = (path, fallback = '') => {
    if (!path) return fallback;
    if (path.startsWith('http')) return path;
    return `${API_BASE_URL}${path.startsWith('/') ? '' : '/'}${path}`;
};
