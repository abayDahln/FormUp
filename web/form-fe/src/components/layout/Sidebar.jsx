import {  
    LayoutDashboard, 
    Folder, 
    MessageSquare, 
    LayoutTemplate, 
    History,
    LogOut,
    Shield,
    Bot,
    Sparkles,
    X
} from 'lucide-react';
import { useState } from 'react';
import { useNavigate, useLocation, Link } from 'react-router-dom';
import { getLocalUser, clearSession } from '../../services/apiService';
import logo from '../../assets/logo.png';
import ConfirmModal from '../ui/ConfirmModal';
import UserGuideModal from '../ui/UserGuideModal';

export default function Sidebar({ onStartTour = null, isOpen = false, onClose = () => {} }) {
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
                action: () => {
                    navigate(path);
                    onClose();
                },
            });
            return;
        }

        navigate(path);
        onClose();
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

    const renderSidebarContent = () => (
        <div className="flex flex-col h-full p-4 sm:p-6 overflow-hidden">
            {/* Header (Terkunci di atas) */}
            <div className="flex items-center justify-between shrink-0 mb-6">
                <Link to="/dashboard" onClick={onClose} className="flex items-center gap-3 group">
                    <div className="p-2.5 bg-white/15 dark:bg-white/10 rounded-xl group-hover:bg-white/25 transition-all">
                        <img src={logo} alt="FormUp Logo" className="w-6 h-6 object-contain" />
                    </div>
                    <div>
                        <h1 className="text-xl font-extrabold tracking-tight leading-none text-white">FormUp</h1>
                    </div>
                </Link>

                <button 
                    onClick={onClose} 
                    type="button"
                    className="md:hidden p-1.5 rounded-lg bg-white/10 text-teal-100 hover:text-white cursor-pointer active:scale-95 transition-transform"
                >
                    <X size={20} />
                </button>
            </div>

            {/* Navigasi Utama (Hanya area ini yang dapat di-scroll jika layar terlalu pendek) */}
            <nav className="flex-1 space-y-1.5 overflow-y-auto min-h-0 pr-1 custom-scrollbar" data-tour="sidebar-nav">
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

            {/* Bottom Section (AI Assistant & Logout - Terkunci di bawah) */}
            <div className="pt-4 mt-auto shrink-0 space-y-2 border-t border-white/10 dark:border-slate-800">
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

                <button
                    type="button"
                    onClick={handleLogout}
                    className="w-full flex items-center gap-3 px-4 py-3 font-bold text-sm text-teal-100 hover:text-white hover:bg-white/10 dark:text-red-400 dark:hover:bg-red-950/30 dark:hover:text-red-300 rounded-xl transition-all cursor-pointer"
                >
                    <LogOut size={18} />
                    <span>Keluar</span>
                </button>
            </div>
        </div>
    );

    return (
        <>
            {/* 1. Sidebar Desktop */}
            <aside className="w-64 bg-[#005B52] dark:bg-slate-900 border-r border-[#004D46] dark:border-slate-800 text-white hidden md:flex shrink-0 h-screen sticky top-0 z-40 overflow-hidden">
                {renderSidebarContent()}
            </aside>

            {/* 2. Drawer Mobile & Backdrop */}
            {isOpen && (
                <div 
                    onClick={onClose}
                    className="fixed inset-0 bg-black/60 z-50 md:hidden backdrop-blur-xs transition-opacity"
                />
            )}
            <aside 
                className={`
                    fixed top-0 left-0 bottom-0 w-72 max-w-[85vw] bg-[#005B52] dark:bg-slate-900 text-white z-50 md:hidden
                    transform transition-transform duration-300 ease-in-out shadow-2xl h-[100dvh]
                    ${isOpen ? 'translate-x-0' : '-translate-x-full'}
                `}
            >
                {renderSidebarContent()}
            </aside>

            {/* Modals */}
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