import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, FileText, Users, CheckCircle2, Clock, Edit3, BarChart2, Sparkles, SearchX, ArrowRight, BookOpen, Compass, HelpCircle, ChevronDown } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import AIFormBuilderModal from '../../../components/ui/AIFormBuilderModal';
import OnboardingTour from '../../../components/ui/OnboardingTour';
import UserGuideModal from '../../../components/ui/UserGuideModal';
import {
    getMyForms,
    getMyStats,
    getFormResponses,
    getLocalUser,
    clearSession,
    assetUrl,
    createForm
} from '../../../services/apiService';import { motion, AnimatePresence } from 'framer-motion';

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
    const [stats, setStats] = useState(null);
    const [loading, setLoading] = useState(true);
    const [user] = useState(() => getLocalUser());
    const [searchQuery, setSearchQuery] = useState('');
    const [creatingForm, setCreatingForm] = useState(false);
    const [aiFormBuilderOpen, setAiFormBuilderOpen] = useState(false);
    const [onboardingTourOpen, setOnboardingTourOpen] = useState(false);
    const [userGuideOpen, setUserGuideOpen] = useState(false);
    const [createDropdownOpen, setCreateDropdownOpen] = useState(false);
    const createDropdownRef = useRef(null);
    // 1. Tambahkan state ini di atas bersama state lainnya
    const [recentResponses, setRecentResponses] = useState([]);

    useEffect(() => {
    const fetchData = async () => {
        try {
            setLoading(true);

            const [formsResult, statsResult] = await Promise.all([
                getMyForms(),
                getMyStats().catch(() => null),
            ]);

            if (formsResult.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }

            if (formsResult.ok && Array.isArray(formsResult.data)) {
                setMyForms(formsResult.data);

                // Ambil response dari seluruh form milik user
                                const responseResults = await Promise.all(
                    formsResult.data.map(async (form) => {
                        try {
                            const result = await getFormResponses(form.id, {
                                page: 1,
                                pageSize: 10,
                            });

                            if (result?.ok) {
                                const list = Array.isArray(result.data)
                                    ? result.data
                                    : (result.data?.responses || result.data?.items || []);

                                return list.map((response) => ({
                                    ...response,
                                    formTitle: form.title || 'Formulir Tanpa Judul',
                                    formId: form.id,
                                }));
                            }

                            return [];
                        } catch (error) {
                            console.error(
                                `Gagal mengambil response form ${form.id}:`,
                                error
                            );
                            return [];
                        }
                    })
                );

                // Gabungkan semua response dari semua form
                const allResponses = responseResults.flat();

                // Urutkan berdasarkan waktu terbaru
                allResponses.sort((a, b) => {
                    const dateA = new Date(
                        a.submittedAt ||
                        a.createdAt ||
                        a.updatedAt ||
                        0
                    ).getTime();

                    const dateB = new Date(
                        b.submittedAt ||
                        b.createdAt ||
                        b.updatedAt ||
                        0
                    ).getTime();

                    return dateB - dateA;
                });

                // Hanya tampilkan 10 response terbaru
                setRecentResponses(allResponses.slice(0, 10));
            }

            if (statsResult?.ok && statsResult?.data) {
                setStats(statsResult.data);
            }

            // Cek onboarding
            const storageKey =
                `onboarding_completed_${user?.id || user?.email || 'default'}`;

            const hasCompletedOnboarding =
                localStorage.getItem(storageKey);

            if (!hasCompletedOnboarding) {
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

    const handleGoToMyForms = () => {
    // Ganti '/my-forms' sesuai path route halaman MyForms Anda
    navigate('/my-forms'); 
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

                        {/* Skeleton Content Grid (2 Kolom: Formulir Saya & Responden Terbaru) */}
<div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

  {/* Kolom Kiri: Formulir Saya (2/3) */}
  <div className="lg:col-span-2 bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 space-y-4 animate-pulse">
    <div className="flex justify-between items-center mb-2">
      <div className="h-5 bg-slate-200 dark:bg-slate-800 rounded w-32" />
      <div className="h-4 bg-slate-200 dark:bg-slate-800 rounded w-20" />
    </div>

    {/* 4 Item List Formulir */}
    {[1, 2, 3, 4].map((i) => (
      <div key={i} className="flex items-center justify-between p-3 rounded-xl border border-slate-100 dark:border-slate-800">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-lg bg-slate-200 dark:bg-slate-800 shrink-0" />
          <div className="space-y-2">
            <div className="h-4 w-44 bg-slate-200 dark:bg-slate-800 rounded" />
            <div className="h-3 w-20 bg-slate-100 dark:bg-slate-800/60 rounded" />
          </div>
        </div>
        <div className="h-3 w-8 bg-slate-100 dark:bg-slate-800/60 rounded" />
      </div>
    ))}
  </div>

  {/* Kolom Kanan: Responden Terbaru (1/3) */}
  <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 space-y-4 animate-pulse">
    <div className="flex justify-between items-center mb-2">
      <div className="h-5 bg-slate-200 dark:bg-slate-800 rounded w-36" />
      <div className="h-4 bg-slate-200 dark:bg-slate-800 rounded w-16" />
    </div>

    {/* 4 Item List Responden */}
    {[1, 2, 3, 4].map((i) => (
      <div key={i} className="flex items-center justify-between py-2">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-800 shrink-0" />
          <div className="h-4 w-28 bg-slate-200 dark:bg-slate-800 rounded" />
        </div>
        <div className="h-3 w-10 bg-slate-100 dark:bg-slate-800/60 rounded" />
      </div>
    ))}
  </div>

</div>
                    </main>
                </div>
            </div>
        );
    }

const formatRelativeTime = (dateString) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now - date) / 1000);

    if (diffInSeconds < 60) return 'Baru saja';
    if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)} mnt lalu`;
    if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)} jam lalu`;
    if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)} hr lalu`;
    return date.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
  };

  const popUpVariants = {
    hidden: { opacity: 0, scale: 0.95 },
    visible: { 
      opacity: 1, 
      scale: 1,
      transition: { duration: 0.25, ease: "easeOut" }
    }
  };

  const fadeInVariants = {
    hidden: { opacity: 0 },
    visible: { 
      opacity: 1,
      transition: { duration: 0.3 }
    }
  };

  return (
  <div className="flex min-h-screen w-full bg-slate-50 dark:bg-slate-950 font-sans antialiased text-slate-900 dark:text-slate-100 transition-colors">
  <Sidebar />

  <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
    <main className="flex-1 w-full p-3 sm:p-6 lg:p-8 space-y-6 sm:space-y-8">
      <Topbar 
        searchQuery={searchQuery} 
        onSearchChange={setSearchQuery} 
        placeholder="Cari..." 
      />

      {/* Header Section */}
<div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 sm:gap-4">
  <div className="space-y-1">
    <div className="flex items-center gap-2">
      <h1 className="text-lg sm:text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-50">
        {getGreeting()}, {user?.fullname ? user.fullname.split(' ')[0] : 'Pengguna'}
      </h1>
      <Sparkles size={18} className="text-teal-600 dark:text-teal-400 shrink-0" />
    </div>
    {/* Teks Deskripsi Ringkas & Clean di Mobile */}
    <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 leading-relaxed max-w-xl">
      Ringkasan performa & statistik formulir Anda hari ini.
    </p>
  </div>

  {/* Action Button & Dropdown Wrapper */}
  <button
      onClick={handleGoToMyForms}
      data-tour="create-form-btn"
      className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-teal-600 hover:bg-teal-700 text-white text-xs sm:text-sm font-semibold rounded-xl transition-all cursor-pointer shadow-sm active:scale-95"
    >
      <Plus size={16} />
      <span>Buat Formulir</span>
    </button>
</div>

{/* BARIS 1: Stats Metrics (PASTI 2 KOLOM DI MOBILE / HP) */}
<AnimatePresence mode="wait">
  {loading ? (
    <motion.div
      key="dashboard-skeleton"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      className="space-y-6"
    >
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
        {[1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="bg-white dark:bg-slate-800/80 p-3 sm:p-4 rounded-2xl border border-slate-100 dark:border-slate-800 flex items-center justify-between animate-pulse"
          >
            <div className="space-y-2">
              <div className="h-2.5 w-14 bg-slate-200 dark:bg-slate-700 rounded" />
              <div className="h-6 w-10 bg-slate-300 dark:bg-slate-600 rounded-lg" />
            </div>
            <div className="w-8 h-8 rounded-xl bg-slate-100 dark:bg-slate-700" />
          </div>
        ))}
      </div>
    </motion.div>
  ) : (
    (() => {
      const totalFormCount = stats?.totalForms ?? stats?.formsCount ?? myForms.length;
      const totalResponsesCount = stats?.totalResponses ?? stats?.responsesCount ?? totalResponses;
      const activeCount = stats?.publishedForms ?? stats?.publishedCount ?? publishedCount;
      const draftCountVal = stats?.draftForms ?? stats?.draftCount ?? draftCount;

      return (
        /* Perubahan di sini: 'grid-cols-2 lg:grid-cols-4' kunci 2 kolom di layar HP */
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-5" data-tour="stats-overview">
          
          {/* Card 1: Total Form */}
          <motion.div
            variants={popUpVariants}
            initial="hidden"
            animate="visible"
            className="relative overflow-hidden bg-gradient-to-br from-teal-500 to-teal-700 dark:from-teal-600 dark:to-teal-900 p-3.5 sm:p-5 rounded-2xl text-white shadow-md shadow-teal-500/10 flex items-center justify-between"
          >
            <div className="relative z-10 space-y-0.5">
              <p className="text-[10px] sm:text-xs font-semibold text-teal-100 uppercase tracking-wider">Total Form</p>
              <h3 className="text-lg sm:text-3xl font-black text-white">{totalFormCount}</h3>
            </div>
            <div className="relative z-10 p-2 sm:p-3 bg-white/10 backdrop-blur-md rounded-xl sm:rounded-2xl border border-white/20 text-white shrink-0">
              <FileText className="w-4 h-4 sm:w-6 sm:h-6" />
            </div>
            <div className="absolute -right-6 -bottom-6 w-20 h-20 bg-white/10 rounded-full blur-lg pointer-events-none" />
          </motion.div>

          {/* Card 2: Total Respons */}
          <motion.div
            variants={popUpVariants}
            initial="hidden"
            animate="visible"
            className="relative overflow-hidden bg-gradient-to-br from-indigo-500 to-indigo-700 dark:from-indigo-600 dark:to-indigo-900 p-3.5 sm:p-5 rounded-2xl text-white shadow-md shadow-indigo-500/10 flex items-center justify-between"
          >
            <div className="relative z-10 space-y-0.5">
              <p className="text-[10px] sm:text-xs font-semibold text-indigo-100 uppercase tracking-wider">Total Respons</p>
              <h3 className="text-lg sm:text-3xl font-black text-white">{totalResponsesCount}</h3>
            </div>
            <div className="relative z-10 p-2 sm:p-3 bg-white/10 backdrop-blur-md rounded-xl sm:rounded-2xl border border-white/20 text-white shrink-0">
              <Users className="w-4 h-4 sm:w-6 sm:h-6" />
            </div>
            <div className="absolute -right-6 -bottom-6 w-20 h-20 bg-white/10 rounded-full blur-lg pointer-events-none" />
          </motion.div>

          {/* Card 3: Aktif */}
          <motion.div
            variants={popUpVariants}
            initial="hidden"
            animate="visible"
            className="relative overflow-hidden bg-gradient-to-br from-sky-500 to-sky-700 dark:from-sky-600 dark:to-sky-900 p-3.5 sm:p-5 rounded-2xl text-white shadow-md shadow-sky-500/10 flex items-center justify-between"
          >
            <div className="relative z-10 space-y-0.5">
              <p className="text-[10px] sm:text-xs font-semibold text-sky-100 uppercase tracking-wider">Aktif</p>
              <h3 className="text-lg sm:text-3xl font-black text-white">{activeCount}</h3>
            </div>
            <div className="relative z-10 p-2 sm:p-3 bg-white/10 backdrop-blur-md rounded-xl sm:rounded-2xl border border-white/20 text-white shrink-0">
              <CheckCircle2 className="w-4 h-4 sm:w-6 sm:h-6" />
            </div>
            <div className="absolute -right-6 -bottom-6 w-20 h-20 bg-white/10 rounded-full blur-lg pointer-events-none" />
          </motion.div>

          {/* Card 4: Draf */}
          <motion.div
            variants={popUpVariants}
            initial="hidden"
            animate="visible"
            className="relative overflow-hidden bg-gradient-to-br from-amber-500 to-amber-700 dark:from-amber-600 dark:to-amber-900 p-3.5 sm:p-5 rounded-2xl text-white shadow-md shadow-amber-500/10 flex items-center justify-between"
          >
            <div className="relative z-10 space-y-0.5">
              <p className="text-[10px] sm:text-xs font-semibold text-amber-100 uppercase tracking-wider">Draf</p>
              <h3 className="text-lg sm:text-3xl font-black text-white">{draftCountVal}</h3>
            </div>
            <div className="relative z-10 p-2 sm:p-3 bg-white/10 backdrop-blur-md rounded-xl sm:rounded-2xl border border-white/20 text-white shrink-0">
              <Clock className="w-4 h-4 sm:w-6 sm:h-6" />
            </div>
            <div className="absolute -right-6 -bottom-6 w-20 h-20 bg-white/10 rounded-full blur-lg pointer-events-none" />
          </motion.div>

        </div>
      );
    })()
  )}
</AnimatePresence>

      {/* BARIS 2: Layout Split */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
        
        {/* KOLOM KIRI: Card Formulir */}
        <section className="lg:col-span-2" data-tour="recent-forms-section">
          <AnimatePresence mode="wait">
            {loading ? (
              <motion.div 
                key="forms-skeleton"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 space-y-3"
              >
                {[1, 2, 3, 4].map((i) => (
                  <div key={i} className="h-14 bg-slate-200 dark:bg-slate-800 rounded-xl w-full animate-pulse" />
                ))}
              </motion.div>
            ) : (
              <motion.div 
                key="forms-card"
                variants={popUpVariants}
                initial="hidden"
                animate="visible"
                className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-xs overflow-hidden"
              >
                <div className="p-4 sm:p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
                  <h2 className="text-base font-bold text-slate-900 dark:text-white">Formulir Saya</h2>
                  {myForms.length > 0 && (
                    <button
                      onClick={() => navigate('/my-forms')}
                      className="inline-flex items-center gap-1.5 text-xs font-bold text-teal-600 hover:text-teal-700 transition-colors cursor-pointer"
                    >
                      <span>Lihat Semua</span>
                      <ArrowRight size={14} />
                    </button>
                  )}
                </div>

                {myForms.length === 0 ? (
                  <div className="p-8 sm:p-10 text-center flex flex-col items-center justify-center space-y-3">
                    <FileText size={32} className="text-slate-300 dark:text-slate-600" />
                    <p className="text-sm font-semibold text-slate-600 dark:text-slate-400">Belum ada formulir</p>
                  </div>
                ) : (
                  <div className="divide-y divide-slate-100 dark:divide-slate-800/60">
                    {recentForms.slice(0, 10).map((form, index) => {
                      const isPublished = (form.status || '').toLowerCase() === 'published' || form.isPublished;
                      const responseCount = form.responseCount ?? form.responsesCount ?? 0;

                      return (
                        <motion.div 
                          key={form.id || index}
                          variants={fadeInVariants}
                          initial="hidden"
                          animate="visible"
                          onClick={() => navigate(`/forms/${form.id}/edit`)}
                          className="p-3.5 sm:p-4 sm:px-5 hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-all cursor-pointer flex items-center justify-between gap-3 group"
                        >
                          <div className="flex items-center gap-3 min-w-0 flex-1">
                            <div className="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-teal-50 dark:bg-teal-950/50 text-teal-600 dark:text-teal-400 flex items-center justify-center shrink-0 border border-teal-100/50 dark:border-teal-900/30">
                              <FileText size={18} />
                            </div>
                            <div className="min-w-0 flex-1">
                              <h3 className="text-xs sm:text-sm font-semibold text-slate-900 dark:text-slate-100 truncate group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
                                {form.title || 'Formulir Tanpa Judul'}
                              </h3>
                              <div className="flex items-center gap-1.5 sm:gap-2 mt-0.5 sm:mt-1 flex-wrap">
                                <span className={`text-[9px] sm:text-[10px] font-bold px-1.5 sm:px-2 py-0.5 rounded uppercase ${
                                  isPublished 
                                    ? 'bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400' 
                                    : 'bg-slate-100 dark:bg-slate-800 text-slate-400'
                                }`}>
                                  {isPublished ? 'Aktif' : 'Draf'}
                                </span>
                                <span className="text-[11px] sm:text-xs text-slate-400">
                                  {form.createdAt ? new Date(form.createdAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) : ''}
                                </span>
                              </div>
                            </div>
                          </div>

                          <div className="flex items-center gap-2 shrink-0" onClick={(e) => e.stopPropagation()}>
                            <button
                              onClick={() => navigate(`/forms/${form.id}/responses`)}
                              className="flex items-center gap-1 px-2.5 sm:px-3 py-1 sm:py-1.5 text-slate-600 hover:text-teal-600 dark:text-slate-300 dark:hover:text-teal-400 bg-slate-50 dark:bg-slate-800 hover:bg-teal-50/80 rounded-lg text-xs font-semibold border border-slate-200/60 dark:border-slate-700/60 transition-colors cursor-pointer"
                            >
                              <BarChart2 size={14} />
                              <span>{responseCount}</span>
                            </button>
                          </div>
                        </motion.div>
                      );
                    })}
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        </section>

        {/* KOLOM KANAN: Data Responden Terbaru */}
        <aside className="space-y-4">
          <AnimatePresence mode="wait">
            {loading ? (
              <motion.div 
                key="resp-skeleton"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 space-y-3"
              >
                {[1, 2, 3].map((i) => (
                  <div key={i} className="h-12 bg-slate-200 dark:bg-slate-800 rounded-xl w-full animate-pulse" />
                ))}
              </motion.div>
            ) : (
              <motion.div 
                key="resp-card"
                variants={popUpVariants}
                initial="hidden"
                animate="visible"
                className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 sm:p-5 space-y-4 shadow-xs"
              >
                <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                  <div className="flex items-center gap-2">
                    <Users size={18} className="text-teal-600 dark:text-teal-400" />
                    <h2 className="text-sm font-bold text-slate-900 dark:text-white">Responden Terbaru</h2>
                  </div>
                </div>

                {recentResponses && recentResponses.length > 0 ? (
                  <div className="space-y-2">
                    {recentResponses.slice(0, 10).map((resp, idx) => {
                      const respondentName =
                        resp.respondentName ||
                        resp.name ||
                        resp.respondent?.fullname ||
                        resp.respondent?.fullName ||
                        resp.respondent?.name ||
                        'Responden';

                      const respondentEmail =
                        resp.respondentEmail ||
                        resp.email ||
                        resp.respondent?.email ||
                        '-';

                      const submittedAt =
                        resp.submittedAt ||
                        resp.createdAt ||
                        resp.updatedAt;

                      return (
                        <motion.div
                          key={resp.id || `${resp.formId || 'resp'}-${idx}`}
                          variants={fadeInVariants}
                          initial="hidden"
                          animate="visible"
                          className="flex items-start gap-2.5 p-2 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors"
                        >
                          <div className="w-7 h-7 sm:w-8 sm:h-8 rounded-full bg-teal-100 dark:bg-teal-900/60 text-teal-700 dark:text-teal-300 font-bold text-[11px] sm:text-xs flex items-center justify-center shrink-0 mt-0.5">
                            {respondentName.charAt(0).toUpperCase()}
                          </div>

                          <div className="min-w-0 flex-1">
                            <div className="flex items-center justify-between gap-1">
                              <p className="text-xs font-bold text-slate-800 dark:text-slate-200 truncate">
                                {respondentName}
                              </p>

                              <span className="text-[10px] text-slate-400 shrink-0">
                                {formatRelativeTime(submittedAt)}
                              </span>
                            </div>

                            <p className="text-[11px] sm:text-xs text-slate-500 dark:text-slate-400 truncate mt-0.5">
                              {respondentEmail}
                            </p>
                          </div>
                        </motion.div>
                      );
                    })}
                  </div>
                ) : (
                  <div className="py-8 text-center">
                    <Users
                      size={28}
                      className="mx-auto text-slate-300 dark:text-slate-600 mb-2"
                    />
                    <p className="text-sm font-semibold text-slate-600 dark:text-slate-400">
                      Belum ada respons
                    </p>
                    <p className="text-xs text-slate-400 dark:text-slate-500 mt-1">
                      Respons terbaru akan muncul di sini.
                    </p>
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        </aside>

      </div>
    </main>
  </div>

  {/* Modals & Tours */}
  <AIFormBuilderModal
    isOpen={aiFormBuilderOpen}
    onClose={() => setAiFormBuilderOpen(false)}
    onFormCreated={(newId) => navigate(`/forms/${newId}/edit`)}
  />

  <OnboardingTour
    isOpen={onboardingTourOpen}
    onClose={() => setOnboardingTourOpen(false)}
    onComplete={handleOnboardingComplete}
    steps={[
      {
        selector: '[data-tour="create-form-btn"]',
        title: 'Buat Formulir Baru',
        description: 'Klik di sini untuk langsung membuat formulir kosong.',
        icon: <Plus size={18} />,
        placement: 'bottom',
        badge: 'Mulai Cepat'
      },
      {
        selector: '[data-tour="create-ai-btn"]',
        title: 'Kecerdasan Buat Form AI',
        description: 'Cukup deskripsikan topik Anda, AI FormUp akan otomatis merancang pertanyaan!',
        icon: <Sparkles size={18} />,
        placement: 'bottom',
        badge: 'Kecerdasan AI',
        action: () => setCreateDropdownOpen(true)
      }
    ]}
  />
</div>
);
};

export default UserHome;
