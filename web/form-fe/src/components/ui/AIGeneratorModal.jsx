import { useState, useEffect, useRef } from 'react';
import {
    Sparkles,
    X,
    Loader2,
    CheckCircle2,
    Key,
    BookOpen,
    Check,
    AlertCircle,
    Code,
    Calculator,
    RotateCcw,
    Eye,
    EyeOff,
    ExternalLink,
    Trash2,
    ShieldCheck,
    Cpu,
    Clock,
    ChevronDown,
    ChevronUp,
    FileText
} from 'lucide-react';
import {
    generateQuestionsWithAI,
    getGeminiApiKey,
    saveGeminiApiKey,
    removeGeminiApiKey,
    AVAILABLE_MODELS
} from '../../services/aiService';
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
    const [showAdvanced, setShowAdvanced] = useState(false);
    const [selectedModel, setSelectedModel] = useState('gemini-2.5-flash');

    // API Key config (Cached in localStorage ONLY, never sent to database)
    const [apiKey, setApiKey] = useState('');
    const [inputKey, setInputKey] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showKeyEditor, setShowKeyEditor] = useState(false);
    const [keySavedToast, setKeySavedToast] = useState(false);

    // Generation state & Friendly status
    const [generating, setGenerating] = useState(false);
    const [statusMessage, setStatusMessage] = useState('');
    const [elapsedSeconds, setElapsedSeconds] = useState(0);
    const [error, setError] = useState(null);
    const [generatedQuestions, setGeneratedQuestions] = useState([]);
    const [selectedIndices, setSelectedIndices] = useState([]);
    const [resultInfo, setResultInfo] = useState({ model: '', time: '' });

    const timerIntervalRef = useRef(null);

    useEffect(() => {
        if (isOpen) {
            setStep('config');
            setError(null);
            setStatusMessage('');
            setElapsedSeconds(0);
            const saved = getGeminiApiKey();
            setApiKey(saved);
            setInputKey(saved);
            setShowKeyEditor(!saved); // Open key setup automatically if no key is saved
            if (!topic && formTitle) setTopic(formTitle);
        }
    }, [isOpen, formTitle]);

    // Timer counter when generating
    useEffect(() => {
        if (generating) {
            setElapsedSeconds(0);
            timerIntervalRef.current = setInterval(() => {
                setElapsedSeconds(prev => prev + 1);
            }, 1000);
        } else {
            if (timerIntervalRef.current) clearInterval(timerIntervalRef.current);
        }
        return () => {
            if (timerIntervalRef.current) clearInterval(timerIntervalRef.current);
        };
    }, [generating]);

    if (!isOpen) return null;

    const handleSaveKey = (e) => {
        if (e) e.preventDefault();
        const trimmed = inputKey.trim();
        if (!trimmed) {
            setError('Masukkan Gemini API Key yang valid dari Google AI Studio.');
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
            setError('Harap masukkan topik/materi soal yang ingin dibuat.');
            return;
        }

        setError(null);
        setGenerating(true);
        setStatusMessage('Menghubungkan ke Google AI Studio...');

        const res = await generateQuestionsWithAI({
            topic: topic.trim(),
            contextText: contextText.trim(),
            count: parseInt(count, 10) || 5,
            typePreference,
            difficulty,
            includeMath,
            includeCode,
            selectedModel,
            customApiKey: currentKey,
            onStatus: (msg) => setStatusMessage(msg),
        });

        setGenerating(false);

        if (res.ok && res.data && res.data.length > 0) {
            setGeneratedQuestions(res.data);
            setResultInfo({ model: res.modelUsed, time: res.elapsedSec });
            setSelectedIndices(res.data.map((_, i) => i)); // Select all by default
            setStep('preview');
        } else {
            setError(res.message || 'Gagal membuat soal. Periksa kembali koneksi atau API Key Anda.');
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
        1: 'Isian Singkat / Essay',
        2: 'Pilihan Ganda',
        3: 'Pilihan Majemuk (Checkbox)',
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
                className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs transition-opacity"
                onClick={onClose}
            />

            {/* Modal Dialog */}
            <div className="relative bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl w-full max-w-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh] z-10">
                
                {/* Header Sederhana & Ramah */}
                <div className="px-6 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between bg-gradient-to-r from-teal-500/10 via-emerald-500/5 to-transparent">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-2xl bg-[#00897B] text-white flex items-center justify-center shadow-md shadow-teal-500/20">
                            <Sparkles size={20} />
                        </div>
                        <div>
                            <h2 className="text-base font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                                Buat Soal Otomatis dengan AI
                            </h2>
                            <p className="text-xs text-slate-500 dark:text-slate-400">
                                Bantu guru & siswa membuat butir soal kuis secara instan dan rapi.
                            </p>
                        </div>
                    </div>

                    <div className="flex items-center gap-1.5">
                        <button
                            type="button"
                            onClick={() => setShowKeyEditor(!showKeyEditor)}
                            title="Pengaturan API Key"
                            className={`px-3 py-1.5 rounded-xl transition-all cursor-pointer flex items-center gap-1.5 text-xs font-bold ${
                                apiKey
                                    ? 'text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 hover:bg-teal-100 border border-teal-200 dark:border-teal-800'
                                    : 'text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-950/60 hover:bg-amber-100 border border-amber-200 dark:border-amber-800'
                            }`}
                        >
                            <Key size={13} />
                            <span>{apiKey ? 'API Key Aktif' : 'Atur API Key'}</span>
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

                {/* API Key Setup Panel */}
                {showKeyEditor && (
                    <div className="p-4 bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700/80 space-y-3">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                            <div>
                                <h3 className="text-xs font-extrabold text-slate-900 dark:text-white flex items-center gap-1.5">
                                    <Key size={14} className="text-teal-600" />
                                    Google Gemini API Key
                                </h3>
                                <p className="text-[11px] text-slate-500 dark:text-slate-400 flex items-center gap-1 mt-0.5">
                                    <ShieldCheck size={12} className="text-emerald-500" />
                                    Tersimpan aman di browser Anda (tidak disimpan ke server/database).
                                </p>
                            </div>
                            <a
                                href="https://aistudio.google.com/app/apikey"
                                target="_blank"
                                rel="noreferrer"
                                className="inline-flex items-center gap-1 text-[11px] text-teal-700 dark:text-teal-300 hover:underline font-bold bg-white dark:bg-slate-900 px-2.5 py-1 rounded-lg border border-teal-200 dark:border-teal-800"
                            >
                                Dapatkan Key Gratis di Google AI Studio <ExternalLink size={11} />
                            </a>
                        </div>

                        <form onSubmit={handleSaveKey} className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                            <div className="relative flex-1">
                                <input
                                    type={showPassword ? 'text' : 'password'}
                                    value={inputKey}
                                    onChange={(e) => setInputKey(e.target.value)}
                                    placeholder="Tempel API Key Google AI Studio di sini (AIzaSy...)"
                                    className="w-full pl-3.5 pr-10 py-2 bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-xs font-mono text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
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
                                    className="flex-1 sm:flex-initial px-4 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center gap-1.5"
                                >
                                    <Check size={14} /> Simpan
                                </button>
                                {apiKey && (
                                    <button
                                        type="button"
                                        onClick={handleRemoveKey}
                                        title="Hapus Key"
                                        className="px-3 py-2 border border-red-200 dark:border-red-900 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center"
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
                        <span>API Key tersimpan di browser!</span>
                    </div>
                )}

                {/* Body Content */}
                <div className="flex-1 overflow-y-auto p-6 space-y-5">
                    
                    {error && (
                        <div className="p-3.5 bg-red-50 dark:bg-red-950/60 border border-red-200 dark:border-red-900 rounded-2xl flex items-start gap-2.5 text-xs text-red-700 dark:text-red-300">
                            <AlertCircle size={16} className="shrink-0 mt-0.5" />
                            <div className="flex-1">
                                <p className="font-bold">Perhatian</p>
                                <p className="mt-0.5">{error}</p>
                            </div>
                        </div>
                    )}

                    {step === 'config' ? (
                        <form onSubmit={handleGenerate} className="space-y-4">
                            
                            {/* Topik / Materi Soal */}
                            <div className="space-y-1.5">
                                <label className="text-xs font-extrabold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                                    <BookOpen size={14} className="text-teal-600" />
                                    Materi / Topik Soal <span className="text-red-500">*</span>
                                </label>
                                <input
                                    type="text"
                                    value={topic}
                                    onChange={(e) => setTopic(e.target.value)}
                                    placeholder="Contoh: Fotosintesis, Hukum Newton, Tata Surya, Pemrograman Web Dasar..."
                                    className="w-full px-4 py-3 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-2xl text-xs sm:text-sm text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B] font-medium"
                                    required
                                    disabled={generating}
                                />
                            </div>

                            {/* Pengaturan Utama: Jumlah Soal, Bentuk Soal, Kesulitan */}
                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                                
                                {/* Jumlah Soal */}
                                <div className="space-y-1.5">
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Jumlah Soal
                                    </label>
                                    <div className="flex items-center gap-1 bg-slate-100 dark:bg-slate-800 p-1 border border-slate-200 dark:border-slate-700 rounded-xl">
                                        {[3, 5, 10, 15].map(num => (
                                            <button
                                                key={num}
                                                type="button"
                                                disabled={generating}
                                                onClick={() => setCount(num)}
                                                className={`flex-1 py-1.5 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                                                    count === num
                                                        ? 'bg-white dark:bg-slate-700 text-[#00897B] dark:text-teal-300 shadow-xs'
                                                        : 'text-slate-500 hover:text-slate-900 dark:text-slate-400'
                                                }`}
                                            >
                                                {num}
                                            </button>
                                        ))}
                                    </div>
                                </div>

                                {/* Bentuk Soal */}
                                <div className="space-y-1.5">
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Bentuk Soal
                                    </label>
                                    <select
                                        value={typePreference}
                                        onChange={(e) => setTypePreference(e.target.value)}
                                        disabled={generating}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    >
                                        <option value="2">Pilihan Ganda (A, B, C, D)</option>
                                        <option value="1">Isian Singkat / Essay</option>
                                        <option value="5">Benar / Salah (True/False)</option>
                                        <option value="3">Pilihan Majemuk (Checkbox)</option>
                                        <option value="mixed">Campuran (Bervariasi)</option>
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
                                        disabled={generating}
                                        className="w-full px-3 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    >
                                        <option value="Mudah">Mudah (Dasar)</option>
                                        <option value="Sedang">Sedang (Standar)</option>
                                        <option value="Sulit (HOTS)">Sulit (Penalaran / HOTS)</option>
                                    </select>
                                </div>
                            </div>

                            {/* Pilihan Model AI Google Studio */}
                            <div className="space-y-1.5 pt-1">
                                <label className="text-xs font-bold text-slate-700 dark:text-slate-300 flex items-center justify-between">
                                    <span className="flex items-center gap-1.5">
                                        <Cpu size={14} className="text-teal-600" /> Model Google Gemini
                                    </span>
                                    <span className="text-[11px] text-slate-400">Dari Google AI Studio</span>
                                </label>
                                <select
                                    value={selectedModel}
                                    onChange={(e) => setSelectedModel(e.target.value)}
                                    disabled={generating}
                                    className="w-full px-3.5 py-2.5 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                >
                                    {AVAILABLE_MODELS.map(m => (
                                        <option key={m.id} value={m.id}>
                                            {m.name} — {m.desc}
                                        </option>
                                    ))}
                                </select>
                            </div>

                            {/* Opsi Tambahan / Referensi Teks (Collapsible) */}
                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                <button
                                    type="button"
                                    onClick={() => setShowAdvanced(!showAdvanced)}
                                    className="text-xs font-bold text-teal-700 dark:text-teal-400 hover:underline flex items-center gap-1 cursor-pointer"
                                >
                                    <FileText size={13} />
                                    <span>{showAdvanced ? 'Tutup Opsi Tambahan' : 'Tambah Catatan / Teks Materi Referensi (Opsional)'}</span>
                                    {showAdvanced ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                                </button>

                                {showAdvanced && (
                                    <div className="mt-3 space-y-3 p-3.5 bg-slate-50 dark:bg-slate-800/40 rounded-2xl border border-slate-200 dark:border-slate-700">
                                        <div className="space-y-1">
                                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                                Tempel Teks / Rangkuman Buku:
                                            </label>
                                            <textarea
                                                value={contextText}
                                                onChange={(e) => setContextText(e.target.value)}
                                                rows={3}
                                                disabled={generating}
                                                placeholder="Tempelkan teks modul atau rangkuman di sini agar soal dibuat persis dari materi ini..."
                                                className="w-full px-3 py-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                            />
                                        </div>

                                        <div className="flex flex-wrap gap-4 pt-1">
                                            <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-slate-700 dark:text-slate-300">
                                                <input
                                                    type="checkbox"
                                                    checked={includeMath}
                                                    onChange={(e) => setIncludeMath(e.target.checked)}
                                                    disabled={generating}
                                                    className="w-4 h-4 rounded text-teal-600 focus:ring-teal-500 border-slate-300"
                                                />
                                                <span className="flex items-center gap-1">
                                                    <Calculator size={13} className="text-amber-500" /> Rumus Matematika (LaTeX)
                                                </span>
                                            </label>
                                            <label className="flex items-center gap-2 cursor-pointer text-xs font-medium text-slate-700 dark:text-slate-300">
                                                <input
                                                    type="checkbox"
                                                    checked={includeCode}
                                                    onChange={(e) => setIncludeCode(e.target.checked)}
                                                    disabled={generating}
                                                    className="w-4 h-4 rounded text-teal-600 focus:ring-teal-500 border-slate-300"
                                                />
                                                <span className="flex items-center gap-1">
                                                    <Code size={13} className="text-sky-500" /> Kode Pemrograman
                                                </span>
                                            </label>
                                        </div>
                                    </div>
                                )}
                            </div>

                            {/* Loading Status Sederhana & Jelas */}
                            {generating && (
                                <div className="p-4 rounded-2xl bg-teal-50 dark:bg-teal-950/50 border border-teal-200 dark:border-teal-800/80 flex items-center gap-3.5 animate-in fade-in">
                                    <Loader2 size={24} className="animate-spin text-[#00897B] dark:text-teal-400 shrink-0" />
                                    <div className="flex-1 min-w-0">
                                        <p className="text-xs font-extrabold text-teal-900 dark:text-teal-100">
                                            {statusMessage || 'Sedang membuat soal...'}
                                        </p>
                                        <p className="text-[11px] text-teal-700 dark:text-teal-300 mt-0.5 flex items-center gap-2">
                                            <span>Model: <b className="font-semibold">{selectedModel}</b></span>
                                            <span>•</span>
                                            <span className="flex items-center gap-1">
                                                <Clock size={11} /> {elapsedSeconds} detik
                                            </span>
                                        </p>
                                    </div>
                                </div>
                            )}

                        </form>
                    ) : (
                        /* Preview Soal yang Dibuat */
                        <div className="space-y-4">
                            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-800">
                                <div className="flex items-center gap-2">
                                    <span className="text-xs font-bold text-slate-800 dark:text-slate-200">
                                        ✨ {generatedQuestions.length} Soal Berhasil Dibuat
                                    </span>
                                    <span className="text-[11px] px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 font-bold">
                                        {resultInfo.time} detik • {resultInfo.model}
                                    </span>
                                </div>
                                <button
                                    type="button"
                                    onClick={toggleSelectAll}
                                    className="text-xs text-teal-700 dark:text-teal-400 font-bold hover:underline cursor-pointer"
                                >
                                    {selectedIndices.length === generatedQuestions.length ? 'Batal Pilih Semua' : 'Pilih Semua'}
                                </button>
                            </div>

                            <div className="space-y-3 max-h-[50vh] overflow-y-auto pr-1">
                                {generatedQuestions.map((q, idx) => {
                                    const isSelected = selectedIndices.includes(idx);
                                    return (
                                        <div
                                            key={idx}
                                            onClick={() => toggleSelect(idx)}
                                            className={`p-4 rounded-2xl border transition-all cursor-pointer ${
                                                isSelected
                                                    ? 'bg-white dark:bg-slate-800 border-teal-500 dark:border-teal-400 shadow-sm ring-1 ring-teal-500/20'
                                                    : 'bg-slate-50 dark:bg-slate-900 border-slate-200 dark:border-slate-800 opacity-60'
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
                                                        <span className="text-[11px] font-extrabold px-2 py-0.5 rounded-md bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200">
                                                            Nomor {idx + 1}
                                                        </span>
                                                        <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-teal-50 dark:bg-teal-950 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-800">
                                                            {typeLabels[q.typeId] || 'Pilihan Ganda'}
                                                        </span>
                                                    </div>

                                                    <div className="text-xs sm:text-sm font-bold text-slate-900 dark:text-white leading-relaxed">
                                                        <RichContentRenderer content={q.question} />
                                                    </div>

                                                    {/* Pilihan Jawaban */}
                                                    {[2, 3].includes(q.typeId) && q.options?.length > 0 && (
                                                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5 pt-1">
                                                            {q.options.map((opt, oIdx) => (
                                                                <div
                                                                    key={oIdx}
                                                                    className={`px-3 py-1.5 rounded-xl text-xs flex items-center gap-2 ${
                                                                        opt.isCorrect
                                                                            ? 'bg-emerald-50 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 font-bold border border-emerald-300 dark:border-emerald-800'
                                                                            : 'bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-300 border border-slate-200 dark:border-slate-700'
                                                                    }`}
                                                                >
                                                                    <span className="shrink-0 w-4 h-4 rounded-full flex items-center justify-center text-[10px] font-bold bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-200">
                                                                        {String.fromCharCode(65 + oIdx)}
                                                                    </span>
                                                                    <span className="truncate flex-1">{opt.optionText}</span>
                                                                    {opt.isCorrect && <Check size={12} className="text-emerald-600 shrink-0" />}
                                                                </div>
                                                            ))}
                                                        </div>
                                                    )}

                                                    {q.typeId === 5 && (
                                                        <div className="text-xs text-slate-600 dark:text-slate-400 pt-1">
                                                            Kunci Jawaban: <span className="font-bold text-teal-700 dark:text-teal-300">{q.correctAnswer || 'Benar'}</span>
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

                {/* Footer Tombol Aksi */}
                <div className="px-6 py-4 bg-slate-50 dark:bg-slate-800/50 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                    {step === 'config' ? (
                        <>
                            <div className="text-xs text-slate-400 dark:text-slate-500">
                                {apiKey ? (
                                    <span className="flex items-center gap-1.5 text-emerald-700 dark:text-emerald-300 font-bold">
                                        <CheckCircle2 size={13} /> Key: {maskKey(apiKey)}
                                    </span>
                                ) : (
                                    <span className="text-amber-700 dark:text-amber-300 font-bold">
                                        ⚠️ Harap masukkan API Key
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
                                    className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-md shadow-teal-500/20 flex items-center gap-2 transition-all cursor-pointer disabled:opacity-60 disabled:cursor-not-allowed"
                                >
                                    {generating ? (
                                        <>
                                            <Loader2 size={15} className="animate-spin" />
                                            <span>Sedang Membuat ({elapsedSeconds}s)...</span>
                                        </>
                                    ) : (
                                        <>
                                            <Sparkles size={15} />
                                            <span>Buat {count} Soal Sekarang</span>
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
                                className="px-4 py-2 text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer"
                            >
                                <RotateCcw size={14} /> Buat Ulang
                            </button>
                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    onClick={onClose}
                                    className="px-4 py-2.5 text-xs font-bold text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white rounded-xl transition-all cursor-pointer"
                                >
                                    Batal
                                </button>
                                <button
                                    type="button"
                                    onClick={handleImportToForm}
                                    disabled={selectedIndices.length === 0}
                                    className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-md shadow-teal-500/20 flex items-center gap-2 transition-all cursor-pointer disabled:opacity-50"
                                >
                                    <CheckCircle2 size={15} />
                                    <span>Masukkan {selectedIndices.length} Soal ke Formulir</span>
                                </button>
                            </div>
                        </>
                    )}
                </div>

            </div>
        </div>
    );
}
