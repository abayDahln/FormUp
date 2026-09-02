import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Save, Plus, Trash2, ChevronUp, ChevronDown,
    Globe, Lock, ArrowLeft, Upload, FileUp, Image, Music, Download,
    GripVertical, Code, Calculator, Eye, EyeOff, X
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
import BlockQuestionEditor from '../../components/ui/BlockQuestionEditor';
import MathAndCodeModal from '../../components/ui/MathAndCodeModal';
import ImageLightboxModal from '../../components/ui/ImageLightboxModal';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://api.formup.my.id';
const FRONTEND_BASE_URL = import.meta.env.VITE_FRONTEND_URL || 'https://formup.my.id';

const QUESTION_TYPES = [
    { id: 1, label: 'Essay / Short Answer' },
    { id: 2, label: 'Multiple Choice' },
    { id: 3, label: 'Checkbox' },
    { id: 4, label: 'Date Time' },
    { id: 5, label: 'True / False' },
];

const newQuestion = (order) => ({
    _id: `q_new_${Date.now()}_${order}`,
    id: null,
    question: '',
    typeId: 2,
    questionOrder: order,
    isRequired: true,
    isScorable: true,
    points: null,
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
    const [copiedLink, setCopiedLink] = useState(false);
    const [lightboxImage, setLightboxImage] = useState(null);

    // Modal state for Code & KaTeX Math insertion (for Question or Option)
    const [modalOpen, setModalOpen] = useState(false);
    const [modalMode, setModalMode] = useState('math');
    const [modalTarget, setModalTarget] = useState({ type: 'question', qIdx: null, oIdx: null });

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

    const toLocalDatetimeInput = (dateVal) => {
        if (!dateVal) return '';
        const d = new Date(dateVal);
        if (isNaN(d.getTime())) return '';
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        const hours = String(d.getHours()).padStart(2, '0');
        const minutes = String(d.getMinutes()).padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    };

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, qRes] = await Promise.all([getFormById(id), getQuestions(id)]);

            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }

            if (formRes.ok && formRes.data) {
                const f = formRes.data;
                setForm(f);
                const s = f.settings || {};
                setSettings({
                    formTypeId: s.formTypeId ?? 1,
                    showScore: s.showScore ?? false,
                    randomizeQuestions: s.randomizeQuestions ?? false,
                    oneResponse: s.oneResponse ?? false,
                    requiredLogin: s.requiredLogin ?? false,
                    formToken: s.formToken ?? '',
                    timerDuration: s.timerDuration ? Math.round(s.timerDuration / 60) : '',
                    openFormTime: toLocalDatetimeInput(s.openFormTime),
                    closeFormTime: toLocalDatetimeInput(s.closeFormTime),
                    customFormLink: f.formLink || '',
                });
            }

            if (qRes.ok && Array.isArray(qRes.data) && qRes.data.length > 0) {
                setQuestions(qRes.data.map((q, i) => {
                    const hasCorrectOption = (q.options || []).some(o => o.isCorrect === true);
                    const hasCorrectAnswer = !!(q.correctAnswer && q.correctAnswer.trim());
                    const isScorable = q.isScorable !== undefined ? q.isScorable : (hasCorrectOption || hasCorrectAnswer);

                    return {
                        ...q,
                        _id: `q_${q.id}`,
                        isScorable: isScorable,
                        options: q.options || [],
                    };
                }));
            } else {
                setQuestions([newQuestion(1)]);
            }

            setLoading(false);
        };
        load();
    }, [id, navigate]);

    const handleSaveQuestions = async () => {
        setSaving(true);
        // 0 soal diperbolehkan: kirim array kosong -> backend hapus semua soal
        const payloadQuestions = questions.map((q, i) => {
            const scorable = q.isScorable !== false;
            return {
                id: q.id ?? undefined,
                typeId: parseInt(q.typeId),
                question: q.question || '',
                questionFormat: q.questionFormat || 'text',
                questionOrder: i + 1,
                isRequired: !!q.isRequired,
                correctAnswer: scorable ? (q.correctAnswer || null) : null,
                points: scorable && q.points ? parseInt(q.points, 10) : null,
                questionImage: q.questionImage || null,
                questionAudio: q.questionAudio || null,
                options: (q.options || []).map(opt => ({
                    optionText: opt.optionText || '',
                    isCorrect: scorable ? !!opt.isCorrect : false,
                })),
            };
        });

        const res = await saveQuestions(id, payloadQuestions);
        setSaving(false);

        if (res.ok) {
            showToast(payloadQuestions.length === 0 ? 'Semua soal berhasil dihapus!' : 'Soal berhasil disimpan!');
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                if (qRes.data.length === 0) {
                    setQuestions([]);
                } else {
                    setQuestions(qRes.data.map((q, i) => ({
                        ...q,
                        _id: questions[i]?._id || `q_${q.id}`,
                        isScorable: questions[i]?.isScorable ?? ((q.options || []).some(o => o.isCorrect === true) || !!(q.correctAnswer && q.correctAnswer.trim())),
                        points: q.points ?? null,
                        options: q.options || [],
                    })));
                }
                // Jika form kehabisan soal, status otomatis kembali draft
                const refreshed = await getFormById(id);
                if (refreshed.ok && refreshed.data) setForm(refreshed.data);
            }
            return true;
        } else {
            showToast(res.message || 'Gagal menyimpan soal.', 'error');
            return false;
        }
    };

    const handleClearAllQuestions = () => {
        if (questions.length === 0) return;
        if (!window.confirm('Hapus semua soal? Perubahan berlaku setelah Simpan.')) return;
        setQuestions([]);
        showToast('Semua soal dihapus dari draf. Tekan Simpan untuk menyimpan perubahan.', 'success');
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

        const parsedTimer = parseInt(settings.timerDuration, 10);
        const timerValue = !isNaN(parsedTimer) && parsedTimer > 0 ? parsedTimer * 60 : null;

        const res = await updateFormSettings(id, {
            formTypeId: parseInt(settings.formTypeId, 10) || 1,
            showScore: !!settings.showScore,
            randomizeQuestions: !!settings.randomizeQuestions,
            oneResponse: !!settings.oneResponse,
            requiredLogin: !!settings.requiredLogin,
            formToken: settings.formToken ? settings.formToken.trim() : null,
            timerDuration: timerValue,
            openFormTime: settings.openFormTime ? new Date(settings.openFormTime).toISOString() : null,
            closeFormTime: settings.closeFormTime ? new Date(settings.closeFormTime).toISOString() : null,
        });

        setSaving(false);

        if (res.ok) {
            const refreshed = await getFormById(id);
            if (refreshed.ok && refreshed.data) {
                const f = refreshed.data;
                setForm(f);
                const s = f.settings || {};
                setSettings({
                    formTypeId: s.formTypeId ?? 1,
                    showScore: s.showScore ?? false,
                    randomizeQuestions: s.randomizeQuestions ?? false,
                    oneResponse: s.oneResponse ?? false,
                    requiredLogin: s.requiredLogin ?? false,
                    formToken: s.formToken ?? '',
                    timerDuration: s.timerDuration ? Math.round(s.timerDuration / 60) : '',
                    openFormTime: toLocalDatetimeInput(s.openFormTime),
                    closeFormTime: toLocalDatetimeInput(s.closeFormTime),
                    customFormLink: f.formLink || '',
                });
            }
            showToast('Pengaturan formulir berhasil disimpan!');
        } else {
            showToast(res.message || 'Gagal menyimpan pengaturan', 'error');
        }
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
                `${API_BASE_URL}/api/forms/${id}/share/qr?frontendUrl=${encodeURIComponent(FRONTEND_BASE_URL)}`,
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
            showToast(`Berhasil mengimpor ${res.data?.totalImported ?? 0} soal!`);
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                setQuestions(qRes.data.map((q, i) => ({
                    ...q,
                    _id: `q_${q.id}`,
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

    // Auto-save questions helper for unsaved questions before uploading image/audio
    const autoSaveBeforeUpload = async (idx) => {
        let currentQ = questions[idx];
        if (!currentQ.id) {
            const success = await handleSaveQuestions();
            if (!success) return null;
            const updatedList = await getQuestions(id);
            if (updatedList.ok && Array.isArray(updatedList.data) && updatedList.data[idx]) {
                return updatedList.data[idx].id;
            }
        }
        return currentQ.id;
    };

    const handleUploadQuestionImage = async (idx, file) => {
        const qId = await autoSaveBeforeUpload(idx);
        if (!qId) { showToast('Gagal memproses soal sebelum mengunggah gambar', 'error'); return; }

        const res = await uploadQuestionImage(id, qId, file);
        if (res.ok) {
            updateQuestion(idx, 'questionImage', res.data?.questionImage ?? null);
            showToast('Gambar soal berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah gambar', 'error');
        }
    };

    const handleUploadQuestionAudio = async (idx, file) => {
        const qId = await autoSaveBeforeUpload(idx);
        if (!qId) { showToast('Gagal memproses soal sebelum mengunggah audio', 'error'); return; }

        const res = await uploadQuestionAudio(id, qId, file);
        if (res.ok) {
            updateQuestion(idx, 'questionAudio', res.data?.questionAudio ?? null);
            showToast('Audio soal berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah audio', 'error');
        }
    };

    const handleRemoveQuestionImage = (idx) => {
        updateQuestion(idx, 'questionImage', null);
    };

    const handleRemoveQuestionAudio = (idx) => {
        updateQuestion(idx, 'questionAudio', null);
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

    const updateQuestion = (idx, field, value) =>
        setQuestions(prev => prev.map((q, i) => i === idx ? { ...q, [field]: value } : q));

    const openInsertModal = (qIdx, mode, targetType = 'question', oIdx = null) => {
        setModalTarget({ type: targetType, qIdx, oIdx });
        setModalMode(mode);
        setModalOpen(true);
    };

    const handleInsertFromModal = (snippetHtml) => {
        const { type, qIdx, oIdx } = modalTarget;
        if (qIdx === null) return;

        if (type === 'option' && oIdx !== null) {
            const current = questions[qIdx]?.options?.[oIdx]?.optionText || '';
            updateOption(qIdx, oIdx, 'optionText', current + (current ? ' ' : '') + snippetHtml);
        } else {
            const current = questions[qIdx]?.question || '';
            updateQuestion(qIdx, 'question', current + snippetHtml);
        }
    };

    const togglePreview = (idx) => {
        setPreviewVisibility(prev => ({ ...prev, [idx]: !prev[idx] }));
    };

    const addOption = (qIdx) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: [...q.options, { optionText: '', isCorrect: false }] } : q
        ));

    const removeOption = (qIdx, oIdx) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: q.options.filter((_, oi) => oi !== oIdx) } : q
        ));

    const updateOption = (qIdx, oIdx, field, val) =>
        setQuestions(prev => prev.map((q, i) => {
            if (i !== qIdx) return q;
            const opts = q.options.map((opt, oi) => {
                if (oi !== oIdx) return opt;
                return { ...opt, [field]: val };
            });
            return { ...q, options: opts };
        }));

    if (loading) {
        return (
            <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat builder formulir...</p>
            </div>
        );
    }

    const isPublished = form?.status?.toLowerCase() === 'published';

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 min-h-screen overflow-y-auto">

                {/* Top Header */}
                <div className="sticky top-0 z-30 bg-white/90 dark:bg-slate-900/90 backdrop-blur-md border-b border-slate-200/80 dark:border-slate-800 px-4 sm:px-6 py-3 flex items-center justify-between gap-4 shadow-xs">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/my-forms')} className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-xl transition-all cursor-pointer">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <div className="flex items-center gap-2">
                                <h1 className="text-sm sm:text-base font-extrabold text-slate-900 dark:text-white truncate">{form?.title || 'Formulir Tanpa Judul'}</h1>
                                <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full ${isPublished ? 'bg-teal-50 text-[#00897B] dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800' : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400'}`}>
                                    {isPublished ? 'Publik' : 'Draf'}
                                </span>
                            </div>
                            <p className="text-[11px] text-slate-400 dark:text-slate-500 font-mono">/f/{form?.formLink}</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                        <button
                            onClick={handleTogglePublish}
                            disabled={publishing}
                            className={`flex items-center gap-1.5 px-3 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${isPublished ? 'bg-amber-50 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-800 hover:bg-amber-100' : 'bg-[#00897B] hover:bg-[#00796B] text-white shadow-xs'}`}
                        >
                            {isPublished ? <Lock size={14} /> : <Globe size={14} />}
                            <span className="hidden sm:inline">{publishing ? 'Memproses...' : isPublished ? 'Jadikan Draf' : 'Publikasikan'}</span>
                        </button>

                        <button
                            onClick={activeTab === 'settings' ? handleSaveSettings : handleSaveQuestions}
                            disabled={saving}
                            className="flex items-center gap-1.5 px-4 py-2 bg-slate-900 hover:bg-slate-800 dark:bg-slate-700 dark:hover:bg-slate-600 text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer disabled:opacity-60"
                        >
                            <Save size={14} />
                            <span>{saving ? 'Menyimpan...' : 'Simpan Perubahan'}</span>
                        </button>
                    </div>
                </div>

                {toast && (
                    <div className={`fixed top-16 right-6 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-[#00897B]'}`}>
                        {toast.msg}
                    </div>
                )}

                {/* Sub-Header Tabs */}
                <div className="flex border-b border-slate-200/80 dark:border-slate-800 bg-white dark:bg-slate-900 px-6">
                    {[
                        { key: 'questions', label: 'Pertanyaan & Soal' },
                        { key: 'settings', label: 'Pengaturan & Aturan' },
                        { key: 'share', label: 'Bagikan & Kode QR' },
                    ].map(t => (
                        <button
                            key={t.key}
                            onClick={() => {
                                setActiveTab(t.key);
                                if (t.key === 'share') handleLoadShare();
                            }}
                            className={`py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all cursor-pointer ${activeTab === t.key ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400' : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'}`}
                        >
                            {t.label}
                        </button>
                    ))}
                </div>

                <div className="p-4 sm:p-6 lg:p-8 max-w-4xl mx-auto w-full space-y-6 flex-1">

                    {/* ── QUESTIONS TAB ── */}
                    {activeTab === 'questions' && (
                        <>
                            {/* Form Header Info Card */}
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs">
                                <div>
                                    <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">Judul Formulir</label>
                                    <input
                                        type="text"
                                        value={form?.title || ''}
                                        onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
                                        onBlur={() => updateForm(id, { title: form.title, description: form.description })}
                                        placeholder="Judul Formulir..."
                                        className="w-full text-xl font-extrabold bg-transparent text-slate-900 dark:text-white border-b border-transparent hover:border-slate-200 dark:hover:border-slate-700 focus:border-[#00897B] focus:outline-none py-1 transition-all"
                                    />
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">Deskripsi Formulir</label>
                                    <BlockQuestionEditor
                                        value={form?.description || ''}
                                        onChange={(newHtml) => setForm(f => ({ ...f, description: newHtml }))}
                                        placeholder="Tuliskan petunjuk atau deskripsi umum formulir..."
                                    />
                                </div>

                                {/* Banner Image Upload */}
                                <div className="pt-2 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        {form?.bannerImage && (
                                            <img src={assetUrl(form.bannerImage)} alt="Banner" className="w-16 h-10 object-cover rounded-lg border border-slate-200 dark:border-slate-700" />
                                        )}
                                        <span className="text-xs font-bold text-slate-600 dark:text-slate-300">
                                            {form?.bannerImage ? 'Gambar Banner Terpasang' : 'Belum Ada Gambar Banner'}
                                        </span>
                                    </div>
                                    <label className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-700 dark:text-slate-200 rounded-xl text-xs font-bold cursor-pointer transition-all">
                                        <Upload size={13} /> {form?.bannerImage ? 'Ubah Banner' : 'Unggah Banner'}
                                        <input type="file" accept="image/*" className="hidden" onChange={handleBannerUpload} />
                                    </label>
                                </div>

                                {/* Question Import Bar */}
                                <div className="pt-2 border-t border-slate-100 dark:border-slate-800 space-y-2">
                                    <div className="flex items-center justify-between gap-3">
                                        <p className="text-xs text-slate-400 dark:text-slate-500 font-medium">Impor soal dari XLSX, CSV, DOCX, atau PDF:</p>
                                        <label className="flex items-center gap-1.5 px-3 py-1.5 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 hover:bg-teal-100 rounded-xl text-xs font-bold cursor-pointer transition-all shrink-0">
                                            <FileUp size={13} /> {importLoading ? 'Mengimpor...' : 'Impor Soal'}
                                            <input type="file" accept=".xlsx,.csv,.docx,.pdf" className="hidden" onChange={handleImportFile} disabled={importLoading} />
                                        </label>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <span className="text-[11px] text-slate-400 dark:text-slate-500 font-medium">Unduh template:</span>
                                        {['csv', 'xlsx', 'docx (Under Development)'].map(fmt => (
                                            <a
                                                key={fmt}
                                                href={templateDownloadUrl(fmt)}
                                                download
                                                className="inline-flex items-center gap-1 px-2 py-1 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-lg text-[11px] font-bold transition-all"
                                            >
                                                <Download size={11} /> .{fmt.toUpperCase()}
                                            </a>
                                        ))}
                                    </div>
                                </div>
                            </div>

                            {/* Question Cards List */}
                            <div className="space-y-5">
                                {questions.map((q, idx) => (
                                    <div
                                        key={q._id || idx}
                                        className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs hover:border-slate-300 dark:hover:border-slate-700 transition-all"
                                    >
                                        {/* Card Header Controls */}
                                        <div className="flex items-center justify-between gap-2 border-b border-slate-100 dark:border-slate-800 pb-3">
                                            <div className="flex items-center gap-2">
                                                <span className="text-xs font-extrabold text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 px-2.5 py-1 rounded-lg">
                                                    Soal #{idx + 1}
                                                </span>
                                            </div>

                                            <div className="flex items-center gap-1">
                                                <button
                                                    type="button"
                                                    onClick={() => togglePreview(idx)}
                                                    className={`p-1.5 rounded-lg transition-all cursor-pointer ${previewVisibility[idx] ? 'bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400' : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'}`}
                                                    title="Toggle Live Preview"
                                                >
                                                    {previewVisibility[idx] ? <EyeOff size={15} /> : <Eye size={15} />}
                                                </button>

                                                <div className="h-4 w-px bg-slate-200 dark:bg-slate-700 mx-1" />

                                                <button onClick={() => moveQuestion(idx, -1)} disabled={idx === 0} className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 disabled:opacity-30 cursor-pointer" title="Pindah Naik">
                                                    <ChevronUp size={16} />
                                                </button>
                                                <button onClick={() => moveQuestion(idx, 1)} disabled={idx === questions.length - 1} className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 disabled:opacity-30 cursor-pointer" title="Pindah Turun">
                                                    <ChevronDown size={16} />
                                                </button>
                                                <button onClick={() => handleDeleteQuestion(idx)} className="p-1 text-red-400 hover:text-red-600 cursor-pointer" title="Hapus Soal">
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        </div>

                                        {/* Media Attachments at the TOP of the Question */}
                                        <div className="pb-3 border-b border-slate-100 dark:border-slate-800 space-y-2">
                                            <div className="flex flex-wrap items-center gap-3">
                                                {/* Image attachment */}
                                                {q.questionImage ? (
                                                    <div className="flex items-center gap-2 bg-slate-50 dark:bg-slate-800 p-2 rounded-xl border border-slate-200 dark:border-slate-700">
                                                        <img
                                                            src={assetUrl(q.questionImage)}
                                                            alt="Soal"
                                                            className="h-14 w-24 object-cover rounded-lg cursor-zoom-in hover:opacity-90 transition-opacity"
                                                            onClick={() => setLightboxImage({ src: assetUrl(q.questionImage), alt: 'Gambar Soal' })}
                                                            title="Klik untuk memperbesar gambar"
                                                        />
                                                        <div className="flex flex-col gap-1">
                                                            <label className="text-[11px] font-bold text-[#00897B] dark:text-teal-400 cursor-pointer hover:underline">
                                                                Ganti Gambar
                                                                <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                            </label>
                                                            <button
                                                                type="button"
                                                                onClick={() => handleRemoveQuestionImage(idx)}
                                                                className="text-[10px] font-bold text-red-500 hover:underline flex items-center gap-1 cursor-pointer"
                                                            >
                                                                <X size={11} /> Hapus Gambar
                                                            </button>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 cursor-pointer hover:border-[#00897B] hover:text-[#00897B] transition-all">
                                                        <Image size={13} /> Tambah Gambar Soal
                                                        <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                    </label>
                                                )}

                                                {/* Audio attachment */}
                                                {q.questionAudio ? (
                                                    <div className="flex items-center gap-2 bg-slate-50 dark:bg-slate-800 p-2 rounded-xl border border-slate-200 dark:border-slate-700">
                                                        <audio controls src={assetUrl(q.questionAudio)} className="h-8 max-w-[200px]" />
                                                        <div className="flex flex-col gap-1">
                                                            <label className="text-[11px] font-bold text-[#00897B] dark:text-teal-400 cursor-pointer hover:underline">
                                                                Ganti Audio
                                                                <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                            </label>
                                                            <button
                                                                type="button"
                                                                onClick={() => handleRemoveQuestionAudio(idx)}
                                                                className="text-[10px] font-bold text-red-500 hover:underline flex items-center gap-1 cursor-pointer"
                                                            >
                                                                <X size={11} /> Hapus Audio
                                                            </button>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 cursor-pointer hover:border-[#00897B] hover:text-[#00897B] transition-all">
                                                        <Music size={13} /> Tambah Audio Soal
                                                        <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                    </label>
                                                )}
                                            </div>
                                        </div>

                                        {/* Question Block Editor (Modular Notion-style) */}
                                        <div className="space-y-2">
                                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block">Isi Pertanyaan Soal</label>
                                            <BlockQuestionEditor
                                                value={q.question || ''}
                                                onChange={(newHtml) => updateQuestion(idx, 'question', newHtml)}
                                                placeholder="Tuliskan teks pertanyaan soal, kode program, atau rumus..."
                                            />
                                        </div>

                                        {/* Live Preview Box with Word Wrap Fix */}
                                        {previewVisibility[idx] && (
                                            <div className="p-4 bg-slate-50 dark:bg-slate-800/80 rounded-xl border border-slate-200/80 dark:border-slate-700 space-y-2 overflow-hidden">
                                                <div className="flex items-center justify-between text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                                                    <span>Live Preview</span>
                                                </div>
                                                <div className="break-words break-all [overflow-wrap:anywhere]">
                                                    <RichContentRenderer content={q.question} format={q.questionFormat} className="text-sm font-semibold text-slate-800 dark:text-slate-100" />
                                                </div>
                                            </div>
                                        )}

                                        {/* Question Type & Settings */}
                                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                            <div>
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">Tipe Soal</label>
                                                <select
                                                    value={q.typeId}
                                                    onChange={e => updateQuestion(idx, 'typeId', parseInt(e.target.value))}
                                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                >
                                                    {QUESTION_TYPES.map(t => (
                                                        <option key={t.id} value={t.id}>{t.label}</option>
                                                    ))}
                                                </select>
                                            </div>

                                            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-end gap-4 pt-1 sm:pt-5">
                                                <label className="flex items-center gap-2 text-xs font-bold text-slate-700 dark:text-slate-300 cursor-pointer">
                                                    <input
                                                        type="checkbox"
                                                        checked={q.isScorable !== false}
                                                        onChange={e => updateQuestion(idx, 'isScorable', e.target.checked)}
                                                        className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                                    />
                                                    <span>Hitung ke Skor (Dinilai)</span>
                                                </label>

                                                <label className="flex items-center gap-2 text-xs font-bold text-slate-700 dark:text-slate-300 cursor-pointer">
                                                    <input
                                                        type="checkbox"
                                                        checked={!!q.isRequired}
                                                        onChange={e => updateQuestion(idx, 'isRequired', e.target.checked)}
                                                        className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                                    />
                                                    <span>Soal Wajib Diisi</span>
                                                </label>
                                            </div>
                                        </div>

                                        {/* Points input — visible only when scorable */}
                                        {q.isScorable !== false && (
                                            <div className="flex items-center gap-3">
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 whitespace-nowrap">Poin Soal</label>
                                                <input
                                                    type="number"
                                                    min="0"
                                                    step="1"
                                                    placeholder="Kosongi = bobot sama rata"
                                                    value={q.points ?? ''}
                                                    onChange={e => updateQuestion(idx, 'points', e.target.value === '' ? null : parseInt(e.target.value, 10))}
                                                    className="w-40 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                />
                                                <span className="text-[10px] text-slate-400 dark:text-slate-500 italic">opsional — biarkan kosong untuk bobot sama rata</span>
                                            </div>
                                        )}

                                        {/* Non-Scorable Notice */}
                                        {q.isScorable === false ? (
                                            <div className="p-3 bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-700/80 rounded-xl flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                                                <span className="w-2 h-2 rounded-full bg-slate-400 shrink-0" />
                                                <span>Soal ini <b>Tidak Dinilai</b> (digunakan untuk pengumpulan data seperti Nama, Email, NIM, atau survei umum). Tidak memerlukan kunci jawaban dan tidak memengaruhi skor.</span>
                                            </div>
                                        ) : null}

                                                {needsOptions(q.typeId) && (
                                            <div className="space-y-3 pt-3 border-t border-slate-100 dark:border-slate-800">
                                                <div className="flex items-center justify-between">
                                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block">Pilihan Jawaban:</label>
                                                    {q.isScorable !== false && (
                                                        <span className="text-[11px] text-slate-400 dark:text-slate-500">
                                                            {q.typeId === 2
                                                                ? '● Pilih 1 jawaban benar (radio)'
                                                                : '☑ Centang semua jawaban benar'}
                                                        </span>
                                                    )}
                                                </div>
                                                {q.options.map((opt, oIdx) => (
                                                    <div key={oIdx} className="space-y-1">
                                                        <div className="flex items-center gap-2">
                                                            {q.isScorable !== false ? (
                                                                <label className="flex items-center gap-1 cursor-pointer">
                                                                    {q.typeId === 2 ? (
                                                                        // TASK 3: Multiple Choice → radio (single-select)
                                                                        <input
                                                                            type="radio"
                                                                            name={`correct_q${idx}`}
                                                                            checked={!!opt.isCorrect}
                                                                            onChange={() => {
                                                                                setQuestions(prev => prev.map((qq, qi) => {
                                                                                    if (qi !== idx) return qq;
                                                                                    return {
                                                                                        ...qq,
                                                                                        options: qq.options.map((o, oi) => ({
                                                                                            ...o,
                                                                                            isCorrect: oi === oIdx,
                                                                                        })),
                                                                                    };
                                                                                }));
                                                                            }}
                                                                            className="w-4 h-4 shrink-0 cursor-pointer accent-[#00897B]"
                                                                            title="Tandai sebagai satu-satunya jawaban benar"
                                                                        />
                                                                    ) : (
                                                                        // TASK 3: Checkbox type → checkbox (multi-select unchanged)
                                                                        <input
                                                                            type="checkbox"
                                                                            checked={!!opt.isCorrect}
                                                                            onChange={e => updateOption(idx, oIdx, 'isCorrect', e.target.checked)}
                                                                            className="w-4 h-4 text-[#00897B] rounded shrink-0 cursor-pointer"
                                                                            title="Tandai sebagai jawaban benar"
                                                                        />
                                                                    )}
                                                                    {opt.isCorrect && <span className="text-[10px] font-extrabold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 px-1.5 py-0.5 rounded">✓ Benar</span>}
                                                                </label>
                                                            ) : (
                                                                <span className="w-5 h-5 flex items-center justify-center text-[10px] font-bold text-slate-400 bg-slate-100 dark:bg-slate-800 rounded-full shrink-0">
                                                                    {String.fromCharCode(65 + oIdx)}
                                                                </span>
                                                            )}

                                                            <div className="flex-1 flex items-center gap-1">
                                                                <input
                                                                    placeholder={`Pilihan ${oIdx + 1}`}
                                                                    value={opt.optionText}
                                                                    onChange={e => updateOption(idx, oIdx, 'optionText', e.target.value)}
                                                                    className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                                />
                                                                <button
                                                                    type="button"
                                                                    onClick={() => openInsertModal(idx, 'math', 'option', oIdx)}
                                                                    className="p-1 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 rounded cursor-pointer"
                                                                    title="Sisipkan Rumus (KaTeX)"
                                                                >
                                                                    <Calculator size={14} />
                                                                </button>
                                                                <button
                                                                    type="button"
                                                                    onClick={() => openInsertModal(idx, 'code', 'option', oIdx)}
                                                                    className="p-1 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 rounded cursor-pointer"
                                                                    title="Sisipkan Kode Block"
                                                                >
                                                                    <Code size={14} />
                                                                </button>
                                                            </div>

                                                            <button onClick={() => removeOption(idx, oIdx)} className="text-red-400 hover:text-red-600 p-1 shrink-0 cursor-pointer">
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>

                                                        {/* Option Rich Content Preview if formula/code inserted */}
                                                        {(opt.optionText?.includes('$') || opt.optionText?.includes('<pre') || opt.optionText?.includes('<code')) && (
                                                            <div className="ml-6 p-2 bg-slate-50 dark:bg-slate-800/60 rounded-lg text-xs border border-slate-200/60 dark:border-slate-700">
                                                                <RichContentRenderer content={opt.optionText} format="text" className="text-xs" />
                                                            </div>
                                                        )}
                                                    </div>
                                                ))}
                                                <button onClick={() => addOption(idx)} className="text-xs font-bold text-[#00897B] dark:text-teal-400 hover:underline mt-1 cursor-pointer">
                                                    + Tambah Pilihan
                                                </button>
                                            </div>
                                        )}

                                        {/* Answer Key for Essay / Date / True-False (Only if isScorable !== false) */}
                                        {q.isScorable !== false && [1, 4, 5].includes(q.typeId) && (
                                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">
                                                    Jawaban Benar yang Diharapkan (untuk penilaian otomatis & skor):
                                                </label>
                                                {q.typeId === 5 ? (
                                                    <select
                                                        value={(() => {
                                                            const v = q.correctAnswer || 'Benar';
                                                            return (v === 'True' || v === 'true') ? 'Benar' : (v === 'False' || v === 'false') ? 'Salah' : v;
                                                        })()}
                                                        onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-[#00897B] bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
                                                    >
                                                        <option value="Benar">Benar</option>
                                                        <option value="Salah">Salah</option>
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
                                    </div>
                                ))}
                            </div>

                            {questions.length === 0 && (
                                <div className="py-8 text-center border-2 border-dashed border-slate-200 dark:border-slate-700 rounded-2xl bg-white/60 dark:bg-slate-900/60">
                                    <p className="text-sm font-bold text-slate-500 dark:text-slate-400">Belum ada soal</p>
                                    <p className="text-xs text-slate-400 dark:text-slate-500 mt-1">Form tanpa soal akan tersimpan kosong (0 soal) dan otomatis kembali menjadi draf.</p>
                                </div>
                            )}
                            <div className="flex gap-2">
                                <button
                                    onClick={addQuestion}
                                    className="flex-1 py-3.5 border-2 border-dashed border-slate-300 dark:border-slate-700 rounded-2xl text-xs font-extrabold text-slate-600 dark:text-slate-400 hover:border-[#00897B] dark:hover:border-teal-400 hover:text-[#00897B] dark:hover:text-teal-400 transition-all flex items-center justify-center gap-2 bg-white/60 dark:bg-slate-900/60 cursor-pointer"
                                >
                                    <Plus size={18} /> Tambah Soal Baru
                                </button>
                                {questions.length > 0 && (
                                    <button
                                        onClick={handleClearAllQuestions}
                                        className="px-4 py-3.5 border border-red-200 dark:border-red-900 rounded-2xl text-xs font-extrabold text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 transition-all flex items-center justify-center gap-2 bg-white dark:bg-slate-900 cursor-pointer"
                                    >
                                        <Trash2 size={16} /> Hapus Semua
                                    </button>
                                )}
                            </div>
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
                                            {FRONTEND_BASE_URL}/f/
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
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Waktu Tutup Formulir (Opsional)</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.closeFormTime}
                                            onChange={e => setSettings(s => ({ ...s, closeFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Token Kata Sandi Formulir (Opsional)</label>
                                    <input
                                        type="text"
                                        value={settings.formToken}
                                        onChange={e => setSettings(s => ({ ...s, formToken: e.target.value }))}
                                        placeholder="contoh: RAHASIA123"
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>

                                <div className="space-y-3 pt-2">
                                    {[
                                        { key: 'showScore', label: 'Tampilkan Skor & Kunci Jawaban setelah Pengisian' },
                                        { key: 'randomizeQuestions', label: 'Acak Urutan Soal untuk Setiap Responden' },
                                        { key: 'oneResponse', label: 'Batasi 1 Kali Pengisian per Responden/Sesi' },
                                        { key: 'requiredLogin', label: 'Wajib Login Akun FormUp sebelum Mengisi' },
                                    ].map(({ key, label }) => (
                                        <label key={key} className="flex items-center gap-3 cursor-pointer">
                                            <input
                                                type="checkbox"
                                                checked={settings[key]}
                                                onChange={e => setSettings(s => ({ ...s, [key]: e.target.checked }))}
                                                className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                            />
                                            <span className="text-xs font-bold text-slate-700 dark:text-slate-300">{label}</span>
                                        </label>
                                    ))}
                                </div>

                                <div className="pt-4 border-t border-slate-100 dark:border-slate-800 flex justify-end">
                                    <button
                                        type="button"
                                        onClick={handleSaveSettings}
                                        disabled={saving}
                                        className="px-5 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl shadow-xs transition-all flex items-center gap-2 cursor-pointer disabled:opacity-60"
                                    >
                                        <Save size={14} />
                                        <span>{saving ? 'Menyimpan...' : 'Simpan Pengaturan'}</span>
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ── SHARE TAB ── */}
                    {activeTab === 'share' && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-6 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-900 dark:text-white border-b border-slate-100 dark:border-slate-800 pb-3">
                                Bagikan Tautan & Kode QR Formulir
                            </h2>

                            <div className="space-y-4">
                                <div>
                                    <label className="text-xs font-bold text-slate-600 dark:text-slate-400 block mb-1">Tautan Publik Formulir</label>
                                    <div className="flex items-center gap-2">
                                        <input
                                            type="text"
                                            readOnly
                                            value={`${FRONTEND_BASE_URL}/f/${form?.formLink}`}
                                            className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-mono font-bold bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-slate-100"
                                        />
                                        <button
                                            onClick={() => {
                                                navigator.clipboard.writeText(`${FRONTEND_BASE_URL}/f/${form?.formLink}`);
                                                setCopiedLink(true);
                                                setTimeout(() => setCopiedLink(false), 2000);
                                            }}
                                            className="px-4 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white font-bold text-xs rounded-xl shadow-xs transition-all cursor-pointer"
                                        >
                                            {copiedLink ? '✓ Tersalin!' : 'Salin Tautan'}
                                        </button>
                                    </div>
                                </div>

                                {qrBlobUrl && (
                                    <div className="pt-4 border-t border-slate-100 dark:border-slate-800 flex flex-col items-center gap-3">
                                        <label className="text-xs font-bold text-slate-600 dark:text-slate-400 block">Kode QR Gambar PNG</label>
                                        <img src={qrBlobUrl} alt="Kode QR" className="w-44 h-44 border border-slate-200 dark:border-slate-700 rounded-2xl p-2 bg-white shadow-xs" />
                                        <a
                                            href={qrBlobUrl}
                                            download={`qr-${form?.formLink}.png`}
                                            className="px-4 py-2 bg-slate-900 hover:bg-slate-800 dark:bg-slate-700 dark:hover:bg-slate-600 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-xs transition-all"
                                        >
                                            <Download size={13} /> Unduh Kode QR PNG
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

            {/* Lightbox Modal */}
            <ImageLightboxModal
                isOpen={!!lightboxImage}
                src={lightboxImage?.src}
                alt={lightboxImage?.alt}
                onClose={() => setLightboxImage(null)}
            />
        </div>
    );
}
