import { useState, useEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { login, saveSession, isAuthenticated } from '../../services/apiService';
import { Lock, Mail, Loader2, Eye, EyeOff, FileText, CheckCircle2, TrendingUp, ArrowRight, AlertCircle, X } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const Login = () => {
    const [showPassword, setShowPassword] = useState(false);
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [rememberMe, setRememberMe] = useState(true);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();
    const [searchParams] = useSearchParams();

    useEffect(() => {
        if (isAuthenticated()) {
            navigate('/dashboard', { replace: true });
        }
        const reason = searchParams.get('reason');
        if (reason === 'session_expired') {
            setError('Sesi Anda telah berakhir. Silakan login kembali.');
        }
    }, [navigate, searchParams]);

    useEffect(() => {
    if (error) {
        const timer = setTimeout(() => {
            setError('');
        }, 5000); 

        return () => clearTimeout(timer); // Bersihkan timer jika error berganti/unmount
        }
    }, [error]);

    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const result = await login(email.trim(), password);

            if (result.ok && result.data?.token) {
                saveSession(result.data, rememberMe);
                navigate('/dashboard');
            } else {
                setError(result.message || 'Email atau password salah.');
            }
        } catch (err) {
            console.error('Error Login:', err);
            setError('Terjadi kesalahan koneksi ke server.');
        } finally {
            setLoading(false);
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

            {/* ================= FLOATING ALERT NOTIFICATION (DENGAN ANIMASI) ================= */}
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


            {/* Main Content */}
            <main className="relative z-10 w-full max-w-7xl my-auto py-6 grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center">
                
                {/* ================= SEBELAH KIRI: VISUAL ================= */}
                <div className="hidden lg:flex lg:col-span-7 flex-col justify-center space-y-8 pr-6">
                    
                    {/* Judul Ringkas */}
                    <div className="space-y-3">
                        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-black/30 backdrop-blur-md border border-[#2ED8C3]/30 text-xs font-semibold text-[#2ED8C3]">
                            Platform Formulir Generasi Baru
                        </div>
                        <h1 className="text-4xl lg:text-5xl font-black text-white tracking-tight leading-tight drop-shadow-md">
                            Solusi Cerdas <br />
                            <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#2ED8C3] via-teal-100 to-white">
                                Pengelolaan Form.
                            </span>
                        </h1>
                    </div>

                    {/* Mockup Card */}
                    <div className="w-full max-w-lg pt-2">
                        <div className="p-6 rounded-3xl bg-black/40 border border-white/20 backdrop-blur-xl shadow-2xl space-y-5">
                            
                            {/* Card Top Header */}
                            <div className="flex items-center justify-between border-b border-white/10 pb-3">
                                <div className="flex items-center gap-3">
                                    <div className="w-8 h-8 rounded-lg bg-[#2ED8C3]/20 flex items-center justify-center text-[#2ED8C3]">
                                        <TrendingUp size={18} />
                                    </div>
                                    <div>
                                        <h4 className="text-xs font-bold text-white">Survei Kepuasan Pelanggan</h4>
                                        <p className="text-[10px] text-teal-100/70">Aktif • 1,240 Tanggapan</p>
                                    </div>
                                </div>
                                <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-[#2ED8C3]/20 text-[#2ED8C3]">
                                    +12% Jam Ini
                                </span>
                            </div>

                            {/* Progress Bar */}
                            <div className="space-y-2">
                                <div className="flex justify-between text-xs text-teal-100 font-medium">
                                    <span>Target Respon</span>
                                    <span className="text-[#2ED8C3] font-bold">85%</span>
                                </div>
                                <div className="h-2 w-full bg-black/50 rounded-full overflow-hidden border border-white/10">
                                    <div className="h-full bg-gradient-to-r from-[#0FA89E] to-[#2ED8C3] rounded-full w-[85%]" />
                                </div>
                            </div>

                            {/* Feature List */}
                            <div className="grid grid-cols-2 gap-3 pt-1">
                                <div className="flex items-center gap-2 text-xs text-teal-100">
                                    <CheckCircle2 size={14} className="text-[#2ED8C3]" />
                                    <span>Analitik Real-time</span>
                                </div>
                                <div className="flex items-center gap-2 text-xs text-teal-100">
                                    <CheckCircle2 size={14} className="text-[#2ED8C3]" />
                                    <span>Keamanan Enkripsi</span>
                                </div>
                            </div>

                        </div>
                    </div>

                </div>

                {/* ================= SEBELAH KANAN (Card Login) ================= */}
                <div className="w-full lg:col-span-5 flex justify-center lg:justify-end">
                    <div className="w-full max-w-md bg-black/45 backdrop-blur-2xl border border-white/20 rounded-[28px] p-6 sm:p-9 shadow-[0_25px_50px_rgba(0,0,0,0.7)] space-y-6">
                        
                        {/* Header Kartu */}
                        <div className="text-center lg:text-left">
                            <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight">
                                Selamat Datang
                            </h2>
                            <p className="text-xs sm:text-sm font-medium text-teal-100/80 mt-1">
                                Masuk untuk mengelola formulir Anda
                            </p>
                        </div>

                        <form onSubmit={handleLogin} className="space-y-4">
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
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-4 py-3 rounded-xl border border-teal-500/30 bg-black/60 text-white placeholder:text-teal-200/40 font-medium focus:outline-none focus:bg-black/80 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-teal-100 mb-1.5">
                                    Password
                                </label>
                                <div className="relative">
                                    <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-teal-200/60 pointer-events-none" />
                                    <input
                                        type={showPassword ? "text" : "password"}
                                        placeholder="Kata sandi"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-10 py-3 rounded-xl border border-teal-500/30 bg-black/60 text-white placeholder:text-white-300/40 font-medium focus:outline-none focus:bg-black/80 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                    
                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white-500/40 hover:text-white transition-colors cursor-pointer p-0.5 focus:outline-none"
                                        tabIndex="-1"
                                    >   
                                        {showPassword ? (
                                            <EyeOff size={16} />
                                        ) : (
                                            <Eye size={16} />
                                        )}
                                    </button>
                                </div>
                            </div>

                            <div className="flex items-center justify-between pt-1">
                                <label className="flex items-center gap-2 cursor-pointer select-none">
                                    <input
                                        type="checkbox"
                                        checked={rememberMe}
                                        onChange={(e) => setRememberMe(e.target.checked)}
                                        className="w-4 h-4 rounded text-[#0FA89E] focus:ring-[#0FA89E] accent-[#0FA89E] bg-black/60 border-teal-500/40 cursor-pointer"
                                    />
                                    <span className="text-xs font-medium text-teal-100/90">Ingat Saya</span>
                                </label>
                                <Link
                                    to="/forgot-password"
                                    className="text-xs font-medium text-teal-200 hover:text-[#2ED8C3] transition-colors underline-offset-2 hover:underline"
                                >
                                    Lupa password?
                                </Link>
                            </div>

                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full mt-4 py-3.5 px-6 bg-[#0FA89E] hover:bg-[#12bdae] active:scale-[0.98] text-white font-bold rounded-full transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
                            >
                                {loading ? (
                                    <>
                                        <Loader2 size={16} className="animate-spin" />
                                        <span>Memproses...</span>
                                    </>
                                ) : (
                                    <>
                                        <span>Masuk</span>
                                        <ArrowRight size={16} />
                                    </>
                                )}
                            </button>
                        </form>

                        <div className="text-center pt-3 border-t border-white/10">
                            <span className="text-xs font-medium text-teal-100/70">Belum punya akun? </span>
                            <Link
                                to="/register"
                                className="text-xs ml-1 font-bold text-[#2ED8C3] hover:underline transition-all"
                            >
                                Daftar Sekarang
                            </Link>
                        </div>

                    </div>
                </div>

            </main>

            {/* Footer */}
            <footer className="relative z-10 w-full text-center py-2">
                <p className="text-xs font-medium text-teal-100/60">
                    &copy; {new Date().getFullYear()} FormUp. All rights reserved.
                </p>
            </footer>
        </div>
    );
};

export default Login;