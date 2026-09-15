/**
 * AI Service for Generating Quiz & Form Questions using Google Gemini API
 * Model list matches Google AI Studio free tier models.
 */

export const AVAILABLE_MODELS = [
    { 
        id: 'gemini-3.6-flash',
        name: 'Gemini 3.6 Flash',
        desc: 'Paling Cepat & Akurat (Rekomendasi)', 
        badge: 'Rekomendasi' 
    },
    { 
        id: 'gemini-3.6-flash-lite',
        name: 'Gemini 3.6 Flash Lite',
        desc: 'Hemat Kuota (Limit 10 RPM) & Responsif', 
        badge: 'Hemat Kuota' 
    },
];

export const DEFAULT_AI_MODEL = 'gemini-3.6-flash';
export const normalizeAiModel = (model) => {
    if (!model || model.includes('-pro') || model === 'gemini-3-flash-preview' || !AVAILABLE_MODELS.some(item => item.id === model)) return DEFAULT_AI_MODEL;
    return model;
};

/**
 * API Key Stacking (Multi-Key with Auto-Failover)
 */
export const getGeminiApiKeys = () => {
    if (typeof window !== 'undefined') {
        try {
            const raw = localStorage.getItem('formup_gemini_api_keys');
            if (raw) {
                const parsed = JSON.parse(raw);
                if (Array.isArray(parsed) && parsed.length > 0) {
                    return parsed.map(k => String(k).trim()).filter(Boolean);
                }
            }
        } catch {}
        const legacy = localStorage.getItem('formup_gemini_api_key');
        if (legacy && legacy.trim()) {
            return [legacy.trim()];
        }
    }
    return [];
};

export const saveGeminiApiKeys = (keysInput) => {
    if (typeof window !== 'undefined') {
        let cleanKeys = [];
        if (Array.isArray(keysInput)) {
            cleanKeys = keysInput.map(k => String(k).trim()).filter(Boolean);
        } else if (typeof keysInput === 'string') {
            cleanKeys = keysInput
                .split(/[\n,;]+/)
                .map(k => k.trim())
                .filter(Boolean);
        }
        // Deduplicate while preserving order
        cleanKeys = Array.from(new Set(cleanKeys));

        if (cleanKeys.length === 0) {
            localStorage.removeItem('formup_gemini_api_keys');
            localStorage.removeItem('formup_gemini_api_key');
            localStorage.removeItem('formup_gemini_active_key_idx');
        } else {
            localStorage.setItem('formup_gemini_api_keys', JSON.stringify(cleanKeys));
            localStorage.setItem('formup_gemini_api_key', cleanKeys[0]);
            const curIdx = parseInt(localStorage.getItem('formup_gemini_active_key_idx') || '0', 10);
            if (curIdx >= cleanKeys.length) {
                localStorage.setItem('formup_gemini_active_key_idx', '0');
            }
        }
        return cleanKeys;
    }
    return [];
};

export const getActiveApiKeyIndex = () => {
    if (typeof window !== 'undefined') {
        const idx = parseInt(localStorage.getItem('formup_gemini_active_key_idx') || '0', 10);
        const keys = getGeminiApiKeys();
        if (idx >= 0 && idx < keys.length) return idx;
    }
    return 0;
};

export const rotateToNextApiKey = () => {
    if (typeof window !== 'undefined') {
        const keys = getGeminiApiKeys();
        if (keys.length <= 1) return { index: 0, key: keys[0] || '', total: keys.length, rotated: false };
        const curIdx = getActiveApiKeyIndex();
        const nextIdx = (curIdx + 1) % keys.length;
        localStorage.setItem('formup_gemini_active_key_idx', String(nextIdx));
        localStorage.setItem('formup_gemini_api_key', keys[nextIdx]);
        return { index: nextIdx, key: keys[nextIdx], total: keys.length, rotated: true };
    }
    return { index: 0, key: '', total: 0, rotated: false };
};

export const getGeminiApiKey = () => {
    const keys = getGeminiApiKeys();
    if (keys.length === 0) return '';
    const idx = getActiveApiKeyIndex();
    return keys[idx] || keys[0] || '';
};

export const saveGeminiApiKey = (key) => {
    if (!key || !key.trim()) {
        saveGeminiApiKeys([]);
    } else {
        const existing = getGeminiApiKeys();
        if (!existing.includes(key.trim())) {
            saveGeminiApiKeys([key.trim(), ...existing]);
        }
    }
};

export const removeGeminiApiKey = () => {
    saveGeminiApiKeys([]);
};

/**
 * Execute Gemini API request with automatic multi-key failover rotation.
 */
export const executeWithApiKeyFailover = async (requestFn, customApiKey = null) => {
    if (customApiKey && customApiKey.trim()) {
        return await requestFn(customApiKey.trim(), 0, 1);
    }

    const keys = getGeminiApiKeys();
    if (keys.length === 0) {
        return { ok: false, message: 'API Key Gemini belum diatur. Masukkan API Key dari Google AI Studio.' };
    }

    let startIdx = getActiveApiKeyIndex();
    let attempts = 0;
    const maxAttempts = keys.length;

    while (attempts < maxAttempts) {
        const currentIdx = (startIdx + attempts) % keys.length;
        const currentKey = keys[currentIdx];

        try {
            const result = await requestFn(currentKey, currentIdx, keys.length);
            
            // Check if result returned an HTTP rate-limit or key error
            if (result && result.status && (result.status === 429 || result.status === 400 || result.status === 403)) {
                if (keys.length > 1 && attempts + 1 < maxAttempts) {
                    console.warn(`[API Key Stacking]: Key #${currentIdx + 1} hit error (${result.status}). Auto-failing over to next key...`);
                    rotateToNextApiKey();
                    attempts++;
                    continue;
                }
            }

            // If response is successful, ensure active index matches working key
            if (result && result.ok) {
                if (getActiveApiKeyIndex() !== currentIdx) {
                    localStorage.setItem('formup_gemini_active_key_idx', String(currentIdx));
                    localStorage.setItem('formup_gemini_api_key', currentKey);
                }
            }

            return result;
        } catch (err) {
            const isRateLimitOrAuth = err?.message && (
                err.message.includes('429') ||
                err.message.includes('RESOURCE_EXHAUSTED') ||
                err.message.includes('API_KEY_INVALID') ||
                err.message.includes('403') ||
                err.message.includes('quota')
            );

            if (isRateLimitOrAuth && keys.length > 1 && attempts + 1 < maxAttempts) {
                console.warn(`[API Key Stacking]: Exception on Key #${currentIdx + 1}. Auto-rotating to next key...`, err);
                rotateToNextApiKey();
                attempts++;
                continue;
            }
            throw err;
        }
    }

    return {
        ok: false,
        message: `Seluruh ${keys.length} API Key telah mencapai batas kuota (Rate Limit 429) atau tidak valid. Silakan tambahkan key baru atau coba lagi nanti.`
    };
};

