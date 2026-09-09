import { useState, useEffect, useRef } from 'react';
import {
    Sparkles, X, Loader2, Key, Check, Eye, EyeOff, ExternalLink,
    Trash2, ShieldCheck, AlertCircle, CheckCircle2, RotateCcw, Clock,
    Calculator, Code, ChevronDown, ChevronUp, FileText, Cpu, Layers
} from 'lucide-react';
import {
    getGeminiApiKey,
    saveGeminiApiKey,
    removeGeminiApiKey,
    AVAILABLE_MODELS,
    safeJsonParse
} from '../../services/aiService';
import { createForm, saveQuestions } from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function AIFormBuilderModal({ isOpen, onClose, onFormCreated }) {
    const [prompt, setPrompt] = useState('');
    const [contextText, setContextText] = useState('');
    const [formCount, setFormCount] = useState(1); // B5: 1-5 forms
    const [questionCount, setQuestionCount] = useState(5);
    const [typePreference, setTypePreference] = useState('2');
    const [difficulty, setDifficulty] = useState('Sedang');
    const [selectedModel, setSelectedModel] = useState('gemini-2.5-flash');
    const [includeMath, setIncludeMath] = useState(false);
    const [includeCode, setIncludeCode] = useState(false);
    const [showAdvanced, setShowAdvanced] = useState(false);

    // API Key
    const [apiKey, setApiKey] = useState('');
    const [inputKey, setInputKey] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showKeyEditor, setShowKeyEditor] = useState(false);

    // Status
    const [generating, setGenerating] = useState(false);
    const [creating, setCreating] = useState(false);
    const [error, setError] = useState('');
    const [status, setStatus] = useState('');
    const [elapsed, setElapsed] = useState(0);
    const [previews, setPreviews] = useState(null); // Array of form preview objects
    const [activePreviewIdx, setActivePreviewIdx] = useState(0);

    const timerRef = useRef(null);

    useEffect(() => {
        if (!isOpen) return;
        setPrompt('');
        setContextText('');
        setError('');
        setStatus('');
        setPreviews(null);
        setActivePreviewIdx(0);
        setElapsed(0);
        setFormCount(1);
        setQuestionCount(5);
        setTypePreference('2');
        setDifficulty('Sedang');
        setIncludeMath(false);
        setIncludeCode(false);
        setShowAdvanced(false);
        const saved = getGeminiApiKey();
        setApiKey(saved);
        setInputKey(saved);
        setShowKeyEditor(!saved);
    }, [isOpen]);

    useEffect(() => {
        if (generating || creating) {
            setElapsed(0);
            timerRef.current = setInterval(() => setElapsed(prev => prev + 1), 1000);
        } else {
            if (timerRef.current) clearInterval(timerRef.current);
        }
        return () => {
            if (timerRef.current) clearInterval(timerRef.current);
        };
    }, [generating, creating]);

    if (!isOpen) return null;

    const handleSaveKey = (e) => {
        if (e) e.preventDefault();
        const trimmed = inputKey.trim();
        if (!trimmed) { setError('Masukkan Gemini API Key yang valid.'); return; }
        saveGeminiApiKey(trimmed);
        setApiKey(trimmed);
        setShowKeyEditor(false);
        setError('');
    };

    const generateSingleForm = async (targetIndex, total, currentApiKey) => {
        const mathCodeInstructions = [];
        if (includeMath) mathCodeInstructions.push('- Untuk rumus matematika/fisika, gunakan format LaTeX inline $...$ atau blok $$...$$');
        if (includeCode) mathCodeInstructions.push('- Untuk kode program, gunakan format ```bahasa\\nkode\\n```');

        const typeDescription = {
            '1': 'Semua soal bertipe Essay / Isian Singkat (typeId: 1, sertakan kunci/contoh jawaban di correctAnswer).',
            '2': 'Semua soal bertipe Pilihan Ganda (typeId: 2, sediakan 4 pilihan jawaban di options di mana tepat SATU bernilai isCorrect: true).',
            '3': 'Semua soal bertipe Checkbox / Pilihan Majemuk (typeId: 3, sediakan 4-5 opsi di mana ada minimal 2 bernilai isCorrect: true).',
            '5': 'Semua soal bertipe Benar / Salah (typeId: 5, correctAnswer diisi "Benar" atau "Salah").',
            'mixed': 'Variasi campuran antara Pilihan Ganda (typeId: 2), Benar/Salah (typeId: 5), dan Essay (typeId: 1).',
        }[typePreference] || 'Pilihan Ganda (typeId: 2)';

        let extraContext = '';
        if (contextText && contextText.trim()) {
            extraContext = `\nMateri Referensi Tambahan:\n"""\n${contextText.trim()}\n"""\n`;
        }

        const promptText = `
PERAN & BATASAN KERAS: Anda adalah asisten pembuat formulir dan soal ujian pendidikan FormUp. Anda HANYA membuat kuis dan soal untuk keperluan edukasi.

Buatlah 1 formulir lengkap dengan ${questionCount} butir soal ${total > 1 ? `(Paket/Variasi ke-${targetIndex + 1} dari total ${total} paket)` : ''} berdasarkan panduan berikut:
- **Topik / Deskripsi:** ${prompt.trim()}
- **Tingkat Kesulitan:** ${difficulty}
- **Bentuk Soal:** ${typeDescription}
- **Bahasa:** Bahasa Indonesia baku yang baik
${extraContext}
${mathCodeInstructions.length > 0 ? mathCodeInstructions.join('\n') : ''}

**FORMAT KELUARAN WAJIB (JSON OBJECT):**
Kembalikan HANYA format JSON valid berikut tanpa teks pengantar atau penutup:
{
  "title": "${total > 1 ? `Judul Formulir (Paket ${targetIndex + 1})` : 'Judul Formulir Lengkap'}",
  "description": "Deskripsi singkat mengenai formulir/kuis ini",
  "questions": [
    {
      "question": "Teks pertanyaan lengkap",
      "typeId": 2,
      "isRequired": true,
      "isScorable": true,
      "correctAnswer": "Kunci jawaban jika ada",
      "options": [
        {"optionText": "Pilihan A", "isCorrect": false},
        {"optionText": "Pilihan B", "isCorrect": true},
        {"optionText": "Pilihan C", "isCorrect": false},
        {"optionText": "Pilihan D", "isCorrect": false}
      ]
    }
  ]
}
`.trim();

        const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${selectedModel}:generateContent?key=${currentApiKey}`;
        const resp = await fetch(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                contents: [{ parts: [{ text: promptText }] }],
                generationConfig: { responseMimeType: 'application/json', temperature: 0.7 }
            })
        });

        if (!resp.ok) {
            const errData = await resp.json().catch(() => ({}));
            const errMsg = errData.error?.message || `HTTP ${resp.status}`;
            if (resp.status === 429) throw new Error(`Rate limit tercapai untuk model ${selectedModel}. Coba pilih Gemini 2.5 Flash Lite.`);
            if (resp.status === 400 || resp.status === 403) throw new Error(`API Key tidak valid atau akses ditolak. (${errMsg})`);
            if (resp.status >= 500) throw new Error(`Server AI Studio tidak tersedia (Error ${resp.status}). Coba lagi nanti.`);
            throw new Error(`Gagal memanggil AI: ${errMsg}`);
        }

        const data = await resp.json();
        let text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        let parsed;
        try {
            parsed = safeJsonParse(text);
        } catch {
            throw new Error('AI mengembalikan format JSON yang tidak valid. Coba ulangi pembuatan.');
        }
        if (!parsed || !parsed.title || !Array.isArray(parsed.questions)) throw new Error('Format JSON dari AI tidak valid');
        return parsed;
    };

    const handleGenerate = async () => {
        const curKey = apiKey.trim();
        if (!curKey) { setShowKeyEditor(true); setError('Masukkan API Key terlebih dahulu.'); return; }
        if (!prompt.trim() && !contextText.trim()) { setError('Tulis deskripsi atau materi form yang ingin dibuat.'); return; }

        setError('');
        setGenerating(true);
        const countToGenerate = Math.min(Math.max(parseInt(formCount, 10) || 1, 1), 5);
        const results = [];

        try {
            for (let i = 0; i < countToGenerate; i++) {
                setStatus(`Menyusun formulir ${i + 1} dari ${countToGenerate} dengan ${selectedModel}...`);
                const formRes = await generateSingleForm(i, countToGenerate, curKey);
                results.push(formRes);
            }
            setStatus('Selesai! Tinjau hasil sebelum disimpan.');
            setPreviews(results);
            setActivePreviewIdx(0);
        } catch (err) {
            setError(err.message || 'Terjadi kesalahan saat memproses formulir.');
        } finally {
            setGenerating(false);
        }
    };

    const handleCreateForms = async () => {
        if (!previews || previews.length === 0) return;
        setCreating(true);
        setError('');
        let lastCreatedId = null;

        try {
            for (let fIdx = 0; fIdx < previews.length; fIdx++) {
                const currentPreview = previews[fIdx];
                setStatus(`Menyimpan formulir ${fIdx + 1} dari ${previews.length}: "${currentPreview.title}"...`);
                const formRes = await createForm({
                    title: currentPreview.title,
                    description: currentPreview.description || ''
                });
                if (!formRes.ok || !formRes.data?.id) throw new Error(formRes.message || `Gagal menyimpan form ${fIdx + 1}`);
                const newId = formRes.data.id;
                lastCreatedId = newId;

                if (currentPreview.questions && currentPreview.questions.length > 0) {
                    await saveQuestions(newId, currentPreview.questions.map((q, i) => ({
                        typeId: parseInt(q.typeId, 10) || 2,
                        question: q.question || '',
                        questionFormat: 'text',
                        questionOrder: i + 1,
                        isRequired: q.isRequired !== false,
                        correctAnswer: q.correctAnswer || null,
                        points: null,
                        options: (q.options || []).map(o => ({
                            optionText: String(o.optionText || ''),
                            isCorrect: Boolean(o.isCorrect)
                        })),
                    })));
                }
            }
            onClose();
            if (onFormCreated && lastCreatedId) onFormCreated(lastCreatedId);
        } catch (err) {
            setError('Gagal membuat form: ' + err.message);
        } finally {
            setCreating(false);
        }
    };

    const maskKey = (key) => (!key || key.length < 8) ? '****' : `${key.substring(0, 6)}...${key.substring(key.length - 4)}`;
    const currentPreview = previews ? previews[activePreviewIdx] : null;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <div className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs" onClick={onClose} />
            <div className="relative bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl w-full max-w-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh] z-10">

                {/* Header */}
                <div className="px-6 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between bg-gradient-to-r from-teal-500/10 via-emerald-500/5 to-transparent">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-teal-600 to-emerald-400 text-white flex items-center justify-center shadow-md">
                            <Sparkles size={20} />
                        </div>
                        <div>
                            <h2 className="text-base font-extrabold text-slate-900 dark:text-white">Buat Form dengan AI</h2>
                            <p className="text-xs text-slate-500 dark:text-slate-400">Deskripsikan form & materi, AI menyusun judul, deskripsi, & butir soal.</p>
                        </div>
                    </div>
                    <div className="flex items-center gap-1.5">
                        <button
                            type="button"
                            onClick={() => setShowKeyEditor(!showKeyEditor)}
                            className={`px-2.5 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1 border transition-all cursor-pointer ${
                                apiKey ? 'text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 border-teal-200 dark:border-teal-800' : 'text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-950/60 border-amber-200 dark:border-amber-800'
                            }`}
                        >
                            <Key size={12} />{apiKey ? maskKey(apiKey) : 'Atur Key'}
                        </button>
                        <button type="button" onClick={onClose} className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl cursor-pointer">
                            <X size={18} />
                        </button>
                    </div>
                </div>

                {/* API Key Editor Drawer */}
                {showKeyEditor && (
                    <div className="p-4 bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 space-y-2">
                        <div className="flex items-center justify-between gap-2">
                            <p className="text-xs font-bold text-slate-700 dark:text-slate-200 flex items-center gap-1.5">
                                <ShieldCheck size={13} className="text-emerald-500" /> Tersimpan hanya di browser Anda (localStorage)
                            </p>
                            <a href="https://aistudio.google.com/app/apikey" target="_blank" rel="noreferrer" className="text-[11px] text-teal-600 dark:text-teal-400 font-bold flex items-center gap-1 hover:underline">
                                Dapatkan Key Gratis <ExternalLink size={11} />
                            </a>
                        </div>
                        <form onSubmit={handleSaveKey} className="flex gap-2">
                            <div className="relative flex-1">
                                <input
                                    type={showPassword ? 'text' : 'password'}
                                    value={inputKey}
                                    onChange={e => setInputKey(e.target.value)}
                                    placeholder="AIzaSy..."
                                    className="w-full pl-3 pr-9 py-2 bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-500 text-slate-900 dark:text-white"
                                />
                                <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 cursor-pointer">
                                    {showPassword ? <EyeOff size={14} /> : <Eye size={14} />}
                                </button>
                            </div>
                            <button type="submit" className="px-3 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold cursor-pointer flex items-center gap-1">
                                <Check size={13} /> Simpan
                            </button>
                            {apiKey && (
                                <button type="button" onClick={() => { removeGeminiApiKey(); setApiKey(''); setInputKey(''); setShowKeyEditor(true); }} className="px-2.5 py-2 border border-red-200 dark:border-red-900 text-red-500 rounded-xl text-xs cursor-pointer">
                                    <Trash2 size={13} />
                                </button>
                            )}
                        </form>
                    </div>
                )}

                {/* Content */}
                <div className="flex-1 overflow-y-auto p-6 space-y-4">
                    {error && (
                        <div className="p-3.5 bg-red-50 dark:bg-red-950/60 border border-red-200 dark:border-red-900 rounded-2xl flex items-start gap-2.5 text-xs text-red-700 dark:text-red-300">
                            <AlertCircle size={15} className="shrink-0 mt-0.5" />
                            <span>{error}</span>
                        </div>
                    )}

                    {!previews ? (
                        <div className="space-y-4">
                            {/* Deskripsi / Topik Form */}
                            <div className="space-y-1.5">
                                <label className="text-xs font-extrabold text-slate-800 dark:text-slate-200">
                                    Deskripsi / Topik Formulir <span className="text-red-500">*</span>
                                </label>
                                <textarea
                                    rows={3}
                                    value={prompt}
                                    onChange={e => setPrompt(e.target.value)}
                                    placeholder="Contoh: Kuis Ujian Akhir Semester Fisika SMA Kelas 11 materi Termodinamika & Gelombang Bunyi."
                                    className="w-full px-4 py-3 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-2xl text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    disabled={generating}
                                />
                            </div>

                            {/* B6: Model Selector & Difficulty & Form Counts */}
                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                                {/* Model AI */}
                                <div className="space-y-1">
                                    <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1">
                                        <Cpu size={12} className="text-teal-600" /> Model AI
                                    </label>
                                    <select
                                        value={selectedModel}
                                        onChange={e => setSelectedModel(e.target.value)}
                                        disabled={generating}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl text-xs text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500 font-medium"
                                    >
                                        {AVAILABLE_MODELS.map(m => (
                                            <option key={m.id} value={m.id}>{m.name} ({m.badge})</option>
                                        ))}
                                    </select>
                                </div>

                                {/* Tingkat Kesulitan */}
                                <div className="space-y-1">
                                    <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300">Kesulitan</label>
                                    <select
                                        value={difficulty}
                                        onChange={e => setDifficulty(e.target.value)}
                                        disabled={generating}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl text-xs text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500 font-medium"
                                    >
                                        <option value="Mudah">Mudah</option>
                                        <option value="Sedang">Sedang</option>
                                        <option value="Sulit">Sulit (HOTS)</option>
                                    </select>
                                </div>

                                {/* Tipe Soal */}
                                <div className="space-y-1">
                                    <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300">Tipe Soal</label>
                                    <select
                                        value={typePreference}
                                        onChange={e => setTypePreference(e.target.value)}
                                        disabled={generating}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl text-xs text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500 font-medium"
                                    >
                                        <option value="2">Pilihan Ganda (PG)</option>
                                        <option value="1">Essay / Isian</option>
                                        <option value="5">Benar / Salah</option>
                                        <option value="3">Checkbox / Majemuk</option>
                                        <option value="mixed">Campuran</option>
                                    </select>
                                </div>
                            </div>

                            {/* B5: Jumlah Form & Jumlah Soal */}
                            <div className="grid grid-cols-2 gap-3">
                                <div className="space-y-1">
                                    <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1">
                                        <Layers size={12} className="text-teal-600" /> Jumlah Form Dibuat
                                    </label>
                                    <div className="flex items-center gap-1.5">
                                        {[1, 2, 3, 5].map(cnt => (
                                            <button
                                                key={cnt}
                                                type="button"
                                                onClick={() => setFormCount(cnt)}
                                                disabled={generating}
                                                className={`flex-1 py-1.5 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                                                    formCount === cnt
                                                        ? 'bg-teal-600 text-white border-teal-600 shadow-xs'
                                                        : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-teal-400'
                                                }`}
                                            >
                                                {cnt} {cnt > 1 ? 'Paket' : 'Form'}
                                            </button>
                                        ))}
                                    </div>
                                </div>

                                <div className="space-y-1">
                                    <label className="text-[11px] font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1">
                                        <FileText size={12} className="text-teal-600" /> Soal per Form
                                    </label>
                                    <div className="flex items-center gap-1.5">
                                        {[5, 10, 15, 20].map(cnt => (
                                            <button
                                                key={cnt}
                                                type="button"
                                                onClick={() => setQuestionCount(cnt)}
                                                disabled={generating}
                                                className={`flex-1 py-1.5 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                                                    questionCount === cnt
                                                        ? 'bg-teal-600 text-white border-teal-600 shadow-xs'
                                                        : 'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:border-teal-400'
                                                }`}
                                            >
                                                {cnt}
                                            </button>
                                        ))}
                                    </div>
                                </div>
                            </div>

                            {/* KaTeX & Code Toggle */}
                            <div className="flex items-center gap-2 flex-wrap pt-1">
                                <span className="text-[11px] text-slate-400 dark:text-slate-500 font-medium">Sertakan:</span>
                                <button
                                    type="button"
                                    onClick={() => setIncludeMath(prev => !prev)}
                                    disabled={generating}
                                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer disabled:opacity-50 ${
                                        includeMath
                                            ? 'bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300 border-teal-300 dark:border-teal-700'
                                            : 'bg-white dark:bg-slate-800 text-slate-500 dark:text-slate-400 border-slate-200 dark:border-slate-700 hover:border-teal-300 hover:text-teal-600'
                                    }`}
                                >
                                    <Calculator size={13} />
                                    <span>Rumus (KaTeX)</span>
                                    {includeMath && <span className="w-1.5 h-1.5 rounded-full bg-teal-500 shrink-0" />}
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setIncludeCode(prev => !prev)}
                                    disabled={generating}
                                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer disabled:opacity-50 ${
                                        includeCode
                                            ? 'bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border-indigo-300 dark:border-indigo-700'
                                            : 'bg-white dark:bg-slate-800 text-slate-500 dark:text-slate-400 border-slate-200 dark:border-slate-700 hover:border-indigo-300 hover:text-indigo-600'
                                    }`}
                                >
                                    <Code size={13} />
                                    <span>Code Block</span>
                                    {includeCode && <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 shrink-0" />}
                                </button>
                            </div>

                            {/* B8: Materi Referensi Tambahan (Accordion) */}
                            <div className="pt-1">
                                <button
                                    type="button"
                                    onClick={() => setShowAdvanced(!showAdvanced)}
                                    className="flex items-center gap-1.5 text-xs font-bold text-slate-600 dark:text-slate-300 hover:text-teal-600 transition-colors cursor-pointer"
                                >
                                    {showAdvanced ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                                    <span>Opsi Tambahan: Sisipkan Materi / Teks Rujukan (B8)</span>
                                </button>
                                {showAdvanced && (
                                    <div className="mt-2 space-y-1.5 animate-in fade-in duration-200">
                                        <p className="text-[11px] text-slate-400 dark:text-slate-500">
                                            Tempel rangkuman materi, silabus, atau bahan ajar. AI akan membuat soal spesifik berdasarkan materi ini:
                                        </p>
                                        <textarea
                                            rows={4}
                                            value={contextText}
                                            onChange={e => setContextText(e.target.value)}
                                            placeholder="Tempel teks materi, modul ajar, atau referensi bacaan di sini..."
                                            className="w-full px-3.5 py-2.5 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                                            disabled={generating}
                                        />
                                    </div>
                                )}
                            </div>

                            {generating && (
                                <div className="p-4 rounded-2xl bg-teal-50 dark:bg-teal-950/50 border border-teal-200 dark:border-teal-800 flex items-center gap-3">
                                    <Loader2 size={22} className="animate-spin text-[#00897B] shrink-0" />
                                    <div>
                                        <p className="text-xs font-extrabold text-teal-900 dark:text-teal-100">{status}</p>
                                        <p className="text-[11px] text-teal-600 dark:text-teal-400 flex items-center gap-1 mt-0.5">
                                            <Clock size={11} /> {elapsed} detik
                                        </p>
                                    </div>
                                </div>
                            )}
                        </div>
                    ) : (
                        // Preview Mode (B6)
                        <div className="space-y-4">
                            <div className="flex items-center justify-between">
                                <div>
                                    <p className="text-xs font-extrabold text-slate-800 dark:text-slate-200">✨ Form Siap Ditinjau</p>
                                    <p className="text-[11px] text-slate-400">{previews.length} formulir dihasilkan</p>
                                </div>
                                <button
                                    type="button"
                                    onClick={() => setPreviews(null)}
                                    className="text-xs font-bold text-teal-600 dark:text-teal-400 hover:underline flex items-center gap-1 cursor-pointer"
                                >
                                    <RotateCcw size={13} /> Buat Ulang
                                </button>
                            </div>

                            {/* Multi-form Tab Selector if > 1 */}
                            {previews.length > 1 && (
                                <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
                                    {previews.map((p, idx) => (
                                        <button
                                            key={idx}
                                            type="button"
                                            onClick={() => setActivePreviewIdx(idx)}
                                            className={`px-3 py-1.5 text-xs font-bold rounded-xl border transition-all cursor-pointer whitespace-nowrap ${
                                                activePreviewIdx === idx
                                                    ? 'bg-teal-600 text-white border-teal-600 shadow-xs'
                                                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700'
                                            }`}
                                        >
                                            Paket {idx + 1}: {p.title.slice(0, 18)}...
                                        </button>
                                    ))}
                                </div>
                            )}

                            {currentPreview && (
                                <>
                                    <div className="p-4 bg-teal-50/50 dark:bg-teal-950/30 border border-teal-200/60 dark:border-teal-800/60 rounded-2xl space-y-1">
                                        <p className="text-sm font-extrabold text-slate-900 dark:text-white">{currentPreview.title}</p>
                                        {currentPreview.description && (
                                            <p className="text-xs text-slate-500 dark:text-slate-400">{currentPreview.description}</p>
                                        )}
                                    </div>
                                    <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
                                        {currentPreview.questions?.map((q, i) => {
                                            const typeLabels = { 1: 'Essay', 2: 'Pilihan Ganda', 3: 'Checkbox', 5: 'Benar/Salah' };
                                            const typeColors = {
                                                1: 'bg-blue-50 text-blue-700 dark:bg-blue-950/50 dark:text-blue-300',
                                                2: 'bg-teal-50 text-teal-700 dark:bg-teal-950/50 dark:text-teal-300',
                                                3: 'bg-indigo-50 text-indigo-700 dark:bg-indigo-950/50 dark:text-indigo-300',
                                                5: 'bg-amber-50 text-amber-700 dark:bg-amber-950/50 dark:text-amber-300'
                                            };
                                            return (
                                                <div key={i} className="p-3 bg-white dark:bg-slate-800 rounded-xl border border-slate-200/70 dark:border-slate-700 space-y-1.5">
                                                    <div className="flex items-start gap-2">
                                                        <span className="text-[10px] font-extrabold bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-1.5 py-0.5 rounded shrink-0">{i + 1}</span>
                                                        <span className={`text-[10px] font-extrabold px-1.5 py-0.5 rounded shrink-0 ${typeColors[q.typeId] || 'bg-slate-100 text-slate-600'}`}>{typeLabels[q.typeId] || 'Soal'}</span>
                                                    </div>
                                                    <div className="text-xs font-bold text-slate-800 dark:text-slate-100 leading-relaxed pl-2">
                                                        <RichContentRenderer content={q.question} />
                                                    </div>
                                                    {q.options && q.options.length > 0 && (
                                                        <div className="pl-2 grid grid-cols-2 gap-1">
                                                            {q.options.map((o, oi) => (
                                                                <div key={oi} className={`text-[11px] px-2 py-0.5 rounded-lg flex items-start gap-1 ${o.isCorrect ? 'bg-emerald-50 dark:bg-emerald-950/50 text-emerald-700 dark:text-emerald-300 font-bold' : 'text-slate-600 dark:text-slate-400'}`}>
                                                                    <span className="shrink-0">{String.fromCharCode(65 + oi)}.</span>
                                                                    <span><RichContentRenderer content={o.optionText} /></span>
                                                                    {o.isCorrect && <span className="text-emerald-500 shrink-0">✓</span>}
                                                                </div>
                                                            ))}
                                                        </div>
                                                    )}
                                                </div>
                                            );
                                        })}
                                    </div>
                                </>
                            )}
                        </div>
                    )}
                </div>

                {/* Footer */}
                <div className="px-6 py-4 bg-slate-50 dark:bg-slate-800/50 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                    <div className="text-xs text-slate-400">
                        {apiKey ? (
                            <span className="text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1">
                                <CheckCircle2 size={13} /> {maskKey(apiKey)}
                            </span>
                        ) : (
                            <span className="text-amber-600 font-bold">⚠ Harap atur API Key</span>
                        )}
                    </div>
                    <div className="flex items-center gap-2">
                        <button type="button" onClick={onClose} className="px-4 py-2.5 text-xs font-bold text-slate-600 dark:text-slate-400 hover:text-slate-900 rounded-xl cursor-pointer">
                            Batal
                        </button>
                        {!previews ? (
                            <button
                                type="button"
                                onClick={handleGenerate}
                                disabled={generating || (!prompt.trim() && !contextText.trim())}
                                className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold flex items-center gap-2 cursor-pointer disabled:opacity-60"
                            >
                                {generating ? (
                                    <><Loader2 size={14} className="animate-spin" /> {status || `Membuat... (${elapsed}s)`}</>
                                ) : (
                                    <><Sparkles size={14} /> Generate {formCount > 1 ? `${formCount} Paket Form` : 'Form'}</>
                                )}
                            </button>
                        ) : (
                            <button
                                type="button"
                                onClick={handleCreateForms}
                                disabled={creating}
                                className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold flex items-center gap-2 cursor-pointer disabled:opacity-60"
                            >
                                {creating ? (
                                    <><Loader2 size={14} className="animate-spin" /> Menyimpan Form ({elapsed}s)...</>
                                ) : (
                                    <><CheckCircle2 size={14} /> Simpan {previews.length > 1 ? `${previews.length} Form Ini` : 'Form Ini'}</>
                                )}
                            </button>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

