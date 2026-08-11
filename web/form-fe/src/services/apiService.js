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

// ── Resilient Client Fetch Wrapper (Timeout 6s + Retry 1x + Auto Refresh 401) ──

let isRefreshing = false;
let failedQueue = [];

const processQueue = (error, newToken = null) => {
    failedQueue.forEach(prom => {
        if (error) prom.reject(error);
        else prom.resolve(newToken);
    });
    failedQueue = [];
};

/**
 * Robust fetch wrapper with:
 * 1. Timeout (default 6000ms / 6s)
 * 2. Retry 1x on timeout or network error
 * 3. Auto-refresh token on 401 Unauthorized status
 */
const apiFetch = async (url, options = {}, isRetry = false) => {
    const timeoutMs = options.timeout ?? 6000;
    const fetchOptions = { ...options };
    delete fetchOptions.timeout;

    const executeFetch = async (opts) => {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMs);
        try {
            const response = await fetch(url, { ...opts, signal: controller.signal });
            clearTimeout(timer);
            return response;
        } catch (err) {
            clearTimeout(timer);
            throw err;
        }
    };

    let response;
    try {
        response = await executeFetch(fetchOptions);
    } catch (err) {
        // Retry 1x on timeout or network failure
        if (!isRetry) {
            try {
                response = await executeFetch(fetchOptions);
            } catch (retryErr) {
                return {
                    ok: false,
                    status: 504,
                    message: retryErr.name === 'AbortError' ? 'Koneksi lambat / Timeout (6 detik)' : 'Gagal terhubung ke server',
                    data: null,
                };
            }
        } else {
            return {
                ok: false,
                status: 504,
                message: err.name === 'AbortError' ? 'Koneksi lambat / Timeout (6 detik)' : 'Gagal terhubung ke server',
                data: null,
            };
        }
    }

    // Auto-refresh Token on 401 Unauthorized
    if (response.status === 401 && !url.includes('/api/auth/login') && !url.includes('/api/auth/refresh') && !isRetry) {
        if (isRefreshing) {
            return new Promise((resolve, reject) => {
                failedQueue.push({ resolve, reject });
            }).then(newToken => {
                const newHeaders = { ...(fetchOptions.headers || {}) };
                if (newToken) newHeaders['Authorization'] = `Bearer ${newToken}`;
                return apiFetch(url, { ...fetchOptions, headers: newHeaders }, true);
            }).catch(() => parseResponse(response));
        }

        isRefreshing = true;

        try {
            const refreshRes = await refreshToken();
            if (refreshRes.ok && refreshRes.data?.token) {
                const newToken = refreshRes.data.token;
                saveSession({ token: newToken, user: getLocalUser() });
                processQueue(null, newToken);

                const updatedHeaders = { ...(fetchOptions.headers || {}) };
                updatedHeaders['Authorization'] = `Bearer ${newToken}`;
                isRefreshing = false;
                return apiFetch(url, { ...fetchOptions, headers: updatedHeaders }, true);
            } else {
                processQueue(new Error('Token refresh failed'), null);
                isRefreshing = false;
                clearSession();
                if (!window.location.pathname.includes('/login') && !window.location.pathname.startsWith('/f/')) {
                    window.location.href = '/login';
                }
            }
        } catch (e) {
            processQueue(e, null);
            isRefreshing = false;
            clearSession();
        }
    }

    return parseResponse(response);
};

// ── Auth Endpoints ────────────────────────────────────────────────────────────
export const login = async (email, password) => {
    return apiFetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
    });
};

export const register = async (fullname, username, email, password, birthdate) => {
    return apiFetch(`${API_BASE_URL}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullname, username, email, password, birthdate }),
    });
};

export const verifyRegistration = async (fullname, username, email, password, birthdate, otp) => {
    return apiFetch(`${API_BASE_URL}/api/auth/verify-registration`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullname, username, email, password, birthdate, otp }),
    });
};

export const refreshToken = async () => {
    return apiFetch(`${API_BASE_URL}/api/auth/refresh`, {
        method: 'POST',
        headers: authHeaders(),
    });
};

export const forgotPassword = async (email) => {
    return apiFetch(`${API_BASE_URL}/api/auth/forgot-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
    });
};

