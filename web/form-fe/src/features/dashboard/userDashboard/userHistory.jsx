import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { FileText, Award, Eye, Edit3, BarChart2 } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import { getMyForms, getMySubmittedResponses, clearSession } from '../../../services/apiService';

export default function History() {
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('submitted');
    const [submittedForms, setSubmittedForms] = useState([]);
    const [createdForms, setCreatedForms] = useState([]);
    const [loading, setLoading] = useState(true);
    const [searchQuery, setSearchQuery] = useState('');

    useEffect(() => {
        const fetchHistory = async () => {
            try {
                setLoading(true);
                const [submittedResult, createdResult] = await Promise.all([
                    getMySubmittedResponses(),
                    getMyForms(),
                ]);

                if (submittedResult.status === 401 || createdResult.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (submittedResult.ok && Array.isArray(submittedResult.data)) {
                    setSubmittedForms(submittedResult.data);
                }
                if (createdResult.ok && Array.isArray(createdResult.data)) {
                    setCreatedForms(createdResult.data);
                }
            } catch (err) {
                console.error('History fetch error:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchHistory();
    }, [navigate]);

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleDateString('id-ID', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    };

    const getStatusBadge = (status) => {
        const s = status?.toLowerCase() ?? '';
        if (s === 'submitted' || s === 'reviewed' || s === 'accepted' || s === 'new') {
            return 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800';
        }
        if (s === 'published') {
            return 'bg-teal-50 text-[#00897B] dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800';
        }
        if (s === 'draft') {
            return 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400 border border-slate-200 dark:border-slate-700';
        }
        return 'bg-amber-50 text-amber-600 dark:bg-amber-950/60 dark:text-amber-400 border border-amber-200 dark:border-amber-800';
    };

    const getStatusLabel = (status) => {
        const s = status?.toLowerCase() ?? '';
        if (s === 'submitted') return 'Terkirim';
        if (s === 'reviewed') return 'Ditinjau';
        if (s === 'accepted') return 'Diterima';
        if (s === 'rejected') return 'Ditolak';
        if (s === 'published') return 'Dipublikasikan';
        if (s === 'draft') return 'Draf';
        if (s === 'new') return 'Baru';
        return status || '—';
    };

    // Filter list based on search
    const filteredSubmitted = submittedForms.filter(item => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (
            (item.formTitle && item.formTitle.toLowerCase().includes(q)) ||
            (item.status && item.status.toLowerCase().includes(q))
        );
    });

    const filteredCreated = createdForms.filter(item => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (
            (item.title && item.title.toLowerCase().includes(q)) ||
            (item.status && item.status.toLowerCase().includes(q))
        );
    });

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 min-h-screen overflow-y-auto">
                <main className="p-4 sm:p-6 lg:p-8 space-y-6 w-full flex-1">

                    <Topbar 
                        searchQuery={searchQuery} 
                        onSearchChange={setSearchQuery} 
                        placeholder="Cari riwayat formulir..." 
                    />

                    <div>
                        <h1 className="text-2xl font-bold text-slate-900 dark:text-white">Riwayat & Aktivitas</h1>
                        <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
                            Pantau pengiriman formulir Anda dan kelola riwayat aktivitas akun.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full">
                        <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                            <div className="space-y-2">
                                <div className="p-2.5 bg-teal-50 dark:bg-teal-950/60 w-fit rounded-xl text-[#00897B] dark:text-teal-400">
                                    <FileText size={22} />
                                </div>
                                <p className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Formulir Terkirim</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{submittedForms.length}</h3>
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                            <div className="space-y-2">
                                <div className="p-2.5 bg-indigo-50 dark:bg-indigo-950/60 w-fit rounded-xl text-indigo-500 dark:text-indigo-400">
                                    <Award size={22} />
                                </div>
                                <p className="text-xs font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">Formulir Dibuat</p>
                                <h3 className="text-3xl font-extrabold text-slate-900 dark:text-white">{createdForms.length}</h3>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden w-full">

                        <div className="flex border-b border-slate-200 dark:border-slate-800 px-6 pt-4 gap-8">
                            <button
                                onClick={() => setActiveTab('submitted')}
                                className={`pb-4 text-sm font-bold border-b-2 transition-all cursor-pointer ${
                                    activeTab === 'submitted'
                                        ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400'
                                        : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
                                }`}
                            >
                                Formulir Terkirim ({submittedForms.length})
                            </button>
                            <button
                                onClick={() => setActiveTab('created')}
                                className={`pb-4 text-sm font-bold border-b-2 transition-all cursor-pointer ${
                                    activeTab === 'created'
                                        ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400'
                                        : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'
                                }`}
                            >
                                Formulir Dibuat ({createdForms.length})
                            </button>
                        </div>

                        {loading ? (
                            <div className="py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat riwayat...</div>
                        ) : activeTab === 'submitted' ? (
                            filteredSubmitted.length === 0 ? (
                                <div className="py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                    {searchQuery ? `Tidak ada pengiriman formulir yang cocok dengan "${searchQuery}".` : 'Anda belum pernah mengirimkan formulir.'}
                                </div>
                            ) : (
                                <div className="overflow-x-auto w-full">
                                    <table className="w-full text-left border-collapse text-sm">
                                        <thead>
                                            <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                                <th className="py-4 px-6">Judul Formulir</th>
                                                <th className="py-4 px-6">Waktu Pengiriman</th>
                                                <th className="py-4 px-6">Status</th>
                                                <th className="py-4 px-6 text-right">Aksi</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                            {filteredSubmitted.map((item) => (
                                                <tr key={item.responseId} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                    <td className="py-4 px-6">
                                                        <div className="flex items-center gap-3">
                                                            <div className="p-2 bg-slate-100 dark:bg-slate-800 rounded-xl text-slate-500 dark:text-slate-400">
                                                                <FileText size={18} />
                                                            </div>
                                                            <span className="font-bold text-slate-900 dark:text-white">{item.formTitle || '—'}</span>
                                                        </div>
                                                    </td>
                                                    <td className="py-4 px-6 text-slate-500 dark:text-slate-400 font-medium">
                                                        {formatDate(item.submittedAt)}
                                                    </td>
                                                    <td className="py-4 px-6">
                                                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${getStatusBadge(item.status)}`}>
                                                            {getStatusLabel(item.status)}
                                                        </span>
                                                    </td>
                                                    <td className="py-4 px-6 text-right">
                                                        <button
                                                            onClick={() => navigate(`/f/${item.formLink}/result/${item.responseId}`)}
                                                            className="inline-flex items-center gap-1.5 text-xs font-bold text-[#00897B] dark:text-teal-400 hover:underline cursor-pointer"
                                                        >
                                                            <Eye size={14} /> Lihat Hasil
                                                        </button>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )
                        ) : (
                            filteredCreated.length === 0 ? (
                                <div className="py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                    {searchQuery ? `Tidak ada formulir yang cocok dengan "${searchQuery}".` : 'Belum ada formulir yang dibuat.'}
                                </div>
                            ) : (
                                <div className="overflow-x-auto w-full">
                                    <table className="w-full text-left border-collapse text-sm">
                                        <thead>
                                            <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                                <th className="py-4 px-6">Judul Formulir</th>
                                                <th className="py-4 px-6">Status</th>
                                                <th className="py-4 px-6">Dibuat</th>
                                                <th className="py-4 px-6">Total Respons</th>
                                                <th className="py-4 px-6 text-right">Aksi</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                            {filteredCreated.map((form) => (
                                                <tr key={form.id} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                    <td className="py-4 px-6">
                                                        <div className="flex items-center gap-3">
                                                            <div className="p-2 bg-teal-50 dark:bg-teal-950/60 rounded-xl text-[#00897B] dark:text-teal-400">
                                                                <FileText size={18} />
                                                            </div>
                                                            <span className="font-bold text-slate-900 dark:text-white">{form.title || 'Formulir Tanpa Judul'}</span>
                                                        </div>
                                                    </td>
                                                    <td className="py-4 px-6">
                                                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${getStatusBadge(form.status)}`}>
                                                            {getStatusLabel(form.status)}
                                                        </span>
                                                    </td>
                                                    <td className="py-4 px-6 text-slate-500 dark:text-slate-400 font-medium">
                                                        {formatDate(form.createdAt)}
                                                    </td>
                                                    <td className="py-4 px-6 font-bold text-slate-800 dark:text-slate-200">
                                                        {form.responseCount ?? 0}
                                                    </td>
                                                    <td className="py-4 px-6 text-right">
                                                        <div className="flex items-center justify-end gap-2">
                                                            <button
                                                                onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                                className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-lg transition-colors cursor-pointer"
                                                                title="Edit Formulir"
                                                            >
                                                                <Edit3 size={16} />
                                                            </button>
                                                            <button
                                                                onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                                className="p-1.5 text-slate-400 hover:text-[#00897B] dark:hover:text-teal-400 rounded-lg transition-colors cursor-pointer"
                                                                title="Lihat Respons"
                                                            >
                                                                <BarChart2 size={16} />
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )
                        )}

                    </div>

                </main>
            </div>
        </div>
    );
}