// B2: Guardrail instruction injected into every AI prompt
const AI_GUARDRAIL = `PERAN & BATASAN KERAS: Anda adalah asisten KHUSUS pembuatan soal ujian dan kuis untuk aplikasi pendidikan FormUp. Anda HANYA boleh membantu hal-hal yang berkaitan dengan:
- Membuat, merevisi, atau mengevaluasi soal ujian/kuis/latihan
- Materi pelajaran, topik akademik, dan konten edukasi
- Format soal (pilihan ganda, essay, benar/salah, checkbox, dll.)

Jika diminta hal di luar ini (kode untuk tujuan lain, konten tidak pantas, topik non-edukasi, percakapan umum yang tidak relevan), TOLAK dengan pesan sopan: "Maaf, saya hanya dapat membantu membuat soal ujian dan kuis untuk keperluan pendidikan."

`;

// Helper to parse JSON with unescaped LaTeX backslashes repair
export const safeJsonParse = (rawStr) => {
    if (!rawStr) return null;
    let cleaned = rawStr.trim()
        .replace(/^```json\s*/i, '')
        .replace(/\s*```$/i, '')
        .replace(/^```\s*/i, '')
        .trim();

    try {
        return JSON.parse(cleaned);
    } catch (e1) {
        try {
            // Repair unescaped backslashes that are not valid JSON escape chars (\", \\, /, \b, \f, \n, \r, \t, \uXXXX)
            const repaired = cleaned.replace(/\\([^"\\/bfnrtu]|u(?![\da-fA-F]{4}))/g, '\\\\$1');
            return JSON.parse(repaired);
        } catch {
            const jsonMatch = cleaned.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
            if (jsonMatch) {
                const repaired = jsonMatch[0].replace(/\\([^"\\/bfnrtu]|u(?![\da-fA-F]{4}))/g, '\\\\$1');
                return JSON.parse(repaired);
            }
            throw e1;
        }
    }
};

/**
 * Generate structured quiz questions using Google Gemini API
 */
export const generateQuestionsWithAI = async ({
    topic,
    contextText = '',
    count = 5,
    typePreference = '2',
    difficulty = 'Sedang',
    includeMath = false,
    includeCode = false,
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
    onStatus = null, // Callback: (statusText) => void
}) => {
    const setStatus = (msg) => {
        if (typeof onStatus === 'function') onStatus(msg);
    };

    setStatus(`Mempersiapkan pembuatan ${count} butir soal materi "${topic}"...`);

    const typeDescription = {
        '1': 'Semua soal bertipe Essay / Isian Singkat (typeId: 1, sertakan kunci/contoh jawaban di correctAnswer).',
        '2': 'Semua soal bertipe Pilihan Ganda (typeId: 2, sediakan 4 pilihan jawaban di options di mana tepat SATU bernilai isCorrect: true).',
        '3': 'Semua soal bertipe Checkbox / Pilihan Majemuk (typeId: 3, sediakan 4-5 opsi di mana ada minimal 2 bernilai isCorrect: true).',
        '5': 'Semua soal bertipe Benar / Salah (typeId: 5, correctAnswer diisi "Benar" atau "Salah").',
        'mixed': 'Variasi campuran antara Pilihan Ganda (typeId: 2), Benar/Salah (typeId: 5), dan Essay (typeId: 1).',
    }[typePreference] || 'Pilihan Ganda (typeId: 2)';

    let extraInstructions = [];
    if (includeMath) {
        extraInstructions.push('Gunakan rumus matematika/fisika dalam format LaTeX $...$ untuk inline atau $$...$$ untuk tampilan terpisah jika relevan.');
    }
    if (includeCode) {
        extraInstructions.push('Untuk potongan kode, tulis dalam format ```bahasa\\nkode\\n``` di baris terpisah.');
    }
    if (contextText && contextText.trim()) {
        extraInstructions.push(`Gunakan materi referensi berikut sebagai acuan utama:\n"""\n${contextText.trim()}\n"""`);
    }

    // B2: Guardrail prepended to prompt
    const promptText = `${AI_GUARDRAIL}Buatlah ${count} butir soal berkualitas tinggi dengan panduan berikut:

- **Materi / Topik:** ${topic || 'Pengetahuan Umum'}
- **Tingkat Kesulitan:** ${difficulty}
- **Bentuk Soal:** ${typeDescription}
- **Bahasa:** Gunakan bahasa yang SAMA dengan bahasa topik/materi di atas untuk SELURUH output — termasuk teks pertanyaan, SEMUA opsi jawaban, dan kunci jawaban (correctAnswer). Jangan mencampur bahasa.
${extraInstructions.length > 0 ? `- **Panduan Tambahan:**\n  ${extraInstructions.join('\n  ')}` : ''}

**FORMAT KELUARAN WAJIB (JSON ARRAY):**
Kembalikan HANYA array JSON valid tanpa teks atau penjelasan pembuka/penutup. Struktur objek per soal:
[
  {
    "question": "Teks pertanyaan lengkap",
    "typeId": 2, // 1 = Essay, 2 = Pilihan Ganda, 3 = Checkbox, 5 = Benar/Salah
    "isRequired": true,
    "isScorable": true,
    "correctAnswer": "Kunci jawaban untuk tipe 1 atau 'Benar'/'Salah' untuk tipe 5",
    "options": [
      { "optionText": "Pilihan A", "isCorrect": false },
      { "optionText": "Pilihan B", "isCorrect": true },
      { "optionText": "Pilihan C", "isCorrect": false },
      { "optionText": "Pilihan D", "isCorrect": false }
    ]
  }
]
Catatan Penting:
- Jangan mengisi bobot poin (biarkan default).
- Untuk tipe 2 (Pilihan Ganda), pastikan tepat ada 1 opsi yang isCorrect: true.
- Untuk tipe 1 dan 5, options boleh berupa array kosong [].
`.trim();

    return await executeWithApiKeyFailover(async (apiKey) => {
        try {
            const targetModel = normalizeAiModel(selectedModel);
            setStatus(`Menghubungkan ke ${targetModel} di Google AI Studio...`);

            const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
            
            const startTime = Date.now();
            setStatus(`AI (${targetModel}) sedang berpikir & menyusun butir soal...`);

            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 60000);
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                signal: controller.signal,
                body: JSON.stringify({
                    contents: [{ parts: [{ text: promptText }] }],
                    generationConfig: {
                        responseMimeType: 'application/json',
                        temperature: 0.7,
                    },
                }),
            });
            clearTimeout(timeoutId);

            const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);

            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                const errMsg = errData.error?.message || `HTTP ${response.status} ${response.statusText}`;

                if (response.status === 429) {
                    return {
                        ok: false,
                        status: 429,
                        message: `Batas penggunaan / rate limit Google AI Studio untuk model ${targetModel} telah tercapai.`,
                    };
                }

                if (response.status === 400 || response.status === 403) {
                    return {
                        ok: false,
                        status: response.status,
                        message: `API Key Google AI Studio tidak valid atau izin akses ditolak. (${errMsg})`,
                    };
                }

                if (response.status >= 500) {
                    return {
                        ok: false,
                        status: response.status,
                        message: `Server AI Studio sedang tidak tersedia (Error ${response.status}). Coba beberapa menit lagi atau gunakan Gemini 3.6 Flash Lite.`,
                    };
                }

                return {
                    ok: false,
                    status: response.status,
                    message: `Gagal memanggil model ${targetModel}: ${errMsg}.`,
                };
            }

            setStatus(`Menerima hasil dari AI (${elapsedSec} detik). Memeriksa struktur soal...`);

            const data = await response.json();
            const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text;

            if (!textResponse) {
                return {
                    ok: false,
                    message: 'AI tidak mengembalikan teks soal. Silakan coba klik Generate sekali lagi.',
                };
            }

            let parsedQuestions;
            try {
                parsedQuestions = safeJsonParse(textResponse);
            } catch {
                return { ok: false, message: 'AI mengembalikan format yang tidak valid. Coba klik Generate sekali lagi.' };
            }

            if (!Array.isArray(parsedQuestions) || parsedQuestions.length === 0) {
                return {
                    ok: false,
                    message: 'Format data dari AI tidak valid. Silakan coba klik Generate lagi.',
                };
            }

            // Normalize questions to match FormBuilder structure
            const normalized = parsedQuestions.map((q, idx) => {
                const typeId = parseInt(q.typeId, 10) || 2;
                let options = Array.isArray(q.options) ? q.options : [];

                if ([2, 3].includes(typeId) && options.length === 0) {
                    options = [
                        { optionText: 'Pilihan A', isCorrect: true },
                        { optionText: 'Pilihan B', isCorrect: false },
                        { optionText: 'Pilihan C', isCorrect: false },
                        { optionText: 'Pilihan D', isCorrect: false },
                    ];
                }

                const formattedOptions = options.map((opt, oIdx) => ({
                    optionText: String(opt.optionText || opt.text || `Pilihan ${String.fromCharCode(65 + oIdx)}`),
                    isCorrect: Boolean(opt.isCorrect),
                }));

                return {
                    _id: `q_ai_${Date.now()}_${idx}`,
                    id: null,
                    question: String(q.question || `Pertanyaan ${idx + 1}`),
                    typeId: typeId,
                    isRequired: q.isRequired !== undefined ? Boolean(q.isRequired) : true,
                    isScorable: q.isScorable !== undefined ? Boolean(q.isScorable) : true,
                    points: null,
                    correctAnswer: q.correctAnswer ? String(q.correctAnswer) : '',
                    options: formattedOptions,
                    questionImage: null,
                    questionAudio: null,
                };
            });

            setStatus(`Selesai! ${normalized.length} butir soal siap.`);

            return {
                ok: true,
                data: normalized,
                modelUsed: targetModel,
                elapsedSec,
            };
        } catch (err) {
            if (err && err.name === 'AbortError') {
                return { ok: false, message: 'Koneksi ke AI Studio timeout. Periksa koneksi internet Anda lalu coba lagi.' };
            }
            if (err && err.name === 'TypeError' && err.message && (err.message.includes('fetch') || err.message.includes('network') || err.message.includes('Failed') || err.message.includes('NetworkError'))) {
                return { ok: false, message: 'Tidak dapat terhubung ke AI Studio. Periksa koneksi internet Anda.' };
            }
            if (err instanceof SyntaxError) {
                return { ok: false, message: 'AI mengembalikan format yang tidak valid. Coba klik Generate sekali lagi.' };
            }
            return {
                ok: false,
                message: `Terjadi kendala saat memproses AI: ${err?.message || 'Unknown error'}. Coba lagi atau gunakan model lain.`,
            };
        }
    }, customApiKey);
};

/**
 * B9: Stream quiz questions from Gemini API — questions appear one-by-one as generated.
 * @param {object} params - Same generation params as generateQuestionsWithAI
 * @param {function} onQuestion - Called with each complete normalized question object
 * @param {function} onStatus - Called with status text updates
 * @param {function} onDone - Called on completion: { ok, totalCount, modelUsed, elapsedSec } or { ok: false, message }
 */
export const streamGenerateQuestionsWithAI = async ({
    topic,
    contextText = '',
    count = 5,
    typePreference = '2',
    difficulty = 'Sedang',
    includeMath = false,
    includeCode = false,
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
}, onQuestion, onStatus, onDone) => {
    const apiKey = (customApiKey || getGeminiApiKey()).trim();
    const setStatus = (msg) => { if (typeof onStatus === 'function') onStatus(msg); };

    if (!apiKey) {
        onDone({ ok: false, message: 'API Key Gemini belum diatur.' });
        return;
    }

    const typeDescription = {
        '1': 'Semua soal bertipe Essay / Isian Singkat (typeId: 1, sertakan kunci/contoh jawaban di correctAnswer).',
        '2': 'Semua soal bertipe Pilihan Ganda (typeId: 2, sediakan 4 pilihan jawaban di options di mana tepat SATU bernilai isCorrect: true).',
        '3': 'Semua soal bertipe Checkbox / Pilihan Majemuk (typeId: 3, sediakan 4-5 opsi di mana ada minimal 2 bernilai isCorrect: true).',
        '5': 'Semua soal bertipe Benar / Salah (typeId: 5, correctAnswer diisi "Benar" atau "Salah").',
        'mixed': 'Variasi campuran antara Pilihan Ganda (typeId: 2), Benar/Salah (typeId: 5), dan Essay (typeId: 1).',
    }[typePreference] || 'Pilihan Ganda (typeId: 2)';

    let extraInstructions = [];
    if (includeMath) extraInstructions.push('Gunakan rumus matematika/fisika dalam format LaTeX $...$ untuk inline atau $$...$$ untuk tampilan terpisah jika relevan.');
    if (includeCode) extraInstructions.push('Untuk potongan kode, tulis dalam format ```bahasa\\nkode\\n``` di baris terpisah.');
    if (contextText && contextText.trim()) extraInstructions.push(`Gunakan materi referensi berikut sebagai acuan utama:\n"""\n${contextText.trim()}\n"""`);

    const promptText = `${AI_GUARDRAIL}Buatlah ${count} butir soal berkualitas tinggi dengan panduan berikut:
- **Materi / Topik:** ${topic || 'Pengetahuan Umum'}
- **Tingkat Kesulitan:** ${difficulty}
- **Bentuk Soal:** ${typeDescription}
- **Bahasa:** Gunakan bahasa yang SAMA dengan bahasa topik/materi di atas untuk SELURUH output.
${extraInstructions.length > 0 ? `- **Panduan Tambahan:**\n  ${extraInstructions.join('\n  ')}` : ''}

**FORMAT KELUARAN WAJIB (JSON ARRAY):**
Kembalikan HANYA array JSON valid tanpa teks atau penjelasan pembuka/penutup.
[
  {
    "question": "Teks pertanyaan lengkap",
    "typeId": 2,
    "isRequired": true,
    "isScorable": true,
    "correctAnswer": "Kunci jawaban",
    "options": [
      { "optionText": "Pilihan A", "isCorrect": false },
      { "optionText": "Pilihan B", "isCorrect": true },
      { "optionText": "Pilihan C", "isCorrect": false },
      { "optionText": "Pilihan D", "isCorrect": false }
    ]
  }
]`.trim();

            const targetModel = normalizeAiModel(selectedModel);
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:streamGenerateContent?key=${apiKey}&alt=sse`;
    const startTime = Date.now();
    setStatus(`AI (${targetModel}) sedang menyusun soal...`);

    try {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 60000);
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            signal: controller.signal,
            body: JSON.stringify({
                contents: [{ parts: [{ text: promptText }] }],
                generationConfig: { temperature: 0.7 },
            }),
        });
        clearTimeout(timeoutId);

        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${response.status}`;
            if (response.status === 429) { onDone({ ok: false, message: `Rate limit tercapai untuk model ${targetModel}. Coba model lain atau tunggu sebentar.` }); }
            else if (response.status === 400 || response.status === 403) { onDone({ ok: false, message: `API Key tidak valid atau akses ditolak. (${errMsg})` }); }
            else if (response.status >= 500) { onDone({ ok: false, message: `Server AI Studio tidak tersedia (Error ${response.status}). Coba lagi nanti.` }); }
            else { onDone({ ok: false, message: `Gagal memanggil AI: ${errMsg}` }); }
            return;
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let sseBuffer = '';
        let jsonBuffer = '';
        let questionCount = 0;
        let arrayStarted = false;

        const tryParseQuestion = () => {
            let d = 0, inStr = false, esc = false, objectStart = -1;
            for (let i = 0; i < jsonBuffer.length; i++) {
                const ch = jsonBuffer[i];
                if (esc) { esc = false; continue; }
                if (ch === '\\' && inStr) { esc = true; continue; }
                if (ch === '"') { inStr = !inStr; continue; }
                if (inStr) continue;
                if (ch === '{') { if (d === 0) objectStart = i; d++; }
                else if (ch === '}') {
                    d--;
                    if (d === 0 && objectStart !== -1) {
                        const objStr = jsonBuffer.slice(objectStart, i + 1);
                        jsonBuffer = jsonBuffer.slice(i + 1).replace(/^[,\s]+/, '');
                        try {
                            const q = JSON.parse(objStr);
                            const typeId = parseInt(q.typeId, 10) || 2;
                            let options = Array.isArray(q.options) ? q.options : [];
                            if ([2, 3].includes(typeId) && options.length === 0) {
                                options = [
                                    { optionText: 'Pilihan A', isCorrect: true },
                                    { optionText: 'Pilihan B', isCorrect: false },
                                    { optionText: 'Pilihan C', isCorrect: false },
                                    { optionText: 'Pilihan D', isCorrect: false },
                                ];
                            }
                            const normalized = {
                                _id: `q_ai_stream_${Date.now()}_${questionCount}`,
                                id: null,
                                question: String(q.question || `Pertanyaan ${questionCount + 1}`),
                                typeId,
                                isRequired: q.isRequired !== undefined ? Boolean(q.isRequired) : true,
                                isScorable: q.isScorable !== undefined ? Boolean(q.isScorable) : true,
                                points: null,
                                correctAnswer: q.correctAnswer ? String(q.correctAnswer) : '',
                                options: options.map((opt, oIdx) => ({
                                    optionText: String(opt.optionText || opt.text || `Pilihan ${String.fromCharCode(65 + oIdx)}`),
                                    isCorrect: Boolean(opt.isCorrect),
                                })),
                                questionImage: null,
                                questionAudio: null,
                            };
                            questionCount++;
                            if (typeof onQuestion === 'function') onQuestion(normalized);
                            setStatus(`Menerima soal ${questionCount}/${count}...`);
                            return true;
                        } catch { /* partial, skip */ }
                        break;
                    }
                }
            }
            return false;
        };

        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            sseBuffer += decoder.decode(value, { stream: true });
            const lines = sseBuffer.split('\n');
            sseBuffer = lines.pop() || '';
            for (const line of lines) {
                if (!line.startsWith('data: ')) continue;
                const dataStr = line.slice(6).trim();
                if (dataStr === '[DONE]') continue;
                try {
                    const parsed = JSON.parse(dataStr);
                    const text = parsed.candidates?.[0]?.content?.parts?.[0]?.text || '';
                    jsonBuffer += text;
                    if (!arrayStarted) {
                        const trimmed = jsonBuffer.trimStart();
                        if (trimmed.startsWith('[')) { jsonBuffer = trimmed.slice(1); arrayStarted = true; }
                    }
                    let cont = true;
                    while (cont) { cont = tryParseQuestion(); }
                } catch { /* SSE chunk parse error */ }
            }
        }

        const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);
        setStatus(`Selesai! ${questionCount} butir soal diterima (${elapsedSec} detik).`);
        onDone({ ok: true, totalCount: questionCount, modelUsed: targetModel, elapsedSec });
    } catch (err) {
        if (err && err.name === 'AbortError') { onDone({ ok: false, message: 'Koneksi ke AI Studio timeout. Periksa koneksi internet Anda lalu coba lagi.' }); }
        else if (err && err.name === 'TypeError') { onDone({ ok: false, message: 'Tidak dapat terhubung ke AI Studio. Periksa koneksi internet Anda.' }); }
        else { onDone({ ok: false, message: `Terjadi kendala saat streaming AI: ${err?.message || 'Unknown error'}` }); }
    }
};

/**
 * Generate questions directly from an uploaded document (PDF, Text, CSV, etc.)
 */
export const generateQuestionsFromDocument = async ({
    file,
    instruction = 'Buatkan butir soal kuis/ujian berkualitas tinggi dari materi dokumen ini',
    count = 5,
    typePreference = '2',
    difficulty = 'Sedang',
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
    onStatus = null,
}) => {
    const setStatus = (msg) => { if (typeof onStatus === 'function') onStatus(msg); };

    if (!file) {
        return { ok: false, message: 'Berkas materi belum dipilih.' };
    }

    setStatus(`Membaca berkas "${file.name}"...`);

    const typeDescription = {
        '1': 'Semua soal bertipe Essay / Isian Singkat (typeId: 1, sertakan kunci/contoh jawaban di correctAnswer).',
        '2': 'Semua soal bertipe Pilihan Ganda (typeId: 2, sediakan 4 pilihan jawaban di options di mana tepat SATU bernilai isCorrect: true).',
        '3': 'Semua soal bertipe Checkbox / Pilihan Majemuk (typeId: 3, sediakan 4-5 opsi di mana ada minimal 2 bernilai isCorrect: true).',
        '4': 'Semua soal bertipe Tanggal & Waktu / Date Time (typeId: 4, correctAnswer diisi format ISO "YYYY-MM-DD" atau "YYYY-MM-DDTHH:mm").',
        '5': 'Semua soal bertipe Benar / Salah (typeId: 5, correctAnswer diisi "Benar" atau "Salah").',
        'mixed': 'Variasi campuran antara Pilihan Ganda (typeId: 2), Benar/Salah (typeId: 5), dan Essay (typeId: 1).',
    }[typePreference] || 'Pilihan Ganda (typeId: 2)';

    const promptText = `${AI_GUARDRAIL}Berdasarkan berkas/dokumen materi terlampir, buatlah ${count} butir soal berkualitas tinggi dengan panduan berikut:
