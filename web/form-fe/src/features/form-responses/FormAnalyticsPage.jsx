import { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Users, FileText, Award, TrendingUp } from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import { getFormById, getFormAnalytics, clearSession } from '../../services/apiService';

export default function FormAnalyticsPage() {
    const { id } = useParams();
    const navigate = useNavigate();
    const [form, setForm] = useState(null);
    const [analytics, setAnalytics] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, analyticsRes] = await Promise.all([getFormById(id), getFormAnalytics(id)]);
            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }
            if (formRes.ok) setForm(formRes.data);
            if (analyticsRes.ok) setAnalytics(analyticsRes.data);
            setLoading(false);
        };
        load();
    }, [id, navigate]);

    if (loading) return <div className="flex items-center justify-center min-h-screen bg-slate-50"><p className="text-slate-400">Loading analytics...</p></div>;

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center gap-3">
                    <button onClick={() => navigate(`/forms/${id}/responses`)} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg">
                        <ArrowLeft size={18} />
                    </button>
                    <div className="min-w-0">
                        <h1 className="text-sm font-bold text-slate-800 truncate">{form?.title || 'Form'} — Analytics</h1>
                        <p className="text-[11px] text-slate-400">Response performance overview</p>
                    </div>
                </div>

                <div className="p-6 max-w-4xl mx-auto w-full space-y-6">

                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                        {[
                            { label: 'Total Responses', value: analytics?.totalResponses ?? 0, icon: <Users size={18} />, color: 'text-teal-600 bg-teal-50' },
                            { label: 'Total Questions', value: analytics?.totalQuestions ?? 0, icon: <FileText size={18} />, color: 'text-blue-600 bg-blue-50' },
                            { label: 'Scorable Q\'s', value: analytics?.scorableQuestions ?? 0, icon: <Award size={18} />, color: 'text-indigo-600 bg-indigo-50' },
                            { label: 'Avg Score', value: analytics?.averageScore != null ? `${analytics.averageScore}%` : 'N/A', icon: <TrendingUp size={18} />, color: 'text-emerald-600 bg-emerald-50' },
                        ].map(({ label, value, icon, color }) => (
                            <div key={label} className="bg-white rounded-xl border border-slate-100 p-4 flex items-center gap-3">
                                <div className={`p-2 rounded-lg ${color}`}>{icon}</div>
                                <div>
                                    <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wide">{label}</p>
                                    <p className="text-xl font-extrabold text-slate-800">{value}</p>
                                </div>
                            </div>
                        ))}
                    </div>

                    {analytics?.respondents?.length > 0 && (
                        <div className="bg-white rounded-xl border border-slate-200 overflow-hidden">
                            <div className="p-4 border-b border-slate-100">
                                <h2 className="text-sm font-bold text-slate-700">Respondent Breakdown</h2>
                            </div>
                            <div className="overflow-x-auto">
                                <table className="w-full text-sm text-left">
                                    <thead>
                                        <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                            <th className="py-3 px-4">#</th>
                                            <th className="py-3 px-4">Respondent</th>
                                            <th className="py-3 px-4">Answered</th>
                                            <th className="py-3 px-4">Correct</th>
                                            <th className="py-3 px-4">Score</th>
                                            <th className="py-3 px-4">Submitted</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100">
                                        {analytics.respondents.map((r, i) => (
                                            <tr key={r.responseId} className="hover:bg-slate-50">
                                                <td className="py-3 px-4 text-slate-400">{i + 1}</td>
                                                <td className="py-3 px-4 font-semibold text-slate-800">{r.respondentName || 'Anonymous'}</td>
                                                <td className="py-3 px-4 text-slate-600">{r.answeredCount}/{r.totalQuestions}</td>
                                                <td className="py-3 px-4 text-slate-600">{r.correctCount}/{r.scorableQuestions}</td>
                                                <td className="py-3 px-4">
                                                    {r.score != null ? (
                                                        <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${r.score >= 70 ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600'}`}>
                                                            {r.score}%
                                                        </span>
                                                    ) : <span className="text-slate-400 text-xs">N/A</span>}
                                                </td>
                                                <td className="py-3 px-4 text-slate-500 text-xs">
                                                    {new Date(r.submittedAt).toLocaleDateString()}
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                    {(!analytics || analytics.totalResponses === 0) && (
                        <div className="text-center py-16 text-slate-400 text-sm">No responses to analyze yet.</div>
                    )}
                </div>
            </div>
        </div>
    );
}
