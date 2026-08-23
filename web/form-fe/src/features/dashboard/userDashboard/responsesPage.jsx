import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    TrendingUp, Calendar, FileText, ChevronRight,
    Users, Award, Eye, X, CheckCircle2, XCircle, MinusCircle,
    ChevronLeft, Loader2, ArrowLeft, BarChart3, Download, Maximize2
} from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import {
    getMyForms, getFormAnalytics, getFormById, clearSession,
    exportFormResponses, assetUrl
} from '../../../services/apiService';
import RichContentRenderer from '../../../utils/RichContentRenderer';
import ImageLightboxModal from '../../../components/ui/ImageLightboxModal';

export default function ResponsesPage() {
    const navigate = useNavigate();
    const [forms, setForms] = useState([]);
    const [loadingForms, setLoadingForms] = useState(true);
    const [selectedFormId, setSelectedFormId] = useState(null);
    const [selectedFormData, setSelectedFormData] = useState(null);
    const [analyticsData, setAnalyticsData] = useState(null);
    const [loadingDetail, setLoadingDetail] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const [exporting, setExporting] = useState(false);
    const [lightboxImage, setLightboxImage] = useState(null);

    // Modal Review Answers State
    const [selectedRespondent, setSelectedRespondent] = useState(null);

    useEffect(() => {
        const fetchForms = async () => {
            try {
                setLoadingForms(true);
                const result = await getMyForms();
                if (result.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }
                if (result.ok && Array.isArray(result.data)) {
                    setForms(result.data);
                    // Select first form if available
                    if (result.data.length > 0) {
                        setSelectedFormId(result.data[0].id);
                    }
                }
            } catch (err) {
                console.error('Error fetching forms for responses page:', err);
            } finally {
                setLoadingForms(false);
            }
        };
        fetchForms();
    }, [navigate]);

    // Load analytics/responses data whenever selectedFormId changes
    useEffect(() => {
        if (!selectedFormId) return;

        const loadFormDetails = async () => {
            setLoadingDetail(true);
            try {
                const [formRes, analyticsRes] = await Promise.all([
                    getFormById(selectedFormId),
                    getFormAnalytics(selectedFormId, 1, 100)
                ]);

                if (formRes.ok) setSelectedFormData(formRes.data);
                if (analyticsRes.ok && analyticsRes.data) {
                    setAnalyticsData(analyticsRes.data);
                } else {
                    setAnalyticsData(null);
                }
            } catch (err) {
                console.error('Error loading form detail/analytics:', err);
            } finally {
                setLoadingDetail(false);
            }
        };

        loadFormDetails();
    }, [selectedFormId]);

    // Filter forms based on search query
    const filteredForms = useMemo(() => {
        if (!searchQuery.trim()) return forms;
        const q = searchQuery.toLowerCase();
        return forms.filter(f => (
            (f.title && f.title.toLowerCase().includes(q)) ||
            (f.description && f.description.toLowerCase().includes(q))
        ));
    }, [forms, searchQuery]);

    // Calculate response trend from existing respondent data
    const respondents = analyticsData?.respondents || [];
    
    // Filter respondents based on search query
    const filteredRespondents = useMemo(() => {
        if (!searchQuery.trim()) return respondents;
        const q = searchQuery.toLowerCase();
        return respondents.filter(r => (
            (r.respondentName && r.respondentName.toLowerCase().includes(q)) ||
            (String(r.responseId).includes(q))
        ));
    }, [respondents, searchQuery]);

    const trendData = useMemo(() => {
        if (!respondents || respondents.length === 0) return [];

        const dateMap = {};
        respondents.forEach(r => {
            if (!r.submittedAt) return;
            const d = new Date(r.submittedAt).toLocaleDateString('id-ID', {
                day: '2-digit',
                month: 'short'
            });
            dateMap[d] = (dateMap[d] || 0) + 1;
        });

        return Object.entries(dateMap).map(([date, count]) => ({
            date,
            count
        }));
    }, [respondents]);

    const maxCount = useMemo(() => {
        if (trendData.length === 0) return 1;
        return Math.max(...trendData.map(d => d.count), 1);
    }, [trendData]);

    const formatDate = (dateStr) => {
        if (!dateStr) return '—';
        return new Date(dateStr).toLocaleDateString('id-ID', {
            day: 'numeric',
            month: 'short',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    };

    const totalAllResponses = forms.reduce((acc, f) => acc + (f.responseCount ?? 0), 0);

    const handleExport = async (formId) => {
        if (!formId || exporting) return;
        setExporting(true);
        try {
            const res = await exportFormResponses(formId);
            if (!res.ok) {
                alert(res.message || 'Gagal mengekspor data CSV respons.');
            }
        } catch (err) {
            console.error('Error exporting CSV:', err);
            alert('Terjadi kesalahan saat mengekspor CSV.');
        } finally {
            setExporting(false);
        }
    };

    // Modal navigation
    const currentIndex = selectedRespondent
        ? respondents.findIndex(r => r.responseId === selectedRespondent.responseId)
        : -1;

    const goPrevious = () => {
        if (currentIndex > 0) {
            setSelectedRespondent(respondents[currentIndex - 1]);
        }
    };

    const goNext = () => {
        if (currentIndex < respondents.length - 1) {
            setSelectedRespondent(respondents[currentIndex + 1]);
        }
    };

    const getAnswerStatus = (answer) => {
        if (answer.isCorrect === true) {
            return {
                label: 'Benar',
                icon: <CheckCircle2 size={16} />,
                className: 'text-emerald-600 bg-emerald-50 dark:bg-emerald-950/60 dark:text-emerald-400 border-emerald-200 dark:border-emerald-800'
            };
        }
        if (answer.isCorrect === false) {
            return {
                label: 'Salah',
                icon: <XCircle size={16} />,
                className: 'text-red-600 bg-red-50 dark:bg-red-950/60 dark:text-red-400 border-red-200 dark:border-red-800'
            };
        }
        return {
            label: 'Tidak Dinilai',
            icon: <MinusCircle size={16} />,
            className: 'text-slate-500 bg-slate-50 dark:bg-slate-800 dark:text-slate-400 border-slate-200 dark:border-slate-700'
        };
    };

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar 
                        searchQuery={searchQuery} 
                        onSearchChange={setSearchQuery} 
                        placeholder="Cari formulir, responden, atau jawaban..." 
                    />

                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div>
                            <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">Respons Formulir</h1>
                            <p className="text-sm text-slate-500 dark:text-slate-400 font-medium mt-1">
                                {totalAllResponses.toLocaleString('id-ID')} total respons dari {forms.length} formulir aktif.
                            </p>
                        </div>
                    </div>

                    {loadingForms ? (
                        <div className="py-20 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                            <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400 mb-2" />
                            Memuat data respons...
                        </div>
                    ) : forms.length === 0 ? (
                        <div className="bg-white dark:bg-slate-900 rounded-3xl border-2 border-dashed border-slate-200 dark:border-slate-800 p-12 text-center space-y-4">
                            <div className="w-14 h-14 bg-teal-50 dark:bg-teal-950/60 rounded-2xl flex items-center justify-center mx-auto text-[#00897B] dark:text-teal-400 shadow-xs">
                                <FileText size={28} />
                            </div>
                            <div className="space-y-1">
                                <h3 className="text-base font-bold text-slate-900 dark:text-white">Belum Ada Formulir</h3>
                                <p className="text-xs text-slate-500 dark:text-slate-400 max-w-sm mx-auto">
                                    Buat formulir pertama Anda dan bagikan ke audiens untuk mulai menerima respons.
                                </p>
                            </div>
                            <button
                                onClick={() => navigate('/create-form')}
                                className="px-5 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white font-bold text-xs rounded-xl shadow-xs transition-all cursor-pointer inline-flex items-center gap-1.5"
                            >
                                Buat Formulir Sekarang
                            </button>
                        </div>
                    ) : (
                        <div className="space-y-6">

                            {/* Form Selector Bar */}
                            <div className="bg-white dark:bg-slate-900 p-4 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
                                <div className="flex items-center gap-3 flex-1 min-w-0">
                                    <div className="p-2.5 rounded-xl bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 shrink-0">
                                        <BarChart3 size={20} />
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <label className="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider block mb-0.5">Pilih Formulir Aktif</label>
                                        <select
                                            value={selectedFormId || ''}
                                            onChange={e => setSelectedFormId(parseInt(e.target.value))}
                                            className="w-full bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold text-slate-800 dark:text-slate-100 outline-none focus:ring-2 focus:ring-[#00897B] cursor-pointer"
                                        >
                                            {filteredForms.map(f => (
                                                <option key={f.id} value={f.id}>
                                                    {f.title || 'Formulir Tanpa Judul'} ({f.responseCount ?? 0} respons)
                                                </option>
                                            ))}
                                        </select>
                                    </div>
                                </div>

                                {selectedFormId && (
                                    <div className="flex items-center gap-2 shrink-0">
                                        <button
                                            type="button"
                                            onClick={() => handleExport(selectedFormId)}
                                            disabled={exporting}
                                            className="px-3.5 py-2 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-xs font-bold rounded-xl flex items-center gap-1.5 transition-all border border-slate-200 dark:border-slate-700 disabled:opacity-60 cursor-pointer"
                                        >
                                            {exporting ? <Loader2 size={14} className="animate-spin" /> : <Download size={14} />}
                                            <span>{exporting ? 'Mengekspor...' : 'Unduh CSV'}</span>
                                        </button>
                                        <button
                                            type="button"
                                            onClick={() => navigate(`/forms/${selectedFormId}/edit`)}
                                            className="px-3.5 py-2 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer"
                                        >
                                            Edit Formulir
                                        </button>
                                    </div>
                                )}
                            </div>

                            {loadingDetail ? (
                                <div className="py-20 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                    <Loader2 className="w-8 h-8 animate-spin mx-auto text-[#00897B] dark:text-teal-400 mb-2" />
                                    Memuat rincian respons formulir...
                                </div>
                            ) : (
                                <div className="space-y-6">

                                    {/* SUMMARY STATS & TREND DIAGRAM */}
                                    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

                                        {/* Summary Cards */}
                                        <div className="space-y-4 lg:col-span-1">
                                            <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                                                <div>
                                                    <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Total Respons Formulir Ini</p>
                                                    <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">
                                                        {analyticsData?.totalResponses ?? respondents.length}
                                                    </h3>
                                                </div>
                                                <div className="p-2.5 rounded-xl bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400">
                                                    <Users size={20} />
                                                </div>
                                            </div>

                                            <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                                                <div>
                                                    <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Rata-rata Skor</p>
                                                    <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">
                                                        {analyticsData?.averageScore != null ? `${analyticsData.averageScore}%` : 'N/A'}
                                                    </h3>
                                                </div>
                                                <div className="p-2.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400">
                                                    <Award size={20} />
                                                </div>
                                            </div>

                                            <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex items-center justify-between">
                                                <div>
                                                    <p className="text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider mb-1">Total Soal</p>
                                                    <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">
                                                        {analyticsData?.totalQuestions ?? 0}
                                                    </h3>
                                                </div>
                                                <div className="p-2.5 rounded-xl bg-blue-50 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400">
                                                    <FileText size={20} />
                                                </div>
                                            </div>
                                        </div>

                                        {/* RESPONSE TREND DIAGRAM */}
                                        <div className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm lg:col-span-2 flex flex-col justify-between">
                                            <div className="flex items-center justify-between mb-4">
                                                <div>
                                                    <h3 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                                                        <TrendingUp size={16} className="text-[#00897B] dark:text-teal-400" />
                                                        Diagram Tren Respons
                                                    </h3>
                                                    <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                                        Perkembangan jumlah respons berdasarkan tanggal/waktu submit aktual
                                                    </p>
                                                </div>
                                                <span className="text-[11px] font-bold px-2.5 py-1 rounded-full bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400">
                                                    {trendData.length} Titik Data
                                                </span>
                                            </div>

                                            {trendData.length === 0 ? (
                                                <div className="h-48 flex flex-col items-center justify-center text-center space-y-2 border-2 border-dashed border-slate-100 dark:border-slate-800 rounded-xl p-4">
                                                    <Calendar size={28} className="text-slate-300 dark:text-slate-600" />
                                                    <p className="text-xs text-slate-400 dark:text-slate-500 font-medium">
                                                        Belum ada data respons untuk menampilkan diagram tren.
                                                    </p>
                                                </div>
                                            ) : (
                                                <div className="space-y-3 pt-2">
                                                    <div className="h-48 flex items-end gap-2 sm:gap-4 pt-6 pb-2 px-2 border-b border-slate-100 dark:border-slate-800">
                                                        {trendData.map((item, idx) => {
                                                            const heightPercent = Math.max((item.count / maxCount) * 100, 15);
                                                            return (
                                                                <div key={idx} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group">
                                                                    <span className="text-[10px] font-extrabold text-[#00897B] dark:text-teal-400 opacity-0 group-hover:opacity-100 transition-opacity">
                                                                        {item.count}
                                                                    </span>
                                                                    <div
                                                                        className="w-full bg-linear-to-t from-[#00897B] to-[#4DB6AC] dark:from-teal-600 dark:to-teal-400 rounded-t-lg transition-all duration-500 group-hover:brightness-110 shadow-xs"
                                                                        style={{ height: `${heightPercent}%` }}
                                                                    />
                                                                    <span className="text-[10px] font-semibold text-slate-400 dark:text-slate-500 truncate w-full text-center">
                                                                        {item.date}
                                                                    </span>
                                                                </div>
                                                            );
                                                        })}
                                                    </div>
                                                    <p className="text-[11px] text-slate-400 dark:text-slate-500 text-center font-medium">
                                                        Sumbu X: Tanggal Pengiriman · Sumbu Y: Jumlah Respons
                                                    </p>
                                                </div>
                                            )}
                                        </div>

                                    </div>

                                    {/* RESPONDENT BREAKDOWN TABLE & REVIEW ANSWERS */}
                                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden">
                                        <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                                            <div>
                                                <h3 className="text-base font-bold text-slate-900 dark:text-white">Rincian Respons Responden</h3>
                                                <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                                    Klik Review Jawaban untuk melihat jawaban lengkap setiap responden.
                                                </p>
                                            </div>
                                            <span className="text-xs font-bold text-slate-500 dark:text-slate-400 self-start sm:self-auto">
                                                Total: {filteredRespondents.length} Responden
                                            </span>
                                        </div>

                                        {filteredRespondents.length === 0 ? (
                                            <div className="py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                                {searchQuery ? `Tidak ada responden yang cocok dengan "${searchQuery}".` : 'Belum ada respons yang diterima untuk formulir ini.'}
                                            </div>
                                        ) : (
                                            <div className="overflow-x-auto w-full">
                                                <table className="w-full text-sm text-left">
                                                    <thead>
                                                        <tr className="bg-slate-50 dark:bg-slate-800/60 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                                                            <th className="py-3.5 px-4">#</th>
                                                            <th className="py-3.5 px-4">Responden</th>
                                                            <th className="py-3.5 px-4">Soal Dijawab</th>
                                                            <th className="py-3.5 px-4">Jumlah Benar</th>
                                                            <th className="py-3.5 px-4">Jumlah Salah</th>
                                                            <th className="py-3.5 px-4">Skor</th>
                                                            <th className="py-3.5 px-4">Waktu Submit</th>
                                                            <th className="py-3.5 px-4 text-right">Aksi</th>
                                                        </tr>
                                                    </thead>
                                                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                                                        {filteredRespondents.map((r, idx) => {
                                                            const scorable = r.scorableQuestions ?? 0;
                                                            const correct = r.correctCount ?? 0;
                                                            const wrong = r.wrongCount != null ? r.wrongCount : Math.max(scorable - correct, 0);

                                                            return (
                                                                <tr key={r.responseId || idx} className="hover:bg-slate-50 dark:hover:bg-slate-800/40 transition-colors">
                                                                    <td className="py-3.5 px-4 text-slate-400 font-medium">{idx + 1}</td>
                                                                    <td className="py-3.5 px-4">
                                                                        <div className="font-bold text-slate-900 dark:text-white">
                                                                            {r.respondentName || 'Anonim'}
                                                                        </div>
                                                                        <div className="text-[10px] text-slate-400 dark:text-slate-500">
                                                                            Respons #{r.responseId}
                                                                        </div>
                                                                    </td>
                                                                    <td className="py-3.5 px-4 text-slate-600 dark:text-slate-300 font-medium">
                                                                        {r.answeredCount ?? 0}/{r.totalQuestions ?? 0}
                                                                    </td>
                                                                    <td className="py-3.5 px-4 text-emerald-600 dark:text-emerald-400 font-bold">
                                                                        {correct}
                                                                    </td>
                                                                    <td className="py-3.5 px-4 text-red-500 dark:text-red-400 font-bold">
                                                                        {wrong}
                                                                    </td>
                                                                    <td className="py-3.5 px-4">
                                                                        {r.score != null ? (
                                                                            <span className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                                                                                r.score >= 70
                                                                                    ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800'
                                                                                    : 'bg-red-50 text-red-600 dark:bg-red-950/60 dark:text-red-400 border border-red-200 dark:border-red-800'
                                                                            }`}>
                                                                                {r.score}%
                                                                            </span>
                                                                        ) : (
                                                                            <span className="text-xs text-slate-400 dark:text-slate-500 font-medium">N/A</span>
                                                                        )}
                                                                    </td>
                                                                    <td className="py-3.5 px-4 text-slate-500 dark:text-slate-400 text-xs">
                                                                        {formatDate(r.submittedAt)}
                                                                    </td>
                                                                    <td className="py-3.5 px-4 text-right">
                                                                        <button
                                                                            onClick={() => setSelectedRespondent(r)}
                                                                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold shadow-xs transition-all cursor-pointer"
                                                                        >
                                                                            <Eye size={13} /> Review Jawaban
                                                                        </button>
                                                                    </td>
                                                                </tr>
                                                            );
                                                        })}
                                                    </tbody>
                                                </table>
                                            </div>
                                        )}
                                    </div>

                                </div>
                            )}

                        </div>
                    )}

                </main>
            </div>

            {/* ── REVIEW JAWABAN MODAL ── */}
            {selectedRespondent && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div
                        className="absolute inset-0 bg-black/50 backdrop-blur-xs"
                        onClick={() => setSelectedRespondent(null)}
                    />

                    <div className="relative bg-white dark:bg-slate-900 w-full max-w-3xl max-h-[90vh] rounded-3xl shadow-2xl flex flex-col overflow-hidden border border-slate-200 dark:border-slate-800 text-slate-800 dark:text-slate-100 animate-in fade-in zoom-in-95 duration-200">
                        
                        {/* Modal Header */}
                        <div className="px-6 py-4 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between shrink-0 bg-slate-50/50 dark:bg-slate-800/50">
                            <div>
                                <h2 className="font-bold text-slate-900 dark:text-white text-base">
                                    Review Jawaban Responden
                                </h2>
                                <p className="text-xs text-slate-400 dark:text-slate-500 mt-0.5">
                                    Responden: <span className="font-bold text-slate-700 dark:text-slate-300">{selectedRespondent.respondentName || 'Anonim'}</span> (Respons #{selectedRespondent.responseId})
                                </p>
                            </div>
                            <button
                                onClick={() => setSelectedRespondent(null)}
                                className="p-2 rounded-xl text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                            >
                                <X size={18} />
                            </button>
                        </div>

                        {/* Summary Bar */}
                        <div className="px-6 py-3.5 bg-slate-100/60 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 flex flex-wrap items-center gap-3">
                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Skor</p>
                                <p className="text-base font-extrabold text-slate-900 dark:text-white">
                                    {selectedRespondent.score != null ? `${selectedRespondent.score}%` : 'N/A'}
                                </p>
                            </div>
                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Dijawab</p>
                                <p className="text-base font-extrabold text-slate-900 dark:text-white">
                                    {selectedRespondent.answeredCount}/{selectedRespondent.totalQuestions}
                                </p>
                            </div>
                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Benar</p>
                                <p className="text-base font-extrabold text-emerald-600 dark:text-emerald-400">
                                    {selectedRespondent.correctCount ?? 0}
                                </p>
                            </div>
                            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-1.5 shadow-xs">
                                <p className="text-[10px] uppercase font-bold text-slate-400 dark:text-slate-500">Waktu Submit</p>
                                <p className="text-xs font-bold text-slate-700 dark:text-slate-300 mt-1">
                                    {formatDate(selectedRespondent.submittedAt)}
                                </p>
                            </div>
                        </div>

                        {/* Answer Details */}
                        <div className="flex-1 overflow-y-auto p-6 space-y-4">
                            {(selectedRespondent.answers || []).map((answer, index) => {
                                const status = getAnswerStatus(answer);

                                return (
                                    <div
                                        key={answer.questionId || index}
                                        className="border border-slate-200 dark:border-slate-800 rounded-2xl overflow-hidden shadow-xs"
                                    >
                                        <div className="p-4 bg-white dark:bg-slate-900 flex items-start gap-3 justify-between">
                                            <div className="flex items-start gap-3 flex-1 min-w-0">
                                                <span className="shrink-0 w-7 h-7 flex items-center justify-center rounded-xl bg-slate-100 dark:bg-slate-800 text-xs font-bold text-slate-600 dark:text-slate-300">
                                                    {index + 1}
                                                </span>
                                                <div className="flex-1 min-w-0">
                                                    <div className="text-sm font-semibold text-slate-900 dark:text-white leading-relaxed">
                                                        <RichContentRenderer content={answer.question} />
                                                    </div>
                                                    {answer.questionImage && (
                                                        <div className="my-2 max-w-xs relative group/img overflow-hidden rounded-xl border border-slate-200 dark:border-slate-700 p-1 bg-white dark:bg-slate-900 shadow-xs">
                                                            <img
                                                                src={assetUrl(answer.questionImage)}
                                                                alt="Gambar Soal"
                                                                className="max-h-40 w-auto rounded-lg object-contain mx-auto cursor-zoom-in"
                                                                onClick={() => setLightboxImage({ src: assetUrl(answer.questionImage), alt: 'Gambar Soal' })}
                                                            />
                                                            <button
                                                                type="button"
                                                                onClick={() => setLightboxImage({ src: assetUrl(answer.questionImage), alt: 'Gambar Soal' })}
                                                                className="absolute bottom-2 right-2 p-1.5 bg-slate-900/80 hover:bg-slate-900 text-white rounded-lg text-xs font-bold flex items-center gap-1 opacity-0 group-hover/img:opacity-100 transition-opacity cursor-pointer"
                                                            >
                                                                <Maximize2 size={11} /> Perbesar
                                                            </button>
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                            <div className={`shrink-0 flex items-center gap-1.5 px-2.5 py-1 rounded-full border text-[11px] font-bold ${status.className}`}>
                                                {status.icon}
                                                <span>{status.label}</span>
                                            </div>
                                        </div>

                                        <div className="border-t border-slate-100 dark:border-slate-800 p-4 space-y-3 bg-slate-50 dark:bg-slate-800/50 text-xs">
                                            <div>
                                                <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400 dark:text-slate-500 mb-1">
                                                    Jawaban Responden:
                                                </p>
                                                <div className={`rounded-xl border p-3 font-medium ${
                                                    answer.isCorrect === true
                                                        ? 'bg-emerald-50 dark:bg-emerald-950/40 border-emerald-200 dark:border-emerald-800 text-emerald-900 dark:text-emerald-200'
                                                        : answer.isCorrect === false
                                                        ? 'bg-red-50 dark:bg-red-950/40 border-red-200 dark:border-red-800 text-red-900 dark:text-red-200'
                                                        : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-200'
                                                }`}>
                                                    {answer.answerText || answer.answerValue || answer.optionText ? (
                                                        <RichContentRenderer content={answer.answerText || answer.answerValue || answer.optionText} />
                                                    ) : (
                                                        <span className="text-slate-400 dark:text-slate-500 italic">Tidak ada jawaban</span>
                                                    )}
                                                </div>
                                            </div>

                                            {answer.correctAnswer && (
                                                <div>
                                                    <p className="text-[10px] uppercase tracking-wider font-bold text-slate-400 dark:text-slate-500 mb-1">
                                                        Kunci / Jawaban Benar:
                                                    </p>
                                                    <div className="rounded-xl border border-emerald-200 dark:border-emerald-800 bg-emerald-50 dark:bg-emerald-950/40 p-3 text-emerald-900 dark:text-emerald-200 font-bold">
                                                        <RichContentRenderer content={answer.correctAnswer} />
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                );
                            })}

                            {(!selectedRespondent.answers || selectedRespondent.answers.length === 0) && (
                                <div className="text-center py-12 text-sm text-slate-400 dark:text-slate-500">
                                    Rincian jawaban tidak tersedia.
                                </div>
                            )}
                        </div>

                        {/* Modal Footer Navigation */}
                        <div className="px-6 py-3 border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex items-center justify-between shrink-0">
                            <button
                                onClick={goPrevious}
                                disabled={currentIndex <= 0}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                            >
                                <ChevronLeft size={15} /> Sebelumnya
                            </button>

                            <span className="text-xs text-slate-400 dark:text-slate-500 font-semibold">
                                {currentIndex + 1} dari {respondents.length}
                            </span>

                            <button
                                onClick={goNext}
                                disabled={currentIndex === respondents.length - 1}
                                className="flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
                            >
                                Selanjutnya <ChevronRight size={15} />
                            </button>
                        </div>

                    </div>
                </div>
            )}

            {/* Lightbox Modal */}
            <ImageLightboxModal
                isOpen={!!lightboxImage}
                src={lightboxImage?.src}
                alt={lightboxImage?.alt}
                onClose={() => setLightboxImage(null)}
            />

        </div>
    );
}