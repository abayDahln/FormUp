import {
    Search,
    Sun,
    Moon
} from 'lucide-react';
import { useState, useEffect } from 'react';

export default function Topbar() {

    const [user, setUser] = useState(() => {
        return JSON.parse(localStorage.getItem('user') || '{}');
    });

    // State tema (true jika Dark Mode ON, false jika Light Mode/OFF)
    const [isDark, setIsDark] = useState(() => {
        return localStorage.getItem('theme') === 'dark';
    });

    // Effect untuk mengatur class dark di tag html
    useEffect(() => {
        if (isDark) {
            document.documentElement.classList.add('dark');
            localStorage.setItem('theme', 'dark');
        } else {
            document.documentElement.classList.remove('dark');
            localStorage.setItem('theme', 'light');
        }
    }, [isDark]);

    return (
        <header className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            {/* SEARCH INPUT */}
            <div className="relative w-full sm:flex-1">
                <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                    type="text"
                    placeholder="Search forms, responses..."
                    className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-full text-sm outline-none focus:ring-2 focus:ring-[#6DBFB3] transition-all text-slate-800"
                />
            </div>

            <div className="flex items-center justify-between sm:justify-end gap-4 shrink-0">
                
                {/* TOMBOL SWITCH TOGGLE ON / OFF */}
                <div className="flex items-center gap-2">
                    <Sun size={16} className={isDark ? 'text-slate-400' : 'text-amber-500'} />
                    
                    <button
                        type="button"
                        onClick={() => setIsDark(!isDark)}
                        className={`relative inline-flex h-6 w-11 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                            isDark ? 'bg-[#6DBFB3]' : 'bg-slate-200'
                        }`}
                    >
                        <span
                            className={`pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-md ring-0 transition duration-200 ease-in-out ${
                                isDark ? 'translate-x-5' : 'translate-x-0'
                            }`}
                        />
                    </button>

                    <Moon size={16} className={isDark ? 'text-slate-700' : 'text-slate-400'} />
                </div>

                {/* USER PROFILE */}
                <div className="flex items-center gap-3 pl-3 border-l border-slate-200">
                    <div className="text-right hidden sm:block">
                        <h4 className="text-xs font-bold text-slate-800">{user?.fullname || 'John Doe'}</h4>
                        <p className="text-[10px] text-slate-400 font-semibold uppercase">PRO PLAN</p>
                    </div>
                    <img
                        src={user?.profileImage || "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80"}
                        alt="Profile"
                        className="w-9 h-9 rounded-full object-cover border border-slate-300 shadow-sm"
                    />
                </div>
            </div>
        </header>
    );
}