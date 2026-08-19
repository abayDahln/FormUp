import { useState, useEffect, useCallback } from 'react';
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
    Loader2
} from 'lucide-react';

import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById,
    getFormAnalytics,
    clearSession
} from '../../services/apiService';

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
                <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-6 py-4 flex items-center gap-3">
                    <button
                        onClick={() => navigate(`/forms/${id}/responses`)}
                        className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all"
                    >
                        <ArrowLeft size={18} />
                    </button>

                    <div className="min-w-0">
                        <h1 className="text-base font-extrabold text-slate-900 dark:text-white truncate">
                            {form?.title || 'Formulir'} — Analisis
                        </h1>
                        <p className="text-xs text-slate-400 dark:text-slate-500">
                            Ringkasan performa respons ({respondents.length} / {totalCount || respondents.length} responden dimuat)
                        </p>
                    </div>
                </div>

                <div className="p-6 max-w-5xl mx-auto w-full space-y-6">

                    {/* SUMMARY */}
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

                    {/* RESPONDENTS */}
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
                                        className="px-5 py-2.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 hover:bg-slate-50 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-200 text-xs font-bold rounded-xl shadow-xs transition-all flex items-center justify-center gap-2 mx-auto disabled:opacity-60 cursor-pointer"
                                    >
                                        {loadingMore ? (
                                            <><Loader2 size={14} className="animate-spin text-[#00897B] dark:text-teal-400" /> Memuat responden...</>
                                        ) : (
                                            `Muat Lebih Banyak (${respondents.length} dari ${totalCount || 'banyak'})`
                                        )}
                                    </button>
                                </div>
                            )}
                        </div>
                    ) : (
                        <div className="text-center py-20 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 text-slate-400 dark:text-slate-500 text-sm font-medium">
                            Belum ada respons untuk dianalisis.
                        </div>
                    )}
                </div>
            </div>

            {/* REVIEW MODAL */}
            {selectedRespondent && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-black/50 backdrop-blur-xs"
                        onClick={() => setSelectedRespondent(null)}
                    />

                    <div className="relative bg-white dark:bg-slate-900 w-full max-w-3xl max-h-[90vh] rounded-3xl shadow-2xl flex flex-col overflow-hidden border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 animate-in fade-in zoom-in-95 duration-200">

                        {/* Modal Header */}
                        <div className="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between shrink-0 bg-slate-50/50 dark:bg-slate-800/50">
                            <div>
                                <h2 className="font-bold text-slate-900 dark:text-white text-base">
                                    Review Jawaban Responden
                                </h2>
                                <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                    {selectedRespondent.respondentName || 'Anonim'} (Respons #{selectedRespondent.responseId})
                                </p>
                            </div>

                            <button
                                onClick={() => setSelectedRespondent(null)}
                                className="p-2 rounded-xl text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {/* Score Summary */}
                        <div className="px-6 py-3.5 bg-slate-100/60 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 flex flex-wrap items-center gap-3">
                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">
                                    Skor
                                </p>
                                <p className="text-base font-extrabold text-slate-900 dark:text-white">
                                    {selectedRespondent.score != null
                                        ? `${selectedRespondent.score}%`
                                        : 'N/A'}
                                </p>
                            </div>

                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">
                                    Dijawab
                                </p>
                                <p className="text-base font-extrabold text-slate-900 dark:text-white">
                                    {selectedRespondent.answeredCount}/
                                    {selectedRespondent.totalQuestions}
                                </p>
                            </div>

                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">
                                    Benar
                                </p>
                                <p className="text-base font-extrabold text-emerald-600 dark:text-emerald-400">
                                    {selectedRespondent.correctCount}/
                                    {selectedRespondent.scorableQuestions}
                                </p>
                            </div>
                        </div>

                        {/* Answers */}
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
                                                    <p className="text-sm font-semibold text-slate-900 dark:text-white leading-relaxed">
                                                        {answer.question}
                                                    </p>
                                                </div>
                                            </div>
                                            <div className={`shrink-0 flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[11px] font-bold ${status.className}`}>
                                                {status.icon}
                                                <span>{status.label}</span>
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
                                                    {answer.answerText || answer.answerValue || answer.optionText || (
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
                                                        {answer.correctAnswer}
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

                        {/* Footer navigation */}
                        <div className="px-6 py-3 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between shrink-0">
                            <button
                                onClick={goPrevious}
                                disabled={currentIndex <= 0}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                            >
                                <ChevronLeft size={15} /> Sebelumnya
                            </button>

                            <span className="text-xs text-slate-400 dark:text-slate-500 font-semibold">
                                {currentIndex + 1} dari {respondents.length}
                            </span>

                            <button
                                onClick={goNext}
                                disabled={currentIndex === respondents.length - 1}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                            >
                                Selanjutnya <ChevronRight size={15} />
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}