- **Instruksi Khusus Pengguna:** ${instruction || 'Buat butir soal dari seluruh materi'}
- **Tingkat Kesulitan:** ${difficulty}
- **Bentuk Soal:** ${typeDescription}
- **Bahasa:** Gunakan bahasa yang SAMA dengan bahasa dokumen materi di atas untuk SELURUH output.

**FORMAT KELUARAN WAJIB (JSON ARRAY):**
Kembalikan HANYA array JSON valid tanpa teks atau penjelasan pembuka/penutup. Struktur objek per soal:
[
  {
    "question": "Teks pertanyaan lengkap",
    "typeId": 2,
    "isRequired": true,
    "isScorable": true,
    "points": 1,
    "correctAnswer": "Kunci jawaban untuk tipe 1/4 atau 'Benar'/'Salah' untuk tipe 5",
    "options": [
      { "optionText": "Pilihan A", "isCorrect": false },
      { "optionText": "Pilihan B", "isCorrect": true },
      { "optionText": "Pilihan C", "isCorrect": false },
      { "optionText": "Pilihan D", "isCorrect": false }
    ]
  }
]
Catatan:
- Untuk tipe 2 (Pilihan Ganda), pastikan tepat 1 opsi isCorrect: true.
- Untuk tipe 3 (Checkbox), minimal 2 opsi isCorrect: true.
- Untuk tipe 1, 4, 5, options boleh kosong [].
`.trim();

    return await executeWithApiKeyFailover(async (apiKey) => {
        try {
            const targetModel = normalizeAiModel(selectedModel);
            setStatus(`Menghubungkan ke ${targetModel} di Google AI Studio...`);

            const isPdfOrImage = file.type === 'application/pdf' || file.type.startsWith('image/') || file.name.toLowerCase().endsWith('.pdf');
            const parts = [{ text: promptText }];

            if (isPdfOrImage) {
                const base64Data = await new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onload = () => {
                        const res = reader.result;
                        const base64 = typeof res === 'string' ? res.split(',')[1] : '';
                        resolve(base64);
                    };
                    reader.onerror = reject;
                    reader.readAsDataURL(file);
                });
                parts.push({
                    inlineData: {
                        mimeType: file.type || 'application/pdf',
                        data: base64Data,
                    }
                });
            } else {
                const textContent = await new Promise((resolve, reject) => {
                    const reader = new FileReader();
                    reader.onload = () => resolve(reader.result || '');
                    reader.onerror = reject;
                    reader.readAsText(file);
                });
                parts.push({
                    text: `\n\n=== ISI DOKUMEN MATERI ("${file.name}") ===\n"""\n${String(textContent).slice(0, 100000)}\n"""`
                });
            }

            const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
            const startTime = Date.now();
            setStatus(`AI (${targetModel}) sedang membaca materi & menyusun butir soal...`);

            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts }],
                    generationConfig: {
                        responseMimeType: 'application/json',
                        temperature: 0.7,
                    },
                }),
            });

            const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);

            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                const errMsg = errData.error?.message || `HTTP ${response.status}`;
                if (response.status === 429) {
                    return { ok: false, status: 429, message: `Batas rate limit model ${targetModel} tercapai. Coba lagi dalam beberapa saat.` };
                }
                if (response.status === 400 || response.status === 403) {
                    return { ok: false, status: response.status, message: `API Key tidak valid atau akses ditolak. (${errMsg})` };
                }
                return { ok: false, status: response.status, message: `Gagal memanggil AI: ${errMsg}` };
            }

            setStatus(`Menerima hasil soal dari AI (${elapsedSec} detik). Memvalidasi struktur...`);

            const data = await response.json();
            const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text;

            if (!textResponse) {
                return { ok: false, message: 'AI tidak mengembalikan hasil teks soal.' };
            }

            let parsedQuestions;
            try {
                parsedQuestions = safeJsonParse(textResponse);
            } catch {
                return { ok: false, message: 'Format data dari AI tidak valid.' };
            }

            if (!Array.isArray(parsedQuestions) || parsedQuestions.length === 0) {
                return { ok: false, message: 'Format data dari AI tidak menghasilkan daftar soal.' };
            }

            const normalized = parsedQuestions.map((q, idx) => {
                const typeId = parseInt(q.typeId, 10) || 2;
                let options = Array.isArray(q.options) ? q.options : [];
                if ([2, 3].includes(typeId) && options.length === 0) {
                    options = [
                        { optionText: 'Pilihan A', isCorrect: true },
                        { optionText: 'Pilihan B', isCorrect: false },
                        { optionText: 'Pilihan C', isCorrect: false },
                        { optionText: 'Pilihan D', isCorrect: false },
                    ];
                }
                return {
                    _id: `q_doc_ai_${Date.now()}_${idx}`,
                    id: null,
                    question: String(q.question || `Pertanyaan ${idx + 1}`),
                    typeId: typeId,
                    isRequired: q.isRequired !== undefined ? Boolean(q.isRequired) : true,
                    isScorable: q.isScorable !== undefined ? Boolean(q.isScorable) : true,
                    points: q.points != null ? Number(q.points) : 1,
                    correctAnswer: q.correctAnswer ? String(q.correctAnswer) : '',
                    options: options.map((opt, oIdx) => ({
                        optionText: String(opt.optionText || opt.text || `Pilihan ${String.fromCharCode(65 + oIdx)}`),
                        isCorrect: Boolean(opt.isCorrect),
                    })),
                    questionImage: null,
                    questionAudio: null,
                };
            });

            setStatus(`Selesai! Berhasil membuat ${normalized.length} butir soal dari "${file.name}".`);

            return {
                ok: true,
                data: normalized,
                fileName: file.name,
                modelUsed: targetModel,
                elapsedSec,
            };
        } catch (err) {
            return {
                ok: false,
                message: `Terjadi kendala saat membaca materi atau memproses AI: ${err?.message || 'Unknown error'}`,
            };
        }
    }, customApiKey);
};

/**
 * Helper to download structured questions as a standard CSV template for re-import
 */
export const exportQuestionsToCSV = (questions, title = 'template-soal-ai') => {
    if (!questions || questions.length === 0) return;
    const rows = [
        ['question', 'type_id', 'order', 'is_required', 'correct_answer', 'options']
    ];
    questions.forEach((q, i) => {
        const isChoice = q.typeId === 2 || q.typeId === 3;
        const optionsStr = (q.options || []).map(o => (o.isCorrect ? `[BENAR] ${o.optionText}` : o.optionText)).join('|');
        const cleanQ = (q.question || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
        const correctCa = isChoice
            ? (q.options || []).filter(o => o.isCorrect).map(o => o.optionText).join(',')
            : (q.correctAnswer || '');
        rows.push([
            `"${cleanQ.replace(/"/g, '""')}"`,
            q.typeId || 2,
            i + 1,
            q.isRequired ? 'true' : 'false',
            `"${(correctCa || '').replace(/"/g, '""')}"`,
            `"${optionsStr.replace(/"/g, '""')}"`,
        ]);
    });
    const csv = '\uFEFF' + rows.map(r => r.join(',')).join('\r\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${title.replace(/\s+/g, '_')}-${Date.now()}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
};

