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

    const promptText = `
Anda adalah asisten pembuat soal ujian dan kuis sekolah profesional. Buatlah ${count} butir soal berkualitas tinggi dengan panduan berikut:

- **Materi / Topik:** ${topic || 'Pengetahuan Umum'}
- **Tingkat Kesulitan:** ${difficulty}
- **Bentuk Soal:** ${typeDescription}
- **Bahasa:** Bahasa Indonesia yang baik, jelas, baku, dan mudah dipahami siswa.
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

            return {
                ok: false,
                message: `Gagal memanggil model ${targetModel}: ${errMsg}`,
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
        return {
            ok: false,
            message: `Terjadi kendala saat memproses AI: ${err.message}`,
        };
    }
};
