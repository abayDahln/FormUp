import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Download, Filter, Clock, Calendar, Share2,
    Trash2, BarChart3, Plus, FileText
} from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import { getMyForms, clearSession, assetUrl } from '../../../services/apiService';

const ResponsesPage = () => {
    const navigate = useNavigate();
    const [forms, setForms] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchForms = async () => {
            try {
                setLoading(true);
                const result = await getMyForms();
                if (result.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }
                if (result.ok && Array.isArray(result.data)) {
                    setForms(result.data);
                }
            } catch (err) {
                console.error('Error fetching forms:', err);
            } finally {
                setLoading(false);
            }
        };
        fetchForms();
    }, [navigate]);

    const totalResponses = forms.reduce((acc, f) => acc + (f.responseCount ?? 0), 0);

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    };

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar />

                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div>
                            <h2 className="text-2xl font-bold text-slate-900 tracking-tight">Form Responses</h2>
                            <p className="text-sm text-slate-500 font-medium mt-1">
                                {totalResponses.toLocaleString()} total responses across {forms.length} forms.
                            </p>
                        </div>

                        <div className="flex items-center gap-3">
                            <button className="flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-50 transition-all shadow-sm">
                                <Filter size={16} /> Filters
                            </button>
                        </div>
                    </div>

                    {loading ? (
                        <div className="py-16 text-center text-slate-400 text-sm font-medium">
                            Loading responses...
                        </div>
                    ) : forms.length === 0 ? (
                        <div className="bg-teal-50/30 rounded-2xl border-2 border-dashed border-teal-100 p-12 flex flex-col items-center justify-center text-center space-y-4">
                            <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-sm text-teal-600">
                                <FileText size={24} />
                            </div>
                            <div className="space-y-1">
                                <h4 className="text-sm font-bold text-slate-800">No forms yet</h4>
                                <p className="text-xs text-slate-500 font-medium">Create a form and start collecting responses.</p>
                            </div>
                            <button
                                onClick={() => navigate('/create-form')}
                                className="text-xs font-bold text-teal-600 hover:underline flex items-center gap-1"
                            >
                                Create New Form &rarr;
                            </button>
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                            {forms.map((form) => {
                                const isPublished = form.status?.toLowerCase() === 'published';
                                const responseCount = form.responseCount ?? 0;

                                return (
                                    <div key={form.id} className="bg-white rounded-2xl border border-slate-100 shadow-sm p-6 flex flex-col space-y-5">
                                        <div className="flex items-center justify-between">
                                            <div className={`p-2.5 rounded-xl ${isPublished ? 'bg-teal-50 text-teal-600' : 'bg-slate-50 text-slate-400'}`}>
                                                <BarChart3 size={20} />
                                            </div>
                                            <span className={`text-[10px] font-extrabold px-3 py-1 rounded-full uppercase tracking-widest ${
                                                isPublished ? 'bg-teal-50 text-teal-600' : 'bg-slate-100 text-slate-500'
                                            }`}>
                                                ● {form.status ?? 'draft'}
                                            </span>
                                        </div>

                                        <div>
                                            <h3 className="text-lg font-bold text-slate-900 line-clamp-1">{form.title}</h3>
                                            {form.description && (
                                                <p className="text-sm text-slate-400 font-medium mt-1 line-clamp-1">{form.description}</p>
                                            )}
                                        </div>

                                        <div className="grid grid-cols-2 gap-4">
                                            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100/50">
                                                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Total Responses</p>
                                                <h4 className="text-2xl font-extrabold text-teal-600">{responseCount.toLocaleString()}</h4>
                                            </div>
                                            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100/50">
                                                <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Created</p>
                                                <h4 className="text-base font-extrabold text-slate-800">{formatDate(form.createdAt)}</h4>
                                            </div>
                                        </div>

                                        <div className="flex items-center gap-3 text-[11px] font-bold text-slate-400">
                                            <span className="flex items-center gap-1.5">
                                                <Calendar size={14} /> Updated {formatDate(form.updatedAt)}
                                            </span>
                                        </div>

                                        <div className="flex items-center gap-2 pt-1">
                                            <button
                                                onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                className="flex-1 py-2.5 px-4 bg-[#005B52] hover:bg-[#00463F] text-white font-bold text-xs rounded-xl transition-all shadow-sm"
                                            >
                                                View Responses
                                            </button>
                                            <a
                                                href={`${import.meta.env.VITE_API_BASE_URL}/api/forms/${form.id}/responses/export`}
                                                target="_blank"
                                                rel="noreferrer"
                                                className="p-2.5 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-50 transition-all"
                                                title="Export CSV"
                                            >
                                                <Download size={16} />
                                            </a>
                                            <button
                                                onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                className="p-2.5 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-50 transition-all"
                                                title="Share form link"
                                            >
                                                <Share2 size={16} />
                                            </button>
                                        </div>
                                    </div>
                                );
                            })}

                            <div className="bg-teal-50/30 rounded-2xl border-2 border-dashed border-teal-100 p-8 flex flex-col items-center justify-center text-center space-y-4">
                                <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-sm text-teal-600">
                                    <Plus size={24} />
                                </div>
                                <div className="space-y-1">
                                    <h4 className="text-sm font-bold text-slate-800">Ready to start collecting?</h4>
                                    <p className="text-xs text-slate-500 font-medium">Launch a new form to start seeing analytics here.</p>
                                </div>
                                <button
                                    onClick={() => navigate('/create-form')}
                                    className="text-xs font-bold text-teal-600 hover:underline flex items-center gap-1"
                                >
                                    Create New Form &rarr;
                                </button>
                            </div>
                        </div>
                    )}

                </main>
            </div>
        </div>
    );
};

export default ResponsesPage;