import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Clock, Lock, AlertCircle, ArrowLeft, Send, CheckCircle2, User, Key } from 'lucide-react';
import {
    getPublicFormByLink,
    getPublicFormQuestions,
    submitPublicFormResponse,
    assetUrl,
    isAuthenticated,
    getLocalUser
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function FormRunnerPage() {
    const { formLink } = useParams();
    const navigate = useNavigate();

    // Step 1 State: Form metadata
    const [metaLoading, setMetaLoading] = useState(true);
    const [formMeta, setFormMeta] = useState(null);
    const [gateError, setGateError] = useState(null);

    // Inputs for requirements
    const [tokenInput, setTokenInput] = useState('');
    const [guestName, setGuestName] = useState(() => getLocalUser().fullname || '');
    const [needsToken, setNeedsToken] = useState(false);
    const [needsLogin, setNeedsLogin] = useState(false);

    // Step 2 State: Questions
    const [questionsLoading, setQuestionsLoading] = useState(false);
    const [questions, setQuestions] = useState([]);

    // Answers & Submission
    const [answers, setAnswers] = useState({});
    const [submitting, setSubmitting] = useState(false);
    const [submitError, setSubmitError] = useState(null);

    // Timer state
    const [timeLeft, setTimeLeft] = useState(null);
    const timerRef = useRef(null);

    // ── Step 1: Load Form Metadata ──────────────────────────────────────────────
    useEffect(() => {
        const loadMeta = async () => {
            setMetaLoading(true);
            setGateError(null);
            const res = await getPublicFormByLink(formLink);

            if (res.ok && res.data) {
                setFormMeta(res.data);

                // Check Gates
                if (res.data.requiresLogin && !isAuthenticated()) {
                    setNeedsLogin(true);
                    setMetaLoading(false);
                    return;
                }

                if (res.data.requiresToken) {
                    setNeedsToken(true);
                    setMetaLoading(false);
                    return;
                }

                // If no token/login gate, load questions immediately
                fetchQuestions(res.data);
            } else {
                setGateError({
                    status: res.status,
                    message: res.message || 'Form tidak ditemukan atau tidak tersedia.',
                });
                setMetaLoading(false);
            }
        };

        loadMeta();
    }, [formLink]);

    // ── Step 2: Fetch Questions ────────────────────────────────────────────────
    const fetchQuestions = async (meta, token = tokenInput, name = guestName) => {
        setQuestionsLoading(true);
        setSubmitError(null);

        const res = await getPublicFormQuestions(formLink, { token, name });
        setQuestionsLoading(false);
        setMetaLoading(false);

        if (res.ok && res.data?.questions) {
            setQuestions(res.data.questions);
            setNeedsToken(false);
            setNeedsLogin(false);

            // Initialize Timer if configured
            if (meta?.timerDuration && meta.timerDuration > 0) {
                setTimeLeft(meta.timerDuration); // timerDuration in seconds
            }
        } else if (res.status === 401) {
            if (res.message?.toLowerCase().includes('token')) setNeedsToken(true);
            if (res.message?.toLowerCase().includes('login')) setNeedsLogin(true);
            setSubmitError(res.message);
        } else {
            setGateError({ status: res.status, message: res.message || 'Failed to fetch form questions.' });
        }
    };

    // ── Countdown Timer Effect ─────────────────────────────────────────────────
    useEffect(() => {
        if (timeLeft === null || timeLeft <= 0) return;

        timerRef.current = setInterval(() => {
            setTimeLeft(prev => {
                if (prev <= 1) {
                    clearInterval(timerRef.current);
                    // Auto submit on timer expiration
                    handleAutoSubmit();
                    return 0;
                }
                return prev - 1;
            });
        }, 1000);

        return () => clearInterval(timerRef.current);
    }, [timeLeft]);

    const formatTimer = (seconds) => {
        if (seconds === null || seconds < 0) return '00:00';
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
    };

    // ── Answer Handler Helpers ─────────────────────────────────────────────────
    const setAnswerValue = (questionId, val) => {
        setAnswers(prev => ({ ...prev, [questionId]: val }));
    };

    const toggleCheckboxAnswer = (questionId, optionId) => {
        setAnswers(prev => {
            const current = prev[questionId] || [];
            return {
                ...prev,
                [questionId]: current.includes(optionId)
                    ? current.filter(id => id !== optionId)
                    : [...current, optionId],
            };
        });
    };

    // ── Progress Calculator ────────────────────────────────────────────────────
    const answeredCount = Object.keys(answers).filter(qId => {
        const val = answers[qId];
        if (val === undefined || val === null || val === '') return false;
        if (Array.isArray(val) && val.length === 0) return false;
        return true;
    }).length;

    const totalQuestions = questions.length;
    const progressPercent = totalQuestions > 0 ? Math.round((answeredCount / totalQuestions) * 100) : 0;

    // ── Submit Handlers ────────────────────────────────────────────────────────
    const handleSubmit = async (e) => {
        if (e) e.preventDefault();
        await executeSubmission();
    };

    const handleAutoSubmit = async () => {
        await executeSubmission();
    };

    const executeSubmission = async () => {
        if (submitting) return;
        setSubmitting(true);
        setSubmitError(null);

        // Validation for required questions
        for (const q of questions) {
            if (!q.isRequired) continue;
            const ans = answers[q.id];
            if (ans === undefined || ans === '' || ans === null || (Array.isArray(ans) && ans.length === 0)) {
                setSubmitError(`Pertanyaan "${q.question}" wajib diisi.`);
                setSubmitting(false);
                return;
            }
        }

        // Build answers payload
        const payloadAnswers = [];
        for (const q of questions) {
            const ans = answers[q.id];
            if (ans === undefined || ans === null) continue;

            if (q.typeId === 3) {
                // Checkbox (Multi-select)
                (ans || []).forEach(optId => {
                    payloadAnswers.push({ questionId: q.id, optionId: optId, answerValue: null });
                });
            } else if (q.typeId === 2 || q.typeId === 5) {
                // Multiple Choice / True-False
                payloadAnswers.push({ questionId: q.id, optionId: ans, answerValue: null });
            } else {
                // Essay, Date-Time, Short Answer
                payloadAnswers.push({ questionId: q.id, optionId: null, answerValue: String(ans) });
            }
        }

        // Read stored guest token if available
        const existingGuestToken = localStorage.getItem(`guestToken_${formLink}`);

        const payload = {
            token: tokenInput || null,
            respondentName: guestName.trim() || 'Guest',
            guestToken: existingGuestToken || null,
            answers: payloadAnswers,
        };

        const res = await submitPublicFormResponse(formLink, payload);
        setSubmitting(false);

        if (res.ok || res.status === 201) {
            const responseId = res.data?.responseId;
            const newGuestToken = res.data?.guestToken;

            if (newGuestToken) {
                localStorage.setItem(`guestToken_${formLink}`, newGuestToken);
            }

            // Navigate to Result Page
            navigate(`/f/${formLink}/result/${responseId}`);
        } else {
            setSubmitError(res.message || 'Gagal menyimpan jawaban. Silakan coba lagi.');
        }
    };

    // ── Render States ──────────────────────────────────────────────────────────

    if (metaLoading) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <p className="text-slate-400 text-sm font-medium">Memuat form...</p>
        </div>
    );

    if (gateError) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl border border-slate-200 p-8 max-w-md w-full text-center space-y-3 shadow-xs">
                <div className="text-3xl">🔒</div>
                <h2 className="text-lg font-bold text-slate-900">{gateError.message}</h2>
                <p className="text-xs text-slate-400">Form ini mungkin belum dibuka, sudah ditutup, atau belum dipublish.</p>
                <button onClick={() => navigate('/')} className="mt-4 px-4 py-2 bg-slate-900 text-white font-bold rounded-xl text-xs">
                    Kembali ke Beranda
                </button>
            </div>
        </div>
    );

    if (needsLogin) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl border border-slate-200 p-8 max-w-md w-full text-center space-y-4 shadow-xs">
                <div className="w-12 h-12 bg-teal-50 text-teal-600 rounded-full flex items-center justify-center mx-auto">
                    <User size={24} />
                </div>
                <div>
                    <h2 className="text-lg font-bold text-slate-900">Login Required</h2>
                    <p className="text-xs text-slate-500 mt-1">Pemilik form mewajibkan Anda untuk login terlebih dahulu sebelum mengisi form ini.</p>
                </div>
                <button
                    onClick={() => navigate('/login')}
                    className="w-full py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-bold text-xs rounded-xl shadow-sm"
                >
                    Login Sekarang
                </button>
            </div>
        </div>
    );

    if (needsToken && questions.length === 0) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl border border-slate-200 p-8 max-w-md w-full space-y-4 shadow-xs">
                <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-full flex items-center justify-center mx-auto">
                    <Key size={24} />
                </div>
                <div className="text-center">
                    <h2 className="text-lg font-bold text-slate-900">Token Akses Diperlukan</h2>
                    <p className="text-xs text-slate-500 mt-1">Masukkan token rahasia untuk membuka soal form ini.</p>
                </div>

                <form onSubmit={(e) => { e.preventDefault(); fetchQuestions(formMeta); }} className="space-y-3">
                    <input
                        type="text"
                        required
                        value={tokenInput}
                        onChange={e => setTokenInput(e.target.value)}
                        placeholder="Masukkan token form..."
                        className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-400"
                    />
                    {!isAuthenticated() && (
                        <input
                            type="text"
                            value={guestName}
                            onChange={e => setGuestName(e.target.value)}
                            placeholder="Nama Anda (opsional)..."
                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                        />
                    )}
                    {submitError && <p className="text-xs font-bold text-red-500">{submitError}</p>}
                    <button
                        type="submit"
                        disabled={questionsLoading}
                        className="w-full py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-bold text-xs rounded-xl shadow-sm disabled:opacity-60"
                    >
                        {questionsLoading ? 'Memverifikasi...' : 'Buka Form'}
                    </button>
                </form>
            </div>
        </div>
    );

    return (
        <div className="min-h-screen bg-slate-50 font-sans text-slate-800 pb-16">
            
            {/* Sticky Header with Progress Bar & Timer */}
            <div className="sticky top-0 z-30 bg-white/90 backdrop-blur-md border-b border-slate-200 px-4 py-3 shadow-xs">
                <div className="max-w-2xl mx-auto flex items-center justify-between gap-4">
                    <div className="flex-1 min-w-0">
                        <div className="flex justify-between items-center text-xs font-bold text-slate-600 mb-1.5">
                            <span className="truncate">{formMeta?.title}</span>
                            <span className="shrink-0 text-teal-600">{answeredCount} / {totalQuestions} Terjawab ({progressPercent}%)</span>
                        </div>
                        {/* Progress Bar */}
                        <div className="w-full h-2 bg-slate-100 rounded-full overflow-hidden">
                            <div
                                className="h-full bg-teal-600 transition-all duration-300 rounded-full"
                                style={{ width: `${progressPercent}%` }}
                            />
                        </div>
                    </div>

                    {/* Timer Badge */}
                    {timeLeft !== null && (
                        <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-mono text-xs font-extrabold border shrink-0 ${timeLeft < 60 ? 'bg-red-50 text-red-600 border-red-200 animate-pulse' : 'bg-slate-900 text-teal-400 border-slate-800'}`}>
                            <Clock size={14} />
                            <span>{formatTimer(timeLeft)}</span>
                        </div>
                    )}
                </div>
            </div>

            <div className="max-w-2xl mx-auto px-4 pt-6 space-y-5">

                {/* Form Header Card */}
                <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
                    {formMeta?.bannerImage && (
                        <img src={assetUrl(formMeta.bannerImage)} alt="Banner" className="w-full h-36 sm:h-44 object-cover" />
                    )}
                    <div className="p-6 border-t-4 border-teal-600 space-y-2">
                        <h1 className="text-2xl font-extrabold text-slate-900">{formMeta?.title}</h1>
                        {formMeta?.description && (
                            <RichContentRenderer content={formMeta.description} format={formMeta.descriptionFormat} className="text-xs text-slate-600" />
                        )}
                    </div>
                </div>

                {/* Guest Name input if not logged in */}
                {!isAuthenticated() && (
                    <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-xs">
                        <label className="text-xs font-bold text-slate-700 block mb-1">Nama Responden (Opsional):</label>
                        <input
                            type="text"
                            value={guestName}
                            onChange={e => setGuestName(e.target.value)}
                            placeholder="Nama Anda..."
                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400"
                        />
                    </div>
                )}

                {/* Questions Form */}
                <form onSubmit={handleSubmit} className="space-y-4">
                    {questions.map((q, idx) => (
                        <div key={q.id} className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs space-y-4">
                            
                            {/* Question Title & Media */}
                            <div className="space-y-2">
                                <div className="text-sm font-bold text-slate-900 flex items-start gap-2">
                                    <span className="text-slate-400 shrink-0">{idx + 1}.</span>
                                    <div className="flex-1">
                                        <RichContentRenderer content={q.question} format={q.questionFormat} className="inline font-bold text-slate-900 text-sm" />
                                        {q.isRequired && <span className="text-red-500 font-bold ml-1">*</span>}
                                    </div>
                                </div>

                                {q.questionImage && (
                                    <img src={assetUrl(q.questionImage)} alt="Question illustration" className="max-h-60 w-auto rounded-xl border border-slate-200 mt-2" />
                                )}

                                {q.questionAudio && (
                                    <audio controls src={assetUrl(q.questionAudio)} className="w-full mt-2" />
                                )}
                            </div>

                            {/* Option Inputs based on Type ID */}
                            
                            {/* Type 1: Essay / Short Answer */}
                            {q.typeId === 1 && (
                                <textarea
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswerValue(q.id, e.target.value)}
                                    rows={3}
                                    placeholder="Tuliskan jawaban Anda..."
                                    className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-teal-400 resize-y"
                                />
                            )}

                            {/* Type 2: Multiple Choice (Radio) */}
                            {q.typeId === 2 && (
                                <div className="space-y-2">
                                    {q.options?.map(opt => (
                                        <label key={opt.id} className="flex items-center gap-3 p-3 border border-slate-200 rounded-xl hover:bg-slate-50 cursor-pointer transition-all">
                                            <input
                                                type="radio"
                                                name={`q_${q.id}`}
                                                required={q.isRequired}
                                                checked={answers[q.id] === opt.id}
                                                onChange={() => setAnswerValue(q.id, opt.id)}
                                                className="w-4 h-4 text-teal-600 cursor-pointer"
                                            />
                                            <span className="text-xs font-medium text-slate-800">{opt.optionText}</span>
                                        </label>
                                    ))}
                                </div>
                            )}

                            {/* Type 3: Checkbox (Multi-select) */}
                            {q.typeId === 3 && (
                                <div className="space-y-2">
                                    {q.options?.map(opt => (
                                        <label key={opt.id} className="flex items-center gap-3 p-3 border border-slate-200 rounded-xl hover:bg-slate-50 cursor-pointer transition-all">
                                            <input
                                                type="checkbox"
                                                checked={(answers[q.id] || []).includes(opt.id)}
                                                onChange={() => toggleCheckboxAnswer(q.id, opt.id)}
                                                className="w-4 h-4 text-teal-600 rounded cursor-pointer"
                                            />
                                            <span className="text-xs font-medium text-slate-800">{opt.optionText}</span>
                                        </label>
                                    ))}
                                </div>
                            )}

                            {/* Type 4: Date Time */}
                            {q.typeId === 4 && (
                                <input
                                    type="datetime-local"
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswerValue(q.id, e.target.value)}
                                    className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs font-medium focus:outline-none focus:ring-2 focus:ring-teal-400"
                                />
                            )}

                            {/* Type 5: True / False */}
                            {q.typeId === 5 && (
                                <div className="flex gap-3">
                                    {['True', 'False'].map(optionVal => (
                                        <label key={optionVal} className="flex-1 flex items-center justify-center gap-2 p-3 border border-slate-200 rounded-xl hover:bg-slate-50 cursor-pointer transition-all text-xs font-bold">
                                            <input
                                                type="radio"
                                                name={`q_${q.id}`}
                                                required={q.isRequired}
                                                checked={answers[q.id] === optionVal}
                                                onChange={() => setAnswerValue(q.id, optionVal)}
                                                className="w-4 h-4 text-teal-600"
                                            />
                                            <span>{optionVal}</span>
                                        </label>
                                    ))}
                                </div>
                            )}
                        </div>
                    ))}

                    {submitError && (
                        <div className="p-4 bg-red-50 border border-red-200 rounded-xl text-red-600 text-xs font-bold flex items-center gap-2">
                            <AlertCircle size={16} />
                            <span>{submitError}</span>
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={submitting}
                        className="w-full py-3.5 bg-teal-600 hover:bg-teal-700 text-white font-extrabold rounded-2xl shadow-sm text-sm transition-all disabled:opacity-60 flex items-center justify-center gap-2"
                    >
                        <Send size={16} /> {submitting ? 'Kirim Jawaban...' : 'Kirim Jawaban'}
                    </button>
                </form>
            </div>
        </div>
    );
}
