import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, FileText, Users, CheckCircle2, Clock, Edit3, BarChart2, Sparkles, SearchX, ArrowRight } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import AIFormBuilderModal from '../../../components/ui/AIFormBuilderModal';
import { getMyForms, getLocalUser, clearSession, assetUrl, createForm } from '../../../services/apiService';

const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
};

const UserHome = () => {
    const navigate = useNavigate();
    const [myForms, setMyForms] = useState([]);
    const [loading, setLoading] = useState(true);
    const [user] = useState(() => getLocalUser());
    const [searchQuery, setSearchQuery] = useState('');
    const [creatingForm, setCreatingForm] = useState(false);
    const [aiFormBuilderOpen, setAiFormBuilderOpen] = useState(false);

    useEffect(() => {
        const fetchData = async () => {
            try {
                setLoading(true);
                const formsResult = await getMyForms();

                if (formsResult.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (formsResult.ok && Array.isArray(formsResult.data)) {
                    setMyForms(formsResult.data);
                }
            } catch (err) {
                console.error('Dashboard fetch error:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, [navigate]);

    const handleCreateNewForm = async () => {
        if (creatingForm) return;
        setCreatingForm(true);
        try {
            const res = await createForm({
                title: 'Formulir Tanpa Judul',
                description: '',
            });
            if (res.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }
            if (res.ok && res.data?.id) {
                navigate(`/forms/${res.data.id}/edit`);
            } else {
                navigate('/create-form');
            }
        } catch (err) {
            console.error('Error creating form:', err);
            navigate('/create-form');
        } finally {
            setCreatingForm(false);
        }
    };

    const totalResponses = myForms.reduce((acc, f) => acc + (f.responseCount ?? 0), 0);
    const publishedCount = myForms.filter(f => f.status?.toLowerCase() === 'published').length;
    const draftCount = myForms.filter(f => f.status?.toLowerCase() === 'draft').length;

    const filteredForms = myForms.filter(form => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (
            (form.title && form.title.toLowerCase().includes(q)) ||
            (form.description && form.description.toLowerCase().includes(q)) ||
            (form.status && form.status.toLowerCase().includes(q))
        );
    });

    const recentForms = [...filteredForms]
        .sort((a, b) => new Date(b.updatedAt ?? b.createdAt) - new Date(a.updatedAt ?? a.createdAt))
        .slice(0, 10);

    if (loading) {
        return (
            <div className="flex min-h-screen w-full bg-slate-50 dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100">
                <Sidebar />

                <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                    <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">
                        <Topbar searchQuery={searchQuery} onSearchChange={setSearchQuery} />

                        {/* Skeleton Header */}
                        <div className="animate-pulse space-y-2">
                            <div className="h-7 bg-slate-200 dark:bg-slate-800 rounded-md w-56"></div>
                            <div className="h-4 bg-slate-200 dark:bg-slate-800 rounded-md w-72"></div>
                        </div>

                        {/* Skeleton Stats Grid */}
                        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                            {[1, 2, 3, 4].map((i) => (
                                <div key={i} className="bg-white dark:bg-slate-900 p-4 sm:p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 flex items-center justify-between animate-pulse">
                                    <div className="space-y-2">
                                        <div className="h-3 bg-slate-200 dark:bg-slate-800 rounded w-16 sm:w-20"></div>
                                        <div className="h-6 sm:h-7 bg-slate-200 dark:bg-slate-800 rounded w-10 sm:w-12"></div>
                                    </div>
                                    <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-slate-200 dark:bg-slate-800 shrink-0"></div>
                                </div>
                            ))}
                        </div>

                        {/* Skeleton Content Grid */}
                        <div className="space-y-4">
                            <div className="h-5 bg-slate-200 dark:bg-slate-800 rounded w-36 animate-pulse"></div>
                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-4">
                                {[1, 2, 3, 4, 5].map((i) => (
                                    <div key={i} className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 overflow-hidden animate-pulse h-48 sm:h-64 flex flex-col justify-between p-4">
                                        <div className="h-full bg-slate-200 dark:bg-slate-800 rounded-xl w-full"></div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </main>
                </div>
            </div>
        );
    }

    return (
        <div className="flex min-h-screen w-full bg-slate-50 dark:bg-slate-950 font-sans antialiased text-slate-900 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                {/* Menghapus max-w-7xl mx-auto agar layout full width mengisi seluruh layar */}
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6 sm:space-y-8">
                    <Topbar 
                        searchQuery={searchQuery} 
                        onSearchChange={setSearchQuery} 
                        placeholder="Cari formulir, status, atau deskripsi..." 
                    />

                    {/* Header Section */}
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div>
                            <div className="flex items-center gap-2">
                                <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-50">
                                    {getGreeting()}, {user?.fullname ? user.fullname.split(' ')[0] : 'Pengguna'}
                                </h1>
                                <Sparkles size={18} className="text-teal-600 dark:text-teal-400" />
                            </div>
                            <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                                Berikut ringkasan aktivitas dan performa formulir Anda.
                            </p>
                        </div>

                        <div className="flex items-center gap-2">
                        <button
                            onClick={() => setAiFormBuilderOpen(true)}
                            className="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-gradient-to-r from-teal-600 to-emerald-500 hover:from-teal-700 hover:to-emerald-600 text-white text-xs font-semibold rounded-xl shadow-xs transition-all cursor-pointer w-full sm:w-auto"
                        >
                            <Sparkles size={15} />
                            <span>Buat dengan AI</span>
                        </button>
                        <button
                            onClick={handleCreateNewForm}
                            disabled={creatingForm}
                            className="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-teal-600 hover:bg-teal-700 dark:bg-teal-600 dark:hover:bg-teal-500 text-white text-xs font-semibold rounded-xl shadow-xs transition-all cursor-pointer w-full sm:w-auto disabled:opacity-60"
                        >
                            <Plus size={16} />
                            <span>{creatingForm ? 'Membuat...' : 'Buat Formulir Baru'}</span>
                        </button>
                        </div>
                    </div>

                    {/* Stats Metrics */}
                    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
                        <div className="bg-white dark:bg-slate-900 p-3.5 sm:p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800/80 shadow-2xs flex items-center justify-between">
                            <div>
                                <p className="text-[10px] sm:text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-0.5">Total Formulir</p>
                                <h3 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">{myForms.length}</h3>
                            </div>
                            <div className="p-2 sm:p-2.5 rounded-xl bg-teal-50 dark:bg-teal-950/50 text-teal-600 dark:text-teal-400">
                                <FileText size={18} className="sm:w-5 sm:h-5" />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-3.5 sm:p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800/80 shadow-2xs flex items-center justify-between">
                            <div>
                                <p className="text-[10px] sm:text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-0.5">Total Respons</p>
                                <h3 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">{totalResponses}</h3>
                            </div>
                            <div className="p-2 sm:p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 dark:text-indigo-400">
                                <Users size={18} className="sm:w-5 sm:h-5" />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-3.5 sm:p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800/80 shadow-2xs flex items-center justify-between">
                            <div>
                                <p className="text-[10px] sm:text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-0.5">Dipublikasikan</p>
                                <h3 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">{publishedCount}</h3>
                            </div>
                            <div className="p-2 sm:p-2.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400">
                                <CheckCircle2 size={18} className="sm:w-5 sm:h-5" />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-3.5 sm:p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800/80 shadow-2xs flex items-center justify-between">
                            <div>
                                <p className="text-[10px] sm:text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-0.5">Draf</p>
                                <h3 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">{draftCount}</h3>
                            </div>
                            <div className="p-2 sm:p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-400">
                                <Clock size={18} className="sm:w-5 sm:h-5" />
                            </div>
                        </div>
                    </div>

                    {/* Recent Forms Section */}
                    <section className="space-y-4">
                        <div className="flex items-center justify-between">
                            <div>
                                <h2 className="text-base font-bold text-slate-900 dark:text-white">Formulir Terbaru</h2>
                                <p className="text-xs text-slate-500 dark:text-slate-400">
                                    {searchQuery ? `Hasil pencarian untuk "${searchQuery}"` : 'Formulir yang terakhir kali diubah'}
                                </p>
                            </div>
                            <button
                                onClick={() => navigate('/my-forms')}
                                className="inline-flex items-center gap-1 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors cursor-pointer"
                            >
                                <span>Lihat semua</span>
                                <ArrowRight size={14} />
                            </button>
                        </div>

                        {/* Responsive Grid: Menyamping di HP, Grid fleksibel 3-5 kolom di Desktop */}
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-4">
                            {recentForms.map((form) => {
                                const status = typeof form.status === 'string' ? form.status : 'draft';
                                const isPublished = status.toLowerCase() === 'published';
                                const responseCount = form.responseCount ?? 0;

                                return (
                                    <div 
                                        key={form.id} 
                                        className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-2xs hover:border-slate-300 dark:hover:border-slate-700 transition-all duration-200 flex flex-row sm:flex-col justify-between overflow-hidden group hover:-translate-y-0.5"
                                    >
                                        {/* Banner: Menyamping di HP, Penuh di Desktop */}
                                        <div className="w-28 xs:w-32 sm:w-full h-auto sm:h-36 relative overflow-hidden bg-slate-100 dark:bg-slate-800/50 flex shrink-0 items-center justify-center border-r sm:border-r-0 sm:border-b border-slate-100 dark:border-slate-800">
                                            {form.bannerImage ? (
                                                <img
                                                    src={assetUrl(form.bannerImage)}
                                                    alt={form.title}
                                                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500 ease-out"
                                                />
                                            ) : (
                                                <div className="flex flex-col items-center justify-center gap-1 text-slate-400 dark:text-slate-600">
                                                    <FileText size={24} />
                                                </div>
                                            )}
                                            
                                            <span className={`absolute top-2.5 left-2.5 text-[9px] sm:text-[10px] font-semibold px-2 py-0.5 rounded-md uppercase tracking-wider backdrop-blur-md ${
                                                isPublished 
                                                    ? 'bg-emerald-500/90 text-white' 
                                                    : 'bg-slate-900/70 text-slate-200'
                                            }`}>
                                                {isPublished ? 'Dipublikasikan' : 'Draf'}
                                            </span>
                                        </div>

                                        {/* Content Area */}
                                        <div className="p-3.5 sm:p-4 flex-1 flex flex-col justify-between space-y-3 min-w-0">
                                            <div>
                                                <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100 truncate group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
                                                    {form.title || 'Formulir Tanpa Judul'}
                                                </h3>
                                                <div className="flex items-center justify-between mt-1.5 text-xs text-slate-500 dark:text-slate-400">
                                                    <span>{responseCount} respons</span>
                                                    <span>
                                                        {form.createdAt ? new Date(form.createdAt).toLocaleDateString('id-ID', { month: 'short', day: 'numeric' }) : ''}
                                                    </span>
                                                </div>
                                            </div>

                                            {/* Action Buttons */}
                                            <div className="flex items-center gap-2 pt-2.5 border-t border-slate-100 dark:border-slate-800/80">
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                    className="flex-1 py-1.5 px-2 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700/80 text-slate-700 dark:text-slate-200 font-medium text-xs rounded-xl transition-colors flex items-center justify-center gap-1.5 border border-slate-200/60 dark:border-slate-700/60 cursor-pointer"
                                                >
                                                    <Edit3 size={13} /> Edit
                                                </button>
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                    className="flex-1 py-1.5 px-2 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700/80 text-slate-700 dark:text-slate-200 font-medium text-xs rounded-xl transition-colors flex items-center justify-center gap-1.5 border border-slate-200/60 dark:border-slate-700/60 cursor-pointer"
                                                >
                                                    <BarChart2 size={13} /> Respons
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        {/* Empty State Search */}
                        {recentForms.length === 0 && searchQuery && (
                            <div className="py-12 text-center flex flex-col items-center justify-center bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800">
                                <SearchX size={32} className="text-slate-300 dark:text-slate-600 mb-2" />
                                <p className="text-sm font-semibold text-slate-700 dark:text-slate-300">Hasil tidak ditemukan</p>
                                <p className="text-xs text-slate-400 dark:text-slate-500 mt-1">
                                    Tidak ada formulir yang cocok dengan kata kunci "{searchQuery}".
                                </p>
                            </div>
                        )}
                    </section>

                </main>
            </div>

            {/* AI-1: AI Form Builder Modal */}
            <AIFormBuilderModal
                isOpen={aiFormBuilderOpen}
                onClose={() => setAiFormBuilderOpen(false)}
                onFormCreated={(newId) => navigate(`/forms/${newId}/edit`)}
            />
        </div>
    );
};

export default UserHome;