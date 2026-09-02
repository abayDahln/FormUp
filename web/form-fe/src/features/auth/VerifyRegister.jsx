import { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { verifyRegistration } from '../../services/apiService';
import { FileText, ArrowRight, User, Mail, Lock, Calendar, Loader2, Eye, EyeOff } from 'lucide-react';


const VerifyRegister = () => {
    const [otp, setOtp] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    
    const location = useLocation();
    const navigate = useNavigate();
    
    // Menangkap data dari halaman Register
    const userData = location.state;

    // Jika tidak ada data (user langsung tembak URL /verify), kembalikan ke register
    useEffect(() => {
        if (!userData) {
            navigate('/register');
        }
    }, [userData, navigate]);

    const handleVerify = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        const result = await verifyRegistration(
            userData.fullname,
            userData.username,
            userData.email,
            userData.password,
            userData.birthdate,
            otp
        );
        setLoading(false);

        // Cek sukses verifikasi
        if (result.ok && result.data?.token) {
            navigate('/login');
        } else {
            setError(result.message || 'Verifikasi OTP gagal. Coba lagi.');
        }
    };

    if (!userData) return null;

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

        {/* Card Verifikasi */}
        <div className="relative z-10 w-full max-w-md my-auto">
            <div className="w-full bg-black/40 backdrop-blur-[20px] border border-white/10 rounded-[28px] p-6 sm:p-8 shadow-[0_8px_32px_0_rgba(0,0,0,0.37)] space-y-6">
                
                <div className="text-center space-y-2">
                    <h2 className="text-2xl sm:text-[28px] font-bold text-white tracking-tight">
                        Verifikasi Email
                    </h2>
                    <p className="text-xs sm:text-sm font-medium text-white/70">
                        Masukkan 6 digit kode OTP yang dikirim ke <span className="text-[#2ED8C3] font-semibold">{userData?.email}</span>
                    </p>
                </div>

                {error && (
                    <div className="p-3.5 bg-red-500/20 border border-red-500/30 rounded-xl">
                        <p className="text-xs font-bold text-red-300 text-center">{error}</p>
                    </div>
                )}

                <form onSubmit={handleVerify} className="space-y-6">
                    <div>
                        <input
                            type="text"
                            placeholder="123456"
                            value={otp}
                            onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                            required
                            maxLength={6}
                            className="w-full px-4 py-3.5 sm:py-4 rounded-xl border border-white/10 bg-black/30 text-white placeholder:text-white/30 font-mono tracking-[0.5em] text-center focus:outline-none focus:bg-black/50 focus:border-[#2ED8C3] focus:ring-1 focus:ring-[#2ED8C3] transition-all text-lg sm:text-xl shadow-inner"
                        />
                    </div>

                    <button
                        type="submit"
                        disabled={loading}
                        className="w-full py-3.5 px-6 bg-[#0FA89E] hover:bg-[#0d968d] active:scale-[0.98] disabled:opacity-60 text-white font-bold rounded-full shadow-[0_6px_20px_rgba(15,168,158,0.4)] transition-all duration-200 text-xs sm:text-sm tracking-wide cursor-pointer disabled:cursor-not-allowed flex items-center justify-center gap-2"
                    >
                        {loading ? (
                            <>
                                <Loader2 size={16} className="animate-spin" />
                                <span>Memverifikasi...</span>
                            </>
                        ) : (
                            <span>Verifikasi & Lanjutkan</span>
                        )}
                    </button>
                </form>

            </div>
        </div>
    </div>
);
};

export default VerifyRegister;