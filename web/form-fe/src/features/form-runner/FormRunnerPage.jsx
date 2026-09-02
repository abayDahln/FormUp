import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    Clock, Lock, ArrowRight, ArrowLeft,
    AlertCircle, Send, Loader2, Maximize2,
    Sun, Moon, AlertTriangle, X, CheckCircle2
} from 'lucide-react';
import {
    getPublicFormByLink, getPublicFormQuestions, submitPublicFormResponse,
    submitFeedback, clearSession, assetUrl, getLocalUser
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';
import ImageLightboxModal from '../../components/ui/ImageLightboxModal';

export default function FormRunnerPage() {
    const { formLink } = useParams();
    const navigate = useNavigate();

    const [form, setForm] = useState(null);
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState('');
    const [validationToast, setValidationToast] = useState(null);

    // Gatekeeper states
    const [tokenInput, setTokenInput] = useState('');
    const [tokenUnlocked, setTokenUnlocked] = useState(false);
    const [respondentName, setRespondentName] = useState('');

    // Answers state: { [questionId]: value }
    const [answers, setAnswers] = useState(() => {
        if (typeof window !== 'undefined') {
            try {
                const cached = localStorage.getItem(`formup_cache_${formLink}`);
                if (cached) {
                    const parsed = JSON.parse(cached);
                    if (parsed && typeof parsed === 'object') return parsed;
                }
            } catch {}
        }
        return {};
    });

    const [currentStep, setCurrentStep] = useState(0);

    // Lightbox modal for full-resolution question image viewing
    const [lightboxImage, setLightboxImage] = useState(null);

    // Pre-submission Issue Report Modal
    const [reportModalOpen, setReportModalOpen] = useState(false);
    const [reportReason, setReportReason] = useState('PERTANYAAN_TIDAK_JELAS');
    const [reportDescription, setReportDescription] = useState('');
    const [submittingReport, setSubmittingReport] = useState(false);
    const [reportSuccess, setReportSuccess] = useState(false);
    const [reportError, setReportError] = useState('');

    // Timer
    const [timeLeft, setTimeLeft] = useState(null);
    const timerRef = useRef(null);
    const isSubmittingRef = useRef(false);

    // Dark mode toggle for Form Runner
    const [isDarkMode, setIsDarkMode] = useState(() => {
        if (typeof window !== 'undefined') {
            return document.documentElement.classList.contains('dark') || localStorage.getItem('theme') === 'dark';
        }
        return false;
    });

    const toggleDarkMode = () => {
        setIsDarkMode(prev => {
            const next = !prev;
            if (next) {
                document.documentElement.classList.add('dark');
                localStorage.setItem('theme', 'dark');
            } else {
                document.documentElement.classList.remove('dark');
                localStorage.setItem('theme', 'light');
            }
            return next;
        });
    };

    const currentUser = getLocalUser();

    // Auto-cache answers progress to localStorage on any change (BUG-1)
    useEffect(() => {
        if (formLink && Object.keys(answers).length > 0) {
            try {
                localStorage.setItem(`formup_cache_${formLink}`, JSON.stringify(answers));
            } catch {}
        }
    }, [answers, formLink]);

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

                // Check single attempt lock early
                const localSub = localStorage.getItem(`formup_submitted_${formLink}`);
                if (f.oneResponse && (f.alreadySubmitted || localSub)) {
                    setLoading(false);
                    return;
                }

                // If form does not require a token, fetch questions directly
                if (!f.requiresToken) {
                    setTokenUnlocked(true);
                    loadQuestions();
                }

                // Setup persistent timer if available
                if (f.timerDuration && f.timerDuration > 0) {
                    const timerDeadlineKey = `formup_timer_deadline_${formLink}`;
                    const now = Date.now();
                    let deadlineMs = parseInt(localStorage.getItem(timerDeadlineKey), 10);
                    if (!deadlineMs || isNaN(deadlineMs)) {
                        deadlineMs = now + (f.timerDuration * 1000);
                        localStorage.setItem(timerDeadlineKey, String(deadlineMs));
                    }
                    const remaining = Math.max(0, Math.ceil((deadlineMs - now) / 1000));
                    setTimeLeft(remaining);
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
            const qList = res.data.questions || res.data || [];
            setQuestions(qList);
            questionsRef.current = qList;
            // Restore cached answers if available
            try {
                const cached = localStorage.getItem(`formup_cache_${formLink}`);
                if (cached) {
                    const parsed = JSON.parse(cached);
                    if (parsed && typeof parsed === 'object') {
                        setAnswers(prev => {
                            const next = { ...parsed, ...prev };
                            answersRef.current = next;
                            return next;
                        });
                    }
                }
            } catch {}
        } else {
            setError(res.message || 'Gagal memuat soal formulir.');
        }
    };

    const answersRef = useRef(answers);
    const questionsRef = useRef(questions);

    useEffect(() => {
        answersRef.current = answers;
    }, [answers]);

    useEffect(() => {
        questionsRef.current = questions;
    }, [questions]);

    // Timer countdown with persistent deadline
    useEffect(() => {
        if (!tokenUnlocked || !form?.timerDuration || form.timerDuration <= 0) return;

        const timerDeadlineKey = `formup_timer_deadline_${formLink}`;
        let stored = localStorage.getItem(timerDeadlineKey);
        let deadlineMs = stored ? parseInt(stored, 10) : null;
        const now = Date.now();

        if (!deadlineMs || isNaN(deadlineMs)) {
            deadlineMs = now + (form.timerDuration * 1000);
            localStorage.setItem(timerDeadlineKey, String(deadlineMs));
        }

        const checkTimer = () => {
            const currentNow = Date.now();
            const remaining = Math.max(0, Math.ceil((deadlineMs - currentNow) / 1000));
            setTimeLeft(remaining);

            if (remaining <= 0) {
                if (timerRef.current) clearInterval(timerRef.current);
                if (!isSubmittingRef.current) {
                    handleSubmit(null, true);
                }
            }
        };

        checkTimer();
        timerRef.current = setInterval(checkTimer, 1000);

        return () => {
            if (timerRef.current) clearInterval(timerRef.current);
        };
    }, [tokenUnlocked, form?.timerDuration, formLink]);

    const formatTimer = (seconds) => {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    };

    const handleAnswerChange = (questionId, value) => {
        setAnswers(prev => {
            const next = { ...prev, [questionId]: value };
            answersRef.current = next;
            try {
                localStorage.setItem(`formup_cache_${formLink}`, JSON.stringify(next));
            } catch {}
            return next;
        });
    };

    const handleCheckboxChange = (questionId, optionId, checked) => {
        setAnswers(prev => {
            const current = Array.isArray(prev[questionId]) ? prev[questionId] : [];
            const updated = checked
                ? [...current, optionId]
                : current.filter(id => id !== optionId);
            const next = { ...prev, [questionId]: updated };
            answersRef.current = next;
            try {
                localStorage.setItem(`formup_cache_${formLink}`, JSON.stringify(next));
            } catch {}
            return next;
        });
    };

    const handleUnlockToken = async (e) => {
        e.preventDefault();
        setError('');
        const token = tokenInput.trim();
        const res = await getPublicFormQuestions(formLink, { token, name: respondentName });
        if (res.ok && res.data) {
            setTokenUnlocked(true);
            const qList = res.data.questions || res.data || [];
            setQuestions(qList);
            questionsRef.current = qList;
            try {
                const cached = localStorage.getItem(`formup_cache_${formLink}`);
                if (cached) {
                    const parsed = JSON.parse(cached);
                    if (parsed && typeof parsed === 'object') {
                        setAnswers(parsed);
                        answersRef.current = parsed;
                    }
                }
            } catch {}
        } else {
            setError(res.message || 'Token sandi akses salah.');
        }
    };

    const showValidationAlert = (msg) => {
        setValidationToast(msg);
        setTimeout(() => setValidationToast(null), 4500);
    };

    const handleSubmit = async (e, isAuto = false) => {
        if (e && typeof e.preventDefault === 'function') e.preventDefault();

        // Guard against double submission (concurrent clicks or timer hitting 0 while manual click)
        if (isSubmittingRef.current) return;

        const currentQuestions = questionsRef.current?.length ? questionsRef.current : questions;
        const currentAnswers = answersRef.current || answers;

        // Validation for required questions (only for manual submission; skip on auto-submit when timer expires)
        if (!isAuto) {
            const unanswered = [];
            for (const q of currentQuestions) {
                if (q.isRequired) {
                    const val = currentAnswers[q.id];
                    const isAnswered = q.typeId === 3
                        ? (Array.isArray(val) && val.length > 0)
                        : (val !== undefined && val !== null && String(val).trim().length > 0);
                    if (!isAnswered) {
                        unanswered.push(q);
                    }
                }
            }

            if (unanswered.length > 0) {
                const msg = `Ada ${unanswered.length} pertanyaan wajib yang belum dijawab.`;
                showValidationAlert(msg);
                setError(msg);

                const firstUnanswered = unanswered[0];
                const isStep = form?.formTypeId === 2 || form?.settings?.formTypeId === 2;
                if (isStep) {
                    const targetIdx = currentQuestions.findIndex(item => item.id === firstUnanswered.id);
                    if (targetIdx !== -1) setCurrentStep(targetIdx);
                } else {
                    const el = document.getElementById(`question-card-${firstUnanswered.id}`);
                    if (el) {
                        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        el.classList.add('ring-2', 'ring-red-400', 'transition-all');
                        setTimeout(() => el.classList.remove('ring-2', 'ring-red-400'), 3500);
                    }
                }
                return;
            }
        }

        // Lock submission immediately
        isSubmittingRef.current = true;
        setSubmitting(true);
        if (timerRef.current) clearInterval(timerRef.current);
        setError('');
        setValidationToast(null);

        // Format answers matching backend contract: only include non-empty, valid answers
        const formattedAnswers = Object.entries(currentAnswers).map(([questionId, value]) => {
            const q = currentQuestions.find(item => item.id === parseInt(questionId, 10));
            if (!q) return null;

            if (q.typeId === 2) {
                const parsed = parseInt(value, 10);
                if (isNaN(parsed) || parsed <= 0) return null;
                return {
                    questionId: q.id,
                    optionId: parsed,
                };
            }

            if (q.typeId === 3) {
                const ids = Array.isArray(value) ? value.map(v => parseInt(v, 10)).filter(id => !isNaN(id) && id > 0) : [];
                if (ids.length === 0) return null;
                return ids.map(id => ({
                    questionId: q.id,
                    optionId: id
                }));
            }

            if (q.typeId === 5) {
                const strVal = String(value || '').trim();
                if (!strVal) return null;
                const normalizedVal = (strVal.toLowerCase() === 'benar' || strVal.toLowerCase() === 'true') ? 'Benar' : 'Salah';
                return {
                    questionId: q.id,
                    answerValue: normalizedVal,
                };
            }

            const textVal = String(value || '').trim();
            if (!textVal) return null;
            return {
                questionId: q.id,
                answerValue: textVal,
            };
        }).flat().filter(Boolean);

        const payload = {
            token: tokenInput ? tokenInput.trim() : null,
            respondentName: respondentName.trim() || 'Anonim',
            isAutoSubmit: Boolean(isAuto),
            IsAutoSubmit: Boolean(isAuto),
            answers: formattedAnswers,
        };

        try {
            const res = await submitPublicFormResponse(formLink, payload);
            const responseData = res.data;
            const responseId = responseData?.responseId || responseData?.id || (typeof responseData === 'number' || typeof responseData === 'string' ? responseData : null);
            const guestToken = responseData?.guestToken || null;

            if (res.ok && responseId) {
                // Clean up localStorage cache upon successful submit (BUG-1)
                try {
                    localStorage.removeItem(`formup_cache_${formLink}`);
                    localStorage.removeItem(`formup_timer_deadline_${formLink}`);
                    localStorage.setItem(`formup_submitted_${formLink}`, String(responseId));
                } catch {}

                // Pass guestToken via router state so FormResultPage can fetch result
                navigate(`/f/${formLink}/result/${responseId}`, {
                    state: { guestToken }
                });
            } else {
                isSubmittingRef.current = false;
                setSubmitting(false);
                const errText = res.message || 'Gagal mengirimkan respons formulir.';
                setError(errText);
                showValidationAlert(errText);
            }
        } catch (err) {
            isSubmittingRef.current = false;
            setSubmitting(false);
            const errText = 'Terjadi kesalahan koneksi saat mengirim formulir.';
            setError(errText);
            showValidationAlert(errText);
        }
    };

    const handleSendReport = async (e) => {
        e.preventDefault();
        setReportError('');
        setSubmittingReport(true);
        const formId = form?.id;
        const res = await submitFeedback(formId, {
            reason: reportReason,
            description: reportDescription.trim()
        });
        setSubmittingReport(false);
        if (res.ok) {
            setReportSuccess(true);
            setReportDescription('');
            setTimeout(() => {
                setReportModalOpen(false);
                setReportSuccess(false);
            }, 2500);
        } else {
            setReportError(res.message || 'Gagal mengirimkan laporan masalah.');
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

    // Single Attempt Locked Screen
    const localSubmittedId = typeof window !== 'undefined' ? localStorage.getItem(`formup_submitted_${formLink}`) : null;
    if (form && form.oneResponse && (form.alreadySubmitted || localSubmittedId)) {
        const previousId = form.previousResponseId || localSubmittedId;
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F4F8F7] dark:bg-slate-950 p-4 font-sans text-slate-800 dark:text-slate-100">
                <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 max-w-md w-full text-center space-y-5 shadow-xl">
                    <div className="w-16 h-16 bg-amber-50 dark:bg-amber-950/60 text-amber-500 rounded-2xl flex items-center justify-center mx-auto shadow-xs">
                        <Lock size={30} />
                    </div>
                    <div className="space-y-2">
                        <h2 className="text-xl font-extrabold text-slate-900 dark:text-white">Formulir Terkunci</h2>
                        <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                            Anda sudah pernah mengerjakan formulir <b>{form.title}</b>. Pembuat formulir membatasi pengisian hanya <b>1 kali pengerjaan</b> per responden.
                        </p>
                    </div>

                    <div className="pt-2 flex flex-col gap-2.5">
                        {previousId && form.showScore && (
                            <button
                                type="button"
                                onClick={() => navigate(`/f/${formLink}/result/${previousId}`)}
                                className="w-full py-3 bg-[#00897B] hover:bg-[#00796B] text-white font-bold rounded-xl text-xs shadow-sm transition-all cursor-pointer"
                            >
                                Lihat Hasil Pengerjaan Sebelumnya
                            </button>
                        )}
                        <button
                            type="button"
                            onClick={() => navigate(currentUser?.id ? '/dashboard' : '/login')}
                            className="w-full py-2.5 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 font-bold rounded-xl text-xs transition-all cursor-pointer"
                        >
                            Kembali ke {currentUser?.id ? 'Dashboard' : 'Halaman Utama'}
                        </button>
                    </div>
                </div>
            </div>
        );
    }

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
            
            {/* Floating Interactive Validation Toast (BUG-9) */}
            {validationToast && (
                <div className="fixed top-5 left-1/2 -translate-x-1/2 z-50 max-w-md w-[92vw] sm:w-auto bg-red-600 dark:bg-red-700 text-white px-4 py-3 rounded-2xl shadow-2xl flex items-center justify-between gap-3 border border-red-500 animate-in fade-in slide-in-from-top-3 duration-200">
                    <div className="flex items-center gap-2.5">
                        <AlertCircle size={18} className="shrink-0 text-white" />
                        <span className="text-xs sm:text-sm font-bold">{validationToast}</span>
                    </div>
                    <button
                        type="button"
                        onClick={() => setValidationToast(null)}
                        className="p-1 text-white/80 hover:text-white rounded-lg cursor-pointer shrink-0"
                        title="Tutup Notifikasi"
                    >
                        <X size={16} />
                    </button>
                </div>
            )}

            <div className="max-w-3xl mx-auto space-y-6">

                {/* Top Bar: Floating Timer, Dark Mode Toggle, and Report Problem Button */}
                <div className="flex items-center justify-between gap-3 flex-wrap">
                    <div className="flex items-center gap-2">
                        <button
                            type="button"
                            onClick={toggleDarkMode}
                            className="p-2.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 shadow-xs transition-all flex items-center gap-1.5 text-xs font-bold cursor-pointer"
                            title={isDarkMode ? 'Beralih ke Mode Terang' : 'Beralih ke Mode Gelap'}
                        >
                            {isDarkMode ? <Sun size={15} className="text-amber-400" /> : <Moon size={15} className="text-teal-600" />}
                            <span>{isDarkMode ? 'Mode Terang' : 'Mode Gelap'}</span>
                        </button>

                        {/* BUG-4: Report issue during taking form (pre-submission) */}
                        <button
                            type="button"
                            onClick={() => setReportModalOpen(true)}
                            className="p-2.5 rounded-2xl border border-amber-200 dark:border-amber-900/60 bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 hover:bg-amber-100 dark:hover:bg-amber-950/70 shadow-xs transition-all flex items-center gap-1.5 text-xs font-bold cursor-pointer"
                            title="Laporkan Kendala Soal"
                        >
                            <AlertTriangle size={14} />
                            <span>Laporkan Masalah</span>
                        </button>
                    </div>

                    {timeLeft !== null && (
                        <div className={`px-4 py-2 rounded-2xl shadow-lg border backdrop-blur-md flex items-center gap-2 font-mono font-bold text-xs sm:text-sm ${
                            timeLeft <= 60 
                                ? 'bg-red-500/90 text-white border-red-400 animate-pulse' 
                                : 'bg-slate-900/90 dark:bg-slate-800/90 text-teal-400 border-slate-700'
                        }`}>
                            <Clock size={15} />
                            <span>Waktu: {formatTimer(timeLeft)}</span>
                        </div>
                    )}
                </div>

                {/* Form Banner & Header */}
                <div className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-sm">
                    {form?.bannerImage && (
                        <div className="w-full h-44 sm:h-56 relative bg-slate-100 dark:bg-slate-800 overflow-hidden flex items-center justify-center border-b border-slate-100 dark:border-slate-800">
                            <img
                                src={assetUrl(form.bannerImage)}
                                alt={form.title}
                                className="w-full h-full object-cover"
                            />
                        </div>
                    )}

                    <div className="p-5 sm:p-8 space-y-4">
                        <div className="space-y-1">
                            <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight break-words">
                                {form?.title || 'Formulir'}
                            </h1>
                            {form?.description && (
                                <div className="pt-2 text-slate-600 dark:text-slate-300 text-sm leading-relaxed break-words break-all [overflow-wrap:anywhere]">
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
                                className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-semibold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
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
                    <div id={`question-card-${currentQ.id}`} className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 p-5 sm:p-8 shadow-sm space-y-6 transition-all">
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
                            {/* Media at TOP of Question */}
                            {currentQ.questionImage && (
                                <div className="my-2 w-full max-w-2xl relative group/img overflow-hidden rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 p-2 shadow-xs mx-auto">
                                    <img
                                        src={assetUrl(currentQ.questionImage)}
                                        alt="Gambar Soal"
                                        className="max-h-96 sm:max-h-[440px] w-auto max-w-full rounded-xl object-contain mx-auto cursor-zoom-in transition-transform group-hover/img:scale-[1.01]"
                                        onClick={() => setLightboxImage({ src: assetUrl(currentQ.questionImage), alt: 'Gambar Soal' })}
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setLightboxImage({ src: assetUrl(currentQ.questionImage), alt: 'Gambar Soal' })}
                                        className="absolute bottom-3 right-3 p-2 bg-slate-900/80 hover:bg-slate-900 text-white rounded-xl shadow-md text-xs font-bold flex items-center gap-1 backdrop-blur-xs opacity-0 group-hover/img:opacity-100 transition-opacity cursor-pointer"
                                    >
                                        <Maximize2 size={13} /> Perbesar
                                    </button>
                                </div>
                            )}
                            {currentQ.questionAudio && (
                                <div className="my-2 max-w-md w-full bg-slate-50 dark:bg-slate-800/80 p-2.5 rounded-2xl border border-slate-200/80 dark:border-slate-700 shadow-xs">
                                    <audio controls src={assetUrl(currentQ.questionAudio)} className="w-full h-8 rounded-xl outline-none" />
                                </div>
                            )}

                            {/* Question Text */}
                            <div className="text-sm sm:text-base font-bold text-slate-900 dark:text-white leading-relaxed break-words break-all [overflow-wrap:anywhere]">
                                <RichContentRenderer content={currentQ.question} />
                            </div>

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
                                    onClick={(e) => handleSubmit(e, false)}
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
                    <form onSubmit={(e) => handleSubmit(e, false)} className="space-y-5">
                        {questions.map((q, idx) => (
                            <div
                                key={q.id || idx}
                                id={`question-card-${q.id}`}
                                className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 p-5 sm:p-8 shadow-sm space-y-4 transition-all"
                            >
                                <div className="flex items-center justify-between gap-3 border-b border-slate-100 dark:border-slate-800 pb-2.5">
                                    <span className="shrink-0 w-7 h-7 flex items-center justify-center rounded-xl bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 text-xs font-bold">
                                        {idx + 1}
                                    </span>
                                    {q.isRequired && (
                                        <span className="shrink-0 text-[11px] font-extrabold text-red-500 bg-red-50 dark:bg-red-950/60 px-2 py-0.5 rounded-md">
                                            Wajib
                                        </span>
                                    )}
                                </div>

                                {/* Media at TOP of Question */}
                                {q.questionImage && (
                                    <div className="my-2 w-full max-w-2xl relative group/img overflow-hidden rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 p-2 shadow-xs mx-auto">
                                        <img
                                            src={assetUrl(q.questionImage)}
                                            alt="Gambar Soal"
                                            className="max-h-96 sm:max-h-[440px] w-auto max-w-full rounded-xl object-contain mx-auto cursor-zoom-in transition-transform group-hover/img:scale-[1.01]"
                                            onClick={() => setLightboxImage({ src: assetUrl(q.questionImage), alt: 'Gambar Soal' })}
                                        />
                                        <button
                                            type="button"
                                            onClick={() => setLightboxImage({ src: assetUrl(q.questionImage), alt: 'Gambar Soal' })}
                                            className="absolute bottom-3 right-3 p-2 bg-slate-900/80 hover:bg-slate-900 text-white rounded-xl shadow-md text-xs font-bold flex items-center gap-1 backdrop-blur-xs opacity-0 group-hover/img:opacity-100 transition-opacity cursor-pointer"
                                        >
                                            <Maximize2 size={13} /> Perbesar
                                        </button>
                                    </div>
                                )}
                                {q.questionAudio && (
                                    <div className="my-2 max-w-md w-full bg-slate-50 dark:bg-slate-800/80 p-2.5 rounded-2xl border border-slate-200/80 dark:border-slate-700 shadow-xs">
                                        <audio controls src={assetUrl(q.questionAudio)} className="w-full h-8 rounded-xl outline-none" />
                                    </div>
                                )}

                                {/* Question Text */}
                                <div className="text-sm sm:text-base font-bold text-slate-900 dark:text-white leading-relaxed break-words break-all [overflow-wrap:anywhere]">
                                    <RichContentRenderer content={q.question} />
                                </div>

                                <div className="pt-2">
                                    {renderAnswerField(q, answers, handleAnswerChange, handleCheckboxChange)}
                                </div>
                            </div>
                        ))}

                        <div className="pt-4 flex justify-end">
                            <button
                                type="submit"
                                disabled={submitting}
                                className="w-full sm:w-auto px-8 py-3.5 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.99] text-white font-bold rounded-2xl shadow-md transition-all text-sm flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60"
                            >
                                <Send size={16} />
                                <span>{submitting ? 'Mengirimkan Respons...' : 'Kirim Respons Formulir'}</span>
                            </button>
                        </div>
                    </form>
                )}

            </div>

            {/* Pre-submission Issue Report Modal (BUG-4) */}
            {reportModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs transition-opacity" onClick={() => setReportModalOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 sm:p-8 max-w-md w-full shadow-2xl space-y-4 z-10 animate-in fade-in zoom-in-95 duration-200">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2 text-amber-500 font-extrabold text-sm">
                                <AlertTriangle size={18} />
                                <span>Laporkan Masalah Formulir</span>
                            </div>
                            <button
                                type="button"
                                onClick={() => setReportModalOpen(false)}
                                className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 rounded-lg cursor-pointer"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {reportSuccess ? (
                            <div className="p-4 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 rounded-2xl text-xs font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-2">
                                <CheckCircle2 size={16} />
                                <span>Laporan masalah Anda telah terkirim. Terima kasih!</span>
                            </div>
                        ) : (
                            <form onSubmit={handleSendReport} className="space-y-4">
                                {reportError && (
                                    <div className="p-3 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">
                                        {reportError}
                                    </div>
                                )}

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Alasan Masalah</label>
                                    <select
                                        value={reportReason}
                                        onChange={e => setReportReason(e.target.value)}
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-bold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    >
                                        <option value="PERTANYAAN_TIDAK_JELAS">Pertanyaan tidak jelas / rancu</option>
                                        <option value="KUNCI_JAWABAN_SALAH">Kunci jawaban / opsi salah</option>
                                        <option value="KENDALA_TEKNIS">Kendala teknis / media tidak tampil</option>
                                        <option value="KONTEN_TIDAK_PANTAS">Konten tidak pantas</option>
                                        <option value="LAINNYA">Alasan lainnya</option>
                                    </select>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Deskripsi Kendala (Opsional)</label>
                                    <textarea
                                        rows={3}
                                        value={reportDescription}
                                        onChange={e => setReportDescription(e.target.value)}
                                        placeholder="Ceritakan detail kendala yang dialami..."
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl p-3 text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>

                                <div className="flex justify-end gap-2 pt-1">
                                    <button
                                        type="button"
                                        onClick={() => setReportModalOpen(false)}
                                        className="px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer"
                                    >
                                        Batal
                                    </button>
                                    <button
                                        type="submit"
                                        disabled={submittingReport}
                                        className="px-5 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-1.5 cursor-pointer disabled:opacity-60"
                                    >
                                        <Send size={13} />
                                        <span>{submittingReport ? 'Mengirim...' : 'Kirim Laporan'}</span>
                                    </button>
                                </div>
                            </form>
                        )}
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
                            <div className="text-xs sm:text-sm leading-relaxed flex-1">
                                <RichContentRenderer content={opt.optionText} />
                            </div>
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
                            <div className="text-xs sm:text-sm leading-relaxed flex-1">
                                <RichContentRenderer content={opt.optionText} />
                            </div>
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

    // 5: True / False — menyimpan "Benar"/"Salah" sesuai kontrak live API
    if (q.typeId === 5) {
        return (
            <div className="grid grid-cols-2 gap-3 max-w-sm">
                {[{ value: 'Benar', label: 'Benar' }, { value: 'Salah', label: 'Salah' }].map((choice) => {
                    const isSelected = String(val) === choice.value;
                    return (
                        <button
                            key={choice.value}
                            type="button"
                            onClick={() => handleAnswerChange(q.id, choice.value)}
                            className={`py-3 px-4 rounded-2xl border text-xs font-bold transition-all cursor-pointer ${
                                isSelected
                                    ? 'border-[#00897B] bg-[#00897B] text-white shadow-xs'
                                    : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'
                            }`}
                        >
                            {choice.label}
                        </button>
                    );
                })}
            </div>
        );
    }

    return null;
}
