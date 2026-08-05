const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

const getToken = () => localStorage.getItem('token');

const authHeaders = () => ({
    'Content-Type': 'application/json',
    Authorization: `Bearer ${getToken()}`,
});

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

// ── Auth ──────────────────────────────────────────────────────────────────────
export const login = async (email, password) => {
    const res = await fetch(`${API_BASE_URL}/api/Auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
    });
    return parseResponse(res);
};

export const register = async (fullname, username, email, password, birthdate) => {
    const res = await fetch(`${API_BASE_URL}/api/Auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullname, username, email, password, birthdate }),
    });
    return parseResponse(res);
};

export const verifyRegistration = async (fullname, username, email, password, birthdate, otp) => {
    const res = await fetch(`${API_BASE_URL}/api/Auth/verify-registration`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullname, username, email, password, birthdate, otp }),
    });
    return parseResponse(res);
};

// ── Users ─────────────────────────────────────────────────────────────────────
export const getMyProfile = async () => parseResponse(await fetch(`${API_BASE_URL}/api/Users/me`, { headers: authHeaders() }));
export const getMyStats = async () => parseResponse(await fetch(`${API_BASE_URL}/api/Users/me/stats`, { headers: authHeaders() }));
export const getMySubmittedResponses = async () => parseResponse(await fetch(`${API_BASE_URL}/api/Users/me/responses`, { headers: authHeaders() }));

// ── Forms ─────────────────────────────────────────────────────────────────────
export const getMyForms = async () => parseResponse(await fetch(`${API_BASE_URL}/api/Forms`, { headers: authHeaders() }));

export const getFormById = async (id) => parseResponse(await fetch(`${API_BASE_URL}/api/Forms/${id}`, { headers: authHeaders() }));

export const createForm = async ({ title, description, bannerImage }) => {
    const res = await fetch(`${API_BASE_URL}/api/Forms`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ title, description, bannerImage }),
    });
    return parseResponse(res);
};

export const updateForm = async (id, { title, description, bannerImage }) => {
    const res = await fetch(`${API_BASE_URL}/api/Forms/${id}`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ title, description, bannerImage }),
    });
    return parseResponse(res);
};

export const deleteForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/Forms/${id}`, { method: 'DELETE', headers: authHeaders() });
    return parseResponse(res);
};

export const togglePublishForm = async (id) => {
    const res = await fetch(`${API_BASE_URL}/api/Forms/${id}/publish`, { method: 'POST', headers: authHeaders() });
    return parseResponse(res);
};

export const updateFormSettings = async (id, settings) => {
    const res = await fetch(`${API_BASE_URL}/api/Forms/${id}/settings`, {
        method: 'PATCH',
        headers: authHeaders(),
        body: JSON.stringify(settings),
    });
    return parseResponse(res);
};

export const getFormShare = async (id) => parseResponse(await fetch(`${API_BASE_URL}/api/Forms/${id}/share`, { headers: authHeaders() }));

export const uploadFormBanner = async (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const res = await fetch(`${API_BASE_URL}/api/Forms/${formId}/banner`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${getToken()}` },
        body: form,
    });
    return parseResponse(res);
};

// ── Questions ─────────────────────────────────────────────────────────────────
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
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/import`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${getToken()}` },
        body: form,
    });
    return parseResponse(res);
};

export const uploadQuestionImage = async (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-image`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${getToken()}` },
        body: form,
    });
    return parseResponse(res);
};

export const uploadQuestionAudio = async (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const res = await fetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-audio`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${getToken()}` },
        body: form,
    });
    return parseResponse(res);
};

// ── Responses ─────────────────────────────────────────────────────────────────
export const getFormResponses = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/responses`, { headers: authHeaders() }));
export const getResponseDetail = async (formId, responseId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/responses/${responseId}`, { headers: authHeaders() }));

export const updateResponseStatus = async (responseId, statusId) => {
    const res = await fetch(`${API_BASE_URL}/api/responses/${responseId}/status`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ statusId }),
    });
    return parseResponse(res);
};

// ── Templates ────────────────────────────────────────────────────────────────
export const templateDownloadUrl = (format = 'csv') =>
    `${API_BASE_URL}/api/templates/import-questions?format=${format}`;

// ── Analytics ─────────────────────────────────────────────────────────────────
export const getFormAnalytics = async (formId) => parseResponse(await fetch(`${API_BASE_URL}/api/forms/${formId}/analytics`, { headers: authHeaders() }));

// ── Session helpers ───────────────────────────────────────────────────────────
export const saveSession = (authData) => {
    localStorage.setItem('token', authData.token);
    localStorage.setItem('user', JSON.stringify(authData.user));
};
export const clearSession = () => { localStorage.removeItem('token'); localStorage.removeItem('user'); };
export const isAuthenticated = () => !!localStorage.getItem('token');
export const getLocalUser = () => { try { return JSON.parse(localStorage.getItem('user') || '{}'); } catch { return {}; } };
export const assetUrl = (path, fallback = '') => {
    if (!path) return fallback;
    if (path.startsWith('http')) return path;
    return `${API_BASE_URL}${path}`;
};
export const exportUrl = (formId) => `${API_BASE_URL}/api/forms/${formId}/responses/export`;

// ── Public Form Runner ────────────────────────────────────────────────────────
export const getPublicFormByLink = async (formLink, token) => {
    const url = token
        ? `${API_BASE_URL}/api/public/forms/${formLink}?token=${encodeURIComponent(token)}`
        : `${API_BASE_URL}/api/public/forms/${formLink}`;
    const res = await fetch(url);
    return parseResponse(res);
};

export const submitPublicFormResponse = async (formLink, payload) => {
    const headers = { 'Content-Type': 'application/json' };
    const token = getToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const res = await fetch(`${API_BASE_URL}/api/public/forms/${formLink}/responses`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
    });
    return parseResponse(res);
};
