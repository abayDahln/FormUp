import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

const Login = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const navigate = useNavigate();

    const handleLogin = (e) => {
        e.preventDefault();
        navigate('/dashboard');
    };

    return (
        <div className="relative w-screen h-screen overflow-hidden flex items-center justify-center select-none bg-slate-900">
            
            <div 
                className="absolute w-[1728px] h-[1117px] overflow-hidden flex items-center justify-center"
                style={{
                    // Gradasi Background Utama: Atas-Kiri (#E1F9F4) ke Bawah-Kanan (#018081)
                    background: 'linear-gradient(200deg, #E1F9F4 0%, #E1F9F4 35%, #018081 75%, #004D4E 100%)'               
                }}
            >

                {/* LAYER 2: Ellipse 4 - Bola Biru Tua Atas Kiri (Dekat / Dimajuin) */}
                <div
                    className="absolute pointer-events-none rounded-full"
                    style={{
                        width: '700px',
                        height: '700px',
                        top: '10px',
                        left: '50px',
                        background: 'linear-gradient(160deg, rgba(21, 61, 195, 0.48) 9%, #0A1D5D 100%)',                        opacity: 0.8,
                        zIndex: 2
                    }}
                ></div>

                {/* LAYER 3: Ellipse 5 - Bola Mint Toska Bawah Kanan (Maju) */}
                <div
                    className="absolute pointer-events-none rounded-full"
                    style={{
                        width: '700px',
                        height: '700px',
                        bottom: '-20px',
                        right: '120px',
                        background: 'linear-gradient(135deg, #6FF6DF 0%, rgba(10,29,93,0.7) 100%)',
                        zIndex: 3
                    }}
                ></div>


                {/* LAYER 4 (Paling Depan): Konten Utama & Form Card */}
                <div className="relative z-10 w-full max-w-[1280px] px-16 flex flex-row items-center justify-between gap-12">

                    <div className="flex-1 flex flex-col justify-end text-white max-w-xl mt-50">
                        <h1 className="text-[56px] font-bold tracking-tight mb-4 leading-[1.1] text-white">
                            Create without limits
                        </h1>
                        <p className="text-[18px] text-white/95 font-medium leading-relaxed max-w-md">
                            Build forms, surveys, quizzes, and exams with a simple, intuitive experience.
                        </p>
                    </div>

                    {/* Form Card Glassmorphism */}
                    <div className="w-[420px]">
                        <div className="w-full bg-white/20 backdrop-blur-[20px] border border-white/40 rounded-[28px] p-9 shadow-[0_8px_32px_0_rgba(0,0,0,0.1)]">

                            <div className="mb-6">
                                <h2 className="text-[32px] font-bold text-black tracking-tight mb-1">
                                    Welcome Back!
                                </h2>
                                <p className="text-[14px] font-bold text-gray-700/80">
                                    Sign in to access your FormUp workspace
                                </p>
                            </div>

                            <form onSubmit={handleLogin} className="space-y-4">
                                <div>
                                    <label
                                        htmlFor="username"
                                        className="block text-[13px] font-extrabold text-gray-800 mb-1.5"
                                    >
                                        Username
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
                                    className="w-full mt-6 py-3.5 px-6 bg-[#14a098] hover:bg-[#118b84] active:scale-[0.98] text-white font-bold rounded-full shadow-[0_6px_20px_rgba(20,160,152,0.3)] transition-all duration-200 text-[15px] tracking-wide"
                                >
                                    Login
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