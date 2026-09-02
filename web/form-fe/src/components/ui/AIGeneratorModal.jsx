import { useState, useEffect } from 'react';
import {
    Sparkles,
    X,
    Loader2,
    CheckCircle2,
    Key,
    BookOpen,
    HelpCircle,
    Check,
    Settings,
    AlertCircle,
    Sliders,
    Code,
    Calculator,
    ArrowRight,
    RotateCcw,
    Eye,
    EyeOff,
    ExternalLink,
    Trash2,
    ShieldCheck
} from 'lucide-react';
import { generateQuestionsWithAI, getGeminiApiKey, saveGeminiApiKey, removeGeminiApiKey } from '../../services/aiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function AIGeneratorModal({ isOpen, onClose, onAddQuestions, formTitle = '' }) {
    const [step, setStep] = useState('config'); // 'config' | 'preview'
    const [topic, setTopic] = useState(formTitle || '');
    const [contextText, setContextText] = useState('');
    const [count, setCount] = useState(5);
    const [typePreference, setTypePreference] = useState('2'); // '2' = MCQ, '1' = Essay, '5' = T/F, '3' = Checkbox, 'mixed' = Mixed
    const [difficulty, setDifficulty] = useState('Sedang');
    const [includeMath, setIncludeMath] = useState(false);
    const [includeCode, setIncludeCode] = useState(false);

    // API Key config (Cached in localStorage ONLY, never stored in DB)
    const [apiKey, setApiKey] = useState('');
    const [inputKey, setInputKey] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showKeyEditor, setShowKeyEditor] = useState(false);
    const [keySavedToast, setKeySavedToast] = useState(false);

    // Generation state
    const [generating, setGenerating] = useState(false);
    const [error, setError] = useState(null);
    const [generatedQuestions, setGeneratedQuestions] = useState([]);
    const [selectedIndices, setSelectedIndices] = useState([]);
    const [modelUsed, setModelUsed] = useState('');

    useEffect(() => {
        if (isOpen) {
            setStep('config');
            setError(null);
            const saved = getGeminiApiKey();
            setApiKey(saved);
            setInputKey(saved);
            setShowKeyEditor(!saved); // Open key setup automatically if no key is saved
            if (!topic && formTitle) setTopic(formTitle);
        }
    }, [isOpen, formTitle]);

    if (!isOpen) return null;

    const handleSaveKey = (e) => {
        if (e) e.preventDefault();
        const trimmed = inputKey.trim();
        if (!trimmed) {
            setError('Masukkan Gemini API Key yang valid.');
            return;
        }
        saveGeminiApiKey(trimmed);
        setApiKey(trimmed);
        setShowKeyEditor(false);
        setError(null);
        setKeySavedToast(true);
        setTimeout(() => setKeySavedToast(false), 3000);
    };

    const handleRemoveKey = () => {
        removeGeminiApiKey();
        setApiKey('');
        setInputKey('');
        setShowKeyEditor(true);
    };

    const handleGenerate = async (e) => {
        if (e) e.preventDefault();
        
        const currentKey = apiKey.trim();
        if (!currentKey) {
            setShowKeyEditor(true);
            setError('Silakan masukkan Google Gemini API Key Anda terlebih dahulu.');
            return;
        }

        if (!topic.trim() && !contextText.trim()) {
            setError('Harap masukkan topik soal atau teks referensi materi.');
            return;
        }

        setError(null);
        setGenerating(true);

        const res = await generateQuestionsWithAI({
            topic: topic.trim(),
            contextText: contextText.trim(),
            count: parseInt(count, 10) || 5,
            typePreference,
            difficulty,
            includeMath,
            includeCode,
            customApiKey: currentKey,
        });

        setGenerating(false);

        if (res.ok && res.data && res.data.length > 0) {
            setGeneratedQuestions(res.data);
            setModelUsed(res.modelUsed || 'gemini-2.5-flash');
            // Select all by default
            setSelectedIndices(res.data.map((_, i) => i));
            setStep('preview');
        } else {
            setError(res.message || 'Gagal menghasilkan soal dari AI. Pastikan API Key Anda aktif dan memiliki kuota.');
        }
    };

    const toggleSelect = (index) => {
        setSelectedIndices(prev =>
            prev.includes(index) ? prev.filter(i => i !== index) : [...prev, index]
        );
    };

    const toggleSelectAll = () => {
        if (selectedIndices.length === generatedQuestions.length) {
            setSelectedIndices([]);
        } else {
            setSelectedIndices(generatedQuestions.map((_, i) => i));
        }
    };

    const handleImportToForm = () => {
        const selected = generatedQuestions.filter((_, i) => selectedIndices.includes(i));
        if (selected.length === 0) return;
        onAddQuestions(selected);
        onClose();
    };

    const typeLabels = {
        1: 'Essay',
        2: 'Pilihan Ganda',
        3: 'Checkbox',
        5: 'Benar / Salah'
    };

    const maskKey = (key) => {
        if (!key || key.length < 8) return '****';
        return `${key.substring(0, 6)}...${key.substring(key.length - 4)}`;
    };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            {/* Backdrop */}
            <div
                className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs transition-opacity animate-in fade-in"
                onClick={onClose}
            />

            {/* Modal Dialog */}
            <div className="relative bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl w-full max-w-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh] z-10 animate-in fade-in zoom-in-95 duration-200">
                
                {/* Header */}
                <div className="px-6 py-4.5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between bg-gradient-to-r from-teal-500/10 via-emerald-500/5 to-transparent">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-teal-600 to-emerald-400 text-white flex items-center justify-center shadow-md shadow-teal-500/20">
                            <Sparkles size={20} className="animate-pulse" />
                        </div>
                        <div>
                            <h2 className="text-base font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                                AI Quiz & Question Generator
                                <span className="text-[10px] uppercase tracking-wider font-extrabold px-2 py-0.5 rounded-full bg-teal-500/15 text-teal-600 dark:text-teal-400 border border-teal-500/20">
                                    Gemini AI
                                </span>
                            </h2>
                            <p className="text-xs text-slate-500 dark:text-slate-400">
                                Buat puluhan soal otomatis dalam hitungan detik berdasarkan topik atau materi.
                            </p>
                        </div>
                    </div>

                    <div className="flex items-center gap-1.5">
                        <button
                            type="button"
                            onClick={() => setShowKeyEditor(!showKeyEditor)}
                            title="Konfigurasi API Key"
                            className={`p-2 rounded-xl transition-all cursor-pointer flex items-center gap-1.5 text-xs font-bold ${
                                apiKey
                                    ? 'text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950/50 hover:bg-teal-100'
                                    : 'text-amber-600 dark:text-amber-400 bg-amber-50 dark:bg-amber-950/50 hover:bg-amber-100'
                            }`}
                        >
                            <Key size={15} />
                            <span className="hidden sm:inline">{apiKey ? 'Key Aktif' : 'Setup Key'}</span>
                        </button>
                        <button
                            type="button"
                            onClick={onClose}
                            className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all cursor-pointer"
                        >
                            <X size={18} />
                        </button>
                    </div>
                </div>

                {/* API Key Setup / Editor Card */}
                {showKeyEditor && (
                    <div className="p-5 bg-gradient-to-b from-slate-50 to-white dark:from-slate-800/80 dark:to-slate-900 border-b border-slate-200 dark:border-slate-800 space-y-3.5 animate-in slide-in-from-top-2 duration-150">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                            <div className="flex items-center gap-2">
                                <span className="p-1.5 rounded-lg bg-teal-500/10 text-teal-600 dark:text-teal-400">
                                    <Key size={15} />
                                </span>
                                <div>
                                    <h3 className="text-xs font-extrabold text-slate-900 dark:text-white">
                                        Google Gemini API Key
                                    </h3>
                                    <p className="text-[11px] text-slate-500 dark:text-slate-400 flex items-center gap-1">
                                        <ShieldCheck size={12} className="text-emerald-500" />
                                        Disimpan lokal di browser (localStorage) — tidak disimpan ke database.
                                    </p>
                                </div>
                            </div>
                            <a
                                href="https://aistudio.google.com/app/apikey"
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 text-[11px] text-teal-600 dark:text-teal-400 hover:underline font-bold bg-teal-50 dark:bg-teal-950/40 px-2.5 py-1 rounded-lg border border-teal-200/60 dark:border-teal-800"
                            >
                                Dapatkan API Key Gratis di Google AI Studio <ExternalLink size={11} />
                            </a>
                        </div>

                        <form onSubmit={handleSaveKey} className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                            <div className="relative flex-1">
                                <input
                                    type={showPassword ? 'text' : 'password'}
                                    value={inputKey}
                                    onChange={(e) => setInputKey(e.target.value)}
                                    placeholder="Tempel Gemini API Key di sini (AIzaSy...)"
                                    className="w-full pl-3.5 pr-10 py-2.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-mono text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
                                    required
                                />
                                <button
                                    type="button"
                                    onClick={() => setShowPassword(!showPassword)}
                                    className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer"
                                >
                                    {showPassword ? <EyeOff size={14} /> : <Eye size={14} />}
                                </button>
                            </div>

                            <div className="flex items-center gap-2">
                                <button
                                    type="submit"
                                    className="flex-1 sm:flex-initial px-4 py-2.5 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-1.5 shadow-xs"
                                >
                                    <Check size={14} /> Simpan Key di Browser
                                </button>
                                {apiKey && (
                                    <button
                                        type="button"
                                        onClick={handleRemoveKey}
                                        title="Hapus Key dari Browser"
                                        className="px-3 py-2.5 border border-red-200 dark:border-red-900/60 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center"
                                    >
                                        <Trash2 size={14} />
                                    </button>
                                )}
                            </div>
                        </form>
                    </div>
                )}

                {/* Toast Notification */}
                {keySavedToast && (
                    <div className="px-6 py-2 bg-emerald-50 dark:bg-emerald-950/60 border-b border-emerald-200 dark:border-emerald-800 text-xs text-emerald-700 dark:text-emerald-300 font-bold flex items-center gap-2">
                        <CheckCircle2 size={14} />
                        <span>API Key berhasil disimpan di cache browser Anda!</span>
                    </div>
                )}

                {/* Body Content */}
                <div className="flex-1 overflow-y-auto p-6 space-y-5">
                    
                    {error && (
                        <div className="p-3.5 bg-red-50 dark:bg-red-950/60 border border-red-200 dark:border-red-900 rounded-2xl flex items-start gap-2.5 text-xs text-red-600 dark:text-red-400">
                            <AlertCircle size={16} className="shrink-0 mt-0.5" />
                            <div className="flex-1">
                                <p className="font-bold">Gagal Membuat Soal</p>
                                <p className="mt-0.5 opacity-90">{error}</p>
                            </div>
                        </div>
                    )}

                    {step === 'config' ? (
                        <form onSubmit={handleGenerate} className="space-y-4.5">
                            
                            {/* Topik Soal */}
                            <div className="space-y-1.5">
                                <label className="text-xs font-extrabold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                                    <BookOpen size={14} className="text-teal-500" /> Topik / Judul Materi Soal <span className="text-red-500">*</span>
                                </label>
                                <input
                                    type="text"
                                    value={topic}
                                    onChange={(e) => setTopic(e.target.value)}
                                    placeholder="Contoh: Tata Surya & Planet, Pemrograman Python Dasar, Sejarah Kemerdekaan RI..."
                                    className="w-full px-4 py-3 bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-2xl text-xs sm:text-sm text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500 font-medium"
                                    required
                                />
                            </div>

                            {/* Teks Rangkuman / Referensi (Opsional) */}
                            <div className="space-y-1.5">
                                <label className="text-xs font-bold text-slate-700 dark:text-slate-300 flex items-center justify-between">
                                    <span>Teks / Catatan Materi Tambahan (Opsional)</span>
                                    <span className="text-[11px] text-slate-400">Paste artikel / rangkuman materi</span>
                                </label>
                                <textarea
                                    value={contextText}
                                    onChange={(e) => setContextText(e.target.value)}
                                    rows={3}
                                    placeholder="Tempelkan paragraf, ringkasan bab, atau modul belajar di sini agar AI membuat soal persis dari teks ini..."
                                    className="w-full px-4 py-2.5 bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-2xl text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500 resize-y"
                                />
                            </div>

                            {/* Grid Setting: Jumlah, Tipe, Kesulitan */}
                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5 pt-1">
                                
                                {/* Jumlah Soal */}
                                <div className="space-y-1.5">
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Jumlah Soal
                                    </label>
                                    <div className="flex items-center gap-1 bg-slate-50 dark:bg-slate-800/50 p-1 border border-slate-200 dark:border-slate-700 rounded-xl">
                                        {[3, 5, 10, 15].map(num => (
                                            <button
                                                key={num}
                                                type="button"
                                                onClick={() => setCount(num)}
                                                className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                                                    count === num
                                                        ? 'bg-white dark:bg-slate-700 text-teal-600 dark:text-teal-300 shadow-xs'
                                                        : 'text-slate-500 hover:text-slate-900 dark:text-slate-400'
                                                }`}
                                            >
                                                {num}
                                            </button>
                                        ))}
                                    </div>
                                </div>

                                {/* Tipe Soal */}
                                <div className="space-y-1.5">
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Format Soal
                                    </label>
                                    <select
                                        value={typePreference}
                                        onChange={(e) => setTypePreference(e.target.value)}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500"
                                    >
                                        <option value="2">Pilihan Ganda (MCQ)</option>
                                        <option value="1">Essay / Isian Singkat</option>
                                        <option value="5">Benar / Salah (True/False)</option>
                                        <option value="3">Checkbox (Multi-pilihan)</option>
                                        <option value="mixed">Campuran (Variasi)</option>
                                    </select>
                                </div>

                                {/* Tingkat Kesulitan */}
                                <div className="space-y-1.5">
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Tingkat Kesulitan
                                    </label>
                                    <select
                                        value={difficulty}
                                        onChange={(e) => setDifficulty(e.target.value)}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-teal-500"
                                    >
                                        <option value="Mudah">Mudah</option>
                                        <option value="Sedang">Sedang</option>
                                        <option value="Sulit (HOTS)">Sulit (HOTS)</option>
                                    </select>
                                </div>
                            </div>

                            {/* Fitur Tambahan (Math & Code) */}
                            <div className="pt-2 flex flex-wrap items-center gap-4 border-t border-slate-100 dark:border-slate-800">
                                <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-slate-700 dark:text-slate-300">
                                    <input
                                        type="checkbox"
                                        checked={includeMath}
                                        onChange={(e) => setIncludeMath(e.target.checked)}
                                        className="w-4 h-4 rounded text-teal-600 focus:ring-teal-500 border-slate-300"
                                    />
                                    <span className="flex items-center gap-1">
                                        <Calculator size={13} className="text-amber-500" /> Sertakan Rumus Matematika (LaTeX)
                                    </span>
                                </label>

                                <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-slate-700 dark:text-slate-300">
                                    <input
                                        type="checkbox"
                                        checked={includeCode}
                                        onChange={(e) => setIncludeCode(e.target.checked)}
                                        className="w-4 h-4 rounded text-teal-600 focus:ring-teal-500 border-slate-300"
                                    />
                                    <span className="flex items-center gap-1">
                                        <Code size={13} className="text-sky-500" /> Sertakan Kode Pemrograman
                                    </span>
                                </label>
                            </div>

                        </form>
                    ) : (
                        /* Preview Generated Questions */
                        <div className="space-y-4">
                            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-800">
                                <div className="flex items-center gap-2">
                                    <span className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Hasil: {generatedQuestions.length} Soal Dibuat
                                    </span>
                                    <span className="text-[11px] px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400">
                                        {selectedIndices.length} dipilih
                                    </span>
                                </div>
                                <button
                                    type="button"
                                    onClick={toggleSelectAll}
                                    className="text-xs text-teal-600 dark:text-teal-400 font-bold hover:underline cursor-pointer"
                                >
                                    {selectedIndices.length === generatedQuestions.length ? 'Batal Pilih Semua' : 'Pilih Semua'}
                                </button>
                            </div>

                            <div className="space-y-3.5 max-h-[50vh] overflow-y-auto pr-1">
                                {generatedQuestions.map((q, idx) => {
                                    const isSelected = selectedIndices.includes(idx);
                                    return (
                                        <div
                                            key={idx}
                                            onClick={() => toggleSelect(idx)}
                                            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
                                                isSelected
                                                    ? 'bg-teal-50/50 dark:bg-teal-950/20 border-teal-300 dark:border-teal-800 shadow-xs'
                                                    : 'bg-slate-50/60 dark:bg-slate-800/40 border-slate-200 dark:border-slate-700 opacity-60'
                                            }`}
                                        >
                                            <div className="flex items-start gap-3">
                                                <input
                                                    type="checkbox"
                                                    checked={isSelected}
                                                    onChange={() => toggleSelect(idx)}
                                                    onClick={(e) => e.stopPropagation()}
                                                    className="w-4 h-4 mt-1 rounded text-teal-600 focus:ring-teal-500 border-slate-300 cursor-pointer"
                                                />
                                                <div className="flex-1 min-w-0 space-y-2">
                                                    <div className="flex items-center gap-2">
                                                        <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-md bg-slate-200/80 dark:bg-slate-700 text-slate-700 dark:text-slate-200">
                                                            Soal {idx + 1}
                                                        </span>
                                                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-md bg-teal-100 dark:bg-teal-900/60 text-teal-700 dark:text-teal-300">
                                                            {typeLabels[q.typeId] || 'Pilihan Ganda'}
                                                        </span>
                                                        {q.points !== null && q.points !== undefined && (
                                                            <span className="text-[10px] text-slate-400 font-medium">
                                                                {q.points} Poin
                                                            </span>
                                                        )}
                                                    </div>

                                                    <div className="text-xs sm:text-sm font-bold text-slate-900 dark:text-white leading-relaxed">
                                                        <RichContentRenderer content={q.question} />
                                                    </div>

                                                    {/* Options or Answer */}
                                                    {[2, 3].includes(q.typeId) && q.options?.length > 0 && (
                                                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5 pt-1">
                                                            {q.options.map((opt, oIdx) => (
                                                                <div
                                                                    key={oIdx}
                                                                    className={`px-3 py-1.5 rounded-xl text-xs flex items-center gap-2 ${
                                                                        opt.isCorrect
                                                                            ? 'bg-emerald-100/70 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 font-bold border border-emerald-300 dark:border-emerald-800'
                                                                            : 'bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 border border-slate-200/60 dark:border-slate-700'
                                                                    }`}
                                                                >
                                                                    <span className="shrink-0 w-4 h-4 rounded-full flex items-center justify-center text-[10px] font-bold bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
                                                                        {String.fromCharCode(65 + oIdx)}
                                                                    </span>
                                                                    <span className="truncate flex-1">{opt.optionText}</span>
                                                                    {opt.isCorrect && <Check size={12} className="text-emerald-600 dark:text-emerald-400 shrink-0" />}
                                                                </div>
                                                            ))}
                                                        </div>
                                                    )}

                                                    {q.typeId === 5 && (
                                                        <div className="text-xs text-slate-600 dark:text-slate-400 pt-1">
                                                            Kunci Jawaban: <span className="font-bold text-teal-600 dark:text-teal-400">{q.correctAnswer || 'Benar'}</span>
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                </div>

                {/* Footer */}
                <div className="px-6 py-4 bg-slate-50 dark:bg-slate-800/40 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                    {step === 'config' ? (
                        <>
                            <div className="text-xs text-slate-400 dark:text-slate-500">
                                {apiKey ? (
                                    <span className="flex items-center gap-1.5 text-emerald-600 dark:text-emerald-400 font-bold">
                                        <CheckCircle2 size={13} /> Key: {maskKey(apiKey)}
                                    </span>
                                ) : (
                                    <span className="text-amber-600 dark:text-amber-400 font-bold">
                                        ⚠️ Masukkan API Key terlebih dahulu
                                    </span>
                                )}
                            </div>
                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    onClick={onClose}
                                    disabled={generating}
                                    className="px-4 py-2.5 text-xs font-bold text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white rounded-xl transition-all cursor-pointer disabled:opacity-50"
                                >
                                    Batal
                                </button>
                                <button
                                    type="button"
                                    onClick={handleGenerate}
                                    disabled={generating || (!topic.trim() && !contextText.trim())}
                                    className="px-6 py-2.5 bg-gradient-to-r from-teal-600 to-emerald-500 hover:from-teal-700 hover:to-emerald-600 text-white rounded-xl text-xs font-bold shadow-md shadow-teal-500/20 flex items-center gap-2 transition-all cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                                >
                                    {generating ? (
                                        <>
                                            <Loader2 size={15} className="animate-spin" />
                                            <span>Menghasilkan Soal AI...</span>
                                        </>
                                    ) : (
                                        <>
                                            <Sparkles size={15} />
                                            <span>Generate {count} Soal Sekarang</span>
                                        </>
                                    )}
                                </button>
                            </div>
                        </>
                    ) : (
                        <>
                            <button
                                type="button"
                                onClick={() => setStep('config')}
                                className="px-4 py-2 text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-200/60 dark:hover:bg-slate-700 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer"
                            >
                                <RotateCcw size={14} /> Atur Ulang
                            </button>
                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    onClick={onClose}
                                    className="px-4 py-2.5 text-xs font-bold text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white rounded-xl transition-all cursor-pointer"
                                >
                                    Tutup
                                </button>
                                <button
                                    type="button"
                                    onClick={handleImportToForm}
                                    disabled={selectedIndices.length === 0}
                                    className="px-6 py-2.5 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold shadow-md shadow-teal-500/20 flex items-center gap-2 transition-all cursor-pointer disabled:opacity-50"
                                >
                                    <CheckCircle2 size={15} />
                                    <span>Tambahkan {selectedIndices.length} Soal ke Form</span>
                                </button>
                            </div>
                        </>
                    )}
                </div>

            </div>
        </div>
    );
}
