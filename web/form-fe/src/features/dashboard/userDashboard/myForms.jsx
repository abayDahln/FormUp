import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import {
    Plus, MoreVertical, MessageSquare, Calendar,
    Edit3, Eye, Trash2, Globe, Lock, CheckCircle2
} from 'lucide-react';
import { getMyForms, deleteForm, togglePublishForm, clearSession, assetUrl } from '../../../services/apiService';

const MyForms = () => {
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('All');
    const [myForms, setMyForms] = useState([]);
    const [loading, setLoading] = useState(true);
    const [openMenuId, setOpenMenuId] = useState(null);
    const [actionLoading, setActionLoading] = useState(null);
    const menuRef = useRef(null);

    useEffect(() => {
        const fetchMyForms = async () => {
            try {
                setLoading(true);
                const result = await getMyForms();

                if (result.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (result.ok && Array.isArray(result.data)) {
                    setMyForms(result.data);
                }
            } catch (err) {
                console.error('Error fetching forms:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchMyForms();
    }, [navigate]);

    useEffect(() => {
        const handleClickOutside = (e) => {
            if (menuRef.current && !menuRef.current.contains(e.target)) {
                setOpenMenuId(null);
            }
        };
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    const handleTogglePublish = async (formId) => {
        setActionLoading(formId);
        setOpenMenuId(null);
        try {
            const result = await togglePublishForm(formId);
            if (result.ok) {
                const updated = await getMyForms();
                if (updated.ok && Array.isArray(updated.data)) {
                    setMyForms(updated.data);
                }
            }
        } catch (err) {
            console.error('Toggle publish error:', err);
        } finally {
            setActionLoading(null);
        }
    };

    const handleDelete = async (formId) => {
        if (!window.confirm('Delete this form? This action cannot be undone.')) return;
        setActionLoading(formId);
        setOpenMenuId(null);
        try {
            const result = await deleteForm(formId);
            if (result.ok) {
                setMyForms(prev => prev.filter(f => f.id !== formId));
            }
        } catch (err) {
            console.error('Delete form error:', err);
        } finally {
            setActionLoading(null);
        }
    };

    const publishedForms = myForms.filter(f => f.status?.toLowerCase() === 'published');
    const draftForms = myForms.filter(f => f.status?.toLowerCase() === 'draft');
    const totalResponses = myForms.reduce((acc, f) => acc + (f.responseCount ?? 0), 0);

    const filteredForms = myForms.filter((form) => {
        const s = form.status?.toLowerCase() ?? 'draft';
        if (activeTab === 'Published') return s === 'published';
        if (activeTab === 'Draft') return s === 'draft';
        return true;
    });

    const tabs = [
        { id: 'All', label: `All (${myForms.length})` },
        { id: 'Published', label: `Published (${publishedForms.length})` },
        { id: 'Draft', label: `Draft (${draftForms.length})` },
    ];

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800 overflow-hidden">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar />

                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 pt-2">
                        <div>
                            <h1 className="text-[28px] font-bold text-slate-900 tracking-tight">My Forms</h1>
                            <p className="text-sm text-slate-500 font-medium mt-0.5">
                                Manage and track your active collection of forms.
                            </p>
                        </div>

                        <div className="flex items-center bg-gray-100/80 p-1.5 rounded-full border border-gray-200">
                            {tabs.map((tab) => (
                                <button
                                    key={tab.id}
                                    onClick={() => setActiveTab(tab.id)}
                                    className={`px-6 py-2.5 rounded-full text-[14px] font-bold transition-all duration-200 ${
                                        activeTab === tab.id
                                            ? 'bg-white text-gray-900 shadow-sm border border-gray-200/50'
                                            : 'text-gray-500 hover:text-gray-700'
                                    }`}
                                >
                                    {tab.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        <div className="bg-[#126f63] rounded-2xl p-6 text-white shadow-sm relative overflow-hidden md:col-span-2 lg:col-span-1">
                            <div className="relative z-10">
                                <p className="text-white/80 font-bold text-[11px] uppercase tracking-wider mb-1">Total Responses</p>
                                <h2 className="text-3xl font-extrabold tracking-tight">{totalResponses.toLocaleString()}</h2>
                            </div>
                            <div className="absolute -right-6 -bottom-6 w-32 h-32 bg-white/10 rounded-full blur-2xl" />
                        </div>

                        <div className="bg-white border border-slate-100 rounded-2xl p-6 shadow-sm md:col-span-2 lg:col-span-1">
                            <p className="text-slate-400 font-bold text-[11px] uppercase tracking-wider mb-1">Active Forms</p>
                            <h2 className="text-3xl font-extrabold text-slate-800 tracking-tight">{publishedForms.length}</h2>
                            <p className="text-[#00897B] flex items-center text-xs font-bold mt-2">
                                <CheckCircle2 className="w-3.5 h-3.5 mr-1" /> Live & accepting responses
                            </p>
                        </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4" ref={menuRef}>
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
                                const status = typeof form.status === 'string' ? form.status : 'draft';
                                const isPublished = status.toLowerCase() === 'published';
                                const responseCount = form.responseCount ?? 0;
                                const isActing = actionLoading === form.id;
                                const createdDate = form.createdAt
                                    ? new Date(form.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
                                    : 'Recent';

                                return (
                                    <div
                                        key={form.id}
                                        className={`bg-white border border-slate-100 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-shadow flex flex-col ${isActing ? 'opacity-60 pointer-events-none' : ''}`}
                                    >
                                        <div className="h-32 bg-gradient-to-br from-teal-50 to-blue-50 relative p-4 flex items-start justify-end border-b border-slate-100 overflow-hidden">
                                            {form.bannerImage ? (
                                                <img src={assetUrl(form.bannerImage)} alt={form.title} className="absolute inset-0 w-full h-full object-cover" />
                                            ) : (
                                                <div className="absolute inset-x-6 top-6 bottom-0 bg-white shadow-sm rounded-t-xl border border-slate-200 border-b-0 opacity-80 flex flex-col gap-2 p-3">
                                                    <div className="w-1/2 h-2 bg-slate-200 rounded-full" />
                                                    <div className="w-full h-2 bg-slate-100 rounded-full" />
                                                    <div className="w-3/4 h-2 bg-slate-100 rounded-full" />
                                                </div>
                                            )}
                                            <span className={`relative z-10 px-2.5 py-1 rounded-md text-[10px] font-extrabold uppercase tracking-wider shadow-sm ${
                                                isPublished ? 'bg-teal-50 text-[#00897B]' : 'bg-slate-100 text-slate-500'
                                            }`}>
                                                {status}
                                            </span>

                                            <div className="relative z-10 ml-2">
                                                <button
                                                    onClick={() => setOpenMenuId(openMenuId === form.id ? null : form.id)}
                                                    className="p-1.5 bg-white/80 backdrop-blur-sm rounded-full text-slate-600 hover:bg-white shadow-sm transition-all"
                                                >
                                                    <MoreVertical className="w-4 h-4" />
                                                </button>

                                                {openMenuId === form.id && (
                                                    <div className="absolute right-0 top-8 w-44 bg-white rounded-xl shadow-lg border border-slate-100 z-50 py-1 overflow-hidden">
                                                        <button
                                                            onClick={() => handleTogglePublish(form.id)}
                                                            className="w-full flex items-center gap-2.5 px-3 py-2.5 text-xs font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
                                                        >
                                                            {isPublished ? <Lock className="w-3.5 h-3.5 text-amber-500" /> : <Globe className="w-3.5 h-3.5 text-teal-500" />}
                                                            {isPublished ? 'Unpublish' : 'Publish'}
                                                        </button>
                                                        <button
                                                            onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                            className="w-full flex items-center gap-2.5 px-3 py-2.5 text-xs font-semibold text-slate-700 hover:bg-slate-50 transition-colors"
                                                        >
                                                            <Edit3 className="w-3.5 h-3.5 text-blue-500" /> Edit Form
                                                        </button>
                                                        <div className="border-t border-slate-100 my-1" />
                                                        <button
                                                            onClick={() => handleDelete(form.id)}
                                                            className="w-full flex items-center gap-2.5 px-3 py-2.5 text-xs font-semibold text-red-600 hover:bg-red-50 transition-colors"
                                                        >
                                                            <Trash2 className="w-3.5 h-3.5" /> Delete
                                                        </button>
                                                    </div>
                                                )}
                                            </div>
                                        </div>

                                        <div className="p-4 flex flex-col flex-1">
                                            <div className="flex justify-between items-start mb-3">
                                                <h3 className="text-sm font-bold text-slate-800 leading-tight line-clamp-1">{form.title}</h3>
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
                                                    <Eye className="w-3.5 h-3.5" /> Responses
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