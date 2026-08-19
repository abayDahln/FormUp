import {
    Search,
    Sun,
    Moon
} from 'lucide-react';
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { getLocalUser, assetUrl } from '../../services/apiService';

export default function Topbar({ 
    searchQuery = '', 
    onSearchChange = null, 
    placeholder = 'Cari formulir, respons...' 
}) {
    const navigate = useNavigate();
    const [user] = useState(() => getLocalUser());
    const [internalSearch, setInternalSearch] = useState('');

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

    const handleInputChange = (e) => {
        const value = e.target.value;
        setInternalSearch(value);
        if (onSearchChange) {
            onSearchChange(value);
        }
    };

    const currentValue = onSearchChange ? searchQuery : internalSearch;

    return (
        <header className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition-colors">
            {/* SEARCH INPUT */}
            <div className="relative w-full sm:flex-1">
                <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 dark:text-slate-500 pointer-events-none" />
                <input
                    type="text"
                    value={currentValue}
                    onChange={handleInputChange}
                    placeholder={placeholder}
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-50 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700 rounded-xl text-sm outline-none focus:ring-2 focus:ring-[#00897B] dark:focus:ring-teal-400 transition-all text-slate-800 dark:text-slate-100 placeholder:text-slate-400 dark:placeholder:text-slate-500 font-medium"
                />
            </div>

            <div className="flex items-center justify-between sm:justify-end gap-4 shrink-0">
                {/* TOGGLE DARK MODE */}
                <div className="flex items-center gap-2 bg-slate-100 dark:bg-slate-800 p-1 rounded-xl border border-slate-200 dark:border-slate-700">
                    <button
                        type="button"
                        onClick={() => setIsDark(false)}
                        className={`p-1.5 rounded-lg transition-all ${
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
                        className={`p-1.5 rounded-lg transition-all ${
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
    );
}