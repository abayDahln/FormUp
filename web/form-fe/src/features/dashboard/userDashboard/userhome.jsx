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

  // Animasi Pop-Up Ringan untuk Card
  const popUpVariants = {
    hidden: { opacity: 0, scale: 0.95 },
    visible: { 
      opacity: 1, 
      scale: 1,
      transition: { duration: 0.25, ease: "easeOut" }
    }
  };

  // Animasi Simple Fade-In untuk Tiap Baris Data
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
        <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">
          <Topbar 
            searchQuery={searchQuery} 
            onSearchChange={setSearchQuery} 
            placeholder="Cari..." 
          />

          {/* Header Section */}
          <div className="flex items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-slate-900 dark:text-slate-50">
                {getGreeting()}, {user?.fullname ? user.fullname.split(' ')[0] : 'Pengguna'}
              </h1>
              <Sparkles size={18} className="text-teal-600 dark:text-teal-400" />
            </div>

            <div className="relative" ref={createDropdownRef}>
              <button
                onClick={() => setCreateDropdownOpen(prev => !prev)}
                data-tour="create-form-btn"
                className="inline-flex items-center gap-2 px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white text-xs font-semibold rounded-xl transition-all cursor-pointer shadow-sm active:scale-95"
              >
                <Plus size={16} />
                <span>Buat Formulir</span>
                <ChevronDown size={14} className={`transition-transform duration-200 ${createDropdownOpen ? 'rotate-180' : ''}`} />
              </button>

              {createDropdownOpen && (
                <div className="absolute right-0 top-full mt-1 w-48 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl shadow-lg z-50 overflow-hidden">
                  <button
                    onClick={() => { setCreateDropdownOpen(false); handleCreateNewForm(); }}
                    disabled={creatingForm}
                    className="w-full flex items-center gap-2 px-3.5 py-2.5 text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors text-left"
                  >
                    <Plus size={14} />
                    <span>Buat Manual</span>
                  </button>
                  <button
                    onClick={() => { setCreateDropdownOpen(false); setAiFormBuilderOpen(true); }}
                    data-tour="create-ai-btn"
                    className="w-full flex items-center gap-2 px-3.5 py-2.5 text-xs font-semibold text-teal-600 dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/40 transition-colors text-left"
                  >
                    <Sparkles size={14} />
                    <span>Buat dengan AI</span>
                  </button>
                </div>
              )}
            </div>
          </div>

          {/* BARIS 1: Stats Metrics */}
          <AnimatePresence mode="wait">
            {loading ? (
              /* SKELETON ANIMATED */
              <motion.div
                key="skeleton-stats"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4"
              >
                {[1, 2, 3, 4].map((i) => (
                  <div
                    key={i}
                    className="bg-slate-200 dark:bg-slate-800 h-24 rounded-2xl p-4 flex flex-col justify-between animate-pulse"
                  />
                ))}
              </motion.div>
            ) : (
              /* CARDS STATS (ANIMASI POP-UP) */
              (() => {
                const totalFormCount = stats?.totalForms ?? stats?.formsCount ?? myForms.length;
                const totalResponsesCount = stats?.totalResponses ?? stats?.responsesCount ?? totalResponses;
                const activeCount = stats?.publishedForms ?? stats?.publishedCount ?? publishedCount;
                const draftCountVal = stats?.draftForms ?? stats?.draftCount ?? draftCount;

                return (
                  <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4" data-tour="stats-overview">
                    <motion.div
                      variants={popUpVariants}
                      initial="hidden"
                      animate="visible"
                      className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-xs flex items-center justify-between"
                    >
                      <div>
                        <p className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Total Form</p>
                        <h3 className="text-xl font-bold text-slate-900 dark:text-white mt-0.5">{totalFormCount}</h3>
                      </div>
                      <div className="p-2 rounded-xl bg-teal-50 dark:bg-teal-950/50 text-teal-600 dark:text-teal-400">
                        <FileText size={18} />
                      </div>
                    </motion.div>

                    <motion.div
                      variants={popUpVariants}
                      initial="hidden"
                      animate="visible"
                      className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-xs flex items-center justify-between"
                    >
                      <div>
                        <p className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Total Respons</p>
                        <h3 className="text-xl font-bold text-slate-900 dark:text-white mt-0.5">{totalResponsesCount}</h3>
                      </div>
                      <div className="p-2 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 dark:text-indigo-400">
                        <Users size={18} />
                      </div>
                    </motion.div>

                    <motion.div
                      variants={popUpVariants}
                      initial="hidden"
                      animate="visible"
                      className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-xs flex items-center justify-between"
                    >
                      <div>
                        <p className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Aktif</p>
                        <h3 className="text-xl font-bold text-slate-900 dark:text-white mt-0.5">{activeCount}</h3>
                      </div>
                      <div className="p-2 rounded-xl bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400">
                        <CheckCircle2 size={18} />
                      </div>
                    </motion.div>

                    <motion.div
                      variants={popUpVariants}
                      initial="hidden"
                      animate="visible"
                      className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-xs flex items-center justify-between"
                    >
                      <div>
                        <p className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Draf</p>
                        <h3 className="text-xl font-bold text-slate-900 dark:text-white mt-0.5">{draftCountVal}</h3>
                      </div>
                      <div className="p-2 rounded-xl bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-400">
                        <Clock size={18} />
                      </div>
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
                      <div key={i} className="h-12 bg-slate-200 dark:bg-slate-800 rounded-xl w-full animate-pulse" />
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
                    <div className="p-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
                      <h2 className="text-sm font-bold text-slate-900 dark:text-white">Formulir Saya</h2>
                      {myForms.length > 0 && (
                        <button
                          onClick={() => navigate('/my-forms')}
                          className="inline-flex items-center gap-1 text-xs font-semibold text-teal-600 hover:text-teal-700 transition-colors cursor-pointer"
                        >
                          <span>Lihat Semua</span>
                          <ArrowRight size={13} />
                        </button>
                      )}
                    </div>

                    {myForms.length === 0 ? (
                      <div className="p-8 text-center flex flex-col items-center justify-center space-y-3">
                        <FileText size={24} className="text-slate-300 dark:text-slate-600" />
                        <p className="text-xs font-semibold text-slate-600 dark:text-slate-400">Belum ada formulir</p>
                      </div>
                    ) : (
                      /* DATA DENGAN FADE IN */
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
                              className="p-3.5 sm:px-4 hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-all cursor-pointer flex items-center justify-between gap-3 group"
                            >
                              <div className="flex items-center gap-3 min-w-0">
                                <div className="w-8 h-8 rounded-lg bg-teal-50 dark:bg-teal-950/50 text-teal-600 dark:text-teal-400 flex items-center justify-center shrink-0 border border-teal-100/50 dark:border-teal-900/30">
                                  <FileText size={16} />
                                </div>
                                <div className="min-w-0">
                                  <h3 className="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">
                                    {form.title || 'Formulir Tanpa Judul'}
                                  </h3>
                                  <div className="flex items-center gap-2 mt-0.5">
                                    <span className={`text-[9px] font-bold px-1.5 py-0.2 rounded uppercase ${
                                      isPublished 
                                        ? 'bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400' 
                                        : 'bg-slate-100 dark:bg-slate-800 text-slate-400'
                                    }`}>
                                      {isPublished ? 'Aktif' : 'Draf'}
                                    </span>
                                    <span className="text-[10px] text-slate-400">
                                      {form.createdAt ? new Date(form.createdAt).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) : ''}
                                    </span>
                                  </div>
                                </div>
                              </div>

                              <div className="flex items-center gap-2 shrink-0" onClick={(e) => e.stopPropagation()}>
                                <button
                                  onClick={() => navigate(`/forms/${form.id}/responses`)}
                                  className="flex items-center gap-1 px-2 py-1 text-slate-500 hover:text-teal-600 dark:text-slate-400 dark:hover:text-teal-400 bg-slate-50 dark:bg-slate-800 hover:bg-teal-50 rounded-lg text-xs font-medium border border-slate-200/60 dark:border-slate-700/60 transition-colors cursor-pointer"
                                >
                                  <BarChart2 size={12} />
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
            <aside className="space-y-3">
              <AnimatePresence mode="wait">
                {loading ? (
                  <motion.div 
                    key="resp-skeleton"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 space-y-2"
                  >
                    {[1, 2, 3].map((i) => (
                      <div key={i} className="h-10 bg-slate-200 dark:bg-slate-800 rounded-xl w-full animate-pulse" />
                    ))}
                  </motion.div>
                ) : (
                  <motion.div 
                    key="resp-card"
                    variants={popUpVariants}
                    initial="hidden"
                    animate="visible"
                    className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-4 space-y-3 shadow-xs"
                  >
                    <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-2.5">
                      <div className="flex items-center gap-2">
                        <Users size={15} className="text-teal-600 dark:text-teal-400" />
                        <h2 className="text-xs font-bold text-slate-900 dark:text-white">Responden Terbaru</h2>
                      </div>
                      <span className="text-[9px] font-semibold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 px-1.5 py-0.5 rounded">
                        Realtime
                      </span>
                    </div>

                    {recentResponses && recentResponses.length > 0 ? (
                      /* LIST RESPONDEN DENGAN EMAIL DIBIARKAN TEPAT DI BAWAH NAMA (FADE-IN) */
                      <div className="space-y-1">
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
                              <div className="w-7 h-7 rounded-full bg-teal-100 dark:bg-teal-900/60 text-teal-700 dark:text-teal-300 font-bold text-[10px] flex items-center justify-center shrink-0 mt-0.5">
                                {respondentName.charAt(0).toUpperCase()}
                              </div>

                              <div className="min-w-0 flex-1">
                                <div className="flex items-center justify-between gap-2">
                                  <p className="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate">
                                    {respondentName}
                                  </p>

                                  <span className="text-[9px] text-slate-400 shrink-0">
                                    {formatRelativeTime(submittedAt)}
                                  </span>
                                </div>

                                <p className="text-[10px] text-slate-500 dark:text-slate-400 truncate mt-0.5">
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
                          size={22}
                          className="mx-auto text-slate-300 dark:text-slate-600 mb-2"
                        />
                        <p className="text-xs font-semibold text-slate-500 dark:text-slate-400">
                          Belum ada respons
                        </p>
                        <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-1">
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
