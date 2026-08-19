import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    Clock, Lock, ArrowRight, ArrowLeft,
    AlertCircle, Send, Loader2
} from 'lucide-react';
import {
    getPublicFormByLink, getPublicFormQuestions, submitPublicFormResponse,
    clearSession, assetUrl, getLocalUser
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function FormRunnerPage() {
    const { formLink } = useParams();
    const navigate = useNavigate();

    const [form, setForm] = useState(null);
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState('');

    // Gatekeeper states
    const [tokenInput, setTokenInput] = useState('');
    const [tokenUnlocked, setTokenUnlocked] = useState(false);
    const [respondentName, setRespondentName] = useState('');

    // Answers state: { [questionId]: value }
    const [answers, setAnswers] = useState({});

    // Wizard step for step-by-step layout
    const [currentStep, setCurrentStep] = useState(0);

    // Timer
    const [timeLeft, setTimeLeft] = useState(null);
    const timerRef = useRef(null);

    const currentUser = getLocalUser();

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            setError('');
            const res = await getPublicFormByLink(formLink);
            setLoading(false);

            if (res.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }

            if (res.ok && res.data) {
                const f = res.data;
                setForm(f);

                // Auto-fill respondent name if logged in
                if (currentUser?.fullname) {
                    setRespondentName(currentUser.fullname);
                }

                // If form does not require a token, fetch questions directly
                if (!f.requiresToken) {
                    setTokenUnlocked(true);
                    loadQuestions();
                }

                // Setup timer if available
                if (f.timerDuration) {
                    setTimeLeft(f.timerDuration);
                }
            } else {
                setError(res.message || 'Formulir tidak ditemukan atau belum dipublikasikan.');
            }
        };

        load();
    }, [formLink, navigate]);

    const loadQuestions = async (token = null) => {
        const res = await getPublicFormQuestions(formLink, { token, name: respondentName });
        if (res.ok && res.data) {
            setQuestions(res.data.questions || res.data || []);
        } else {
            setError(res.message || 'Gagal memuat soal formulir.');
        }
    };

    // Timer countdown
    useEffect(() => {
        if (timeLeft === null || !tokenUnlocked) return;

        if (timeLeft <= 0) {
            handleSubmit();
            return;
        }

        timerRef.current = setInterval(() => {
            setTimeLeft(prev => {
                if (prev <= 1) {
                    clearInterval(timerRef.current);
                    return 0;
                }
                return prev - 1;
            });
        }, 1000);

        return () => clearInterval(timerRef.current);
    }, [timeLeft, tokenUnlocked]);

    const formatTimer = (seconds) => {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    };

    const handleAnswerChange = (questionId, value) => {
        setAnswers(prev => ({ ...prev, [questionId]: value }));
    };

    const handleCheckboxChange = (questionId, optionId, checked) => {
        setAnswers(prev => {
            const current = Array.isArray(prev[questionId]) ? prev[questionId] : [];
            const updated = checked
                ? [...current, optionId]
                : current.filter(id => id !== optionId);
            return { ...prev, [questionId]: updated };
        });
    };

    const handleUnlockToken = async (e) => {
        e.preventDefault();
        setError('');
        const token = tokenInput.trim();
        const res = await getPublicFormQuestions(formLink, { token, name: respondentName });
        if (res.ok && res.data) {
            setTokenUnlocked(true);
            setQuestions(res.data.questions || res.data || []);
        } else {
            setError(res.message || 'Token sandi akses salah.');
        }
    };

    const handleSubmit = async (e) => {
        if (e) e.preventDefault();

        // Validation for required questions
        for (const q of questions) {
            if (q.isRequired) {
                const val = answers[q.id];
                if (!val || (Array.isArray(val) && val.length === 0) || (typeof val === 'string' && !val.trim())) {
                    setError(`Soal "${q.question ? q.question.replace(/<[^>]*>?/gm, '') : 'Wajib'}" belum dijawab.`);
                    return;
                }
            }
        }

        setSubmitting(true);
        setError('');

        const formattedAnswers = Object.entries(answers).map(([questionId, value]) => {
            const q = questions.find(item => item.id === parseInt(questionId));
            if (!q) return null;

            if (q.typeId === 2) {
                return { questionId: q.id, optionId: value ? parseInt(value) : null };
            }
            if (q.typeId === 3) {
                return { questionId: q.id, optionIds: Array.isArray(value) ? value.map(v => parseInt(v)) : [] };
            }
            return { questionId: q.id, answerText: String(value || '') };
        }).filter(Boolean);

        const payload = {
            respondentName: respondentName.trim() || 'Anonim',
            answers: formattedAnswers,
        };

        const res = await submitPublicFormResponse(formLink, payload);
        const responseId = res.data?.responseId || res.data?.id || (typeof res.data === 'number' || typeof res.data === 'string' ? res.data : null);

        if (res.ok && responseId) {
            // Instantly navigate to result & answer review page
            navigate(`/f/${formLink}/result/${responseId}`);
        } else {
            setSubmitting(false);
            setError(res.message || 'Gagal mengirimkan respons formulir.');
        }
    };

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <div className="text-center space-y-2">
                <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400" />
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat formulir...</p>
            </div>
        </div>
    );

    if (error && !form) return (
        <div className="min-h-screen flex items-center justify-center bg-[#F4F8F7] dark:bg-slate-950 p-4">
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-8 max-w-md w-full text-center space-y-4 shadow-xl">
                <div className="w-14 h-14 bg-red-50 dark:bg-red-950/50 text-red-500 rounded-2xl flex items-center justify-center mx-auto">
                    <AlertCircle size={28} />
                </div>
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">Formulir Tidak Tersedia</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">{error}</p>
            </div>
        </div>
    );

    // Token Unlock Screen
    if (!tokenUnlocked) return (
        <div className="min-h-screen flex items-center justify-center bg-[#F4F8F7] dark:bg-slate-950 p-4 font-sans text-slate-800 dark:text-slate-100">
            <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 max-w-md w-full space-y-6 shadow-xl">
                <div className="text-center space-y-2">
                    <div className="w-14 h-14 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-2xl flex items-center justify-center mx-auto shadow-xs">
                        <Lock size={26} />
                    </div>
                    <h2 className="text-lg font-extrabold text-slate-900 dark:text-white">Formulir Membutuhkan Sandi Akses</h2>
                    <p className="text-xs text-slate-500 dark:text-slate-400 font-medium">
                        Masukkan token sandi yang diberikan oleh pembuat formulir untuk mulai mengisi.
                    </p>
                </div>

                {error && (
                    <div className="px-4 py-2.5 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">
                        {error}
                    </div>
                )}

                <form onSubmit={handleUnlockToken} className="space-y-4">
                    <input
                        type="password"
                        required
                        value={tokenInput}
                        onChange={e => setTokenInput(e.target.value)}
                        placeholder="Masukkan token sandi..."
                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-4 py-3 text-sm font-mono font-bold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                    />
                    <button
                        type="submit"
                        className="w-full py-3 bg-[#00897B] hover:bg-[#00796B] text-white font-bold rounded-xl text-xs shadow-sm transition-all cursor-pointer"
                    >
                        Buka Formulir
                    </button>
                </form>
            </div>
        </div>
    );

    const isStepLayout = form?.formTypeId === 2 || form?.settings?.formTypeId === 2;
    const currentQ = questions[currentStep];
    const totalSteps = questions.length;

    return (
        <div className="min-h-screen bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 py-8 px-4 sm:px-6 transition-colors">
            <div className="max-w-3xl mx-auto space-y-6">

                {/* Floating Timer if enabled */}
                {timeLeft !== null && (
                    <div className="sticky top-4 z-30 flex justify-end">
                        <div className={`px-4 py-2 rounded-2xl shadow-lg border backdrop-blur-md flex items-center gap-2 font-mono font-bold text-sm ${
                            timeLeft <= 60 
                                ? 'bg-red-500/90 text-white border-red-400 animate-pulse' 
                                : 'bg-slate-900/90 dark:bg-slate-800/90 text-teal-400 border-slate-700'
                        }`}>
                            <Clock size={16} />
                            <span>Waktu Tersisa: {formatTimer(timeLeft)}</span>
                        </div>
                    </div>
                )}

                {/* Form Banner & Header */}
                <div className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-sm">
                    {form?.bannerImage && (
                        <div className="w-full h-48 sm:h-56 relative bg-slate-100 dark:bg-slate-800 overflow-hidden flex items-center justify-center border-b border-slate-100 dark:border-slate-800">
                            <img
                                src={assetUrl(form.bannerImage)}
                                alt={form.title}
                                className="w-full h-full object-cover"
                            />
                        </div>
                    )}

                    <div className="p-6 sm:p-8 space-y-4">
                        <div className="space-y-1">
                            <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
                                {form?.title || 'Formulir'}
                            </h1>
                            {form?.description && (
                                <div className="pt-2 text-slate-600 dark:text-slate-300 text-sm leading-relaxed">
                                    <RichContentRenderer content={form.description} />
                                </div>
                            )}
                        </div>

                        {/* Respondent Name Input */}
                        <div className="pt-4 border-t border-slate-100 dark:border-slate-800 space-y-1">
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block">
                                Nama Anda (Opsional):
                            </label>
                            <input
                                type="text"
                                value={respondentName}
                                onChange={e => setRespondentName(e.target.value)}
                                placeholder="Masukkan nama lengkap Anda..."
                                className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                            />
                        </div>
                    </div>
                </div>

                {error && (
                    <div className="px-5 py-3.5 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-2xl text-xs font-bold text-red-600 dark:text-red-400 flex items-center gap-2">
                        <AlertCircle size={16} />
                        <span>{error}</span>
                    </div>
                )}

                {/* ── QUESTION LIST / STEPPER ── */}
                {isStepLayout && currentQ ? (
                    // Step-by-step view
                    <div className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 p-6 sm:p-8 shadow-sm space-y-6">
                        <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                            <span className="text-xs font-bold text-[#00897B] dark:text-teal-400 bg-teal-50 dark:bg-teal-950/60 px-3 py-1 rounded-full">
                                Soal {currentStep + 1} dari {totalSteps}
                            </span>
                            {currentQ.isRequired && (
                                <span className="text-xs font-bold text-red-500 bg-red-50 dark:bg-red-950/60 px-2.5 py-0.5 rounded-md">
                                    Wajib
                                </span>
                            )}
                        </div>

                        <div className="space-y-4">
                            <div className="text-base font-bold text-slate-900 dark:text-white leading-relaxed">
                                <RichContentRenderer content={currentQ.question} />
                            </div>

                            {/* Media if present */}
                            {currentQ.questionImage && (
                                <div className="my-2 max-w-md overflow-hidden rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 p-2 shadow-xs">
                                    <img src={assetUrl(currentQ.questionImage)} alt="Gambar Soal" className="max-h-64 w-auto max-w-full rounded-xl object-contain mx-auto" />
                                </div>
                            )}
                            {currentQ.questionAudio && (
                                <div className="my-2 max-w-sm w-full bg-slate-50 dark:bg-slate-800/80 p-2.5 rounded-2xl border border-slate-200/80 dark:border-slate-700 shadow-xs">
                                    <audio controls src={assetUrl(currentQ.questionAudio)} className="w-full h-8 rounded-xl outline-none" />
                                </div>
                            )}

                            {/* Options rendering */}
                            <div className="pt-2">
                                {renderAnswerField(currentQ, answers, handleAnswerChange, handleCheckboxChange)}
                            </div>
                        </div>

                        <div className="flex items-center justify-between pt-4 border-t border-slate-100 dark:border-slate-800">
                            <button
                                type="button"
                                onClick={() => setCurrentStep(prev => Math.max(prev - 1, 0))}
                                disabled={currentStep === 0}
                                className="px-4 py-2.5 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5 cursor-pointer"
                            >
                                <ArrowLeft size={14} /> Sebelumnya
                            </button>

                            {currentStep < totalSteps - 1 ? (
                                <button
                                    type="button"
                                    onClick={() => setCurrentStep(prev => prev + 1)}
                                    className="px-5 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-1.5 cursor-pointer"
                                >
                                    Selanjutnya <ArrowRight size={14} />
                                </button>
                            ) : (
                                <button
                                    type="button"
                                    onClick={handleSubmit}
                                    disabled={submitting}
                                    className="px-6 py-2.5 bg-slate-900 hover:bg-slate-800 dark:bg-teal-600 dark:hover:bg-teal-700 text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-2 cursor-pointer disabled:opacity-60"
                                >
                                    <Send size={14} /> {submitting ? 'Mengirimkan...' : 'Kirim Formulir'}
                                </button>
                            )}
                        </div>
                    </div>
                ) : (
                    // Single page view (all questions)
                    <form onSubmit={handleSubmit} className="space-y-5">
                        {questions.map((q, idx) => (
                            <div
                                key={q.id || idx}
                                className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 p-6 sm:p-8 shadow-sm space-y-4"
                            >
                                <div className="flex items-start justify-between gap-3">
                                    <div className="flex items-start gap-3">
                                        <span className="shrink-0 w-7 h-7 flex items-center justify-center rounded-xl bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 text-xs font-bold">
                                            {idx + 1}
                                        </span>
                                        <div className="text-sm sm:text-base font-bold text-slate-900 dark:text-white leading-relaxed">
                                            <RichContentRenderer content={q.question} />
                                        </div>
                                    </div>
                                    {q.isRequired && (
                                        <span className="shrink-0 text-[11px] font-extrabold text-red-500 bg-red-50 dark:bg-red-950/60 px-2 py-0.5 rounded-md">
                                            Wajib
                                        </span>
                                    )}
                                </div>

                                {q.questionImage && (
                                    <div className="my-2 max-w-md overflow-hidden rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 p-2 shadow-xs sm:ml-10">
                                        <img src={assetUrl(q.questionImage)} alt="Gambar Soal" className="max-h-64 w-auto max-w-full rounded-xl object-contain mx-auto" />
                                    </div>
                                )}
                                {q.questionAudio && (
                                    <div className="my-2 max-w-sm w-full bg-slate-50 dark:bg-slate-800/80 p-2.5 rounded-2xl border border-slate-200/80 dark:border-slate-700 shadow-xs sm:ml-10">
                                        <audio controls src={assetUrl(q.questionAudio)} className="w-full h-8 rounded-xl outline-none" />
                                    </div>
                                )}

                                <div className="pl-0 sm:pl-10 pt-2">
                                    {renderAnswerField(q, answers, handleAnswerChange, handleCheckboxChange)}
                                </div>
                            </div>
                        ))}

                        <div className="pt-4 flex justify-end">
                            <button
                                type="submit"
                                disabled={submitting}
                                className="px-8 py-3.5 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.99] text-white font-bold rounded-2xl shadow-md transition-all text-sm flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60"
                            >
                                <Send size={16} />
                                <span>{submitting ? 'Mengirimkan Respons...' : 'Kirim Respons Formulir'}</span>
                            </button>
                        </div>
                    </form>
                )}

            </div>
        </div>
    );
}

