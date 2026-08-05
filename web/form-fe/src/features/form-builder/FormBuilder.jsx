import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Save, Plus, Trash2, ChevronUp, ChevronDown,
    Globe, Lock, ArrowLeft, Upload, FileUp, Image, Music, Download
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById, getQuestions, saveQuestions, updateForm,
    togglePublishForm, updateFormSettings, getFormShare,
    uploadFormBanner, clearSession, assetUrl,
    deleteQuestion, importQuestions, uploadQuestionImage, uploadQuestionAudio,
    templateDownloadUrl
} from '../../services/apiService';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

const QUESTION_TYPES = [
    { id: 1, label: 'Multiple Choice' },
    { id: 2, label: 'Checkboxes' },
    { id: 3, label: 'Short Answer' },
    { id: 4, label: 'Paragraph' },
    { id: 5, label: 'Dropdown' },
    { id: 6, label: 'Date' },
    { id: 7, label: 'Time' },
    { id: 8, label: 'Rating' },
];

const newQuestion = (order) => ({
    _id: `q_new_${Date.now()}_${order}`,
    id: null,
    question: '',
    typeId: 1,
    questionOrder: order,
    isRequired: false,
    correctAnswer: '',
    options: [{ optionText: '', isCorrect: false }],
    questionImage: null,
    questionAudio: null,
});

