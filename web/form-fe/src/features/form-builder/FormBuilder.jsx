import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Save, Plus, Trash2, ChevronUp, ChevronDown,
    Globe, Lock, ArrowLeft, Upload, FileUp, Image, Music, Download,
    GripVertical, Code, Calculator, Eye, EyeOff, FileText, Settings,
    Share2, Copy, Check, QrCode
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById, getQuestions, saveQuestions, updateForm,
    togglePublishForm, updateFormSettings, getFormShare,
    uploadFormBanner, clearSession, assetUrl,
    deleteQuestion, importQuestions, uploadQuestionImage, uploadQuestionAudio,
    templateDownloadUrl
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';
import SummernoteEditor from '../../components/ui/SummernoteEditor';
import MathAndCodeModal from '../../components/ui/MathAndCodeModal';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000';

const QUESTION_TYPES = [
    { id: 1, label: 'Esai / Jawaban Singkat' },
    { id: 2, label: 'Pilihan Ganda' },
    { id: 3, label: 'Kotak Centang (Multi-pilihan)' },
    { id: 4, label: 'Tanggal & Waktu' },
    { id: 5, label: 'Benar / Salah' },
];

const newQuestion = (order) => ({
    _id: `q_new_${Date.now()}_${order}`,
    id: null,
    question: '',
    typeId: 2,
    questionOrder: order,
    isRequired: false,
    correctAnswer: '',
    options: [{ optionText: '', isCorrect: false }, { optionText: '', isCorrect: false }],
    questionImage: null,
    questionAudio: null,
});

const needsOptions = (typeId) => [2, 3].includes(typeId);

