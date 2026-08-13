import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Download, Eye, X, BarChart2, Loader2 } from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    getFormById, getFormResponses, getResponseDetail,
    updateResponseStatus, clearSession, exportUrl
} from '../../services/apiService';

const STATUS_OPTIONS = [
    { id: 1, label: 'New' },
    { id: 2, label: 'Reviewed' },
    { id: 3, label: 'Accepted' },
    { id: 4, label: 'Rejected' },
];

const PAGE_SIZE = 20;

export default function FormResponsesPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [form, setForm] = useState(null);
    const [responses, setResponses] = useState([]);
    const [loading, setLoading] = useState(true);
    const [loadingMore, setLoadingMore] = useState(false);
    const [page, setPage] = useState(1);
    const [hasMore, setHasMore] = useState(true);
    const [totalCount, setTotalCount] = useState(0);

    const [detail, setDetail] = useState(null);
    const [detailLoading, setDetailLoading] = useState(false);
    const [statusUpdating, setStatusUpdating] = useState(null);
    const [toast, setToast] = useState(null);

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, respRes] = await Promise.all([
                getFormById(id),
                getFormResponses(id, 1, PAGE_SIZE)
            ]);
            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }
            if (formRes.ok) setForm(formRes.data);

            if (respRes.ok) {
                const list = Array.isArray(respRes.data)
                    ? respRes.data
                    : respRes.data?.responses || respRes.data?.items || [];
                const total = respRes.data?.totalCount ?? list.length;

                setResponses(list);
                setTotalCount(total);
                setHasMore(list.length >= PAGE_SIZE);
            }
            setLoading(false);
        };
        load();
    }, [id, navigate]);

    const handleLoadMore = useCallback(async () => {
        if (loadingMore || !hasMore) return;
        setLoadingMore(true);

        const nextPage = page + 1;
        const res = await getFormResponses(id, nextPage, PAGE_SIZE);
        setLoadingMore(false);

        if (res.ok) {
            const newList = Array.isArray(res.data)
                ? res.data
                : res.data?.responses || res.data?.items || [];

            if (newList.length > 0) {
                setResponses(prev => [...prev, ...newList]);
                setPage(nextPage);
                setHasMore(newList.length >= PAGE_SIZE);
            } else {
                setHasMore(false);
            }
        }
    }, [id, page, loadingMore, hasMore]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    const viewDetail = async (responseId) => {
        setDetailLoading(true);
        const res = await getResponseDetail(id, responseId);
        if (res.ok) setDetail(res.data);
        setDetailLoading(false);
    };

    const handleStatusChange = async (responseId, statusId) => {
        setStatusUpdating(responseId);
        const res = await updateResponseStatus(responseId, statusId);
        if (res.ok) {
            setResponses(prev => prev.map(r =>
                r.id === responseId
                    ? { ...r, status: STATUS_OPTIONS.find(s => s.id === statusId)?.label?.toLowerCase() ?? r.status }
                    : r
            ));
            if (detail?.id === responseId) {
                setDetail(prev => ({
                    ...prev,
                    status: STATUS_OPTIONS.find(s => s.id === statusId)?.label?.toLowerCase() ?? prev.status,
                }));
            }
            showToast('Status updated');
        } else {
            showToast(res.message || 'Failed to update status', 'error');
        }
        setStatusUpdating(null);
    };

    const formatDate = (d) => d
        ? new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' })
        : '—';

    const statusColor = (status) => {
        switch (status?.toLowerCase()) {
            case 'new': return 'bg-blue-50 text-blue-600';
            case 'reviewed': return 'bg-yellow-50 text-yellow-600';
            case 'accepted': return 'bg-emerald-50 text-emerald-600';
            case 'rejected': return 'bg-red-50 text-red-600';
            default: return 'bg-slate-100 text-slate-500';
        }
    };

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-slate-50">
            <p className="text-slate-400 text-sm">Loading responses...</p>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/my-forms')} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <h1 className="text-sm font-bold text-slate-800 truncate">{form?.title || 'Form'}</h1>
                            <p className="text-[11px] text-slate-400">{responses.length} / {totalCount || responses.length} responses loaded</p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                        <button
                            onClick={() => navigate(`/forms/${id}/analytics`)}
                            className="flex items-center gap-1.5 px-3 py-1.5 bg-teal-50 text-teal-600 text-xs font-bold rounded-lg hover:bg-teal-100"
                        >
                            <BarChart2 size={13} /> Analytics
                        </button>
                        <a
                            href={exportUrl(id)}
                            target="_blank"
                            rel="noreferrer"
                            className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-800 text-white text-xs font-bold rounded-lg hover:bg-slate-900"
                        >
                            <Download size={13} /> Export CSV
                        </a>
                    </div>
                </div>

                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-sm font-semibold text-white ${toast.type === 'error' ? 'bg-red-500' : 'bg-teal-600'}`}>
                        {toast.msg}
                    </div>
                )}

                <div className="p-6 max-w-5xl mx-auto w-full space-y-4">
                    {responses.length === 0 ? (
                        <div className="text-center py-16 text-slate-400 text-sm">No responses yet.</div>
                    ) : (
                        <>
                            <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-xs">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                            <th className="py-3 px-4">#</th>
                                            <th className="py-3 px-4">Respondent</th>
                                            <th className="py-3 px-4">Status</th>
                                            <th className="py-3 px-4">Submitted At</th>
                                            <th className="py-3 px-4 text-right">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100">
                                        {responses.map((r, i) => (
                                            <tr key={r.id} className="hover:bg-slate-50 transition-colors">
                                                <td className="py-3 px-4 text-slate-400 font-medium">{i + 1}</td>
                                                <td className="py-3 px-4 font-semibold text-slate-800">{r.respondentName || 'Anonymous'}</td>
                                                <td className="py-3 px-4">
                                                    <select
                                                        value={STATUS_OPTIONS.find(s => s.label.toLowerCase() === r.status?.toLowerCase())?.id ?? ''}
                                                        onChange={e => handleStatusChange(r.id, parseInt(e.target.value))}
                                                        disabled={statusUpdating === r.id}
                                                        className={`text-[11px] font-bold px-2 py-0.5 rounded-full border-0 cursor-pointer focus:outline-none focus:ring-1 focus:ring-teal-400 disabled:opacity-60 ${statusColor(r.status)}`}
                                                    >
                                                        {STATUS_OPTIONS.map(s => (
                                                            <option key={s.id} value={s.id}>{s.label}</option>
                                                        ))}
                                                    </select>
                                                </td>
                                                <td className="py-3 px-4 text-slate-500 text-xs">{formatDate(r.submittedAt)}</td>
                                                <td className="py-3 px-4 text-right">
                                                    <button
                                                        onClick={() => viewDetail(r.id)}
                                                        className="inline-flex items-center gap-1 text-xs font-bold text-teal-600 hover:underline"
                                                    >
                                                        <Eye size={13} /> View
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>

                            {/* Infinite Scroll / Load More Button */}
                            {hasMore && (
                                <div className="text-center pt-2">
                                    <button
                                        onClick={handleLoadMore}
                                        disabled={loadingMore}
                                        className="px-5 py-2.5 bg-white border border-slate-200 hover:bg-slate-50 text-slate-700 text-xs font-bold rounded-xl shadow-xs transition-all flex items-center justify-center gap-2 mx-auto disabled:opacity-60"
                                    >
                                        {loadingMore ? (
                                            <><Loader2 size={14} className="animate-spin text-teal-600" /> Memuat respons...</>
                                        ) : (
                                            `Muat Lebih Banyak (${responses.length} dari ${totalCount || 'banyak'})`
                                        )}
                                    </button>
                                </div>
                            )}
                        </>
                    )}
                </div>
            </div>

            {/* Detail modal */}
            {(detail || detailLoading) && (
                <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
                    <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[80vh] flex flex-col">
                        <div className="flex items-center justify-between p-4 border-b border-slate-100">
                            <h3 className="font-bold text-slate-800 text-sm">Response Detail</h3>
                            <button onClick={() => setDetail(null)} className="text-slate-400 hover:text-slate-700"><X size={18} /></button>
                        </div>
                        <div className="overflow-y-auto p-4 space-y-4 flex-1">
                            {detailLoading ? (
                                <p className="text-center text-slate-400 text-sm py-8">Loading...</p>
                            ) : detail ? (
                                <>
                                    <div className="text-xs text-slate-500 space-y-1">
                                        <p><span className="font-bold">Respondent:</span> {detail.respondentName || 'Anonymous'}</p>
                                        <p><span className="font-bold">Status:</span>{' '}
                                            <select
                                                value={STATUS_OPTIONS.find(s => s.label.toLowerCase() === detail.status?.toLowerCase())?.id ?? ''}
                                                onChange={e => handleStatusChange(detail.id, parseInt(e.target.value))}
                                                disabled={statusUpdating === detail.id}
                                                className="ml-1 border border-slate-200 rounded text-xs px-1 py-0.5"
                                            >
                                                {STATUS_OPTIONS.map(s => <option key={s.id} value={s.id}>{s.label}</option>)}
                                            </select>
                                        </p>
                                        <p><span className="font-bold">Submitted:</span> {formatDate(detail.submittedAt)}</p>
                                    </div>
                                    <div className="space-y-3">
                                        {detail.answers?.map((a, i) => (
                                            <div key={i} className="bg-slate-50 rounded-lg p-3">
                                                <p className="text-xs font-bold text-slate-700 mb-1">{i + 1}. {a.question}</p>
                                                <p className="text-sm text-slate-800">
                                                    {a.optionText || a.answerValue || <span className="text-slate-400 italic">No answer</span>}
                                                </p>
                                                {a.correctAnswer && (
                                                    <p className={`text-[11px] font-bold mt-1 ${a.isCorrect ? 'text-emerald-600' : 'text-red-500'}`}>
                                                        {a.isCorrect ? '✓ Correct' : `✗ Correct: ${a.correctAnswer}`}
                                                    </p>
                                                )}
                                            </div>
                                        ))}
                                    </div>
                                </>
                            ) : null}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
