import { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import {
    Clock, Lock, ArrowRight, ArrowLeft,
    AlertCircle, Send, Loader2, Maximize2,
    Sun, Moon, AlertTriangle, X, CheckCircle2, Bookmark, BookmarkCheck, Eye,
    LayoutGrid
} from 'lucide-react';
import {
    getPublicFormByLink, getPublicFormQuestions, submitPublicFormResponse,
    submitFeedback, clearSession, assetUrl, getLocalUser,
    getFormById, getQuestions, getMyForms, postExamEvent
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';
import ImageLightboxModal from '../../components/ui/ImageLightboxModal';

export default function FormRunnerPage() {
    const { formLink } = useParams();
    const navigate = useNavigate();
    const [searchParams] = useSearchParams();
    const isPreviewMode = searchParams.get('preview') === 'true';

    const [form, setForm] = useState(null);
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState('');
    const [validationToast, setValidationToast] = useState(null);

    const [tokenInput, setTokenInput] = useState('');
    const [tokenUnlocked, setTokenUnlocked] = useState(false);
    const [respondentName, setRespondentName] = useState('');

    // A-2: solid yellow ragu-ragu
    const [markedForReview, setMarkedForReview] = useState(new Set());
    // A-1: nav popup
    const [navPopupOpen, setNavPopupOpen] = useState(false);
    // FEAT-3: submit confirm
    const [submitConfirmOpen, setSubmitConfirmOpen] = useState(false);
    // Exam mode monitoring & violation tracking (Server-side source of truth)
    const [tabSwitchCount, setTabSwitchCount] = useState(0);
    const [violationCount, setViolationCount] = useState(0);
    const [tabSwitchWarning, setTabSwitchWarning] = useState(false);

    // Persistent sessionId for exam mode (per formLink)
    const getStoredSessionId = useCallback(() => {
        if (typeof window === 'undefined') return null;
        try {
            let sid = sessionStorage.getItem(`formup_exam_session_${formLink}`);
            if (!sid) {
                sid = (typeof crypto !== 'undefined' && crypto.randomUUID)
                    ? crypto.randomUUID()
                    : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
                        const r = Math.random() * 16 | 0;
                        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
                    });
                sessionStorage.setItem(`formup_exam_session_${formLink}`, sid);
            }
            return sid;
        } catch {
            return null;
        }
    }, [formLink]);
    const examSessionIdRef = useRef(null);
    if (!examSessionIdRef.current && typeof window !== 'undefined') {
        examSessionIdRef.current = getStoredSessionId();
    }

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
    const [lightboxImage, setLightboxImage] = useState(null);

    const [reportModalOpen, setReportModalOpen] = useState(false);
    const [reportReason, setReportReason] = useState('PERTANYAAN_TIDAK_JELAS');
    const [reportDescription, setReportDescription] = useState('');
    const [submittingReport, setSubmittingReport] = useState(false);
    const [reportSuccess, setReportSuccess] = useState(false);
    const [reportError, setReportError] = useState('');

    const [timeLeft, setTimeLeft] = useState(null);
    const timerRef = useRef(null);
    const isSubmittingRef = useRef(false);

    const [isDarkMode, setIsDarkMode] = useState(() => {
        if (typeof window !== 'undefined') {
            return document.documentElement.classList.contains('dark') || localStorage.getItem('theme') === 'dark';
        }
        return false;
    });

    const toggleDarkMode = () => {
        setIsDarkMode(prev => {
            const next = !prev;
            if (next) { document.documentElement.classList.add('dark'); localStorage.setItem('theme', 'dark'); }
            else { document.documentElement.classList.remove('dark'); localStorage.setItem('theme', 'light'); }
            return next;
        });
    };

    const currentUser = getLocalUser();

    // auto-cache
    useEffect(() => {
        if (formLink && Object.keys(answers).length > 0) {
            try { localStorage.setItem(`formup_cache_${formLink}`, JSON.stringify(answers)); } catch {}
        }
    }, [answers, formLink]);

    // B-2: apply theme
    useEffect(() => {
        if (!form) return;
        const root = document.documentElement;
        if (form.themePrimaryColor) root.style.setProperty('--form-primary', form.themePrimaryColor);
        if (form.themeBackgroundColor) root.style.setProperty('--form-bg', form.themeBackgroundColor);
        return () => { root.style.removeProperty('--form-primary'); root.style.removeProperty('--form-bg'); };
    }, [form]);

    // Send incremental exam event to server in background
    const sendExamEvent = useCallback(async (eventType) => {
        if (!form || isPreviewMode || form.isOwner) return;
        const isExam = form.isExamMode || form.detectTabSwitch;
        if (!isExam && !form.disableCopyPaste) return;
        if (isSubmittingRef.current) return;

        try {
            const sid = examSessionIdRef.current || getStoredSessionId();
            const payload = {
                sessionId: sid,
                respondentName: (respondentName || '').trim() || currentUser?.fullname || 'Anonim',
                type: eventType,
                occurredAt: new Date().toISOString(),
            };
            const res = await postExamEvent(formLink, payload);
            if (res.ok && res.data) {
                if (res.data.sessionId) {
                    examSessionIdRef.current = res.data.sessionId;
                    try { sessionStorage.setItem(`formup_exam_session_${formLink}`, res.data.sessionId); } catch {}
                }
                if (typeof res.data.tabSwitchCount === 'number') {
                    setTabSwitchCount(res.data.tabSwitchCount);
                }
                if (typeof res.data.violationCount === 'number') {
                    setViolationCount(res.data.violationCount);
                }
                // Only show warning banner when an actual violation event occurs, not on presence (session_start / heartbeat)
                if (eventType !== 'session_start' && eventType !== 'heartbeat') {
                    setTabSwitchWarning(true);
                }
                if (res.data.shouldAutoSubmit && !isSubmittingRef.current) {
                    setTimeout(() => handleSubmit(null, true), 1000);
                }
            }
        } catch (err) {
            console.warn('[ExamEvent] Background event report failed:', eventType, err);
        }
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [form, formLink, isPreviewMode, respondentName, currentUser]);

    // Exam mode session presence: session_start and periodic heartbeat
    useEffect(() => {
        if (!form || isPreviewMode || form.isOwner) return;
        if (!form.isExamMode && !form.detectTabSwitch) return;
        if (form.requiresToken && !tokenUnlocked) return;

        // Start session on server
        sendExamEvent('session_start');

        // Periodic heartbeat every 30 seconds
        const heartbeatTimer = setInterval(() => {
            if (!isSubmittingRef.current) {
                sendExamEvent('heartbeat');
            }
        }, 30000);

        return () => clearInterval(heartbeatTimer);
    }, [form, isPreviewMode, tokenUnlocked, sendExamEvent]);

    // Exam mode violation detection (Real-time incremental report, anti double-count)
    useEffect(() => {
        if (!form || isPreviewMode || form.isOwner) return;
        const isExam = form.isExamMode || form.detectTabSwitch;
        const disableCopy = form.disableCopyPaste || isExam;

        const handleVisibilityChange = () => {
            // Anti-double-count: ONLY report on hidden (leaving), never on visible (return)
            if (document.hidden && isExam) {
                sendExamEvent('tab_switch');
            }
        };

        const handleCopy = (e) => {
            if (disableCopy) {
                e.preventDefault();
                sendExamEvent('copy_attempt');
            }
        };

        const handlePaste = (e) => {
            if (disableCopy) {
                e.preventDefault();
                sendExamEvent('paste_attempt');
            }
        };

        const handleContextMenu = (e) => {
            if (disableCopy) {
                e.preventDefault();
                sendExamEvent('context_menu');
            }
        };

        if (isExam) {
            document.addEventListener('visibilitychange', handleVisibilityChange);
        }
        if (disableCopy) {
            document.addEventListener('copy', handleCopy);
            document.addEventListener('cut', handleCopy);
            document.addEventListener('paste', handlePaste);
            document.addEventListener('contextmenu', handleContextMenu);
        }

        return () => {
            if (isExam) {
                document.removeEventListener('visibilitychange', handleVisibilityChange);
            }
            if (disableCopy) {
                document.removeEventListener('copy', handleCopy);
                document.removeEventListener('cut', handleCopy);
                document.removeEventListener('paste', handlePaste);
                document.removeEventListener('contextmenu', handleContextMenu);
            }
        };
    }, [form, isPreviewMode, sendExamEvent]);

    const answersRef = useRef(answers);
    const questionsRef = useRef(questions);
    useEffect(() => { answersRef.current = answers; }, [answers]);
    useEffect(() => { questionsRef.current = questions; }, [questions]);

    const loadQuestionsInternal = async (token) => {
        const res = await getPublicFormQuestions(formLink, { token, name: '' });
        if (res.ok && res.data) {
            const qList = res.data.questions || res.data || [];
            setQuestions(qList);
            questionsRef.current = qList;
            try {
                const cached = localStorage.getItem(`formup_cache_${formLink}`);
                if (cached) {
                    const parsed = JSON.parse(cached);
                    if (parsed && typeof parsed === 'object') {
                        setAnswers(prev => { const next = { ...parsed, ...prev }; answersRef.current = next; return next; });
                    }
                }
            } catch {}
        }
    };

    const loadQuestions = async (token = null) => {
        const res = await getPublicFormQuestions(formLink, { token, name: respondentName });
        if (res.ok && res.data) {
            const qList = res.data.questions || res.data || [];
            setQuestions(qList);
            questionsRef.current = qList;
            try {
                const cached = localStorage.getItem(`formup_cache_${formLink}`);
                if (cached) {
                    const parsed = JSON.parse(cached);
                    if (parsed && typeof parsed === 'object') {
                        setAnswers(prev => { const next = { ...parsed, ...prev }; answersRef.current = next; return next; });
                    }
                }
            } catch {}
        } else {
            setError(res.message || 'Gagal memuat soal formulir.');
        }
    };

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            setError('');

            // A-3: In preview mode, load draft/published form via owner endpoints
            if (isPreviewMode) {
                let targetFormId = searchParams.get('formId');
                if (!targetFormId) {
                    try {
                        const myFormsRes = await getMyForms();
                        if (myFormsRes.ok && Array.isArray(myFormsRes.data)) {
                            const found = myFormsRes.data.find(f => f.formLink === formLink);
                            if (found) targetFormId = found.id;
                        }
                    } catch {}
                }

                if (targetFormId) {
                    try {
                        const [formRes, questionsRes] = await Promise.all([
                            getFormById(targetFormId),
                            getQuestions(targetFormId)
                        ]);
                        setLoading(false);
                        if (formRes.ok && formRes.data) {
                            setForm(formRes.data);
                            setTokenUnlocked(true);
                            if (currentUser?.fullname) setRespondentName(currentUser.fullname);
                            const qList = Array.isArray(questionsRes.data) ? questionsRes.data : [];
                            setQuestions(qList);
                            questionsRef.current = qList;
                            return;
                        }
                    } catch {}
                }
            }

            const res = await getPublicFormByLink(formLink);
            setLoading(false);
            if (res.status === 401) { clearSession(); navigate('/login'); return; }
            if (res.ok && res.data) {
                const f = res.data;
                setForm(f);
                if (currentUser?.fullname) setRespondentName(currentUser.fullname);

                // A-5: preview bypasses all gates
                if (isPreviewMode) {
                    setTokenUnlocked(true);
                    await loadQuestionsInternal(null);
                    return;
                }

                const localSub = localStorage.getItem(`formup_submitted_${formLink}`);
                if (f.oneResponse && (f.alreadySubmitted || localSub)) return;

                let savedToken = '';
                try { savedToken = localStorage.getItem(`formup_token_${formLink}`) || ''; } catch {}
                if (savedToken) setTokenInput(savedToken);

                if (!f.requiresToken) {
                    setTokenUnlocked(true);
                    await loadQuestions();
                } else if (savedToken) {
                    const unlockRes = await getPublicFormQuestions(formLink, { token: savedToken, name: currentUser?.fullname || '' });
                    if (unlockRes.ok && unlockRes.data) {
                        setTokenUnlocked(true);
                        const qList = unlockRes.data.questions || unlockRes.data || [];
                        setQuestions(qList);
                        questionsRef.current = qList;
                    }
                }

                if (f.timerDuration && f.timerDuration > 0) {
                    const timerDeadlineKey = `formup_timer_deadline_${formLink}`;
                    const now = Date.now();
                    let deadlineMs = parseInt(localStorage.getItem(timerDeadlineKey), 10);
                    if (!deadlineMs || isNaN(deadlineMs)) {
                        deadlineMs = now + (f.timerDuration * 1000);
                        localStorage.setItem(timerDeadlineKey, String(deadlineMs));
                    }
                    setTimeLeft(Math.max(0, Math.ceil((deadlineMs - now) / 1000)));
                }
            } else {
                setError(res.message || 'Formulir tidak ditemukan atau belum dipublikasikan.');
            }
        };
        load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [formLink, navigate]);

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
            const remaining = Math.max(0, Math.ceil((deadlineMs - Date.now()) / 1000));
            setTimeLeft(remaining);
            if (remaining <= 0) { if (timerRef.current) clearInterval(timerRef.current); if (!isSubmittingRef.current) handleSubmit(null, true); }
        };
        checkTimer();
        timerRef.current = setInterval(checkTimer, 1000);
        return () => { if (timerRef.current) clearInterval(timerRef.current); };
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [tokenUnlocked, form?.timerDuration, formLink]);

    const formatTimer = (seconds) => {
        const m = Math.floor(seconds / 60), s = seconds % 60;
        return `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
    };

    const handleAnswerChange = (questionId, value) => {
        setAnswers(prev => {
            const next = { ...prev, [questionId]: value };
            answersRef.current = next;
            try { localStorage.setItem(`formup_cache_${formLink}`, JSON.stringify(next)); } catch {}
            return next;
        });
    };

    const handleCheckboxChange = (questionId, optionId, checked) => {
        setAnswers(prev => {
            const current = Array.isArray(prev[questionId]) ? prev[questionId] : [];
            const updated = checked ? [...current, optionId] : current.filter(id => id !== optionId);
            const next = { ...prev, [questionId]: updated };
            answersRef.current = next;
            try { localStorage.setItem(`formup_cache_${formLink}`, JSON.stringify(next)); } catch {}
            return next;
        });
    };

    const handleUnlockToken = async (e) => {
        e.preventDefault();
        setError('');
        const token = tokenInput.trim();
        const res = await getPublicFormQuestions(formLink, { token, name: respondentName });
        if (res.ok && res.data) {
            try { localStorage.setItem(`formup_token_${formLink}`, token); } catch {}
            setTokenUnlocked(true);
            const qList = res.data.questions || res.data || [];
            setQuestions(qList);
            questionsRef.current = qList;
            try {
                const cached = localStorage.getItem(`formup_cache_${formLink}`);
                if (cached) { const parsed = JSON.parse(cached); if (parsed) { setAnswers(parsed); answersRef.current = parsed; } }
            } catch {}
        } else {
            setError(res.message || 'Token sandi akses salah.');
        }
    };

    const showValidationAlert = (msg) => { setValidationToast(msg); setTimeout(() => setValidationToast(null), 4500); };

    const handleSubmit = async (e, isAuto = false) => {
        if (e && typeof e.preventDefault === 'function') e.preventDefault();
        if (isPreviewMode) { window.close(); return; }
        if (!isAuto && !submitConfirmOpen) { setSubmitConfirmOpen(true); return; }
        setSubmitConfirmOpen(false);
        if (isSubmittingRef.current) return;

        const currentQuestions = questionsRef.current?.length ? questionsRef.current : questions;
        const currentAnswers = answersRef.current || answers;

        if (!isAuto) {
            const unanswered = currentQuestions.filter(q => {
                if (!q.isRequired) return false;
                const val = currentAnswers[q.id];
                return q.typeId === 3 ? !(Array.isArray(val) && val.length > 0) : !(val !== undefined && val !== null && String(val).trim().length > 0);
            });
            if (unanswered.length > 0) {
                const msg = `Ada ${unanswered.length} pertanyaan wajib yang belum dijawab.`;
                showValidationAlert(msg); setError(msg);
                const first = unanswered[0];
                const isStep = form?.formTypeId === 2;
                if (isStep) { const idx = currentQuestions.findIndex(q => q.id === first.id); if (idx !== -1) setCurrentStep(idx); }
                else { const el = document.getElementById(`question-card-${first.id}`); if (el) { el.scrollIntoView({ behavior:'smooth', block:'center' }); el.classList.add('ring-2','ring-red-400'); setTimeout(() => el.classList.remove('ring-2','ring-red-400'), 3500); } }
                return;
            }
        }

        isSubmittingRef.current = true;
        setSubmitting(true);
        if (timerRef.current) clearInterval(timerRef.current);
        setError(''); setValidationToast(null);

        const formattedAnswers = Object.entries(currentAnswers).map(([questionId, value]) => {
            const q = currentQuestions.find(item => item.id === parseInt(questionId, 10));
            if (!q) return null;
            if (q.typeId === 2) { const p = parseInt(value, 10); return (!isNaN(p) && p > 0) ? { questionId: q.id, optionId: p } : null; }
            if (q.typeId === 3) { const ids = Array.isArray(value) ? value.map(v => parseInt(v,10)).filter(id => !isNaN(id) && id > 0) : []; return ids.length ? ids.map(id => ({ questionId: q.id, optionId: id })) : null; }
            if (q.typeId === 5) { const s = String(value||'').trim(); return s ? { questionId: q.id, answerValue: (s.toLowerCase()==='benar'||s.toLowerCase()==='true') ? 'Benar' : 'Salah' } : null; }
            const t = String(value||'').trim(); return t ? { questionId: q.id, answerValue: t } : null;
        }).flat().filter(Boolean);

        try {
            const res = await submitPublicFormResponse(formLink, {
                token: tokenInput ? tokenInput.trim() : null,
                respondentName: respondentName.trim() || 'Anonim',
                isAutoSubmit: Boolean(isAuto), IsAutoSubmit: Boolean(isAuto),
                answers: formattedAnswers,
                examSessionId: examSessionIdRef.current || null,
                tabSwitchCount: typeof tabSwitchCount === 'number' ? tabSwitchCount : null,
            });
            const d = res.data;
            const responseId = d?.responseId || d?.id || (typeof d === 'number' || typeof d === 'string' ? d : null);
            if (res.ok && responseId) {
                try {
                    localStorage.removeItem(`formup_cache_${formLink}`);
                    localStorage.removeItem(`formup_timer_deadline_${formLink}`);
                    localStorage.removeItem(`formup_token_${formLink}`);
                    localStorage.setItem(`formup_submitted_${formLink}`, String(responseId));
                    sessionStorage.removeItem(`formup_exam_session_${formLink}`);
                    sessionStorage.removeItem(`formup_violations_${formLink}`);
                } catch {}
                navigate(`/f/${formLink}/result/${responseId}`, { state: { guestToken: d?.guestToken || null } });
            } else {
                isSubmittingRef.current = false; setSubmitting(false);
                const errText = res.message || 'Gagal mengirimkan respons formulir.';
                setError(errText); showValidationAlert(errText);
            }
        } catch {
            isSubmittingRef.current = false; setSubmitting(false);
            const errText = 'Terjadi kesalahan koneksi saat mengirim formulir.';
            setError(errText); showValidationAlert(errText);
        }
    };

    const handleSendReport = async (e) => {
        e.preventDefault(); setReportError(''); setSubmittingReport(true);
        const res = await submitFeedback(form?.id, { reason: reportReason, description: reportDescription.trim() });
        setSubmittingReport(false);
        if (res.ok) { setReportSuccess(true); setReportDescription(''); setTimeout(() => { setReportModalOpen(false); setReportSuccess(false); }, 2500); }
        else setReportError(res.message || 'Gagal mengirimkan laporan masalah.');
    };

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <div className="text-center space-y-2">
                <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400" />
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat formulir...</p>
            </div>
        </div>
    );

    // A-5: skip locked screen in preview
    const localSubmittedId = typeof window !== 'undefined' ? localStorage.getItem(`formup_submitted_${formLink}`) : null;
    if (!isPreviewMode && form && form.oneResponse && (form.alreadySubmitted || localSubmittedId)) {
        const previousId = form.previousResponseId || localSubmittedId;
        return (
            <div className="min-h-screen flex items-center justify-center bg-[#F4F8F7] dark:bg-slate-950 p-4 font-sans text-slate-800 dark:text-slate-100">
                <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 max-w-md w-full text-center space-y-5 shadow-xl">
                    <div className="w-16 h-16 bg-amber-50 dark:bg-amber-950/60 text-amber-500 rounded-2xl flex items-center justify-center mx-auto shadow-xs"><Lock size={30} /></div>
                    <div className="space-y-2">
                        <h2 className="text-xl font-extrabold text-slate-900 dark:text-white">Formulir Terkunci</h2>
                        <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">Anda sudah pernah mengerjakan formulir <b>{form.title}</b>. Pembuat formulir membatasi pengisian hanya <b>1 kali pengerjaan</b> per responden.</p>
                    </div>
                    <div className="pt-2 flex flex-col gap-2.5">
                        {previousId && form.showScore && <button type="button" onClick={() => navigate(`/f/${formLink}/result/${previousId}`)} className="w-full py-3 bg-[#00897B] hover:bg-[#00796B] text-white font-bold rounded-xl text-xs shadow-sm transition-all cursor-pointer">Lihat Hasil Pengerjaan Sebelumnya</button>}
                        <button type="button" onClick={() => navigate(currentUser?.id ? '/dashboard' : '/login')} className="w-full py-2.5 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 font-bold rounded-xl text-xs transition-all cursor-pointer">Kembali ke {currentUser?.id ? 'Dashboard' : 'Halaman Utama'}</button>
                    </div>
                </div>
            </div>
        );
    }

    if (error && !form) return (
        <div className="min-h-screen flex items-center justify-center bg-[#F4F8F7] dark:bg-slate-950 p-4">
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-8 max-w-md w-full text-center space-y-4 shadow-xl">
                <div className="w-14 h-14 bg-red-50 dark:bg-red-950/50 text-red-500 rounded-2xl flex items-center justify-center mx-auto"><AlertCircle size={28} /></div>
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">Formulir Tidak Tersedia</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">{error}</p>
            </div>
        </div>
    );

    // A-5: skip token screen in preview
    if (!isPreviewMode && !tokenUnlocked) return (
        <div className="min-h-screen flex items-center justify-center bg-[#F4F8F7] dark:bg-slate-950 p-4 font-sans text-slate-800 dark:text-slate-100">
            <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 max-w-md w-full space-y-6 shadow-xl">
                <div className="text-center space-y-2">
                    <div className="w-14 h-14 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-2xl flex items-center justify-center mx-auto shadow-xs"><Lock size={26} /></div>
                    <h2 className="text-lg font-extrabold text-slate-900 dark:text-white">Formulir Membutuhkan Sandi Akses</h2>
                    <p className="text-xs text-slate-500 dark:text-slate-400 font-medium">Masukkan token sandi yang diberikan oleh pembuat formulir untuk mulai mengisi.</p>
                </div>
                {error && <div className="px-4 py-2.5 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">{error}</div>}
                <form onSubmit={handleUnlockToken} className="space-y-4">
                    <input type="password" required value={tokenInput} onChange={e => setTokenInput(e.target.value)} placeholder="Masukkan token sandi..." className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-4 py-3 text-sm font-mono font-bold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
                    <button type="submit" className="w-full py-3 bg-[#00897B] hover:bg-[#00796B] text-white font-bold rounded-xl text-xs shadow-sm transition-all cursor-pointer">Buka Formulir</button>
                </form>
            </div>
        </div>
    );

    const isStepLayout = form?.formTypeId === 2 || form?.settings?.formTypeId === 2;
    const currentQ = questions[currentStep];
    const totalSteps = questions.length;

    // FEAT-4: progress
    const answeredCount = questions.filter(q => {
        const val = answers[q.id];
        return q.typeId === 3 ? Array.isArray(val) && val.length > 0 : val !== undefined && val !== null && String(val).trim().length > 0;
    }).length;
    const progressPercent = totalSteps > 0 ? Math.round((answeredCount / totalSteps) * 100) : 0;

    // B-2: theme
    const primaryColor = form?.themePrimaryColor || '#00897B';
    const bgColor = form?.themeBackgroundColor;

    return (
        <div className={`min-h-screen font-sans antialiased text-slate-800 dark:text-slate-100 ${questions.length > 0 ? 'pt-16' : 'py-8'} pb-8 px-4 sm:px-6 transition-colors`} style={{ backgroundColor: bgColor || undefined }}>

            {/* A-4: Sticky full-width progress bar at top of viewport */}
            {questions.length > 0 && (
                <div className="fixed top-0 left-0 right-0 z-40 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-b border-slate-200/80 dark:border-slate-800 px-4 sm:px-8 py-2.5 shadow-xs transition-all">
                    <div className={`${isStepLayout ? 'max-w-4xl lg:max-w-5xl' : 'max-w-3xl'} mx-auto flex items-center justify-between text-xs font-bold text-slate-600 dark:text-slate-300 mb-1.5`}>
                        <span className="truncate mr-3">{form?.title ? `${form.title} — ` : ''}{answeredCount} dari {totalSteps} soal terjawab</span>
                        <span className="shrink-0 font-mono" style={{ color: primaryColor }}>{progressPercent}%</span>
                    </div>
                    <div className={`${isStepLayout ? 'max-w-4xl lg:max-w-5xl' : 'max-w-3xl'} mx-auto w-full h-1.5 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden`}>
                        <div className="h-full rounded-full transition-all duration-300" style={{ width: `${progressPercent}%`, backgroundColor: primaryColor }} />
                    </div>
                </div>
            )}

            {/* Exam mode violation warning */}
            {tabSwitchWarning && (form?.detectTabSwitch || form?.isExamMode) && (
                <div className="fixed top-5 left-1/2 -translate-x-1/2 z-50 bg-red-600 text-white px-5 py-3 rounded-2xl shadow-2xl flex items-center gap-3 max-w-md w-[92vw]">
                    <AlertCircle size={18} className="shrink-0" />
                    <div className="flex-1">
                        <p className="text-xs font-extrabold">Peringatan: Terdeteksi aktivitas keluar / pelanggaran mode ujian!</p>
                        {form.maxTabSwitch ? (
                            <p className="text-[11px] opacity-90">Pindah Tab: {tabSwitchCount}/{form.maxTabSwitch} {violationCount > tabSwitchCount ? `• Total Pelanggaran: ${violationCount}` : ''}</p>
                        ) : (
                            <p className="text-[11px] opacity-90">Pindah Tab: {tabSwitchCount} {violationCount > tabSwitchCount ? `• Total Pelanggaran: ${violationCount}` : ''}</p>
                        )}
                    </div>
                    <button onClick={() => setTabSwitchWarning(false)} className="p-1 hover:bg-white/20 rounded cursor-pointer"><X size={15} /></button>
                </div>
            )}

            {/* Validation Toast */}
            {validationToast && (
                <div className="fixed top-5 left-1/2 -translate-x-1/2 z-50 max-w-md w-[92vw] sm:w-auto bg-red-600 dark:bg-red-700 text-white px-4 py-3 rounded-2xl shadow-2xl flex items-center justify-between gap-3 border border-red-500 animate-in fade-in slide-in-from-top-3 duration-200">
                    <div className="flex items-center gap-2.5"><AlertCircle size={18} className="shrink-0 text-white" /><span className="text-xs sm:text-sm font-bold">{validationToast}</span></div>
                    <button type="button" onClick={() => setValidationToast(null)} className="p-1 text-white/80 hover:text-white rounded-lg cursor-pointer shrink-0"><X size={16} /></button>
                </div>
            )}

            <div className={`${isStepLayout ? 'max-w-4xl lg:max-w-5xl' : 'max-w-3xl'} mx-auto space-y-6 transition-all`}>

                {/* A-5: Preview banner */}
                {isPreviewMode && (
                    <div className="bg-amber-50 dark:bg-amber-950/60 border border-amber-200 dark:border-amber-800 rounded-2xl px-4 py-3 flex items-center justify-between gap-3">
                        <div className="flex items-center gap-2 text-amber-700 dark:text-amber-300 text-xs font-bold"><Eye size={15} /><span>Mode Preview — Jawaban tidak akan disimpan</span></div>
                        <button type="button" onClick={() => window.close()} className="text-xs font-bold text-amber-600 dark:text-amber-400 hover:underline cursor-pointer">Tutup Preview</button>
                    </div>
                )}

                {/* Top Bar — hide report button in preview mode (A-4) */}
                <div className="flex items-center justify-between gap-3 flex-wrap">
                    <div className="flex items-center gap-2">
                        <button type="button" onClick={toggleDarkMode} className="p-2.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 shadow-xs transition-all flex items-center gap-1.5 text-xs font-bold cursor-pointer">
                            {isDarkMode ? <Sun size={15} className="text-amber-400" /> : <Moon size={15} className="text-teal-600" />}
                            <span>{isDarkMode ? 'Mode Terang' : 'Mode Gelap'}</span>
                        </button>
                        {/* A-4: Hide report button in preview mode */}
                        {!isPreviewMode && (
                            <button type="button" onClick={() => setReportModalOpen(true)} className="p-2.5 rounded-2xl border border-amber-200 dark:border-amber-900/60 bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 hover:bg-amber-100 shadow-xs transition-all flex items-center gap-1.5 text-xs font-bold cursor-pointer">
                                <AlertTriangle size={14} /><span>Laporkan Masalah</span>
                            </button>
                        )}
                    </div>
                    {timeLeft !== null && (
                        <div className={`px-4 py-2 rounded-2xl shadow-lg border backdrop-blur-md flex items-center gap-2 font-mono font-bold text-xs sm:text-sm ${timeLeft <= 60 ? 'bg-red-500/90 text-white border-red-400 animate-pulse' : 'bg-slate-900/90 dark:bg-slate-800/90 text-teal-400 border-slate-700'}`}>
                            <Clock size={15} /><span>Waktu: {formatTimer(timeLeft)}</span>
                        </div>
                    )}
                </div>

                {/* Form header */}
                <div className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-sm">
                    {form?.bannerImage && (
                        <div className="w-full h-44 sm:h-56 relative bg-slate-100 dark:bg-slate-800 overflow-hidden">
                            <img src={assetUrl(form.bannerImage)} alt={form.title} className="w-full h-full object-cover" />
                        </div>
                    )}
                    <div className="p-5 sm:p-8 space-y-4">
                        <div className="space-y-1">
                            <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight break-words">{form?.title || 'Formulir'}</h1>
                            {form?.description && <div className="pt-2 text-slate-600 dark:text-slate-300 text-sm leading-relaxed break-words break-all [overflow-wrap:anywhere]"><RichContentRenderer content={form.description} /></div>}
                        </div>
                        <div className="pt-4 border-t border-slate-100 dark:border-slate-800 space-y-1">
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block">Nama Anda (Opsional):</label>
                            <input type="text" value={respondentName} onChange={e => setRespondentName(e.target.value)} placeholder="Masukkan nama lengkap Anda..." className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-semibold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
                        </div>
                    </div>
                </div>

                {error && (
                    <div className="px-5 py-3.5 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-2xl text-xs font-bold text-red-600 dark:text-red-400 flex items-center gap-2">
                        <AlertCircle size={16} /><span>{error}</span>
                    </div>
                )}

                {/* ── STEP LAYOUT ── */}
                {isStepLayout && currentQ ? (
                    <div id={`question-card-${currentQ.id}`} className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 p-6 sm:p-10 lg:p-12 shadow-sm space-y-8 transition-all">
                        <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-4">
                            <div className="flex items-center gap-2.5">
                                <span className="text-xs sm:text-sm font-bold px-3.5 py-1.5 rounded-full" style={{ backgroundColor: `${primaryColor}18`, color: primaryColor }}>
                                    Soal {currentStep + 1} dari {totalSteps}
                                </span>
                                {/* A-1: nav popup trigger */}
                                <button type="button" onClick={() => setNavPopupOpen(true)} title="Navigasi soal cepat" className="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700 transition-all cursor-pointer">
                                    <LayoutGrid size={15} />
                                </button>
                            </div>
                            <div className="flex items-center gap-2">
                                {currentQ.isRequired && <span className="text-xs font-bold text-red-500 bg-red-50 dark:bg-red-950/60 px-2.5 py-0.5 rounded-md">Wajib</span>}
                                {/* A-2: solid yellow ragu-ragu */}
                                <button type="button"
                                    onClick={() => setMarkedForReview(prev => { const next = new Set(prev); if (next.has(currentQ.id)) next.delete(currentQ.id); else next.add(currentQ.id); return next; })}
                                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${
                                        markedForReview.has(currentQ.id)
                                            ? 'bg-yellow-400 dark:bg-yellow-500 text-white border-yellow-400 dark:border-yellow-500'
                                            : 'bg-slate-50 dark:bg-slate-800 text-slate-500 dark:text-slate-400 border-slate-200 dark:border-slate-700 hover:border-yellow-400'
                                    }`}>
                                    {markedForReview.has(currentQ.id) ? <BookmarkCheck size={14} /> : <Bookmark size={14} />}
                                    <span>{markedForReview.has(currentQ.id) ? 'Ragu-ragu' : 'Tandai'}</span>
                                </button>
                            </div>
                        </div>

                        <div className="space-y-6">
                            {currentQ.questionImage && (
                                <div className="my-2 w-full max-w-2xl relative group/img overflow-hidden rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 p-2 shadow-xs mx-auto">
                                    <img src={assetUrl(currentQ.questionImage)} alt="Gambar Soal" className="max-h-96 sm:max-h-[440px] w-auto max-w-full rounded-xl object-contain mx-auto cursor-zoom-in" onClick={() => setLightboxImage({ src: assetUrl(currentQ.questionImage), alt: 'Gambar Soal' })} />
                                    <button type="button" onClick={() => setLightboxImage({ src: assetUrl(currentQ.questionImage), alt: 'Gambar Soal' })} className="absolute bottom-3 right-3 p-2 bg-slate-900/80 hover:bg-slate-900 text-white rounded-xl shadow-md text-xs font-bold flex items-center gap-1 opacity-0 group-hover/img:opacity-100 transition-opacity cursor-pointer"><Maximize2 size={13} /> Perbesar</button>
                                </div>
                            )}
                            {currentQ.questionAudio && (
                                <div className="my-2 max-w-md w-full bg-slate-50 dark:bg-slate-800/80 p-2.5 rounded-2xl border border-slate-200/80 dark:border-slate-700 shadow-xs">
                                    <audio controls src={assetUrl(currentQ.questionAudio)} className="w-full h-8 rounded-xl outline-none" />
                                </div>
                            )}
                            <div className="text-base sm:text-lg lg:text-xl font-bold text-slate-900 dark:text-white leading-relaxed break-words break-all [overflow-wrap:anywhere]">
                                <RichContentRenderer content={currentQ.question} />
                            </div>
                            <div className="pt-2">{renderAnswerField(currentQ, answers, handleAnswerChange, handleCheckboxChange, primaryColor)}</div>
                        </div>

                        <div className="flex items-center justify-between pt-4 border-t border-slate-100 dark:border-slate-800">
                            <button type="button" onClick={() => setCurrentStep(prev => Math.max(prev - 1, 0))} disabled={currentStep === 0} className="px-4 py-2.5 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5 cursor-pointer">
                                <ArrowLeft size={14} /> Sebelumnya
                            </button>
                            {currentStep < totalSteps - 1 ? (
                                <button type="button" onClick={() => setCurrentStep(prev => prev + 1)} className="px-5 py-2.5 text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-1.5 cursor-pointer" style={{ backgroundColor: primaryColor }}>
                                    Selanjutnya <ArrowRight size={14} />
                                </button>
                            ) : (
                                // A-4: In preview mode, show "Selesai Preview" instead of submit
                                isPreviewMode ? (
                                    <button type="button" onClick={() => window.close()} className="px-6 py-2.5 bg-amber-500 hover:bg-amber-600 text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-2 cursor-pointer">
                                        <Eye size={14} /> Selesai Preview
                                    </button>
                                ) : (
                                    <button type="button" onClick={(e) => handleSubmit(e, false)} disabled={submitting} className="px-6 py-2.5 bg-slate-900 hover:bg-slate-800 dark:bg-teal-600 dark:hover:bg-teal-700 text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-2 cursor-pointer disabled:opacity-60">
                                        <Send size={14} /> {submitting ? 'Mengirimkan...' : 'Kirim Formulir'}
                                    </button>
                                )
                            )}
                        </div>
                    </div>
                ) : (
                    // ── SCROLL LAYOUT ──
                    <form onSubmit={(e) => handleSubmit(e, false)} className="space-y-5">
                        {questions.map((q, idx) => (
                            <div key={q.id || idx} id={`question-card-${q.id}`} className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 p-5 sm:p-8 shadow-sm space-y-4 transition-all">
                                <div className="flex items-center justify-between gap-3 border-b border-slate-100 dark:border-slate-800 pb-2.5">
                                    <span className="shrink-0 w-7 h-7 flex items-center justify-center rounded-xl text-xs font-bold text-white" style={{ backgroundColor: primaryColor }}>{idx + 1}</span>
                                    {q.isRequired && <span className="shrink-0 text-[11px] font-extrabold text-red-500 bg-red-50 dark:bg-red-950/60 px-2 py-0.5 rounded-md">Wajib</span>}
                                </div>
                                {q.questionImage && (
                                    <div className="my-2 w-full max-w-2xl relative group/img overflow-hidden rounded-2xl border border-slate-200/80 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40 p-2 shadow-xs mx-auto">
                                        <img src={assetUrl(q.questionImage)} alt="Gambar Soal" className="max-h-96 sm:max-h-[440px] w-auto max-w-full rounded-xl object-contain mx-auto cursor-zoom-in" onClick={() => setLightboxImage({ src: assetUrl(q.questionImage), alt: 'Gambar Soal' })} />
                                        <button type="button" onClick={() => setLightboxImage({ src: assetUrl(q.questionImage), alt: 'Gambar Soal' })} className="absolute bottom-3 right-3 p-2 bg-slate-900/80 hover:bg-slate-900 text-white rounded-xl shadow-md text-xs font-bold flex items-center gap-1 opacity-0 group-hover/img:opacity-100 transition-opacity cursor-pointer"><Maximize2 size={13} /> Perbesar</button>
                                    </div>
                                )}
                                {q.questionAudio && <div className="my-2 max-w-md w-full bg-slate-50 dark:bg-slate-800/80 p-2.5 rounded-2xl border border-slate-200/80 dark:border-slate-700 shadow-xs"><audio controls src={assetUrl(q.questionAudio)} className="w-full h-8 rounded-xl outline-none" /></div>}
                                <div className="text-sm sm:text-base font-bold text-slate-900 dark:text-white leading-relaxed break-words break-all [overflow-wrap:anywhere]"><RichContentRenderer content={q.question} /></div>
                                <div className="pt-2">{renderAnswerField(q, answers, handleAnswerChange, handleCheckboxChange, primaryColor)}</div>
                            </div>
                        ))}
                        <div className="pt-4 flex justify-end">
                            {/* A-4: Preview mode — show "Selesai Preview" only, no real submit */}
                            {isPreviewMode ? (
                                <button type="button" onClick={() => window.close()}
                                    className="w-full sm:w-auto px-8 py-3.5 bg-amber-500 hover:bg-amber-600 text-white font-bold rounded-2xl shadow-md transition-all text-sm flex items-center justify-center gap-2 cursor-pointer">
                                    <Eye size={16} />
                                    <span>Selesai Preview</span>
                                </button>
                            ) : (
                                <button type="submit" disabled={submitting}
                                    className="w-full sm:w-auto px-8 py-3.5 text-white font-bold rounded-2xl shadow-md transition-all text-sm flex items-center justify-center gap-2 cursor-pointer disabled:opacity-60"
                                    style={{ backgroundColor: primaryColor }}>
                                    <Send size={16} />
                                    <span>{submitting ? 'Mengirimkan Respons...' : 'Kirim Respons Formulir'}</span>
                                </button>
                            )}
                        </div>
                    </form>
                )}
            </div>

            {/* A-1: Nav popup modal */}
            {navPopupOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-black/50 backdrop-blur-xs" onClick={() => setNavPopupOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-5 max-w-sm w-full shadow-2xl z-10">
                        <div className="flex items-center justify-between mb-3">
                            <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2"><LayoutGrid size={16} className="text-teal-600" /> Navigasi Soal</h3>
                            <button onClick={() => setNavPopupOpen(false)} className="p-1 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 cursor-pointer"><X size={16} /></button>
                        </div>
                        <div className="flex items-center gap-3 mb-3 flex-wrap text-[11px] font-medium text-slate-500 dark:text-slate-400">
                            <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-emerald-500 inline-block" /> Terjawab</span>
                            <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-slate-200 dark:bg-slate-700 inline-block" /> Belum</span>
                            <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-yellow-400 inline-block" /> Ragu-ragu</span>
                        </div>
                        <div className="grid grid-cols-5 gap-2">
                            {questions.map((q, qIdx) => {
                                const isAnswered = (() => { const val = answers[q.id]; return q.typeId === 3 ? Array.isArray(val) && val.length > 0 : val !== undefined && val !== null && String(val).trim().length > 0; })();
                                const isActive = qIdx === currentStep;
                                const isMarked = markedForReview.has(q.id);
                                return (
                                    <button key={q.id || qIdx} type="button"
                                        onClick={() => { setCurrentStep(qIdx); setNavPopupOpen(false); }}
                                        className={`relative w-full aspect-square rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center justify-center ${
                                            isActive
                                                ? 'text-white ring-2 ring-offset-1 ring-teal-500'
                                                : isMarked
                                                ? 'bg-yellow-400 text-white'
                                                : isAnswered
                                                ? 'bg-emerald-500 text-white'
                                                : 'bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700'
                                        }`}
                                        style={isActive ? { backgroundColor: primaryColor } : {}}>
                                        {qIdx + 1}
                                        {isMarked && !isActive && (
                                            <span className="absolute -top-0.5 -right-0.5 w-2.5 h-2.5 bg-yellow-400 rounded-full border-2 border-white dark:border-slate-900" />
                                        )}
                                    </button>
                                );
                            })}
                        </div>
                    </div>
                </div>
            )}

            {/* Report Modal */}
            {reportModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs" onClick={() => setReportModalOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 sm:p-8 max-w-md w-full shadow-2xl space-y-4 z-10 animate-in fade-in zoom-in-95 duration-200">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-2 text-amber-500 font-extrabold text-sm"><AlertTriangle size={18} /><span>Laporkan Masalah Formulir</span></div>
                            <button type="button" onClick={() => setReportModalOpen(false)} className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 rounded-lg cursor-pointer"><X size={18} /></button>
                        </div>
                        {reportSuccess ? (
                            <div className="p-4 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 rounded-2xl text-xs font-bold text-emerald-600 dark:text-emerald-400 flex items-center gap-2"><CheckCircle2 size={16} /><span>Laporan masalah Anda telah terkirim. Terima kasih!</span></div>
                        ) : (
                            <form onSubmit={handleSendReport} className="space-y-4">
                                {reportError && <div className="p-3 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">{reportError}</div>}
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Alasan Masalah</label>
                                    <select value={reportReason} onChange={e => setReportReason(e.target.value)} className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-bold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]">
                                        <option value="PERTANYAAN_TIDAK_JELAS">Pertanyaan tidak jelas / rancu</option>
                                        <option value="KUNCI_JAWABAN_SALAH">Kunci jawaban / opsi salah</option>
                                        <option value="KENDALA_TEKNIS">Kendala teknis / media tidak tampil</option>
                                        <option value="KONTEN_TIDAK_PANTAS">Konten tidak pantas</option>
                                        <option value="LAINNYA">Alasan lainnya</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Deskripsi Kendala (Opsional)</label>
                                    <textarea rows={3} value={reportDescription} onChange={e => setReportDescription(e.target.value)} placeholder="Ceritakan detail kendala yang dialami..." className="w-full border border-slate-200 dark:border-slate-700 rounded-xl p-3 text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
                                </div>
                                <div className="flex justify-end gap-2 pt-1">
                                    <button type="button" onClick={() => setReportModalOpen(false)} className="px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer">Batal</button>
                                    <button type="submit" disabled={submittingReport} className="px-5 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-1.5 cursor-pointer disabled:opacity-60"><Send size={13} /><span>{submittingReport ? 'Mengirim...' : 'Kirim Laporan'}</span></button>
                                </div>
                            </form>
                        )}
                    </div>
                </div>
            )}

            {/* FEAT-3: Submit confirm */}
            {submitConfirmOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-black/60 backdrop-blur-xs" onClick={() => setSubmitConfirmOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 max-w-sm w-full shadow-2xl space-y-4 z-10">
                        <div className="flex items-center gap-3">
                            <div className="p-2.5 rounded-full bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400"><Send size={20} /></div>
                            <h3 className="text-base font-bold text-slate-900 dark:text-white">Kirim Jawaban?</h3>
                        </div>
                        <p className="text-sm text-slate-500 dark:text-slate-400">Jawaban tidak dapat diubah setelah dikirim. Apakah Anda yakin?</p>
                        <div className="flex items-center gap-2 pt-2">
                            <button type="button" onClick={() => setSubmitConfirmOpen(false)} className="flex-1 px-4 py-2.5 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-xs font-bold rounded-xl cursor-pointer">Batal</button>
                            <button type="button" onClick={() => handleSubmit(null, false)} className="flex-1 px-4 py-2.5 text-white text-xs font-bold rounded-xl cursor-pointer" style={{ backgroundColor: primaryColor }}>Ya, Kirim</button>
                        </div>
                    </div>
                </div>
            )}

            <ImageLightboxModal isOpen={!!lightboxImage} src={lightboxImage?.src} alt={lightboxImage?.alt} onClose={() => setLightboxImage(null)} />
        </div>
    );
}