const needsOptions = (typeId) => [1, 2, 5].includes(typeId);

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

    const [settings, setSettings] = useState({
        showScore: false,
        randomizeQuestions: false,
        oneResponse: false,
        timerDuration: '',
    });

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, qRes] = await Promise.all([getFormById(id), getQuestions(id)]);
            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }
            if (formRes.ok && formRes.data) {
                setForm(formRes.data);
                const s = formRes.data.settings;
                if (s) setSettings({
                    showScore: s.showScore ?? false,
                    randomizeQuestions: s.randomizeQuestions ?? false,
                    oneResponse: s.oneResponse ?? false,
                    timerDuration: s.timerDuration ?? '',
                });
            }
            if (qRes.ok && Array.isArray(qRes.data) && qRes.data.length > 0) {
                setQuestions(qRes.data.map((q, i) => ({
                    _id: `q_${q.id}`,
                    id: q.id,
                    question: q.question,
                    typeId: q.typeId,
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
            showToast('Questions saved!');
            // Reload to get real IDs
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                setQuestions(qRes.data.map((q, i) => ({
                    _id: `q_${q.id}`,
                    id: q.id,
                    question: q.question,
                    typeId: q.typeId,
                    questionOrder: q.questionOrder ?? i + 1,
                    isRequired: q.isRequired ?? false,
                    correctAnswer: q.correctAnswer ?? '',
                    questionImage: q.questionImage ?? null,
                    questionAudio: q.questionAudio ?? null,
                    options: q.options?.length > 0 ? q.options : [{ optionText: '', isCorrect: false }],
                })));
            }
        } else {
            showToast(res.message || 'Failed to save', 'error');
        }
    };

    const handleSaveSettings = async () => {
        setSaving(true);
        const res = await updateFormSettings(id, {
            showScore: settings.showScore,
            randomizeQuestions: settings.randomizeQuestions,
            oneResponse: settings.oneResponse,
            timerDuration: settings.timerDuration ? parseInt(settings.timerDuration) : 0,
        });
        setSaving(false);
        showToast(res.ok ? 'Settings saved!' : (res.message || 'Failed'), res.ok ? 'success' : 'error');
    };

    const handleTogglePublish = async () => {
        setPublishing(true);
        const res = await togglePublishForm(id);
        if (res.ok) {
            const updated = await getFormById(id);
            if (updated.ok) setForm(updated.data);
            showToast(res.message || 'Done!');
        } else {
            showToast(res.message || 'Failed', 'error');
        }
        setPublishing(false);
    };

    const handleLoadShare = useCallback(async () => {
        const res = await getFormShare(id);
        if (res.ok) {
            setShareInfo(res.data);
            const token = localStorage.getItem('token');
            const qrRes = await fetch(
                `${API_BASE_URL}/api/Forms/${id}/share/qr?frontendUrl=${encodeURIComponent(window.location.origin)}`,
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
                    question: q.question,
                    typeId: q.typeId,
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
            if (!res.ok) { showToast(res.message || 'Failed to delete', 'error'); return; }
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

    const updateQuestion = (idx, field, value) =>
        setQuestions(prev => prev.map((q, i) => i === idx ? { ...q, [field]: value } : q));

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
            <p className="text-slate-400 text-sm">Loading form...</p>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                {/* Top bar */}
                <div className="sticky top-0 z-10 bg-white border-b border-slate-200 px-6 py-3 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/my-forms')} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <h1 className="text-sm font-bold text-slate-800 truncate">{form?.title || 'Untitled Form'}</h1>
                            <p className="text-[11px] text-slate-400">Form Builder</p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                        <span className={`text-[11px] font-bold px-2.5 py-1 rounded-full ${isPublished ? 'bg-teal-50 text-teal-600' : 'bg-slate-100 text-slate-500'}`}>
                            {isPublished ? 'Published' : 'Draft'}
                        </span>
                        <button
                            onClick={handleTogglePublish}
                            disabled={publishing}
                            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition-all disabled:opacity-60 ${isPublished ? 'bg-amber-50 text-amber-600 hover:bg-amber-100' : 'bg-teal-600 text-white hover:bg-teal-700'}`}
                        >
                            {isPublished ? <><Lock size={13} /> Unpublish</> : <><Globe size={13} /> Publish</>}
                        </button>
                        {activeTab === 'questions' && (
                            <button
                                onClick={handleSaveQuestions}
                                disabled={saving}
                                className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-800 hover:bg-slate-900 text-white rounded-lg text-xs font-bold disabled:opacity-60"
                            >
                                <Save size={13} /> {saving ? 'Saving...' : 'Save'}
                            </button>
                        )}
                    </div>
                </div>

                {/* Toast */}
                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-sm font-semibold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-teal-600'}`}>
                        {toast.msg}
                    </div>
                )}

                {/* Tabs */}
                <div className="flex border-b border-slate-200 bg-white px-6">
                    {[
                        { key: 'questions', label: '📝 Questions' },
                        { key: 'settings', label: '⚙️ Settings' },
                        { key: 'share', label: '🔗 Share' },
                    ].map(tab => (
                        <button
                            key={tab.key}
                            onClick={() => { setActiveTab(tab.key); if (tab.key === 'share' && !shareInfo) handleLoadShare(); }}
                            className={`py-3 px-4 text-sm font-bold border-b-2 transition-all ${activeTab === tab.key ? 'border-teal-500 text-teal-600' : 'border-transparent text-slate-400 hover:text-slate-600'}`}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>

                <div className="p-6 max-w-3xl mx-auto w-full space-y-4">

                    {/* ── QUESTIONS TAB ── */}
                    {activeTab === 'questions' && (
                        <>
                            {/* Form info */}
                            <div className="bg-white rounded-xl border border-slate-200 p-4 space-y-3">
                                <h2 className="text-xs font-bold text-slate-500 uppercase tracking-wide">Form Info</h2>
                                <div>
                                    <label className="text-xs font-semibold text-slate-500 mb-1 block">Title</label>
                                    <input
                                        value={form?.title ?? ''}
                                        onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
                                        onBlur={() => form?.title && updateForm(id, { title: form.title, description: form.description })}
                                        className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                    />
                                </div>
                                <div>
                                    <label className="text-xs font-semibold text-slate-500 mb-1 block">Description</label>
                                    <textarea
                                        value={form?.description ?? ''}
                                        onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
                                        onBlur={() => updateForm(id, { title: form.title, description: form.description })}
                                        rows={2}
                                        className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 resize-none"
                                    />
                                </div>
                                <div>
                                    <label className="text-xs font-semibold text-slate-500 mb-1 block">Banner Image</label>
                                    {form?.bannerImage && (
                                        <img src={assetUrl(form.bannerImage)} alt="banner" className="w-full h-24 object-cover rounded-lg mb-2" />
                                    )}
                                    <label className="flex items-center gap-2 cursor-pointer px-3 py-2 border border-dashed border-slate-300 rounded-lg text-xs text-slate-500 hover:border-teal-400 hover:text-teal-600 transition-all w-fit">
                                        <Upload size={14} /> Upload Banner
                                        <input type="file" accept="image/*" className="hidden" onChange={handleBannerUpload} />
                                    </label>
                                </div>
                            </div>

                            {/* Import toolbar */}
                            <div className="bg-white rounded-xl border border-slate-200 p-4 flex flex-wrap items-center gap-3">
                                <span className="text-xs font-bold text-slate-500">Import Questions:</span>
                                <label className={`flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 rounded-lg text-xs font-bold cursor-pointer hover:border-teal-400 hover:text-teal-600 transition-all ${importLoading ? 'opacity-50 pointer-events-none' : ''}`}>
                                    <FileUp size={13} /> {importLoading ? 'Importing...' : 'Upload File'}
                                    <input type="file" accept=".csv,.xlsx,.xls,.pdf,.docx" className="hidden" onChange={handleImportFile} />
                                </label>
                                <span className="text-slate-300 text-xs">|</span>
                                <span className="text-xs text-slate-500">Download template:</span>
                                {['csv', 'xlsx', 'docx', 'pdf'].map(fmt => (
                                    <a
                                        key={fmt}
                                        href={templateDownloadUrl(fmt)}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="flex items-center gap-1 px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-600 text-[11px] font-bold rounded-lg transition-all"
                                    >
                                        <Download size={11} /> {fmt.toUpperCase()}
                                    </a>
                                ))}
                            </div>

                            {/* Question cards */}
                            {questions.map((q, idx) => (
                                <div key={q._id} className="bg-white rounded-xl border border-slate-200 p-4 space-y-3">
                                    <div className="flex items-center gap-2">
                                        <span className="text-xs font-bold text-slate-400">Q{idx + 1}</span>
                                        {q.id && <span className="text-[10px] text-slate-300">#{q.id}</span>}
                                        <div className="flex items-center gap-1 ml-auto">
                                            <button onClick={() => moveQuestion(idx, -1)} className="p-1 text-slate-300 hover:text-slate-600 rounded"><ChevronUp size={15} /></button>
                                            <button onClick={() => moveQuestion(idx, 1)} className="p-1 text-slate-300 hover:text-slate-600 rounded"><ChevronDown size={15} /></button>
                                            <button onClick={() => handleDeleteQuestion(idx)} className="p-1 text-red-300 hover:text-red-500 rounded"><Trash2 size={15} /></button>
                                        </div>
                                    </div>

                                    <input
                                        placeholder="Question text..."
                                        value={q.question}
                                        onChange={e => updateQuestion(idx, 'question', e.target.value)}
                                        className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                    />

                                    <div className="flex items-center gap-3 flex-wrap">
                                        <select
                                            value={q.typeId}
                                            onChange={e => updateQuestion(idx, 'typeId', parseInt(e.target.value))}
                                            className="border border-slate-200 rounded-lg px-2 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                                        >
                                            {QUESTION_TYPES.map(t => <option key={t.id} value={t.id}>{t.label}</option>)}
                                        </select>
                                        <label className="flex items-center gap-1.5 text-xs text-slate-600 cursor-pointer">
                                            <input
                                                type="checkbox"
                                                checked={q.isRequired}
                                                onChange={e => updateQuestion(idx, 'isRequired', e.target.checked)}
                                                className="rounded"
                                            />
                                            Required
                                        </label>
                                    </div>

                                    {/* Options for choice types */}
                                    {needsOptions(q.typeId) && (
                                        <div className="space-y-1.5 pl-2 border-l-2 border-slate-100">
                                            {q.options.map((opt, oIdx) => (
                                                <div key={oIdx} className="flex items-center gap-2">
                                                    <input
                                                        type="checkbox"
                                                        checked={opt.isCorrect}
                                                        onChange={e => updateOption(idx, oIdx, 'isCorrect', e.target.checked)}
                                                        className="rounded shrink-0"
                                                        title="Mark as correct answer"
                                                    />
                                                    <input
                                                        placeholder={`Option ${oIdx + 1}`}
                                                        value={opt.optionText}
                                                        onChange={e => updateOption(idx, oIdx, 'optionText', e.target.value)}
                                                        className="flex-1 border border-slate-200 rounded-lg px-2 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                                                    />
                                                    <button onClick={() => removeOption(idx, oIdx)} className="text-red-300 hover:text-red-500 shrink-0">
                                                        <Trash2 size={13} />
                                                    </button>
                                                </div>
                                            ))}
                                            <button onClick={() => addOption(idx)} className="text-xs text-teal-600 hover:underline mt-1">+ Add option</button>
                                        </div>
                                    )}

                                    {/* Correct answer for text types */}
                                    {[3, 4].includes(q.typeId) && (
                                        <div>
                                            <label className="text-[11px] text-slate-400 block mb-1">Correct answer (optional)</label>
                                            <input
                                                placeholder="Correct answer..."
                                                value={q.correctAnswer}
                                                onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                className="w-full border border-slate-200 rounded-lg px-2 py-1.5 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                                            />
                                        </div>
                                    )}

                                    {/* Media uploads (only if question already saved) */}
                                    {q.id && (
                                        <div className="flex flex-wrap gap-2 pt-1 border-t border-slate-100">
                                            {q.questionImage ? (
                                                <div className="flex items-center gap-2">
                                                    <img src={assetUrl(q.questionImage)} alt="question" className="h-12 w-20 object-cover rounded-lg border border-slate-200" />
                                                    <label className="text-[11px] text-teal-600 cursor-pointer hover:underline">
                                                        Change image
                                                        <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                    </label>
                                                </div>
                                            ) : (
                                                <label className="flex items-center gap-1.5 px-2.5 py-1.5 border border-dashed border-slate-200 rounded-lg text-[11px] text-slate-500 cursor-pointer hover:border-teal-400 hover:text-teal-600 transition-all">
                                                    <Image size={12} /> Add image
                                                    <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                </label>
                                            )}
                                            {q.questionAudio ? (
                                                <div className="flex items-center gap-2">
                                                    <audio controls src={assetUrl(q.questionAudio)} className="h-8 text-xs" />
                                                    <label className="text-[11px] text-teal-600 cursor-pointer hover:underline">
                                                        Change audio
                                                        <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                    </label>
                                                </div>
                                            ) : (
                                                <label className="flex items-center gap-1.5 px-2.5 py-1.5 border border-dashed border-slate-200 rounded-lg text-[11px] text-slate-500 cursor-pointer hover:border-teal-400 hover:text-teal-600 transition-all">
                                                    <Music size={12} /> Add audio
                                                    <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                </label>
                                            )}
                                        </div>
                                    )}
                                    {!q.id && (
                                        <p className="text-[10px] text-slate-400 italic">Save first to upload image/audio</p>
                                    )}
                                </div>
                            ))}

                            <button
                                onClick={addQuestion}
                                className="w-full py-3 border-2 border-dashed border-slate-200 rounded-xl text-sm font-semibold text-slate-400 hover:border-teal-400 hover:text-teal-600 transition-all flex items-center justify-center gap-2"
                            >
                                <Plus size={16} /> Add Question
                            </button>
                        </>
                    )}

                    {/* ── SETTINGS TAB ── */}
                    {activeTab === 'settings' && (
                        <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-5">
                            <h2 className="text-sm font-bold text-slate-700">Form Settings</h2>
                            {[
                                { key: 'showScore', label: 'Show score after submission' },
                                { key: 'randomizeQuestions', label: 'Randomize question order' },
                                { key: 'oneResponse', label: 'Limit to one response per user' },
                            ].map(({ key, label }) => (
                                <label key={key} className="flex items-center justify-between cursor-pointer">
                                    <span className="text-sm text-slate-700">{label}</span>
                                    <input
                                        type="checkbox"
                                        checked={settings[key]}
                                        onChange={e => setSettings(s => ({ ...s, [key]: e.target.checked }))}
                                        className="w-4 h-4 rounded"
                                    />
                                </label>
                            ))}
                            <div>
                                <label className="text-sm text-slate-700 block mb-1">Timer (minutes, 0 = disabled)</label>
                                <input
                                    type="number"
                                    min="0"
                                    value={settings.timerDuration}
                                    onChange={e => setSettings(s => ({ ...s, timerDuration: e.target.value }))}
                                    className="border border-slate-200 rounded-lg px-3 py-2 text-sm w-32 focus:outline-none focus:ring-2 focus:ring-teal-400"
                                    placeholder="0"
                                />
                            </div>
                            <button
                                onClick={handleSaveSettings}
                                disabled={saving}
                                className="px-4 py-2 bg-slate-800 hover:bg-slate-900 text-white text-sm font-bold rounded-lg disabled:opacity-60"
                            >
                                {saving ? 'Saving...' : 'Save Settings'}
                            </button>
                        </div>
                    )}

                    {/* ── SHARE TAB ── */}
                    {activeTab === 'share' && (
                        <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-4">
                            <h2 className="text-sm font-bold text-slate-700">Share Form</h2>
                            {!isPublished && (
                                <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-700 font-medium">
                                    Form is not published yet. Publish it first to share.
                                </div>
                            )}
                            {shareInfo ? (
                                <div className="space-y-3">
                                    <div>
                                        <label className="text-xs font-semibold text-slate-500 mb-1 block">Share URL</label>
                                        <div className="flex gap-2">
                                            <input
                                                readOnly
                                                value={`${window.location.origin}/f/${shareInfo.formLink}`}
                                                className="flex-1 border border-slate-200 rounded-lg px-3 py-2 text-xs bg-slate-50"
                                            />
                                            <button
                                                onClick={() => { navigator.clipboard.writeText(`${window.location.origin}/f/${shareInfo.formLink}`); showToast('Copied!'); }}
                                                className="px-3 py-2 bg-teal-600 text-white text-xs font-bold rounded-lg hover:bg-teal-700"
                                            >
                                                Copy
                                            </button>
                                        </div>
                                    </div>
                                    {qrBlobUrl && (
                                        <div>
                                            <label className="text-xs font-semibold text-slate-500 mb-1 block">QR Code</label>
                                            <a href={qrBlobUrl} download={`qr-form-${id}.png`}>
                                                <img src={qrBlobUrl} alt="QR Code" className="w-32 h-32 border border-slate-200 rounded-lg hover:opacity-80" />
                                            </a>
                                            <p className="text-[10px] text-slate-400 mt-1">Click to download</p>
                                        </div>
                                    )}
                                    <div>
                                        <label className="text-xs font-semibold text-slate-500">Form Link Key</label>
                                        <p className="text-xs text-slate-600 font-mono mt-1">{shareInfo.formLink}</p>
                                    </div>
                                    {shareInfo.requiresToken && (
                                        <p className="text-xs text-amber-600 font-medium">⚠ This form requires a token to access.</p>
                                    )}
                                </div>
                            ) : (
                                <button
                                    onClick={handleLoadShare}
                                    className="px-4 py-2 bg-teal-600 text-white text-sm font-bold rounded-lg hover:bg-teal-700"
                                >
                                    Load Share Info
                                </button>
                            )}
                        </div>
                    )}

                </div>
            </div>
        </div>
    );
}
