import { useState, useEffect } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router-dom';
import {
    CheckCircle2, Award, Home, RotateCcw, AlertTriangle,
    Send, Loader2, MessageSquare, Check, X
} from 'lucide-react';
import {
    getPublicResponseResult, getPublicFormByLink, submitFeedback,
    getLocalUser
} from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function FormResultPage() {
    const { formLink, responseId } = useParams();
    const navigate = useNavigate();
    const location = useLocation();

    const [form, setForm] = useState(null);
    const [result, setResult] = useState(null);
    const [loading, setLoading] = useState(true);

    // Feedback State
    const [feedbackOpen, setFeedbackOpen] = useState(false);
    const [reason, setReason] = useState('PERTANYAAN_TIDAK_JELAS');
    const [description, setDescription] = useState('');
    const [sendingFeedback, setSendingFeedback] = useState(false);
    const [feedbackSuccess, setFeedbackSuccess] = useState(false);
    const [feedbackError, setFeedbackError] = useState('');

    const user = getLocalUser();

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
        });
        setSendingFeedback(false);

        if (res.ok) {
            setFeedbackSuccess(true);
            setDescription('');
        } else {
            setFeedbackError(res.message || 'Gagal mengirimkan masukan.');
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

    const showScore = form?.showScore || form?.settings?.showScore || result?.showScore;
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
                                Masukan Anda telah berhasil dikirimkan ke pembuat formulir. Terima kasih!
                            </div>
                        ) : (
                            <form onSubmit={handleSendFeedback} className="space-y-4">
                                {feedbackError && (
                                    <div className="p-3 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">
                                        {feedbackError}
                                    </div>
                                )}

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Alasan Laporan</label>
                                    <select
                                        value={reason}
                                        onChange={e => setReason(e.target.value)}
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    >
                                        <option value="PERTANYAAN_TIDAK_JELAS">Pertanyaan tidak jelas atau membingungkan</option>
                                        <option value="KUNCI_JAWABAN_SALAH">Kunci jawaban dinilai salah</option>
                                        <option value="KENDALA_TEKNIS">Kendala teknis saat pengisian</option>
                                        <option value="KONTEN_TIDAK_PANTAS">Konten mengandung unsur tidak pantas</option>
                                        <option value="LAINNYA">Alasan lainnya</option>
                                    </select>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Deskripsi Tambahan (Opsional)</label>
                                    <textarea
                                        rows={3}
                                        value={description}
                                        onChange={e => setDescription(e.target.value)}
                                        placeholder="Jelaskan detail kendala atau saran Anda..."
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl p-3 text-xs bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>

                                <div className="flex justify-end gap-2">
                                    <button
                                        type="button"
                                        onClick={() => setFeedbackOpen(false)}
                                        className="px-4 py-2 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-50"
                                    >
                                        Batal
                                    </button>
                                    <button
                                        type="submit"
                                        disabled={sendingFeedback}
                                        className="px-5 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-1.5 cursor-pointer disabled:opacity-60"
                                    >
                                        <Send size={13} /> {sendingFeedback ? 'Mengirim...' : 'Kirim Masukan'}
                                    </button>
                                </div>
                            </form>
                        )}
                    </div>
                )}

                {/* Detailed Answer Review Section */}
                {result?.answers && result.answers.length > 0 && (
                    <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl p-6 sm:p-8 shadow-xl space-y-4">
                        <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-4">
                            <div>
                                <h3 className="text-base font-extrabold text-slate-900 dark:text-white">Rincian Jawaban & Review Soal</h3>
                                <p className="text-xs text-slate-400 dark:text-slate-500">Tinjauan jawaban yang telah Anda kirimkan</p>
                            </div>
                            {result.correctCount != null && (
                                <span className="text-xs font-extrabold px-3 py-1 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-full border border-teal-200 dark:border-teal-800">
                                    Benar {result.correctCount} / {result.scorableQuestions || result.totalQuestions}
                                </span>
                            )}
                        </div>

                        <div className="space-y-4 pt-2">
                            {result.answers.map((a, i) => {
                                const isCorrect = a.isCorrect === true;
                                const isWrong = a.isCorrect === false;

                                return (
                                    <div key={i} className={`p-4 rounded-2xl border transition-all ${isCorrect ? 'bg-emerald-50/50 dark:bg-emerald-950/30 border-emerald-200 dark:border-emerald-800/60' : isWrong ? 'bg-red-50/50 dark:bg-red-950/30 border-red-200 dark:border-red-800/60' : 'bg-slate-50 dark:bg-slate-800/50 border-slate-200/80 dark:border-slate-700'}`}>
                                        <div className="flex items-start justify-between gap-3 mb-2">
                                            <div className="flex items-start gap-2 flex-1">
                                                <span className="font-extrabold text-slate-400 dark:text-slate-500 text-xs shrink-0">{i + 1}.</span>
                                                <RichContentRenderer content={a.question} format={a.questionFormat} className="text-xs font-bold text-slate-800 dark:text-slate-100" />
                                            </div>

                                            {a.isCorrect != null && (
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

                                            {isWrong && a.correctAnswer && (
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
        </div>
    );
}
