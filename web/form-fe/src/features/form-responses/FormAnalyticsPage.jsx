import { useState, useEffect } from 'react';
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
    ChevronRight
} from 'lucide-react';

import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById,
    getFormAnalytics,
    clearSession
} from '../../services/apiService';

export default function FormAnalyticsPage() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [form, setForm] = useState(null);
    const [analytics, setAnalytics] = useState(null);
    const [loading, setLoading] = useState(true);

    // Responden yang sedang direview
    const [selectedRespondent, setSelectedRespondent] = useState(null);

    useEffect(() => {
        const load = async () => {
            setLoading(true);

            try {
                const [formRes, analyticsRes] = await Promise.all([
                    getFormById(id),
                    getFormAnalytics(id)
                ]);

                if (formRes.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (formRes.ok) {
                    setForm(formRes.data);
                }

                if (analyticsRes.ok) {
                    setAnalytics(analyticsRes.data);
                }
            } catch (error) {
                console.error('Failed to load analytics:', error);
            } finally {
                setLoading(false);
            }
        };

        load();
    }, [id, navigate]);

    if (loading) {
        return (
            <div className="flex items-center justify-center min-h-screen bg-slate-50">
                <p className="text-slate-400">Loading analytics...</p>
            </div>
        );
    }

    const respondents = analytics?.respondents || [];

    const currentIndex = selectedRespondent
        ? respondents.findIndex(
              r => r.responseId === selectedRespondent.responseId
          )
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
                label: 'Correct',
                icon: <CheckCircle2 size={16} />,
                className: 'text-emerald-600 bg-emerald-50 border-emerald-200'
            };
        }

        if (answer.isCorrect === false) {
            return {
                label: 'Incorrect',
                icon: <XCircle size={16} />,
                className: 'text-red-600 bg-red-50 border-red-200'
            };
        }

        return {
            label: 'Not graded',
            icon: <MinusCircle size={16} />,
            className: 'text-slate-500 bg-slate-50 border-slate-200'
        };
    };

    const formatAnswer = (answer) => {
        if (
            answer.answerText === null ||
            answer.answerText === undefined ||
            answer.answerText === ''
        ) {
            return 'No answer';
        }

        return answer.answerText;
    };

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">

                {/* Header */}
                <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center gap-3">
                    <button
                        onClick={() => navigate(`/forms/${id}/responses`)}
                        className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg"
                    >
                        <ArrowLeft size={18} />
                    </button>

                    <div className="min-w-0">
                        <h1 className="text-sm font-bold text-slate-800 truncate">
                            {form?.title || 'Form'} — Analytics
                        </h1>

                        <p className="text-[11px] text-slate-400">
                            Response performance overview
                        </p>
                    </div>
                </div>

                <div className="p-6 max-w-5xl mx-auto w-full space-y-6">

                    {/* SUMMARY */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                        {[
                            {
                                label: 'Total Responses',
                                value: analytics?.totalResponses ?? 0,
                                icon: <Users size={18} />,
                                color: 'text-teal-600 bg-teal-50'
                            },
                            {
                                label: 'Total Questions',
                                value: analytics?.totalQuestions ?? 0,
                                icon: <FileText size={18} />,
                                color: 'text-blue-600 bg-blue-50'
                            },
                            {
                                label: 'Scorable Q\'s',
                                value: analytics?.scorableQuestions ?? 0,
                                icon: <Award size={18} />,
                                color: 'text-indigo-600 bg-indigo-50'
                            },
                            {
                                label: 'Avg Score',
                                value:
                                    analytics?.averageScore != null
                                        ? `${analytics.averageScore}%`
                                        : 'N/A',
                                icon: <TrendingUp size={18} />,
                                color: 'text-emerald-600 bg-emerald-50'
                            }
                        ].map(({ label, value, icon, color }) => (
                            <div
                                key={label}
                                className="bg-white rounded-xl border border-slate-100 p-4 flex items-center gap-3"
                            >
                                <div className={`p-2 rounded-lg ${color}`}>
                                    {icon}
                                </div>

                                <div>
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">
                                        {label}
                                    </p>

                                    <p className="text-xl font-extrabold text-slate-800">
                                        {value}
                                    </p>
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* RESPONDENTS */}
                    {respondents.length > 0 ? (
                        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">

                            <div className="p-4 border-b border-slate-100 flex items-center justify-between">
                                <div>
                                    <h2 className="text-sm font-bold text-slate-700">
                                        Respondent Breakdown
                                    </h2>

                                    <p className="text-xs text-slate-400 mt-1">
                                        Klik Review Answers untuk melihat jawaban lengkap.
                                    </p>
                                </div>
                            </div>

                            <div className="overflow-x-auto">
                                <table className="w-full text-sm text-left">

                                    <thead>
                                        <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                            <th className="py-3 px-4">#</th>
                                            <th className="py-3 px-4">Respondent</th>
                                            <th className="py-3 px-4">Answered</th>
                                            <th className="py-3 px-4">Correct</th>
                                            <th className="py-3 px-4">Score</th>
                                            <th className="py-3 px-4">Submitted</th>
                                            <th className="py-3 px-4 text-right">
                                                Action
                                            </th>
                                        </tr>
                                    </thead>

                                    <tbody className="divide-y divide-slate-100">

                                        {respondents.map((r, i) => (
                                            <tr
                                                key={r.responseId}
                                                className="hover:bg-slate-50"
                                            >
                                                <td className="py-3 px-4 text-slate-400">
                                                    {i + 1}
                                                </td>

                                                <td className="py-3 px-4">
                                                    <div className="font-semibold text-slate-800">
                                                        {r.respondentName || 'Anonymous'}
                                                    </div>

                                                    <div className="text-[10px] text-slate-400">
                                                        Response #{r.responseId}
                                                    </div>
                                                </td>

                                                <td className="py-3 px-4 text-slate-600">
                                                    {r.answeredCount}/{r.totalQuestions}
                                                </td>

                                                <td className="py-3 px-4 text-slate-600">
                                                    {r.correctCount}/{r.scorableQuestions}
                                                </td>

                                                <td className="py-3 px-4">
                                                    {r.score != null ? (
                                                        <span
                                                            className={`text-xs font-bold px-2 py-0.5 rounded-full ${
                                                                r.score >= 70
                                                                    ? 'bg-emerald-50 text-emerald-600'
                                                                    : 'bg-red-50 text-red-600'
                                                            }`}
                                                        >
                                                            {r.score}%
                                                        </span>
                                                    ) : (
                                                        <span className="text-slate-400 text-xs">
                                                            N/A
                                                        </span>
                                                    )}
                                                </td>

                                                <td className="py-3 px-4 text-slate-500 text-xs">
                                                    {r.submittedAt
                                                        ? new Date(
                                                              r.submittedAt
                                                          ).toLocaleDateString(
                                                              'id-ID',
                                                              {
                                                                  day: '2-digit',
                                                                  month: 'short',
                                                                  year: 'numeric'
                                                              }
                                                          )
                                                        : '-'}
                                                </td>

                                                <td className="py-3 px-4 text-right">
                                                    <button
                                                        onClick={() =>
                                                            setSelectedRespondent(r)
                                                        }
                                                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 text-white text-xs font-semibold hover:bg-slate-900 transition-colors"
                                                    >
                                                        <Eye size={13} />
                                                        Review Answers
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}

                                    </tbody>
                                </table>
                            </div>
                        </div>
                    ) : (
                        <div className="text-center py-16 text-slate-400 text-sm">
                            No responses to analyze yet.
                        </div>
                    )}
                </div>
            </div>

            {/* REVIEW MODAL */}
            {selectedRespondent && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">

                    {/* Overlay */}
                    <div
                        className="absolute inset-0 bg-black/40 backdrop-blur-[2px]"
                        onClick={() => setSelectedRespondent(null)}
                    />

                    {/* Modal */}
                    <div className="relative bg-white w-full max-w-3xl max-h-[90vh] rounded-2xl shadow-2xl flex flex-col overflow-hidden">

                        {/* Modal Header */}
                        <div className="px-6 py-4 border-b border-slate-200 flex items-center justify-between shrink-0">

                            <div className="min-w-0">
                                <h2 className="font-bold text-slate-800">
                                    Review Answers
                                </h2>

                                <p className="text-xs text-slate-400 mt-0.5">
                                    {selectedRespondent.respondentName ||
                                        'Anonymous'}
                                </p>
                            </div>

                            <button
                                onClick={() => setSelectedRespondent(null)}
                                className="p-2 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {/* Score Summary */}
                        <div className="px-6 py-4 bg-slate-50 border-b border-slate-200">
                            <div className="flex flex-wrap items-center gap-3">

                                <div className="bg-white border border-slate-200 rounded-lg px-4 py-2">
                                    <p className="text-[10px] uppercase font-bold text-slate-400">
                                        Score
                                    </p>

                                    <p className="text-lg font-extrabold text-slate-800">
                                        {selectedRespondent.score != null
                                            ? `${selectedRespondent.score}%`
                                            : 'N/A'}
                                    </p>
                                </div>

                                <div className="bg-white border border-slate-200 rounded-lg px-4 py-2">
                                    <p className="text-[10px] uppercase font-bold text-slate-400">
                                        Answered
                                    </p>

                                    <p className="text-lg font-extrabold text-slate-800">
                                        {selectedRespondent.answeredCount}/
                                        {selectedRespondent.totalQuestions}
                                    </p>
                                </div>

                                <div className="bg-white border border-slate-200 rounded-lg px-4 py-2">
                                    <p className="text-[10px] uppercase font-bold text-slate-400">
                                        Correct
                                    </p>

                                    <p className="text-lg font-extrabold text-slate-800">
                                        {selectedRespondent.correctCount}/
                                        {selectedRespondent.scorableQuestions}
                                    </p>
                                </div>

                            </div>
                        </div>

                        {/* Answers */}
                        <div className="flex-1 overflow-y-auto p-6 space-y-4">

                            {(selectedRespondent.answers || []).map(
                                (answer, index) => {

                                    const status = getAnswerStatus(answer);

                                    return (
                                        <div
                                            key={answer.questionId || index}
                                            className="border border-slate-200 rounded-xl overflow-hidden"
                                        >

                                            {/* Question */}
                                            <div className="p-4 bg-white">
                                                <div className="flex items-start gap-3">

                                                    <span className="shrink-0 w-7 h-7 flex items-center justify-center rounded-lg bg-slate-100 text-xs font-bold text-slate-500">
                                                        {index + 1}
                                                    </span>

                                                    <div className="flex-1 min-w-0">

                                                        <p className="text-sm font-semibold text-slate-800 leading-relaxed">
                                                            {answer.question}
                                                        </p>

                                                        <span className="inline-block mt-2 text-[10px] px-2 py-0.5 rounded bg-slate-100 text-slate-500">
                                                            Type ID: {answer.typeId}
                                                        </span>

                                                    </div>

                                                    {/* Status */}
                                                    <div
                                                        className={`shrink-0 flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[11px] font-bold ${status.className}`}
                                                    >
                                                        {status.icon}
                                                        {status.label}
                                                    </div>

                                                </div>
                                            </div>

                                            {/* Answer */}
                                            <div className="border-t border-slate-100 p-4 space-y-3 bg-slate-50">

                                                <div>
                                                    <p className="text-[10px] uppercase tracking-wide font-bold text-slate-400 mb-1">
                                                        Respondent's Answer
                                                    </p>

                                                    <div
                                                        className={`rounded-lg border p-3 text-sm ${
                                                            answer.isCorrect === true
                                                                ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                                                                : answer.isCorrect === false
                                                                ? 'bg-red-50 border-red-200 text-red-800'
                                                                : 'bg-white border-slate-200 text-slate-700'
                                                        }`}
                                                    >
                                                        {formatAnswer(answer)}
                                                    </div>
                                                </div>

                                                {/* Correct Answer */}
                                                {answer.correctAnswer !== null &&
                                                    answer.correctAnswer !==
                                                        undefined &&
                                                    answer.correctAnswer !== '' && (
                                                        <div>
                                                            <p className="text-[10px] uppercase tracking-wide font-bold text-slate-400 mb-1">
                                                                Correct Answer
                                                            </p>

                                                            <div className="rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-800">
                                                                {answer.correctAnswer}
                                                            </div>
                                                        </div>
                                                    )}

                                                {/* Not graded */}
                                                {answer.correctAnswer == null && (
                                                    <div className="text-xs text-slate-400 italic">
                                                        This question has no
                                                        correct answer and is
                                                        not automatically graded.
                                                    </div>
                                                )}

                                            </div>
                                        </div>
                                    );
                                }
                            )}

                            {(!selectedRespondent.answers ||
                                selectedRespondent.answers.length === 0) && (
                                <div className="text-center py-12 text-sm text-slate-400">
                                    No answer details available.
                                </div>
                            )}

                        </div>

                        {/* Footer navigation */}
                        <div className="px-6 py-3 border-t border-slate-200 bg-white flex items-center justify-between shrink-0">

                            <button
                                onClick={goPrevious}
                                disabled={currentIndex <= 0}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-lg border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                            >
                                <ChevronLeft size={15} />
                                Previous
                            </button>

                            <span className="text-xs text-slate-400">
                                {currentIndex + 1} / {respondents.length}
                            </span>

                            <button
                                onClick={goNext}
                                disabled={
                                    currentIndex === respondents.length - 1
                                }
                                className="flex items-center gap-1.5 px-3 py-2 rounded-lg border border-slate-200 text-xs font-semibold text-slate-600 hover:bg-slate-50 disabled:opacity-40 disabled:cursor-not-allowed"
                            >
                                Next
                                <ChevronRight size={15} />
                            </button>

                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}