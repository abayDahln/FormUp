import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { register } from '../../services/apiService';
import { 
  ArrowRight, 
  User, 
  Mail, 
  Lock, 
  Loader2, 
  Eye, 
  EyeOff, 
  AlertCircle,
  Sparkles,
  ShieldCheck,
  Zap,
  X
} from 'lucide-react';

const EMOJI_REGEX = /[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\uFE0F]/gu;
const NAME_REGEX = /^[a-zA-Z\s.'-]+$/;

const Register = () => {
  const [fullname, setFullname] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const navigate = useNavigate();

  // Auto Dismiss Error Alert setelah 5 detik
  useEffect(() => {
    if (error) {
      const timer = setTimeout(() => {
        setError('');
      }, 5000);

      return () => clearTimeout(timer);
    }
  }, [error]);

  const handleRegister = async (e) => {
    e.preventDefault();
    setError('');

    const trimmedFullname = fullname.trim();
    const trimmedEmail = email.trim();

    // Validasi Emoji pada Nama
    if (EMOJI_REGEX.test(trimmedFullname)) {
      setError('Nama tidak boleh mengandung emoji.');
      return;
    }

    // Validasi Emoji pada Email
    if (EMOJI_REGEX.test(trimmedEmail)) {
      setError('Email tidak boleh mengandung emoji.');
      return;
    }

    // Validasi Format Nama
    if (!NAME_REGEX.test(trimmedFullname)) {
      setError('Nama lengkap hanya boleh berisi huruf, spasi, titik, apostrof, & strip.');
      return;
    }

    // Validasi Kesesuaian Password
    if (password !== confirmPassword) {
      setError('Password dan Konfirmasi Password tidak cocok.');
      return;
    }

    // Validasi Panjang Password
    if (password.length < 8) {
      setError('Password minimal 8 karakter.');
      return;
    }

    setLoading(true);
    const result = await register(trimmedFullname, trimmedEmail, password);
    setLoading(false);

    if (result.ok && result.status === 200) {
      navigate('/verify', {
        state: { fullname: trimmedFullname, email: trimmedEmail, password }
      });
    } else {
      setError(result.message || 'Registrasi gagal. Silakan coba lagi.');
    }
  };

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

      {/* Main Container Grid Layout */}
      <main className="relative z-10 w-full max-w-7xl my-auto py-6 grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
        
        {/* ================= SEBELAH KIRI: VISUAL MODERN & SIMPLE ================= */}
        <div className="hidden lg:flex lg:col-span-7 flex-col justify-between py-4 pr-10 text-white min-h-[480px]">
          
          {/* Header Brand Simple */}
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-white/10 backdrop-blur-md rounded-full border border-white/15 text-[#2ED8C3] text-xs font-semibold tracking-wide uppercase mb-6">
              <Sparkles size={14} className="animate-pulse" />
              <span>FormUp Platform</span>
            </div>

            <h1 className="text-4xl lg:text-5xl font-black tracking-tight leading-none">
              Kelola Form & Ujian <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#2ED8C3] to-[#80FFF0]">
                Tanpa Ribet.
              </span>
            </h1>
          </div>

          {/* Interactive Glass Cards Visual */}
          <div className="relative w-full my-auto py-6">
            {/* Card 1 - Main Stat Card */}
            <div className="w-64 bg-white/10 backdrop-blur-xl border border-white/20 p-4 rounded-2xl shadow-2xl space-y-2 transform -rotate-2 hover:rotate-0 transition-all duration-300">
              <div className="flex items-center justify-between">
                <span className="text-xs text-white/70 font-medium">Respons Realtime</span>
                <span className="w-2 h-2 rounded-full bg-[#2ED8C3] animate-ping" />
              </div>
              <p className="text-2xl font-bold text-white tracking-tight">100% Real-time</p>
              <p className="text-[10px] text-white/50">Otomatis tersimpan secara aman</p>
            </div>

            {/* Card 2 - Floating Badge */}
            <div className="absolute top-10 left-48 bg-[#2ED8C3]/20 backdrop-blur-xl border border-[#2ED8C3]/40 px-4 py-3 rounded-2xl shadow-xl flex items-center gap-3 transform rotate-3 hover:rotate-0 transition-all duration-300">
              <div className="p-2 bg-[#2ED8C3] rounded-xl text-[#002b2c]">
                <ShieldCheck size={18} />
              </div>
              <div>
                <p className="text-xs font-bold text-white">Sistem Keamanan</p>
                <p className="text-[10px] text-white/70">Data Terenkripsi</p>
              </div>
            </div>
          </div>

          {/* Footer Feature Badges Simple */}
          <div className="flex items-center gap-6 border-t border-white/10 pt-6">
            <div className="flex items-center gap-2 text-xs font-semibold text-white/80">
              <Zap size={16} className="text-[#2ED8C3]" />
              <span>Cepat & Praktis</span>
            </div>
            <div className="w-1 h-1 rounded-full bg-white/30" />
            <div className="flex items-center gap-2 text-xs font-semibold text-white/80">
              <ShieldCheck size={16} className="text-[#2ED8C3]" />
              <span>Privasi Terjaga</span>
            </div>
          </div>

        </div>

        {/* ================= SEBELAH KANAN: CARD REGISTER GELAP ================= */}
        <div className="w-full lg:col-span-5 flex justify-center lg:justify-end">
          <div className="w-full max-w-md bg-black/45 backdrop-blur-2xl border border-white/20 rounded-[28px] p-6 sm:p-9 shadow-[0_25px_50px_rgba(0,0,0,0.7)] space-y-5">
            
            {/* Header Kartu */}
            <div className="text-center lg:text-left">
              <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight">
                Buat Akun Baru
              </h2>
              <p className="text-xs sm:text-sm font-medium text-teal-100/80 mt-1">
                Lengkapi data untuk memulai
              </p>
            </div>

            {/* Form Input */}
            <form onSubmit={handleRegister} className="space-y-3.5">
              
              {/* Nama Lengkap */}
              <div>
                <label className="block text-xs font-semibold text-teal-100 mb-1.5">
                  Nama Lengkap
                </label>
                <div className="relative">
                  <User size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-teal-200/60 pointer-events-none" />
                  <input
                    type="text"
                    placeholder="Nama Lengkap"
                    value={fullname}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (!EMOJI_REGEX.test(val) && /^[a-zA-Z\s.'-]*$/.test(val)) {
                        setFullname(val);
                      }
                    }}
                    required
                    className="w-full pl-10 pr-4 py-3 rounded-xl border border-teal-500/30 bg-black/60 text-white placeholder:text-teal-200/40 font-medium focus:outline-none focus:bg-black/80 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                  />
                </div>
              </div>

              {/* Email */}
              <div>
                <label className="block text-xs font-semibold text-teal-100 mb-1.5">
                  Email
                </label>
                <div className="relative">
                  <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-teal-200/60 pointer-events-none" />
                  <input
                    type="email"
                    placeholder="Email"
                    value={email}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (!EMOJI_REGEX.test(val)) {
                        setEmail(val);
                      }
                    }}
                    required
                    className="w-full pl-10 pr-4 py-3 rounded-xl border border-teal-500/30 bg-black/60 text-white placeholder:text-teal-200/40 font-medium focus:outline-none focus:bg-black/80 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                  />
                </div>
              </div>

              {/* Password */}
              <div>
                <label className="block text-xs font-semibold text-teal-100 mb-1.5">
                  Password
                </label>
                <div className="relative">
                  <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-teal-200/60 pointer-events-none" />
                  <input
                    type={showPassword ? "text" : "password"}
                    placeholder="Kata sandi (Min. 8 karakter)"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    required
                    className="w-full pl-10 pr-10 py-3 rounded-xl border border-teal-500/30 bg-black/60 text-white placeholder:text-teal-200/40 font-medium focus:outline-none focus:bg-black/80 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white/40 hover:text-white transition-colors cursor-pointer p-0.5 focus:outline-none"
                    tabIndex="-1"
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              {/* Confirm Password */}
              <div>
                <label className="block text-xs font-semibold text-teal-100 mb-1.5">
                  Konfirmasi Password
                </label>
                <div className="relative">
                  <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-teal-200/60 pointer-events-none" />
                  <input
                    type={showConfirmPassword ? "text" : "password"}
                    placeholder="Ulangi kata sandi"
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    required
                    className="w-full pl-10 pr-10 py-3 rounded-xl border border-teal-500/30 bg-black/60 text-white placeholder:text-teal-200/40 font-medium focus:outline-none focus:bg-black/80 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                  />
                  <button
                    type="button"
                    onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white/40 hover:text-white transition-colors cursor-pointer p-0.5 focus:outline-none"
                    tabIndex="-1"
                  >
                    {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                disabled={loading}
                className="w-full mt-4 py-3.5 px-6 bg-[#0FA89E] hover:bg-[#12bdae] active:scale-[0.98] text-white font-bold rounded-full transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
              >
                {loading ? (
                  <>
                    <Loader2 size={16} className="animate-spin" />
                    <span>Mendaftarkan...</span>
                  </>
                ) : (
                  <>
                    <span>Daftar Sekarang</span>
                    <ArrowRight size={16} />
                  </>
                )}
              </button>
            </form>

            {/* Footer Link */}
            <div className="text-center pt-3 border-t border-white/10">
              <span className="text-xs font-medium text-teal-100/70">Sudah punya akun? </span>
              <Link
                to="/login"
                className="text-xs ml-1 font-bold text-[#2ED8C3] hover:underline transition-all"
              >
                Masuk ke sini
              </Link>
            </div>

          </div>
        </div>

      </main>
    </div>
  );
};

export default Register;