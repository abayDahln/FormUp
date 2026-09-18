import { useState, useEffect } from 'react';
import { useParams, useNavigate, useLocation, Link } from 'react-router-dom';
import {
    CheckCircle2, Award, Home, RotateCcw, AlertTriangle,
    Send, Loader2, MessageSquare, Check, X,
    BookOpen, Lightbulb, HelpCircle, CheckCircle,
    ArrowRight, RefreshCw, Key, ExternalLink, ShieldCheck
} from 'lucide-react';
import {
    getPublicResponseResult, getPublicFormByLink, submitFeedback,
    getLocalUser
} from '../../services/apiService';
import {
    generateRemedialExplanation, getGeminiApiKeys
} from '../../services/aiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

const OWNER_FEEDBACK_REASONS = [
    { value: 'PERTANYAAN_TIDAK_JELAS', label: 'Pertanyaan tidak jelas atau membingungkan' },
    { value: 'KUNCI_JAWABAN_SALAH', label: 'Kunci jawaban dinilai salah' },
    { value: 'KENDALA_TEKNIS', label: 'Kendala teknis saat pengisian' },
    { value: 'LAINNYA', label: 'Masukan lainnya untuk pemilik formulir' },
];

const ADMIN_REPORT_REASONS = [
    { value: 'ADMIN_KONTEN_TIDAK_PANTAS', label: 'Konten formulir tidak pantas / melanggar aturan' },
    { value: 'ADMIN_SPAM_PENYALAHGUNAAN', label: 'Formulir terindikasi spam atau disalahgunakan' },
    { value: 'ADMIN_DATA_PRIBADI', label: 'Formulir meminta data pribadi secara mencurigakan' },
    { value: 'ADMIN_LAINNYA', label: 'Pelanggaran lainnya (laporkan ke Admin FormUp)' },
];

