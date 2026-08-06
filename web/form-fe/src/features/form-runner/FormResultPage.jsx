import { useState, useEffect } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { CheckCircle2, XCircle, Award, MessageSquare, ArrowLeft, Send } from 'lucide-react';
import { getPublicResponseResult, submitFeedback, assetUrl, isAuthenticated } from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function FormResultPage() {
    const { formLink, responseId } = useParams();
    const [searchParams] = useSearchParams();
    const navigate = useNavigate();

    const guestToken = searchParams.get('token') || localStorage.getItem(`guestToken_${formLink}`);

    const [loading, setLoading] = useState(true);
    const [result, setResult] = useState(null);
    const [error, setError] = useState(null);

    // Feedback Modal State
    const [showFeedbackModal, setShowFeedbackModal] = useState(false);
    const [feedbackReason, setFeedbackReason] = useState('Feedback');
    const [feedbackDesc, setFeedbackDesc] = useState('');
    const [feedbackSubmitting, setFeedbackSubmitting] = useState(false);
    const [feedbackSuccess, setFeedbackSuccess] = useState(false);

    useEffect(() => {
        const loadResult = async () => {
            setLoading(true);
            const res = await getPublicResponseResult(formLink, responseId, guestToken);
            if (res.ok && res.data) {
                setResult(res.data);
            } else {
                setError(res.message || 'Failed to load response result');
            }
            setLoading(false);
        };
        loadResult();
    }, [formLink, responseId, guestToken]);

    const handleSendFeedback = async (e) => {
        e.preventDefault();
        if (!result?.formId) return;
        setFeedbackSubmitting(true);
        const res = await submitFeedback(result.formId, {
            reason: feedbackReason,
            description: feedbackDesc,
        });
        setFeedbackSubmitting(false);
        if (res.ok) {
            setFeedbackSuccess(true);
            setTimeout(() => {
                setShowFeedbackModal(false);
                setFeedbackSuccess(false);
            }, 2000);
        } else {
            alert(res.message || 'Failed to submit feedback');
        }
    };

    if (loading) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <p className="text-slate-400 text-sm font-medium">Loading result...</p>
        </div>
    );

    if (error || !result) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl border border-slate-200 p-8 max-w-md w-full text-center space-y-3 shadow-xs">
                <div className="text-3xl">⚠️</div>
                <h2 className="text-lg font-bold text-slate-800">Result Unavailable</h2>
                <p className="text-xs text-slate-500">{error || 'Response not found'}</p>
                <button onClick={() => navigate(`/f/${formLink}`)} className="mt-4 px-4 py-2 bg-teal-600 text-white font-bold rounded-xl text-xs">
                    Return to Form
                </button>
            </div>
        </div>
    );

    const { formTitle, showScore, score, correctCount, wrongCount, totalQuestions, answers } = result;

    return (
        <div className="min-h-screen bg-slate-50 py-8 px-4 font-sans text-slate-800">
            <div className="max-w-2xl mx-auto space-y-5">
                
                {/* Result Card */}
                <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs text-center space-y-4">
                    <div className="w-12 h-12 bg-teal-50 text-teal-600 rounded-full flex items-center justify-center mx-auto">
                        <Award size={24} />
                    </div>

                    <div>
                        <h1 className="text-xl font-extrabold text-slate-900">{formTitle}</h1>
                        <p className="text-xs text-slate-400 mt-0.5">Submission Summary</p>
                    </div>

                    {showScore && score !== null && (
                        <div className="bg-slate-900 text-white rounded-xl p-5 shadow-sm space-y-1">
                            <p className="text-xs text-slate-400 font-bold uppercase tracking-wider">Your Score</p>
                            <h2 className="text-4xl font-extrabold text-teal-400">{score}%</h2>
                            <div className="flex justify-center items-center gap-4 pt-2 text-xs font-bold text-slate-300">
                                <span className="text-emerald-400">✓ {correctCount} Correct</span>
                                <span className="text-red-400">✕ {wrongCount} Wrong</span>
                                <span className="text-slate-400">Total: {totalQuestions} Questions</span>
                            </div>
                        </div>
                    )}

                    <div className="flex justify-center gap-3 pt-2">
                        <button
                            onClick={() => navigate(`/f/${formLink}`)}
                            className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl flex items-center gap-1.5"
                        >
                            <ArrowLeft size={14} /> Back to Form
                        </button>
                        {isAuthenticated() && (
                            <button
                                onClick={() => setShowFeedbackModal(true)}
                                className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-xs"
                            >
                                <MessageSquare size={14} /> Send Feedback
                            </button>
                        )}
                    </div>
                </div>

                {/* Question Answers Breakdown */}
                <div className="space-y-3">
                    <h3 className="text-xs font-extrabold text-slate-500 uppercase tracking-wider px-1">Answer Breakdown</h3>
                    {answers?.map((ans, idx) => (
                        <div key={idx} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-xs space-y-2">
                            <div className="flex items-start justify-between gap-3">
                                <div className="text-xs font-bold text-slate-900 flex-1">
                                    <span className="text-slate-400 mr-1.5">{idx + 1}.</span>
                                    <RichContentRenderer content={ans.question} format={ans.questionFormat} className="inline text-xs font-bold" />
                                </div>
                                {showScore && ans.isCorrect !== undefined && (
                                    <span className="shrink-0">
                                        {ans.isCorrect ? (
                                            <CheckCircle2 size={18} className="text-emerald-500" />
                                        ) : (
                                            <XCircle size={18} className="text-red-500" />
                                        )}
                                    </span>
                                )}
                            </div>

                            <div className="bg-slate-50 rounded-xl p-3 text-xs space-y-1">
                                <p className="font-semibold text-slate-700">
                                    <span className="text-slate-400 mr-1">Your Answer:</span>
                                    {ans.answerText || <span className="text-slate-400 italic">No answer</span>}
                                </p>

                                {showScore && !ans.isCorrect && ans.correctAnswer && (
                                    <p className="text-emerald-600 font-bold pt-1 border-t border-slate-200/60">
                                        Correct Answer: {ans.correctAnswer}
                                    </p>
                                )}
                            </div>
                        </div>
                    ))}
                </div>

            </div>

            {/* Feedback Modal */}
            {showFeedbackModal && (
                <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
                    <div className="bg-white rounded-2xl border border-slate-200 shadow-xl max-w-md w-full p-6 space-y-4">
                        <div className="flex justify-between items-center border-b border-slate-100 pb-3">
                            <h3 className="text-sm font-extrabold text-slate-800">Submit Form Feedback</h3>
                            <button onClick={() => setShowFeedbackModal(false)} className="text-slate-400 hover:text-slate-600 text-sm">✕</button>
                        </div>

                        {feedbackSuccess ? (
                            <div className="text-center py-6 text-emerald-600 space-y-1">
                                <p className="text-2xl">🎉</p>
                                <p className="font-bold text-sm">Thank you for your feedback!</p>
                            </div>
                        ) : (
                            <form onSubmit={handleSendFeedback} className="space-y-4">
                                <div>
                                    <label className="text-xs font-bold text-slate-700 block mb-1">Reason</label>
                                    <select
                                        value={feedbackReason}
                                        onChange={e => setFeedbackReason(e.target.value)}
                                        className="w-full border border-slate-200 rounded-xl px-3 py-2 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-teal-400"
                                    >
                                        <option value="Feedback">General Feedback</option>
                                        <option value="Inappropriate Content">Inappropriate Content</option>
                                        <option value="Misleading Information">Misleading Information</option>
                                        <option value="Bug / Technical Issue">Bug / Technical Issue</option>
                                    </select>
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-700 block mb-1">Description</label>
                                    <textarea
                                        required
                                        rows={3}
                                        value={feedbackDesc}
                                        onChange={e => setFeedbackDesc(e.target.value)}
                                        placeholder="Describe your feedback or issues..."
                                        className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400 resize-none"
                                    />
                                </div>

                                <button
                                    type="submit"
                                    disabled={feedbackSubmitting}
                                    className="w-full py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-bold text-xs rounded-xl flex items-center justify-center gap-1.5 shadow-sm disabled:opacity-60"
                                >
                                    <Send size={14} /> {feedbackSubmitting ? 'Sending...' : 'Send Feedback'}
                                </button>
                            </form>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
