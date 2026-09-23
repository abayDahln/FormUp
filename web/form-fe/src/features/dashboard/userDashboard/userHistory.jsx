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
    const [searchQuery, setSearchQuery] = useState('');

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
        return new Date(dateStr).toLocaleDateString('id-ID', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    };

    const getStatusBadge = (status) => {
        const s = status?.toLowerCase() ?? '';
        if (s === 'submitted' || s === 'reviewed' || s === 'accepted' || s === 'new') {
            return 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/60 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800';
        }
        if (s === 'published') {
            return 'bg-teal-50 text-[#00897B] dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800';
        }
        if (s === 'draft') {
            return 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400 border border-slate-200 dark:border-slate-700';
        }
        return 'bg-amber-50 text-amber-600 dark:bg-amber-950/60 dark:text-amber-400 border border-amber-200 dark:border-amber-800';
    };

    const getStatusLabel = (status) => {
        const s = status?.toLowerCase() ?? '';
        if (s === 'submitted') return 'Terkirim';
        if (s === 'reviewed') return 'Ditinjau';
        if (s === 'accepted') return 'Diterima';
        if (s === 'rejected') return 'Ditolak';
        if (s === 'published') return 'Dipublikasikan';
        if (s === 'draft') return 'Draf';
        if (s === 'new') return 'Baru';
        return status || '—';
    };

    // Filter list based on search
    const filteredSubmitted = submittedForms.filter(item => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (
            (item.formTitle && item.formTitle.toLowerCase().includes(q)) ||
            (item.status && item.status.toLowerCase().includes(q))
        );
    });

    const filteredCreated = createdForms.filter(item => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (
            (item.title && item.title.toLowerCase().includes(q)) ||
            (item.status && item.status.toLowerCase().includes(q))
        );
    });

    return (
    <div className="flex min-h-screen w-full bg-[#F8FAFC] dark:bg-slate-950 font-sans text-slate-800 dark:text-slate-100 transition-colors">
  <Sidebar />

  <div className="flex-1 flex flex-col min-w-0 min-h-screen overflow-y-auto">
    <main className="p-4 sm:p-6 lg:p-8 space-y-6 w-full flex-1 max-w-7xl mx-auto">

      <Topbar 
        searchQuery={searchQuery} 
        onSearchChange={setSearchQuery} 
        placeholder="Cari riwayat formulir..." 
      />

      {/* Header Section */}
      <div>
        <h1 className="text-xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">Riwayat & Aktivitas</h1>
        <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 mt-1">
          Pantau pengiriman formulir Anda dan kelola riwayat aktivitas akun.
        </p>
      </div>

      {/* Vibrant Dashboard Stat Cards (Selalu 2 Kolom per baris di Mobile) */}
      <div className="grid grid-cols-2 gap-3 sm:gap-6 w-full">
        {/* Card 1: Formulir Terkirim */}
        <div className="relative overflow-hidden bg-gradient-to-br from-teal-500 to-teal-700 dark:from-teal-600 dark:to-teal-900 rounded-2xl p-3.5 sm:p-6 text-white shadow-lg shadow-teal-500/15 flex items-center justify-between">
          <div className="relative z-10 space-y-0.5 sm:space-y-1">
            <p className="text-[10px] sm:text-xs font-semibold text-teal-100 uppercase tracking-wider">Formulir Terkirim</p>
            <h3 className="text-2xl sm:text-4xl font-black text-white">{submittedForms.length}</h3>
          </div>
          <div className="relative z-10 p-2 sm:p-3 bg-white/10 backdrop-blur-md rounded-xl sm:rounded-2xl border border-white/20 text-white shrink-0">
            <FileText className="w-5 h-5 sm:w-7 sm:h-7" />
          </div>
          {/* Decorative Background Circles */}
          <div className="absolute -right-6 -bottom-6 w-24 h-24 sm:w-32 sm:h-32 bg-white/10 rounded-full blur-xl pointer-events-none" />
        </div>

        {/* Card 2: Formulir Dibuat */}
        <div className="relative overflow-hidden bg-gradient-to-br from-indigo-500 to-indigo-700 dark:from-indigo-600 dark:to-indigo-900 rounded-2xl p-3.5 sm:p-6 text-white shadow-lg shadow-indigo-500/15 flex items-center justify-between">
          <div className="relative z-10 space-y-0.5 sm:space-y-1">
            <p className="text-[10px] sm:text-xs font-semibold text-indigo-100 uppercase tracking-wider">Formulir Dibuat</p>
            <h3 className="text-2xl sm:text-4xl font-black text-white">{createdForms.length}</h3>
          </div>
          <div className="relative z-10 p-2 sm:p-3 bg-white/10 backdrop-blur-md rounded-xl sm:rounded-2xl border border-white/20 text-white shrink-0">
            <Award className="w-5 h-5 sm:w-7 sm:h-7" />
          </div>
          {/* Decorative Background Circles */}
          <div className="absolute -right-6 -bottom-6 w-24 h-24 sm:w-32 sm:h-32 bg-white/10 rounded-full blur-xl pointer-events-none" />
        </div>
      </div>

      {/* Main Content Card Container */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden w-full">

        {/* Tab Navigation */}
        <div className="flex border-b border-slate-200 dark:border-slate-800 px-4 sm:px-6 pt-4 gap-2 sm:gap-4 bg-slate-50/50 dark:bg-slate-900/50">
          <button
            onClick={() => setActiveTab('submitted')}
            className={`pb-3.5 px-2 sm:px-3 text-xs sm:text-sm font-bold border-b-2 transition-all cursor-pointer flex items-center gap-1.5 sm:gap-2 ${
              activeTab === 'submitted'
                ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400'
                : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            Formulir Terkirim
            <span className={`px-2 py-0.5 text-[10px] sm:text-[11px] rounded-full font-bold ${
              activeTab === 'submitted' 
                ? 'bg-teal-50 dark:bg-teal-950 text-[#00897B] dark:text-teal-400' 
                : 'bg-slate-200/60 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
            }`}>
              {submittedForms.length}
            </span>
          </button>

          <button
            onClick={() => setActiveTab('created')}
            className={`pb-3.5 px-2 sm:px-3 text-xs sm:text-sm font-bold border-b-2 transition-all cursor-pointer flex items-center gap-1.5 sm:gap-2 ${
              activeTab === 'created'
                ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400'
                : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            Formulir Dibuat
            <span className={`px-2 py-0.5 text-[10px] sm:text-[11px] rounded-full font-bold ${
              activeTab === 'created' 
                ? 'bg-teal-50 dark:bg-teal-950 text-[#00897B] dark:text-teal-400' 
                : 'bg-slate-200/60 dark:bg-slate-800 text-slate-600 dark:text-slate-400'
            }`}>
              {createdForms.length}
            </span>
          </button>
        </div>

        {loading ? (
          <div className="py-20 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
            Memuat riwayat...
          </div>
        ) : activeTab === 'submitted' ? (
          filteredSubmitted.length === 0 ? (
            <div className="py-20 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
              {searchQuery ? `Tidak ada pengiriman formulir yang cocok dengan "${searchQuery}".` : 'Anda belum pernah mengirimkan formulir.'}
            </div>
          ) : (
            <>
              {/* Mobile List View */}
              <div className="divide-y divide-slate-100 dark:divide-slate-800 sm:hidden">
                {filteredSubmitted.map((item) => (
                  <div key={item.responseId} className="p-4 flex items-center justify-between gap-3 active:bg-slate-50 dark:active:bg-slate-800/50">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="p-2.5 bg-slate-100 dark:bg-slate-800 rounded-xl text-slate-600 dark:text-slate-300 shrink-0">
                        <FileText size={18} />
                      </div>
                      <div className="min-w-0">
                        <p className="font-bold text-slate-900 dark:text-white text-xs truncate">
                          {item.formTitle || '—'}
                        </p>
                        <div className="flex items-center gap-2 mt-1">
                          <span className="text-[10px] text-slate-400 dark:text-slate-500">
                            {formatDate(item.submittedAt)}
                          </span>
                          {item.showScore && item.score != null && (
                            <span className="text-[10px] font-extrabold text-[#00897B] dark:text-teal-400">
                              • Skor: {item.score}%
                            </span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                      <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold ${getStatusBadge(item.status)}`}>
                        {getStatusLabel(item.status)}
                      </span>
                      <button
                        onClick={() => navigate(`/f/${item.formLink}/result/${item.responseId}`)}
                        className="p-2 text-[#00897B] dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/60 rounded-xl transition-colors cursor-pointer"
                        title="Lihat Hasil"
                      >
                        <Eye size={18} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>

              {/* Desktop Table View */}
              <div className="hidden sm:block overflow-x-auto w-full">
                <table className="w-full text-left border-collapse text-sm">
                  <thead>
                    <tr className="bg-slate-50/80 dark:bg-slate-800/40 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                      <th className="py-4 px-6">Judul Formulir</th>
                      <th className="py-4 px-6">Waktu Pengiriman</th>
                      <th className="py-4 px-6">Skor</th>
                      <th className="py-4 px-6">Status</th>
                      <th className="py-4 px-6 text-right">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {filteredSubmitted.map((item) => (
                      <tr key={item.responseId} className="hover:bg-slate-50/80 dark:hover:bg-slate-800/50 transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            <div className="p-2 bg-slate-100 dark:bg-slate-800 rounded-xl text-slate-500 dark:text-slate-400">
                              <FileText size={18} />
                            </div>
                            <span className="font-bold text-slate-900 dark:text-white">{item.formTitle || '—'}</span>
                          </div>
                        </td>
                        <td className="py-4 px-6 text-slate-500 dark:text-slate-400 font-medium">
                          {formatDate(item.submittedAt)}
                        </td>
                        <td className="py-4 px-6">
                          {item.showScore && item.score != null ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-extrabold bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 border border-teal-200/60 dark:border-teal-800/60">
                              <Award size={12} /> {item.score}%
                            </span>
                          ) : (
                            <span className="text-xs text-slate-400 dark:text-slate-500 font-medium">—</span>
                          )}
                        </td>
                        <td className="py-4 px-6">
                          <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${getStatusBadge(item.status)}`}>
                            {getStatusLabel(item.status)}
                          </span>
                        </td>
                        <td className="py-4 px-6 text-right">
                          <button
                            onClick={() => navigate(`/f/${item.formLink}/result/${item.responseId}`)}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold text-[#00897B] dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/60 transition-colors cursor-pointer"
                          >
                            <Eye size={14} /> Lihat Hasil
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          )
        ) : (
          filteredCreated.length === 0 ? (
            <div className="py-20 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
              {searchQuery ? `Tidak ada formulir yang cocok dengan "${searchQuery}".` : 'Belum ada formulir yang dibuat.'}
            </div>
          ) : (
            <>
              {/* Mobile List View */}
              <div className="divide-y divide-slate-100 dark:divide-slate-800 sm:hidden">
                {filteredCreated.map((form) => (
                  <div key={form.id} className="p-4 flex items-center justify-between gap-3 active:bg-slate-50 dark:active:bg-slate-800/50">
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="p-2.5 bg-indigo-50 dark:bg-indigo-950/60 rounded-xl text-indigo-600 dark:text-indigo-400 shrink-0">
                        <FileText size={18} />
                      </div>
                      <div className="min-w-0">
                        <p className="font-bold text-slate-900 dark:text-white text-xs truncate">
                          {form.title || 'Formulir Tanpa Judul'}
                        </p>
                        <div className="flex items-center gap-2 mt-1">
                          <span className="text-[10px] text-slate-400 dark:text-slate-500">
                            {formatDate(form.createdAt)}
                          </span>
                          <span className="text-[10px] font-bold text-slate-600 dark:text-slate-300">
                            • {form.responseCount ?? 0} Respons
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      <button
                        onClick={() => navigate(`/forms/${form.id}/edit`)}
                        className="p-2 text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors cursor-pointer"
                        title="Edit Formulir"
                      >
                        <Edit3 size={16} />
                      </button>
                      <button
                        onClick={() => navigate(`/forms/${form.id}/responses`)}
                        className="p-2 text-[#00897B] dark:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/60 rounded-xl transition-colors cursor-pointer"
                        title="Lihat Respons"
                      >
                        <BarChart2 size={16} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>

              {/* Desktop Table View */}
              <div className="hidden sm:block overflow-x-auto w-full">
                <table className="w-full text-left border-collapse text-sm">
                  <thead>
                    <tr className="bg-slate-50/80 dark:bg-slate-800/40 text-[11px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 border-b border-slate-100 dark:border-slate-800">
                      <th className="py-4 px-6">Judul Formulir</th>
                      <th className="py-4 px-6">Status</th>
                      <th className="py-4 px-6">Dibuat</th>
                      <th className="py-4 px-6">Total Respons</th>
                      <th className="py-4 px-6 text-right">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {filteredCreated.map((form) => (
                      <tr key={form.id} className="hover:bg-slate-50/80 dark:hover:bg-slate-800/50 transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3">
                            <div className="p-2 bg-indigo-50 dark:bg-indigo-950/60 rounded-xl text-indigo-600 dark:text-indigo-400">
                              <FileText size={18} />
                            </div>
                            <span className="font-bold text-slate-900 dark:text-white">{form.title || 'Formulir Tanpa Judul'}</span>
                          </div>
                        </td>
                        <td className="py-4 px-6">
                          <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${getStatusBadge(form.status)}`}>
                            {getStatusLabel(form.status)}
                          </span>
                        </td>
                        <td className="py-4 px-6 text-slate-500 dark:text-slate-400 font-medium">
                          {formatDate(form.createdAt)}
                        </td>
                        <td className="py-4 px-6 font-bold text-slate-800 dark:text-slate-200">
                          {form.responseCount ?? 0}
                        </td>
                        <td className="py-4 px-6 text-right">
                          <div className="flex items-center justify-end gap-1">
                            <button
                              onClick={() => navigate(`/forms/${form.id}/edit`)}
                              className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
                              title="Edit Formulir"
                            >
                              <Edit3 size={16} />
                            </button>
                            <button
                              onClick={() => navigate(`/forms/${form.id}/responses`)}
                              className="p-2 text-slate-400 hover:text-[#00897B] dark:hover:text-teal-400 hover:bg-teal-50 dark:hover:bg-teal-950/60 rounded-lg transition-colors cursor-pointer"
                              title="Lihat Respons"
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
            </>
          )
        )}

      </div>

    </main>
  </div>
</div>
    );
}
