import {  
    FileText,  
    LayoutDashboard, 
    Folder, 
    MessageSquare, 
    LayoutTemplate, 
    History,
    LogOut,
    Shield,
    HelpCircle,
    Bot,
    Sparkles,
} from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { getLocalUser, clearSession } from '../../services/apiService';
import logo from '../../assets/logo.png';
import ConfirmModal from '../ui/ConfirmModal';
import UserGuideModal from '../ui/UserGuideModal';

export default function Sidebar({ onStartTour = null }) {
    const navigate = useNavigate();
    const location = useLocation();
    const user = getLocalUser();
    const [guideModalOpen, setGuideModalOpen] = useState(false);

    const [confirmNav, setConfirmNav] = useState({ isOpen: false, action: null, message: '' });

   const navigateWithConfirm = (path) => {
    if (window.__formBuilderDirty === true) {
        setConfirmNav({
            isOpen: true,
            message: 'Ada perubahan yang belum disimpan. Yakin ingin meninggalkan halaman ini?',
            action: () => navigate(path),
        });
        return;
    }

    navigate(path);
};

const handleLogout = () => {
    if (window.__formBuilderDirty === true) {
        setConfirmNav({
            isOpen: true,
            message: 'Ada perubahan yang belum disimpan. Yakin ingin keluar?',
            action: () => {
                clearSession();
                navigate('/login', { replace: true });
            },
        });
        return;
    }

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

    const isAiChatActive = location.pathname.startsWith('/ai-chat');

    return (
        <>
            <aside className="w-64 bg-[#005B52] dark:bg-slate-900 border-r border-[#004D46] dark:border-slate-800 text-white flex flex-col justify-between p-6 shadow-lg hidden md:flex shrink-0 h-screen sticky top-0 z-40 overflow-hidden">
                {/* Header & Navigation */}
                <div className="flex flex-col space-y-8 min-h-0 flex-1">
                    {/* Brand Logo */}
                    <Link to="/dashboard" className="flex items-center gap-3 group">
                        <div className="p-2.5 bg-white/15 dark:bg-white/10 rounded-xl group-hover:bg-white/25 transition-all">
                            <img 
                                src={logo} 
                                alt="FormUp Logo" 
                                className="w-6 h-6 object-contain" 
                            />
                        </div>
                        <div>
                            <h1 className="text-xl font-extrabold tracking-tight leading-none text-white">FormUp</h1>
                        </div>
                    </Link>

                    <nav className="space-y-1.5 flex-1 overflow-y-auto" data-tour="sidebar-nav">
                        {menuItems.map((item) => {
                            const Icon = item.icon;
                            const isActive = location.pathname.startsWith(item.path);

                            return (
                                <button
                                key={item.path}
                                type="button"
                                onClick={() => navigateWithConfirm(item.path)}
                                className={`w-full flex items-center gap-3 px-4 py-3 font-bold text-sm rounded-xl transition-all cursor-pointer ${
                                    isActive
                                        ? 'bg-white/20 dark:bg-teal-600/30 text-white shadow-xs border border-white/20 dark:border-teal-500/40'
                                        : 'text-teal-100/80 dark:text-slate-300 hover:bg-white/10 dark:hover:bg-slate-800/80 hover:text-white'
                                }`}
                            >
                                <Icon
                                    size={18}
                                    className={
                                        isActive
                                            ? 'text-teal-200 dark:text-teal-300'
                                            : 'text-teal-200/70 dark:text-slate-400'
                                    }
                                />
                                <span>{item.label}</span>
                            </button>
                            );
                        })}
                    </nav>
                </div>

                {/* Bottom Section: AI Assistant directly above the Logout divider */}
                <div className="pt-2 shrink-0 space-y-2">
                    <button
                        type="button"
                        onClick={() => navigateWithConfirm('/ai-chat')}
                        className={`w-full flex items-center gap-3 px-4 py-3 font-bold text-sm rounded-xl transition-all cursor-pointer ${
                            isAiChatActive
                                ? 'bg-gradient-to-r from-teal-500/40 to-emerald-500/40 text-white shadow-sm border border-teal-300/40'
                                : 'text-teal-100 hover:bg-white/15 dark:hover:bg-slate-800/80 hover:text-white bg-white/10 dark:bg-slate-800/50 border border-white/10'
                        }`}
                    >
                        <Bot size={18} className={isAiChatActive ? 'text-teal-200' : 'text-teal-300'} />
                        <span className="flex-1 text-left">AI Assistant</span>
                        <Sparkles size={14} className="text-amber-300 animate-pulse" />
                    </button>

                    <div className="border-t border-white/10 dark:border-slate-800 pt-2">
                        <button
                            onClick={handleLogout}
                            className="w-full flex items-center gap-3 px-4 py-3 font-bold text-sm text-teal-100 hover:text-white hover:bg-white/10 dark:text-red-400 dark:hover:bg-red-950/30 dark:hover:text-red-300 rounded-xl transition-all cursor-pointer"
                        >
                            <LogOut size={18} />
                            <span>Keluar</span>
                        </button>
                    </div>
                </div>
            </aside>

            {/* Popup Ringkasan Panduan Pengguna */}
            <UserGuideModal
                isOpen={guideModalOpen}
                onClose={() => setGuideModalOpen(false)}
                onStartTour={() => {
                    setGuideModalOpen(false);
                    if (onStartTour) {
                        onStartTour();
                    } else if (window.__startFormUpTour) {
                        window.__startFormUpTour();
                    }
                }}
            />
            <ConfirmModal
                isOpen={confirmNav.isOpen}
                onClose={() => setConfirmNav({ isOpen: false, action: null, message: '' })}
                onConfirm={() => {
                    const action = confirmNav.action;
                    setConfirmNav({ isOpen: false, action: null, message: '' });
                    if (action) action();
                }}
                title="Perubahan Belum Disimpan"
                message={confirmNav.message}
                variant="danger"
                confirmText="Ya, Lanjutkan"
            />
        </>
    );
}