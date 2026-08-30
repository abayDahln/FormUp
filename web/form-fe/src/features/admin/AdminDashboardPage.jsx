import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
    Users, FileText, Trash2, Search, Shield, ArrowLeft, Loader2,
    Ban, CheckCircle2, Eye, AlertTriangle, RefreshCw, MessageSquare,
    X, ExternalLink, Calendar, Mail, User as UserIcon, Lock, CheckCircle
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    adminGetUsers, adminGetUserDetail, adminGetForms, adminGetFormDetail,
    adminGetFeedback, adminBanUser, adminActivateUser, adminDeleteUser,
    adminTakedownForm, adminRestoreForm, adminDeleteForm, adminDeleteFeedback,
    adminTakedownFormFromFeedback, adminRestoreFormFromFeedback,
    clearSession, getLocalUser, assetUrl
} from '../../services/apiService';
import useDebounce from '../../hooks/useDebounce';

export default function AdminDashboardPage() {
    const navigate = useNavigate();
    const [user] = useState(() => getLocalUser());
    const [users, setUsers] = useState([]);
    const [forms, setForms] = useState([]);
    const [feedbacks, setFeedbacks] = useState([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('users');
    const [searchQuery, setSearchQuery] = useState('');
    const debouncedSearch = useDebounce(searchQuery, 300);
    const [toast, setToast] = useState(null);
    const [actionLoadingId, setActionLoadingId] = useState(null);

    // Modals
    const [selectedUserDetail, setSelectedUserDetail] = useState(null);
    const [loadingUserDetail, setLoadingUserDetail] = useState(false);
    const [selectedFormDetail, setSelectedFormDetail] = useState(null);
    const [loadingFormDetail, setLoadingFormDetail] = useState(false);

    useEffect(() => {
        const userRole = (user?.role || '').toUpperCase();
        if (userRole !== 'ADMIN' && userRole !== 'SUPER_ADMIN') {
            navigate('/dashboard');
            return;
        }

        const load = async () => {
            setLoading(true);
            try {
                const [usersRes, formsRes, feedbackRes] = await Promise.all([
                    adminGetUsers(),
                    adminGetForms(),
                    adminGetFeedback()
                ]);

                if (usersRes.status === 401 || formsRes.status === 401 || feedbackRes.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (usersRes.ok && usersRes.data) {
                    const uData = Array.isArray(usersRes.data) ? usersRes.data : (usersRes.data?.items || []);
                    setUsers(uData);
                }
                if (formsRes.ok && formsRes.data) {
                    const fData = Array.isArray(formsRes.data) ? formsRes.data : (formsRes.data?.items || []);
                    setForms(fData);
                }
                if (feedbackRes.ok && feedbackRes.data) {
                    const fbData = Array.isArray(feedbackRes.data) ? feedbackRes.data : (feedbackRes.data?.items || []);
                    setFeedbacks(fbData);
                }
            } catch (err) {
                console.error('Error loading admin data:', err);
                showToast('Gagal memuat beberapa data admin', 'error');
            } finally {
                setLoading(false);
            }
        };
        load();
    }, [navigate, user]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    // ── User Handlers ───────────────────────────────────────────────────────────
    const handleViewUser = async (userId) => {
        setLoadingUserDetail(true);
        setSelectedUserDetail({ id: userId, loading: true });
        const res = await adminGetUserDetail(userId);
        setLoadingUserDetail(false);
        if (res.ok && res.data) {
            setSelectedUserDetail(res.data);
        } else {
            showToast(res.message || 'Gagal memuat detail pengguna', 'error');
            setSelectedUserDetail(null);
        }
    };

    const handleBanUser = async (userId) => {
        if (!window.confirm('Blokir (Ban) pengguna ini? Pengguna tidak akan dapat login.')) return;
        setActionLoadingId(`user_ban_${userId}`);
        const res = await adminBanUser(userId);
        setActionLoadingId(null);
        if (res.ok) {
            setUsers(prev => prev.map(u => u.id === userId ? { ...u, isActive: false } : u));
            showToast('Pengguna berhasil diblokir (Banned)');
        } else {
            showToast(res.message || 'Gagal memblokir pengguna', 'error');
        }
    };

    const handleActivateUser = async (userId) => {
        setActionLoadingId(`user_act_${userId}`);
        const res = await adminActivateUser(userId);
        setActionLoadingId(null);
        if (res.ok) {
            setUsers(prev => prev.map(u => u.id === userId ? { ...u, isActive: true } : u));
            showToast('Pengguna berhasil diaktifkan kembali');
        } else {
            showToast(res.message || 'Gagal mengaktifkan pengguna', 'error');
        }
    };

    const handleDeleteUser = async (userId) => {
        if (!window.confirm('Hapus pengguna ini? Semua formulir milik pengguna ini juga akan dihapus.')) return;
        setActionLoadingId(`user_del_${userId}`);
        const res = await adminDeleteUser(userId);
        setActionLoadingId(null);
        if (res.ok) {
            setUsers(prev => prev.filter(u => u.id !== userId));
            showToast('Pengguna berhasil dihapus');
        } else {
            showToast(res.message || 'Gagal menghapus pengguna', 'error');
        }
    };

    // ── Form Handlers ───────────────────────────────────────────────────────────
    const handleViewForm = async (formId) => {
        setLoadingFormDetail(true);
        setSelectedFormDetail({ id: formId, loading: true });
        const res = await adminGetFormDetail(formId);
        setLoadingFormDetail(false);
        if (res.ok && res.data) {
            setSelectedFormDetail(res.data);
        } else {
            showToast(res.message || 'Gagal memuat detail formulir', 'error');
            setSelectedFormDetail(null);
        }
    };

    const handleTakedownForm = async (formId) => {
        if (!window.confirm('Take down formulir ini? Formulir tidak akan bisa diakses publik.')) return;
        setActionLoadingId(`form_td_${formId}`);
        const res = await adminTakedownForm(formId);
        setActionLoadingId(null);
        if (res.ok) {
            setForms(prev => prev.map(f => f.id === formId ? { ...f, takenDownAt: new Date().toISOString() } : f));
            showToast('Formulir berhasil di-takedown');
        } else {
            showToast(res.message || 'Gagal take down formulir', 'error');
        }
    };

    const handleRestoreForm = async (formId) => {
        setActionLoadingId(`form_rst_${formId}`);
        const res = await adminRestoreForm(formId);
        setActionLoadingId(null);
        if (res.ok) {
            setForms(prev => prev.map(f => f.id === formId ? { ...f, takenDownAt: null } : f));
            showToast('Formulir berhasil dipulihkan (Restore)');
        } else {
            showToast(res.message || 'Gagal memulihkan formulir', 'error');
        }
    };

    const handleDeleteForm = async (formId) => {
        if (!window.confirm('Hapus formulir ini? Tindakan ini tidak dapat dibatalkan.')) return;
        setActionLoadingId(`form_del_${formId}`);
        const res = await adminDeleteForm(formId);
        setActionLoadingId(null);
        if (res.ok) {
            setForms(prev => prev.filter(f => f.id !== formId));
            showToast('Formulir berhasil dihapus');
        } else {
            showToast(res.message || 'Gagal menghapus formulir', 'error');
        }
    };

    // ── Feedback Handlers ───────────────────────────────────────────────────────
    const handleDeleteFeedback = async (fbId) => {
        if (!window.confirm('Hapus laporan umpan balik ini?')) return;
        setActionLoadingId(`fb_del_${fbId}`);
        const res = await adminDeleteFeedback(fbId);
        setActionLoadingId(null);
        if (res.ok) {
            setFeedbacks(prev => prev.filter(fb => fb.id !== fbId));
            showToast('Umpan balik berhasil dihapus');
        } else {
            showToast(res.message || 'Gagal menghapus umpan balik', 'error');
        }
    };

    const handleTakedownFromFeedback = async (fbId) => {
        if (!window.confirm('Take down formulir terkait dari laporan ini?')) return;
        setActionLoadingId(`fb_td_${fbId}`);
        const res = await adminTakedownFormFromFeedback(fbId);
        setActionLoadingId(null);
        if (res.ok) {
            setFeedbacks(prev => prev.map(fb => fb.id === fbId ? { ...fb, isTakedown: true } : fb));
            showToast('Formulir terkait berhasil di-takedown');
        } else {
            showToast(res.message || 'Gagal take down formulir', 'error');
        }
    };

    const handleRestoreFromFeedback = async (fbId) => {
        setActionLoadingId(`fb_rst_${fbId}`);
        const res = await adminRestoreFormFromFeedback(fbId);
        setActionLoadingId(null);
        if (res.ok) {
            setFeedbacks(prev => prev.map(fb => fb.id === fbId ? { ...fb, isTakedown: false } : fb));
            showToast('Formulir terkait berhasil dipulihkan');
        } else {
            showToast(res.message || 'Gagal memulihkan formulir', 'error');
        }
    };

    // ── Filtered Data ───────────────────────────────────────────────────────────
    const filteredUsers = users.filter(u => {
        if (!debouncedSearch.trim()) return true;
        const q = debouncedSearch.toLowerCase();
        return (
            (u.fullname && u.fullname.toLowerCase().includes(q)) ||
            (u.username && u.username.toLowerCase().includes(q)) ||
            (u.email && u.email.toLowerCase().includes(q)) ||
            (u.role && u.role.toLowerCase().includes(q))
        );
    });

    const filteredForms = forms.filter(f => {
        if (!debouncedSearch.trim()) return true;
        const q = debouncedSearch.toLowerCase();
        const owner = f.ownerName || f.owner?.fullname || f.ownerEmail || '';
        return (
            (f.title && f.title.toLowerCase().includes(q)) ||
            (f.formLink && f.formLink.toLowerCase().includes(q)) ||
            owner.toLowerCase().includes(q)
        );
    });

    const filteredFeedbacks = feedbacks.filter(fb => {
        if (!debouncedSearch.trim()) return true;
        const q = debouncedSearch.toLowerCase();
        return (
            (fb.description && fb.description.toLowerCase().includes(q)) ||
            (fb.reason && fb.reason.toLowerCase().includes(q)) ||
            (fb.formTitle && fb.formTitle.toLowerCase().includes(q)) ||
            (fb.userName && fb.userName.toLowerCase().includes(q)) ||
            (fb.userEmail && fb.userEmail.toLowerCase().includes(q))
        );
    });

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <div className="text-center space-y-2">
                <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400" />
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat panel kontrol admin...</p>
            </div>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-6 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3">
                        <button onClick={() => navigate('/dashboard')} className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all cursor-pointer">
                            <ArrowLeft size={18} />
                        </button>
                        <div>
                            <h1 className="text-base font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                                <Shield size={18} className="text-[#00897B] dark:text-teal-400" />
                                Kontrol & Manajemen Admin
                            </h1>
                            <p className="text-xs text-slate-400 dark:text-slate-500">Kelola akun pengguna, formulir global, dan laporan moderasi.</p>
                        </div>
                    </div>
                </div>

                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-[#00897B]'}`}>
                        {toast.msg}
                    </div>
                )}

                <div className="p-6 max-w-6xl mx-auto w-full space-y-6">

                    {/* Stats Cards */}
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-5 shadow-xs flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Pengguna Terdaftar</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{users.length}</h3>
                            </div>
                            <div className="p-3 bg-teal-50 dark:bg-teal-950/60 rounded-xl text-[#00897B] dark:text-teal-400">
                                <Users size={22} />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-5 shadow-xs flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Formulir Global</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{forms.length}</h3>
                            </div>
                            <div className="p-3 bg-blue-50 dark:bg-blue-950/60 rounded-xl text-blue-600 dark:text-blue-400">
                                <FileText size={22} />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-5 shadow-xs flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Laporan & Umpan Balik</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{feedbacks.length}</h3>
                            </div>
                            <div className="p-3 bg-amber-50 dark:bg-amber-950/60 rounded-xl text-amber-600 dark:text-amber-400">
                                <MessageSquare size={22} />
                            </div>
                        </div>
                    </div>

                    {/* Tab Navigation & Search */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 flex flex-col sm:flex-row items-center justify-between gap-4 shadow-xs">
                        <div className="flex flex-wrap gap-2 w-full sm:w-auto">
                            <button
                                onClick={() => setActiveTab('users')}
                                className={`px-4 py-2 rounded-xl text-xs font-extrabold transition-all cursor-pointer ${
                                    activeTab === 'users' 
                                        ? 'bg-[#00897B] text-white shadow-xs' 
                                        : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200'
                                }`}
                            >
                                Kelola Pengguna ({users.length})
                            </button>
                            <button
                                onClick={() => setActiveTab('forms')}
                                className={`px-4 py-2 rounded-xl text-xs font-extrabold transition-all cursor-pointer ${
                                    activeTab === 'forms' 
                                        ? 'bg-[#00897B] text-white shadow-xs' 
                                        : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200'
                                }`}
                            >
                                Kelola Formulir ({forms.length})
                            </button>
                            <button
                                onClick={() => setActiveTab('feedback')}
                                className={`px-4 py-2 rounded-xl text-xs font-extrabold transition-all cursor-pointer ${
                                    activeTab === 'feedback' 
                                        ? 'bg-[#00897B] text-white shadow-xs' 
                                        : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:bg-slate-200'
                                }`}
                            >
                                Umpan Balik ({feedbacks.length})
                            </button>
                        </div>

                        <div className="relative w-full sm:w-64">
                            <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                            <input
                                type="text"
                                value={searchQuery}
                                onChange={e => setSearchQuery(e.target.value)}
                                placeholder="Cari data..."
                                className="w-full pl-9 pr-3 py-1.5 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-medium text-slate-800 dark:text-slate-100 outline-none focus:ring-2 focus:ring-[#00897B]"
                            />
                        </div>
                    </div>

                    {/* Table Views */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-xs">
                        
                        {/* ── TAB 1: USERS ────────────────────────────────────────────── */}
                        {activeTab === 'users' && (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                            <th className="py-3 px-4">Pengguna</th>
                                            <th className="py-3 px-4">Email</th>
                                            <th className="py-3 px-4">Peran</th>
                                            <th className="py-3 px-4">Status Akun</th>
                                            <th className="py-3 px-4 text-center">Form / Respon</th>
                                            <th className="py-3 px-4 text-right">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                        {filteredUsers.length === 0 ? (
                                            <tr>
                                                <td colSpan={6} className="text-center py-8 text-xs text-slate-400">Tidak ada pengguna ditemukan.</td>
                                            </tr>
                                        ) : (
                                            filteredUsers.map(u => {
                                                const isBanned = u.isActive === false;
                                                const isSelf = u.id === user?.id;
                                                const isAdminUser = (u.role || '').toUpperCase() === 'ADMIN' || (u.role || '').toUpperCase() === 'SUPER_ADMIN';

                                                return (
                                                    <tr key={u.id} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                        <td className="py-3.5 px-4">
                                                            <div className="font-bold text-slate-900 dark:text-white flex items-center gap-2">
                                                                <span>{u.fullname}</span>
                                                                {isSelf && <span className="text-[10px] bg-teal-100 text-teal-700 dark:bg-teal-900 dark:text-teal-300 px-1.5 py-0.2 rounded">Anda</span>}
                                                            </div>
                                                            <div className="text-[10px] text-slate-400 dark:text-slate-500 font-mono">@{u.username}</div>
                                                        </td>
                                                        <td className="py-3.5 px-4 text-slate-600 dark:text-slate-300 font-medium text-xs">{u.email}</td>
                                                        <td className="py-3.5 px-4">
                                                            <span className={`text-[10px] font-extrabold px-2.5 py-0.5 rounded-full ${
                                                                isAdminUser
                                                                    ? 'bg-purple-50 text-purple-600 dark:bg-purple-950/60 dark:text-purple-400 border border-purple-200 dark:border-purple-800' 
                                                                    : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400'
                                                            }`}>
                                                                {u.role || 'USER'}
                                                            </span>
                                                        </td>
                                                        <td className="py-3.5 px-4">
                                                            <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full inline-flex items-center gap-1 ${
                                                                isBanned 
                                                                    ? 'bg-red-50 text-red-600 dark:bg-red-950/60 dark:text-red-400 border border-red-200 dark:border-red-800' 
                                                                    : 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400'
                                                            }`}>
                                                                {isBanned ? <Ban size={10} /> : <CheckCircle2 size={10} />}
                                                                {isBanned ? 'Diblokir (Banned)' : 'Aktif'}
                                                            </span>
                                                        </td>
                                                        <td className="py-3.5 px-4 text-center text-xs font-semibold text-slate-600 dark:text-slate-400">
                                                            {u.formCount ?? 0} form / {u.responseCount ?? 0} respon
                                                        </td>
                                                        <td className="py-3.5 px-4 text-right">
                                                            <div className="flex items-center justify-end gap-1.5">
                                                                {/* Detail */}
                                                                <button
                                                                    onClick={() => handleViewUser(u.id)}
                                                                    className="p-1.5 text-slate-400 hover:text-[#00897B] dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
                                                                    title="Lihat Detail Pengguna"
                                                                >
                                                                    <Eye size={15} />
                                                                </button>

                                                                {/* Ban / Unban (not for admin or self) */}
                                                                {!isAdminUser && !isSelf && (
                                                                    isBanned ? (
                                                                        <button
                                                                            onClick={() => handleActivateUser(u.id)}
                                                                            disabled={actionLoadingId === `user_act_${u.id}`}
                                                                            className="p-1.5 text-emerald-500 hover:text-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 rounded-lg transition-colors cursor-pointer"
                                                                            title="Aktifkan Kembali Pengguna"
                                                                        >
                                                                            <CheckCircle size={15} />
                                                                        </button>
                                                                    ) : (
                                                                        <button
                                                                            onClick={() => handleBanUser(u.id)}
                                                                            disabled={actionLoadingId === `user_ban_${u.id}`}
                                                                            className="p-1.5 text-amber-500 hover:text-amber-700 hover:bg-amber-50 dark:hover:bg-amber-950/40 rounded-lg transition-colors cursor-pointer"
                                                                            title="Blokir (Ban) Pengguna"
                                                                        >
                                                                            <Ban size={15} />
                                                                        </button>
                                                                    )
                                                                )}

                                                                {/* Delete User */}
                                                                {!isAdminUser && !isSelf && (
                                                                    <button
                                                                        onClick={() => handleDeleteUser(u.id)}
                                                                        disabled={actionLoadingId === `user_del_${u.id}`}
                                                                        className="p-1.5 text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer"
                                                                        title="Hapus Pengguna"
                                                                    >
                                                                        <Trash2 size={15} />
                                                                    </button>
                                                                )}
                                                            </div>
                                                        </td>
                                                    </tr>
                                                );
                                            })
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        )}

                        {/* ── TAB 2: FORMS ────────────────────────────────────────────── */}
                        {activeTab === 'forms' && (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                            <th className="py-3 px-4">Judul Formulir</th>
                                            <th className="py-3 px-4">Pemilik</th>
                                            <th className="py-3 px-4">Status Publikasi</th>
                                            <th className="py-3 px-4">Status Moderasi</th>
                                            <th className="py-3 px-4">Respons</th>
                                            <th className="py-3 px-4 text-right">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                        {filteredForms.length === 0 ? (
                                            <tr>
                                                <td colSpan={6} className="text-center py-8 text-xs text-slate-400">Tidak ada formulir ditemukan.</td>
                                            </tr>
                                        ) : (
                                            filteredForms.map(f => {
                                                const isTakenDown = !!f.takenDownAt;
                                                const isPublished = (f.status || '').toUpperCase() === 'PUBLISHED';

                                                return (
                                                    <tr key={f.id} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                        <td className="py-3.5 px-4">
                                                            <div className="font-bold text-slate-900 dark:text-white line-clamp-1">{f.title || 'Formulir Tanpa Judul'}</div>
                                                            <div className="text-[10px] text-slate-400 dark:text-slate-500 font-mono">/f/{f.formLink}</div>
                                                        </td>
                                                        <td className="py-3.5 px-4 text-xs text-slate-600 dark:text-slate-300 font-medium">
                                                            {f.ownerName || f.owner?.fullname || f.ownerEmail || '—'}
                                                        </td>
                                                        <td className="py-3.5 px-4">
                                                            <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                                                                isPublished 
                                                                    ? 'bg-teal-50 text-teal-600 dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800' 
                                                                    : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
                                                            }`}>
                                                                {f.status}
                                                            </span>
                                                        </td>
                                                        <td className="py-3.5 px-4">
                                                            {isTakenDown ? (
                                                                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-50 text-red-600 dark:bg-red-950/60 dark:text-red-400 border border-red-200 dark:border-red-800 inline-flex items-center gap-1">
                                                                    <AlertTriangle size={10} /> Di-Takedown
                                                                </span>
                                                            ) : (
                                                                <span className="text-[10px] font-medium text-emerald-600 dark:text-emerald-400">
                                                                    Normal
                                                                </span>
                                                            )}
                                                        </td>
                                                        <td className="py-3.5 px-4 text-xs font-bold text-slate-700 dark:text-slate-300">
                                                            {f.responseCount ?? 0}
                                                        </td>
                                                        <td className="py-3.5 px-4 text-right">
                                                            <div className="flex items-center justify-end gap-1.5">
                                                                {/* Detail */}
                                                                <button
                                                                    onClick={() => handleViewForm(f.id)}
                                                                    className="p-1.5 text-slate-400 hover:text-[#00897B] dark:hover:text-teal-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
                                                                    title="Lihat Detail Formulir"
                                                                >
                                                                    <Eye size={15} />
                                                                </button>

                                                                {/* Takedown / Restore */}
                                                                {isTakenDown ? (
                                                                    <button
                                                                        onClick={() => handleRestoreForm(f.id)}
                                                                        disabled={actionLoadingId === `form_rst_${f.id}`}
                                                                        className="p-1.5 text-emerald-500 hover:text-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 rounded-lg transition-colors cursor-pointer"
                                                                        title="Pulihkan (Restore) Formulir"
                                                                    >
                                                                        <RefreshCw size={15} />
                                                                    </button>
                                                                ) : (
                                                                    <button
                                                                        onClick={() => handleTakedownForm(f.id)}
                                                                        disabled={actionLoadingId === `form_td_${f.id}`}
                                                                        className="p-1.5 text-amber-500 hover:text-amber-700 hover:bg-amber-50 dark:hover:bg-amber-950/40 rounded-lg transition-colors cursor-pointer"
                                                                        title="Take Down Formulir"
                                                                    >
                                                                        <AlertTriangle size={15} />
                                                                    </button>
                                                                )}

                                                                {/* Delete Form */}
                                                                <button
                                                                    onClick={() => handleDeleteForm(f.id)}
                                                                    disabled={actionLoadingId === `form_del_${f.id}`}
                                                                    className="p-1.5 text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer"
                                                                    title="Hapus Formulir"
                                                                >
                                                                    <Trash2 size={15} />
                                                                </button>
                                                            </div>
                                                        </td>
                                                    </tr>
                                                );
                                            })
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        )}

                        {/* ── TAB 3: FEEDBACK ─────────────────────────────────────────── */}
                        {activeTab === 'feedback' && (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                            <th className="py-3 px-4">Pengirim</th>
                                            <th className="py-3 px-4">Kategori</th>
                                            <th className="py-3 px-4">Isi Pesan / Laporan</th>
                                            <th className="py-3 px-4">Formulir Terkait</th>
                                            <th className="py-3 px-4 text-right">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                        {filteredFeedbacks.length === 0 ? (
                                            <tr>
                                                <td colSpan={5} className="text-center py-8 text-xs text-slate-400">Tidak ada umpan balik / laporan masuk.</td>
                                            </tr>
                                        ) : (
                                            filteredFeedbacks.map(fb => (
                                                <tr key={fb.id} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                    <td className="py-3.5 px-4">
                                                        <div className="font-bold text-slate-900 dark:text-white text-xs">{fb.userName || fb.user?.fullname || 'Anonim'}</div>
                                                        <div className="text-[10px] text-slate-400 font-mono">{fb.userEmail || fb.user?.email || '—'}</div>
                                                    </td>
                                                    <td className="py-3.5 px-4">
                                                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700">
                                                            {fb.reason || 'Laporan'}
                                                        </span>
                                                    </td>
                                                    <td className="py-3.5 px-4 text-xs text-slate-700 dark:text-slate-300 max-w-xs break-words">
                                                        {fb.description || fb.content || fb.message || '—'}
                                                    </td>
                                                    <td className="py-3.5 px-4 text-xs font-medium text-slate-600 dark:text-slate-400">
                                                        {fb.formTitle || fb.formId ? (
                                                            <span>{fb.formTitle || `Form #${fb.formId}`}</span>
                                                        ) : (
                                                            <span className="text-slate-400 italic">Umum</span>
                                                        )}
                                                    </td>
                                                    <td className="py-3.5 px-4 text-right">
                                                        <div className="flex items-center justify-end gap-1.5">
                                                            {fb.formId && (
                                                                fb.isTakedown ? (
                                                                    <button
                                                                        onClick={() => handleRestoreFromFeedback(fb.id)}
                                                                        disabled={actionLoadingId === `fb_rst_${fb.id}`}
                                                                        className="p-1.5 text-emerald-500 hover:text-emerald-700 hover:bg-emerald-50 dark:hover:bg-emerald-950/40 rounded-lg transition-colors cursor-pointer"
                                                                        title="Pulihkan Formulir dari Laporan"
                                                                    >
                                                                        <RefreshCw size={15} />
                                                                    </button>
                                                                ) : (
                                                                    <button
                                                                        onClick={() => handleTakedownFromFeedback(fb.id)}
                                                                        disabled={actionLoadingId === `fb_td_${fb.id}`}
                                                                        className="p-1.5 text-amber-500 hover:text-amber-700 hover:bg-amber-50 dark:hover:bg-amber-950/40 rounded-lg transition-colors cursor-pointer"
                                                                        title="Take Down Formulir dari Laporan"
                                                                    >
                                                                        <AlertTriangle size={15} />
                                                                    </button>
                                                                )
                                                            )}

                                                            <button
                                                                onClick={() => handleDeleteFeedback(fb.id)}
                                                                disabled={actionLoadingId === `fb_del_${fb.id}`}
                                                                className="p-1.5 text-red-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-lg transition-colors cursor-pointer"
                                                                title="Hapus Umpan Balik"
                                                            >
                                                                <Trash2 size={15} />
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        )}

                    </div>

                </div>
            </div>

            {/* ── MODAL: USER DETAIL ────────────────────────────────────────────── */}
            {selectedUserDetail && (
                <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
                    <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl w-full max-w-lg shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-150">
                        <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
                            <h3 className="font-extrabold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                                <UserIcon size={16} className="text-[#00897B]" />
                                Detail Akun Pengguna
                            </h3>
                            <button onClick={() => setSelectedUserDetail(null)} className="p-1 text-slate-400 hover:text-slate-600 rounded-lg cursor-pointer">
                                <X size={18} />
                            </button>
                        </div>
                        <div className="p-6 space-y-4">
                            {selectedUserDetail.loading ? (
                                <div className="py-8 text-center"><Loader2 className="w-6 h-6 animate-spin mx-auto text-[#00897B]" /></div>
                            ) : (
                                <>
                                    <div className="flex items-center gap-4">
                                        <div className="w-14 h-14 rounded-2xl bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800 flex items-center justify-center text-xl font-black text-[#00897B]">
                                            {selectedUserDetail.fullname?.slice(0, 2).toUpperCase() || 'US'}
                                        </div>
                                        <div>
                                            <h4 className="font-bold text-base text-slate-900 dark:text-white">{selectedUserDetail.fullname}</h4>
                                            <p className="text-xs text-slate-400 font-mono">@{selectedUserDetail.username}</p>
                                            <div className="flex gap-2 mt-1">
                                                <span className="text-[10px] font-extrabold px-2 py-0.5 bg-purple-50 text-purple-700 rounded-full border border-purple-200">
                                                    {selectedUserDetail.role || 'USER'}
                                                </span>
                                                <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${selectedUserDetail.isActive !== false ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'}`}>
                                                    {selectedUserDetail.isActive !== false ? 'Aktif' : 'Diblokir'}
                                                </span>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="grid grid-cols-2 gap-3 pt-2 text-xs">
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl">
                                            <p className="text-slate-400 font-medium text-[10px]">EMAIL</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200 truncate">{selectedUserDetail.email || '—'}</p>
                                        </div>
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl">
                                            <p className="text-slate-400 font-medium text-[10px]">TANGGAL LAHIR</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200">{selectedUserDetail.birthdate || '—'}</p>
                                        </div>
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl">
                                            <p className="text-slate-400 font-medium text-[10px]">TOTAL FORMULIR</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200">{selectedUserDetail.formCount ?? 0}</p>
                                        </div>
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl">
                                            <p className="text-slate-400 font-medium text-[10px]">TOTAL RESPONS</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200">{selectedUserDetail.responseCount ?? 0}</p>
                                        </div>
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl col-span-2">
                                            <p className="text-slate-400 font-medium text-[10px]">TANGGAL BERGABUNG</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200">
                                                {selectedUserDetail.createdAt ? new Date(selectedUserDetail.createdAt).toLocaleString('id-ID') : '—'}
                                            </p>
                                        </div>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* ── MODAL: FORM DETAIL ────────────────────────────────────────────── */}
            {selectedFormDetail && (
                <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
                    <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl w-full max-w-xl shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-150 max-h-[90vh] flex flex-col">
                        <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between shrink-0">
                            <h3 className="font-extrabold text-sm text-slate-900 dark:text-white flex items-center gap-2">
                                <FileText size={16} className="text-[#00897B]" />
                                Detail Formulir
                            </h3>
                            <button onClick={() => setSelectedFormDetail(null)} className="p-1 text-slate-400 hover:text-slate-600 rounded-lg cursor-pointer">
                                <X size={18} />
                            </button>
                        </div>
                        <div className="p-6 space-y-4 overflow-y-auto">
                            {selectedFormDetail.loading ? (
                                <div className="py-8 text-center"><Loader2 className="w-6 h-6 animate-spin mx-auto text-[#00897B]" /></div>
                            ) : (
                                <>
                                    <div>
                                        <h4 className="font-bold text-lg text-slate-900 dark:text-white">{selectedFormDetail.title || 'Formulir Tanpa Judul'}</h4>
                                        <p className="text-xs text-slate-500 font-mono mt-0.5">/f/{selectedFormDetail.formLink}</p>
                                    </div>

                                    <div className="grid grid-cols-2 gap-3 text-xs">
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl">
                                            <p className="text-slate-400 font-medium text-[10px]">PEMILIK FORM</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200">{selectedFormDetail.owner?.fullname || '—'}</p>
                                            <p className="text-[10px] text-slate-400">{selectedFormDetail.owner?.email || ''}</p>
                                        </div>
                                        <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl">
                                            <p className="text-slate-400 font-medium text-[10px]">STATUS & RESPONS</p>
                                            <p className="font-bold text-slate-800 dark:text-slate-200 uppercase">{selectedFormDetail.status}</p>
                                            <p className="text-[10px] text-[#00897B] font-bold">{selectedFormDetail.responseCount ?? 0} respons</p>
                                        </div>
                                    </div>

                                    {selectedFormDetail.settings && (
                                        <div className="space-y-1">
                                            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Pengaturan Formulir</p>
                                            <pre className="p-3 bg-slate-900 text-teal-300 font-mono text-[11px] rounded-xl overflow-x-auto">
                                                {JSON.stringify(selectedFormDetail.settings, null, 2)}
                                            </pre>
                                        </div>
                                    )}

                                    <div className="text-[11px] text-slate-400 space-y-1 pt-2 border-t border-slate-100 dark:border-slate-800">
                                        <p>Dibuat pada: {selectedFormDetail.createdAt ? new Date(selectedFormDetail.createdAt).toLocaleString('id-ID') : '—'}</p>
                                        {selectedFormDetail.takenDownAt && (
                                            <p className="text-red-500 font-bold">Di-takedown pada: {new Date(selectedFormDetail.takenDownAt).toLocaleString('id-ID')}</p>
                                        )}
                                    </div>
                                </>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
