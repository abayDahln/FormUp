import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Save, Plus, Trash2, ChevronUp, ChevronDown,
    Globe, Lock, ArrowLeft, Upload, FileUp, Image, Music, Download,
    GripVertical, Code, Calculator, Eye, EyeOff
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

    // Modal state for Code & KaTeX Math insertion
    const [modalOpen, setModalOpen] = useState(false);
    const [modalMode, setModalMode] = useState('math'); // 'math' or 'code'
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
            showToast('Questions saved successfully!');
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
            showToast(res.message || 'Failed to save questions', 'error');
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
                showToast(formRes.message || 'Failed to update custom form link', 'error');
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
        showToast(res.ok ? 'Settings saved!' : (res.message || 'Failed to save settings'), res.ok ? 'success' : 'error');
    };

    const handleTogglePublish = async () => {
        setPublishing(true);
        const res = await togglePublishForm(id);
        if (res.ok) {
            const updated = await getFormById(id);
            if (updated.ok) setForm(updated.data);
            showToast(res.message || 'Form status updated!');
        } else {
            showToast(res.message || 'Failed to toggle status', 'error');
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
            showToast('Banner updated!');
        } else {
            showToast(res.message || 'Upload failed', 'error');
        }
    };

    const handleImportFile = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setImportLoading(true);
        const res = await importQuestions(id, file);
        setImportLoading(false);
        if (res.ok) {
            showToast(`Imported! ${res.message}`);
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
            showToast(res.message || 'Import failed', 'error');
        }
        e.target.value = '';
    };

    const handleDeleteQuestion = async (idx) => {
        const q = questions[idx];
        if (q.id) {
            const res = await deleteQuestion(id, q.id);
            if (!res.ok) { showToast(res.message || 'Failed to delete question', 'error'); return; }
        }
        setQuestions(prev => prev.filter((_, i) => i !== idx));
        showToast('Question removed');
    };

    const handleUploadQuestionImage = async (idx, file) => {
        const q = questions[idx];
        if (!q.id) { showToast('Save questions first before uploading image', 'error'); return; }
        const res = await uploadQuestionImage(id, q.id, file);
        if (res.ok) {
            updateQuestion(idx, 'questionImage', res.data?.questionImage ?? null);
            showToast('Image uploaded!');
        } else {
            showToast(res.message || 'Upload failed', 'error');
        }
    };

    const handleUploadQuestionAudio = async (idx, file) => {
        const q = questions[idx];
        if (!q.id) { showToast('Save questions first before uploading audio', 'error'); return; }
        const res = await uploadQuestionAudio(id, q.id, file);
        if (res.ok) {
            updateQuestion(idx, 'questionAudio', res.data?.questionAudio ?? null);
            showToast('Audio uploaded!');
        } else {
            showToast(res.message || 'Upload failed', 'error');
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

    const isPublished = form?.status?.toLowerCase() === 'published';

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-slate-50">
            <p className="text-slate-400 text-sm font-medium">Loading form builder...</p>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                {/* Header Navbar */}
                <div className="sticky top-0 z-20 bg-white border-b border-slate-200 px-6 py-3.5 flex items-center justify-between gap-4 shadow-xs">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/my-forms')} className="p-2 text-slate-400 hover:text-slate-700 hover:bg-slate-100 rounded-xl transition-all">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <h1 className="text-base font-extrabold text-slate-900 truncate">{form?.title || 'Untitled Form'}</h1>
                            <p className="text-xs text-slate-400 font-mono">/f/{form?.formLink}</p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                        <span className={`text-xs font-bold px-3 py-1 rounded-full ${isPublished ? 'bg-teal-50 text-teal-600 border border-teal-200' : 'bg-slate-100 text-slate-500'}`}>
                            {isPublished ? 'Published' : 'Draft'}
                        </span>
                        <button
                            onClick={handleTogglePublish}
                            disabled={publishing}
                            className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all disabled:opacity-60 ${isPublished ? 'bg-amber-50 text-amber-600 hover:bg-amber-100 border border-amber-200' : 'bg-teal-600 text-white hover:bg-teal-700 shadow-sm'}`}
                        >
                            {isPublished ? <><Lock size={13} /> Unpublish</> : <><Globe size={13} /> Publish</>}
                        </button>
                        {activeTab === 'questions' && (
                            <button
                                onClick={handleSaveQuestions}
                                disabled={saving}
                                className="flex items-center gap-1.5 px-4 py-1.5 bg-slate-900 hover:bg-slate-800 text-white rounded-xl text-xs font-bold shadow-sm transition-all disabled:opacity-60"
                            >
                                <Save size={14} /> {saving ? 'Saving...' : 'Save Changes'}
                            </button>
                        )}
                    </div>
                </div>

                {/* Toast Notification */}
                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-teal-600'}`}>
                        {toast.msg}
                    </div>
                )}

                {/* Navigation Tabs */}
                <div className="flex border-b border-slate-200 bg-white px-6">
                    {[
                        { key: 'questions', label: '📝 Questions' },
                        { key: 'settings', label: '⚙️ Settings' },
                        { key: 'share', label: '🔗 Share & QR' },
                    ].map(tab => (
                        <button
                            key={tab.key}
                            onClick={() => { setActiveTab(tab.key); if (tab.key === 'share' && !shareInfo) handleLoadShare(); }}
                            className={`py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all ${activeTab === tab.key ? 'border-teal-600 text-teal-600' : 'border-transparent text-slate-400 hover:text-slate-700'}`}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>

                <div className="p-6 max-w-3xl mx-auto w-full space-y-5">

                    {/* ── QUESTIONS TAB ── */}
                    {activeTab === 'questions' && (
                        <>
                            {/* Form Header Info Card */}
                            <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-4">
                                <h2 className="text-xs font-extrabold text-slate-400 uppercase tracking-wider">Form Meta Info</h2>
                                <div>
                                    <label className="text-xs font-bold text-slate-600 mb-1 block">Title</label>
                                    <input
                                        value={form?.title ?? ''}
                                        onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
                                        onBlur={() => form?.title && updateForm(id, { title: form.title, description: form.description })}
                                        className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-teal-400"
                                    />
                                </div>
                                <div>
                                    <label className="text-xs font-bold text-slate-600 mb-1 block">Description</label>
                                    <SummernoteEditor
                                        value={form?.description ?? ''}
                                        onChange={val => {
                                            setForm(f => ({ ...f, description: val }));
                                            updateForm(id, { title: form.title, description: val });
                                        }}
                                        placeholder="Form description or details..."
                                        className="w-full"
                                    />
                                </div>
                                <div>
                                    <label className="text-xs font-bold text-slate-600 mb-1 block">Banner Image</label>
                                    {form?.bannerImage && (
                                        <img src={assetUrl(form.bannerImage)} alt="banner" className="w-full h-28 object-cover rounded-xl mb-2 border border-slate-200" />
                                    )}
                                    <label className="flex items-center gap-2 cursor-pointer px-3.5 py-2 border border-dashed border-slate-300 rounded-xl text-xs font-bold text-slate-600 hover:border-teal-400 hover:text-teal-600 transition-all w-fit">
                                        <Upload size={14} /> Upload Banner
                                        <input type="file" accept="image/*" className="hidden" onChange={handleBannerUpload} />
                                    </label>
                                </div>
                            </div>

                            {/* Question Import & Template Downloads Toolbar */}
                            <div className="bg-white rounded-2xl border border-slate-200 p-4 flex flex-wrap items-center justify-between gap-3 shadow-xs">
                                <div className="flex items-center gap-3">
                                    <span className="text-xs font-bold text-slate-700">Import Questions:</span>
                                    <label className={`flex items-center gap-1.5 px-3 py-1.5 bg-teal-50 border border-teal-200 text-teal-700 rounded-xl text-xs font-bold cursor-pointer hover:bg-teal-100 transition-all ${importLoading ? 'opacity-50 pointer-events-none' : ''}`}>
                                        <FileUp size={14} /> {importLoading ? 'Importing...' : 'Upload File (.xlsx, .csv, .docx, .pdf)'}
                                        <input type="file" accept=".csv,.xlsx,.xls,.pdf,.docx" className="hidden" onChange={handleImportFile} />
                                    </label>
                                </div>
                                <div className="flex items-center gap-1.5">
                                    <span className="text-xs text-slate-400 font-semibold mr-1">Templates:</span>
                                    {['csv', 'xlsx', 'docx', 'pdf'].map(fmt => (
                                        <a
                                            key={fmt}
                                            href={templateDownloadUrl(fmt)}
                                            target="_blank"
                                            rel="noreferrer"
                                            className="flex items-center gap-1 px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 text-[11px] font-extrabold rounded-lg transition-all"
                                        >
                                            <Download size={11} /> {fmt.toUpperCase()}
                                        </a>
                                    ))}
                                </div>
                            </div>

                            {/* Questions Cards with Drag and Drop */}
                            <div className="space-y-4">
                                {questions.map((q, idx) => (
                                    <div
                                        key={q._id}
                                        draggable
                                        onDragStart={() => handleDragStart(idx)}
                                        onDragOver={(e) => handleDragOver(e, idx)}
                                        onDragEnd={() => setDragIndex(null)}
                                        className={`bg-white rounded-2xl border transition-all p-5 shadow-xs space-y-3 relative group ${dragIndex === idx ? 'border-teal-400 ring-2 ring-teal-100 shadow-md bg-teal-50/20' : 'border-slate-200 hover:border-slate-300'}`}
                                    >
                                        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                                            <div className="flex items-center gap-2">
                                                <div className="cursor-grab active:cursor-grabbing p-1 text-slate-300 hover:text-slate-600 rounded">
                                                    <GripVertical size={16} />
                                                </div>
                                                <span className="text-xs font-extrabold text-slate-700 bg-slate-100 px-2 py-0.5 rounded-md">Q{idx + 1}</span>
                                                {q.id && <span className="text-[10px] text-slate-400 font-mono">ID: {q.id}</span>}
                                            </div>

                                            {/* Toolbar for KaTeX & Code Snippets */}
                                            <div className="flex items-center gap-1.5">
                                                <button
                                                    type="button"
                                                    onClick={() => openInsertModal(idx, 'math')}
                                                    className="flex items-center gap-1 px-2.5 py-1 bg-teal-50 hover:bg-teal-100 border border-teal-200 text-teal-700 text-xs font-bold rounded-lg transition-all"
                                                    title="Insert KaTeX Math Formula"
                                                >
                                                    <Calculator size={13} /> KaTeX Math
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => openInsertModal(idx, 'code')}
                                                    className="flex items-center gap-1 px-2.5 py-1 bg-slate-900 hover:bg-slate-800 text-teal-400 text-xs font-mono font-bold rounded-lg transition-all"
                                                    title="Insert Code Snippet"
                                                >
                                                    <Code size={13} /> Code Block
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => togglePreview(idx)}
                                                    className={`flex items-center gap-1 px-2.5 py-1 text-xs font-bold rounded-lg transition-all border ${previewVisibility[idx] ? 'bg-teal-600 text-white border-teal-600' : 'bg-slate-100 text-slate-600 border-slate-200 hover:bg-slate-200'}`}
                                                    title="Toggle Live Preview"
                                                >
                                                    {previewVisibility[idx] ? <EyeOff size={13} /> : <Eye size={13} />}
                                                    <span>Preview</span>
                                                </button>
                                                <div className="w-px h-4 bg-slate-200 mx-1" />
                                                <button onClick={() => moveQuestion(idx, -1)} className="p-1 text-slate-300 hover:text-slate-600 rounded"><ChevronUp size={15} /></button>
                                                <button onClick={() => moveQuestion(idx, 1)} className="p-1 text-slate-300 hover:text-slate-600 rounded"><ChevronDown size={15} /></button>
                                                <button onClick={() => handleDeleteQuestion(idx)} className="p-1 text-red-400 hover:text-red-600 rounded"><Trash2 size={15} /></button>
                                            </div>
                                        </div>

                                        {/* Question Summernote Editor */}
                                        <SummernoteEditor
                                            value={q.question}
                                            onChange={val => updateQuestion(idx, 'question', val)}
                                            placeholder="Type question text..."
                                            className="w-full"
                                        />

                                        {/* Single Clean Live Preview Box (Toggled on/off per question) */}
                                        {previewVisibility[idx] && q.question && (
                                            <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 space-y-1">
                                                <p className="text-[10px] font-extrabold text-slate-400 uppercase tracking-wider flex items-center gap-1">
                                                    <Eye size={11} className="text-teal-600" /> Live Question Preview:
                                                </p>
                                                <div className="pt-1">
                                                    <RichContentRenderer content={q.question} className="text-xs text-slate-800" />
                                                </div>
                                            </div>
                                        )}

                                        <div className="flex items-center justify-between flex-wrap gap-3 pt-1">
                                            <div className="flex items-center gap-3">
                                                <label className="text-xs font-bold text-slate-500">Type:</label>
                                                <select
                                                    value={q.typeId}
                                                    onChange={e => updateQuestion(idx, 'typeId', parseInt(e.target.value))}
                                                    className="border border-slate-200 rounded-xl px-3 py-1.5 text-xs font-bold text-slate-700 focus:outline-none focus:ring-2 focus:ring-teal-400 bg-white"
                                                >
                                                    {QUESTION_TYPES.map(t => <option key={t.id} value={t.id}>{t.label}</option>)}
                                                </select>
                                            </div>
                                            <label className="flex items-center gap-2 text-xs font-bold text-slate-700 cursor-pointer">
                                                <input
                                                    type="checkbox"
                                                    checked={q.isRequired}
                                                    onChange={e => updateQuestion(idx, 'isRequired', e.target.checked)}
                                                    className="w-4 h-4 text-teal-600 rounded"
                                                />
                                                Required Question
                                            </label>
                                        </div>

                                        {/* Choice Options */}
                                        {needsOptions(q.typeId) && (
                                            <div className="space-y-2 pt-2 border-t border-slate-100">
                                                <label className="text-xs font-bold text-slate-500 block">Options:</label>
                                                {q.options.map((opt, oIdx) => (
                                                    <div key={oIdx} className="flex items-center gap-2">
                                                        <input
                                                            type="checkbox"
                                                            checked={opt.isCorrect}
                                                            onChange={e => updateOption(idx, oIdx, 'isCorrect', e.target.checked)}
                                                            className="w-4 h-4 text-teal-600 rounded shrink-0 cursor-pointer"
                                                            title="Mark as correct answer"
                                                        />
                                                        <input
                                                            placeholder={`Option ${oIdx + 1}`}
                                                            value={opt.optionText}
                                                            onChange={e => updateOption(idx, oIdx, 'optionText', e.target.value)}
                                                            className="flex-1 border border-slate-200 rounded-xl px-3 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                                                        />
                                                        <button onClick={() => removeOption(idx, oIdx)} className="text-red-300 hover:text-red-500 p-1 shrink-0">
                                                            <Trash2 size={14} />
                                                        </button>
                                                    </div>
                                                ))}
                                                <button onClick={() => addOption(idx)} className="text-xs font-bold text-teal-600 hover:underline mt-1">
                                                    + Add Option
                                                </button>
                                            </div>
                                        )}

                                        {/* Correct answer input for Essay / Text */}
                                        {q.typeId === 1 && (
                                            <div className="pt-2 border-t border-slate-100">
                                                <label className="text-xs font-bold text-slate-500 block mb-1">Expected Correct Answer (for auto-grading):</label>
                                                <input
                                                    placeholder="e.g. 4 or Soekarno"
                                                    value={q.correctAnswer}
                                                    onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                    className="w-full border border-slate-200 rounded-xl px-3 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                                                />
                                            </div>
                                        )}

                                        {/* Image / Audio Uploads */}
                                        {q.id ? (
                                            <div className="flex flex-wrap items-center gap-3 pt-2 border-t border-slate-100">
                                                {q.questionImage ? (
                                                    <div className="flex items-center gap-2">
                                                        <img src={assetUrl(q.questionImage)} alt="question" className="h-12 w-20 object-cover rounded-lg border border-slate-200" />
                                                        <label className="text-xs font-bold text-teal-600 cursor-pointer hover:underline">
                                                            Change image
                                                            <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                        </label>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 rounded-xl text-xs font-bold text-slate-600 cursor-pointer hover:border-teal-400 hover:text-teal-600 transition-all">
                                                        <Image size={13} /> Add Image
                                                        <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                    </label>
                                                )}

                                                {q.questionAudio ? (
                                                    <div className="flex items-center gap-2">
                                                        <audio controls src={assetUrl(q.questionAudio)} className="h-8 text-xs" />
                                                        <label className="text-xs font-bold text-teal-600 cursor-pointer hover:underline">
                                                            Change audio
                                                            <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                        </label>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 rounded-xl text-xs font-bold text-slate-600 cursor-pointer hover:border-teal-400 hover:text-teal-600 transition-all">
                                                        <Music size={13} /> Add Audio
                                                        <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                    </label>
                                                )}
                                            </div>
                                        ) : (
                                            <p className="text-[11px] text-slate-400 italic">Save question first to upload image or audio.</p>
                                        )}
                                    </div>
                                ))}
                            </div>

                            <button
                                onClick={addQuestion}
                                className="w-full py-3.5 border-2 border-dashed border-slate-300 rounded-2xl text-xs font-extrabold text-slate-500 hover:border-teal-500 hover:text-teal-600 transition-all flex items-center justify-center gap-2 bg-white/50"
                            >
                                <Plus size={18} /> Add New Question
                            </button>
                        </>
                    )}

                    {/* ── SETTINGS TAB ── */}
                    {activeTab === 'settings' && (
                        <div className="bg-white rounded-2xl border border-slate-200 p-6 space-y-6 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-800 border-b border-slate-100 pb-3">Form Configuration & Rules</h2>

                            <div className="space-y-4">
                                <div>
                                    <label className="text-xs font-bold text-slate-700 block mb-1">Custom Form Link Slug</label>
                                    <div className="flex items-center gap-2">
                                        <span className="text-xs font-mono text-slate-400 bg-slate-100 px-3 py-2 rounded-xl border border-slate-200">{window.location.origin}/f/</span>
                                        <input
                                            value={settings.customFormLink}
                                            onChange={e => setSettings(s => ({ ...s, customFormLink: e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '') }))}
                                            placeholder="my-custom-link"
                                            className="flex-1 border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-teal-400"
                                        />
                                    </div>
                                    <p className="text-[11px] text-slate-400 mt-1">Only lowercase letters, numbers, and hyphens (3-100 chars).</p>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs font-bold text-slate-700 block mb-1">Form Layout Type</label>
                                        <select
                                            value={settings.formTypeId}
                                            onChange={e => setSettings(s => ({ ...s, formTypeId: parseInt(e.target.value) }))}
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-teal-400 bg-white"
                                        >
                                            <option value={1}>Single Page Form</option>
                                            <option value={2}>Multi Page / Step Form</option>
                                        </select>
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 block mb-1">Timer Duration (minutes)</label>
                                        <input
                                            type="number"
                                            min="0"
                                            value={settings.timerDuration}
                                            onChange={e => setSettings(s => ({ ...s, timerDuration: e.target.value }))}
                                            placeholder="0 (no timer)"
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-teal-400"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
                                    <div>
                                        <label className="text-xs font-bold text-slate-700 block mb-1">Open Form Date/Time</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.openFormTime}
                                            onChange={e => setSettings(s => ({ ...s, openFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-teal-400"
                                        />
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 block mb-1">Close Form Date/Time</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.closeFormTime}
                                            onChange={e => setSettings(s => ({ ...s, closeFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-teal-400"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-700 block mb-1">Form Password Token (Optional)</label>
                                    <input
                                        type="text"
                                        value={settings.formToken}
                                        onChange={e => setSettings(s => ({ ...s, formToken: e.target.value }))}
                                        placeholder="Secret token required to take form..."
                                        className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-400"
                                    />
                                </div>

                                <div className="space-y-3 pt-3 border-t border-slate-100">
                                    {[
                                        { key: 'requiredLogin', label: 'Require login to fill out form' },
                                        { key: 'showScore', label: 'Show score / grade to respondent after submission' },
                                        { key: 'randomizeQuestions', label: 'Randomize question order for each respondent' },
                                        { key: 'oneResponse', label: 'Limit to 1 response per respondent' },
                                    ].map(({ key, label }) => (
                                        <label key={key} className="flex items-center justify-between cursor-pointer py-1">
                                            <span className="text-xs font-bold text-slate-700">{label}</span>
                                            <input
                                                type="checkbox"
                                                checked={settings[key]}
                                                onChange={e => setSettings(s => ({ ...s, [key]: e.target.checked }))}
                                                className="w-4 h-4 text-teal-600 rounded"
                                            />
                                        </label>
                                    ))}
                                </div>
                            </div>

                            <button
                                onClick={handleSaveSettings}
                                disabled={saving}
                                className="px-5 py-2.5 bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold rounded-xl shadow-sm transition-all disabled:opacity-60"
                            >
                                {saving ? 'Saving Settings...' : 'Save Settings'}
                            </button>
                        </div>
                    )}

                    {/* ── SHARE TAB ── */}
                    {activeTab === 'share' && (
                        <div className="bg-white rounded-2xl border border-slate-200 p-6 space-y-4 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-800">Share Form</h2>
                            {!isPublished && (
                                <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-800 font-semibold">
                                    ⚠ Form is currently Draft. Publish it to allow respondents to submit answers.
                                </div>
                            )}
                            {shareInfo ? (
                                <div className="space-y-4">
                                    <div>
                                        <label className="text-xs font-bold text-slate-600 mb-1 block">Share Public Link</label>
                                        <div className="flex gap-2">
                                            <input
                                                readOnly
                                                value={`${window.location.origin}/f/${shareInfo.formLink}`}
                                                className="flex-1 border border-slate-200 rounded-xl px-3.5 py-2 text-xs font-mono bg-slate-50"
                                            />
                                            <button
                                                onClick={() => { navigator.clipboard.writeText(`${window.location.origin}/f/${shareInfo.formLink}`); showToast('Link copied!'); }}
                                                className="px-4 py-2 bg-teal-600 text-white text-xs font-bold rounded-xl hover:bg-teal-700 shadow-xs"
                                            >
                                                Copy
                                            </button>
                                        </div>
                                    </div>
                                    {qrBlobUrl && (
                                        <div>
                                            <label className="text-xs font-bold text-slate-600 mb-1 block">QR Code</label>
                                            <a href={qrBlobUrl} download={`qr-${shareInfo.formLink}.png`}>
                                                <img src={qrBlobUrl} alt="QR Code" className="w-36 h-36 border border-slate-200 rounded-xl hover:opacity-90 shadow-xs" />
                                            </a>
                                            <p className="text-[11px] text-slate-400 mt-1 font-medium">Click image to download QR PNG.</p>
                                        </div>
                                    )}
                                </div>
                            ) : (
                                <button
                                    onClick={handleLoadShare}
                                    className="px-4 py-2 bg-teal-600 text-white text-xs font-bold rounded-xl hover:bg-teal-700"
                                >
                                    Generate Share Details
                                </button>
                            )}
                        </div>
                    )}

                </div>
            </div>

            {/* Modal for safe KaTeX Math & Code Insertion */}
            <MathAndCodeModal
                isOpen={modalOpen}
                mode={modalMode}
                onClose={() => setModalOpen(false)}
                onInsert={handleInsertFromModal}
            />
        </div>
    );
}
