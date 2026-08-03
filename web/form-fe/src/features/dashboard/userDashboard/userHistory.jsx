import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { FileText, Award, Eye, Edit3, BarChart2 } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import { getMyForms, getMySubmittedResponses, clearSession } from '../../../services/apiService';

export default function History() {
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('submitted');
    const [submittedForms, setSubmittedForms] = useState([]);
    const [createdForms, setCreatedForms] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchHistory = async () => {
            try {
                setLoading(true);
                const [submittedResult, createdResult] = await Promise.all([
                    getMySubmittedResponses(),
                    getMyForms(),
                ]);

                if (submittedResult.status === 401 || createdResult.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (submittedResult.ok && Array.isArray(submittedResult.data)) {
                    setSubmittedForms(submittedResult.data);
                }
                if (createdResult.ok && Array.isArray(createdResult.data)) {
                    setCreatedForms(createdResult.data);
                }
            } catch (err) {
                console.error('History fetch error:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchHistory();
    }, [navigate]);

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    };

    const getStatusStyle = (status) => {
        const s = status?.toLowerCase() ?? '';
        if (s === 'submitted' || s === 'reviewed' || s === 'new') return 'bg-emerald-50 text-emerald-600';
        if (s === 'published') return 'bg-teal-50 text-[#6DBFB3]';
        if (s === 'draft') return 'bg-slate-100 text-slate-500';
        return 'bg-amber-50 text-amber-600';
    };

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 min-h-screen overflow-y-auto">
                <div className="p-8 space-y-8 w-full flex-1">

                    <Topbar />

                    <div>
                        <h1 className="text-2xl font-bold text-slate-800">History & Activity</h1>
                        <p className="text-sm text-slate-500 mt-1">
                            Track your submissions and manage your form life cycles.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full">
                        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div className="space-y-2">
                                <div className="p-2.5 bg-teal-50 w-fit rounded-xl text-[#6DBFB3]">
                                    <FileText size={22} />
                                </div>
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Forms Submitted</p>
                                <h3 className="text-3xl font-extrabold text-slate-800">{submittedForms.length}</h3>
                            </div>
                        </div>

                        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div className="space-y-2">
                                <div className="p-2.5 bg-indigo-50 w-fit rounded-xl text-indigo-500">
                                    <Award size={22} />
                                </div>
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">Forms Created</p>
                                <h3 className="text-3xl font-extrabold text-slate-800">{createdForms.length}</h3>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden w-full">

                        <div className="flex border-b border-slate-100 px-6 pt-4 gap-8">
                            <button
                                onClick={() => setActiveTab('submitted')}
                                className={`pb-4 text-sm font-bold border-b-2 transition-all ${
                                    activeTab === 'submitted'
                                        ? 'border-[#6DBFB3] text-[#6DBFB3]'
                                        : 'border-transparent text-slate-400 hover:text-slate-600'
                                }`}
                            >
                                Submitted Forms
                            </button>
                            <button
                                onClick={() => setActiveTab('created')}
                                className={`pb-4 text-sm font-bold border-b-2 transition-all ${
                                    activeTab === 'created'
                                        ? 'border-[#6DBFB3] text-[#6DBFB3]'
                                        : 'border-transparent text-slate-400 hover:text-slate-600'
                                }`}
                            >
                                Created Forms
                            </button>
                        </div>

                        {loading ? (
                            <div className="py-12 text-center text-slate-400 text-sm">Loading...</div>
                        ) : activeTab === 'submitted' ? (
                            submittedForms.length === 0 ? (
                                <div className="py-12 text-center text-slate-400 text-sm">You have not submitted any forms yet.</div>
                            ) : (
                                <div className="overflow-x-auto w-full">
                                    <table className="w-full text-left border-collapse">
                                        <thead>
                                            <tr className="bg-slate-50/50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                                <th className="py-4 px-6">Form Title</th>
                                                <th className="py-4 px-6">Submitted At</th>
                                                <th className="py-4 px-6">Status</th>
                                                <th className="py-4 px-6 text-right">Action</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100 text-sm">
                                            {submittedForms.map((item) => (
                                                <tr key={item.responseId} className="hover:bg-slate-50/60 transition-colors">
                                                    <td className="py-4 px-6">
                                                        <div className="flex items-center gap-3">
                                                            <div className="p-2 bg-slate-100 rounded-lg text-slate-500">
                                                                <FileText size={18} />
                                                            </div>
                                                            <span className="font-semibold text-slate-800">{item.formTitle || '—'}</span>
                                                        </div>
                                                    </td>
                                                    <td className="py-4 px-6 text-slate-500 font-medium">
                                                        {formatDate(item.submittedAt)}
                                                    </td>
                                                    <td className="py-4 px-6">
                                                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${getStatusStyle(item.status)}`}>
                                                            {item.status}
                                                        </span>
                                                    </td>
                                                    <td className="py-4 px-6 text-right">
                                                        <button
                                                            onClick={() => navigate(`/forms/${item.formId}/f`)}
                                                            className="inline-flex items-center gap-1.5 text-xs font-bold text-[#6DBFB3] hover:underline"
                                                        >
                                                            <Eye size={14} /> View
                                                        </button>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )
                        ) : (
                            createdForms.length === 0 ? (
                                <div className="py-12 text-center text-slate-400 text-sm">No forms created yet.</div>
                            ) : (
                                <div className="overflow-x-auto w-full">
                                    <table className="w-full text-left border-collapse">
                                        <thead>
                                            <tr className="bg-slate-50/50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                                <th className="py-4 px-6">Form Title</th>
                                                <th className="py-4 px-6">Status</th>
                                                <th className="py-4 px-6">Created</th>
                                                <th className="py-4 px-6">Responses</th>
                                                <th className="py-4 px-6 text-right">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100 text-sm">
                                            {createdForms.map((form) => (
                                                <tr key={form.id} className="hover:bg-slate-50/60 transition-colors">
                                                    <td className="py-4 px-6">
                                                        <div className="flex items-center gap-3">
                                                            <div className="p-2 bg-teal-50 rounded-lg text-[#6DBFB3]">
                                                                <FileText size={18} />
                                                            </div>
                                                            <span className="font-semibold text-slate-800">{form.title}</span>
                                                        </div>
                                                    </td>
                                                    <td className="py-4 px-6">
                                                        <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${getStatusStyle(form.status)}`}>
                                                            {form.status}
                                                        </span>
                                                    </td>
                                                    <td className="py-4 px-6 text-slate-500 font-medium">
                                                        {formatDate(form.createdAt)}
                                                    </td>
                                                    <td className="py-4 px-6 font-bold text-slate-700">
                                                        {form.responseCount ?? 0}
                                                    </td>
                                                    <td className="py-4 px-6 text-right">
                                                        <div className="flex items-center justify-end gap-3">
                                                            <button
                                                                onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                                className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg transition-colors"
                                                                title="Edit Form"
                                                            >
                                                                <Edit3 size={16} />
                                                            </button>
                                                            <button
                                                                onClick={() => navigate('/responses')}
                                                                className="p-1.5 text-slate-400 hover:text-[#6DBFB3] rounded-lg transition-colors"
                                                                title="View Responses"
                                                            >
                                                                <BarChart2 size={16} />
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )
                        )}

                    </div>

                </div>
            </div>
        </div>
    );
}