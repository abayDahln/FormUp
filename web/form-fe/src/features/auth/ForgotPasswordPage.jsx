import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft, Mail, KeyRound, RefreshCw, CheckCircle } from 'lucide-react';
import { forgotPassword, resetPassword } from '../../services/apiService';

export default function ForgotPasswordPage() {
    const navigate = useNavigate();

    // Step 1: Email input | Step 2: OTP + new password
    const [step, setStep] = useState(1);
    const [email, setEmail] = useState('');
    const [otp, setOtp] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState(false);

    const handleSendOtp = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);
        const res = await forgotPassword(email);
        setLoading(false);
        if (res.ok) {
            setStep(2);
        } else {
            setError(res.message || 'Email tidak ditemukan.');
        }
    };

    const handleResetPassword = async (e) => {
        e.preventDefault();
        setError('');
        if (newPassword !== confirmPassword) {
            setError('Password baru dan konfirmasi tidak cocok.');
            return;
        }
        if (newPassword.length < 8) {
            setError('Password minimal 8 karakter.');
            return;
        }
        setLoading(true);
        const res = await resetPassword(email, otp, newPassword);
        setLoading(false);
        if (res.ok) {
            setSuccess(true);
        } else {
            setError(res.message || 'OTP salah atau kadaluarsa.');
        }
    };

    // ── Success State ──
    if (success) return (
        <div className="min-h-screen w-full bg-gradient-to-br from-[#E1F9F4] via-[#a8e8e0] to-[#004D4E] flex items-center justify-center p-4 font-sans py-8">
            <div className="bg-white/80 dark:bg-slate-900/90 backdrop-blur-xl border border-white/60 dark:border-slate-800 rounded-3xl p-8 sm:p-10 max-w-sm w-full text-center shadow-2xl space-y-5">
                <div className="w-14 h-14 bg-teal-100 dark:bg-teal-950/60 text-teal-600 dark:text-teal-400 rounded-full flex items-center justify-center mx-auto">
                    <CheckCircle size={28} />
                </div>
                <div>
                    <h2 className="text-xl font-extrabold text-slate-900 dark:text-white">Password Berhasil Diubah!</h2>
                    <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">Silakan login dengan password baru Anda.</p>
                </div>
                <button
                    onClick={() => navigate('/login')}
                    className="w-full py-3 bg-[#00897B] hover:bg-[#00796B] text-white font-bold rounded-2xl transition-all cursor-pointer shadow-md"
                >
                    Kembali ke Login
                </button>
            </div>
        </div>
    );

    return (
        <div className="min-h-screen w-full bg-gradient-to-br from-[#E1F9F4] via-[#a8e8e0] to-[#004D4E] flex items-center justify-center p-4 font-sans py-8">
            <div className="bg-white/80 dark:bg-slate-900/90 backdrop-blur-xl border border-white/60 dark:border-slate-800 rounded-3xl p-6 sm:p-8 max-w-sm w-full shadow-2xl">

                {/* Header */}
                <div className="mb-7">
                    <Link to="/login" className="flex items-center gap-1.5 text-xs font-bold text-teal-700 hover:text-teal-900 mb-5 transition-colors">
                        <ArrowLeft size={14} /> Kembali ke Login
                    </Link>
                    <div className="flex items-center gap-3 mb-1">
                        <div className="w-9 h-9 bg-teal-100 text-teal-600 rounded-xl flex items-center justify-center">
                            <KeyRound size={18} />
                        </div>
                        <h1 className="text-xl font-extrabold text-slate-900">Lupa Password</h1>
                    </div>
                    <p className="text-xs text-slate-500 ml-12">
                        {step === 1
                            ? 'Masukkan email Anda dan kami akan mengirimkan kode OTP.'
                            : `Kode OTP telah dikirim ke ${email}. Berlaku 15 menit.`
                        }
                    </p>
                </div>

                {/* Step Indicator */}
                <div className="flex items-center gap-2 mb-6">
                    {[1, 2].map(s => (
                        <div key={s} className={`flex-1 h-1 rounded-full transition-all ${s <= step ? 'bg-teal-500' : 'bg-slate-200'}`} />
                    ))}
                    <span className="text-xs font-bold text-slate-400 shrink-0">{step}/2</span>
                </div>

                {error && (
                    <div className="mb-4 px-4 py-2.5 bg-red-50 border border-red-200 rounded-xl">
                        <p className="text-xs font-bold text-red-600">{error}</p>
                    </div>
                )}

                {/* Step 1: Email */}
                {step === 1 && (
                    <form onSubmit={handleSendOtp} className="space-y-4">
                        <div>
                            <label className="block text-xs font-bold text-slate-700 mb-1.5">
                                <Mail size={12} className="inline mr-1" />Email Terdaftar
                            </label>
                            <input
                                type="email"
                                required
                                value={email}
                                onChange={e => setEmail(e.target.value)}
                                placeholder="contoh@email.com"
                                className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                            />
                        </div>
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full mt-2 py-3 bg-teal-600 hover:bg-teal-700 text-white font-bold rounded-2xl shadow transition-all disabled:opacity-60 text-sm"
                        >
                            {loading ? 'Mengirim OTP...' : 'Kirim Kode OTP'}
                        </button>
                    </form>
                )}

                {/* Step 2: OTP + New Password */}
                {step === 2 && (
                    <form onSubmit={handleResetPassword} className="space-y-4">
                        <div>
                            <label className="block text-xs font-bold text-slate-700 mb-1.5">Kode OTP (6 digit)</label>
                            <input
                                type="text"
                                required
                                maxLength={6}
                                value={otp}
                                onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
                                placeholder="123456"
                                className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm font-mono tracking-widest text-center focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                            />
                        </div>
                        <div>
                            <label className="block text-xs font-bold text-slate-700 mb-1.5">Password Baru</label>
                            <input
                                type="password"
                                required
                                value={newPassword}
                                onChange={e => setNewPassword(e.target.value)}
                                placeholder="Minimal 8 karakter"
                                className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                            />
                        </div>
                        <div>
                            <label className="block text-xs font-bold text-slate-700 mb-1.5">Konfirmasi Password Baru</label>
                            <input
                                type="password"
                                required
                                value={confirmPassword}
                                onChange={e => setConfirmPassword(e.target.value)}
                                placeholder="Ulangi password baru"
                                className={`w-full border rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all ${confirmPassword && confirmPassword !== newPassword ? 'border-red-300 bg-red-50' : 'border-slate-200'}`}
                            />
                        </div>
                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full py-3 bg-teal-600 hover:bg-teal-700 text-white font-bold rounded-2xl shadow transition-all disabled:opacity-60 text-sm"
                        >
                            {loading ? 'Menyimpan...' : 'Reset Password'}
                        </button>
                        <button
                            type="button"
                            onClick={() => { setStep(1); setOtp(''); setNewPassword(''); setConfirmPassword(''); setError(''); }}
                            className="w-full flex items-center justify-center gap-1.5 text-xs font-bold text-teal-700 hover:text-teal-900 mt-1 transition-colors"
                        >
                            <RefreshCw size={12} /> Kirim Ulang OTP
                        </button>
                    </form>
                )}
            </div>
        </div>
    );
}