/**
 * Extract text content or transcript from a given URL (Web Article or YouTube Video)
 */
export const extractContentFromUrl = async (url, onStatus = null) => {
    const setStatus = (msg) => { if (typeof onStatus === 'function') onStatus(msg); };
    if (!url || typeof url !== 'string') return { ok: false, message: 'URL tidak valid' };

    const trimmedUrl = url.trim();
    setStatus(`Membaca URL: ${trimmedUrl}...`);

    // 1. YouTube URL detection
    const ytMatch = trimmedUrl.match(/(?:youtube\.com\/(?:watch\?v=|embed\/|v\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/i);
    if (ytMatch && ytMatch[1]) {
        const videoId = ytMatch[1];
        setStatus(`Mendeteksi video YouTube (ID: ${videoId}). Mengambil judul & transkrip...`);

        try {
            // Attempt to fetch oEmbed metadata for title
            let videoTitle = `YouTube Video (${videoId})`;
            try {
                const oembedRes = await fetch(`https://noembed.com/embed?url=https://www.youtube.com/watch?v=${videoId}`);
                if (oembedRes.ok) {
                    const meta = await oembedRes.json();
                    if (meta.title) videoTitle = meta.title;
                }
            } catch {}

            // Attempt public timedtext / subtitles extraction via corsproxy
            let transcriptText = '';
            try {
                const subRes = await fetch(`https://corsproxy.io/?${encodeURIComponent(`https://www.youtube.com/watch?v=${videoId}`)}`);
                if (subRes.ok) {
                    const html = await subRes.text();
                    // Extract captions JSON from initial player response if available
                    const captionMatch = html.match(/"captionTracks":\s*(\[[^\]]+\])/);
                    if (captionMatch && captionMatch[1]) {
                        const tracks = JSON.parse(captionMatch[1]);
                        const trackUrl = tracks[0]?.baseUrl;
                        if (trackUrl) {
                            const trackRes = await fetch(`https://corsproxy.io/?${encodeURIComponent(trackUrl)}`);
                            if (trackRes.ok) {
                                const xmlText = await trackRes.text();
                                transcriptText = xmlText
                                    .replace(/<text[^>]*>/g, ' ')
                                    .replace(/<\/text>/g, '\n')
                                    .replace(/<[^>]+>/g, '')
                                    .replace(/&amp;/g, '&')
                                    .replace(/&#39;/g, "'")
                                    .replace(/&quot;/g, '"')
                                    .replace(/\s+/g, ' ')
                                    .trim();
                            }
                        }
                    }
                }
            } catch {}

            if (!transcriptText) {
                // Fallback video summary payload
                transcriptText = `Video YouTube: "${videoTitle}". URL: https://youtu.be/${videoId}. Silakan analisis materi dan buat soal sesuai topik/judul video ini.`;
            }

            return {
                ok: true,
                type: 'youtube',
                title: videoTitle,
                videoId,
                content: transcriptText.slice(0, 50000),
                url: trimmedUrl
            };
        } catch (err) {
            return {
                ok: true,
                type: 'youtube',
                title: `Video YouTube (${videoId})`,
                videoId,
                content: `Video YouTube: https://youtu.be/${videoId}`,
                url: trimmedUrl
            };
        }
    }

    // 2. Standard Webpage Article extraction
    try {
        setStatus(`Mengambil teks artikel dari webpage...`);
        let html = '';
        try {
            const resp = await fetch(`https://corsproxy.io/?${encodeURIComponent(trimmedUrl)}`);
            if (resp.ok) {
                html = await resp.text();
            }
        } catch {}

        if (!html) {
            const directResp = await fetch(trimmedUrl, { mode: 'cors' }).catch(() => null);
            if (directResp && directResp.ok) {
                html = await directResp.text();
            }
        }

        if (!html) {
            return { ok: false, message: 'Tidak dapat mengambil konten halaman web. Pastikan URL dapat diakses publik.' };
        }

        // Clean HTML to pure article text
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');

        // Remove script, style, nav, footer tags
        doc.querySelectorAll('script, style, nav, footer, header, noscript, iframe, svg, [role="navigation"]').forEach(el => el.remove());

        const pageTitle = doc.querySelector('title')?.innerText || doc.querySelector('h1')?.innerText || trimmedUrl;
        
        // Extract paragraph texts
        const paragraphs = Array.from(doc.querySelectorAll('article, main, p, h1, h2, h3, h4, li'))
            .map(el => el.innerText.trim())
            .filter(t => t.length > 20);

        const fullText = paragraphs.join('\n\n').slice(0, 60000);

        if (!fullText || fullText.length < 50) {
            return { ok: false, message: 'Teks artikel pada halaman web tersebut terlalu singkat atau tidak dapat diekstrak.' };
        }

        return {
            ok: true,
            type: 'webpage',
            title: pageTitle.trim(),
            content: fullText,
            url: trimmedUrl
        };
    } catch (err) {
        return { ok: false, message: `Gagal membaca URL: ${err.message}` };
    }
};

/**
 * Generate remedial explanation & self-check practice questions for "Pelajari Soal" feature
 */
export const generateRemedialExplanation = async ({
    questionText,
    questionType = 2,
    userAnswer = '',
    correctAnswer = '',
    options = [],
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
}) => {
    return await executeWithApiKeyFailover(async (apiKey) => {
        const typeLabelMap = { 1: 'Essay', 2: 'Pilihan Ganda', 3: 'Checkbox', 4: 'Tanggal', 5: 'Benar/Salah' };
        const qTypeName = typeLabelMap[questionType] || 'Pilihan Ganda';

        const promptText = `
Anda adalah Guru & Tutor Pendamping Cerdas yang ramah, memotivasi, dan solutif.
Siswa baru saja mengerjakan soal kuis dan ingin mempelajari letak kesalahan serta konsep dasar materinya secara mendalam.

=== DATA SOAL KUIS ===
- Bentuk Soal: ${qTypeName}
- Pertanyaan: "${questionText}"
- Pilihan Opsi yang Tersedia: ${options.map((o, i) => `${String.fromCharCode(65 + i)}. ${o.optionText}`).join(' | ') || '-'}
- Jawaban yang Dipilih Siswa: "${userAnswer || '(Tidak dijawab / Kosong)'}"
- Jawaban yang Benar / Kunci: "${correctAnswer}"

TUGAS ANDA:
1. Jelaskan secara ramah, ringkas, dan jelas mengapa jawaban siswa salah (jika salah) dan mengapa jawaban kunci adalah jawaban yang tepat.
2. Tuliskan 2-3 poin ringkas materi/rumus kunci yang harus diingat siswa.
3. Buat 1 BUTIR SOAL LATIHAN SEJENIS (Pilihan Ganda 4 opsi) lengkap dengan kunci jawaban dan pembahasannya agar siswa dapat langsung menguji pemahamannya secara mandiri.

**FORMAT KELUARAN WAJIB (JSON VALID):**
{
  "explanation": "Penjelasan ramah dan terstruktur (bisa gunakan Markdown bullet/bold/LaTeX jika ada rumus)",
  "keyTakeaways": [
    "Poin kunci 1",
    "Poin kunci 2"
  ],
  "practiceQuestion": {
    "question": "Teks soal latihan serupa untuk menguji pemahaman",
    "options": [
      { "optionText": "Pilihan A", "isCorrect": false },
      { "optionText": "Pilihan B", "isCorrect": true },
      { "optionText": "Pilihan C", "isCorrect": false },
      { "optionText": "Pilihan D", "isCorrect": false }
    ],
    "explanation": "Pembahasan singkat untuk soal latihan ini"
  }
}
`.trim();

        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${selectedModel}:generateContent?key=${apiKey}`;
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: promptText }] }],
                generationConfig: {
                    responseMimeType: 'application/json',
                    temperature: 0.6,
                },
            }),
        });

        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${response.status}`;
            return { ok: false, status: response.status, message: errMsg };
        }

        const data = await response.json();
        const rawText = data.candidates?.[0]?.content?.parts?.[0]?.text;
        if (!rawText) return { ok: false, message: 'AI tidak mengembalikan hasil.' };

        const parsed = safeJsonParse(rawText);
        if (!parsed || !parsed.explanation) {
            return { ok: false, message: 'Format respons tutor AI tidak valid.' };
        }

        return {
            ok: true,
            data: parsed,
            modelUsed: selectedModel,
        };
    }, customApiKey);
};

/**
 * Revise a single question using Gemini API with failover
 */
export const reviseQuestionWithAI = async ({
    question,
    options = [],
    correctAnswer = '',
    typeId = 2,
    isRequired = true,
    isScorable = true,
    instruction,
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
}) => {
    return await executeWithApiKeyFailover(async (apiKey) => {
        const cleanQ = (question || '').replace(/<[^>]*>/g, '').trim();
        const optionsText = options.map((o, i) => `${String.fromCharCode(65+i)}. ${o.optionText}${o.isCorrect?' (jawaban benar)':''}`).join('\n');
        const prompt = `Anda adalah asisten penyusun soal ujian. Revisi soal berikut sesuai instruksi.

Soal asli:
${cleanQ}

Pilihan jawaban:
${optionsText || '(tidak ada opsi)'}

Kunci jawaban: ${correctAnswer || ''}

Instruksi revisi: ${instruction.trim()}

Kembalikan HANYA JSON valid (satu objek, bukan array) dengan struktur:
{
  "question": "teks soal yang direvisi",
  "typeId": ${typeId},
  "isRequired": ${isRequired},
  "isScorable": ${isScorable},
  "correctAnswer": "kunci jawaban",
  "options": [{"optionText":"...", "isCorrect": false}]
}`;
            const targetModel = normalizeAiModel(selectedModel);
        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
        const resp = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: { responseMimeType: 'application/json', temperature: 0.7 }
            })
        });
        if (!resp.ok) {
            const errData = await resp.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${resp.status}`;
            return { ok: false, status: resp.status, message: errMsg };
        }
        const data = await resp.json();
        let textRes = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        textRes = textRes.trim().replace(/^```json\s*/,'').replace(/\s*```$/,'').replace(/^```\s*/,'');
        const revised = JSON.parse(textRes);
        return { ok: true, data: revised };
    }, customApiKey);
};