export const resetPassword = async (email, otp, newPassword) => {
    return apiFetch(`${API_BASE_URL}/api/auth/reset-password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, otp, newPassword }),
    });
};

// ── User Profile Endpoints ────────────────────────────────────────────────────
export const getMyProfile = async () => apiFetch(`${API_BASE_URL}/api/users/me`, { headers: authHeaders() });

export const updateProfile = async (payload) => {
    return apiFetch(`${API_BASE_URL}/api/users/me`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify(payload),
    });
};

export const changePassword = async (currentPassword, newPassword) => {
    return apiFetch(`${API_BASE_URL}/api/users/change-password`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ currentPassword, newPassword }),
    });
};

export const uploadProfileImage = async (file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return apiFetch(`${API_BASE_URL}/api/users/me/profile-image`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
};

export const getMyStats = async () => apiFetch(`${API_BASE_URL}/api/users/me/stats`, { headers: authHeaders() });
export const getMySubmittedResponses = async () => apiFetch(`${API_BASE_URL}/api/users/me/responses`, { headers: authHeaders() });

// ── Reference Endpoints ──────────────────────────────────────────────────────
export const getFormTypes = async () => apiFetch(`${API_BASE_URL}/api/references/form-types`, { headers: authHeaders() });
export const getFormStatuses = async () => apiFetch(`${API_BASE_URL}/api/references/form-statuses`, { headers: authHeaders() });
export const getQuestionTypes = async () => apiFetch(`${API_BASE_URL}/api/references/question-types`, { headers: authHeaders() });

// ── Form Endpoints ────────────────────────────────────────────────────────────
export const getMyForms = async () => apiFetch(`${API_BASE_URL}/api/forms`, { headers: authHeaders() });
export const getFormById = async (id) => apiFetch(`${API_BASE_URL}/api/forms/${id}`, { headers: authHeaders() });

export const createForm = async ({ title, description, descriptionFormat }) => {
    return apiFetch(`${API_BASE_URL}/api/forms`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ title, description, descriptionFormat }),
    });
};

export const updateForm = async (id, payload) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${id}`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify(payload),
    });
};

export const deleteForm = async (id) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${id}`, { method: 'DELETE', headers: authHeaders() });
};

export const togglePublishForm = async (id) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${id}/publish`, { method: 'POST', headers: authHeaders() });
};

export const updateFormSettings = async (id, settings) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${id}/settings`, {
        method: 'PATCH',
        headers: authHeaders(),
        body: JSON.stringify(settings),
    });
};

export const getFormShare = async (id) => apiFetch(`${API_BASE_URL}/api/forms/${id}/share`, { headers: authHeaders() });

export const uploadFormBanner = async (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/banner`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
};

// ── Question Endpoints ────────────────────────────────────────────────────────
export const getQuestions = async (formId) => apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions`, { headers: authHeaders() });

export const saveQuestions = async (formId, questions) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ questions }),
    });
};

export const addQuestions = async (formId, questions) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ questions }),
    });
};

export const deleteQuestion = async (formId, questionId) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}`, {
        method: 'DELETE',
        headers: authHeaders(),
    });
};

export const importQuestions = async (formId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions/import`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
};

export const uploadQuestionImage = async (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-image`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
};

export const uploadQuestionAudio = async (formId, questionId, file) => {
    const form = new FormData();
    form.append('file', file);
    const token = getToken();
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/questions/${questionId}/upload-audio`, {
        method: 'POST',
        headers: token ? { Authorization: `Bearer ${token}` } : {},
        body: form,
    });
};

// ── Response Endpoints (Owner) ────────────────────────────────────────────────
export const getFormResponses = async (formId, page = null, pageSize = null) => {
    let url = `${API_BASE_URL}/api/forms/${formId}/responses`;
    if (page !== null && pageSize !== null) {
        url += `?page=${page}&pageSize=${pageSize}`;
    }
    return apiFetch(url, { headers: authHeaders() });
};

export const getResponseDetail = async (formId, responseId) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/responses/${responseId}`, { headers: authHeaders() });
};

export const updateResponseStatus = async (responseId, statusId) => {
    return apiFetch(`${API_BASE_URL}/api/responses/${responseId}/status`, {
        method: 'PUT',
        headers: authHeaders(),
        body: JSON.stringify({ statusId }),
    });
};

export const exportUrl = (formId) => `${API_BASE_URL}/api/forms/${formId}/responses/export`;

// ── Feedback Endpoints ────────────────────────────────────────────────────────
export const submitFeedback = async (formId, { reason, description }) => {
    return apiFetch(`${API_BASE_URL}/api/forms/${formId}/feedback`, {
        method: 'POST',
        headers: authHeaders(),
        body: JSON.stringify({ reason, description }),
    });
};

export const getMyFeedback = async (formId) => apiFetch(`${API_BASE_URL}/api/forms/${formId}/feedback`, { headers: authHeaders() });

// ── Template Endpoints ────────────────────────────────────────────────────────
export const templateDownloadUrl = (format = 'csv') =>
    `${API_BASE_URL}/api/templates/import-questions?format=${format}`;

