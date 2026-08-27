import { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { 
    ArrowLeft, Download, Eye, X, BarChart2, Loader2, 
    MessageSquare, AlertTriangle, CheckCircle2, XCircle, 
    MinusCircle, ChevronLeft, ChevronRight, TrendingUp, Calendar, Maximize2,
    Sliders, Edit2, RotateCcw, Check, Save
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById, getFormResponses, getFormAnalytics,
    getResponseResult,
    updateResponseStatus, clearSession, exportFormResponses, getMyFeedback, assetUrl
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';
import ImageLightboxModal from '../../components/ui/ImageLightboxModal';

const STATUS_OPTIONS = [
    { id: 1, label: 'Baru', code: 'new' },
    { id: 2, label: 'Ditinjau', code: 'reviewed' },
    { id: 3, label: 'Diterima', code: 'accepted' },
    { id: 4, label: 'Ditolak', code: 'rejected' },
];

const PAGE_SIZE = 25;

export default function FormResponsesPage() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [activeTab, setActiveTab] = useState('responses');

    const [form, setForm] = useState(null);
    const [responses, setResponses] = useState([]);
    const [analytics, setAnalytics] = useState(null);
    const [loading, setLoading] = useState(true);
    const [statusUpdating, setStatusUpdating] = useState(null);
    const [toast, setToast] = useState(null);
    const [exporting, setExporting] = useState(false);
    const [lightboxImage, setLightboxImage] = useState(null);

    // Feedback
    const [feedbacks, setFeedbacks] = useState([]);
    const [feedbackLoading, setFeedbackLoading] = useState(false);

    // Review Answers Modal
    const [selectedRespondent, setSelectedRespondent] = useState(null);

    // Score Overrides (Local/Persistent per Form ID)
    const [scoreOverrides, setScoreOverrides] = useState(() => {
        try {
            const saved = localStorage.getItem(`formup_scores_${id}`);
            return saved ? JSON.parse(saved) : {};
        } catch {
            return {};
        }
    });

    const [editingScoreId, setEditingScoreId] = useState(null);
    const [inlineScoreInput, setInlineScoreInput] = useState('');
    const [bulkModalOpen, setBulkModalOpen] = useState(false);
    const [bulkType, setBulkType] = useState('min'); // 'min' | 'bonus' | 'scale' | 'set_fixed'
    const [bulkValue, setBulkValue] = useState(75);
    const [bulkFilter, setBulkFilter] = useState('all'); // 'all' | 'below' | 'range'
    const [filterThreshold, setFilterThreshold] = useState(75);
    const [filterRangeMin, setFilterRangeMin] = useState(0);
    const [filterRangeMax, setFilterRangeMax] = useState(70);

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            try {
                const [formRes, respRes, analyticsRes] = await Promise.all([
                    getFormById(id),
                    getFormResponses(id, { page: 1, pageSize: PAGE_SIZE }),
                    getFormAnalytics(id, 1, 100)
                ]);

                if (formRes.status === 401) { 
                    clearSession(); 
                    navigate('/login'); 
                    return; 
                }

                if (formRes.ok) setForm(formRes.data);

                if (respRes.ok) {
                    const list = Array.isArray(respRes.data)
                        ? respRes.data
                        : respRes.data?.responses || respRes.data?.items || [];
                    setResponses(list);
                }

                if (analyticsRes.ok && analyticsRes.data) {
                    setAnalytics(analyticsRes.data);
                }
            } catch (err) {
                console.error('Error loading responses:', err);
            } finally {
                setLoading(false);
            }
        };

        load();
    }, [id, navigate]);

    // Load feedback tab
    useEffect(() => {
        if (activeTab !== 'feedback') return;
        const loadFeedback = async () => {
            setFeedbackLoading(true);
            const res = await getMyFeedback(id);
            setFeedbackLoading(false);
            if (res.ok) {
                const data = res.data;
                if (Array.isArray(data)) setFeedbacks(data);
                else if (data && typeof data === 'object') setFeedbacks([data]);
                else setFeedbacks([]);
            }
        };
        loadFeedback();
    }, [activeTab, id]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    const handleExport = (formId) => {
        if (!formId || exporting) return;
        setExporting(true);
        try {
            if (!respondentsList || respondentsList.length === 0) {
                showToast('Belum ada data respons untuk diekspor.', 'error');
                setExporting(false);
                return;
            }

            // Extract unique question titles
            const questionMap = new Map();
            respondentsList.forEach(r => {
                (r.answers || []).forEach(a => {
                    if (a.questionId && !questionMap.has(a.questionId)) {
                        questionMap.set(a.questionId, a.question || `Soal #${a.questionId}`);
                    }
                });
            });

            const escapeCsv = (val) => {
                if (val === null || val === undefined) return '""';
                const str = String(val).replace(/<[^>]*>/g, '').trim();
                return `"${str.replace(/"/g, '""')}"`;
            };

            const headerRow = [
                'ID Respons',
                'Nama Responden',
                'Waktu Submit',
                'Status',
                'Soal Dijawab',
                'Benar',
                'Salah',
                'Skor Akhir (%)',
                ...Array.from(questionMap.values())
            ];

            const rows = respondentsList.map(r => {
                const answerByQ = new Map((r.answers || []).map(a => [a.questionId, a.answerText || a.answerValue || a.optionText || '']));
                const scorable = r.scorableQuestions ?? 0;
                const correct = r.correctCount ?? 0;
                const wrong = r.wrongCount != null ? r.wrongCount : Math.max(scorable - correct, 0);

                return [
                    r.responseId,
                    r.respondentName || 'Anonim',
                    formatDate(r.submittedAt),
                    r.status || 'new',
                    `${r.answeredCount ?? 0}/${r.totalQuestions ?? 0}`,
                    correct,
                    wrong,
                    r.score != null ? `${r.score}%` : 'N/A',
                    ...Array.from(questionMap.keys()).map(qId => answerByQ.get(qId) || '')
                ].map(escapeCsv).join(',');
            });

            const csvContent = '\uFEFF' + [headerRow.map(escapeCsv).join(','), ...rows].join('\r\n');
            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.setAttribute('download', `respons-formulir-${form?.title ? form.title.replace(/\s+/g, '_') : formId}.csv`);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);

            showToast('File CSV (lengkap dengan pembaruan nilai) berhasil diunduh!');
        } catch (err) {
            console.error(err);
            showToast('Terjadi kesalahan saat mengekspor CSV.', 'error');
        } finally {
            setExporting(false);
        }
    };

    const handleStatusChange = async (responseId, statusId) => {
        setStatusUpdating(responseId);
        const res = await updateResponseStatus(responseId, statusId);
        if (res.ok) {
            const statusLabel = STATUS_OPTIONS.find(s => s.id === statusId)?.code ?? 'new';
            setResponses(prev => prev.map(r =>
                r.id === responseId
                    ? { ...r, status: statusLabel }
                    : r
            ));
            showToast('Status respons berhasil diperbarui');
        } else {
            showToast(res.message || 'Gagal memperbarui status', 'error');
        }
        setStatusUpdating(null);
    };

    const formatDate = (d) => d
        ? new Date(d).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
        : '—';

    const statusStyle = (status) => {
        switch (status?.toLowerCase()) {
            case 'new': 
            case 'baru': return 'bg-blue-50 text-blue-600 dark:bg-blue-950/60 dark:text-blue-400';
            case 'reviewed': 
            case 'ditinjau': return 'bg-yellow-50 text-yellow-600 dark:bg-yellow-950/60 dark:text-yellow-400';
            case 'accepted': 
            case 'diterima': return 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400';
            case 'rejected': 
            case 'ditolak': return 'bg-red-50 text-red-600 dark:bg-red-950/60 dark:text-red-400';
            default: return 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400';
        }
    };

    const persistOverrides = (newOverrides) => {
        setScoreOverrides(newOverrides);
        try {
            localStorage.setItem(`formup_scores_${id}`, JSON.stringify(newOverrides));
        } catch (e) {
            console.error('Error saving score overrides:', e);
        }
    };

    const handleSaveIndividualScore = (responseId, newScore) => {
        const parsed = Math.max(0, Math.min(100, parseFloat(newScore) || 0));
        const updated = {
            ...scoreOverrides,
            [responseId]: {
                ...(scoreOverrides[responseId] || {}),
                score: parsed,
                isCustom: true
            }
        };
        persistOverrides(updated);
        setEditingScoreId(null);
        showToast(`Skor responden #${responseId} diperbarui menjadi ${parsed}%`);
    };

    const handleToggleQuestionCorrect = (responseId, questionId, currentIsCorrect) => {
        const nextIsCorrect = currentIsCorrect === true ? false : true;
        const respOverride = scoreOverrides[responseId] || {};
        const qOverrides = { ...(respOverride.questionOverrides || {}) };
        qOverrides[questionId] = nextIsCorrect;

        const respondent = respondentsList.find(r => r.responseId === responseId);
        const answers = respondent?.answers || [];
        const scorableCount = respondent?.scorableQuestions || answers.length || 1;
        let newCorrectCount = 0;
        answers.forEach(a => {
            const isCorr = qOverrides[a.questionId] !== undefined ? qOverrides[a.questionId] : a.isCorrect;
            if (isCorr === true) newCorrectCount++;
        });

        const newCalculatedScore = Math.min(100, Math.round((newCorrectCount / scorableCount) * 100 * 10) / 10);

        const updated = {
            ...scoreOverrides,
            [responseId]: {
                ...respOverride,
                score: newCalculatedScore,
                correctCount: newCorrectCount,
                questionOverrides: qOverrides,
                isCustom: true
            }
        };
        persistOverrides(updated);
        
        if (selectedRespondent && selectedRespondent.responseId === responseId) {
            setSelectedRespondent(prev => ({
                ...prev,
                score: newCalculatedScore,
                correctCount: newCorrectCount,
                answers: prev.answers.map(a => a.questionId === questionId ? { ...a, isCorrect: nextIsCorrect } : a)
            }));
        }

        showToast(`Status soal #${questionId} diubah menjadi ${nextIsCorrect ? 'Benar' : 'Salah'}`);
    };

    // Preview adjustments before applying
    const previewAdjustments = useMemo(() => {
        return respondentsList.map(r => {
            const current = r.score != null ? r.score : 0;
            let meetsFilter = true;
            if (bulkFilter === 'below') {
                meetsFilter = current < filterThreshold;
            } else if (bulkFilter === 'range') {
                meetsFilter = current >= filterRangeMin && current <= filterRangeMax;
            }

            let projected = current;
            if (meetsFilter) {
                if (bulkType === 'min') {
                    projected = Math.max(current, bulkValue);
                } else if (bulkType === 'bonus') {
                    projected = Math.min(100, Math.max(0, current + bulkValue));
                } else if (bulkType === 'scale') {
                    projected = Math.min(100, Math.max(0, Math.round(current * (bulkValue / 100) * 10) / 10));
                } else if (bulkType === 'set_fixed') {
                    projected = Math.min(100, Math.max(0, bulkValue));
                }
            }

            return {
                ...r,
                currentScore: current,
                projectedScore: Math.round(projected * 10) / 10,
                diff: Math.round((projected - current) * 10) / 10,
                meetsFilter
            };
        });
    }, [respondentsList, bulkType, bulkFilter, filterThreshold, filterRangeMin, filterRangeMax, bulkValue]);

    const handleApplyBulkScore = () => {
        const updated = { ...scoreOverrides };

        previewAdjustments.forEach(item => {
            if (item.meetsFilter) {
                updated[item.responseId] = {
                    ...(updated[item.responseId] || {}),
                    score: item.projectedScore,
                    isCustom: true
                };
            }
        });

        persistOverrides(updated);
        setBulkModalOpen(false);
        showToast('Penyesuaian skor massal berhasil diterapkan!');
    };

    const handleResetAllScores = () => {
        persistOverrides({});
        setBulkModalOpen(false);
        showToast('Semua skor telah dikembalikan ke perhitungan sistem.');
    };

    // Merge respondent data from analytics with response list and apply score overrides
    const respondentsList = useMemo(() => {
        const rawList = analytics?.respondents && analytics.respondents.length > 0
            ? analytics.respondents
            : responses.map(r => ({
                responseId: r.id,
                respondentName: r.respondentName,
                submittedAt: r.submittedAt,
                status: r.status,
                answeredCount: 0,
                totalQuestions: 0,
                correctCount: 0,
                wrongCount: 0,
                score: null,
                answers: []
            }));

        return rawList.map(r => {
            const override = scoreOverrides[r.responseId];
            if (!override) return { ...r, baseScore: r.score };

            const effectiveScore = override.score !== undefined ? override.score : r.score;
            const effectiveCorrect = override.correctCount !== undefined ? override.correctCount : r.correctCount;
            const qOverrides = override.questionOverrides || {};

            const effectiveAnswers = (r.answers || []).map(a => ({
                ...a,
                isCorrect: qOverrides[a.questionId] !== undefined ? qOverrides[a.questionId] : a.isCorrect
            }));

            return {
                ...r,
                baseScore: r.score,
                score: effectiveScore,
                correctCount: effectiveCorrect,
                answers: effectiveAnswers,
                isCustomScore: !!override.isCustom
            };
        });
    }, [analytics, responses, scoreOverrides]);

    // Trend calculations
    const trendData = useMemo(() => {
        if (!respondentsList || respondentsList.length === 0) return [];
        const dateMap = {};
        respondentsList.forEach(r => {
            if (!r.submittedAt) return;
            const d = new Date(r.submittedAt).toLocaleDateString('id-ID', {
                day: '2-digit',
                month: 'short'
            });
            dateMap[d] = (dateMap[d] || 0) + 1;
        });
        return Object.entries(dateMap).map(([date, count]) => ({ date, count }));
    }, [respondentsList]);

    const maxCount = useMemo(() => {
        if (trendData.length === 0) return 1;
        return Math.max(...trendData.map(d => d.count), 1);
    }, [trendData]);

    const currentIndex = selectedRespondent
        ? respondentsList.findIndex(r => r.responseId === selectedRespondent.responseId)
        : -1;

    const goPrevious = () => {
        if (currentIndex > 0) {
            setSelectedRespondent(respondentsList[currentIndex - 1]);
        }
    };

    const goNext = () => {
        if (currentIndex < respondentsList.length - 1) {
            setSelectedRespondent(respondentsList[currentIndex + 1]);
        }
    };

    const getAnswerStatus = (answer) => {
        if (answer.isCorrect === true) {
            return {
                label: 'Benar',
                icon: <CheckCircle2 size={16} />,
                className: 'text-emerald-600 bg-emerald-50 dark:bg-emerald-950/60 dark:text-emerald-400 border-emerald-200 dark:border-emerald-800'
            };
        }
        if (answer.isCorrect === false) {
            return {
                label: 'Salah',
                icon: <XCircle size={16} />,
                className: 'text-red-600 bg-red-50 dark:bg-red-950/60 dark:text-red-400 border-red-200 dark:border-red-800'
            };
        }
        return {
            label: 'Tidak Dinilai',
            icon: <MinusCircle size={16} />,
            className: 'text-slate-500 bg-slate-50 dark:bg-slate-800 dark:text-slate-400 border-slate-200 dark:border-slate-700'
        };
    };

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <div className="text-center space-y-2">
                <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400" />
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat respons...</p>
            </div>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                {/* Header */}
                <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-6 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3 min-w-0">
                        <button 
                            onClick={() => navigate('/my-forms')} 
                            className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
                        >
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <h1 className="text-base font-extrabold text-slate-900 dark:text-white truncate">
                                {form?.title || 'Formulir'}
                            </h1>
                            <p className="text-xs text-slate-400 dark:text-slate-500">
                                {respondentsList.length} total respons masuk
                            </p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                        <button
                            onClick={() => navigate(`/forms/${id}/analytics`)}
                            className="flex items-center gap-1.5 px-3.5 py-2 bg-teal-50 hover:bg-teal-100 dark:bg-teal-950/60 dark:hover:bg-teal-900 text-[#00897B] dark:text-teal-400 text-xs font-bold rounded-xl transition-all cursor-pointer"
                        >
                            <BarChart2 size={14} /> Analisis
                        </button>
                        <button
                            type="button"
                            onClick={() => handleExport(id)}
                            disabled={exporting}
                            className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-900 hover:bg-slate-800 dark:bg-slate-800 dark:hover:bg-slate-700 text-white text-xs font-bold rounded-xl transition-all shadow-xs disabled:opacity-60 cursor-pointer"
                        >
                            {exporting ? <Loader2 size={14} className="animate-spin" /> : <Download size={14} />}
                            <span>{exporting ? 'Mengekspor...' : 'Unduh CSV'}</span>
                        </button>
                    </div>
                </div>

                {/* Sub-tabs: Respons / Feedback */}
                <div className="flex border-b border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 px-6">
                    <button
                        onClick={() => setActiveTab('responses')}
                        className={`flex items-center gap-1.5 py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all cursor-pointer ${
                            activeTab === 'responses' 
                                ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400' 
                                : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
                        }`}
                    >
                        <Eye size={14} /> Respons
                    </button>
                    <button
                        onClick={() => setActiveTab('feedback')}
                        className={`flex items-center gap-1.5 py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all cursor-pointer ${
                            activeTab === 'feedback' 
                                ? 'border-amber-500 text-amber-600 dark:text-amber-400' 
                                : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
                        }`}
                    >
                        <AlertTriangle size={14} /> Laporan Masukan
                    </button>
                </div>

                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-[#00897B]'}`}>
                        {toast.msg}
                    </div>
                )}

                <div className="p-6 max-w-6xl mx-auto w-full space-y-6">

                    {/* ── RESPONSES TAB ── */}
                    {activeTab === 'responses' && (
                        <>
                            {/* Trend Diagram */}
                            {trendData.length > 0 && (
                                <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm space-y-4">
                                    <div className="flex items-center justify-between">
                                        <div>
                                            <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                                                <TrendingUp size={16} className="text-[#00897B] dark:text-teal-400" />
                                                Diagram Tren Respons Formulir
                                            </h3>
                                            <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                                Perkembangan jumlah pengiriman berdasarkan tanggal submit
                                            </p>
                                        </div>
                                        <span className="text-[11px] font-bold px-2.5 py-1 rounded-full bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400">
                                            {trendData.length} Titik Data
                                        </span>
                                    </div>

                                    <div className="h-44 flex items-end gap-3 pt-6 pb-2 px-2 border-b border-slate-100 dark:border-slate-800">
                                        {trendData.map((item, idx) => {
                                            const heightPercent = Math.max((item.count / maxCount) * 100, 15);
                                            return (
                                                <div key={idx} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group">
                                                    <span className="text-[10px] font-extrabold text-[#00897B] dark:text-teal-400 opacity-0 group-hover:opacity-100 transition-opacity">
                                                        {item.count}
                                                    </span>
                                                    <div
                                                        className="w-full bg-linear-to-t from-[#00897B] to-[#4DB6AC] dark:from-teal-600 dark:to-teal-400 rounded-t-lg transition-all duration-500 group-hover:brightness-110 shadow-xs"
                                                        style={{ height: `${heightPercent}%` }}
                                                    />
                                                    <span className="text-[10px] font-semibold text-slate-400 dark:text-slate-500 truncate w-full text-center">
                                                        {item.date}
                                                    </span>
                                                </div>
                                            );
                                        })}
                                    </div>
                                </div>
                            )}

                            {respondentsList.length === 0 ? (
                                <div className="text-center py-20 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 text-slate-400 dark:text-slate-500 text-sm font-medium">
                                    Belum ada respons yang masuk untuk formulir ini.
                                </div>
                            ) : (
                                <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-sm">
                                    <div className="p-4 border-b border-slate-100 dark:border-slate-800 flex flex-wrap items-center justify-between gap-3">
                                        <div className="flex items-center gap-3">
                                            <h2 className="text-sm font-bold text-slate-900 dark:text-white">Daftar Respons Masuk</h2>
                                            <span className="text-xs font-bold text-slate-400 dark:text-slate-500">{respondentsList.length} Total Respons</span>
                                        </div>

                                        {respondentsList.length > 0 && (
                                            <div className="flex items-center gap-2">
                                                <button
                                                    type="button"
                                                    onClick={() => setBulkModalOpen(true)}
                                                    className="flex items-center gap-1.5 px-3 py-1.5 bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800 text-[#00897B] dark:text-teal-400 hover:bg-teal-100 dark:hover:bg-teal-900/60 rounded-xl text-xs font-bold transition-all shadow-2xs cursor-pointer"
                                                    title="Ubah skor seluruh responden secara massal (bonus, skala, dll)"
                                                >
                                                    <Sliders size={13} /> Penyesuaian Skor Massal
                                                </button>
                                            </div>
                                        )}
                                    </div>

                                    <div className="overflow-x-auto w-full">
                                        <table className="w-full text-sm text-left">
                                            <thead>
                                                <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                                    <th className="py-3 px-4">#</th>
                                                    <th className="py-3 px-4">Responden</th>
                                                    <th className="py-3 px-4">Soal Dijawab</th>
                                                    <th className="py-3 px-4">Benar</th>
                                                    <th className="py-3 px-4">Salah</th>
                                                    <th className="py-3 px-4">Skor</th>
                                                    <th className="py-3 px-4">Status</th>
                                                    <th className="py-3 px-4">Waktu Submit</th>
                                                    <th className="py-3 px-4 text-right">Aksi</th>
                                                </tr>
                                            </thead>
                                            <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                                {respondentsList.map((r, i) => {
                                                    const scorable = r.scorableQuestions ?? 0;
                                                    const correct = r.correctCount ?? 0;
                                                    const wrong = r.wrongCount != null ? r.wrongCount : Math.max(scorable - correct, 0);
                                                    const isEditing = editingScoreId === r.responseId;

                                                    return (
                                                        <tr key={r.responseId || i} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                            <td className="py-3.5 px-4 text-slate-400 font-medium">{i + 1}</td>
                                                            <td className="py-3.5 px-4">
                                                                <div className="font-bold text-slate-900 dark:text-white">{r.respondentName || 'Anonim'}</div>
                                                                <div className="text-[10px] text-slate-400 dark:text-slate-500">#{r.responseId}</div>
                                                            </td>
                                                            <td className="py-3.5 px-4 text-slate-600 dark:text-slate-300 font-medium">
                                                                {r.answeredCount ?? 0}/{r.totalQuestions ?? 0}
                                                            </td>
                                                            <td className="py-3.5 px-4 text-emerald-600 dark:text-emerald-400 font-bold">
                                                                {correct}
                                                            </td>
                                                            <td className="py-3.5 px-4 text-red-500 dark:text-red-400 font-bold">
                                                                {wrong}
                                                            </td>
                                                            <td className="py-3.5 px-4">
                                                                {isEditing ? (
                                                                    <div className="flex items-center gap-1">
                                                                        <input
                                                                            type="number"
                                                                            min="0"
                                                                            max="100"
                                                                            step="0.5"
                                                                            value={inlineScoreInput}
                                                                            onChange={e => setInlineScoreInput(e.target.value)}
                                                                            className="w-16 px-2 py-1 bg-white dark:bg-slate-800 border border-[#00897B] rounded-lg text-xs font-bold text-slate-900 dark:text-white focus:outline-none"
                                                                            autoFocus
                                                                            onKeyDown={e => e.key === 'Enter' && handleSaveIndividualScore(r.responseId, inlineScoreInput)}
                                                                        />
                                                                        <button
                                                                            type="button"
                                                                            onClick={() => handleSaveIndividualScore(r.responseId, inlineScoreInput)}
                                                                            className="p-1 bg-[#00897B] text-white rounded-lg hover:bg-[#00796B] cursor-pointer"
                                                                            title="Simpan Skor"
                                                                        >
                                                                            <Check size={12} />
                                                                        </button>
                                                                        <button
                                                                            type="button"
                                                                            onClick={() => setEditingScoreId(null)}
                                                                            className="p-1 text-slate-400 hover:text-slate-600 cursor-pointer"
                                                                            title="Batal"
                                                                        >
                                                                            <X size={12} />
                                                                        </button>
                                                                    </div>
                                                                ) : (
                                                                    <div className="flex items-center gap-1.5 group">
                                                                        {r.score != null ? (
                                                                            <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${
                                                                                r.score >= 70
                                                                                    ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400'
                                                                                    : 'bg-red-50 text-red-600 dark:bg-red-950/60 dark:text-red-400'
                                                                            }`}>
                                                                                {r.score}%
                                                                                {r.isCustomScore && <span className="ml-1 text-[9px] opacity-75 font-normal">*edit</span>}
                                                                            </span>
                                                                        ) : (
                                                                            <span className="text-xs text-slate-400 dark:text-slate-500 font-medium">N/A</span>
                                                                        )}
                                                                        <button
                                                                            type="button"
                                                                            onClick={() => {
                                                                                setEditingScoreId(r.responseId);
                                                                                setInlineScoreInput(r.score != null ? String(r.score) : '100');
                                                                            }}
                                                                            className="opacity-0 group-hover:opacity-100 p-1 text-slate-400 hover:text-[#00897B] rounded transition-opacity cursor-pointer"
                                                                            title="Ubah Nilai Responden"
                                                                        >
                                                                            <Edit2 size={12} />
                                                                        </button>
                                                                    </div>
                                                                )}
                                                            </td>
                                                            <td className="py-3.5 px-4">
                                                                <select
                                                                    value={STATUS_OPTIONS.find(s => s.code === r.status?.toLowerCase())?.id ?? 1}
                                                                    onChange={e => handleStatusChange(r.responseId, parseInt(e.target.value))}
                                                                    disabled={statusUpdating === r.responseId}
                                                                    className={`text-[11px] font-bold px-2.5 py-1 rounded-full border-0 cursor-pointer focus:outline-none focus:ring-1 focus:ring-teal-400 disabled:opacity-60 ${statusStyle(r.status)}`}
                                                                >
                                                                    {STATUS_OPTIONS.map(s => (
                                                                        <option key={s.id} value={s.id}>{s.label}</option>
                                                                    ))}
                                                                </select>
                                                            </td>
                                                            <td className="py-3.5 px-4 text-slate-500 dark:text-slate-400 text-xs">
                                                                {formatDate(r.submittedAt)}
                                                            </td>
                                                            <td className="py-3.5 px-4 text-right">
                                                                <button
                                                                    onClick={async () => {
                                                                        if (r.answers && r.answers.length > 0) {
                                                                            setSelectedRespondent(r);
                                                                        } else {
                                                                            const res = await getResponseResult(id, r.responseId);
                                                                            setSelectedRespondent(res.ok && res.data ? { ...r, ...res.data } : r);
                                                                        }
                                                                    }}
                                                                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer"
                                                                >
                                                                    <Eye size={13} /> Review Jawaban
                                                                </button>
                                                            </td>
                                                        </tr>
                                                    );
                                                })}
                                            </tbody>
                                        </table>
                                    </div>
                                </div>
                            )}
                        </>
                    )}

                    {/* ── FEEDBACK TAB ── */}
                    {activeTab === 'feedback' && (
                        <>
                            {feedbackLoading ? (
                                <div className="text-center py-16 text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat laporan masukan...</div>
                            ) : feedbacks.length === 0 ? (
                                <div className="text-center py-16 space-y-2 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800">
                                    <MessageSquare size={32} className="text-slate-300 dark:text-slate-600 mx-auto" />
                                    <p className="text-slate-500 dark:text-slate-400 text-sm font-bold">Belum ada laporan masukan untuk formulir ini.</p>
                                    <p className="text-xs text-slate-400 dark:text-slate-500">Masukan dikirimkan oleh responden setelah menyelesaikan formulir.</p>
                                </div>
                            ) : (
                                <div className="space-y-3">
                                    {feedbacks.map((fb, i) => (
                                        <div key={fb.id ?? i} className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 shadow-xs space-y-3">
                                            <div className="flex items-start justify-between gap-3">
                                                <span className="text-xs font-extrabold px-3 py-1 rounded-full bg-amber-50 dark:bg-amber-950/60 text-amber-700 dark:text-amber-400 border border-amber-200 dark:border-amber-800 flex items-center gap-1.5">
                                                    <AlertTriangle size={13} /> {fb.reason}
                                                </span>
                                                <span className="text-xs text-slate-400 dark:text-slate-500 font-medium shrink-0">{formatDate(fb.createdAt)}</span>
                                            </div>

                                            {fb.description && (
                                                <p className="text-sm text-slate-700 dark:text-slate-200 leading-relaxed border-l-2 border-amber-300 dark:border-amber-500 pl-3">
                                                    {fb.description}
                                                </p>
                                            )}

                                            <div className="flex items-center gap-3 pt-1 border-t border-slate-100 dark:border-slate-800">
                                                <div className="w-6 h-6 bg-teal-100 dark:bg-teal-950 text-[#00897B] dark:text-teal-400 rounded-full flex items-center justify-center text-[10px] font-black shrink-0">
                                                    {(fb.userName || 'U').charAt(0).toUpperCase()}
                                                </div>
                                                <span className="text-xs font-bold text-slate-800 dark:text-slate-200">{fb.userName || 'Anonim'}</span>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </>
                    )}

                </div>
            </div>

            {/* ── REVIEW JAWABAN MODAL ── */}
            {selectedRespondent && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-black/50 backdrop-blur-xs"
                        onClick={() => setSelectedRespondent(null)}
                    />

                    <div className="relative bg-white dark:bg-slate-900 w-full max-w-3xl max-h-[90vh] rounded-3xl shadow-2xl flex flex-col overflow-hidden border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 animate-in fade-in zoom-in-95 duration-200">
                        
                        {/* Header */}
                        <div className="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between shrink-0 bg-slate-50/50 dark:bg-slate-800/50">
                            <div>
                                <h2 className="font-bold text-slate-900 dark:text-white text-base">
                                    Review Jawaban Responden
                                </h2>
                                <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                    Responden: <span className="font-bold text-slate-700 dark:text-slate-300">{selectedRespondent.respondentName || 'Anonim'}</span> (Respons #{selectedRespondent.responseId})
                                </p>
                            </div>
                            <button
                                onClick={() => setSelectedRespondent(null)}
                                className="p-2 rounded-xl text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {/* Summary Bar with Editable Score */}
                        <div className="px-6 py-3.5 bg-slate-100/60 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 flex flex-wrap items-center justify-between gap-3">
                            <div className="flex flex-wrap items-center gap-3">
                                <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Skor Total</p>
                                    <div className="flex items-center gap-1.5">
                                        <input
                                            type="number"
                                            min="0"
                                            max="100"
                                            step="0.5"
                                            value={selectedRespondent.score != null ? selectedRespondent.score : ''}
                                            onChange={e => {
                                                const val = parseFloat(e.target.value) || 0;
                                                setSelectedRespondent(prev => ({ ...prev, score: val }));
                                            }}
                                            onBlur={e => handleSaveIndividualScore(selectedRespondent.responseId, e.target.value)}
                                            className="w-16 text-base font-extrabold text-slate-900 dark:text-white bg-transparent border-b border-slate-300 dark:border-slate-600 focus:border-[#00897B] outline-none"
                                        />
                                        <span className="text-xs font-bold text-slate-500">%</span>
                                    </div>
                                </div>
                                <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Dijawab</p>
                                    <p className="text-base font-extrabold text-slate-900 dark:text-white">
                                        {selectedRespondent.answeredCount}/{selectedRespondent.totalQuestions}
                                    </p>
                                </div>
                                <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Benar</p>
                                    <p className="text-base font-extrabold text-emerald-600 dark:text-emerald-400">
                                        {selectedRespondent.correctCount ?? 0}
                                    </p>
                                </div>
                                <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                    <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Waktu Submit</p>
                                    <p className="text-xs font-bold text-slate-700 dark:text-slate-300 mt-1">
                                        {formatDate(selectedRespondent.submittedAt)}
                                    </p>
                                </div>
                            </div>
                        </div>

                        {/* Answers List */}
                        <div className="flex-1 overflow-y-auto p-6 space-y-4">
                            {(selectedRespondent.answers || []).map((answer, index) => {
                                const status = getAnswerStatus(answer);

                                return (
                                    <div
                                        key={answer.questionId || index}
                                        className="border border-slate-200 dark:border-slate-800 rounded-2xl overflow-hidden shadow-xs"
                                    >
                                        <div className="p-4 bg-white dark:bg-slate-900 flex items-start gap-3 justify-between">
                                            <div className="flex items-start gap-3 flex-1 min-w-0">
                                                <span className="shrink-0 w-7 h-7 flex items-center justify-center rounded-xl bg-slate-100 dark:bg-slate-800 text-xs font-bold text-slate-600 dark:text-slate-300">
                                                    {index + 1}
                                                </span>
                                                <div className="flex-1 min-w-0">
                                                    <div className="text-sm font-semibold text-slate-900 dark:text-white leading-relaxed break-words">
                                                        <RichContentRenderer content={answer.question} />
                                                    </div>
                                                    {answer.questionImage && (
                                                        <div className="my-2 max-w-xs relative group/img overflow-hidden rounded-xl border border-slate-200 dark:border-slate-700 p-1 bg-white dark:bg-slate-900 shadow-xs">
                                                            <img
                                                                src={assetUrl(answer.questionImage)}
                                                                alt="Gambar Soal"
                                                                className="max-h-40 w-auto rounded-lg object-contain mx-auto cursor-zoom-in"
                                                                onClick={() => setLightboxImage({ src: assetUrl(answer.questionImage), alt: 'Gambar Soal' })}
                                                            />
                                                            <button
                                                                type="button"
                                                                onClick={() => setLightboxImage({ src: assetUrl(answer.questionImage), alt: 'Gambar Soal' })}
                                                                className="absolute bottom-2 right-2 p-1.5 bg-slate-900/80 hover:bg-slate-900 text-white rounded-lg text-xs font-bold flex items-center gap-1 opacity-0 group-hover/img:opacity-100 transition-opacity cursor-pointer"
                                                            >
                                                                <Maximize2 size={11} /> Perbesar
                                                            </button>
                                                        </div>
                                                    )}
                                                </div>
                                            </div>

                                            {/* Status Badge & Per-question Score Correction Controls */}
                                            <div className="shrink-0 flex items-center gap-2">
                                                <div className={`flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[11px] font-bold ${status.className}`}>
                                                    {status.icon}
                                                    <span>{status.label}</span>
                                                </div>
                                                <div className="flex items-center gap-1 bg-slate-100 dark:bg-slate-800 p-0.5 rounded-lg border border-slate-200 dark:border-slate-700">
                                                    <button
                                                        type="button"
                                                        onClick={() => handleToggleQuestionCorrect(selectedRespondent.responseId, answer.questionId, false)}
                                                        className={`px-2 py-1 text-[11px] font-bold rounded cursor-pointer transition-all ${
                                                            answer.isCorrect === true
                                                                ? 'bg-emerald-500 text-white shadow-2xs'
                                                                : 'text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
                                                        }`}
                                                        title="Koreksi: Tandai Benar"
                                                    >
                                                        Benar
                                                    </button>
                                                    <button
                                                        type="button"
                                                        onClick={() => handleToggleQuestionCorrect(selectedRespondent.responseId, answer.questionId, true)}
                                                        className={`px-2 py-1 text-[11px] font-bold rounded cursor-pointer transition-all ${
                                                            answer.isCorrect === false
                                                                ? 'bg-red-500 text-white shadow-2xs'
                                                                : 'text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
                                                        }`}
                                                        title="Koreksi: Tandai Salah"
                                                    >
                                                        Salah
                                                    </button>
                                                </div>
                                            </div>
                                        </div>

                                        <div className="border-t border-slate-100 dark:border-slate-800 p-4 space-y-3 bg-slate-50 dark:bg-slate-800/50 text-xs">
                                            <div>
                                                <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400 dark:text-slate-500 mb-1">
                                                    Jawaban Responden:
                                                </p>
                                                <div className={`rounded-xl border p-3 font-medium ${
                                                    answer.isCorrect === true
                                                        ? 'bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800 text-emerald-900 dark:text-emerald-200'
                                                        : answer.isCorrect === false
                                                        ? 'bg-red-50 dark:bg-red-950/40 border-red-200 dark:border-red-800 text-red-900 dark:text-red-200'
                                                        : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200'
                                                }`}>
                                                    {answer.answerText || answer.answerValue || answer.optionText ? (
                                                        <RichContentRenderer content={answer.answerText || answer.answerValue || answer.optionText} />
                                                    ) : (
                                                        <span className="text-slate-400 dark:text-slate-500 italic">Tidak ada jawaban</span>
                                                    )}
                                                </div>
                                            </div>

                                            {answer.correctAnswer && (
                                                <div>
                                                    <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400 dark:text-slate-500 mb-1">
                                                        Kunci / Jawaban Benar:
                                                    </p>
                                                    <div className="rounded-xl border border-emerald-200 dark:border-emerald-800 bg-emerald-50 dark:bg-emerald-950/40 p-3 text-emerald-900 dark:text-emerald-200 font-bold">
                                                        <RichContentRenderer content={answer.correctAnswer} />
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                );
                            })}

                            {(!selectedRespondent.answers || selectedRespondent.answers.length === 0) && (
                                <div className="text-center py-12 text-sm text-slate-400 dark:text-slate-500">
                                    Rincian jawaban tidak tersedia.
                                </div>
                            )}
                        </div>

                        {/* Navigation Footer */}
                        <div className="px-6 py-3 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between shrink-0">
                            <button
                                onClick={goPrevious}
                                disabled={currentIndex <= 0}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                            >
                                <ChevronLeft size={15} /> Sebelumnya
                            </button>

                            <span className="text-xs text-slate-400 dark:text-slate-500 font-semibold">
                                {currentIndex + 1} dari {respondentsList.length}
                            </span>

                            <button
                                onClick={goNext}
                                disabled={currentIndex === respondentsList.length - 1}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                            >
                                Selanjutnya <ChevronRight size={15} />
                            </button>
                        </div>

                    </div>
                </div>
            )}

            {/* ── BULK SCORE ADJUSTMENT MODAL ── */}
            {bulkModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-black/50 backdrop-blur-xs"
                        onClick={() => setBulkModalOpen(false)}
                    />

                    <div className="relative bg-white dark:bg-slate-900 w-full max-w-xl max-h-[90vh] rounded-3xl shadow-2xl overflow-hidden border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 flex flex-col animate-in fade-in zoom-in-95 duration-150 font-sans">
                        
                        {/* Header */}
                        <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between shrink-0 bg-slate-50/50 dark:bg-slate-800/50">
                            <div className="flex items-center gap-2.5">
                                <div className="p-2 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-xl">
                                    <Sliders size={18} />
                                </div>
                                <div>
                                    <h3 className="text-sm font-extrabold text-slate-900 dark:text-white">
                                        Penyesuaian Skor Massal
                                    </h3>
                                    <p className="text-[11px] text-slate-400 dark:text-slate-500">
                                        Sesuaikan nilai responden dengan filter dan aturan fleksibel
                                    </p>
                                </div>
                            </div>
                            <button
                                type="button"
                                onClick={() => setBulkModalOpen(false)}
                                className="p-1 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-lg cursor-pointer"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {/* Body */}
                        <div className="p-5 overflow-y-auto space-y-5 flex-1">
                            
                            {/* 1. Target Filter */}
                            <div>
                                <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-2">
                                    1. Target Responden yang Disesuaikan:
                                </label>
                                <div className="grid grid-cols-3 gap-2">
                                    <button
                                        type="button"
                                        onClick={() => setBulkFilter('all')}
                                        className={`p-2.5 rounded-xl border text-xs font-bold text-center cursor-pointer transition-all ${
                                            bulkFilter === 'all'
                                                ? 'bg-teal-50 dark:bg-teal-950/60 border-[#00897B] text-[#00897B] dark:text-teal-400 shadow-2xs'
                                                : 'border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-400'
                                        }`}
                                    >
                                        Semua Responden
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => setBulkFilter('below')}
                                        className={`p-2.5 rounded-xl border text-xs font-bold text-center cursor-pointer transition-all ${
                                            bulkFilter === 'below'
                                                ? 'bg-teal-50 dark:bg-teal-950/60 border-[#00897B] text-[#00897B] dark:text-teal-400 shadow-2xs'
                                                : 'border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-400'
                                        }`}
                                    >
                                        Nilai di Bawah Batas
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => setBulkFilter('range')}
                                        className={`p-2.5 rounded-xl border text-xs font-bold text-center cursor-pointer transition-all ${
                                            bulkFilter === 'range'
                                                ? 'bg-teal-50 dark:bg-teal-950/60 border-[#00897B] text-[#00897B] dark:text-teal-400 shadow-2xs'
                                                : 'border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-400'
                                        }`}
                                    >
                                        Rentang Nilai Tertentu
                                    </button>
                                </div>

                                {bulkFilter === 'below' && (
                                    <div className="mt-3 p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl border border-slate-200 dark:border-slate-700 flex items-center justify-between gap-3 text-xs">
                                        <span className="font-medium text-slate-600 dark:text-slate-300">Hanya sesuaikan responden dengan nilai di bawah:</span>
                                        <div className="flex items-center gap-1">
                                            <input
                                                type="number"
                                                min="0"
                                                max="100"
                                                value={filterThreshold}
                                                onChange={e => setFilterThreshold(parseFloat(e.target.value) || 0)}
                                                className="w-16 px-2 py-1 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-center font-bold"
                                            />
                                            <span className="font-bold text-slate-500">%</span>
                                        </div>
                                    </div>
                                )}

                                {bulkFilter === 'range' && (
                                    <div className="mt-3 p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl border border-slate-200 dark:border-slate-700 flex items-center justify-between gap-3 text-xs">
                                        <span className="font-medium text-slate-600 dark:text-slate-300">Hanya sesuaikan responden dengan nilai antara:</span>
                                        <div className="flex items-center gap-2">
                                            <input
                                                type="number"
                                                min="0"
                                                max="100"
                                                value={filterRangeMin}
                                                onChange={e => setFilterRangeMin(parseFloat(e.target.value) || 0)}
                                                className="w-14 px-2 py-1 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-center font-bold"
                                            />
                                            <span className="text-slate-400">s/d</span>
                                            <input
                                                type="number"
                                                min="0"
                                                max="100"
                                                value={filterRangeMax}
                                                onChange={e => setFilterRangeMax(parseFloat(e.target.value) || 0)}
                                                className="w-14 px-2 py-1 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-center font-bold"
                                            />
                                            <span className="font-bold text-slate-500">%</span>
                                        </div>
                                    </div>
                                )}
                            </div>

                            {/* 2. Adjustment Method */}
                            <div>
                                <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-2">
                                    2. Metode Penyesuaian Nilai:
                                </label>
                                <div className="space-y-2">
                                    <label className={`flex items-start gap-3 p-3 rounded-2xl border cursor-pointer transition-all ${
                                        bulkType === 'min'
                                            ? 'border-[#00897B] bg-teal-50/40 dark:bg-teal-950/40'
                                            : 'border-slate-200 dark:border-slate-700 hover:border-slate-300'
                                    }`}>
                                        <input
                                            type="radio"
                                            name="bulkType"
                                            value="min"
                                            checked={bulkType === 'min'}
                                            onChange={() => { setBulkType('min'); setBulkValue(75); }}
                                            className="mt-0.5 text-[#00897B] cursor-pointer"
                                        />
                                        <div className="flex-1 text-xs">
                                            <p className="font-bold text-slate-900 dark:text-white">Batas Skor Minimum (Threshold)</p>
                                            <p className="text-slate-500 dark:text-slate-400">Nilai di bawah batas dinaikkan ke batas. Nilai yang sudah di atas batas tetap aman dan tidak akan turun.</p>
                                        </div>
                                    </label>

                                    <label className={`flex items-start gap-3 p-3 rounded-2xl border cursor-pointer transition-all ${
                                        bulkType === 'bonus'
                                            ? 'border-[#00897B] bg-teal-50/40 dark:bg-teal-950/40'
                                            : 'border-slate-200 dark:border-slate-700 hover:border-slate-300'
                                    }`}>
                                        <input
                                            type="radio"
                                            name="bulkType"
                                            value="bonus"
                                            checked={bulkType === 'bonus'}
                                            onChange={() => { setBulkType('bonus'); setBulkValue(10); }}
                                            className="mt-0.5 text-[#00897B] cursor-pointer"
                                        />
                                        <div className="flex-1 text-xs">
                                            <p className="font-bold text-slate-900 dark:text-white">Tambah Nilai Bonus (+ Poin)</p>
                                            <p className="text-slate-500 dark:text-slate-400">Tambahkan poin tetap ke setiap responden yang memenuhi kriteria (maksimal 100).</p>
                                        </div>
                                    </label>

                                    <label className={`flex items-start gap-3 p-3 rounded-2xl border cursor-pointer transition-all ${
                                        bulkType === 'scale'
                                            ? 'border-[#00897B] bg-teal-50/40 dark:bg-teal-950/40'
                                            : 'border-slate-200 dark:border-slate-700 hover:border-slate-300'
                                    }`}>
                                        <input
                                            type="radio"
                                            name="bulkType"
                                            value="scale"
                                            checked={bulkType === 'scale'}
                                            onChange={() => { setBulkType('scale'); setBulkValue(110); }}
                                            className="mt-0.5 text-[#00897B] cursor-pointer"
                                        />
                                        <div className="flex-1 text-xs">
                                            <p className="font-bold text-slate-900 dark:text-white">Kalikan Kurva Skala Persentase (x %)</p>
                                            <p className="text-slate-500 dark:text-slate-400">Kalikan nilai saat ini dengan persentase tertentu (misal: 110% = nilai x 1.1).</p>
                                        </div>
                                    </label>

                                    <label className={`flex items-start gap-3 p-3 rounded-2xl border cursor-pointer transition-all ${
                                        bulkType === 'set_fixed'
                                            ? 'border-[#00897B] bg-teal-50/40 dark:bg-teal-950/40'
                                            : 'border-slate-200 dark:border-slate-700 hover:border-slate-300'
                                    }`}>
                                        <input
                                            type="radio"
                                            name="bulkType"
                                            value="set_fixed"
                                            checked={bulkType === 'set_fixed'}
                                            onChange={() => { setBulkType('set_fixed'); setBulkValue(80); }}
                                            className="mt-0.5 text-[#00897B] cursor-pointer"
                                        />
                                        <div className="flex-1 text-xs">
                                            <p className="font-bold text-slate-900 dark:text-white">Tetapkan Nilai Rata (= Nilai Tetap)</p>
                                            <p className="text-slate-500 dark:text-slate-400">Ubah seluruh nilai responden yang memenuhi kriteria langsung menjadi nilai ini.</p>
                                        </div>
                                    </label>
                                </div>
                            </div>

                            {/* 3. Parameter Value Input */}
                            <div>
                                <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1.5">
                                    {bulkType === 'min' ? 'Batas Nilai Minimum Target:' : bulkType === 'bonus' ? 'Jumlah Poin Bonus Tambahan (+):' : bulkType === 'scale' ? 'Faktor Skala Persentase (%):' : 'Nilai Tetap yang Diterapkan:'}
                                </label>
                                <div className="flex items-center gap-2">
                                    <input
                                        type="number"
                                        step={bulkType === 'scale' ? '5' : '1'}
                                        min="0"
                                        max={bulkType === 'scale' ? '200' : '100'}
                                        value={bulkValue}
                                        onChange={e => setBulkValue(parseFloat(e.target.value) || 0)}
                                        className="w-full px-3.5 py-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white text-sm font-bold focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                    <span className="text-xs font-bold text-slate-500">
                                        {bulkType === 'scale' ? '%' : 'poin'}
                                    </span>
                                </div>
                            </div>

                            {/* 4. Live Preview Section */}
                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                <div className="flex items-center justify-between mb-2">
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                                        Live Preview Perubahan Nilai:
                                    </label>
                                    <span className="text-[11px] font-bold text-teal-600 dark:text-teal-400">
                                        {previewAdjustments.filter(p => p.meetsFilter && p.diff !== 0).length} dari {previewAdjustments.length} responden terpengaruh
                                    </span>
                                </div>

                                <div className="border border-slate-200 dark:border-slate-700 rounded-2xl overflow-hidden max-h-44 overflow-y-auto">
                                    <table className="w-full text-xs text-left">
                                        <thead className="bg-slate-100 dark:bg-slate-800 text-slate-500 font-bold sticky top-0">
                                            <tr>
                                                <th className="py-2 px-3">Responden</th>
                                                <th className="py-2 px-3 text-center">Skor Saat Ini</th>
                                                <th className="py-2 px-3 text-center">Skor Baru</th>
                                                <th className="py-2 px-3 text-right">Perubahan</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                            {previewAdjustments.map((item, idx) => (
                                                <tr key={item.responseId || idx} className="hover:bg-slate-50 dark:hover:bg-slate-800/50">
                                                    <td className="py-2 px-3 font-medium text-slate-800 dark:text-slate-200">
                                                        {item.respondentName || 'Anonim'}
                                                    </td>
                                                    <td className="py-2 px-3 text-center font-bold text-slate-600 dark:text-slate-300">
                                                        {item.currentScore}%
                                                    </td>
                                                    <td className="py-2 px-3 text-center font-extrabold text-slate-900 dark:text-white">
                                                        {item.projectedScore}%
                                                    </td>
                                                    <td className="py-2 px-3 text-right font-bold">
                                                        {item.diff > 0 ? (
                                                            <span className="text-emerald-600 dark:text-emerald-400 font-extrabold">+{item.diff}%</span>
                                                        ) : item.diff < 0 ? (
                                                            <span className="text-red-500 dark:text-red-400 font-extrabold">{item.diff}%</span>
                                                        ) : (
                                                            <span className="text-slate-400 font-normal">Tetap</span>
                                                        )}
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                        </div>

                        {/* Footer */}
                        <div className="p-4 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between shrink-0 bg-slate-50/50 dark:bg-slate-800/50">
                            <button
                                type="button"
                                onClick={handleResetAllScores}
                                className="flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-red-500 transition-colors cursor-pointer"
                                title="Kembalikan semua nilai ke perhitungan asli sistem"
                            >
                                <RotateCcw size={13} /> Reset Semua
                            </button>

                            <div className="flex items-center gap-2">
                                <button
                                    type="button"
                                    onClick={() => setBulkModalOpen(false)}
                                    className="px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
                                >
                                    Batal
                                </button>
                                <button
                                    type="button"
                                    onClick={handleApplyBulkScore}
                                    className="px-5 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-xs cursor-pointer"
                                >
                                    Terapkan Perubahan
                                </button>
                            </div>
                        </div>

                    </div>
                </div>
            )}

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
