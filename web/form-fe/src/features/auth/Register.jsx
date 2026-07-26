
import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

const Register = () => {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const navigate = useNavigate();

    const handleRegister = (e) => {
        e.preventDefault();

        // Siapkan payload untuk dikirim ke API
        // const payload = { email, password };

        // TODO: Panggil API Register (misal menggunakan fetch atau axios)
        // try {
        //   const response = await axios.post('URL_API/register', payload);
        //   if (response.data.token) {
        //     localStorage.setItem('token', response.data.token);
        //     navigate('/dashboard');
        //   }
        // } catch (error) {
        //   console.error("Register gagal", error);
        // }

        navigate('/dashboard');
    };

    return (
        <div className="relative min-h-screen w-full bg-gradient-to-br from-[#0b7c76] via-[#2cb6ab] to-[#e4fcf9] flex items-center justify-center p-6 md:p-12 overflow-hidden select-none">

            <div className="absolute -top-[20%] -left-[10%] w-[900px] h-[900px] rounded-full bg-[#1e4584] pointer-events-none z-0"></div>

            <div className="absolute -bottom-[20%] -right-[10%] w-[800px] h-[800px] rounded-full bg-[#99f3eb] pointer-events-none z-0"></div>

            <div className="absolute -bottom-[25%] right-[5%] w-[700px] h-[700px] rounded-full bg-[#20a49b] opacity-40 mix-blend-multiply pointer-events-none z-0"></div>

            <div className="relative z-10 w-full max-w-[1100px] flex flex-col lg:flex-row items-center justify-between gap-12 lg:gap-8">

                <div className="flex-1 text-white max-w-xl pl-2 lg:pl-4 text-center lg:text-left">
                    <h1 className="text-4xl sm:text-5xl lg:text-[54px] font-bold tracking-tight mb-4 leading-[1.1] text-white">
                        GET STARTED
                    </h1>
                    <p className="text-base sm:text-lg lg:text-[17px] text-white/95 font-medium leading-relaxed max-w-sm">
                        Create your FormUp account and bring your ideas to life.

                    </p>
                </div>

                <div className="w-full max-w-[450px] bg-white/20 backdrop-blur-[18px] border border-white/40 rounded-[28px] p-8 sm:p-10 shadow-[0_8px_32px_0_rgba(0,0,0,0.1)]">

                    <div className="mb-7">
                        <h2 className="text-[32px] font-bold text-black tracking-tight mb-1">
                            Create an Account
                        </h2>
                        <p className="text-[15px] font-bold text-gray-600/90">
                            Sign up to access your FormUp workspace
                        </p>
                    </div>

                    <form onSubmit={handleRegister} className="space-y-4">
                        <div>
                            <label
                                htmlFor="username"
                                className="block text-[14px] font-extrabold text-gray-800 mb-1.5"
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
                                className="w-full px-4 py-3.5 rounded-xl border border-white/60 bg-white/40 text-gray-900 placeholder:text-gray-400/90 font-bold focus:outline-none focus:bg-white/60 focus:ring-2 focus:ring-[#16a096] transition-all text-[14px]"
                            />
                        </div>

                        <div>
                            <label
                                htmlFor="password"
                                className="block text-[14px] font-extrabold text-gray-800 mb-1.5"
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
                                className="w-full px-4 py-3.5 rounded-xl border border-white/60 bg-white/40 text-gray-900 placeholder:text-gray-400/90 font-bold focus:outline-none focus:bg-white/60 focus:ring-2 focus:ring-[#16a096] transition-all text-[14px]"
                            />
                        </div>

                        <button
                            type="submit"
                            className="w-full mt-8 py-3.5 px-6 bg-[#14a098] hover:bg-[#118b84] active:scale-[0.98] text-white font-bold rounded-full shadow-[0_6px_20px_rgba(20,160,152,0.3)] transition-all duration-200 text-[16px] tracking-wide"
                        >
                            Register
                        </button>
                    </form>

                    <div className="mt-6 text-center flex flex-col items-center gap-0.5">
                        <span className="text-[13px] font-bold text-gray-600">Already have an account?</span>
                        <Link
                            to="/login"
                            className="text-[14px] font-extrabold text-gray-800 hover:text-[#14a098] transition-colors"
                        >
                            Sign in
                        </Link>
                    </div>

                </div>

            </div>
        </div>
    );
};

export default Register;