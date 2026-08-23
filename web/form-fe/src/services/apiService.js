const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://api.formup.my.id';

const getToken = () => localStorage.getItem('token');

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

export const uploadQuestionImage = async (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-image`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
    return parseResponse(res);
};

export const uploadQuestionAudio = async (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-audio`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
    return parseResponse(res);
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

export const exportUrl = (formId) => `${API_BASE_URL}/api/forms/${formId}/responses/export`;

// ── Feedback Endpoints ────────────────────────────────────────────────────────
export const submitFeedback = async (formId, { reason, description }) => {
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/feedback`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ reason, description }),
    });
    return parseResponse(res);
};

export const getMyFeedback = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/feedback`, { headers: authHeaders() }));

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
export const saveSession = (authData) => {
    if (authData.token) localStorage.setItem('token', authData.token);
    if (authData.user) localStorage.setItem('user', JSON.stringify(authData.user));
};
export const clearSession = () => { localStorage.removeItem('token'); localStorage.removeItem('user'); };
export const isAuthenticated = () => !!localStorage.getItem('token');
export const getLocalUser = () => { try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; } };
export const assetUrl = (path, fallback = '') => {
    if (!path) return fallback;
    if (path.startsWith('http')) return path;
    return `${API_BASE_URL}${path.startsWith('/') ? '' : '/'}${path}`;
};
