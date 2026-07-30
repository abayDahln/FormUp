import {
    Search,
    Bell,
    Settings,
} from 'lucide-react';
import { useState } from 'react';

export default function Topbar() {

    const [user, setUser] = useState(() => {
        return JSON.parse(localStorage.getItem('user') || '{}');
    });

    return (
        <header className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="relative w-full sm:flex-1">
                <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                    type="text"
                    placeholder="Search forms, responses..."
                    className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-full text-sm outline-none focus:ring-2 focus:ring-[#6DBFB3] transition-all"
                />
            </div>

            <div className="flex items-center justify-between sm:justify-end gap-4 shrink-0">
                <div className="flex items-center gap-2">
                    <button className="p-2 text-slate-500 hover:bg-slate-50 rounded-full transition-all">
                        <Bell size={18} />
                    </button>
                    <button className="p-2 text-slate-500 hover:bg-slate-50 rounded-full transition-all">
                        <Settings size={18} />
                    </button>
                </div>

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
    )
}