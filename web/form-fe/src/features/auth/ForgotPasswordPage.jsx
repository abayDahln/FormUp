import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ArrowLeft, Mail, KeyRound, RefreshCw, CheckCircle, Loader2, Eye, EyeOff } from 'lucide-react';
import { forgotPassword, resetPassword } from '../../services/apiService';

export default function ForgotPasswordPage() {
    const navigate = useNavigate();

    // Step 1: Email input | Step 2: OTP + new password
    const [step, setStep] = useState(1);
    const [email, setEmail] = useState('');
    const [otp, setOtp] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    
    // State toggle mata password
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);

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
            <div className="h-screen max-h-screen w-full bg-[#004D4E] flex items-center justify-center p-4 sm:p-6 lg:p-12 relative overflow-hidden select-none touch-none"> 
            {/* Background Gradien Utama */}
            <div 
                className="absolute inset-0 pointer-events-none"
                style={{
                    background: 'linear-gradient(200deg, #2ED8C3 0%, #0FA89E 35%, #018081 75%, #004D4E 100%)'
                }}
            />

            {/* Bulatan Gradien Kiri Atas */}
            <div
                className="absolute pointer-events-none rounded-full"
                style={{
                    width: 'clamp(350px, 45vw, 750px)',
                    height: 'clamp(350px, 45vw, 750px)',
                    top: '-10%',
                    left: '-10%',
                    background: 'linear-gradient(-143deg, #2ED8C3 0%, rgba(10, 95, 110, 0.7) 100%)',
                    opacity: 0.6,
                    zIndex: 1
                }}
            />

            {/* Bulatan Gradien Kanan Bawah */}
            <div
                className="absolute pointer-events-none rounded-full"
                style={{
                    width: 'clamp(350px, 45vw, 750px)',
                    height: 'clamp(350px, 45vw, 750px)',
                    bottom: '-10%',
                    right: '-10%',
                    background: 'linear-gradient(135deg, #2ED8C3 0%, rgba(10, 29, 93, 0.7) 100%)',
                    opacity: 0.8,
                    zIndex: 1
                }}
            />

            {/* Container Utama */}
            <div className="relative z-10 w-full max-w-md my-auto">
                <div className="w-full bg-black/40 backdrop-blur-[20px] border border-white/10 rounded-[28px] p-6 sm:p-8 shadow-[0_8px_32px_0_rgba(0,0,0,0.37)] space-y-6">
                    
                    {/* Header */}
                    <div>
                        <Link to="/login" className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#2ED8C3] hover:underline mb-4 transition-all">
                            <ArrowLeft size={14} /> Kembali ke Login
                        </Link>
                        <div className="flex items-center gap-3 mb-2">
                            <div className="w-10 h-10 bg-white/10 border border-white/20 rounded-xl flex items-center justify-center text-[#2ED8C3] shrink-0">
                                <KeyRound size={20} />
                            </div>
                            <h1 className="text-2xl font-bold text-white tracking-tight">Lupa Password</h1>
                        </div>
                        <p className="text-xs font-medium text-white/70">
                            {step === 1
                                ? 'Masukkan email Anda dan kami akan mengirimkan kode OTP.'
                                : `Kode OTP telah dikirim ke ${email}. Berlaku 15 menit.`
                            }
                        </p>
                    </div>

                    {/* Step Indicator */}
                    <div className="flex items-center gap-2">
                        {[1, 2].map(s => (
                            <div key={s} className={`flex-1 h-1.5 rounded-full transition-all ${s <= step ? 'bg-[#2ED8C3]' : 'bg-white/20'}`} />
                        ))}
                        <span className="text-xs font-bold text-white/50 shrink-0">{step}/2</span>
                    </div>

                    {error && (
                        <div className="p-3.5 bg-red-500/20 border border-red-500/30 rounded-xl">
                            <p className="text-xs font-bold text-red-300 text-center">{error}</p>
                        </div>
                    )}

                    {/* Step 1: Email */}
                    {step === 1 && (
                        <form onSubmit={handleSendOtp} className="space-y-4">
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    <Mail size={12} className="inline mr-1 text-[#2ED8C3]" />Email Terdaftar
                                </label>
                                <input
                                    type="email"
                                    required
                                    value={email}
                                    onChange={e => setEmail(e.target.value)}
                                    placeholder="nama@email.com"
                                    className="w-full px-3.5 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                />
                            </div>
                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full mt-2 py-3.5 bg-[#0FA89E] hover:bg-[#0d968d] active:scale-[0.98] text-white font-bold rounded-full shadow-[0_6px_20px_rgba(15,168,158,0.4)] transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
                            >
                                {loading ? (
                                    <>
                                        <Loader2 size={16} className="animate-spin" />
                                        <span>Mengirim OTP...</span>
                                    </>
                                ) : (
                                    <span>Kirim Kode OTP</span>
                                )}
                            </button>
                        </form>
                    )}

                    {/* Step 2: OTP + New Password */}
                    {step === 2 && (
                        <form onSubmit={handleResetPassword} className="space-y-4">
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">Kode OTP (6 digit)</label>
                                <input
                                    type="text"
                                    required
                                    maxLength={6}
                                    value={otp}
                                    onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
                                    placeholder="123456"
                                    className="w-full px-3.5 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-mono tracking-widest text-center focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-sm transition-all shadow-inner"
                                />
                            </div>

                            {/* Input Password Baru */}
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">Password Baru</label>
                                <div className="relative flex items-center">
                                    <input
                                        type={showPassword ? "text" : "password"}
                                        required
                                        value={newPassword}
                                        onChange={e => setNewPassword(e.target.value)}
                                        placeholder="Minimal 8 karakter"
                                        className="w-full px-3.5 py-3 pr-10 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        className="absolute right-3 text-white/50 hover:text-white transition-colors cursor-pointer"
                                    >
                                        {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                                    </button>
                                </div>
                            </div>

                            {/* Input Konfirmasi Password */}
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">Konfirmasi Password Baru</label>
                                <div className="relative flex items-center">
                                    <input
                                        type={showConfirmPassword ? "text" : "password"}
                                        required
                                        value={confirmPassword}
                                        onChange={e => setConfirmPassword(e.target.value)}
                                        placeholder="Ulangi password baru"
                                        className={`w-full px-3.5 py-3 pr-10 rounded-xl border bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner ${confirmPassword && confirmPassword !== newPassword ? 'border-red-500/50 bg-red-500/10' : 'border-white/10'}`}
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                                        className="absolute right-3 text-white/50 hover:text-white transition-colors cursor-pointer"
                                    >
                                        {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                                    </button>
                                </div>
                            </div>

                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full py-3.5 bg-[#0FA89E] hover:bg-[#0d968d] active:scale-[0.98] text-white font-bold rounded-full shadow-[0_6px_20px_rgba(15,168,158,0.4)] transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
                            >
                                {loading ? (
                                    <>
                                        <Loader2 size={16} className="animate-spin" />
                                        <span>Menyimpan...</span>
                                    </>
                                ) : (
                                    <span>Reset Password</span>
                                )}
                            </button>
                            <button
                                type="button"
                                onClick={() => { setStep(1); setOtp(''); setNewPassword(''); setConfirmPassword(''); setError(''); }}
                                className="w-full flex items-center justify-center gap-1.5 text-xs font-semibold text-[#2ED8C3] hover:underline pt-1 transition-colors cursor-pointer"
                            >
                                <RefreshCw size={12} /> Kirim Ulang OTP
                            </button>
                        </form>
                    )}
                </div>
            </div>
        </div>
    );
}