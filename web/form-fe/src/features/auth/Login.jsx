import { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [scale, setScale] = useState(() => {
        if (typeof window !== 'undefined') {
            return Math.max(window.innerWidth / 1728, 0.45);
        }
        return 1;
    });
    const navigate = useNavigate();

    useEffect(() => {
        const handleResize = () => {
            const baseWidth = 1728;
            const currentWidth = window.innerWidth;
            const calculatedScale = Math.max(currentWidth / baseWidth, 0.45);
            setScale(calculatedScale);
        };

        handleResize();
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    // Fungsi handleLogin yang diperbaiki
    const handleLogin = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;

            const response = await fetch(`${API_BASE_URL}/api/Auth/login`, {
                method: 'POST',
                headers: {
                    'accept': 'text/plain',
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    email: email,
                    password: password,
                }),
            });

            const responseText = await response.text();
            let data;
            try {
                data = JSON.parse(responseText);
            } catch {
                data = responseText;
            }

            if (response.ok) {
                // Ekstrak token dari string plain text atau JSON object
                const token = typeof data === 'string' ? data : (data.token || data.data?.token || data.accessToken);

                if (token) {
                    localStorage.setItem('token', token);
                    if (typeof data === 'object' && (data.user || data.data?.user)) {
                        localStorage.setItem('user', JSON.stringify(data.user || data.data?.user));
                    }
                    navigate('/dashboard');
                } else {
                    setError('Login berhasil, namun Token tidak ditemukan.');
                }
            } else {
                const errorMessage = typeof data === 'object' ? (data.message || data.title) : data;
                setError(errorMessage || 'Email atau password salah.');
            }
        } catch (err) {
            console.error('Error Login:', err);
            setError('Terjadi kesalahan koneksi ke server.');
        } finally {
            setLoading(false);
        }
    };

//  const handleLogin = (e) => {
//         e.preventDefault();
//         setLoading(true);

//         // Simpan dummy session ke localStorage
//         localStorage.setItem('token', 'dummy-token-bypass-12345');
//         localStorage.setItem(
//             'user', 
//             JSON.stringify({
//                 fullname: "John Doe",
//                 username: "johndoe",
//                 email: email || "john@example.com",
//                 password: 'john123'
//             })
//         );

//         setTimeout(() => {
//             setLoading(false);
//             navigate('/dashboard');
//         }, 400);
//     };

    return (
        <div className="w-screen h-screen overflow-hidden bg-[#004D4E] flex items-center justify-center select-none">
            <div 
                className="relative shrink-0 flex items-center justify-center"
                style={{
                    width: '2228px', 
                    height: '1117px',
                    transform: `scale(${scale})`,
                    transformOrigin: 'center center',
                    background: 'linear-gradient(200deg, #E1F9F4 0%, #E1F9F4 35%, #018081 75%, #004D4E 100%)'
                }}
            >

                <div
                    className="absolute pointer-events-none rounded-full"
                    style={{
                        width: '750px',
                        height: '750px',
                        top: '10px',
                        left: '50px',
                        background: 'linear-gradient(-143deg, #6FF6DF 0%, rgba(15, 136, 158, 0.7) 100%)',
                        opacity: 0.5,        
                        zIndex: 2
                    }}
                ></div>

                <div
                    className="absolute pointer-events-none rounded-full"
                    style={{
                        width: '750px',
                        height: '750px',
                        bottom: '-20px',
                        right: '120px',
                        background: 'linear-gradient(135deg, #6FF6DF 0%, rgba(10,29,93,0.7) 100%)',
                        zIndex: 3
                    }}
                ></div>

                <div className="relative z-10 w-full max-w-7xl px-16 flex flex-row items-center justify-between gap-12">
                    <div className="flex-1 flex flex-col justify-end text-white max-w-xl mt-40">
                        <h1 className="text-[56px] font-bold tracking-tight mb-4 leading-[1.1] text-white">
                            Create without limits
                        </h1>
                        <p className="text-[18px] text-white/95 font-medium leading-relaxed max-w-md">
                            Build forms, surveys, quizzes, and exams with a simple, intuitive experience.
                        </p>
                    </div>

                    <div className="w-full max-w-137.5 px-4">
                        <div className="w-full min-h-125 bg-white/20 backdrop-blur-[20px] border border-white/40 rounded-[28px] p-10 shadow-[0_8px_32px_0_rgba(0,0,0,0.1)] ml-30">
                            <div className="mb-6">
                                <h2 className="text-[32px] font-bold text-black tracking-tight mb-1">
                                    Welcome Back!
                                </h2>
                                <p className="text-[14px] font-bold text-gray-700/80">
                                    Sign in to access your FormUp workspace
                                </p>
                            </div>

                            {error && (
                                <div className="mb-3 px-4 py-2.5 bg-red-500/20 border border-red-400/50 rounded-xl">
                                    <p className="text-[13px] font-bold text-red-700">{error}</p>
                                </div>
                            )}

                            <form onSubmit={handleLogin} className="space-y-4">
                                <div>
                                    <label
                                        htmlFor="username"
                                        className="block text-[13px] font-extrabold text-gray-800 mb-1.5"
                                    >
                                        Email
                                    </label>
                                    <input
                                        id="username"
                                        type="text"
                                        placeholder="Input Your Email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="w-full px-4 py-3 rounded-xl border border-white/60 bg-white/40 text-gray-900 placeholder:text-gray-400 font-bold focus:outline-none focus:bg-white/60 focus:ring-2 focus:ring-[#16a096] transition-all text-[14px]"
                                    />
                                </div>

                                <div>
                                    <label
                                        htmlFor="password"
                                        className="block text-[13px] font-extrabold text-gray-800 mb-1.5"
                                    >
                                        Password
                                    </label>
                                    <input
                                        id="password"
                                        type="password"
                                        placeholder="Input Your Password"
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                        className="w-full px-4 py-3 rounded-xl border border-white/60 bg-white/40 text-gray-900 placeholder:text-gray-400 font-bold focus:outline-none focus:bg-white/60 focus:ring-2 focus:ring-[#16a096] transition-all text-[14px]"
                                    />
                                </div>

                                <button
                                    type="submit"
                                    disabled={loading}
                                    className="w-full mt-6 py-3.5 px-6 bg-[#14a098] hover:bg-[#118b84] active:scale-[0.98] text-white font-bold rounded-full shadow-[0_6px_20px_rgba(20,160,152,0.3)] transition-all duration-200 text-[15px] tracking-wide disabled:opacity-60 disabled:cursor-not-allowed"
                                >
                                    {loading ? 'Signing in...' : 'Login'}
                                </button>
                            </form>

                            <div className="mt-5 text-center flex flex-col items-center gap-0.5">
                                <span className="text-[12px] font-bold text-gray-600">New here?</span>
                                <Link
                                    to="/register"
                                    className="text-[13px] font-extrabold text-gray-800 hover:text-[#14a098] transition-colors"
                                >
                                    Create an account
                                </Link>
                            </div>

                        </div>
                    </div>

                </div>

            </div>
        </div>
    );
};

export default Login;