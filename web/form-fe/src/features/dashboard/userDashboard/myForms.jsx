import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import {
    Plus,
    MoreVertical,
    MessageSquare,
    Calendar,
    Edit3,
    Eye,
    Play,
    CheckCircle2
} from 'lucide-react';

const MyForms = () => {
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('All');
    const [myForms, setMyForms] = useState([]);
    const [loading, setLoading] = useState(true);

    // Fetch Data dari API C#
    useEffect(() => {
        const fetchMyForms = async () => {
            const API_BASE_URL = import.meta.env.VITE_API_BASE_URL;
            const token = localStorage.getItem('token');

            try {
                setLoading(true);
                const res = await fetch(`${API_BASE_URL}/api/Forms/my-forms`, {
                    headers: { 
                        'Authorization': `Bearer ${token}`,
                        'Content-Type': 'application/json'
                    }
                });

                const result = await res.json();
                
                if (result.data) {
                    setMyForms(result.data);
                }
            } catch (err) {
                console.error("Error fetching my forms:", err);
            } finally {
                setLoading(false);
            }
        };

        fetchMyForms();
    }, []);

    // Perhitungan Statistik Otomatis
    const publishedForms = myForms.filter(f => (f.status?.name?.toUpperCase() === 'PUBLISHED' || f.statusId === 2));
    const draftForms = myForms.filter(f => (f.status?.name?.toUpperCase() === 'DRAFT' || f.statusId === 1));
    const totalSubmissions = myForms.reduce((acc, form) => acc + (form.responses?.length || 0), 0);

    // Filter list form berdasarkan tab yang aktif
    const filteredForms = myForms.filter((form) => {
        const statusName = (form.status?.name || (form.statusId === 2 ? 'PUBLISHED' : 'DRAFT')).toUpperCase();
        if (activeTab === 'Published') return statusName === 'PUBLISHED';
        if (activeTab === 'Draft') return statusName === 'DRAFT';
        return true; // 'All'
    });

    const tabs = [
        { id: 'All', label: `All (${myForms.length})` },
        { id: 'Published', label: `Published (${publishedForms.length})` },
        { id: 'Draft', label: `Draft (${draftForms.length})` },
    ];

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800 overflow-hidden">
            {/* Sidebar tetap di kiri */}
            <Sidebar />

            {/* Container Konten Utama */}
            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">

                {/* Main memiliki padding sehingga Topbar & Konten ikut mengambang */}
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    {/* Topbar sekarang ada di dalam main, jadi otomatis mengambang / punya jarak */}
                    <Topbar />

                    {/* Bagian Header & Tabs */}
                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 md:gap-0 pt-2">
                        <div>
                            <h1 className="text-[28px] font-bold text-slate-900 tracking-tight">My Forms</h1>
                            <p className="text-sm text-slate-500 font-medium mt-0.5">
                                Manage and track your active collection of forms.
                            </p>
                        </div>

                        {/* Custom Tabs */}
                        <div className="flex items-center bg-gray-100/80 p-1.5 rounded-full border border-gray-200">
                            {tabs.map((tab) => (
                                <button
                                    key={tab.id}
                                    onClick={() => setActiveTab(tab.id)}
                                    className={`px-6 py-2.5 rounded-full text-[14px] font-bold transition-all duration-200 ${activeTab === tab.id
                                            ? 'bg-white text-gray-900 shadow-sm border border-gray-200/50'
                                            : 'text-gray-500 hover:text-gray-700'
                                        }`}
                                >
                                    {tab.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Bagian Statistik */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        {/* Total Submissions Card */}
                        <div className="bg-[#126f63] rounded-2xl p-6 text-white shadow-sm relative overflow-hidden md:col-span-2 lg:col-span-1 xl:col-span-1">
                            <div className="relative z-10">
                                <p className="text-white/80 font-bold text-[11px] uppercase tracking-wider mb-1">Total Submissions</p>
                                <h2 className="text-3xl font-extrabold tracking-tight">{totalSubmissions.toLocaleString()}</h2>
                            </div>
                            <div className="absolute -right-6 -bottom-6 w-32 h-32 bg-white/10 rounded-full blur-2xl"></div>
                        </div>

                        {/* Active Forms Card */}
                        <div className="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm md:col-span-2 lg:col-span-1 xl:col-span-1">
                            <p className="text-slate-400 font-bold text-[11px] uppercase tracking-wider mb-1">Active Forms</p>
                            <h2 className="text-3xl font-extrabold text-slate-800 tracking-tight">{publishedForms.length}</h2>
                            <p className="text-[#00897B] flex items-center text-xs font-bold mt-2">
                                <CheckCircle2 className="w-3.5 h-3.5 mr-1" /> All systems online
                            </p>
                        </div>
                    </div>

                    {/* Rendering Konten Berdasarkan Tab yang Aktif */}
                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">

                        {/* Card Create New Form (Selalu muncul) */}
                        <div 
                            onClick={() => navigate('/create-form')}
                            className="bg-white border-2 border-dashed border-slate-200 rounded-2xl min-h-[280px] flex flex-col items-center justify-center cursor-pointer hover:border-[#6DBFB3] transition-colors group shadow-sm"
                        >
                            <div className="w-12 h-12 bg-teal-50 rounded-full flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                                <Plus className="w-6 h-6 text-[#00897B]" />
                            </div>
                            <h3 className="text-slate-800 font-bold text-sm mb-1">New Form</h3>
                            <p className="text-slate-400 text-[11px] font-medium text-center px-6">
                                Start from scratch or use a<br />template
                            </p>
                        </div>

                        {/* Item Cards Form dari API */}
                        {loading ? (
                            <div className="col-span-full py-12 text-center text-slate-400 text-sm font-medium">
                                Loading forms...
                            </div>
                        ) : filteredForms.length === 0 ? (
                            <div className="col-span-full py-12 text-center text-slate-400 text-sm font-medium">
                                No {activeTab.toLowerCase()} forms found.
                            </div>
                        ) : (
                            filteredForms.map((form) => {
                                const statusName = form.status?.name || (form.statusId === 2 ? 'PUBLISHED' : 'DRAFT');
                                const isPublished = statusName.toUpperCase() === 'PUBLISHED';
                                const responseCount = form.responses?.length || 0;
                                const createdDate = form.createdAt 
                                    ? new Date(form.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) 
                                    : 'Recent';

                                return (
                                    <div key={form.id} className="bg-white border border-slate-100 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow flex flex-col">
                                        <div className="h-32 bg-gradient-to-br from-teal-50 to-blue-50 relative p-4 flex items-start justify-end border-b border-slate-100 overflow-hidden">
                                            {form.bannerImage ? (
                                                <img src={form.bannerImage} alt={form.title} className="absolute inset-0 w-full h-full object-cover" />
                                            ) : (
                                                <div className="absolute inset-x-6 top-6 bottom-0 bg-white shadow-sm rounded-t-xl border border-slate-200 border-b-0 opacity-80 flex flex-col gap-2 p-3">
                                                    <div className="w-1/2 h-2 bg-slate-200 rounded-full"></div>
                                                    <div className="w-full h-2 bg-slate-100 rounded-full"></div>
                                                    <div className="w-3/4 h-2 bg-slate-100 rounded-full"></div>
                                                </div>
                                            )}
                                            <span className={`relative z-10 px-2.5 py-1 rounded-md text-[10px] font-extrabold uppercase tracking-wider flex items-center shadow-sm ${
                                                isPublished 
                                                    ? 'bg-teal-50 text-[#00897B]' 
                                                    : 'bg-slate-100 text-slate-500'
                                            }`}>
                                                {statusName}
                                            </span>
                                        </div>
                                        <div className="p-4 flex flex-col flex-1">
                                            <div className="flex justify-between items-start mb-3">
                                                <h3 className="text-sm font-bold text-slate-800 leading-tight line-clamp-1">{form.title}</h3>
                                                <button className="text-slate-400 hover:text-slate-600">
                                                    <MoreVertical className="w-4 h-4" />
                                                </button>
                                            </div>
                                            <div className="flex items-center gap-3 mb-5 text-xs font-medium text-slate-500">
                                                <span className="flex items-center gap-1">
                                                    <MessageSquare className="w-3.5 h-3.5" /> {responseCount} Responses
                                                </span>
                                                <span className="flex items-center gap-1">
                                                    <Calendar className="w-3.5 h-3.5" /> {createdDate}
                                                </span>
                                            </div>
                                            <div className="mt-auto flex gap-2">
                                                {!isPublished ? (
                                                    <button 
                                                        onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                        className="flex-1 bg-[#126f63] hover:bg-[#0e5c52] text-white font-semibold py-1.5 rounded-lg flex items-center justify-center gap-1.5 text-xs transition-colors"
                                                    >
                                                        <Play className="w-3.5 h-3.5 fill-current" /> Publish
                                                    </button>
                                                ) : null}
                                                <button 
                                                    onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                    className="flex-1 bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 font-semibold py-1.5 rounded-lg flex items-center justify-center gap-1.5 text-xs transition-colors"
                                                >
                                                    <Edit3 className="w-3.5 h-3.5" /> Edit
                                                </button>
                                                <button 
                                                    onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                    className="flex-1 bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 font-semibold py-1.5 rounded-lg flex items-center justify-center gap-1.5 text-xs transition-colors"
                                                >
                                                    <Eye className="w-3.5 h-3.5" /> View
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}

                    </div>

                </main>
            </div>
        </div>
    );
};

export default MyForms;