import { useNavigate } from 'react-router-dom';

export default function UserHome() {
    const navigate = useNavigate();

    // Ambil data user dari localStorage
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    const username = user.username || user.fullname || 'User';

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        navigate('/login');
    };

    return (
        <div
            className="relative w-screen h-screen overflow-hidden flex flex-col items-center justify-center select-none"
            style={{
                background: 'linear-gradient(200deg, #E1F9F4 0%, #E1F9F4 35%, #018081 75%, #004D4E 100%)',
            }}
        >
            {/* Decorative blob top-left */}
            <div
                className="absolute pointer-events-none rounded-full"
                style={{
                    width: '700px',
                    height: '700px',
                    top: '10px',
                    left: '50px',
                    background: 'linear-gradient(160deg, rgba(21, 61, 195, 0.48) 9%, #0A1D5D 100%)',
                    opacity: 0.8,
                    zIndex: 0,
                }}
            />
            {/* Decorative blob bottom-right */}
            <div
                className="absolute pointer-events-none rounded-full"
                style={{
                    width: '700px',
                    height: '700px',
                    bottom: '-20px',
                    right: '120px',
                    background: 'linear-gradient(135deg, #6FF6DF 0%, rgba(10,29,93,0.7) 100%)',
                    zIndex: 0,
                }}
            />

            {/* Content */}
            <div className="relative z-10 flex flex-col items-center gap-10">
                {/* Username display */}
                <div className="text-center">
                    <p className="text-white/70 text-[22px] font-semibold mb-2 tracking-wide">
                        Welcome back,
                    </p>
                    <h1
                        className="font-extrabold tracking-tight text-white"
                        style={{
                            fontSize: 'clamp(64px, 10vw, 120px)',
                            lineHeight: 1.05,
                            textShadow: '0 4px 32px rgba(0,0,0,0.25)',
                        }}
                    >
                        @{username}
                    </h1>
                </div>

                {/* Logout button */}
                <button
                    id="logout-btn"
                    onClick={handleLogout}
                    className="px-10 py-4 bg-white/20 backdrop-blur-[12px] border border-white/40 text-white font-bold text-[16px] rounded-full shadow-[0_6px_24px_rgba(0,0,0,0.15)] hover:bg-white/30 active:scale-[0.97] transition-all duration-200 tracking-wide"
                >
                    Logout
                </button>
            </div>
        </div>
    );
}