/**
 * Bulk revise multiple questions using Gemini API with failover
 */
export const bulkReviseQuestionsWithAI = async ({
    questions = [],
    selectedIndices = [],
    instruction,
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
}) => {
    return await executeWithApiKeyFailover(async (apiKey) => {
            const targetModel = normalizeAiModel(selectedModel);
        const results = [];
        let anySuccess = false;

        for (const idx of selectedIndices) {
            const q = questions[idx];
            if (!q) continue;
            try {
                const cleanQ = (q.question || '').replace(/<[^>]*>/g, '').trim();
                const optionsText = (q.options || []).map((o, i) => `${String.fromCharCode(65+i)}. ${o.optionText}${o.isCorrect?' (jawaban benar)':''}`).join('\n');
                const prompt = `Revisi soal berikut sesuai instruksi. Kembalikan HANYA JSON valid.\n\nSoal: ${cleanQ}\nOpsi:\n${optionsText || '(tidak ada)'}\nKunci: ${q.correctAnswer || ''}\n\nInstruksi: ${instruction.trim()}\n\nJSON output:\n{"question":"...","typeId":${q.typeId},"isRequired":${q.isRequired},"isScorable":${q.isScorable},"correctAnswer":"...","options":[{"optionText":"...","isCorrect":false}]}`;
                const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
                const resp = await fetch(endpoint, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        contents: [{ parts: [{ text: prompt }] }],
                        generationConfig: { responseMimeType: 'application/json', temperature: 0.7 }
                    })
                });
                if (!resp.ok) {
                    if (resp.status === 429 || resp.status === 400 || resp.status === 403) {
                        return { ok: false, status: resp.status, message: `HTTP ${resp.status}` };
                    }
                    continue;
                }
                const data = await resp.json();
                let textRes = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
                textRes = textRes.trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'').trim();
                // Gemini can occasionally add a short sentence around the JSON.
                // Extract the object so one malformed wrapper does not drop a
                // selected question from the bulk result.
                const jsonStart = textRes.indexOf('{');
                const jsonEnd = textRes.lastIndexOf('}');
                if (jsonStart >= 0 && jsonEnd > jsonStart) textRes = textRes.slice(jsonStart, jsonEnd + 1);
                const revised = safeJsonParse(textRes);
                if (!revised || !revised.question) throw new Error('Format JSON revisi tidak valid');
                results.push({ idx, original: q, revised });
                anySuccess = true;
            } catch (err) {
                console.error(`Error revising question ${idx}:`, err);
            }
        }

        if (!anySuccess && selectedIndices.length > 0) {
            return { ok: false, message: 'Tidak ada soal yang berhasil direvisi oleh AI.' };
        }
        return { ok: true, data: results };
    }, customApiKey);
};

