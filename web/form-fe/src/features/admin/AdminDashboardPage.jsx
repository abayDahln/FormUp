import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
    Users, FileText, Trash2, Ban, CheckCircle, 
    Search, ShieldAlert, ArrowLeft, Loader2, MessageSquare, AlertTriangle, Eye, X
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    adminGetUsers, adminGetForms, adminDeleteUser, adminDeleteForm,
    adminBanUser, adminActivateUser, adminGetFeedback, adminTakedownFormFromFeedback,
    adminGetUserDetail, adminGetFormDetail, adminRestoreFormFromFeedback,
    clearSession, getLocalUser
} from '../../services/apiService';
import useDebounce from '../../hooks/useDebounce';

export default function AdminDashboardPage() {
    const navigate = useNavigate();
    const [user] = useState(() => getLocalUser());
    const [users, setUsers] = useState([]);
    const [forms, setForms] = useState([]);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('users');
    const [searchQuery, setSearchQuery] = useState('');
    const debouncedSearch = useDebounce(searchQuery, 300);
    const [toast, setToast] = useState(null);

    useEffect(() => {
        if (user?.role !== 'ADMIN') {
            navigate('/dashboard');
            return;
        }

        const load = async () => {
            setLoading(true);
            const [usersRes, formsRes] = await Promise.all([adminGetUsers(), adminGetForms()]);
            if (usersRes.status === 401 || formsRes.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }
            if (usersRes.ok && Array.isArray(usersRes.data)) setUsers(usersRes.data);
            if (formsRes.ok && Array.isArray(formsRes.data)) setForms(formsRes.data);
            setLoading(false);
        };
        load();
    }, [navigate, user]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    const handleDeleteUser = async (userId) => {
        if (!window.confirm('Hapus pengguna ini? Semua formulir milik pengguna ini juga akan dihapus.')) return;
        const res = await adminDeleteUser(userId);
        if (res.ok) {
            setUsers(prev => prev.filter(u => u.id !== userId));
            showToast('Pengguna berhasil dihapus');
        } else {
            showToast(res.message || 'Gagal menghapus pengguna', 'error');
        }
    };

    const handleDeleteForm = async (formId) => {
        if (!window.confirm('Hapus formulir ini? Tindakan ini tidak dapat dibatalkan.')) return;
        const res = await adminDeleteForm(formId);
        if (res.ok) {
            setForms(prev => prev.filter(f => f.id !== formId));
            showToast('Formulir berhasil dihapus');
        } else {
            showToast(res.message || 'Gagal menghapus formulir', 'error');
        }
    };

    const filteredUsers = users.filter(u => {
        if (!debouncedSearch.trim()) return true;
        const q = debouncedSearch.toLowerCase();
        return (
            (u.fullname && u.fullname.toLowerCase().includes(q)) ||
            (u.username && u.username.toLowerCase().includes(q)) ||
            (u.email && u.email.toLowerCase().includes(q))
        );
    });

    const filteredForms = forms.filter(f => {
        if (!debouncedSearch.trim()) return true;
        const q = debouncedSearch.toLowerCase();
        return (
            (f.title && f.title.toLowerCase().includes(q)) ||
            (f.formLink && f.formLink.toLowerCase().includes(q)) ||
            (f.owner?.fullname && f.owner.fullname.toLowerCase().includes(q))
        );
    });

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat panel kontrol admin...</p>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-6 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3">
                        <button onClick={() => navigate('/dashboard')} className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all">
                            <ArrowLeft size={18} />
                        </button>
                        <div>
                            <h1 className="text-base font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                                <Shield size={18} className="text-[#00897B] dark:text-teal-400" />
                                Kontrol & Manajemen Admin
                            </h1>
                            <p className="text-xs text-slate-400 dark:text-slate-500">Kelola akun pengguna, formulir global, dan izin sistem.</p>
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
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-5 shadow-xs flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Total Pengguna Terdaftar</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{users.length}</h3>
                            </div>
                            <div className="p-3 bg-teal-50 dark:bg-teal-950/60 rounded-xl text-[#00897B] dark:text-teal-400">
                                <Users size={22} />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-5 shadow-xs flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Total Formulir Global</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{forms.length}</h3>
                            </div>
                            <div className="p-3 bg-blue-50 dark:bg-blue-950/60 rounded-xl text-blue-600 dark:text-blue-400">
                                <FileText size={22} />
                            </div>
                        </div>
                    </div>

                    {/* Tab Navigation & Search */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 flex flex-col sm:flex-row items-center justify-between gap-4 shadow-xs">
                        <div className="flex gap-2 w-full sm:w-auto">
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

                    {/* Table View */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 overflow-hidden shadow-xs">
                        {activeTab === 'users' ? (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                            <th className="py-3 px-4">Pengguna</th>
                                            <th className="py-3 px-4">Email</th>
                                            <th className="py-3 px-4">Peran</th>
                                            <th className="py-3 px-4">Verifikasi</th>
                                            <th className="py-3 px-4 text-right">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                        {filteredUsers.map(u => (
                                            <tr key={u.id} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                <td className="py-3.5 px-4">
                                                    <div className="font-bold text-slate-900 dark:text-white">{u.fullname}</div>
                                                    <div className="text-[10px] text-slate-400 dark:text-slate-500 font-mono">@{u.username}</div>
                                                </td>
                                                <td className="py-3.5 px-4 text-slate-600 dark:text-slate-300 font-medium text-xs">{u.email}</td>
                                                <td className="py-3.5 px-4">
                                                    <span className={`text-[10px] font-extrabold px-2.5 py-0.5 rounded-full ${
                                                        u.role === 'ADMIN' 
                                                            ? 'bg-purple-50 text-purple-600 dark:bg-purple-950/60 dark:text-purple-400 border border-purple-200 dark:border-purple-800' 
                                                            : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400'
                                                    }`}>
                                                        {u.role}
                                                    </span>
                                                </td>
                                                <td className="py-3.5 px-4">
                                                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                                                        u.isVerified 
                                                            ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400' 
                                                            : 'bg-amber-50 text-amber-600 dark:bg-amber-950/60 dark:text-amber-400'
                                                    }`}>
                                                        {u.isVerified ? 'Terverifikasi' : 'Belum Verifikasi'}
                                                    </span>
                                                </td>
                                                <td className="py-3.5 px-4 text-right">
                                                    <button
                                                        onClick={() => handleDeleteUser(u.id)}
                                                        className="p-1 text-red-400 hover:text-red-600 rounded-lg transition-colors cursor-pointer"
                                                        title="Hapus Pengguna"
                                                    >
                                                        <Trash2 size={16} />
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                            <th className="py-3 px-4">Judul Formulir</th>
                                            <th className="py-3 px-4">Pemilik</th>
                                            <th className="py-3 px-4">Status</th>
                                            <th className="py-3 px-4">Respons</th>
                                            <th className="py-3 px-4 text-right">Aksi</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                        {filteredForms.map(f => (
                                            <tr key={f.id} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                <td className="py-3.5 px-4">
                                                    <div className="font-bold text-slate-900 dark:text-white">{f.title || 'Formulir Tanpa Judul'}</div>
                                                    <div className="text-[10px] text-slate-400 dark:text-slate-500 font-mono">/f/{f.formLink}</div>
                                                </td>
                                                <td className="py-3.5 px-4 text-xs text-slate-600 dark:text-slate-300 font-medium">
                                                    {f.owner?.fullname || '—'}
                                                </td>
                                                <td className="py-3.5 px-4">
                                                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                                                        f.status === 'PUBLISHED' 
                                                            ? 'bg-teal-50 text-teal-600 dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800' 
                                                            : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'
                                                    }`}>
                                                        {f.status}
                                                    </span>
                                                </td>
                                                <td className="py-3.5 px-4 text-xs font-bold text-slate-700 dark:text-slate-300">
                                                    {f.responseCount ?? 0}
                                                </td>
                                                <td className="py-3.5 px-4 text-right">
                                                    <button
                                                        onClick={() => handleDeleteForm(f.id)}
                                                        className="p-1 text-red-400 hover:text-red-600 rounded-lg transition-colors cursor-pointer"
                                                        title="Hapus Formulir"
                                                    >
                                                        <Trash2 size={16} />
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}
                    </div>

                </div>
            </div>
        </div>
    );
}
