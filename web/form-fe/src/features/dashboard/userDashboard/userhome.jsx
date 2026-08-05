import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, FileText, Users, Star, Clock, MoreVertical, Edit3, BarChart2 } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import { getMyForms, getLocalUser, clearSession, assetUrl } from '../../../services/apiService';

const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
};

const UserHome = () => {
    const navigate = useNavigate();
    const [myForms, setMyForms] = useState([]);
    const [loading, setLoading] = useState(true);
    const [user] = useState(() => getLocalUser());

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

    const totalResponses = myForms.reduce((acc, f) => acc + (f.responseCount ?? 0), 0);
    const publishedCount = myForms.filter(f => f.status?.toLowerCase() === 'published').length;
    const draftCount = myForms.filter(f => f.status?.toLowerCase() === 'draft').length;
    const recentForms = [...myForms]
        .sort((a, b) => new Date(b.updatedAt ?? b.createdAt) - new Date(a.updatedAt ?? a.createdAt))
        .slice(0, 8);

    // =====================================
    // SKELETON LOADING STATE
    // =====================================
    if (loading) {
        return (
            <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
                {/* Sidebar tetap dirender agar tidak lompat */}
                <Sidebar />

                <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                    <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">
                        
                        {/* Topbar tetap dirender */}
                        <Topbar />

                        {/* Skeleton Greeting */}
                        <div className="animate-pulse">
                            <div className="h-8 bg-slate-200 rounded-md w-48 sm:w-64 mb-2"></div>
                            <div className="h-3 bg-slate-200 rounded-md w-56 mt-2"></div>
                        </div>

                        {/* Skeleton Stats Grid */}
                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                            {[1, 2, 3, 4].map((i) => (
                                <div key={i} className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between animate-pulse">
                                    <div className="w-full">
                                        <div className="h-3 bg-slate-200 rounded-md w-20 mb-3"></div>
                                        <div className="h-7 bg-slate-200 rounded-md w-12"></div>
                                    </div>
                                    <div className="w-10 h-10 rounded-xl bg-slate-200 shrink-0"></div>
                                </div>
                            ))}
                        </div>

                        {/* Skeleton Recent Forms */}
                        <section className="space-y-4">
                            <div className="flex items-center justify-between animate-pulse">
                                <div>
                                    <div className="h-5 bg-slate-200 rounded-md w-28 mb-1.5"></div>
                                    <div className="h-3 bg-slate-200 rounded-md w-40"></div>
                                </div>
                                <div className="h-3 bg-slate-200 rounded-md w-16"></div>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                                {[1, 2, 3, 4].map((i) => (
                                    <div key={i} className="bg-white rounded-2xl border border-slate-100 shadow-sm flex flex-col justify-between overflow-hidden animate-pulse">
                                        {/* Skeleton Image Banner */}
                                        <div className="h-28 w-full bg-slate-200"></div>

                                        <div className="p-4 flex-1 flex flex-col justify-between">
                                            <div>
                                                {/* Skeleton Title */}
                                                <div className="h-4 bg-slate-200 rounded-md w-3/4 mb-4"></div>
                                                
                                                {/* Skeleton Badges / Responses */}
                                                <div className="flex items-center justify-between mt-2">
                                                    <div className="h-4 bg-slate-200 rounded-md w-16"></div>
                                                    <div className="h-3 bg-slate-200 rounded-md w-20"></div>
                                                </div>
                                            </div>

                                            {/* Skeleton Buttons */}
                                            <div className="flex items-center gap-2 pt-4 mt-4 border-t border-slate-100">
                                                <div className="flex-1 h-8 bg-slate-200 rounded-lg"></div>
                                                <div className="flex-1 h-8 bg-slate-200 rounded-lg"></div>
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

    // =====================================
    // MAIN CONTENT (DATA LOADED)
    // =====================================
    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar />

                    <div>
                        <h2 className="text-xl sm:text-2xl font-bold text-slate-800">
                            {getGreeting()}, {user?.fullname ? user.fullname.split(' ')[0] : 'there'} 👋
                        </h2>
                        <p className="text-xs text-slate-500 font-medium mt-1">
                            Here's how your forms are performing today.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Total Forms</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">{myForms.length}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-teal-50 text-[#00897B]">
                                <FileText size={20} />
                            </div>
                        </div>

                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Total Responses</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">{totalResponses}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-teal-50 text-[#00897B]">
                                <Users size={20} />
                            </div>
                        </div>

                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Published</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">{publishedCount}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-emerald-50 text-emerald-600">
                                <Star size={20} />
                            </div>
                        </div>

                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Draft</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">{draftCount}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-amber-50 text-amber-600">
                                <Clock size={20} />
                            </div>
                        </div>
                    </div>

                    <section className="space-y-4">
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="text-base font-bold text-slate-800">Recent Forms</h3>
                                <p className="text-xs text-slate-400 font-medium">Your most recently updated forms</p>
                            </div>
                            <button
                                onClick={() => navigate('/my-forms')}
                                className="text-xs font-bold text-[#00897B] hover:underline"
                            >
                                View all &rarr;
                            </button>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                            {recentForms.map((form) => {
                                const status = typeof form.status === 'string' ? form.status : 'draft';
                                const isPublished = status.toLowerCase() === 'published';
                                const responseCount = form.responseCount ?? 0;

                                return (
                                    <div key={form.id} className="bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-all flex flex-col justify-between overflow-hidden">
                                        {form.bannerImage ? (
                                            <div className="h-28 w-full relative overflow-hidden bg-slate-100">
                                                <img
                                                    src={assetUrl(form.bannerImage)}
                                                    alt={form.title}
                                                    className="w-full h-full object-cover"
                                                />
                                                <button className="absolute top-3 right-3 p-1.5 bg-white/80 backdrop-blur-md text-slate-700 hover:bg-white rounded-full transition-all shadow-sm">
                                                    <MoreVertical size={14} />
                                                </button>
                                            </div>
                                        ) : null}

                                        <div className="p-4 flex-1 flex flex-col justify-between">
                                            <div>
                                                {!form.bannerImage && (
                                                    <div className="flex items-start justify-between mb-3">
                                                        <div className="p-2 bg-teal-50 text-[#00897B] rounded-lg">
                                                            <FileText size={18} />
                                                        </div>
                                                        <button className="text-slate-400 hover:text-slate-600">
                                                            <MoreVertical size={16} />
                                                        </button>
                                                    </div>
                                                )}
                                                <h4 className="text-sm font-bold text-slate-800 line-clamp-1">{form.title}</h4>
                                                <div className="flex items-center justify-between mt-2">
                                                    <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-md uppercase tracking-wider ${isPublished ? 'bg-teal-50 text-[#00897B]' : 'bg-slate-100 text-slate-500'}`}>
                                                        {status}
                                                    </span>
                                                    <p className="text-xs text-slate-400 font-medium">
                                                        {responseCount} responses
                                                    </p>
                                                </div>
                                            </div>

                                            <div className="flex items-center gap-2 pt-4 mt-3 border-t border-slate-100">
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                    className="flex-1 py-1.5 px-2 bg-slate-50 hover:bg-slate-100 text-slate-700 font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-1 border border-slate-200"
                                                >
                                                    <Edit3 size={12} /> Edit
                                                </button>
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                    className="flex-1 py-1.5 px-2 bg-slate-50 hover:bg-slate-100 text-slate-700 font-semibold text-xs rounded-lg transition-all flex items-center justify-center gap-1 border border-slate-200"
                                                >
                                                    <BarChart2 size={12} /> Analytics
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}

                            <div
                                onClick={() => navigate('/my-forms')}
                                className="bg-white p-5 rounded-2xl border-2 border-dashed border-slate-200 shadow-sm hover:border-[#6DBFB3] transition-all flex flex-col items-center justify-center text-center cursor-pointer min-h-[180px] group"
                            >
                                <div className="w-10 h-10 rounded-full bg-teal-50 text-[#00897B] flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                                    <Plus size={20} />
                                </div>
                                <h4 className="text-xs font-bold text-slate-800">Create New Form</h4>
                                <p className="text-[11px] text-slate-400 font-medium mt-1 max-w-[140px]">
                                    Start from a template or build from scratch.
                                </p>
                            </div>
                        </div>
                    </section>

                </main>
            </div>
        </div>
    );
};

export default UserHome;