// ── Analytics Endpoints ───────────────────────────────────────────────────────
export const getFormAnalytics = async (formId, page = null, pageSize = null) => {
    let url = `${API_BASE_URL}/api/forms/${formId}/analytics`;
    if (page !== null && pageSize !== null) {
        url += `?page=${page}&pageSize=${pageSize}`;
    }
    return apiFetch(url, { headers: authHeaders() });
};

// ── Public Form Flow (Responden) ──────────────────────────────────────────────

// Step 1: Get public form metadata & requirements (no questions)
export const getPublicFormByLink = async (formLink) => {
    return apiFetch(`${API_BASE_URL}/api/public/forms/${formLink}`);
};

// Step 2: Request public questions after token/login validation
export const getPublicFormQuestions = async (formLink, { token, name } = {}) => {
    const headers = authHeaders();
    return apiFetch(`${API_BASE_URL}/api/public/forms/${formLink}/questions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ token: token || null, name: name || null }),
    });
};

// Step 3: Submit public form responses
export const submitPublicFormResponse = async (formLink, payload) => {
    const headers = authHeaders();
    return apiFetch(`${API_BASE_URL}/api/public/forms/${formLink}/responses`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
    });
};

// Step 4: Get public response result (for respondent view)
export const getPublicResponseResult = async (formLink, responseId, guestToken) => {
    const headers = authHeaders();
    const url = guestToken
        ? `${API_BASE_URL}/api/public/forms/${formLink}/responses/${responseId}?token=${encodeURIComponent(guestToken)}`
        : `${API_BASE_URL}/api/public/forms/${formLink}/responses/${responseId}`;
    return apiFetch(url, { headers });
};

// ── Admin Endpoints ───────────────────────────────────────────────────────────
export const adminGetUsers = async (page = null, pageSize = null) => {
    let url = `${API_BASE_URL}/api/admin/users`;
    if (page !== null && pageSize !== null) url += `?page=${page}&pageSize=${pageSize}`;
    return apiFetch(url, { headers: authHeaders() });
};

export const adminGetUserDetail = async (userId) => apiFetch(`${API_BASE_URL}/api/admin/users/${userId}`, { headers: authHeaders() });

export const adminBanUser = async (userId) => apiFetch(`${API_BASE_URL}/api/admin/users/${userId}/ban`, { method: 'PUT', headers: authHeaders() });

export const adminActivateUser = async (userId) => apiFetch(`${API_BASE_URL}/api/admin/users/${userId}/activate`, { method: 'PUT', headers: authHeaders() });

export const adminDeleteUser = async (userId) => apiFetch(`${API_BASE_URL}/api/admin/users/${userId}`, { method: 'DELETE', headers: authHeaders() });

export const adminGetForms = async (page = null, pageSize = null) => {
    let url = `${API_BASE_URL}/api/admin/forms`;
    if (page !== null && pageSize !== null) url += `?page=${page}&pageSize=${pageSize}`;
    return apiFetch(url, { headers: authHeaders() });
};

export const adminGetFormDetail = async (formId) => apiFetch(`${API_BASE_URL}/api/admin/forms/${formId}`, { headers: authHeaders() });

export const adminTakedownForm = async (formId) => apiFetch(`${API_BASE_URL}/api/admin/forms/${formId}/takedown`, { method: 'POST', headers: authHeaders() });

export const adminRestoreForm = async (formId) => apiFetch(`${API_BASE_URL}/api/admin/forms/${formId}/restore`, { method: 'POST', headers: authHeaders() });

export const adminDeleteForm = async (formId) => apiFetch(`${API_BASE_URL}/api/admin/forms/${formId}`, { method: 'DELETE', headers: authHeaders() });

export const adminGetFeedback = async (page = null, pageSize = null) => {
    let url = `${API_BASE_URL}/api/admin/feedback`;
    if (page !== null && pageSize !== null) url += `?page=${page}&pageSize=${pageSize}`;
    return apiFetch(url, { headers: authHeaders() });
};

export const adminDeleteFeedback = async (feedbackId) => apiFetch(`${API_BASE_URL}/api/admin/feedback/${feedbackId}`, { method: 'DELETE', headers: authHeaders() });

export const adminTakedownFormFromFeedback = async (feedbackId) => apiFetch(`${API_BASE_URL}/api/admin/feedback/${feedbackId}/takedown`, { method: 'POST', headers: authHeaders() });

export const adminRestoreFormFromFeedback = async (feedbackId) => apiFetch(`${API_BASE_URL}/api/admin/feedback/${feedbackId}/restore`, { method: 'POST', headers: authHeaders() });

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
