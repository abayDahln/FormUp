import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { register } from '../../services/apiService';
import { FileText, ArrowRight, User, Mail, Lock, Calendar, Loader2, Eye, EyeOff } from 'lucide-react';

const Register = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [fullname, setFullname] = useState('');
    const [username, setUsername] = useState('');
    const [birthdate, setBirthdate] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    // State untuk toggle visibilitas password
    const [showPassword, setShowPassword] = useState(false);
    const [showConfirmPassword, setShowConfirmPassword] = useState(false);

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
        <div className="relative z-10 w-full max-w-6xl flex flex-col lg:flex-row items-center justify-between gap-8 lg:gap-12 my-auto">
            
            {/* Left side branding */}
            <div className="w-full lg:w-1/2 text-white space-y-4 text-center lg:text-left">
                {/* <div className="inline-flex items-center gap-2.5 px-4 py-2 bg-white/10 backdrop-blur-md rounded-2xl border border-white/20">
                    <FileText size={20} className="text-[#2ED8C3]" />
                    <span className="font-extrabold text-sm tracking-wide">FormUp Registration</span>
                </div> */}
                <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-tight text-white">
                    Mulai Bersama FormUp
                </h1>
                <p className="text-base sm:text-lg text-white/95 font-medium leading-relaxed max-w-lg mx-auto lg:mx-0">
                    Daftar akun gratis dan buat berbagai formulir, survei, serta ujian daring dengan mudah.
                </p>
            </div>

            {/* Right side form card */}
            <div className="w-full lg:w-1/2 max-w-lg">
                <div className="w-full bg-black/40 backdrop-blur-[20px] border border-white/10 rounded-[28px] p-6 sm:p-10 shadow-[0_8px_32px_0_rgba(0,0,0,0.37)] space-y-6">
                    <div>
                        <h2 className="text-2xl sm:text-3xl font-bold text-white tracking-tight">
                            Buat Akun Baru
                        </h2>
                        <p className="text-xs sm:text-sm font-medium text-white/70 mt-1">
                            Lengkapi data di bawah ini untuk memulai
                        </p>
                    </div>

                    {error && (
                        <div className="p-3.5 bg-red-500/20 border border-red-500/30 rounded-xl">
                            <p className="text-xs font-bold text-red-300 text-center">{error}</p>
                        </div>
                    )}

                    <form onSubmit={handleRegister} className="space-y-4">
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    Nama Lengkap
                                </label>
                                <div className="relative">
                                    <User size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none" />
                                    <input
                                        type="text"
                                        placeholder="Nama Lengkap"
                                        value={fullname}
                                        onChange={(e) => setFullname(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-3.5 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    Username
                                </label>
                                <div className="relative">
                                    <input
                                        type="text"
                                        placeholder="username"
                                        value={username}
                                        onChange={(e) => setUsername(e.target.value)}
                                        required
                                        className="w-full px-3.5 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    Email
                                </label>
                                <div className="relative">
                                    <Mail size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none" />
                                    <input
                                        type="email"
                                        placeholder="nama@email.com"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-3.5 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    Tanggal Lahir
                                </label>
                                <div className="relative">
                                    <input
                                        type="date"
                                        value={birthdate}
                                        onChange={(e) => setBirthdate(e.target.value)}
                                        required
                                        className="w-full px-3.5 py-3 rounded-xl border border-white/10 bg-black/30 text-white font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner [color-scheme:dark]"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    Password
                                </label>
                                <div className="relative">
                                    <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none" />
                                    <input
                                        type={showPassword ? "text" : "password"}
                                        placeholder="Min. 8 karakter"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-10 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white/50 hover:text-white transition-colors cursor-pointer p-0.5 focus:outline-none"
                                        tabIndex="-1"
                                    >
                                        {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                                    </button>
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-semibold text-white/90 mb-1.5">
                                    Ulangi Password
                                </label>
                                <div className="relative">
                                    <Lock size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-white/50 pointer-events-none" />
                                    <input
                                        type={showConfirmPassword ? "text" : "password"}
                                        placeholder="Ulangi password"
                                        value={confirmPassword}
                                        onChange={(e) => setConfirmPassword(e.target.value)}
                                        required
                                        className="w-full pl-10 pr-10 py-3 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/40 font-medium focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] text-xs sm:text-sm transition-all shadow-inner"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-white/50 hover:text-white transition-colors cursor-pointer p-0.5 focus:outline-none"
                                        tabIndex="-1"
                                    >
                                        {showConfirmPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                                    </button>
                                </div>
                            </div>
                        </div>

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full mt-4 py-3.5 px-6 bg-[#0FA89E] hover:bg-[#0d968d] active:scale-[0.98] text-white font-bold rounded-full shadow-[0_6px_20px_rgba(15,168,158,0.4)] transition-all duration-200 text-xs sm:text-sm tracking-wide disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer flex items-center justify-center gap-2"
                        >
                            {loading ? (
                                <>
                                    <Loader2 size={16} className="animate-spin" />
                                    <span>Mendaftarkan Akun...</span>
                                </>
                            ) : (
                                <>
                                    <span>Daftar Sekarang</span>
                                </>
                            )}
                        </button>
                    </form>

                    <div className="text-center pt-3 border-t border-white/10">
                        <span className="text-xs font-medium text-white/70">Sudah punya akun? </span>
                        <Link
                            to="/login"
                            className="text-xs font-bold text-[#2ED8C3] hover:underline transition-all"
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