// Helper to render question types
function renderAnswerField(q, answers, handleAnswerChange, handleCheckboxChange) {
    const val = answers[q.id];

    // 1: Short Answer / Essay
    if (q.typeId === 1) {
        return (
            <textarea
                rows={3}
                value={val || ''}
                onChange={e => handleAnswerChange(q.id, e.target.value)}
                placeholder="Ketikkan jawaban Anda di sini..."
                className="w-full border border-slate-200 dark:border-slate-700 rounded-2xl p-3.5 text-xs sm:text-sm bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
            />
        );
    }

    // 2: Multiple Choice (Single)
    if (q.typeId === 2) {
        return (
            <div className="space-y-2.5">
                {(q.options || []).map((opt) => {
                    const isSelected = String(val) === String(opt.id);
                    return (
                        <label
                            key={opt.id}
                            className={`flex items-center gap-3 p-3.5 rounded-2xl border transition-all cursor-pointer ${
                                isSelected
                                    ? 'border-[#00897B] bg-teal-50/50 dark:bg-teal-950/40 text-[#00897B] dark:text-teal-300 font-bold'
                                    : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'
                            }`}
                        >
                            <input
                                type="radio"
                                name={`q_${q.id}`}
                                value={opt.id}
                                checked={isSelected}
                                onChange={() => handleAnswerChange(q.id, opt.id)}
                                className="w-4 h-4 text-[#00897B] cursor-pointer"
                            />
                            <span className="text-xs sm:text-sm">{opt.optionText}</span>
                        </label>
                    );
                })}
            </div>
        );
    }

    // 3: Checkboxes (Multiple)
    if (q.typeId === 3) {
        const selectedArr = Array.isArray(val) ? val : [];
        return (
            <div className="space-y-2.5">
                {(q.options || []).map((opt) => {
                    const isChecked = selectedArr.includes(opt.id);
                    return (
                        <label
                            key={opt.id}
                            className={`flex items-center gap-3 p-3.5 rounded-2xl border transition-all cursor-pointer ${
                                isChecked
                                    ? 'border-[#00897B] bg-teal-50/50 dark:bg-teal-950/40 text-[#00897B] dark:text-teal-300 font-bold'
                                    : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'
                            }`}
                        >
                            <input
                                type="checkbox"
                                checked={isChecked}
                                onChange={e => handleCheckboxChange(q.id, opt.id, e.target.checked)}
                                className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                            />
                            <span className="text-xs sm:text-sm">{opt.optionText}</span>
                        </label>
                    );
                })}
            </div>
        );
    }

    // 4: Date
    if (q.typeId === 4) {
        return (
            <input
                type="date"
                value={val || ''}
                onChange={e => handleAnswerChange(q.id, e.target.value)}
                className="w-full max-w-xs border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-semibold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
            />
        );
    }

    // 5: True / False
    if (q.typeId === 5) {
        return (
            <div className="grid grid-cols-2 gap-3 max-w-sm">
                {['True', 'False'].map((choice) => {
                    const labelText = choice === 'True' ? 'Benar (True)' : 'Salah (False)';
                    const isSelected = val === choice;
                    return (
                        <button
                            key={choice}
                            type="button"
                            onClick={() => handleAnswerChange(q.id, choice)}
                            className={`py-3 px-4 rounded-2xl border text-xs font-bold transition-all cursor-pointer ${
                                isSelected
                                    ? 'border-[#00897B] bg-[#00897B] text-white shadow-xs'
                                    : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'
                            }`}
                        >
                            {labelText}
                        </button>
                    );
                })}
            </div>
        );
    }

    return null;
}
