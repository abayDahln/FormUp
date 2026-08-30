import {
    Search,
    Sun,
    Moon,
    Menu,
    X,
    FileText,
    LayoutDashboard,
    Folder,
    MessageSquare,
    LayoutTemplate,
    History,
    LogOut,
    Shield
} from 'lucide-react';
import { useState, useEffect } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { getLocalUser, assetUrl, clearSession } from '../../services/apiService';
import useDebounce from '../../hooks/useDebounce';

export default function Topbar({ 
    searchQuery = '', 
    onSearchChange = null, 
    placeholder = 'Cari formulir, respons...' 
}) {
    const navigate = useNavigate();
    const location = useLocation();
    const [user] = useState(() => getLocalUser());
    const [internalSearch, setInternalSearch] = useState(searchQuery || '');
    const debouncedSearch = useDebounce(internalSearch, 300);
    const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

    const [isDark, setIsDark] = useState(() => {
        return localStorage.getItem('theme') === 'dark';
    });

    useEffect(() => {
        if (isDark) {
            document.documentElement.classList.add('dark');
            document.documentElement.setAttribute('data-theme', 'dark');
            localStorage.setItem('theme', 'dark');
        } else {
            document.documentElement.classList.remove('dark');
            document.documentElement.setAttribute('data-theme', 'light');
            localStorage.setItem('theme', 'light');
        }
    }, [isDark]);

    useEffect(() => {
        if (onSearchChange) {
            onSearchChange(debouncedSearch);
        }
    }, [debouncedSearch, onSearchChange]);

    const handleInputChange = (e) => {
        setInternalSearch(e.target.value);
    };

    const handleLogout = () => {
        clearSession();
        navigate('/login', { replace: true });
    };

    const menuItems = [
        { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
        { path: '/my-forms', icon: Folder, label: 'Formulir Saya' },
        { path: '/responses', icon: MessageSquare, label: 'Respons' },
        { path: '/templates', icon: LayoutTemplate, label: 'Templat' },
        { path: '/history', icon: History, label: 'Riwayat' },
    ];

    const userRole = (user?.role || '').toUpperCase();
    if (userRole === 'ADMIN' || userRole === 'SUPER_ADMIN') {
        menuItems.push({ path: '/admin', icon: Shield, label: 'Kontrol Admin' });
    }

    const currentValue = internalSearch;

    return (
        <>
            <header className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition-colors">
                <div className="flex items-center gap-3 w-full sm:flex-1">
                    {/* MOBILE HAMBURGER BUTTON (BUG-11) */}
                    <button
                        type="button"
                        onClick={() => setMobileMenuOpen(true)}
                        className="md:hidden p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors cursor-pointer shrink-0"
                        title="Buka Menu"
                    >
                        <Menu size={20} />
                    </button>

                    {/* SEARCH INPUT */}
                    <div className="relative flex-1">
                        <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 dark:text-slate-500 pointer-events-none" />
                        <input
                            type="text"
                            value={currentValue}
                            onChange={handleInputChange}
                            placeholder={placeholder}
                            className="w-full pl-10 pr-4 py-2.5 bg-slate-50 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700 rounded-xl text-sm outline-none focus:ring-2 focus:ring-[#00897B] dark:focus:ring-teal-400 transition-all text-slate-800 dark:text-slate-100 placeholder:text-slate-400 dark:placeholder:text-slate-500 font-medium"
                        />
                    </div>
                </div>

                <div className="flex items-center justify-between sm:justify-end gap-4 shrink-0">
                    {/* TOGGLE DARK MODE */}
                    <div className="flex items-center gap-2 bg-slate-100 dark:bg-slate-800 p-1 rounded-xl border border-slate-200 dark:border-slate-700">
                        <button
                            type="button"
                            onClick={() => setIsDark(false)}
                            className={`p-1.5 rounded-lg transition-all cursor-pointer ${
                                !isDark 
                                    ? 'bg-white text-amber-500 shadow-xs' 
                                    : 'text-slate-400 hover:text-slate-600'
                            }`}
                            title="Mode Terang"
                        >
                            <Sun size={16} />
                        </button>
                        <button
                            type="button"
                            onClick={() => setIsDark(true)}
                            className={`p-1.5 rounded-lg transition-all cursor-pointer ${
                                isDark 
                                    ? 'bg-slate-900 text-teal-400 shadow-xs' 
                                    : 'text-slate-400 hover:text-slate-600'
                            }`}
                            title="Mode Gelap"
                        >
                            <Moon size={16} />
                        </button>
                    </div>

                    {/* USER PROFILE */}
                    <button
                        onClick={() => navigate('/profile')}
                        className="flex items-center gap-3 pl-3 border-l border-slate-200 dark:border-slate-700 hover:opacity-85 transition-opacity cursor-pointer text-left"
                        title="Pengaturan Akun"
                    >
                        <div className="text-right hidden sm:block">
                            <h4 className="text-xs font-bold text-slate-800 dark:text-slate-100">{user?.fullname || 'Pengguna'}</h4>
                        </div>
                        <img
                            src={assetUrl(
                                user?.profileImage,
                                `https://ui-avatars.com/api/?name=${encodeURIComponent(user?.fullname || 'U')}&background=00897B&color=fff&size=64`
                            )}
                            alt="Profil"
                            className="w-9 h-9 rounded-full object-cover border-2 border-teal-500/30 dark:border-teal-500/50 shadow-xs"
                        />
                    </button>
                </div>
            </header>

            {/* MOBILE DRAWER / SIDEBAR (BUG-11) */}
            {mobileMenuOpen && (
                <div className="fixed inset-0 z-50 md:hidden flex">
                    {/* Backdrop */}
                    <div
                        className="fixed inset-0 bg-black/60 backdrop-blur-xs transition-opacity"
                        onClick={() => setMobileMenuOpen(false)}
                    />

                    {/* Drawer Content */}
                    <div className="relative w-72 max-w-[85vw] bg-[#005B52] dark:bg-slate-900 text-white flex flex-col justify-between p-6 shadow-2xl z-10 animate-in slide-in-from-left duration-200">
                        <div className="space-y-6">
                            {/* Header */}
                            <div className="flex items-center justify-between">
                                <Link to="/dashboard" onClick={() => setMobileMenuOpen(false)} className="flex items-center gap-3">
                                    <div className="p-2 bg-white/15 dark:bg-white/10 rounded-xl">
                                        <FileText size={20} className="text-white" />
                                    </div>
                                    <span className="text-lg font-extrabold tracking-tight text-white">FormUp</span>
                                </Link>
                                <button
                                    type="button"
                                    onClick={() => setMobileMenuOpen(false)}
                                    className="p-1.5 text-white/80 hover:text-white rounded-lg cursor-pointer"
                                >
                                    <X size={20} />
                                </button>
                            </div>

                            {/* Nav Links */}
                            <nav className="space-y-1.5">
                                {menuItems.map((item) => {
                                    const Icon = item.icon;
                                    const isActive = location.pathname.startsWith(item.path);

                                    return (
                                        <Link 
                                            key={item.path}
                                            to={item.path} 
                                            onClick={() => setMobileMenuOpen(false)}
                                            className={`flex items-center gap-3 px-4 py-3 font-bold text-sm rounded-xl transition-all ${
                                                isActive 
                                                    ? 'bg-white/20 dark:bg-teal-600/30 text-white shadow-xs border border-white/20 dark:border-teal-500/40' 
                                                    : 'text-teal-100/80 dark:text-slate-300 hover:bg-white/10 dark:hover:bg-slate-800/80 hover:text-white' 
                                            }`}
                                        >
                                            <Icon size={18} className={isActive ? 'text-teal-200 dark:text-teal-300' : 'text-teal-200/70 dark:text-slate-400'} />
                                            <span>{item.label}</span>
                                        </Link>
                                    );
                                })}
                            </nav>
                        </div>

                        {/* Footer & Logout */}
                        <div className="pt-4 border-t border-white/10 dark:border-slate-800 space-y-3">
                            <Link
                                to="/profile"
                                onClick={() => setMobileMenuOpen(false)}
                                className="flex items-center gap-3 px-3 py-2 rounded-xl hover:bg-white/10 transition-colors"
                            >
                                <img
                                    src={assetUrl(
                                        user?.profileImage,
                                        `https://ui-avatars.com/api/?name=${encodeURIComponent(user?.fullname || 'U')}&background=00897B&color=fff&size=64`
                                    )}
                                    alt="Profil"
                                    className="w-8 h-8 rounded-full object-cover border border-teal-300/40"
                                />
                                <div className="text-left overflow-hidden">
                                    <p className="text-xs font-bold text-white truncate">{user?.fullname || 'Pengguna'}</p>
                                    <p className="text-[10px] text-teal-200/80 truncate">@{user?.username || 'user'}</p>
                                </div>
                            </Link>

                            <button
                                onClick={handleLogout}
                                className="w-full flex items-center gap-3 px-4 py-3 font-bold text-sm text-teal-100 hover:text-white hover:bg-white/10 dark:text-red-400 dark:hover:bg-red-950/30 dark:hover:text-red-300 rounded-xl transition-all cursor-pointer"
                            >
                                <LogOut size={18} />
                                <span>Keluar</span>
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </>
    );
}