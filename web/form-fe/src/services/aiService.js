/**
 * AI Service for Generating Quiz & Form Questions using Google Gemini API
 * Model list matches Google AI Studio free tier models.
 */

export const AVAILABLE_MODELS = [
    { 
        id: 'gemini-2.5-flash', 
        name: 'Gemini 2.5 Flash', 
        desc: 'Paling Cepat & Akurat (Rekomendasi)', 
        badge: 'Rekomendasi' 
    },
    { 
        id: 'gemini-2.5-flash-lite', 
        name: 'Gemini 2.5 Flash Lite', 
        desc: 'Hemat Kuota (Limit 10 RPM) & Responsif', 
        badge: 'Hemat Kuota' 
    },
    { 
        id: 'gemini-3-flash-preview', 
        name: 'Gemini 3 Flash', 
        desc: 'Generasi Baru dengan pemahaman materi luas', 
        badge: 'Generasi Baru' 
    },
    { 
        id: 'gemini-2.5-pro', 
        name: 'Gemini 2.5 Pro', 
        desc: 'Untuk soal analisis mendalam & studi kasus', 
        badge: 'Pro' 
    },
];

export const getGeminiApiKey = () => {
    if (typeof window !== 'undefined') {
        const stored = localStorage.getItem('formup_gemini_api_key');
        if (stored && stored.trim()) return stored.trim();
    }
    return '';
};

export const saveGeminiApiKey = (key) => {
    if (typeof window !== 'undefined') {
        if (!key || !key.trim()) {
            localStorage.removeItem('formup_gemini_api_key');
        } else {
            localStorage.setItem('formup_gemini_api_key', key.trim());
        }
    }
};

export const removeGeminiApiKey = () => {
    if (typeof window !== 'undefined') {
        localStorage.removeItem('formup_gemini_api_key');
    }
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
            // Repair unescaped backslashes that are not valid JSON escape chars (\", \\, \/, \b, \f, \n, \r, \t, \uXXXX)
            const repaired = cleaned.replace(/\\([^"\\\/bfnrtu]|u(?![\da-fA-F]{4}))/g, '\\\\$1');
            return JSON.parse(repaired);
        } catch (e2) {
            const jsonMatch = cleaned.match(/(\{[\s\S]*\}|\[[\s\S]*\])/);
            if (jsonMatch) {
                const repaired = jsonMatch[0].replace(/\\([^"\\\/bfnrtu]|u(?![\da-fA-F]{4}))/g, '\\\\$1');
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
    selectedModel = 'gemini-2.5-flash',
    customApiKey = null,
    onStatus = null, // Callback: (statusText) => void
}) => {
    const apiKey = (customApiKey || getGeminiApiKey()).trim();

    const setStatus = (msg) => {
        if (typeof onStatus === 'function') onStatus(msg);
    };

    if (!apiKey) {
        return {
            ok: false,
            message: 'API Key Gemini belum diatur. Masukkan Gemini API Key dari Google AI Studio terlebih dahulu.',
        };
    }

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

    try {
        const targetModel = selectedModel || 'gemini-2.5-flash';
        setStatus(`Menghubungkan ke ${targetModel} di Google AI Studio...`);

        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:generateContent?key=${apiKey}`;
        
        const startTime = Date.now();
        setStatus(`AI (${targetModel}) sedang berpikir & menyusun butir soal...`);

        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: promptText }] }],
                generationConfig: {
                    responseMimeType: 'application/json',
                    temperature: 0.7,
                },
            }),
        });

        const elapsedSec = ((Date.now() - startTime) / 1000).toFixed(1);

        if (!response.ok) {
            const errData = await response.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${response.status} ${response.statusText}`;

            if (response.status === 429) {
                return {
                    ok: false,
                    message: `Batas penggunaan harian / rate limit Google AI Studio untuk model ${targetModel} telah tercapai. Coba gunakan model lain seperti Gemini 2.5 Flash Lite atau tunggu beberapa saat.`,
                };
            }

            if (response.status === 400 || response.status === 403) {
                return {
                    ok: false,
                    message: `API Key Google AI Studio tidak valid atau izin akses ditolak. Periksa kembali API Key Anda. (${errMsg})`,
                };
            }

            // B7: Specific 5xx handling
            if (response.status >= 500) {
                return {
                    ok: false,
                    message: `Server AI Studio sedang tidak tersedia (Error ${response.status}). Coba beberapa menit lagi atau gunakan model lain seperti Gemini 2.5 Flash Lite.`,
                };
            }

            return {
                ok: false,
                message: `Gagal memanggil model ${targetModel}: ${errMsg}. Coba model lain seperti Gemini 2.5 Flash Lite.`,
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

        // B7: Use safeJsonParse to tolerate LaTeX formulas
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
        // B7: Specific error type handling
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
    selectedModel = 'gemini-2.5-flash',
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

    const targetModel = selectedModel || 'gemini-2.5-flash';
    const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${targetModel}:streamGenerateContent?key=${apiKey}&alt=sse`;
    const startTime = Date.now();
    setStatus(`AI (${targetModel}) sedang menyusun soal...`);

    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: promptText }] }],
                generationConfig: { temperature: 0.7 },
            }),
        });

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
