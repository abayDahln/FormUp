import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, FileText, Users, Star, Clock, Edit3, BarChart2, Sparkles } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
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

    // Real-time search filter
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
        .slice(0, 8);

    if (loading) {
        return (
            <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100">
                <Sidebar />

                <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                    <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">
                        <Topbar searchQuery={searchQuery} onSearchChange={setSearchQuery} />

                        {/* Skeleton Greeting */}
                        <div className="animate-pulse space-y-2">
                            <div className="h-8 bg-slate-200 dark:bg-slate-800 rounded-lg w-48 sm:w-64"></div>
                            <div className="h-3.5 bg-slate-200 dark:bg-slate-800 rounded-lg w-56"></div>
                        </div>

                        {/* Skeleton Stats Grid */}
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                            {[1, 2, 3, 4].map((i) => (
                                <div key={i} className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between animate-pulse">
                                    <div className="w-full space-y-2">
                                        <div className="h-3 bg-slate-200 dark:bg-slate-800 rounded-md w-20"></div>
                                        <div className="h-7 bg-slate-200 dark:bg-slate-800 rounded-md w-12"></div>
                                    </div>
                                    <div className="w-10 h-10 rounded-xl bg-slate-200 dark:bg-slate-800 shrink-0"></div>
                                </div>
                            ))}
                        </div>

                        {/* Skeleton Recent Forms */}
                        <section className="space-y-4">
                            <div className="flex items-center justify-between animate-pulse">
                                <div className="space-y-1">
                                    <div className="h-5 bg-slate-200 dark:bg-slate-800 rounded-md w-32"></div>
                                    <div className="h-3 bg-slate-200 dark:bg-slate-800 rounded-md w-48"></div>
                                </div>
                                <div className="h-3 bg-slate-200 dark:bg-slate-800 rounded-md w-16"></div>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                                {[1, 2, 3, 4].map((i) => (
                                    <div key={i} className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col justify-between overflow-hidden animate-pulse">
                                        <div className="h-36 w-full bg-slate-200 dark:bg-slate-800"></div>
                                        <div className="p-4 space-y-4 flex-1">
                                            <div className="h-4 bg-slate-200 dark:bg-slate-800 rounded-md w-3/4"></div>
                                            <div className="flex justify-between">
                                                <div className="h-4 bg-slate-200 dark:bg-slate-800 rounded-md w-16"></div>
                                                <div className="h-3 bg-slate-200 dark:bg-slate-800 rounded-md w-20"></div>
                                            </div>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </section>
                    </main>
                </div>
            </div>
        );
    }

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar 
                        searchQuery={searchQuery} 
                        onSearchChange={setSearchQuery} 
                        placeholder="Cari formulir, status, atau deskripsi..." 
                    />

                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div>
                            <div className="flex items-center gap-2">
                                <h2 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white">
                                    {getGreeting()}, {user?.fullname ? user.fullname.split(' ')[0] : 'Pengguna'}
                                </h2>
                                <Sparkles size={20} className="text-[#00897B] dark:text-teal-400" />
                            </div>
                            <p className="text-xs text-slate-500 dark:text-slate-400 font-medium mt-1">
                                Berikut performa dan ringkasan formulir Anda hari ini.
                            </p>
                        </div>

                        <button
                            onClick={handleCreateNewForm}
                            disabled={creatingForm}
                            className="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.98] text-white text-xs font-bold rounded-xl shadow-sm transition-all cursor-pointer self-start sm:self-auto disabled:opacity-60"
                        >
                            <Plus size={16} />
                            <span>{creatingForm ? 'Membuat...' : 'Buat Formulir Baru'}</span>
                        </button>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Total Formulir</p>
                                <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">{myForms.length}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-teal-50 dark:bg-teal-950/50 text-[#00897B] dark:text-teal-400">
                                <FileText size={20} />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Total Respons</p>
                                <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">{totalResponses}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-teal-50 dark:bg-teal-950/50 text-[#00897B] dark:text-teal-400">
                                <Users size={20} />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Dipublikasikan</p>
                                <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">{publishedCount}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400">
                                <Star size={20} />
                            </div>
                        </div>

                        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Draf</p>
                                <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">{draftCount}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-400">
                                <Clock size={20} />
                            </div>
                        </div>
                    </div>

                    <section className="space-y-4">
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="text-base font-bold text-slate-900 dark:text-white">Formulir Terbaru</h3>
                                <p className="text-xs text-slate-400 dark:text-slate-500 font-medium">
                                    {searchQuery ? `Hasil pencarian untuk "${searchQuery}"` : 'Formulir yang paling baru diperbarui'}
                                </p>
                            </div>
                            <button
                                onClick={() => navigate('/my-forms')}
                                className="text-xs font-bold text-[#00897B] dark:text-teal-400 hover:underline cursor-pointer"
                            >
                                Lihat semua &rarr;
                            </button>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                            {recentForms.map((form) => {
                                const status = typeof form.status === 'string' ? form.status : 'draft';
                                const isPublished = status.toLowerCase() === 'published';
                                const responseCount = form.responseCount ?? 0;

                                return (
                                    <div key={form.id} className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all flex flex-col justify-between overflow-hidden group">
                                        {/* Banner container with proper full view */}
                                        <div className="h-36 w-full relative overflow-hidden bg-slate-100 dark:bg-slate-800/80 flex items-center justify-center border-b border-slate-100 dark:border-slate-800">
                                            {form.bannerImage ? (
                                                <img
                                                    src={assetUrl(form.bannerImage)}
                                                    alt={form.title}
                                                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                                                />
                                            ) : (
                                                <div className="flex flex-col items-center justify-center gap-1.5 text-slate-400 dark:text-slate-500">
                                                    <FileText size={28} className="text-[#00897B]/50 dark:text-teal-400/50" />
                                                    <span className="text-[10px] font-bold uppercase tracking-wider">FormUp</span>
                                                </div>
                                            )}
                                            <span className={`absolute top-3 left-3 text-[10px] font-extrabold px-2.5 py-0.5 rounded-full uppercase tracking-wider shadow-xs ${
                                                isPublished 
                                                    ? 'bg-teal-500 text-white dark:bg-teal-600' 
                                                    : 'bg-slate-700/80 text-white backdrop-blur-xs'
                                            }`}>
                                                {isPublished ? 'Dipublikasikan' : 'Draf'}
                                            </span>
                                        </div>

                                        <div className="p-4 flex-1 flex flex-col justify-between space-y-3">
                                            <div>
                                                <h4 className="text-sm font-bold text-slate-900 dark:text-white line-clamp-1 group-hover:text-[#00897B] dark:group-hover:text-teal-400 transition-colors">
                                                    {form.title || 'Formulir Tanpa Judul'}
                                                </h4>
                                                <div className="flex items-center justify-between mt-2">
                                                    <p className="text-xs text-slate-400 dark:text-slate-500 font-medium">
                                                        {responseCount} respons
                                                    </p>
                                                    <span className="text-[11px] text-slate-400 dark:text-slate-500">
                                                        {form.createdAt ? new Date(form.createdAt).toLocaleDateString('id-ID', { month: 'short', day: 'numeric' }) : ''}
                                                    </span>
                                                </div>
                                            </div>

                                            <div className="flex items-center gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                    className="flex-1 py-2 px-2 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700/80 text-slate-700 dark:text-slate-200 font-bold text-xs rounded-xl transition-all flex items-center justify-center gap-1.5 border border-slate-200 dark:border-slate-700 cursor-pointer"
                                                >
                                                    <Edit3 size={13} /> Edit
                                                </button>
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                    className="flex-1 py-2 px-2 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700/80 text-slate-700 dark:text-slate-200 font-bold text-xs rounded-xl transition-all flex items-center justify-center gap-1.5 border border-slate-200 dark:border-slate-700 cursor-pointer"
                                                >
                                                    <BarChart2 size={13} /> Respons
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}

                            {/* <div
                                onClick={handleCreateNewForm}
                                className="bg-white dark:bg-slate-900 p-5 rounded-2xl border-2 border-dashed border-slate-200 dark:border-slate-800 shadow-sm hover:border-[#00897B] dark:hover:border-teal-400 transition-all flex flex-col items-center justify-center text-center cursor-pointer min-h-[220px] group"
                            >
                                <div className="w-11 h-11 rounded-full bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                                    <Plus size={22} />
                                </div>
                                <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200">Buat Formulir Baru</h4>
                                <p className="text-[11px] text-slate-400 dark:text-slate-500 font-medium mt-1 max-w-[160px]">
                                    Mulai dari templat atau bangun dari awal.
                                </p>
                            </div> */}
                        </div>

                        {recentForms.length === 0 && searchQuery && (
                            <div className="py-12 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                Tidak ada formulir yang cocok dengan pencarian "{searchQuery}".
                            </div>
                        )}
                    </section>

                </main>
            </div>
        </div>
    );
};

export default UserHome;