function renderAnswerField(q, answers, handleAnswerChange, handleCheckboxChange, primaryColor = '#00897B') {
    const val = answers[q.id];

    if (q.typeId === 1) return (
        <textarea rows={3} value={val || ''} onChange={e => handleAnswerChange(q.id, e.target.value)} placeholder="Ketikkan jawaban Anda di sini..." className="w-full border border-slate-200 dark:border-slate-700 rounded-2xl p-3.5 text-xs sm:text-sm bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
    );

    if (q.typeId === 2) return (
        <div className="space-y-2.5">
            {(q.options || []).map(opt => {
                const isSelected = String(val) === String(opt.id);
                return (
                    <label key={opt.id} className={`flex items-center gap-3 p-3.5 rounded-2xl border transition-all cursor-pointer ${isSelected ? 'font-bold' : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'}`}
                        style={isSelected ? { borderColor: primaryColor, backgroundColor: `${primaryColor}18`, color: primaryColor } : {}}>
                        <input type="radio" name={`q_${q.id}`} value={opt.id} checked={isSelected} onChange={() => handleAnswerChange(q.id, opt.id)} className="w-4 h-4 cursor-pointer" style={{ accentColor: primaryColor }} />
                        <div className="text-xs sm:text-sm leading-relaxed flex-1"><RichContentRenderer content={opt.optionText} /></div>
                    </label>
                );
            })}
        </div>
    );

    if (q.typeId === 3) {
        const selectedArr = Array.isArray(val) ? val : [];
        return (
            <div className="space-y-2.5">
                {(q.options || []).map(opt => {
                    const isChecked = selectedArr.includes(opt.id);
                    return (
                        <label key={opt.id} className={`flex items-center gap-3 p-3.5 rounded-2xl border transition-all cursor-pointer ${isChecked ? 'font-bold' : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'}`}
                            style={isChecked ? { borderColor: primaryColor, backgroundColor: `${primaryColor}18`, color: primaryColor } : {}}>
                            <input type="checkbox" checked={isChecked} onChange={e => handleCheckboxChange(q.id, opt.id, e.target.checked)} className="w-4 h-4 rounded cursor-pointer" style={{ accentColor: primaryColor }} />
                            <div className="text-xs sm:text-sm leading-relaxed flex-1"><RichContentRenderer content={opt.optionText} /></div>
                        </label>
                    );
                })}
            </div>
        );
    }

    if (q.typeId === 4) return (
        <input type="date" value={val || ''} onChange={e => handleAnswerChange(q.id, e.target.value)} className="w-full max-w-xs border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-semibold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
    );

    if (q.typeId === 5) return (
        <div className="grid grid-cols-2 gap-3 max-w-sm">
            {[{ value: 'Benar', label: 'Benar' }, { value: 'Salah', label: 'Salah' }].map(choice => {
                const isSelected = String(val) === choice.value;
                return (
                    <button key={choice.value} type="button" onClick={() => handleAnswerChange(q.id, choice.value)}
                        className={`py-3 px-4 rounded-2xl border text-xs font-bold transition-all cursor-pointer ${isSelected ? 'text-white shadow-xs' : 'border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-50'}`}
                        style={isSelected ? { backgroundColor: primaryColor, borderColor: primaryColor } : {}}>
                        {choice.label}
                    </button>
                );
            })}
        </div>
    );

    return null;
}