export default function FormBuilder() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [form, setForm] = useState(null);
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [publishing, setPublishing] = useState(false);
    const [activeTab, setActiveTab] = useState('questions');
    const [shareInfo, setShareInfo] = useState(null);
    const [qrBlobUrl, setQrBlobUrl] = useState(null);
    const [toast, setToast] = useState(null);
    const [importLoading, setImportLoading] = useState(false);
    const [dragIndex, setDragIndex] = useState(null);
    const [copiedLink, setCopiedLink] = useState(false);

    // Modal state for Code & KaTeX Math insertion
    const [modalOpen, setModalOpen] = useState(false);
    const [modalMode, setModalMode] = useState('math');
    const [activeQuestionIdx, setActiveQuestionIdx] = useState(null);

    // Live preview toggle per question
    const [previewVisibility, setPreviewVisibility] = useState({});

    // Form settings state
    const [settings, setSettings] = useState({
        formTypeId: 1,
        showScore: false,
        randomizeQuestions: false,
        oneResponse: false,
        requiredLogin: false,
        formToken: '',
        timerDuration: '',
        openFormTime: '',
        closeFormTime: '',
        customFormLink: '',
    });

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, qRes] = await Promise.all([getFormById(id), getQuestions(id)]);
            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }
            if (formRes.ok && formRes.data) {
                setForm(formRes.data);
                const s = formRes.data.settings || {};
                setSettings({
                    formTypeId: s.formTypeId || 1,
                    showScore: s.showScore ?? false,
                    randomizeQuestions: s.randomizeQuestions ?? false,
                    oneResponse: s.oneResponse ?? false,
                    requiredLogin: s.requiredLogin ?? false,
                    formToken: s.formToken || '',
                    timerDuration: s.timerDuration ? Math.round(s.timerDuration / 60) : '',
                    openFormTime: s.openFormTime ? s.openFormTime.substring(0, 16) : '',
                    closeFormTime: s.closeFormTime ? s.closeFormTime.substring(0, 16) : '',
                    customFormLink: formRes.data.formLink || '',
                });
            }
            if (qRes.ok && Array.isArray(qRes.data) && qRes.data.length > 0) {
                setQuestions(qRes.data.map((q, i) => ({
                    _id: `q_${q.id}`,
                    id: q.id,
                    question: q.question || '',
                    typeId: q.typeId || 2,
                    questionOrder: q.questionOrder ?? i + 1,
                    isRequired: q.isRequired ?? false,
                    correctAnswer: q.correctAnswer ?? '',
                    questionImage: q.questionImage ?? null,
                    questionAudio: q.questionAudio ?? null,
                    options: q.options?.length > 0 ? q.options : [{ optionText: '', isCorrect: false }],
                })));
            } else {
                setQuestions([newQuestion(1)]);
            }
            setLoading(false);
        };
        load();
    }, [id, navigate]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3500);
    };

    const handleSaveQuestions = async () => {
        setSaving(true);
        const payload = questions.map((q, i) => ({
            id: q.id || undefined,
            question: q.question,
            typeId: q.typeId,
            questionOrder: i + 1,
            isRequired: q.isRequired,
            correctAnswer: q.correctAnswer || null,
            options: needsOptions(q.typeId)
                ? q.options.filter(o => o.optionText.trim()).map((o, j) => ({
                    optionText: o.optionText,
                    isCorrect: o.isCorrect ?? false,
                    optionOrder: j + 1,
                }))
                : [],
        }));
        const res = await saveQuestions(id, payload);
        setSaving(false);
        if (res.ok) {
            showToast('Soal berhasil disimpan!');
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                setQuestions(qRes.data.map((q, i) => ({
                    _id: `q_${q.id}`,
                    id: q.id,
                    question: q.question || '',
                    typeId: q.typeId || 2,
                    questionOrder: q.questionOrder ?? i + 1,
                    isRequired: q.isRequired ?? false,
                    correctAnswer: q.correctAnswer ?? '',
                    questionImage: q.questionImage ?? null,
                    questionAudio: q.questionAudio ?? null,
                    options: q.options?.length > 0 ? q.options : [{ optionText: '', isCorrect: false }],
                })));
            }
        } else {
            showToast(res.message || 'Gagal menyimpan soal', 'error');
        }
    };

    const handleSaveSettings = async () => {
        setSaving(true);
        if (settings.customFormLink && settings.customFormLink !== form.formLink) {
            const formRes = await updateForm(id, {
                title: form.title,
                description: form.description,
                formLink: settings.customFormLink,
            });
            if (!formRes.ok) {
                showToast(formRes.message || 'Gagal memperbarui slug tautan formulir', 'error');
                setSaving(false);
                return;
            }
            setForm(prev => ({ ...prev, formLink: settings.customFormLink }));
        }

        const res = await updateFormSettings(id, {
            formTypeId: parseInt(settings.formTypeId),
            showScore: settings.showScore,
            randomizeQuestions: settings.randomizeQuestions,
            oneResponse: settings.oneResponse,
            requiredLogin: settings.requiredLogin,
            formToken: settings.formToken.trim() || null,
            timerDuration: settings.timerDuration ? parseInt(settings.timerDuration) * 60 : null,
            openFormTime: settings.openFormTime ? new Date(settings.openFormTime).toISOString() : null,
            closeFormTime: settings.closeFormTime ? new Date(settings.closeFormTime).toISOString() : null,
        });

        setSaving(false);
        showToast(res.ok ? 'Pengaturan formulir berhasil disimpan!' : (res.message || 'Gagal menyimpan pengaturan'), res.ok ? 'success' : 'error');
    };

    const handleTogglePublish = async () => {
        setPublishing(true);
        const res = await togglePublishForm(id);
        if (res.ok) {
            const updated = await getFormById(id);
            if (updated.ok) setForm(updated.data);
            showToast(res.message || 'Status publikasi formulir berhasil diubah!');
        } else {
            showToast(res.message || 'Gagal mengubah status publikasi', 'error');
        }
        setPublishing(false);
    };

    const handleLoadShare = useCallback(async () => {
        const res = await getFormShare(id);
        if (res.ok) {
            setShareInfo(res.data);
            const token = localStorage.getItem('token');
            const qrRes = await fetch(
                `${API_BASE_URL}/api/forms/${id}/share/qr?frontendUrl=${encodeURIComponent(window.location.origin)}`,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            if (qrRes.ok) {
                const blob = await qrRes.blob();
                setQrBlobUrl(URL.createObjectURL(blob));
            }
        }
    }, [id]);

    const handleBannerUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const res = await uploadFormBanner(id, file);
        if (res.ok) {
            const updated = await getFormById(id);
            if (updated.ok) setForm(updated.data);
            showToast('Banner formulir berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah banner', 'error');
        }
    };

    const handleImportFile = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setImportLoading(true);
        const res = await importQuestions(id, file);
        setImportLoading(false);
        if (res.ok) {
            showToast(`Berhasil mengimpor! ${res.message}`);
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                setQuestions(qRes.data.map((q, i) => ({
                    _id: `q_${q.id}`,
                    id: q.id,
                    question: q.question || '',
                    typeId: q.typeId || 2,
                    questionOrder: q.questionOrder ?? i + 1,
                    isRequired: q.isRequired ?? false,
                    correctAnswer: q.correctAnswer ?? '',
                    questionImage: q.questionImage ?? null,
                    questionAudio: q.questionAudio ?? null,
                    options: q.options?.length > 0 ? q.options : [{ optionText: '', isCorrect: false }],
                })));
            }
        } else {
            showToast(res.message || 'Gagal mengimpor berkas', 'error');
        }
        e.target.value = '';
    };

    const handleDeleteQuestion = async (idx) => {
        const q = questions[idx];
        if (q.id) {
            const res = await deleteQuestion(id, q.id);
            if (!res.ok) { showToast(res.message || 'Gagal menghapus soal', 'error'); return; }
        }
        setQuestions(prev => prev.filter((_, i) => i !== idx));
        showToast('Soal berhasil dihapus');
    };

    const handleUploadQuestionImage = async (idx, file) => {
        const q = questions[idx];
        if (!q.id) { showToast('Simpan soal terlebih dahulu sebelum mengunggah gambar', 'error'); return; }
        const res = await uploadQuestionImage(id, q.id, file);
        if (res.ok) {
            updateQuestion(idx, 'questionImage', res.data?.questionImage ?? null);
            showToast('Gambar soal berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah gambar', 'error');
        }
    };

    const handleUploadQuestionAudio = async (idx, file) => {
        const q = questions[idx];
        if (!q.id) { showToast('Simpan soal terlebih dahulu sebelum mengunggah audio', 'error'); return; }
        const res = await uploadQuestionAudio(id, q.id, file);
        if (res.ok) {
            updateQuestion(idx, 'questionAudio', res.data?.questionAudio ?? null);
            showToast('Audio soal berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah audio', 'error');
        }
    };

    const addQuestion = () => setQuestions(prev => [...prev, newQuestion(prev.length + 1)]);

    const moveQuestion = (idx, dir) => {
        setQuestions(prev => {
            const arr = [...prev];
            const target = idx + dir;
            if (target < 0 || target >= arr.length) return arr;
            [arr[idx], arr[target]] = [arr[target], arr[idx]];
            return arr;
        });
    };

    // Drag and Drop reordering
    const handleDragStart = (idx) => setDragIndex(idx);
    const handleDragOver = (e, idx) => {
        e.preventDefault();
        if (dragIndex === null || dragIndex === idx) return;
        setQuestions(prev => {
            const arr = [...prev];
            const dragged = arr[dragIndex];
            arr.splice(dragIndex, 1);
            arr.splice(idx, 0, dragged);
            return arr;
        });
        setDragIndex(idx);
    };

    const updateQuestion = (idx, field, value) =>
        setQuestions(prev => prev.map((q, i) => i === idx ? { ...q, [field]: value } : q));

    const openInsertModal = (idx, mode) => {
        setActiveQuestionIdx(idx);
        setModalMode(mode);
        setModalOpen(true);
    };

    const handleInsertFromModal = (snippetHtml) => {
        if (activeQuestionIdx === null) return;
        const current = questions[activeQuestionIdx].question || '';
        updateQuestion(activeQuestionIdx, 'question', current + snippetHtml);
    };

    const togglePreview = (idx) => {
        setPreviewVisibility(prev => ({ ...prev, [idx]: !prev[idx] }));
    };

    const addOption = (qIdx) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: [...q.options, { optionText: '', isCorrect: false }] } : q
        ));

    const updateOption = (qIdx, oIdx, field, value) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: q.options.map((o, j) => j === oIdx ? { ...o, [field]: value } : o) } : q
        ));

    const removeOption = (qIdx, oIdx) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: q.options.filter((_, j) => j !== oIdx) } : q
        ));

    const handleCopyLink = () => {
        const link = `${window.location.origin}/f/${form?.formLink}`;
        navigator.clipboard.writeText(link);
        setCopiedLink(true);
        setTimeout(() => setCopiedLink(false), 2000);
    };

    const isPublished = form?.status?.toLowerCase() === 'published';

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat Form Builder...</p>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            {/* <Sidebar /> */}

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                {/* Header Navbar */}
                <div className="sticky top-0 z-20 bg-white dark:bg-slate-900 border-b border-slate-200/80 dark:border-slate-800 px-6 py-3.5 flex items-center justify-between gap-4 shadow-xs">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/my-forms')} className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <h1 className="text-base font-extrabold text-slate-900 dark:text-white truncate">
                                {form?.title || 'Formulir Tanpa Judul'}
                            </h1>
                            <p className="text-xs text-slate-400 dark:text-slate-500 font-mono">/f/{form?.formLink}</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                        <span className={`text-xs font-bold px-3 py-1 rounded-full ${
                            isPublished 
                                ? 'bg-teal-50 text-teal-600 dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800' 
                                : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
                        }`}>
                            {isPublished ? 'Dipublikasikan' : 'Draf'}
                        </span>

                        <button
                            onClick={handleTogglePublish}
                            disabled={publishing}
                            className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all cursor-pointer disabled:opacity-60 ${
                                isPublished 
                                    ? 'bg-amber-50 text-amber-600 dark:bg-amber-950/60 dark:text-amber-400 hover:bg-amber-100 border border-amber-200 dark:border-amber-800' 
                                    : 'bg-[#00897B] text-white hover:bg-[#00796B] shadow-xs'
                            }`}
                        >
                            {isPublished ? <><Lock size={13} /> Batal Publikasi</> : <><Globe size={13} /> Publikasikan</>}
                        </button>

                        {activeTab === 'questions' && (
                            <button
                                onClick={handleSaveQuestions}
                                disabled={saving}
                                className="flex items-center gap-1.5 px-4 py-1.5 bg-slate-900 hover:bg-slate-800 dark:bg-teal-600 dark:hover:bg-teal-700 text-white rounded-xl text-xs font-bold shadow-xs transition-all cursor-pointer disabled:opacity-60"
                            >
                                <Save size={14} /> {saving ? 'Menyimpan...' : 'Simpan Soal'}
                            </button>
                        )}
                        {activeTab === 'settings' && (
                            <button
                                onClick={handleSaveSettings}
                                disabled={saving}
                                className="flex items-center gap-1.5 px-4 py-1.5 bg-slate-900 hover:bg-slate-800 dark:bg-teal-600 dark:hover:bg-teal-700 text-white rounded-xl text-xs font-bold shadow-xs transition-all cursor-pointer disabled:opacity-60"
                            >
                                <Save size={14} /> {saving ? 'Menyimpan...' : 'Simpan Pengaturan'}
                            </button>
                        )}
                    </div>
                </div>

                {/* Toast Notification */}
                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-[#00897B]'}`}>
                        {toast.msg}
                    </div>
                )}

                {/* Navigation Tabs without emojis */}
                <div className="flex border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 px-6">
                    {[
                        { key: 'questions', label: 'Soal', icon: FileText },
                        { key: 'settings', label: 'Pengaturan', icon: Settings },
                        { key: 'share', label: 'Bagikan & QR', icon: Share2 },
                    ].map(tab => {
                        const Icon = tab.icon;
                        return (
                            <button
                                key={tab.key}
                                onClick={() => { 
                                    setActiveTab(tab.key); 
                                    if (tab.key === 'share' && !shareInfo) handleLoadShare(); 
                                }}
                                className={`flex items-center gap-2 py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all cursor-pointer ${
                                    activeTab === tab.key 
                                        ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400' 
                                        : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
                                }`}
                            >
                                <Icon size={14} />
                                <span>{tab.label}</span>
                            </button>
                        );
                    })}
                </div>

                <div className="p-6 max-w-3xl mx-auto w-full space-y-5">

                    {/* ── QUESTIONS TAB ── */}
                    {activeTab === 'questions' && (
                        <>
                            {/* Form Header Info Card */}
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-5 shadow-xs space-y-4">
                                <h2 className="text-xs font-extrabold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                                    Informasi Utama Formulir
                                </h2>
                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 mb-1 block">Judul Formulir</label>
                                    <input
                                        value={form?.title ?? ''}
                                        onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
                                        onBlur={() => form?.title && updateForm(id, { title: form.title, description: form.description })}
                                        placeholder="Judul Formulir..."
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-sm font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>
                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 mb-1 block">Deskripsi / Petunjuk Pengisian</label>
                                    <SummernoteEditor
                                        value={form?.description ?? ''}
                                        onChange={val => {
                                            setForm(f => ({ ...f, description: val }));
                                            updateForm(id, { title: form.title, description: val });
                                        }}
                                        placeholder="Tulis deskripsi atau instruksi formulir..."
                                        className="w-full"
                                    />
                                </div>
                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 mb-1 block">Gambar Banner</label>
                                    {form?.bannerImage && (
                                        <div className="w-full h-36 relative overflow-hidden rounded-xl mb-2 border border-slate-200 dark:border-slate-700 bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
                                            <img src={assetUrl(form.bannerImage)} alt="Banner" className="w-full h-full object-cover" />
                                        </div>
                                    )}
                                    <label className="flex items-center gap-2 cursor-pointer px-3.5 py-2 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 hover:border-[#00897B] dark:hover:border-teal-400 hover:text-[#00897B] dark:hover:text-teal-400 transition-all w-fit">
                                        <Upload size={14} /> Unggah Gambar Banner
                                        <input type="file" accept="image/*" className="hidden" onChange={handleBannerUpload} />
                                    </label>
                                </div>
                            </div>

                            {/* Toolbar Import Soal & Unduh Templat */}
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 flex flex-wrap items-center justify-between gap-3 shadow-xs">
                                <div className="flex items-center gap-3">
                                    <span className="text-xs font-bold text-slate-700 dark:text-slate-300">Impor Soal:</span>
                                    <label className={`flex items-center gap-1.5 px-3 py-1.5 bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800 text-[#00897B] dark:text-teal-400 rounded-xl text-xs font-bold cursor-pointer hover:bg-teal-100 transition-all ${importLoading ? 'opacity-50 pointer-events-none' : ''}`}>
                                        <FileUp size={14} /> {importLoading ? 'Mengimpor...' : 'Unggah Berkas (.xlsx, .csv, .docx, .pdf)'}
                                        <input type="file" accept=".csv,.xlsx,.xls,.pdf,.docx" className="hidden" onChange={handleImportFile} />
                                    </label>
                                </div>
                                <div className="flex items-center gap-1.5">
                                    <span className="text-xs text-slate-400 dark:text-slate-500 font-semibold mr-1">Templat:</span>
                                    {['csv', 'xlsx', 'docx', 'pdf'].map(fmt => (
                                        <a
                                            key={fmt}
                                            href={templateDownloadUrl(fmt)}
                                            target="_blank"
                                            rel="noreferrer"
                                            className="flex items-center gap-1 px-2.5 py-1 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-[11px] font-extrabold rounded-lg transition-all"
                                        >
                                            <Download size={11} /> {fmt.toUpperCase()}
                                        </a>
                                    ))}
                                </div>
                            </div>

                            {/* Questions Cards */}
                            <div className="space-y-4">
                                {questions.map((q, idx) => (
                                    <div
                                        key={q._id}
                                        draggable
                                        onDragStart={() => handleDragStart(idx)}
                                        onDragOver={(e) => handleDragOver(e, idx)}
                                        onDragEnd={() => setDragIndex(null)}
                                        className={`bg-white dark:bg-slate-900 rounded-2xl border transition-all p-5 shadow-xs space-y-3 relative group ${
                                            dragIndex === idx 
                                                ? 'border-[#00897B] ring-2 ring-teal-100 dark:ring-teal-900 shadow-md bg-teal-50/20' 
                                                : 'border-slate-200/80 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700'
                                        }`}
                                    >
                                        <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                                            <div className="flex items-center gap-2">
                                                <div className="cursor-grab active:cursor-grabbing p-1 text-slate-300 dark:text-slate-600 hover:text-slate-600 rounded">
                                                    <GripVertical size={16} />
                                                </div>
                                                <span className="text-xs font-extrabold text-slate-700 dark:text-slate-200 bg-slate-100 dark:bg-slate-800 px-2 py-0.5 rounded-md">
                                                    Soal {idx + 1}
                                                </span>
                                            </div>

                                            {/* Formula & Code Insertion */}
                                            <div className="flex items-center gap-1.5">
                                                <button
                                                    type="button"
                                                    onClick={() => openInsertModal(idx, 'math')}
                                                    className="flex items-center gap-1 px-2.5 py-1 bg-teal-50 hover:bg-teal-100 dark:bg-teal-950/60 dark:hover:bg-teal-900 border border-teal-200 dark:border-teal-800 text-[#00897B] dark:text-teal-400 text-xs font-bold rounded-lg transition-all"
                                                    title="Sisipkan Rumus Matematika"
                                                >
                                                    <Calculator size={13} /> Matematika
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => openInsertModal(idx, 'code')}
                                                    className="flex items-center gap-1 px-2.5 py-1 bg-slate-900 hover:bg-slate-800 dark:bg-slate-800 dark:hover:bg-slate-700 text-teal-400 text-xs font-mono font-bold rounded-lg transition-all"
                                                    title="Sisipkan Blok Kode"
                                                >
                                                    <Code size={13} /> Kode
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => togglePreview(idx)}
                                                    className={`flex items-center gap-1 px-2.5 py-1 text-xs font-bold rounded-lg transition-all border ${
                                                        previewVisibility[idx] 
                                                            ? 'bg-[#00897B] text-white border-[#00897B]' 
                                                            : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-200'
                                                    }`}
                                                    title="Buka/Tutup Pratinjau Soal"
                                                >
                                                    {previewVisibility[idx] ? <EyeOff size={13} /> : <Eye size={13} />}
                                                    <span>Pratinjau</span>
                                                </button>
                                                <div className="w-px h-4 bg-slate-200 dark:bg-slate-800 mx-1" />
                                                <button onClick={() => moveQuestion(idx, -1)} className="p-1 text-slate-300 dark:text-slate-600 hover:text-slate-600 rounded cursor-pointer"><ChevronUp size={15} /></button>
                                                <button onClick={() => moveQuestion(idx, 1)} className="p-1 text-slate-300 dark:text-slate-600 hover:text-slate-600 rounded cursor-pointer"><ChevronDown size={15} /></button>
                                                <button onClick={() => handleDeleteQuestion(idx)} className="p-1 text-red-400 hover:text-red-600 rounded cursor-pointer"><Trash2 size={15} /></button>
                                            </div>
                                        </div>

                                        {/* Editor Teks Soal */}
                                        <SummernoteEditor
                                            value={q.question}
                                            onChange={val => updateQuestion(idx, 'question', val)}
                                            placeholder="Tuliskan pertanyaan soal di sini..."
                                            className="w-full"
                                        />

                                        {/* Pratinjau Soal */}
                                        {previewVisibility[idx] && q.question && (
                                            <div className="bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl p-4 space-y-1">
                                                <p className="text-[10px] font-extrabold text-slate-400 dark:text-slate-500 uppercase tracking-wider flex items-center gap-1">
                                                    <Eye size={11} className="text-[#00897B] dark:text-teal-400" /> Pratinjau Tampilan Soal:
                                                </p>
                                                <div className="pt-1">
                                                    <RichContentRenderer content={q.question} className="text-xs text-slate-800 dark:text-slate-100" />
                                                </div>
                                            </div>
                                        )}

                                        <div className="flex items-center justify-between flex-wrap gap-3 pt-1">
                                            <div className="flex items-center gap-3">
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400">Tipe Soal:</label>
                                                <select
                                                    value={q.typeId}
                                                    onChange={e => updateQuestion(idx, 'typeId', parseInt(e.target.value))}
                                                    className="border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                >
                                                    {QUESTION_TYPES.map(t => <option key={t.id} value={t.id}>{t.label}</option>)}
                                                </select>
                                            </div>
                                            <label className="flex items-center gap-2 text-xs font-bold text-slate-700 dark:text-slate-300 cursor-pointer">
                                                <input
                                                    type="checkbox"
                                                    checked={q.isRequired}
                                                    onChange={e => updateQuestion(idx, 'isRequired', e.target.checked)}
                                                    className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                                />
                                                Soal Wajib Diisi
                                            </label>
                                        </div>

                                        {/* Pilihan Opsi */}
                                        {needsOptions(q.typeId) && (
                                            <div className="space-y-2 pt-2 border-t border-slate-100 dark:border-slate-800">
                                                <div className="flex items-center justify-between">
                                                    <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block">Pilihan Jawaban:</label>
                                                    <span className="text-[11px] text-slate-400 dark:text-slate-500">Centang kotak untuk menandai jawaban benar</span>
                                                </div>
                                                {q.options.map((opt, oIdx) => (
                                                    <div key={oIdx} className="flex items-center gap-2">
                                                        <label className="flex items-center gap-1 cursor-pointer">
                                                            <input
                                                                type="checkbox"
                                                                checked={opt.isCorrect}
                                                                onChange={e => updateOption(idx, oIdx, 'isCorrect', e.target.checked)}
                                                                className="w-4 h-4 text-[#00897B] rounded shrink-0 cursor-pointer"
                                                                title="Tandai sebagai jawaban benar"
                                                            />
                                                            {opt.isCorrect && <span className="text-[10px] font-extrabold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 px-1.5 py-0.5 rounded">✓ Benar</span>}
                                                        </label>
                                                        <input
                                                            placeholder={`Pilihan ${oIdx + 1}`}
                                                            value={opt.optionText}
                                                            onChange={e => updateOption(idx, oIdx, 'optionText', e.target.value)}
                                                            className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                        />
                                                        <button onClick={() => removeOption(idx, oIdx)} className="text-red-400 hover:text-red-600 p-1 shrink-0 cursor-pointer">
                                                            <Trash2 size={14} />
                                                        </button>
                                                    </div>
                                                ))}
                                                <button onClick={() => addOption(idx)} className="text-xs font-bold text-[#00897B] dark:text-teal-400 hover:underline mt-1 cursor-pointer">
                                                    + Tambah Pilihan
                                                </button>
                                            </div>
                                        )}

                                        {/* Kunci Jawaban untuk Esai / Tanggal / Benar-Salah */}
                                        {[1, 4, 5].includes(q.typeId) && (
                                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">
                                                    Jawaban Benar yang Diharapkan (untuk penilaian otomatis & skor):
                                                </label>
                                                {q.typeId === 5 ? (
                                                    <select
                                                        value={q.correctAnswer || 'True'}
                                                        onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-[#00897B] bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
                                                    >
                                                        <option value="True">Benar (True)</option>
                                                        <option value="False">Salah (False)</option>
                                                    </select>
                                                ) : (
                                                    <input
                                                        placeholder="contoh: 4 atau Soekarno"
                                                        value={q.correctAnswer}
                                                        onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                    />
                                                )}
                                            </div>
                                        )}

                                        {/* Media Unggahan */}
                                        {q.id ? (
                                            <div className="flex flex-wrap items-center gap-3 pt-2 border-t border-slate-100 dark:border-slate-800">
                                                {q.questionImage ? (
                                                    <div className="flex items-center gap-2">
                                                        <img src={assetUrl(q.questionImage)} alt="Soal" className="h-12 w-20 object-cover rounded-lg border border-slate-200 dark:border-slate-700" />
                                                        <label className="text-xs font-bold text-[#00897B] dark:text-teal-400 cursor-pointer hover:underline">
                                                            Ubah Gambar
                                                            <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                        </label>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 cursor-pointer hover:border-[#00897B] hover:text-[#00897B] transition-all">
                                                        <Image size={13} /> Tambah Gambar
                                                        <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                    </label>
                                                )}

                                                {q.questionAudio ? (
                                                    <div className="flex items-center gap-2">
                                                        <audio controls src={assetUrl(q.questionAudio)} className="h-8 text-xs" />
                                                        <label className="text-xs font-bold text-[#00897B] dark:text-teal-400 cursor-pointer hover:underline">
                                                            Ubah Audio
                                                            <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                        </label>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 cursor-pointer hover:border-[#00897B] hover:text-[#00897B] transition-all">
                                                        <Music size={13} /> Tambah Audio
                                                        <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                    </label>
                                                )}
                                            </div>
                                        ) : (
                                            <p className="text-[11px] text-slate-400 dark:text-slate-500 italic">Simpan soal terlebih dahulu untuk mengunggah gambar atau audio.</p>
                                        )}
                                    </div>
                                ))}
                            </div>

                            <button
                                onClick={addQuestion}
                                className="w-full py-3.5 border-2 border-dashed border-slate-300 dark:border-slate-700 rounded-2xl text-xs font-extrabold text-slate-600 dark:text-slate-400 hover:border-[#00897B] dark:hover:border-teal-400 hover:text-[#00897B] dark:hover:text-teal-400 transition-all flex items-center justify-center gap-2 bg-white/60 dark:bg-slate-900/60 cursor-pointer"
                            >
                                <Plus size={18} /> Tambah Soal Baru
                            </button>
                        </>
                    )}

                    {/* ── SETTINGS TAB ── */}
                    {activeTab === 'settings' && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-6 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-900 dark:text-white border-b border-slate-100 dark:border-slate-800 pb-3">
                                Konfigurasi & Aturan Formulir
                            </h2>

                            <div className="space-y-4">
                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Slug Tautan Khusus</label>
                                    <div className="flex items-center gap-2">
                                        <span className="text-xs font-mono text-slate-400 dark:text-slate-500 bg-slate-100 dark:bg-slate-800 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700">
                                            {window.location.origin}/f/
                                        </span>
                                        <input
                                            value={settings.customFormLink}
                                            onChange={e => setSettings(s => ({ ...s, customFormLink: e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '') }))}
                                            placeholder="tautan-khusus-saya"
                                            className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                    <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-1">Hanya huruf kecil, angka, dan tanda hubung (-).</p>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Tipe Tata Letak Formulir</label>
                                        <select
                                            value={settings.formTypeId}
                                            onChange={e => setSettings(s => ({ ...s, formTypeId: parseInt(e.target.value) }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        >
                                            <option value={1}>Semua Soal dalam Satu Halaman</option>
                                            <option value={2}>Satu Soal per Halaman (Langkah)</option>
                                        </select>
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Durasi Timer (Menit, Opsional)</label>
                                        <input
                                            type="number"
                                            min="0"
                                            value={settings.timerDuration}
                                            onChange={e => setSettings(s => ({ ...s, timerDuration: e.target.value }))}
                                            placeholder="contoh: 30"
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Waktu Buka Formulir (Opsional)</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.openFormTime}
                                            onChange={e => setSettings(s => ({ ...s, openFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-medium bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Waktu Tutup Formulir (Opsional)</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.closeFormTime}
                                            onChange={e => setSettings(s => ({ ...s, closeFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-medium bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Token Sandi Akses (Opsional)</label>
                                    <input
                                        type="text"
                                        value={settings.formToken}
                                        onChange={e => setSettings(s => ({ ...s, formToken: e.target.value }))}
                                        placeholder="Masukkan token rahasia..."
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                    <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-1">Jika diisi, responden wajib memasukkan token sebelum membuka soal.</p>
                                </div>

                                <div className="space-y-3 pt-3 border-t border-slate-100 dark:border-slate-800">
                                    {[
                                        { key: 'showScore', label: 'Tampilkan Skor & Kunci Jawaban setelah Kirim' },
                                        { key: 'randomizeQuestions', label: 'Acak Urutan Soal untuk Setiap Responden' },
                                        { key: 'oneResponse', label: 'Batasi 1 Respons per Pengguna / Perangkat' },
                                        { key: 'requiredLogin', label: 'Wajibkan Login Akun FormUp untuk Mengisi' },
                                    ].map(item => (
                                        <label key={item.key} className="flex items-center gap-3 text-xs font-bold text-slate-700 dark:text-slate-300 cursor-pointer">
                                            <input
                                                type="checkbox"
                                                checked={settings[item.key]}
                                                onChange={e => setSettings(s => ({ ...s, [item.key]: e.target.checked }))}
                                                className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                            />
                                            {item.label}
                                        </label>
                                    ))}
                                </div>

                                <div className="pt-4 flex justify-end">
                                    <button
                                        onClick={handleSaveSettings}
                                        disabled={saving}
                                        className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white font-bold text-xs rounded-xl shadow-xs transition-all cursor-pointer disabled:opacity-60"
                                    >
                                        {saving ? 'Menyimpan...' : 'Simpan Pengaturan'}
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ── SHARE TAB ── */}
                    {activeTab === 'share' && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-6 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-900 dark:text-white border-b border-slate-100 dark:border-slate-800 pb-3">
                                Bagikan Tautan & Kode QR
                            </h2>

                            <div className="space-y-5">
                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Tautan Publik Formulir</label>
                                    <div className="flex items-center gap-2">
                                        <input
                                            readOnly
                                            value={`${window.location.origin}/f/${form?.formLink}`}
                                            className="flex-1 border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-slate-100 rounded-xl px-3.5 py-2 text-xs font-mono select-all"
                                        />
                                        <button
                                            onClick={handleCopyLink}
                                            className="px-4 py-2 bg-[#00897B] hover:bg-[#00796B] text-white font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-xs transition-all cursor-pointer"
                                        >
                                            {copiedLink ? <Check size={14} /> : <Copy size={14} />}
                                            <span>{copiedLink ? 'Tersalin!' : 'Salin Tautan'}</span>
                                        </button>
                                    </div>
                                </div>

                                {qrBlobUrl && (
                                    <div className="flex flex-col items-center justify-center p-6 border border-slate-200 dark:border-slate-700 rounded-2xl bg-slate-50/50 dark:bg-slate-800/50 space-y-3">
                                        <p className="text-xs font-bold text-slate-700 dark:text-slate-300">Scan QR Code untuk Mengisi:</p>
                                        <div className="p-3 bg-white rounded-2xl shadow-sm border border-slate-200 dark:border-slate-700">
                                            <img src={qrBlobUrl} alt="QR Code Formulir" className="w-48 h-48" />
                                        </div>
                                        <a
                                            href={qrBlobUrl}
                                            download={`qrcode-${form?.formLink}.png`}
                                            className="px-4 py-2 bg-slate-900 hover:bg-slate-800 dark:bg-slate-700 dark:hover:bg-slate-600 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-xs transition-all"
                                        >
                                            <Download size={13} /> Unduh QR Code
                                        </a>
                                    </div>
                                )}
                            </div>
                        </div>
                    )}

                </div>
            </div>

            {/* Modal Rumus & Kode */}
            <MathAndCodeModal
                isOpen={modalOpen}
                mode={modalMode}
                onClose={() => setModalOpen(false)}
                onInsert={handleInsertFromModal}
            />
        </div>
    );
}
