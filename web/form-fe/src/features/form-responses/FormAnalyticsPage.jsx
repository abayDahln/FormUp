import { useState, useEffect, useCallback, useMemo } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    ArrowLeft,
    Users,
    FileText,
    Award,
    TrendingUp,
    Eye,
    X,
    CheckCircle2,
    XCircle,
    MinusCircle,
    ChevronLeft,
    ChevronRight,
    Loader2,
    BarChart3,
    Check,
    AlertCircle,
    Download
} from 'lucide-react';

import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById,
    getFormAnalytics,
    exportFormResponses,
    clearSession
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

const PAGE_SIZE = 25;

export default function FormAnalyticsPage() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [form, setForm] = useState(null);
    const [analytics, setAnalytics] = useState(null);
    const [respondents, setRespondents] = useState([]);
    const [loading, setLoading] = useState(true);
    const [loadingMore, setLoadingMore] = useState(false);
    const [page, setPage] = useState(1);
    const [hasMore, setHasMore] = useState(true);
    const [totalCount, setTotalCount] = useState(0);
    const [selectedRespondent, setSelectedRespondent] = useState(null);
    const [exportingFormat, setExportingFormat] = useState(null);
    const [exportError, setExportError] = useState(null);

    const handleExport = async (format) => {
        if (!id || exportingFormat !== null) return;
        setExportingFormat(format);
        setExportError(null);

        try {
            const res = await exportFormResponses(id, format);
            if (!res.ok) {
                setExportError(res.message || `Gagal mengekspor data ke format ${format.toUpperCase()}`);
                setTimeout(() => setExportError(null), 4000);
            }
        } catch (err) {
            setExportError(`Terjadi kesalahan saat mengekspor data ${format.toUpperCase()}`);
            setTimeout(() => setExportError(null), 4000);
        } finally {
            setExportingFormat(null);
        }
    };

    useEffect(() => {
        const load = async () => {
            setLoading(true);

            try {
                const [formRes, analyticsRes] = await Promise.all([
                    getFormById(id),
                    getFormAnalytics(id, 1, PAGE_SIZE)
                ]);

                if (formRes.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (formRes.ok) {
                    setForm(formRes.data);
                }

                if (analyticsRes.ok && analyticsRes.data) {
                    setAnalytics(analyticsRes.data);
                    const list = analyticsRes.data.respondents || [];
                    const total = analyticsRes.data.totalResponses ?? list.length;
                    setRespondents(list);
                    setTotalCount(total);
                    setHasMore(list.length >= PAGE_SIZE);
                }
            } catch (error) {
                console.error('Failed to load analytics:', error);
            } finally {
                setLoading(false);
            }
        };

        load();
    }, [id, navigate]);

    const handleLoadMore = useCallback(async () => {
        if (loadingMore || !hasMore) return;
        setLoadingMore(true);

        const nextPage = page + 1;
        const res = await getFormAnalytics(id, nextPage, PAGE_SIZE);
        setLoadingMore(false);

        if (res.ok && res.data) {
            const newList = res.data.respondents || [];
            if (newList.length > 0) {
                setRespondents(prev => [...prev, ...newList]);
                setPage(nextPage);
                setHasMore(newList.length >= PAGE_SIZE);
            } else {
                setHasMore(false);
            }
        }
    }, [id, page, loadingMore, hasMore]);

    // ── Analytical Calculations for Diagrams ─────────────────────────────────
    const gradeDistribution = useMemo(() => {
        const counts = { A: 0, B: 0, C: 0, D: 0, E: 0, total: 0 };
        respondents.forEach(r => {
            if (r.score == null) return;
            counts.total++;
            if (r.score >= 90) counts.A++;
            else if (r.score >= 75) counts.B++;
            else if (r.score >= 60) counts.C++;
            else if (r.score >= 40) counts.D++;
            else counts.E++;
        });
        return counts;
    }, [respondents]);

    const passRateMetrics = useMemo(() => {
        let passed = 0;
        let failed = 0;
        respondents.forEach(r => {
            if (r.score == null) return;
            if (r.score >= 70) passed++;
            else failed++;
        });
        const total = passed + failed;
        return {
            passed,
            failed,
            total,
            passPercent: total > 0 ? Math.round((passed / total) * 100) : 0,
            failPercent: total > 0 ? Math.round((failed / total) * 100) : 0,
        };
    }, [respondents]);

    const questionAccuracyMap = useMemo(() => {
        const qMap = {};
        respondents.forEach(r => {
            (r.answers || []).forEach(a => {
                if (!a.questionId) return;
                if (!qMap[a.questionId]) {
                    qMap[a.questionId] = {
                        questionId: a.questionId,
                        question: a.question || `Soal #${a.questionId}`,
                        questionFormat: a.questionFormat || 'text',
                        correctCount: 0,
                        totalAttempts: 0,
                    };
                }
                if (a.isCorrect != null) {
                    qMap[a.questionId].totalAttempts++;
                    if (a.isCorrect === true) qMap[a.questionId].correctCount++;
                }
            });
        });

        return Object.values(qMap).map(q => ({
            ...q,
            accuracy: q.totalAttempts > 0 ? Math.round((q.correctCount / q.totalAttempts) * 100) : 0,
        })).sort((a, b) => a.accuracy - b.accuracy);
    }, [respondents]);

    if (loading) {
        return (
            <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
                <div className="text-center space-y-2">
                    <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400" />
                    <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat analisis formulir...</p>
                </div>
            </div>
        );
    }

    const currentIndex = selectedRespondent
        ? respondents.findIndex(r => r.responseId === selectedRespondent.responseId)
        : -1;

    const goPrevious = () => {
        if (currentIndex > 0) {
            setSelectedRespondent(respondents[currentIndex - 1]);
        }
    };

    const goNext = () => {
        if (currentIndex < respondents.length - 1) {
            setSelectedRespondent(respondents[currentIndex + 1]);
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

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">

                {/* Header */}
                <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-6 py-4 flex flex-wrap items-center justify-between gap-3">
                    <div className="flex items-center gap-3 min-w-0">
                        <button
                            onClick={() => navigate(`/forms/${id}/responses`)}
                            className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all cursor-pointer"
                        >
                            <ArrowLeft size={18} />
                        </button>

                        <div className="min-w-0">
                            <h1 className="text-base font-extrabold text-slate-900 dark:text-white truncate">
                                {form?.title || 'Formulir'} — Analisis & Diagram
                            </h1>
                            <p className="text-xs text-slate-400 dark:text-slate-500">
                                Ringkasan performa & analisis hasil ({respondents.length} / {totalCount || respondents.length} responden dimuat)
                            </p>
                        </div>
                    </div>

                    {/* 3 Export Buttons: XLSX, CSV, PDF */}
                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => handleExport('xlsx')}
                            disabled={exportingFormat !== null}
                            className="px-3 py-1.5 text-xs font-bold rounded-xl border border-emerald-300 dark:border-emerald-800 text-emerald-700 dark:text-emerald-400 bg-emerald-50/70 dark:bg-emerald-950/40 hover:bg-emerald-100 dark:hover:bg-emerald-900/50 flex items-center gap-1.5 transition-all cursor-pointer disabled:opacity-50"
                            title="Export ke Excel (.xlsx)"
                        >
                            <Download size={14} />
                            <span>{exportingFormat === 'xlsx' ? 'Mengunduh...' : 'Export XLSX'}</span>
                        </button>

                        <button
                            onClick={() => handleExport('csv')}
                            disabled={exportingFormat !== null}
                            className="px-3 py-1.5 text-xs font-bold rounded-xl border border-slate-300 dark:border-slate-700 text-slate-700 dark:text-slate-300 bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 flex items-center gap-1.5 transition-all cursor-pointer disabled:opacity-50"
                            title="Export ke CSV (.csv)"
                        >
                            <Download size={14} />
                            <span>{exportingFormat === 'csv' ? 'Mengunduh...' : 'Export CSV'}</span>
                        </button>

                        <button
                            onClick={() => handleExport('pdf')}
                            disabled={exportingFormat !== null}
                            className="px-3 py-1.5 text-xs font-bold rounded-xl border border-red-300 dark:border-red-800 text-red-700 dark:text-red-400 bg-red-50/70 dark:bg-red-950/40 hover:bg-red-100 dark:hover:bg-red-900/50 flex items-center gap-1.5 transition-all cursor-pointer disabled:opacity-50"
                            title="Export ke PDF (.pdf)"
                        >
                            <Download size={14} />
                            <span>{exportingFormat === 'pdf' ? 'Mengunduh...' : 'Export PDF'}</span>
                        </button>
                    </div>
                </div>

                {exportError && (
                    <div className="bg-red-50 dark:bg-red-950/60 border-b border-red-200 dark:border-red-800 px-6 py-2.5 text-xs text-red-600 dark:text-red-400 flex items-center gap-2">
                        <AlertCircle size={15} />
                        <span>{exportError}</span>
                    </div>
                )}

                <div className="p-6 max-w-5xl mx-auto w-full space-y-6">

                    {/* SUMMARY CARDS */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                        {[
                            {
                                label: 'Total Respons',
                                value: analytics?.totalResponses ?? 0,
                                icon: <Users size={18} />,
                                color: 'text-[#00897B] dark:text-teal-400 bg-teal-50 dark:bg-teal-950/60'
                            },
                            {
                                label: 'Total Soal',
                                value: analytics?.totalQuestions ?? 0,
                                icon: <FileText size={18} />,
                                color: 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/60'
                            },
                            {
                                label: 'Soal Dinilai',
                                value: analytics?.scorableQuestions ?? 0,
                                icon: <Award size={18} />,
                                color: 'text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60'
                            },
                            {
                                label: 'Rata-rata Skor',
                                value:
                                    analytics?.averageScore != null
                                        ? `${analytics.averageScore}%`
                                        : 'N/A',
                                icon: <TrendingUp size={18} />,
                                color: 'text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60'
                            }
                        ].map(({ label, value, icon, color }) => (
                            <div
                                key={label}
                                className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 flex items-center gap-3 shadow-xs"
                            >
                                <div className={`p-2.5 rounded-xl ${color}`}>
                                    {icon}
                                </div>

                                <div>
                                    <p className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wide">
                                        {label}
                                    </p>

                                    <p className="text-xl font-extrabold text-slate-900 dark:text-white">
                                        {value}
                                    </p>
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* ── RICH ANALYTICAL DIAGRAMS ── */}
                    {respondents.length > 0 && (
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

                            {/* Diagram 1: Score Grade Distribution */}
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs">
                                <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                                    <div className="flex items-center gap-2">
                                        <BarChart3 size={18} className="text-[#00897B] dark:text-teal-400" />
                                        <h2 className="text-sm font-bold text-slate-900 dark:text-white">Diagram Distribusi Predikat Skor</h2>
                                    </div>
                                    <span className="text-[11px] font-bold text-slate-400 dark:text-slate-500">{gradeDistribution.total} Responden Dinilai</span>
                                </div>

                                <div className="space-y-3">
                                    {[
                                        { grade: 'Sangat Baik (A)', range: '90 - 100%', count: gradeDistribution.A, color: 'bg-emerald-500', bg: 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300' },
                                        { grade: 'Baik (B)', range: '75 - 89%', count: gradeDistribution.B, color: 'bg-teal-500', bg: 'bg-teal-50 dark:bg-teal-950/40 text-teal-700 dark:text-teal-300' },
                                        { grade: 'Cukup (C)', range: '60 - 74%', count: gradeDistribution.C, color: 'bg-blue-500', bg: 'bg-blue-50 dark:bg-blue-950/40 text-blue-700 dark:text-blue-300' },
                                        { grade: 'Kurang (D)', range: '40 - 59%', count: gradeDistribution.D, color: 'bg-amber-500', bg: 'bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300' },
                                        { grade: 'Perlu Remidi (E)', range: '< 40%', count: gradeDistribution.E, color: 'bg-red-500', bg: 'bg-red-50 dark:bg-red-950/40 text-red-700 dark:text-red-300' },
                                    ].map(item => {
                                        const pct = gradeDistribution.total > 0 ? Math.round((item.count / gradeDistribution.total) * 100) : 0;
                                        return (
                                            <div key={item.grade} className="space-y-1">
                                                <div className="flex items-center justify-between text-xs">
                                                    <span className="font-bold text-slate-700 dark:text-slate-300">{item.grade} <span className="text-[10px] text-slate-400 font-normal">({item.range})</span></span>
                                                    <span className="font-extrabold text-slate-800 dark:text-slate-200">{item.count} ({pct}%)</span>
                                                </div>
                                                <div className="w-full h-2.5 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
                                                    <div className={`h-full ${item.color} transition-all duration-500 rounded-full`} style={{ width: `${pct}%` }} />
                                                </div>
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>

                            {/* Diagram 2: Pass/Fail Rate Status */}
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs">
                                <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                                    <div className="flex items-center gap-2">
                                        <Award size={18} className="text-emerald-600 dark:text-emerald-400" />
                                        <h2 className="text-sm font-bold text-slate-900 dark:text-white">Diagram Kriteria Kelulusan (&ge; 70%)</h2>
                                    </div>
                                    <span className="text-[11px] font-bold text-slate-400 dark:text-slate-500">Threshold 70%</span>
                                </div>

                                <div className="space-y-5 pt-1">
                                    {/* Segmented Donut / Progress Bar */}
                                    <div className="space-y-2">
                                        <div className="flex justify-between text-xs font-extrabold">
                                            <span className="text-emerald-600 dark:text-emerald-400 flex items-center gap-1">✓ Lulus: {passRateMetrics.passed} ({passRateMetrics.passPercent}%)</span>
                                            <span className="text-red-500 dark:text-red-400 flex items-center gap-1">✗ Belum Lulus: {passRateMetrics.failed} ({passRateMetrics.failPercent}%)</span>
                                        </div>
                                        <div className="w-full h-4 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden flex">
                                            <div className="bg-emerald-500 h-full transition-all duration-500" style={{ width: `${passRateMetrics.passPercent}%` }} />
                                            <div className="bg-red-400 h-full transition-all duration-500" style={{ width: `${passRateMetrics.failPercent}%` }} />
                                        </div>
                                    </div>

                                    <div className="grid grid-cols-2 gap-3 pt-2">
                                        <div className="p-3 bg-emerald-50/70 dark:bg-emerald-950/40 border border-emerald-100 dark:border-emerald-900/50 rounded-xl space-y-1">
                                            <p className="text-[10px] font-bold uppercase tracking-wider text-emerald-600 dark:text-emerald-400">Responden Lulus</p>
                                            <p className="text-2xl font-black text-emerald-700 dark:text-emerald-300">{passRateMetrics.passed}</p>
                                        </div>
                                        <div className="p-3 bg-red-50/70 dark:bg-red-950/40 border border-red-100 dark:border-red-900/50 rounded-xl space-y-1">
                                            <p className="text-[10px] font-bold uppercase tracking-wider text-red-500 dark:text-red-400">Perlu Pengayaan</p>
                                            <p className="text-2xl font-black text-red-600 dark:text-red-300">{passRateMetrics.failed}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>

                        </div>
                    )}

                    {/* Diagram 3: Question Accuracy & Difficulty Breakdown */}
                    {questionAccuracyMap.length > 0 && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs">
                            <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                                <div className="flex items-center gap-2">
                                    <TrendingUp size={18} className="text-indigo-600 dark:text-indigo-400" />
                                    <h2 className="text-sm font-bold text-slate-900 dark:text-white">Analisis Tingkat Kesukaran & Akurasi Per Soal</h2>
                                </div>
                                <span className="text-[11px] font-bold text-slate-400 dark:text-slate-500">Diurutkan dari Soal Tersulit</span>
                            </div>

                            <div className="space-y-4">
                                {questionAccuracyMap.map((q, idx) => {
                                    const isHardest = idx === 0 && q.accuracy < 60;
                                    const isEasiest = idx === questionAccuracyMap.length - 1 && q.accuracy > 80;

                                    return (
                                        <div key={q.questionId} className="p-3 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200/70 dark:border-slate-700/60 space-y-2">
                                            <div className="flex items-start justify-between gap-3 text-xs">
                                                <div className="flex items-start gap-2 flex-1">
                                                    <RichContentRenderer content={q.question} format={q.questionFormat} className="font-bold text-slate-800 dark:text-slate-100" />
                                                    {isHardest && <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-red-100 text-red-600 dark:bg-red-950 dark:text-red-400 border border-red-200 shrink-0">⚠️ Soal Tersulit</span>}
                                                    {isEasiest && <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-600 dark:bg-emerald-950 dark:text-emerald-400 border border-emerald-200 shrink-0">⭐ Soal Termudah</span>}
                                                </div>
                                                <span className="font-extrabold text-slate-700 dark:text-slate-300 shrink-0">
                                                    Akurasi {q.accuracy}% ({q.correctCount}/{q.totalAttempts})
                                                </span>
                                            </div>
                                            <div className="w-full h-2 bg-slate-200 dark:bg-slate-700 rounded-full overflow-hidden">
                                                <div
                                                    className={`h-full transition-all duration-500 rounded-full ${q.accuracy >= 75 ? 'bg-emerald-500' : q.accuracy >= 50 ? 'bg-amber-500' : 'bg-red-500'}`}
                                                    style={{ width: `${q.accuracy}%` }}
                                                />
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    {/* RESPONDENTS TABLE */}
                    {respondents.length > 0 ? (
                        <div className="space-y-4">
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-xs">
                                <div className="p-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
                                    <div>
                                        <h2 className="text-sm font-bold text-slate-900 dark:text-white">
                                            Rincian Responden
                                        </h2>
                                        <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                            Klik Review Jawaban untuk melihat jawaban lengkap.
                                        </p>
                                    </div>
                                </div>

                                <div className="overflow-x-auto w-full">
                                    <table className="w-full text-sm text-left">
                                        <thead>
                                            <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                                <th className="py-3 px-4">#</th>
                                                <th className="py-3 px-4">Responden</th>
                                                <th className="py-3 px-4">Dijawab</th>
                                                <th className="py-3 px-4">Benar</th>
                                                <th className="py-3 px-4">Skor</th>
                                                <th className="py-3 px-4">Waktu Submit</th>
                                                <th className="py-3 px-4 text-right">Aksi</th>
                                            </tr>
                                        </thead>

                                        <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                            {respondents.map((r, i) => (
                                                <tr
                                                    key={r.responseId}
                                                    className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors"
                                                >
                                                    <td className="py-3.5 px-4 text-slate-400">
                                                        {i + 1}
                                                    </td>

                                                    <td className="py-3.5 px-4">
                                                        <div className="font-bold text-slate-900 dark:text-white">
                                                            {r.respondentName || 'Anonim'}
                                                        </div>
                                                        <div className="text-[10px] text-slate-400 dark:text-slate-500">
                                                            Respons #{r.responseId}
                                                        </div>
                                                    </td>

                                                    <td className="py-3.5 px-4 text-slate-600 dark:text-slate-300 font-medium">
                                                        {r.answeredCount}/{r.totalQuestions}
                                                    </td>

                                                    <td className="py-3.5 px-4 text-slate-600 dark:text-slate-300 font-medium">
                                                        {r.correctCount}/{r.scorableQuestions}
                                                    </td>

                                                    <td className="py-3.5 px-4">
                                                        {r.score != null ? (
                                                            <span
                                                                className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                                                                    r.score >= 70
                                                                        ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800'
                                                                        : 'bg-red-50 text-red-600 dark:bg-red-950/60 dark:text-red-400 border border-red-200 dark:border-red-800'
                                                                }`}
                                                            >
                                                                {r.score}%
                                                            </span>
                                                        ) : (
                                                            <span className="text-slate-400 dark:text-slate-500 text-xs">
                                                                N/A
                                                            </span>
                                                        )}
                                                    </td>

                                                    <td className="py-3.5 px-4 text-slate-500 dark:text-slate-400 text-xs">
                                                        {r.submittedAt
                                                            ? new Date(r.submittedAt).toLocaleDateString('id-ID', {
                                                                  day: '2-digit',
                                                                  month: 'short',
                                                                  year: 'numeric'
                                                              })
                                                            : '-'}
                                                    </td>

                                                    <td className="py-3.5 px-4 text-right">
                                                        <button
                                                            onClick={() => setSelectedRespondent(r)}
                                                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold shadow-xs transition-all cursor-pointer"
                                                        >
                                                            <Eye size={13} /> Review Jawaban
                                                        </button>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            </div>

                            {/* Load More Button */}
                            {hasMore && (
                                <div className="text-center pt-2">
                                    <button
                                        onClick={handleLoadMore}
                                        disabled={loadingMore}
                                        className="px-5 py-2.5 bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-200 text-xs font-bold rounded-xl shadow-xs transition-all flex items-center justify-center gap-2 mx-auto disabled:opacity-60 cursor-pointer"
                                    >
                                        {loadingMore ? (
                                            <>
                                                <Loader2 size={14} className="animate-spin text-[#00897B] dark:text-teal-400" />
                                                Memuat responden...
                                            </>
                                        ) : (
                                            `Muat Lebih Banyak (${respondents.length} dari ${totalCount || 'banyak'})`
                                        )}
                                    </button>
                                </div>
                            )}
                        </div>
                    ) : (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-12 text-center text-slate-400 dark:text-slate-500 text-sm font-medium shadow-xs">
                            Belum ada respons yang masuk untuk formulir ini.
                        </div>
                    )}

                </div>
            </div>

            {/* Respondent Detail Modal */}
            {selectedRespondent && (
                <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4">
                    <div className="bg-white dark:bg-slate-900 rounded-2xl shadow-xl w-full max-w-2xl max-h-[85vh] flex flex-col border border-slate-200/80 dark:border-slate-800">
                        {/* Header */}
                        <div className="flex items-center justify-between p-4 border-b border-slate-100 dark:border-slate-800">
                            <div>
                                <h3 className="font-bold text-slate-900 dark:text-white text-sm">
                                    Detail Respons — {selectedRespondent.respondentName || 'Anonim'}
                                </h3>
                                <p className="text-[11px] text-slate-400 dark:text-slate-500">
                                    Respons #{selectedRespondent.responseId} • Skor: {selectedRespondent.score != null ? `${selectedRespondent.score}%` : 'N/A'}
                                </p>
                            </div>

                            <div className="flex items-center gap-2">
                                <button
                                    onClick={goPrevious}
                                    disabled={currentIndex <= 0}
                                    className="p-1.5 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-300 disabled:opacity-30 cursor-pointer"
                                    title="Sebelumnya"
                                >
                                    <ChevronLeft size={16} />
                                </button>
                                <button
                                    onClick={goNext}
                                    disabled={currentIndex >= respondents.length - 1}
                                    className="p-1.5 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-300 disabled:opacity-30 cursor-pointer"
                                    title="Berikutnya"
                                >
                                    <ChevronRight size={16} />
                                </button>

                                <button
                                    onClick={() => setSelectedRespondent(null)}
                                    className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-xl cursor-pointer"
                                >
                                    <X size={18} />
                                </button>
                            </div>
                        </div>

                        {/* Content */}
                        <div className="overflow-y-auto p-4 space-y-4 flex-1">
                            <div className="grid grid-cols-3 gap-3 bg-slate-50 dark:bg-slate-800/60 p-3 rounded-xl text-center text-xs">
                                <div>
                                    <p className="text-slate-400 dark:text-slate-500 font-bold uppercase text-[10px]">Dijawab</p>
                                    <p className="font-extrabold text-slate-800 dark:text-slate-200 text-sm mt-0.5">{selectedRespondent.answeredCount}/{selectedRespondent.totalQuestions}</p>
                                </div>
                                <div>
                                    <p className="text-slate-400 dark:text-slate-500 font-bold uppercase text-[10px]">Benar</p>
                                    <p className="font-extrabold text-slate-800 dark:text-slate-200 text-sm mt-0.5">{selectedRespondent.correctCount}/{selectedRespondent.scorableQuestions}</p>
                                </div>
                                <div>
                                    <p className="text-slate-400 dark:text-slate-500 font-bold uppercase text-[10px]">Skor</p>
                                    <p className="font-extrabold text-[#00897B] dark:text-teal-400 text-sm mt-0.5">{selectedRespondent.score != null ? `${selectedRespondent.score}%` : 'N/A'}</p>
                                </div>
                            </div>

                            <div className="space-y-3">
                                {selectedRespondent.answers?.map((a, i) => {
                                    const status = getAnswerStatus(a);

                                    return (
                                        <div
                                            key={i}
                                            className="bg-slate-50 dark:bg-slate-800/40 rounded-xl p-4 border border-slate-200/60 dark:border-slate-700/60 space-y-2"
                                        >
                                            <div className="flex items-start justify-between gap-2">
                                                <div className="flex items-start gap-2 flex-1">
                                                    <span className="font-bold text-slate-400 text-xs">{i + 1}.</span>
                                                    <RichContentRenderer content={a.question} format={a.questionFormat} className="text-xs font-bold text-slate-800 dark:text-slate-200" />
                                                </div>

                                                <span className={`inline-flex items-center gap-1 text-[10px] font-bold px-2.5 py-0.5 rounded-full border shrink-0 ${status.className}`}>
                                                    {status.icon} {status.label}
                                                </span>
                                            </div>

                                            <div className="pl-4 space-y-1 text-xs">
                                                <div className="flex items-baseline gap-2">
                                                    <span className="text-slate-400 dark:text-slate-500 font-medium">Jawaban:</span>
                                                    <RichContentRenderer content={a.optionText || a.answerText || '—'} format="text" className="font-bold text-slate-800 dark:text-slate-100" />
                                                </div>

                                                {a.correctAnswer && (
                                                    <div className="flex items-baseline gap-2 text-emerald-600 dark:text-emerald-400">
                                                        <span className="font-medium">Kunci:</span>
                                                        <RichContentRenderer content={a.correctAnswer} format="text" className="font-bold" />
                                                    </div>
                                                )}
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}