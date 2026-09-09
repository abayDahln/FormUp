import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, FileText, Users, CheckCircle2, Clock, Edit3, BarChart2, Sparkles, SearchX, ArrowRight, BookOpen, Compass, HelpCircle, ChevronDown } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import AIFormBuilderModal from '../../../components/ui/AIFormBuilderModal';
import OnboardingTour from '../../../components/ui/OnboardingTour';
import UserGuideModal from '../../../components/ui/UserGuideModal';
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
    const [onboardingTourOpen, setOnboardingTourOpen] = useState(false);
    const [userGuideOpen, setUserGuideOpen] = useState(false);
    const [createDropdownOpen, setCreateDropdownOpen] = useState(false);
    const createDropdownRef = useRef(null);

    useEffect(() => {
        const handleClickOutside = (e) => {
            if (createDropdownRef.current && !createDropdownRef.current.contains(e.target)) {
                setCreateDropdownOpen(false);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    // Register global trigger for manual tour launch from Sidebar/Topbar
    useEffect(() => {
        window.__startFormUpTour = () => {
            setOnboardingTourOpen(true);
        };
        return () => {
            delete window.__startFormUpTour;
        };
    }, []);

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

                // Cek apakah user baru (belum pernah menyelesaikan onboarding)
                const storageKey = `onboarding_completed_${user?.id || user?.email || 'default'}`;
                const hasCompletedOnboarding = localStorage.getItem(storageKey);
                if (!hasCompletedOnboarding) {
                    // Berikan sedikit jeda waktu render halaman dashboard sebelum tour muncul
                    setTimeout(() => {
                        setOnboardingTourOpen(true);
                    }, 500);
                }
            } catch (err) {
                console.error('Dashboard fetch error:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
    }, [navigate, user?.id, user?.email]);

    const handleOnboardingComplete = () => {
        const storageKey = `onboarding_completed_${user?.id || user?.email || 'default'}`;
        localStorage.setItem(storageKey, 'true');
    };

    const handleGoToBuilderTour = async () => {
        handleOnboardingComplete();
        setOnboardingTourOpen(false);
        if (myForms && myForms.length > 0) {
            navigate(`/forms/${myForms[0].id}/edit?tour=builder`);
        } else {
            // Jika belum ada formulir, buat formulir draf contoh lalu mulai tur di Form Builder
            try {
                const res = await createForm({
                    title: 'Formulir Pertama Saya',
                    description: 'Formulir latihan panduan FormUp',
                });
                if (res.ok && res.data?.id) {
                    navigate(`/forms/${res.data.id}/edit?tour=builder`);
                } else {
                    navigate('/create-form');
                }
            } catch (err) {
                console.error('Error creating tour form:', err);
                navigate('/create-form');
            }
        }
    };

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

                        <div className="relative" ref={createDropdownRef}>
                            <button
                                onClick={() => setCreateDropdownOpen(prev => !prev)}
                                data-tour="create-form-btn"
                                className="inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-teal-600 hover:bg-teal-700 dark:bg-teal-600 dark:hover:bg-teal-500 text-white text-xs font-semibold rounded-xl shadow-xs transition-all cursor-pointer"
                            >
                                <Plus size={16} />
                                <span>Buat Formulir</span>
                                <ChevronDown size={14} className={`transition-transform duration-200 ${createDropdownOpen ? 'rotate-180' : ''}`} />
                            </button>
                            {createDropdownOpen && (
                                <div className="absolute right-0 top-full mt-1 w-52 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl shadow-xl z-50 overflow-hidden">
                                    <button
                                        onClick={() => { setCreateDropdownOpen(false); handleCreateNewForm(); }}
                                        disabled={creatingForm}
                                        className="w-full flex items-center gap-3 px-4 py-3 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer text-left"
                                    >
                                        <Plus size={15} className="text-slate-500" />
                                        <div>
                                            <div>Buat Manual</div>
                                            <div className="text-[10px] font-normal text-slate-400">Mulai dari formulir kosong</div>
                                        </div>
                                    </button>
                                    <button
                                        onClick={() => { setCreateDropdownOpen(false); setAiFormBuilderOpen(true); }}
                                        data-tour="create-ai-btn"
                                        className="w-full flex items-center gap-3 px-4 py-3 text-xs font-bold text-teal-700 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/30 transition-colors cursor-pointer text-left"
                                    >
                                        <Sparkles size={15} className="text-teal-500" />
                                        <div>
                                            <div>Buat dengan AI ✨</div>
                                            <div className="text-[10px] font-normal text-slate-400">Generate otomatis dengan AI</div>
                                        </div>
                                    </button>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Stats Metrics */}
                    <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4" data-tour="stats-overview">
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
                    <section className="space-y-4" data-tour="recent-forms-section">
                        <div className="flex items-center justify-between">
                            <div>
                                <h2 className="text-base font-bold text-slate-900 dark:text-white">Formulir Terbaru</h2>
                                <p className="text-xs text-slate-500 dark:text-slate-400">
                                    {searchQuery ? `Hasil pencarian untuk "${searchQuery}"` : 'Formulir yang terakhir kali diubah'}
                                </p>
                            </div>
                            {myForms.length > 0 && (
                                <button
                                    onClick={() => navigate('/my-forms')}
                                    className="inline-flex items-center gap-1 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:text-teal-700 dark:hover:text-teal-300 transition-colors cursor-pointer"
                                >
                                    <span>Lihat semua</span>
                                    <ArrowRight size={14} />
                                </button>
                            )}
                        </div>

                        {/* FITUR 1: Empty State Dashboard (User belum punya form sama sekali) */}
                        {myForms.length === 0 ? (
                            <div className="bg-white dark:bg-slate-900 rounded-3xl border-2 border-dashed border-teal-200/80 dark:border-teal-900/40 p-8 sm:p-12 text-center flex flex-col items-center justify-center space-y-5 shadow-xs transition-all hover:border-teal-400">
                                {/* Visual Badge / Icon */}
                                <div className="relative">
                                    <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-3xl bg-gradient-to-tr from-teal-500/20 via-emerald-500/10 to-teal-100 dark:from-teal-900/40 dark:to-slate-800 flex items-center justify-center text-[#00897B] dark:text-teal-400 shadow-inner">
                                        <FileText size={36} className="transform -rotate-6" />
                                    </div>
                                    <div className="absolute -top-1.5 -right-1.5 w-7 h-7 rounded-full bg-gradient-to-r from-teal-600 to-emerald-500 text-white flex items-center justify-center shadow-md animate-bounce">
                                        <Sparkles size={14} />
                                    </div>
                                </div>

                                {/* Headline & Description */}
                                <div className="space-y-1.5 max-w-md">
                                    <h3 className="text-lg sm:text-xl font-extrabold text-slate-900 dark:text-white tracking-tight">
                                        Belum Ada Formulir Nih
                                    </h3>
                                    <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 leading-relaxed font-medium">
                                        Buat formulir atau kuis pertamamu sekarang! Anda bisa membuatnya secara manual atau gunakan kecerdasan AI untuk menyusunnya otomatis dalam sekejap.
                                    </p>
                                </div>

                                {/* Action Buttons */}
                                <div className="flex flex-col sm:flex-row items-center gap-3 w-full sm:w-auto pt-2">
                                    <button
                                        type="button"
                                        onClick={handleCreateNewForm}
                                        disabled={creatingForm}
                                        className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-5 py-3 bg-teal-600 hover:bg-teal-700 dark:bg-teal-600 dark:hover:bg-teal-500 text-white text-xs font-bold rounded-xl shadow-md transition-all active:scale-95 cursor-pointer disabled:opacity-60"
                                    >
                                        <Plus size={16} />
                                        <span>{creatingForm ? 'Membuat...' : 'Buat Formulir Pertama'}</span>
                                    </button>

                                    <button
                                        type="button"
                                        onClick={() => setAiFormBuilderOpen(true)}
                                        className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-5 py-3 bg-gradient-to-r from-teal-500/10 to-emerald-500/10 hover:from-teal-500/20 hover:to-emerald-500/20 text-[#00897B] dark:text-teal-400 border border-teal-500/30 text-xs font-bold rounded-xl transition-all active:scale-95 cursor-pointer"
                                    >
                                        <Sparkles size={15} />
                                        <span>Coba AI Form Builder</span>
                                    </button>
                                </div>

                                {/* Sublink to User Guide */}
                                <button
                                    type="button"
                                    onClick={() => setUserGuideOpen(true)}
                                    className="inline-flex items-center gap-1.5 text-xs font-bold text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 transition-colors cursor-pointer pt-2"
                                >
                                    <BookOpen size={14} />
                                    <span>Butuh panduan? Pelajari cara pakai FormUp</span>
                                </button>
                            </div>
                        ) : (
                            /* Responsive Grid: Menyamping di HP, Grid fleksibel 3-5 kolom di Desktop */
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
                        )}

                        {/* Empty State Search */}
                        {recentForms.length === 0 && searchQuery && myForms.length > 0 && (
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

            {/* FITUR 2: Guided Onboarding Tour (Spotlight) */}
            <OnboardingTour
                isOpen={onboardingTourOpen}
                onClose={() => setOnboardingTourOpen(false)}
                onComplete={handleOnboardingComplete}
                steps={[
                    {
                        selector: '[data-tour="sidebar-nav"]',
                        title: 'Navigasi Menu Lengkap',
                        description: 'Akses cepat ke Dashboard, daftar Formulir Saya, Respons masuk, templat siap pakai, dan Riwayat aktivitas Anda.',
                        icon: <Compass size={18} />,
                        placement: 'right',
                        badge: 'Navigasi'
                    },
                    {
                        selector: '[data-tour="create-form-btn"]',
                        title: 'Buat Formulir Baru',
                        description: 'Klik di sini untuk langsung membuat formulir kosong. Anda dapat menambahkan aneka tipe soal pilihan ganda, essay, rumus matematika, dan kunci jawaban.',
                        icon: <Plus size={18} />,
                        placement: 'bottom',
                        badge: 'Mulai Cepat'
                    },
                    {
                        selector: '[data-tour="create-ai-btn"]',
                        title: 'Kecerdasan Buat Form AI',
                        description: 'Cukup deskripsikan topik atau materi kuis Anda, AI FormUp akan otomatis merancang pertanyaan dan opsi kunci jawaban lengkap untuk Anda!',
                        icon: <Sparkles size={18} />,
                        placement: 'bottom',
                        badge: 'Kecerdasan AI'
                    },
                    {
                        selector: '[data-tour="stats-overview"]',
                        title: 'Ringkasan Aktivitas Real-Time',
                        description: 'Pantau total formulir, jumlah responden yang telah mengisi, serta status formulir aktif maupun draf Anda di sini.',
                        icon: <BarChart2 size={18} />,
                        placement: 'bottom',
                        badge: 'Statistik'
                    },
                    {
                        selector: '[data-tour="recent-forms-section"]',
                        title: 'Daftar Formulir & Aksi Cepat',
                        description: 'Kelola formulir Anda dengan mudah. Anda dapat langsung mengedit pertanyaan, menyalin link, atau memeriksa evaluasi respons masuk kapan saja.',
                        icon: <FileText size={18} />,
                        placement: 'top',
                        badge: 'Koleksi Form'
                    },
                    {
                        selector: '[data-tour="user-guide-btn"]',
                        title: 'Panduan Pengguna Kapan Saja',
                        description: 'Ingin membaca ringkasan fitur atau mengulang tur ini? Klik menu Panduan Pengguna di sidebar ini kapan saja Anda butuhkan!',
                        icon: <HelpCircle size={18} />,
                        placement: 'right',
                        badge: 'Bantuan'
                    },
                    {
                        selector: '[data-tour="create-form-btn"]',
                        title: 'Lanjut ke Panduan Form Builder?',
                        description: 'Eksplorasi cara menyusun pertanyaan kuis, rumus matematika KaTeX, batasan timer pengerjaan, dan Mode Ujian Anti-Curang langsung di editor Form Builder.',
                        icon: <Sparkles size={18} />,
                        placement: 'bottom',
                        badge: 'Langkah Lanjutan',
                        nextBtnText: 'Selesai di Dashboard',
                        actionButton: {
                            text: 'Buka Form Builder & Lanjut Panduan →',
                            icon: <Compass size={15} />,
                            onClick: handleGoToBuilderTour
                        }
                    }
                ]}
            />

            {/* FITUR 3: Popup Ringkasan Panduan Pengguna */}
            <UserGuideModal
                isOpen={userGuideOpen}
                onClose={() => setUserGuideOpen(false)}
                onStartTour={() => {
                    setUserGuideOpen(false);
                    setOnboardingTourOpen(true);
                }}
            />
        </div>
    );
};

export default UserHome;