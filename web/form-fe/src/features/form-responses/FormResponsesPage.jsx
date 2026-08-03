import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Download, Eye, X } from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import { getFormById, getFormResponses, getResponseDetail, clearSession, exportUrl } from '../../services/apiService';

export default function FormResponsesPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [form, setForm] = useState(null);
    const [responses, setResponses] = useState([]);
    const [loading, setLoading] = useState(true);
    const [detail, setDetail] = useState(null);
    const [detailLoading, setDetailLoading] = useState(false);

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, respRes] = await Promise.all([getFormById(id), getFormResponses(id)]);
            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }
            if (formRes.ok) setForm(formRes.data);
            if (respRes.ok && Array.isArray(respRes.data)) setResponses(respRes.data);
            setLoading(false);
        };
        load();
    }, [id, navigate]);

    const viewDetail = async (responseId) => {
        setDetailLoading(true);
        const res = await getResponseDetail(id, responseId);
        if (res.ok) setDetail(res.data);
        setDetailLoading(false);
    };

    const formatDate = (d) => d ? new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';

    if (loading) return <div className="flex items-center justify-center min-h-screen bg-slate-50"><p className="text-slate-400">Loading...</p></div>;

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/responses')} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <h1 className="text-sm font-bold text-slate-800 truncate">{form?.title || 'Form'}</h1>
                            <p className="text-[11px] text-slate-400">{responses.length} responses</p>
                        </div>
                    </div>
                    <div className="flex items-center gap-2 shrink-0">
                        <button
                            onClick={() => navigate(`/forms/${id}/analytics`)}
                            className="px-3 py-1.5 bg-teal-50 text-teal-600 text-xs font-bold rounded-lg hover:bg-teal-100"
                        >
                            Analytics
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

                <div className="p-6 max-w-4xl mx-auto w-full">
                    {responses.length === 0 ? (
                        <div className="text-center py-16 text-slate-400 text-sm">No responses yet.</div>
                    ) : (
                        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
                            <table className="w-full text-sm text-left">
                                <thead>
                                    <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                        <th className="py-3 px-4">#</th>
                                        <th className="py-3 px-4">Respondent</th>
                                        <th className="py-3 px-4">Status</th>
                                        <th className="py-3 px-4">Submitted At</th>
                                        <th className="py-3 px-4 text-right">Action</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y divide-slate-100">
                                    {responses.map((r, i) => (
                                        <tr key={r.id} className="hover:bg-slate-50 transition-colors">
                                            <td className="py-3 px-4 text-slate-400 font-medium">{i + 1}</td>
                                            <td className="py-3 px-4 font-semibold text-slate-800">{r.respondentName || 'Anonymous'}</td>
                                            <td className="py-3 px-4">
                                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-600">
                                                    {r.status}
                                                </span>
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
                    )}
                </div>
            </div>

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
                                        <p><span className="font-bold">Status:</span> {detail.status}</p>
                                        <p><span className="font-bold">Submitted:</span> {new Date(detail.submittedAt).toLocaleString()}</p>
                                    </div>
                                    <div className="space-y-3">
                                        {detail.answers?.map((a, i) => (
                                            <div key={i} className="bg-slate-50 rounded-lg p-3">
                                                <p className="text-xs font-bold text-slate-700 mb-1">{i + 1}. {a.question}</p>
                                                <p className="text-sm text-slate-800">{a.optionText || a.answerValue || <span className="text-slate-400 italic">No answer</span>}</p>
                                                {a.correctAnswer && (
                                                    <p className={`text-[11px] font-bold mt-1 ${a.isCorrect ? 'text-emerald-600' : 'text-red-500'}`}>
                                                        {a.isCorrect ? '✓ Correct' : `✗ Correct answer: ${a.correctAnswer}`}
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
