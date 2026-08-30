import { useState, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { verifyRegistration } from '../../services/apiService';

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
        <div className="min-h-screen w-full flex items-center justify-center bg-slate-900 select-none relative p-4 py-8">
            {/* Background Style */}
            <div className="absolute inset-0 z-0" style={{ background: 'linear-gradient(200deg, #E1F9F4 0%, #018081 50%, #004D4E 100%)', opacity: 0.8 }}></div>
            
            {/* Card Verifikasi */}
            <div className="relative z-10 w-full max-w-md">
                <div className="w-full bg-white/20 backdrop-blur-[20px] border border-white/40 rounded-[28px] p-6 sm:p-10 shadow-[0_8px_32px_0_rgba(0,0,0,0.1)]">
                    
                    <div className="mb-6 text-center">
                        <h2 className="text-2xl sm:text-[28px] font-bold text-black tracking-tight">
                            Verifikasi Email
                        </h2>
                        <p className="text-xs sm:text-[14px] font-bold text-gray-700/80 mt-1">
                            Masukkan 6 digit kode OTP yang dikirim ke {userData?.email}
                        </p>
                    </div>

                    {error && (
                        <div className="mb-4 px-4 py-2.5 bg-red-500/20 border border-red-400/50 rounded-xl">
                            <p className="text-xs font-bold text-red-700 text-center">{error}</p>
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
                                className="w-full px-4 py-3.5 sm:py-4 rounded-xl border border-white/60 bg-white/40 text-gray-900 placeholder:text-gray-400 font-extrabold text-center tracking-[0.5em] focus:outline-none focus:bg-white/60 focus:ring-2 focus:ring-[#00897B] transition-all text-lg sm:text-[20px]"
                            />
                        </div>

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full py-3.5 px-6 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.98] disabled:opacity-70 text-white font-bold rounded-full shadow-[0_6px_20px_rgba(20,160,152,0.3)] transition-all duration-200 text-xs sm:text-[15px] tracking-wide cursor-pointer"
                        >
                            {loading ? 'Memverifikasi...' : 'Verifikasi & Lanjutkan'}
                        </button>
                    </form>

                </div>
            </div>
        </div>
    );
};

export default VerifyRegister;