import {  
    FileText,  
    LayoutDashboard, 
    Folder, 
    MessageSquare, 
    LayoutTemplate, 
    History,
    LogOut,
    Shield,
} from 'lucide-react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { getLocalUser, clearSession } from '../../services/apiService';

export default function Sidebar() {
    const navigate = useNavigate();
    const location = useLocation();
    const user = getLocalUser();

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

    return (
        <aside className="w-64 bg-[#005B52] dark:bg-slate-900 border-r border-[#004D46] dark:border-slate-800 text-white flex flex-col justify-between p-6 shadow-lg hidden md:flex shrink-0 h-screen sticky top-0 z-40 overflow-hidden">
            {/* Header & Navigation */}
            <div className="flex flex-col space-y-8 min-h-0 flex-1">
                {/* Brand Logo */}
                <Link to="/dashboard" className="flex items-center gap-3 group">
                    <div className="p-2.5 bg-white/15 dark:bg-white/10 rounded-xl group-hover:bg-white/25 transition-all">
                        <FileText size={22} className="text-white" />
                    </div>
                    <div>
                        <h1 className="text-xl font-extrabold tracking-tight leading-none text-white">FormUp</h1>
                    </div>
                </Link>

                <nav className="space-y-1.5 flex-1">
                    {menuItems.map((item) => {
                        const Icon = item.icon;
                        const isActive = location.pathname.startsWith(item.path);

                        return (
                            <Link 
                                key={item.path}
                                to={item.path} 
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

            <div className="pt-4 mt-auto border-t border-white/10 dark:border-slate-800 shrink-0">
                <button
                    onClick={handleLogout}
                    className="w-full flex items-center gap-3 px-4 py-3 font-bold text-sm text-teal-100 hover:text-white hover:bg-white/10 dark:text-red-400 dark:hover:bg-red-950/30 dark:hover:text-red-300 rounded-xl transition-all cursor-pointer"
                >
                    <LogOut size={18} />
                    <span>Keluar</span>
                </button>
            </div>
        </aside>
    );
}