export default function FormResultPage() {
    const { formLink, responseId } = useParams();
    const navigate = useNavigate();
    const location = useLocation();

    const [form, setForm] = useState(null);
    const [result, setResult] = useState(null);
    const [loading, setLoading] = useState(true);

    // Feedback State
    const [feedbackOpen, setFeedbackOpen] = useState(false);
    const [feedbackTarget, setFeedbackTarget] = useState('owner'); 
    const [reason, setReason] = useState('PERTANYAAN_TIDAK_JELAS');
    const [description, setDescription] = useState('');
    const [sendingFeedback, setSendingFeedback] = useState(false);
    const [feedbackSuccess, setFeedbackSuccess] = useState(false);
    const [feedbackError, setFeedbackError] = useState('');

    // Remedial / Practice Assistant State
    const [remedialModalOpen, setRemedialModalOpen] = useState(false);
    const [activeRemedialQuestion, setActiveRemedialQuestion] = useState(null);
    const [remedialLoading, setRemedialLoading] = useState(false);
    const [remedialData, setRemedialData] = useState(null);
    const [remedialError, setRemedialError] = useState('');
    const [practiceSelectedOption, setPracticeSelectedOption] = useState(null);
    const [practiceSubmitted, setPracticeSubmitted] = useState(false);
    const [remedialKeyPromptOpen, setRemedialKeyPromptOpen] = useState(false);

    const user = getLocalUser();

    const currentReasonOptions = feedbackTarget === 'admin' ? ADMIN_REPORT_REASONS : OWNER_FEEDBACK_REASONS;

    const handleChangeFeedbackTarget = (target) => {
        setFeedbackTarget(target);
        const options = target === 'admin' ? ADMIN_REPORT_REASONS : OWNER_FEEDBACK_REASONS;
        setReason(options[0].value);
        setFeedbackError('');
    };

    useEffect(() => {
        const load = async () => {
            setLoading(true);

            // Fetch form info always (needed for title, showScore, feedback, etc.)
            const formRes = await getPublicFormByLink(formLink);
            if (formRes.ok) setForm(formRes.data);

            // guestToken passed from submit via router state
            const guestToken = location.state?.guestToken || null;

            // Fetch result — guestToken allows guest users to see their result
            const detailRes = await getPublicResponseResult(formLink, responseId, guestToken);
            if (detailRes.ok && detailRes.data) {
                setResult(detailRes.data);
            }
            setLoading(false);
        };

        load();
    }, [formLink, responseId]);

    const handleSendFeedback = async (e) => {
        e.preventDefault();
        setFeedbackError('');
        setSendingFeedback(true);

        const formId = form?.id || result?.formId;
        const res = await submitFeedback(formId, {
            reason,
            description: description.trim(),
            responseId: parseInt(responseId, 10) || null,
        });
        setSendingFeedback(false);

        if (res.ok) {
            setFeedbackSuccess(true);
            setDescription('');
        } else {
            setFeedbackError(res.message || 'Gagal mengirimkan masukan.');
        }
    };

    const handleOpenRemedial = async (answerItem) => {
        setActiveRemedialQuestion(answerItem);
        setRemedialModalOpen(true);
        setRemedialLoading(true);
        setRemedialError('');
        setRemedialData(null);
        setPracticeSelectedOption(null);
        setPracticeSubmitted(false);

        const keys = getGeminiApiKeys();
        if (keys.length === 0) {
            setRemedialLoading(false);
            setRemedialKeyPromptOpen(true);
            return;
        }

        try {
            const res = await generateRemedialExplanation({
                questionText: answerItem.question,
                questionType: answerItem.typeId || 2,
                userAnswer: answerItem.optionText || answerItem.answerText || '',
                correctAnswer: answerItem.correctAnswer || '',
                options: answerItem.options || [],
            });

            if (res.ok && res.data) {
                setRemedialData(res.data);
            } else {
                setRemedialError(res.message || 'Gagal memuat pembahasan materi.');
            }
        } catch (err) {
            setRemedialError(err.message || 'Terjadi kesalahan saat memuat pembahasan.');
        } finally {
            setRemedialLoading(false);
        }
    };

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <div className="text-center space-y-2">
                <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400" />
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat hasil formulir...</p>
            </div>
        </div>
    );

    // P0-2: Live form setting takes strict precedence over submission snapshot (retroactive)
    const showScore = form
        ? Boolean(form.showScore ?? form.settings?.showScore ?? form.formSetting?.showScore ?? false)
        : Boolean(result?.showScore);
    const score = result?.score;

    return (
        <div className="min-h-screen bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 py-12 px-4 flex justify-center transition-colors">
            <div className="max-w-2xl w-full space-y-6">

                {/* Main Success Card */}
                <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-8 sm:p-10 text-center shadow-xl space-y-6">
                    <div className="w-16 h-16 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-3xl flex items-center justify-center mx-auto shadow-xs">
                        <CheckCircle2 size={36} />
                    </div>

                    <div className="space-y-2">
                        <h1 className="text-2xl font-extrabold text-slate-900 dark:text-white tracking-tight">
                            Respons Anda Telah Terkirim!
                        </h1>
                        <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 font-medium">
                            Terima kasih telah meluangkan waktu untuk mengisi <span className="font-bold text-slate-800 dark:text-slate-200">{form?.title || 'formulir ini'}</span>.
                        </p>
                    </div>

                    {/* Score Display if enabled */}
                    {showScore && score != null && (
                        <div className="bg-linear-to-br from-teal-50/60 to-emerald-50/60 dark:from-teal-950/40 dark:to-slate-800 border border-teal-100 dark:border-teal-900/50 rounded-2xl p-6 space-y-2">
                            <div className="inline-flex items-center gap-1 text-[11px] font-extrabold text-[#00897B] dark:text-teal-400 uppercase tracking-wider">
                                <Award size={15} /> Skor Akhir Anda
                            </div>
                            <div className="text-4xl sm:text-5xl font-black text-slate-900 dark:text-white tracking-tight">
                                {score}%
                            </div>
                            <p className="text-xs text-slate-500 dark:text-slate-400 font-medium">
                                Penilaian otomatis berdasarkan kunci jawaban.
                            </p>
                        </div>
                    )}

                    {!showScore && (
                        <div className="p-4 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 rounded-2xl text-xs sm:text-sm text-slate-600 dark:text-slate-300 font-medium text-center">
                            Anda sudah submit. Terima kasih.
                        </div>
                    )}

                    {/* Action Buttons */}
                    <div className="flex flex-col sm:flex-row gap-3 pt-2">
                        <button
                            onClick={() => navigate(`/f/${formLink}`)}
                            className="flex-1 py-3 px-4 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer"
                        >
                            <RotateCcw size={14} /> Isi Lagi
                        </button>

                        <button
                            onClick={() => navigate(user ? '/dashboard' : '/login')}
                            className="flex-1 py-3 px-4 rounded-xl bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold shadow-xs transition-all flex items-center justify-center gap-2 cursor-pointer"
                        >
                            <Home size={14} /> {user ? 'Ke Dashboard' : 'Masuk FormUp'}
                        </button>
                    </div>

                    {/* Feedback Trigger */}
                    <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                        <button
                            onClick={() => setFeedbackOpen(!feedbackOpen)}
                            className="inline-flex items-center gap-1.5 text-xs font-bold text-slate-400 hover:text-slate-700 dark:hover:text-slate-300 transition-colors cursor-pointer"
                        >
                            <MessageSquare size={13} />
                            <span>Kirim Laporan / Masukan untuk Formulir Ini</span>
                        </button>
                    </div>
                </div>

                {/* Feedback Modal / Box */}
                 {feedbackOpen && (
                    <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 sm:p-8 shadow-lg space-y-4 animate-in fade-in zoom-in-95 duration-200">
                        <div className="flex items-center gap-2">
                            <AlertTriangle size={18} className="text-amber-500" />
                            <h3 className="text-sm font-bold text-slate-900 dark:text-white">Formulir Laporan & Masukan</h3>
                        </div>

                        {feedbackSuccess ? (
                            <div className="p-4 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 rounded-2xl text-xs font-bold text-emerald-600 dark:text-emerald-400">
                                {feedbackTarget === 'admin'
                                    ? 'Laporan Anda telah berhasil dikirimkan ke Admin FormUp untuk ditinjau. Terima kasih!'
                                    : 'Masukan Anda telah berhasil dikirimkan ke pembuat formulir. Terima kasih!'}
                            </div>
                        ) : (
                            <form onSubmit={handleSendFeedback} className="space-y-4">
                                {/* Target Pemilihan: Pemilik Formulir vs Admin FormUp */}
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">Tujuan Kirim</label>
                                    <div className="grid grid-cols-2 gap-2">
                                        <button
                                            type="button"
                                            onClick={() => handleChangeFeedbackTarget('owner')}
                                            className={`p-2.5 rounded-xl border text-xs font-bold text-center cursor-pointer transition-all ${
                                                feedbackTarget === 'owner'
                                                    ? 'bg-teal-50 dark:bg-teal-950/60 border-[#00897B] text-[#00897B] dark:text-teal-400'
                                                    : 'border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-800'
                                            }`}
                                        >
                                            Pemilik Formulir
                                        </button>
                                        <button
                                            type="button"
                                            onClick={() => handleChangeFeedbackTarget('admin')}
                                            className={`p-2.5 rounded-xl border text-xs font-bold text-center cursor-pointer transition-all ${
                                                feedbackTarget === 'admin'
                                                    ? 'bg-red-50 dark:bg-red-950/60 border-red-400 text-red-600 dark:text-red-400'
                                                    : 'border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-800'
                                            }`}
                                        >
                                            Laporkan ke Admin
                                        </button>
                                    </div>
                                    <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-1.5">
                                        {feedbackTarget === 'admin'
                                            ? 'Untuk pelanggaran serius (konten tidak pantas, spam, penyalahgunaan). Ditinjau langsung oleh tim Admin FormUp.'
                                            : 'Untuk kendala teknis, pertanyaan membingungkan, atau kunci jawaban yang salah. Dikirim langsung ke pembuat formulir.'}
                                    </p>
                                </div>

                                {feedbackError && (
                                    <div className="p-3 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">
                                        {feedbackError}
                                    </div>
                                )}

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                                        {feedbackTarget === 'admin' ? 'Kategori Laporan' : 'Alasan Masukan'}
                                    </label>
                                    <select
                                        value={reason}
                                        onChange={e => setReason(e.target.value)}
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    >
                                        {currentReasonOptions.map(opt => (
                                            <option key={opt.value} value={opt.value}>{opt.label}</option>
                                        ))}
                                    </select>
                                </div>

                                <div>
                                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                                    Deskripsi Tambahan (Opsional)
                                </label>

                                <textarea
                                    rows={3}
                                    value={description}
                                    onChange={(e) => setDescription(e.target.value)}
                                    placeholder={
                                        feedbackTarget === 'admin'
                                            ? 'Jelaskan pelanggaran yang Anda temukan...'
                                            : 'Jelaskan kendala atau masukan Anda...'
                                    }
                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl p-3 text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                />
                            </div>

                            <div className="flex justify-end gap-2">
                                <button
                                    type="button"
                                    onClick={() => setFeedbackOpen(false)}
                                    className="px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300"
                                >
                                    Batal
                                </button>

                                <button
                                    type="submit"
                                    disabled={sendingFeedback}
                                    className="px-5 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold disabled:opacity-60"
                                >
                                    {sendingFeedback ? 'Mengirim...' : 'Kirim'}
                                </button>
                            </div>

                            </form>
                            )}
                            </div>
                            )}

                {/* Detailed Answer Review Section - only visible when showScore is enabled */}
                {showScore && result?.answers && result.answers.length > 0 && (
                    <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 sm:p-8 shadow-xl space-y-4">
                        <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-4">
                            <div>
                                <h3 className="text-base font-extrabold text-slate-900 dark:text-white">Rincian Jawaban & Review Soal</h3>
                                <p className="text-xs text-slate-400 dark:text-slate-500">Tinjauan jawaban yang telah Anda kirimkan</p>
                            </div>
                            {showScore && result.correctCount != null && (
                                <span className="text-xs font-extrabold px-3 py-1 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-full border border-teal-200 dark:border-teal-800">
                                    Benar {result.correctCount} / {result.scorableQuestions || result.totalQuestions}
                                </span>
                            )}
                        </div>

                        <div className="space-y-4 pt-2">
                            {result.answers.map((a, i) => {
                                const isCorrect = showScore && a.isCorrect === true;
                                const isWrong = showScore && a.isCorrect === false;

                                return (
                                    <div key={i} className={`p-4 rounded-2xl border transition-all ${isCorrect ? 'bg-emerald-50/50 dark:bg-emerald-950/30 border-emerald-200 dark:border-emerald-800/60' : isWrong ? 'bg-red-50/50 dark:bg-red-950/30 border-red-200 dark:border-red-800/60' : 'bg-slate-50 dark:bg-slate-800/50 border-slate-200/80 dark:border-slate-700'}`}>
                                        <div className="flex items-start justify-between gap-3 mb-2">
                                            <div className="flex items-start gap-2 flex-1">
                                                <span className="font-extrabold text-slate-400 dark:text-slate-500 text-xs shrink-0">{i + 1}.</span>
                                                <RichContentRenderer content={a.question} format={a.questionFormat} className="text-xs font-bold text-slate-800 dark:text-slate-100" />
                                            </div>

                                            {showScore && a.isCorrect != null && (
                                                <span className={`text-[10px] font-extrabold px-2.5 py-0.5 rounded-full shrink-0 flex items-center gap-1 ${isCorrect ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-300' : 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300'}`}>
                                                    {isCorrect ? <><Check size={11} /> Benar</> : <><X size={11} /> Salah</>}
                                                </span>
                                            )}
                                        </div>

                                        <div className="pl-5 space-y-1 text-xs">
                                            <div className="flex items-baseline gap-2">
                                                <span className="text-slate-400 dark:text-slate-500 font-bold shrink-0">Jawaban Anda:</span>
                                                <RichContentRenderer content={a.optionText || a.answerText || '—'} format="text" className="font-bold text-slate-800 dark:text-slate-200" />
                                            </div>

                                            {showScore && isWrong && a.correctAnswer && (
                                                <div className="flex items-baseline gap-2 text-emerald-600 dark:text-emerald-400 pt-0.5">
                                                    <span className="font-bold shrink-0">Jawaban Benar:</span>
                                                    <RichContentRenderer content={a.correctAnswer} format="text" className="font-bold" />
                                                </div>
                                            )}

                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                )}

            </div>

            {/* Remedial / Practice Assistant Modal */}
            {remedialModalOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs" onClick={() => !remedialLoading && setRemedialModalOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 sm:p-8 max-w-2xl w-full shadow-2xl space-y-5 z-10 max-h-[90vh] flex flex-col">
                        {/* Header */}
                        <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
                            <div className="flex items-center gap-2.5">
                                <div className="p-2 rounded-xl bg-teal-50 dark:bg-teal-950/60 text-teal-600 dark:text-teal-400">
                                    <BookOpen size={20} />
                                </div>
                                <div>
                                    <h3 className="text-sm sm:text-base font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                                        Pembahasan Konsep & Latihan Soal
                                    </h3>
                                    <p className="text-xs text-slate-400">
                                        Bimbingan terstruktur untuk memahami konsep dasar dan latihan mandiri.
                                    </p>
                                </div>
                            </div>
                            <button
                                type="button"
                                onClick={() => setRemedialModalOpen(false)}
                                className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-xl cursor-pointer"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {/* Content Area */}
                        <div className="flex-1 overflow-y-auto space-y-5 pr-1">
                            {remedialLoading && (
                                <div className="py-16 text-center space-y-3">
                                    <Loader2 size={32} className="animate-spin mx-auto text-teal-600 dark:text-teal-400" />
                                    <p className="text-xs font-bold text-slate-600 dark:text-slate-300">
                                        Sedang menganalisis soal dan menyusun latihan pemahaman...
                                    </p>
                                </div>
                            )}

                            {remedialError && (
                                <div className="p-4 rounded-2xl bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 text-xs text-red-600 dark:text-red-400 space-y-2">
                                    <p className="font-bold">⚠️ Terjadi Kendala:</p>
                                    <p>{remedialError}</p>
                                    <button
                                        type="button"
                                        onClick={() => activeRemedialQuestion && handleOpenRemedial(activeRemedialQuestion)}
                                        className="px-3 py-1.5 bg-red-600 text-white rounded-xl text-xs font-bold cursor-pointer hover:bg-red-700 inline-flex items-center gap-1"
                                    >
                                        <RefreshCw size={12} /> Coba Lagi
                                    </button>
                                </div>
                            )}

                            {remedialData && (
                                <div className="space-y-5">
                                    {/* Question Reference Box */}
                                    <div className="p-3.5 bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-700 rounded-2xl space-y-1.5">
                                        <span className="text-[10px] uppercase tracking-wider font-extrabold text-slate-400">Soal yang dipelajari:</span>
                                        <div className="text-xs font-bold text-slate-800 dark:text-slate-200">
                                            <RichContentRenderer content={activeRemedialQuestion?.question || ''} />
                                        </div>
                                    </div>

                                    {/* 1. Concept Breakdown */}
                                    <div className="p-4 bg-teal-50/50 dark:bg-teal-950/30 border border-teal-200/80 dark:border-teal-800/60 rounded-2xl space-y-2">
                                        <div className="flex items-center gap-2 text-xs font-bold text-teal-800 dark:text-teal-300">
                                            <Lightbulb size={16} className="text-teal-600" />
                                            <span>Penjelasan & Pembahasan Konsep</span>
                                        </div>
                                        <div className="text-xs text-slate-700 dark:text-slate-200 leading-relaxed prose dark:prose-invert max-w-none">
                                            <RichContentRenderer content={remedialData.explanation} />
                                        </div>
                                    </div>

                                    {/* 2. Key Takeaways */}
                                    {remedialData.keyTakeaways && remedialData.keyTakeaways.length > 0 && (
                                        <div className="p-4 bg-amber-50/50 dark:bg-amber-950/30 border border-amber-200/80 dark:border-amber-800/60 rounded-2xl space-y-2">
                                            <div className="flex items-center gap-2 text-xs font-bold text-amber-800 dark:text-amber-300">
                                                <BookOpen size={16} className="text-amber-600" />
                                                <span>Poin Kunci & Rumus yang Perlu Diingat</span>
                                            </div>
                                            <ul className="list-disc list-inside text-xs text-slate-700 dark:text-slate-200 space-y-1 pl-1">
                                                {remedialData.keyTakeaways.map((item, kIdx) => (
                                                    <li key={kIdx} className="leading-relaxed">{item}</li>
                                                ))}
                                            </ul>
                                        </div>
                                    )}

                                    {/* 3. Interactive Practice Question */}
                                    {remedialData.practiceQuestion && (
                                        <div className="p-4 bg-white dark:bg-slate-800/70 border border-slate-200 dark:border-slate-700 rounded-2xl space-y-3 shadow-xs">
                                            <div className="flex items-center justify-between">
                                                <span className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                                                    <CheckCircle size={15} className="text-teal-600" /> Latihan Uji Pemahaman Mandiri
                                                </span>
                                                <span className="text-[10px] px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 font-bold">
                                                    1 Soal Cepat
                                                </span>
                                            </div>

                                            <p className="text-xs font-semibold text-slate-800 dark:text-slate-100">
                                                {remedialData.practiceQuestion.question}
                                            </p>

                                            <div className="space-y-1.5">
                                                {remedialData.practiceQuestion.options?.map((opt, oIdx) => {
                                                    const isSelected = practiceSelectedOption === oIdx;
                                                    let btnStyle = 'bg-slate-50 dark:bg-slate-900 border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 hover:border-teal-500';

                                                    if (practiceSubmitted) {
                                                        if (opt.isCorrect) {
                                                            btnStyle = 'bg-emerald-50 dark:bg-emerald-950/60 border-emerald-500 text-emerald-800 dark:text-emerald-200 font-bold';
                                                        } else if (isSelected && !opt.isCorrect) {
                                                            btnStyle = 'bg-red-50 dark:bg-red-950/60 border-red-500 text-red-800 dark:text-red-200 font-bold';
                                                        }
                                                    } else if (isSelected) {
                                                        btnStyle = 'bg-teal-50 dark:bg-teal-950/60 border-teal-500 text-teal-900 dark:text-teal-200 font-bold';
                                                    }

                                                    return (
                                                        <button
                                                            key={oIdx}
                                                            type="button"
                                                            disabled={practiceSubmitted}
                                                            onClick={() => setPracticeSelectedOption(oIdx)}
                                                            className={`w-full p-2.5 rounded-xl border text-xs text-left transition-all cursor-pointer flex items-center justify-between ${btnStyle}`}
                                                        >
                                                            <div className="flex items-center gap-2">
                                                                <span className="w-5 h-5 rounded-lg bg-black/5 dark:bg-white/10 flex items-center justify-center font-bold text-[10px] shrink-0">
                                                                    {String.fromCharCode(65 + oIdx)}
                                                                </span>
                                                                <span>{opt.optionText}</span>
                                                            </div>
                                                            {practiceSubmitted && opt.isCorrect && (
                                                                <Check size={14} className="text-emerald-600 shrink-0" />
                                                            )}
                                                        </button>
                                                    );
                                                })}
                                            </div>

                                            {!practiceSubmitted ? (
                                                <button
                                                    type="button"
                                                    disabled={practiceSelectedOption === null}
                                                    onClick={() => setPracticeSubmitted(true)}
                                                    className="w-full py-2 bg-teal-600 hover:bg-teal-700 disabled:opacity-50 text-white rounded-xl text-xs font-bold cursor-pointer transition-all shadow-xs"
                                                >
                                                    Periksa Jawaban
                                                </button>
                                            ) : (
                                                <div className="p-3 bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl space-y-1.5">
                                                    <p className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                                                        {remedialData.practiceQuestion.options[practiceSelectedOption]?.isCorrect ? (
                                                            <span className="text-emerald-600">🎉 Benar sekali! Pemahaman Anda sudah sangat baik.</span>
                                                        ) : (
                                                            <span className="text-red-500">💡 Belum tepat. Simak pembahasan berikut:</span>
                                                        )}
                                                    </p>
                                                    <p className="text-[11px] text-slate-500 dark:text-slate-400">
                                                        {remedialData.practiceQuestion.explanation}
                                                    </p>
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>
                            )}
                        </div>

                        {/* Footer */}
                        <div className="pt-2 border-t border-slate-100 dark:border-slate-800 flex justify-end">
                            <button
                                type="button"
                                onClick={() => setRemedialModalOpen(false)}
                                className="px-5 py-2.5 bg-slate-900 hover:bg-slate-800 dark:bg-slate-700 dark:hover:bg-slate-600 text-white rounded-xl text-xs font-bold cursor-pointer"
                            >
                                Tutup Pembahasan
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* API Key Modal if not set */}
            {remedialKeyPromptOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs" onClick={() => setRemedialKeyPromptOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 max-w-sm w-full shadow-2xl space-y-4 z-10">
                        <div className="flex items-center justify-between">
                            <span className="text-xs font-bold text-slate-800 dark:text-slate-200 flex items-center gap-1.5">
                                <ShieldCheck size={16} className="text-emerald-500" /> API Key Gemini Belum Diatur
                            </span>
                            <button
                                type="button"
                                onClick={() => setRemedialKeyPromptOpen(false)}
                                className="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
                            >
                                <X size={15} />
                            </button>
                        </div>
                        <p className="text-xs text-slate-500 dark:text-slate-400">
                            Fitur pembahasan materi memerlukan Google Gemini API Key. Silakan atur API Key Anda di halaman AI Assistant Chat.
                        </p>
                        <div className="flex items-center gap-2 pt-2">
                            <button
                                type="button"
                                onClick={() => setRemedialKeyPromptOpen(false)}
                                className="flex-1 py-2 bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 rounded-xl text-xs font-bold cursor-pointer"
                            >
                                Tutup
                            </button>
                            <Link
                                to="/ai-chat"
                                className="flex-1 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold text-center transition-colors inline-flex items-center justify-center gap-1"
                            >
                                Atur di AI Chat <ExternalLink size={12} />
                            </Link>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
