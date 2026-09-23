import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { 
    ArrowLeft, 
    Mail, 
    KeyRound, 
    RefreshCw, 
    CheckCircle, 
    Loader2, 
    Eye, 
    EyeOff, 
    AlertCircle, 
    X 
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
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

    // Auto Dismiss Error Alert setelah 5 detik
    useEffect(() => {
        if (error) {
            const timer = setTimeout(() => {
                setError('');
            }, 5000);
    
            return () => clearTimeout(timer);
        }
    }, [error]);

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
<div className="min-h-screen h-full w-full bg-[#003839] flex flex-col justify-between items-center p-4 sm:p-6 lg:p-8 relative overflow-hidden select-none font-sans"> 
  
  {/* Background Gradient Base */}
  <div 
    className="absolute inset-0 pointer-events-none"
    style={{
      background: 'linear-gradient(200deg, #1fa393 0%, #0d7069 40%, #004D4E 75%, #002b2c 100%)'
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
      background: 'radial-gradient(circle, rgba(46, 216, 195, 0.45) 0%, rgba(10, 95, 110, 0) 70%)',
      filter: 'blur(40px)',
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
      background: 'radial-gradient(circle, rgba(46, 216, 195, 0.35) 0%, rgba(10, 29, 93, 0) 70%)',
      filter: 'blur(40px)',
      zIndex: 1
    }}
  />

  {/* Floating Animated Error Alert Toast */}
  <AnimatePresence>
    {error && (
      <motion.div 
        initial={{ opacity: 0, y: -50, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: -20, scale: 0.95 }}
        transition={{ duration: 0.3, ease: 'easeOut' }}
        className="fixed top-5 left-1/2 -translate-x-1/2 z-50 w-[90%] max-w-lg"
      >
        <div className="flex items-center justify-between gap-3 p-4 rounded-2xl bg-red-950/80 border border-red-500/50 backdrop-blur-xl text-red-100 shadow-[0_10px_30px_rgba(239,68,68,0.3)]">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-red-500/20 text-red-400 shrink-0">
              <AlertCircle size={20} />
            </div>
            <p className="text-xs sm:text-sm font-semibold tracking-wide">{error}</p>
          </div>
          <button
            type="button"
            onClick={() => setError('')}
            className="p-1.5 rounded-lg text-red-300 hover:text-white hover:bg-red-500/20 transition-colors shrink-0 cursor-pointer"
            aria-label="Tutup alert"
          >
            <X size={16} />
          </button>
        </div>
      </motion.div>
    )}
  </AnimatePresence>

  {/* Container Utama */}
  <div className="relative z-10 w-full max-w-md my-auto px-4">
    {/* Card Container Utama (Styling disesuaikan dengan Login & Register) */}
    <div className="w-full max-w-md bg-black/45 backdrop-blur-2xl border border-white/20 rounded-[28px] p-6 sm:p-9 shadow-[0_25px_50px_rgba(0,0,0,0.7)] space-y-6">
      
      {/* Header */}
      <div>
        <Link 
          to="/login" 
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#2ED8C3] hover:text-[#52e7d4] hover:underline mb-4 transition-all"
        >
          <ArrowLeft size={14} /> Kembali ke Login
        </Link>
        
        <div className="flex items-center gap-3 mb-2">
          <div className="w-10 h-10 bg-[#2ED8C3]/10 border border-[#2ED8C3]/30 rounded-xl flex items-center justify-center text-[#2ED8C3] shrink-0 shadow-inner">
            <KeyRound size={20} />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">Lupa Password</h1>
        </div>
        
        <p className="text-xs font-medium text-slate-300 leading-relaxed mt-1">
          {step === 1
            ? 'Masukkan email Anda dan kami akan mengirimkan kode OTP.'
            : `Kode OTP telah dikirim ke ${email}. Berlaku 15 menit.`
          }
        </p>
      </div>

      {/* Step Indicator */}
      <div className="flex items-center gap-2">
        {[1, 2].map(s => (
          <div 
            key={s} 
            className={`flex-1 h-1.5 rounded-full transition-all duration-300 ${s <= step ? 'bg-[#2ED8C3] shadow-[0_0_8px_rgba(46,216,195,0.6)]' : 'bg-white/10'}`} 
          />
        ))}
        <span className="text-xs font-bold text-slate-400 shrink-0 ml-1">{step}/2</span>
      </div>

      {/* Step 1: Email Form */}
      {step === 1 && (
        <form onSubmit={handleSendOtp} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-200 mb-1.5">
              Email Terdaftar
            </label>
            <div className="relative flex items-center">
              <Mail size={16} className="absolute left-3.5 text-slate-400 pointer-events-none" />
              <input
                type="email"
                required
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="nama@email.com"
                className="w-full pl-10 pr-4 py-3 rounded-xl border border-white/15 bg-black/40 text-white placeholder:text-slate-500 font-medium focus:outline-none focus:bg-black/70 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full mt-2 py-3.5 bg-[#0FA89E] hover:bg-[#12bdae] active:scale-[0.99] text-white font-bold rounded-full shadow-[0_4px_20px_rgba(15,168,158,0.35)] transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
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

      {/* Step 2: OTP + Password Baru Form */}
      {step === 2 && (
        <form onSubmit={handleResetPassword} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-200 mb-1.5">
              Kode OTP (6 digit)
            </label>
            <input
              type="text"
              required
              maxLength={6}
              value={otp}
              onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
              placeholder="123456"
              className="w-full px-3.5 py-3 rounded-xl border border-white/15 bg-black/40 text-white placeholder:text-slate-500 font-mono tracking-[0.25em] text-center focus:outline-none focus:bg-black/70 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-base font-semibold transition-all shadow-inner"
            />
          </div>

          {/* Input Password Baru */}
          <div>
            <label className="block text-xs font-semibold text-slate-200 mb-1.5">
              Password Baru
            </label>
            <div className="relative flex items-center">
              <input
                type={showPassword ? "text" : "password"}
                required
                value={newPassword}
                onChange={e => setNewPassword(e.target.value)}
                placeholder="Minimal 8 karakter"
                className="w-full pl-4 pr-10 py-3 rounded-xl border border-white/15 bg-black/40 text-white placeholder:text-slate-500 font-medium focus:outline-none focus:bg-black/70 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3.5 text-slate-400 hover:text-white transition-colors cursor-pointer p-0.5"
                tabIndex="-1"
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          {/* Input Konfirmasi Password */}
          <div>
            <label className="block text-xs font-semibold text-slate-200 mb-1.5">
              Konfirmasi Password Baru
            </label>
            <div className="relative flex items-center">
              <input
                type={showConfirmPassword ? "text" : "password"}
                required
                value={confirmPassword}
                onChange={e => setConfirmPassword(e.target.value)}
                placeholder="Ulangi password baru"
                className={`w-full pl-4 pr-10 py-3 rounded-xl border bg-black/40 text-white placeholder:text-slate-500 font-medium focus:outline-none focus:bg-black/70 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner ${
                  confirmPassword && confirmPassword !== newPassword 
                    ? 'border-red-500/50 bg-red-950/20' 
                    : 'border-white/15'
                }`}
              />
              <button
                type="button"
                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                className="absolute right-3.5 text-slate-400 hover:text-white transition-colors cursor-pointer p-0.5"
                tabIndex="-1"
              >
                {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full mt-2 py-3.5 bg-[#0FA89E] hover:bg-[#12bdae] active:scale-[0.99] text-white font-bold rounded-full shadow-[0_4px_20px_rgba(15,168,158,0.35)] transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
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
            className="w-full flex items-center justify-center gap-1.5 text-xs font-semibold text-[#2ED8C3] hover:text-[#52e7d4] hover:underline pt-1 transition-colors cursor-pointer"
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