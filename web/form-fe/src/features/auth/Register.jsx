import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { register } from '../../services/apiService';
import { FileText, ArrowRight, User, Mail, Lock, Calendar, Loader2 } from 'lucide-react';

const Register = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [fullname, setFullname] = useState('');
    const [username, setUsername] = useState('');
    const [birthdate, setBirthdate] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const navigate = useNavigate();

    const handleRegister = async (e) => {
        e.preventDefault();
        setError('');

        if (password !== confirmPassword) {
            setError('Password dan Konfirmasi Password tidak cocok.');
            return;
        }

        if (password.length < 8) {
            setError('Password minimal 8 karakter.');
            return;
        }

        setLoading(true);
        const result = await register(fullname.trim(), username.trim(), email.trim(), password, birthdate);
        setLoading(false);

        if (result.ok && result.status === 200) {
            navigate('/verify', {
                state: { fullname: fullname.trim(), username: username.trim(), email: email.trim(), password, birthdate }
            });
        } else {
            setError(result.message || 'Registrasi gagal. Silakan coba lagi.');
        }
    };

    return (
        <div className="min-h-screen w-full bg-gradient-to-br from-[#E1F9F4] via-[#018081] to-[#004D4E] flex items-center justify-center p-4 sm:p-6 lg:p-12 relative overflow-x-hidden py-10">
            {/* Background glow elements */}
            <div className="absolute top-10 left-10 w-72 h-72 sm:w-96 sm:h-96 rounded-full bg-teal-300/30 blur-3xl pointer-events-none" />
            <div className="absolute bottom-10 right-10 w-72 h-72 sm:w-96 sm:h-96 rounded-full bg-teal-900/40 blur-3xl pointer-events-none" />

            <div className="relative z-10 w-full max-w-5xl flex flex-col lg:flex-row items-center justify-between gap-8 lg:gap-12 my-auto">
                {/* Left side branding */}
                <div className="w-full lg:w-1/2 text-white space-y-4 text-center lg:text-left">
                    <div className="inline-flex items-center gap-2.5 px-4 py-2 bg-white/10 backdrop-blur-md rounded-2xl border border-white/20">
                        <FileText size={20} className="text-teal-200" />
                        <span className="font-extrabold text-sm tracking-wide">FormUp Registration</span>
                    </div>
                    <h1 className="text-3xl sm:text-4xl lg:text-5xl font-extrabold tracking-tight leading-tight text-white">
                        Mulai Bersama FormUp
                    </h1>
                    <p className="text-sm sm:text-base text-teal-50/90 font-medium leading-relaxed max-w-lg mx-auto lg:mx-0">
                        Daftar akun gratis dan buat berbagai formulir, survei, serta ujian daring dengan mudah.
                    </p>
                </div>

                {/* Right side form card */}
                <div className="w-full lg:w-1/2 max-w-lg">
                    <div className="w-full bg-white/25 dark:bg-slate-900/60 backdrop-blur-xl border border-white/40 dark:border-slate-800 rounded-3xl p-6 sm:p-8 shadow-2xl space-y-5">
                        <div>
                            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">
                                Buat Akun Baru
                            </h2>
                            <p className="text-xs sm:text-sm font-semibold text-slate-700 dark:text-slate-300 mt-1">
                                Lengkapi data di bawah ini untuk memulai
                            </p>
                        </div>

                        {error && (
                            <div className="p-3.5 bg-red-500/20 border border-red-400/50 rounded-2xl">
                                <p className="text-xs font-bold text-red-700 dark:text-red-300 text-center">{error}</p>
                            </div>
                        )}

                        <form onSubmit={handleRegister} className="space-y-3.5">
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                                <div>
                                    <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1">
                                        Nama Lengkap
                                    </label>
                                    <div className="relative">
                                        <User size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400 pointer-events-none" />
                                        <input
                                            type="text"
                                            placeholder="Nama Lengkap"
                                            value={fullname}
                                            onChange={(e) => setFullname(e.target.value)}
                                            required
                                            className="w-full pl-9 pr-3.5 py-2.5 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1">
                                        Username
                                    </label>
                                    <div className="relative">
                                        <input
                                            type="text"
                                            placeholder="username"
                                            value={username}
                                            onChange={(e) => setUsername(e.target.value)}
                                            required
                                            className="w-full px-3.5 py-2.5 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                        />
                                    </div>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                                <div>
                                    <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1">
                                        Email
                                    </label>
                                    <div className="relative">
                                        <Mail size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400 pointer-events-none" />
                                        <input
                                            type="email"
                                            placeholder="nama@email.com"
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            required
                                            className="w-full pl-9 pr-3.5 py-2.5 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1">
                                        Tanggal Lahir
                                    </label>
                                    <div className="relative">
                                        <input
                                            type="date"
                                            value={birthdate}
                                            onChange={(e) => setBirthdate(e.target.value)}
                                            required
                                            className="w-full px-3.5 py-2.5 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                        />
                                    </div>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                                <div>
                                    <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1">
                                        Password
                                    </label>
                                    <div className="relative">
                                        <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400 pointer-events-none" />
                                        <input
                                            type="password"
                                            placeholder="Min. 8 karakter"
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            required
                                            className="w-full pl-9 pr-3.5 py-2.5 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-extrabold text-slate-800 dark:text-slate-200 mb-1">
                                        Ulangi Password
                                    </label>
                                    <div className="relative">
                                        <Lock size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400 pointer-events-none" />
                                        <input
                                            type="password"
                                            placeholder="Ulangi password"
                                            value={confirmPassword}
                                            onChange={(e) => setConfirmPassword(e.target.value)}
                                            required
                                            className="w-full pl-9 pr-3.5 py-2.5 rounded-2xl border border-white/60 dark:border-slate-700 bg-white/60 dark:bg-slate-800/80 text-slate-900 dark:text-white placeholder:text-slate-400 font-semibold focus:outline-none focus:ring-2 focus:ring-[#00897B] text-xs sm:text-sm transition-all shadow-xs"
                                        />
                                    </div>
                                </div>
                            </div>

                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full mt-2 py-3.5 px-6 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.99] text-white font-bold rounded-2xl shadow-lg transition-all text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
                            >
                                {loading ? (
                                    <>
                                        <Loader2 size={16} className="animate-spin" />
                                        <span>Mendaftarkan Akun...</span>
                                    </>
                                ) : (
                                    <>
                                        <span>Daftar Sekarang</span>
                                        <ArrowRight size={16} />
                                    </>
                                )}
                            </button>
                        </form>

                        <div className="text-center pt-2 border-t border-white/20 dark:border-slate-800">
                            <span className="text-xs font-medium text-slate-700 dark:text-slate-400">Sudah punya akun? </span>
                            <Link
                                to="/login"
                                className="text-xs font-extrabold text-teal-900 dark:text-teal-300 hover:underline transition-colors"
                            >
                                Masuk ke Sini
                            </Link>
                        </div>

                    </div>
                </div>
            </div>
        </div>
    );
};

export default Register;