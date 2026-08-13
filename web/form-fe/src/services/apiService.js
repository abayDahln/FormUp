const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000';

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
    return {
        ok: res.ok,
        status: body.status ?? res.status,
        message: body.message ?? (res.ok ? 'OK' : 'Error'),
        data: body.data ?? null,
    };
};

// Fetch dengan timeout agar tidak menggantung saat server offline / tidak merespons.
// Error jaringan dikembalikan sebagai objek (status 0) sehingga semua pemanggil
// mendapat pesan yang jelas tanpa perlu try/catch sendiri.
const REQUEST_TIMEOUT = 15000;

const request = async (url, options = {}, timeout = REQUEST_TIMEOUT) => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
        const res = await fetch(url, { ...options, signal: controller.signal });
        return await parseResponse(res);
    } catch (err) {
        if (err?.name === 'AbortError') {
            return { ok: false, status: 0, message: 'Server tidak merespons. Cek apakah server API sudah berjalan.', data: null };
        }
        return { ok: false, status: 0, message: 'Tidak dapat terhubung ke server. Cek apakah server API sudah berjalan dan koneksi internet Anda stabil.', data: null };
    } finally {
        clearTimeout(timer);
    }
};

// ── Auth Endpoints ────────────────────────────────────────────────────────────
export const login = (email, password) => request(`${API_BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
});

export const register = (fullname, username, email, password, birthdate) => request(`${API_BASE_URL}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fullname, username, email, password, birthdate }),
});

export const verifyRegistration = (fullname, username, email, password, birthdate, otp) => request(`${API_BASE_URL}/api/auth/verify-registration`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fullname, username, email, password, birthdate, otp }),
});

export const refreshToken = () => request(`${API_BASE_URL}/api/auth/refresh`, {
    method: 'POST',
    headers: authHeaders(),
});

export const forgotPassword = (email) => request(`${API_BASE_URL}/api/auth/forgot-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email }),
});

export const resetPassword = (email, otp, newPassword) => request(`${API_BASE_URL}/api/auth/reset-password`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, otp, newPassword }),
});

// ── User Profile Endpoints ────────────────────────────────────────────────────
export const getMyProfile = () => request(`${API_BASE_URL}/api/users/me`, { headers: authHeaders() });

export const updateProfile = (payload) => request(`${API_BASE_URL}/api/users/me`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify(payload),
});

export const changePassword = (currentPassword, newPassword) => request(`${API_BASE_URL}/api/users/change-password`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ currentPassword, newPassword }),
});

export const uploadProfileImage = (file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return request(
        `${API_BASE_URL}/api/users/me/profile-image`,
        { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form },
        60000,
    );
};

export const getMyStats = () => request(`${API_BASE_URL}/api/users/me/stats`, { headers: authHeaders() });
export const getMySubmittedResponses = () => request(`${API_BASE_URL}/api/users/me/responses`, { headers: authHeaders() });

// ── Reference Endpoints ──────────────────────────────────────────────────────
export const getFormTypes = () => request(`${API_BASE_URL}/api/references/form-types`, { headers: authHeaders() });
export const getFormStatuses = () => request(`${API_BASE_URL}/api/references/form-statuses`, { headers: authHeaders() });
export const getQuestionTypes = () => request(`${API_BASE_URL}/api/references/question-types`, { headers: authHeaders() });

// ── Form Endpoints ────────────────────────────────────────────────────────────
export const getMyForms = () => request(`${API_BASE_URL}/api/forms`, { headers: authHeaders() });

export const getFormById = (id) => request(`${API_BASE_URL}/api/forms/${id}`, { headers: authHeaders() });

export const createForm = ({ title, description, descriptionFormat }) => request(`${API_BASE_URL}/api/forms`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ title, description, descriptionFormat }),
});

export const updateForm = (id, payload) => request(`${API_BASE_URL}/api/forms/${id}`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify(payload),
});

export const deleteForm = (id) => request(`${API_BASE_URL}/api/forms/${id}`, { method: 'DELETE', headers: authHeaders() });

export const togglePublishForm = (id) => request(`${API_BASE_URL}/api/forms/${id}/publish`, { method: 'POST', headers: authHeaders() });

export const updateFormSettings = (id, settings) => request(`${API_BASE_URL}/api/forms/${id}/settings`, {
    method: 'PATCH',
    headers: authHeaders(),
    body: JSON.stringify(settings),
});

export const getFormShare = (id) => request(`${API_BASE_URL}/api/forms/${id}/share`, { headers: authHeaders() });

export const uploadFormBanner = (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return request(
        `${API_BASE_URL}/api/forms/${formId}/banner`,
        { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form },
        60000,
    );
};

// ── Question Endpoints ────────────────────────────────────────────────────────
export const getQuestions = (formId) => request(`${API_BASE_URL}/api/forms/${formId}/questions`, { headers: authHeaders() });

export const saveQuestions = (formId, questions) => request(`${API_BASE_URL}/api/forms/${formId}/questions`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify({ questions }),
});

export const addQuestions = (formId, questions) => request(`${API_BASE_URL}/api/forms/${formId}/questions`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ questions }),
});

export const deleteQuestion = (formId, questionId) => request(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}`, {
    method: 'DELETE',
    headers: authHeaders(),
});

