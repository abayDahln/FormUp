/**
 * AI Service for Generating Quiz & Form Questions using Google Gemini API
 */

const FALLBACK_MODELS = [
    'gemini-2.5-flash',
    'gemini-flash-latest',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
    'gemini-1.5-flash'
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

/**
 * Generate structured quiz questions using Google Gemini API
 */
export const generateQuestionsWithAI = async ({
    topic,
    contextText = '',
    count = 5,
    typePreference = '2', // '2': Multiple Choice, '1': Essay, '5': True/False, '3': Checkbox, 'mixed': Mixed
    difficulty = 'Sedang', // 'Mudah', 'Sedang', 'Sulit'
    includeMath = false,
    includeCode = false,
    customApiKey = null,
}) => {
    const apiKey = (customApiKey || getGeminiApiKey()).trim();

    if (!apiKey) {
        return {
            ok: false,
            message: 'API Key Gemini belum diatur. Masukkan Gemini API Key Anda untuk menggunakan fitur ini.',
        };
    }

    const typeDescription = {
        '1': 'Semua soal bertipe Essay / Short Answer (typeId: 1, sertakan contoh kunci jawaban di correctAnswer).',
        '2': 'Semua soal bertipe Pilihan Ganda (typeId: 2, sediakan 4 pilihan jawaban di options di mana tepat SATU bernilai isCorrect: true).',
        '3': 'Semua soal bertipe Checkbox / Multi-pilihan (typeId: 3, sediakan 4-5 opsi di mana ada minimal 2 yang isCorrect: true).',
        '5': 'Semua soal bertipe Benar / Salah (typeId: 5, correctAnswer diisi "Benar" atau "Salah").',
        'mixed': 'Variasi campuran antara Pilihan Ganda (typeId: 2), True/False (typeId: 5), dan Essay (typeId: 1).',
    }[typePreference] || 'Pilihan Ganda (typeId: 2)';

    let extraInstructions = [];
    if (includeMath) {
        extraInstructions.push('Sertakan notasi rumus matematika/fisika LaTeX dalam tanda dolar $...$ untuk inline atau $$...$$ untuk baris terpisah jika relevan dengan topik.');
    }
    if (includeCode) {
        extraInstructions.push('Untuk potongan kode pemrograman, WAJIB gunakan format markdown code block dengan baris baru terpisah yang rapi:\n```javascript\n// baris kode di sini\n```\nPastikan nama bahasa (misal: js, jsx, python, java, sql, html, css, cpp) ditulis setelah tiga backtick dan kode berada di baris baru.');
    }
    if (contextText && contextText.trim()) {
        extraInstructions.push(`Gunakan materi/teks referensi berikut sebagai sumber utama pembuatan soal:\n"""\n${contextText.trim()}\n"""`);
    }

    const promptText = `
Anda adalah asisten pembuat soal ujian dan formulir profesional. Buatlah ${count} butir soal berkualitas tinggi dengan spesifikasi berikut:

- **Topik / Materi:** ${topic || 'Pengetahuan Umum'}
- **Tingkat Kesulitan:** ${difficulty}
- **Ketentuan Tipe Soal:** ${typeDescription}
- **Bahasa:** Bahasa Indonesia yang baik, jelas, dan baku.
${extraInstructions.length > 0 ? `- **Instruksi Tambahan:**\n  ${extraInstructions.join('\n  ')}` : ''}

**FORMAT OUTPUT WAJIB (JSON ARRAY):**
Kembalikan HANYA array JSON murni tanpa markdown pembungkus di luar JSON. Setiap elemen harus memiliki struktur berikut:
[
  {
    "question": "Teks pertanyaan lengkap",
    "typeId": 2, // 1 = Essay, 2 = Pilihan Ganda, 3 = Checkbox, 5 = True/False
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
Catatan:
- Jangan menyertakan bobot poin (biarkan default).
- Untuk typeId 2 dan 3, array "options" WAJIB berisi minimal 4 pilihan.
- Untuk typeId 1 dan 5, "options" boleh berupa array kosong [].
- Pastikan ada tepat 1 isCorrect: true untuk typeId 2.
`.trim();

    let lastError = null;

    for (const modelName of FALLBACK_MODELS) {
        try {
            const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;
            
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

            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                const errMsg = errData.error?.message || `HTTP ${response.status} ${response.statusText}`;
                
                // If model not found (404), try next model in fallback list
                if (response.status === 404) {
                    lastError = errMsg;
                    continue;
                }
                
                return {
                    ok: false,
                    message: `Gagal memanggil Gemini API (${modelName}): ${errMsg}`,
                };
            }

            const data = await response.json();
            const textResponse = data.candidates?.[0]?.content?.parts?.[0]?.text;

            if (!textResponse) {
                return {
                    ok: false,
                    message: 'Gemini tidak menghasilkan konten. Silakan coba ulangi lagi.',
                };
            }

            // Clean up possible markdown code fences
            let cleanedJson = textResponse.trim();
            if (cleanedJson.startsWith('```json')) {
                cleanedJson = cleanedJson.replace(/^```json\s*/, '').replace(/\s*```$/, '');
            } else if (cleanedJson.startsWith('```')) {
                cleanedJson = cleanedJson.replace(/^```\s*/, '').replace(/\s*```$/, '');
            }

            const parsedQuestions = JSON.parse(cleanedJson);

            if (!Array.isArray(parsedQuestions) || parsedQuestions.length === 0) {
                return {
                    ok: false,
                    message: 'Format data dari AI tidak valid. Silakan coba lagi.',
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

                // Ensure options have proper fields
                const formattedOptions = options.map((opt, oIdx) => ({
                    optionText: String(opt.optionText || opt.text || `Opsi ${oIdx + 1}`),
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

            return {
                ok: true,
                data: normalized,
                modelUsed: modelName,
            };
        } catch (err) {
            lastError = err.message;
        }
    }

    return {
        ok: false,
        message: lastError ? `Terjadi kesalahan saat memproses AI: ${lastError}` : 'Gagal menghubungi server Gemini AI.',
    };
};
