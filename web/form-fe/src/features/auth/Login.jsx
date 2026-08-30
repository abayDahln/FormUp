import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { login, saveSession, isAuthenticated } from '../../services/apiService';
import { FileText, ArrowRight, Lock, Mail, Loader2 } from 'lucide-react';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [rememberMe, setRememberMe] = useState(true);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    useEffect(() => {
        if (isAuthenticated()) {
            navigate('/dashboard', { replace: true });
        }
    }, [navigate]);

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
        <div className="min-h-screen w-full bg-gradient-to-br from-[#E1F9F4] via-[#018081] to-[#004D4E] flex items-center justify-center p-4 sm:p-6 lg:p-12 relative overflow-x-hidden">
            {/* Background glow elements */}
            <div className="absolute top-10 left-10 w-72 h-72 sm:w-96 sm:h-96 rounded-full bg-teal-300/30 blur-3xl pointer-events-none" />
            <div className="absolute bottom-10 right-10 w-72 h-72 sm:w-96 sm:h-96 rounded-full bg-teal-900/40 blur-3xl pointer-events-none" />

            <div className="relative z-10 w-full max-w-5xl flex flex-col lg:flex-row items-center justify-between gap-8 lg:gap-12 my-auto">
                {/* Left side branding */}
                <div className="w-full lg:w-1/2 text-white space-y-4 text-center lg:text-left">
                    <div className="inline-flex items-center gap-2.5 px-4 py-2 bg-white/10 backdrop-blur-md rounded-2xl border border-white/20">
                        <FileText size={20} className="text-teal-200" />
                        <span className="font-extrabold text-sm tracking-wide">FormUp Workspace</span>
                    </div>
                    <h1 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight leading-tight text-white">
                        Create without limits
                    </h1>
                    <p className="text-sm sm:text-base text-teal-50/90 font-medium leading-relaxed max-w-lg mx-auto lg:mx-0">
                        Buat formulir, kuis interaktif, survei, dan evaluasi dengan pengalaman yang cepat, fleksibel, dan responsif.
                    </p>
                </div>

                {/* Right side form card */}
                <div className="w-full lg:w-1/2 max-w-md">
                    <div className="w-full bg-white/25 dark:bg-slate-900/60 backdrop-blur-xl border border-white/40 dark:border-slate-800 rounded-3xl p-6 sm:p-8 shadow-2xl space-y-6">
                        <div>
                            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
                                Selamat Datang!
                            </h2>
                            <p className="text-xs sm:text-sm font-semibold text-slate-700 dark:text-slate-300 mt-1">
                                Masuk ke akun Anda untuk mengakses formulir dan respons
                            </p>
                        </div>

                        {error && (
                            <div className="p-3.5 bg-red-500/20 border border-red-400/50 rounded-2xl">
                                <p className="text-xs font-bold text-red-700 dark:text-red-300 text-center">{error}</p>
                            </div>
                        )}

                        <form onSubmit={handleLogin} className="space-y-4">
                            <div>
                                <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1.5">
                                    Email
                                </label>
                                <div className="relative">
                                    <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400 pointer-events-none" />
                                    <input
                                        type="email"
                                        placeholder="nama@email.com"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-4 py-3 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1.5">
                                    Password
                                </label>
                                <div className="relative">
                                    <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400 pointer-events-none" />
                                    <input
                                        type="password"
                                        placeholder="••••••••"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-4 py-3 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                    />
                                </div>
                            </div>

                            <div className="flex items-center justify-between pt-1">
                                <label className="flex items-center gap-2 cursor-pointer select-none">
                                    <input
                                        type="checkbox"
                                        checked={rememberMe}
                                        onChange={(e) => setRememberMe(e.target.checked)}
                                        className="w-4 h-4 rounded text-[#00897B] focus:ring-[#00897B] cursor-pointer"
                                    />
                                    <span className="text-xs font-bold text-slate-700 dark:text-slate-300">Ingat Saya</span>
                                </label>
                                <Link
                                    to="/forgot-password"
                                    className="text-xs font-bold text-teal-800 dark:text-teal-300 hover:underline transition-colors"
                                >
                                    Lupa password?
                                </Link>
                            </div>

                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full mt-4 py-3.5 px-6 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.99] text-white font-bold rounded-2xl shadow-lg transition-all text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
                            >
                                {loading ? (
                                    <>
                                        <Loader2 size={16} className="animate-spin" />
                                        <span>Memproses...</span>
                                    </>
                                ) : (
                                    <>
                                        <span>Masuk ke Akun</span>
                                        <ArrowRight size={16} />
                                    </>
                                )}
                            </button>
                        </form>

                        <div className="text-center pt-2 border-t border-white/20 dark:border-slate-800">
                            <span className="text-xs font-medium text-slate-700 dark:text-slate-400">Belum punya akun? </span>
                            <Link
                                to="/register"
                                className="text-xs font-extrabold text-teal-900 dark:text-teal-300 hover:underline transition-colors"
                            >
                                Daftar Sekarang
                            </Link>
                        </div>

                    </div>
                </div>
            </div>
        </div>
    );
};

export default Login;