export const importQuestions = (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return request(
        `${API_BASE_URL}/api/forms/${formId}/questions/import`,
        { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form },
        60000,
    );
};

export const uploadQuestionImage = (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return request(
        `${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-image`,
        { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form },
        60000,
    );
};

export const uploadQuestionAudio = (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return request(
        `${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-audio`,
        { method: 'POST', headers: token ? { Authorization: `Bearer ${token}` } : {}, body: form },
        60000,
    );
};

// ── Response Endpoints (Owner) ────────────────────────────────────────────────
export const getFormResponses = (formId) => request(`${API_BASE_URL}/api/forms/${formId}/responses`, { headers: authHeaders() });
export const getResponseDetail = (formId, responseId) => request(`${API_BASE_URL}/api/forms/${formId}/responses/${responseId}`, { headers: authHeaders() });

export const updateResponseStatus = (responseId, statusId) => request(`${API_BASE_URL}/api/responses/${responseId}/status`, {
    method: 'PUT',
    headers: authHeaders(),
    body: JSON.stringify({ statusId }),
});

export const exportUrl = (formId) => `${API_BASE_URL}/api/forms/${formId}/responses/export`;

// ── Feedback Endpoints ────────────────────────────────────────────────────────
export const submitFeedback = (formId, { reason, description }) => request(`${API_BASE_URL}/api/forms/${formId}/feedback`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ reason, description }),
});

export const getMyFeedback = (formId) => request(`${API_BASE_URL}/api/forms/${formId}/feedback`, { headers: authHeaders() });

// ── Template Endpoints ────────────────────────────────────────────────────────
export const templateDownloadUrl = (format = 'csv') =>
    `${API_BASE_URL}/api/templates/import-questions?format=${format}`;

// ── Analytics Endpoints ───────────────────────────────────────────────────────
export const getFormAnalytics = (formId) => request(`${API_BASE_URL}/api/forms/${formId}/analytics`, { headers: authHeaders() });

// ── Public Form Flow (Responden) ──────────────────────────────────────────────

// Step 1: Get public form metadata & requirements (no questions)
export const getPublicFormByLink = (formLink) => request(`${API_BASE_URL}/api/public/forms/${formLink}`);

// Step 2: Request public questions after token/login validation
export const getPublicFormQuestions = (formLink, { token, name } = {}) => request(`${API_BASE_URL}/api/public/forms/${formLink}/questions`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ token: token || null, name: name || null }),
});

// Step 3: Submit public form responses
export const submitPublicFormResponse = (formLink, payload) => request(`${API_BASE_URL}/api/public/forms/${formLink}/responses`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(payload),
});

// Step 4: Get public response result (for respondent view)
export const getPublicResponseResult = (formLink, responseId, guestToken) => {
    const url = guestToken
        ? `${API_BASE_URL}/api/public/forms/${formLink}/responses/${responseId}?token=${encodeURIComponent(guestToken)}`
        : `${API_BASE_URL}/api/public/forms/${formLink}/responses/${responseId}`;
    return request(url, { headers: authHeaders() });
};

// ── Session Helpers ───────────────────────────────────────────────────────────
export const saveSession = (authData) => {
    localStorage.setItem('token', authData.token);
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
