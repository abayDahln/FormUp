import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
    Plus, 
    FileText, 
    Users, 
    Star, 
    Clock, 
    LayoutDashboard, 
    Folder, 
    MessageSquare, 
    LayoutTemplate, 
    LogOut,
    Search,
    Bell,
    Settings,
    MoreVertical,
    Edit3,
    BarChart2
} from 'lucide-react';

const UserHome = () => {
    const navigate = useNavigate();

    const [user, setUser] = useState({});
    const [myForms, setMyForms] = useState([]);
    const [allResponses, setAllResponses] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // 1. Load User dari LocalStorage (jika disave saat login)
        const savedUser = JSON.parse(localStorage.getItem('user') || '{}');
        setUser(savedUser);

        // 2. Fetch Data API Backend C#
        const fetchDashboardData = async () => {
            const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;
            const token = localStorage.getItem('token');

            try {
                setLoading(true);
                const [formsRes, responsesRes] = await Promise.all([
                    fetch(`${API_BASE_URL}/api/Forms/my-forms`, {
                        headers: { Authorization: `Bearer ${token}` }
                    }),
                    fetch(`${API_BASE_URL}/api/Responses`, {
                        headers: { Authorization: `Bearer ${token}` }
                    })
                ]);

                const formsJson = await formsRes.json();
                const responsesJson = await responsesRes.json();

                // KARENA MENGGUNAKAN ApiResponse<T>, AMBIL DARIPROPERTY .data
                if (formsJson.data) setMyForms(formsJson.data);
                if (responsesJson.data) setAllResponses(responsesJson.data);

            } catch (err) {
                console.error("Error fetching dashboard data:", err);
            } finally {
                setLoading(false);
            }
        };

        fetchDashboardData();
    }, []);

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        navigate('/login');
    };

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            
            {/* SIDEBAR */}
            <aside className="w-64 bg-[#6DBFB3] text-white flex-col justify-between p-6 shadow-lg hidden md:flex shrink-0">
                <div className="space-y-8">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-white/20 rounded-xl">
                            <FileText size={24} className="text-white" />
                        </div>
                        <div>
                            <h1 className="text-xl font-bold tracking-tight leading-none">FormUp</h1>
                            <span className="text-[10px] text-teal-100 font-medium">Pro Workspace</span>
                        </div>
                    </div>

                    <nav className="space-y-1">
                        <a href="#dashboard" className="flex items-center gap-3 px-4 py-3 bg-white/20 font-semibold rounded-xl text-white transition-all">
                            <LayoutDashboard size={18} />
                            <span>Dashboard</span>
                        </a>
                        <a href="#my-forms" className="flex items-center gap-3 px-4 py-3 font-semibold rounded-xl text-teal-50 hover:bg-white/10 transition-all">
                            <Folder size={18} />
                            <span>My Forms</span>
                        </a>
                        <a href="#responses" className="flex items-center gap-3 px-4 py-3 font-semibold rounded-xl text-teal-50 hover:bg-white/10 transition-all">
                            <MessageSquare size={18} />
                            <span>Responses</span>
                        </a>
                        <a href="#templates" className="flex items-center gap-3 px-4 py-3 font-semibold rounded-xl text-teal-50 hover:bg-white/10 transition-all">
                            <LayoutTemplate size={18} />
                            <span>Templates</span>
                        </a>
                    </nav>
                </div>

                <button 
                    onClick={handleLogout}
                    className="flex items-center gap-3 px-4 py-3 font-semibold text-teal-100 hover:text-white hover:bg-white/10 rounded-xl transition-all"
                >
                    <LogOut size={18} />
                    <span>Logout</span>
                </button>
            </aside>

            {/* MAIN CONTENT AREA */}
            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">
                    
                    {/* TOPBAR HEADER WITH WHITE FRAME */}
                    <header className="bg-white p-4 rounded-2xl border border-slate-100 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                       <div className="relative w-full sm:flex-1">
                            <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
                            <input 
                                type="text" 
                                placeholder="Search forms, responses..." 
                                className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-full text-sm outline-none focus:ring-2 focus:ring-[#6DBFB3] transition-all"
                            />
                        </div>

                        <div className="flex items-center justify-between sm:justify-end gap-4 shrink-0">
                            <div className="flex items-center gap-2">
                                <button className="p-2 text-slate-500 hover:bg-slate-50 rounded-full transition-all">
                                    <Bell size={18} />
                                </button>
                                <button className="p-2 text-slate-500 hover:bg-slate-50 rounded-full transition-all">
                                    <Settings size={18} />
                                </button>
                            </div>

                            <div className="flex items-center gap-3 pl-3 border-l border-slate-200">
                                <div className="text-right hidden sm:block">
                                    <h4 className="text-xs font-bold text-slate-800">{user?.fullname || 'John Doe'}</h4>
                                    <p className="text-[10px] text-slate-400 font-semibold uppercase">PRO PLAN</p>
                                </div>
                                <img 
                                    src={user?.profileImage || "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100&auto=format&fit=crop&q=80"} 
                                    alt="Profile" 
                                    className="w-9 h-9 rounded-full object-cover border border-slate-300 shadow-sm"
                                />
                            </div>
                        </div>
                    </header>

                    {/* WELCOME */}
                    <div>
                        <h2 className="text-xl sm:text-2xl font-bold text-slate-800">
                            Good Morning, {user?.fullname ? user.fullname.split(' ')[0] : 'Alex'}
                        </h2>
                        <p className="text-xs text-slate-500 font-medium mt-1">
                            Here's how your forms are performing today.
                        </p>
                    </div>

                    {/* STAT CARDS */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                        {/* 1. TOTAL FORMS */}
                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Total Forms</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">{myForms.length}</h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-teal-50 text-[#00897B]">
                                <FileText size={20} />
                            </div>
                        </div>

                        {/* 2. TOTAL RESPONSES */}
                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Total Responses</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">
                                    {myForms.reduce((acc, form) => acc + (form.responses?.length || 0), 0)}
                                </h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-teal-50 text-[#00897B]">
                                <Users size={20} />
                            </div>
                        </div>

                        {/* 3. TOTAL PUBLISHED FORMS */}
                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Published Form</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">
                                    {myForms.filter(f => f.status?.name?.toUpperCase() === 'PUBLISHED' || f.statusId === 2).length}
                                </h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-emerald-50 text-emerald-600">
                                <Star size={20} />
                            </div>
                        </div>

                        {/* 4. TOTAL DRAFT FORMS */}
                        <div className="bg-white p-5 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div>
                                <p className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">Draft Form</p>
                                <h3 className="text-2xl font-extrabold text-slate-800">
                                    {myForms.filter(f => f.status?.name?.toUpperCase() === 'DRAFT' || f.statusId === 1).length}
                                </h3>
                            </div>
                            <div className="p-2.5 rounded-xl bg-amber-50 text-amber-600">
                                <Clock size={20} />
                            </div>
                        </div>
                    </div>

                    {/* RECENT FORMS */}
                    <section className="space-y-4">
                        <div className="flex items-center justify-between">
                            <div>
                                <h3 className="text-base font-bold text-slate-800">Recent Forms</h3>
                                <p className="text-xs text-slate-400 font-medium">Manage and track your active collections</p>
                            </div>
                            <button className="text-xs font-bold text-[#00897B] hover:underline">View all forms &gt;</button>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
                            {myForms.map((form) => {
                                // Penyesuaian nama property dari backend C#
                                const statusName = form.status?.name || (form.statusId === 2 ? 'PUBLISHED' : 'DRAFT');
                                const isPublished = statusName.toUpperCase() === 'PUBLISHED';
                                const responseCount = form.responses?.length || 0;

                                return (
                                    <div key={form.id} className="bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-all flex flex-col justify-between overflow-hidden">
                                        
                                        {/* Jika form punya Banner Image (Sesuai properti C#: BannerImage) */}
                                        {form.bannerImage && (
                                            <div className="h-28 w-full relative overflow-hidden bg-slate-100">
                                                <img 
                                                    src={form.bannerImage} 
                                                    alt={form.title} 
                                                    className="w-full h-full object-cover"
                                                />
                                                <button className="absolute top-3 right-3 p-1.5 bg-white/80 backdrop-blur-md text-slate-700 hover:bg-white rounded-full transition-all shadow-sm">
                                                    <MoreVertical size={14} />
                                                </button>
                                            </div>
                                        )}

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
                                                    <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-md uppercase tracking-wider ${
                                                        isPublished ? 'bg-teal-50 text-[#00897B]' : 'bg-slate-100 text-slate-500'
                                                    }`}>
                                                        {statusName}
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

                            {/* Tombol Create New Form */}
                            <div 
                                onClick={() => navigate('/create-form')}
                                className="bg-white p-5 rounded-2xl border-2 border-dashed border-slate-200 shadow-sm hover:border-[#6DBFB3] transition-all flex flex-col items-center justify-center text-center cursor-pointer h-full min-h-[200px] group"
                            >
                                <div className="w-10 h-10 rounded-full bg-teal-50 text-[#00897B] flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                                    <Plus size={20} />
                                </div>
                                <h4 className="text-xs font-bold text-slate-800">Create New Form</h4>
                                <p className="text-[11px] text-slate-400 font-medium mt-1 max-w-[160px]">
                                    Start from a template or build from scratch.
                                </p>
                            </div>
                        </div>
                    </section>

                    {/* RECENT RESPONSES */}
                    <section className="bg-white p-5 sm:p-6 rounded-2xl border border-slate-100 shadow-sm space-y-4">
                        <h3 className="text-sm font-bold text-slate-800">Recent Response Activity</h3>
                        <div className="space-y-3">
                            {allResponses.map((res, index) => (
                                <div key={res.id || index} className="flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 transition-colors">
                                    <div className="flex items-center gap-3">
                                        <div className="w-8 h-8 rounded-full bg-teal-50 text-[#00897B] flex items-center justify-center font-bold text-xs shrink-0">
                                            {res.userName ? res.userName.charAt(0) : 'U'}
                                        </div>
                                        <p className="text-xs font-semibold text-slate-700">
                                            <span className="font-bold text-slate-900">{res.userName || 'User'}</span> submitted '{res.formTitle || 'Form'}'
                                        </p>
                                    </div>
                                    <span className="text-[10px] text-slate-400 font-medium shrink-0">Baru saja</span>
                                </div>
                            ))}
                        </div>
                    </section>

                </main>
            </div>
        </div>
    );
};

export default UserHome;