/**
 * AI Analytics & Educational Insights
 */
export const analyzeFormAnalyticsWithAI = async ({
    summary,
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
}) => {
    return await executeWithApiKeyFailover(async (apiKey) => {
        const promptText = `Anda adalah analis pendidikan profesional. Berdasarkan data hasil ujian berikut, berikan analisis mendalam dan rekomendasi perbaikan dalam bahasa Indonesia yang jelas dan mudah dipahami guru.

${summary}

Berikan analisis yang mencakup:
1. Identifikasi soal-soal bermasalah (terlalu sulit/mudah) dan saran perbaikannya
2. Interpretasi distribusi nilai dan apa artinya bagi kualitas pembelajaran
3. Rekomendasi konkret untuk meningkatkan hasil belajar
4. Kesimpulan umum tentang kualitas soal dan pemahaman siswa

Format respons dalam paragraf yang terstruktur, maksimal 400 kata.`;

            const targetModel = normalizeAiModel(selectedModel);
        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
        const resp = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: promptText }] }],
                generationConfig: { temperature: 0.5 }
            })
        });

        if (!resp.ok) {
            const errData = await resp.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${resp.status}`;
            return { ok: false, status: resp.status, message: errMsg };
        }

        const data = await resp.json();
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        return { ok: true, data: text.trim() };
    }, customApiKey);
};

/**
 * AI Holistic Essay Scoring
 */
export const scoreHolisticEssayWithAI = async ({
    essayAnswers = [],
    pgSection = '',
    selectedModel = DEFAULT_AI_MODEL,
    customApiKey = null,
}) => {
    return await executeWithApiKeyFailover(async (apiKey) => {
        const essaySection = essayAnswers.map((a, i) => {
            const text = a.answerText || a.answerValue || '(kosong)';
            const key = a.correctAnswer || '(tidak ada kunci)';
            const q = (a.question || '').replace(/<[^>]*>/g, '').substring(0, 200);
            const aId = a.answerId || a.id;
            return `Essay #${i+1} (answerId: ${aId}):\nPertanyaan: ${q}\nKunci: ${key}\nJawaban: ${text}`;
        }).join('\n\n');

        const prompt = `Anda adalah penilai ujian. Nilai SEMUA soal essay dari satu responden sekaligus secara holistik, dengan mempertimbangkan konteks keseluruhan performa responden.
${pgSection}

Data Essay:
${essaySection}

Kembalikan JSON array — satu objek per essay, HARUS berurutan sesuai Essay #1, #2, dst:
[
  {"answerId": <answerId integer dari data essay>, "score": 85, "isCorrect": true, "reason": "Alasan singkat 1 kalimat"}
]

Panduan penilaian:
- Nilai berdasarkan kesamaan makna/konsep, bukan kata per kata
- isCorrect: true jika score >= 70
- Pertimbangkan konteks: jika PG bagus, cenderung paham materi
- Score: 0-100`;

            const targetModel = normalizeAiModel(selectedModel);
        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
        const resp = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: { responseMimeType: 'application/json', temperature: 0.3 }
            })
        });

        if (!resp.ok) {
            const errData = await resp.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${resp.status}`;
            return { ok: false, status: resp.status, message: errMsg };
        }

        const data = await resp.json();
        let textRes = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        textRes = textRes.trim().replace(/^```json\s*/,'').replace(/\s*```$/,'').replace(/^```\s*/,'');
        const suggestions = JSON.parse(textRes);
        return { ok: true, data: suggestions };
    }, customApiKey);
};
