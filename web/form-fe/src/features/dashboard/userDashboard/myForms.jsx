import { useState, useEffect, useRef, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import ConfirmModal from '../../../components/ui/ConfirmModal';
import {
    Plus, MoreVertical, MessageSquare, Calendar,
    Edit3, Eye, Trash2, CheckCircle2, FileText,
    ChevronLeft, ChevronRight, Square, CheckSquare
} from 'lucide-react';
import { getMyForms, deleteForm, clearSession, assetUrl, createForm, bulkDeleteForms } from '../../../services/apiService';
import useDebounce from '../../../hooks/useDebounce';

const ITEMS_PER_PAGE = 7; // 7 form cards + 1 create card = 8 cards on page 1

const MyForms = () => {
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('All');
    const [myForms, setMyForms] = useState([]);
    const [loading, setLoading] = useState(true);
    const [openMenuId, setOpenMenuId] = useState(null);
    const [actionLoading, setActionLoading] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');
    const debouncedSearch = useDebounce(searchQuery, 350);
    const [currentPage, setCurrentPage] = useState(1);
    const [creatingForm, setCreatingForm] = useState(false);
    const menuRef = useRef(null);

    // Multi-select state
    const [selectedIds, setSelectedIds] = useState(new Set());
    const [selectMode, setSelectMode] = useState(false);

    const [confirmModal, setConfirmModal] = useState({
        isOpen: false,
        title: '',
        message: '',
        variant: 'danger',
        confirmText: 'Ya, Hapus',
        formId: null,
        isBulk: false,
    });

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

    const handleCreateNewForm = async () => {
        if (creatingForm) return;
        setCreatingForm(true);
        try {
            const res = await createForm({
                title: 'Formulir Tanpa Judul',
                description: '',
            });
            if (res.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }
            if (res.ok && res.data?.id) {
                navigate(`/forms/${res.data.id}/edit`);
            } else {
                navigate('/create-form');
            }
        } catch (err) {
            console.error('Error creating form:', err);
            navigate('/create-form');
        } finally {
            setCreatingForm(false);
        }
    };

    const toggleSelect = (id) => {
        setSelectedIds(prev => {
            const next = new Set(prev);
            if (next.has(id)) next.delete(id); else next.add(id);
            return next;
        });
    };

    const toggleSelectAll = () => {
        if (selectedIds.size === pagedForms.length) {
            setSelectedIds(new Set());
        } else {
            setSelectedIds(new Set(pagedForms.map(f => f.id)));
        }
    };

    const triggerBulkDelete = () => {
        if (selectedIds.size === 0) return;
        setConfirmModal({
            isOpen: true,
            title: `Hapus ${selectedIds.size} Formulir?`,
            message: `Apakah Anda yakin ingin menghapus ${selectedIds.size} formulir yang dipilih? Tindakan ini tidak dapat dibatalkan.`,
            variant: 'danger',
            confirmText: `Hapus ${selectedIds.size} Formulir`,
            formId: null,
            isBulk: true,
        });
    };

    const triggerDelete = (formId) => {
        setOpenMenuId(null);
        setConfirmModal({
            isOpen: true,
            title: 'Hapus Formulir?',
            message: 'Apakah Anda yakin ingin menghapus formulir ini? Tindakan ini tidak dapat dibatalkan.',
            variant: 'danger',
            confirmText: 'Ya, Hapus',
            formId: formId,
            isBulk: false,
        });
    };

    const executeDelete = async () => {
        if (confirmModal.isBulk) {
            const ids = [...selectedIds];
            setActionLoading('bulk');
            try {
                const result = await bulkDeleteForms(ids);
                if (result.ok) {
                    setMyForms(prev => prev.filter(f => !ids.includes(f.id)));
                    setSelectedIds(new Set());
                    setSelectMode(false);
                }
            } catch (err) {
                console.error('Bulk delete error:', err);
            } finally {
                setActionLoading(null);
                setConfirmModal(prev => ({ ...prev, isOpen: false }));
            }
        } else {
            const formId = confirmModal.formId;
            if (!formId) return;
            setActionLoading(formId);
            try {
                const result = await deleteForm(formId);
                if (result.ok) {
                    setMyForms(prev => prev.filter(f => f.id !== formId));
                    setSelectedIds(prev => { const n = new Set(prev); n.delete(formId); return n; });
                }
            } catch (err) {
                console.error('Delete form error:', err);
            } finally {
                setActionLoading(null);
                setConfirmModal(prev => ({ ...prev, isOpen: false, formId: null }));
            }
        }
    };

    const publishedForms = myForms.filter(f => f.status?.toLowerCase() === 'published');
    const draftForms = myForms.filter(f => f.status?.toLowerCase() === 'draft');
    const totalResponses = myForms.reduce((acc, f) => acc + (f.responseCount ?? 0), 0);

    const filteredForms = useMemo(() => {
        return myForms.filter((form) => {
            const s = form.status?.toLowerCase() ?? 'draft';
            if (activeTab === 'Published' && s !== 'published') return false;
            if (activeTab === 'Draft' && s !== 'draft') return false;

            if (debouncedSearch.trim()) {
                const q = debouncedSearch.toLowerCase();
                return (
                    (form.title && form.title.toLowerCase().includes(q)) ||
                    (form.description && form.description.toLowerCase().includes(q)) ||
                    (form.status && form.status.toLowerCase().includes(q))
                );
            }

            return true;
        });
    }, [myForms, activeTab, debouncedSearch]);

    // Reset to page 1 on search or tab switch
    useEffect(() => {
        setCurrentPage(1);
    }, [activeTab, debouncedSearch]);

    const totalPages = Math.max(1, Math.ceil(filteredForms.length / ITEMS_PER_PAGE));
    const pagedForms = useMemo(() => {
        const start = (currentPage - 1) * ITEMS_PER_PAGE;
        return filteredForms.slice(start, start + ITEMS_PER_PAGE);
    }, [filteredForms, currentPage]);

    const tabs = [
        { id: 'All', label: `Semua (${myForms.length})` },
        { id: 'Published', label: `Dipublikasikan (${publishedForms.length})` },
        { id: 'Draft', label: `Draf (${draftForms.length})` },
    ];

    return (
        <div className="flex h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 overflow-hidden transition-colors">
            
            <Sidebar />

            <div className="flex-1 flex flex-col h-full min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar 
                        searchQuery={searchQuery} 
                        onSearchChange={setSearchQuery} 
                        placeholder="Cari formulir Anda..." 
                    />

                    <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 pt-2">
                        <div>
                            <h1 className="text-2xl sm:text-[28px] font-bold text-slate-900 dark:text-white tracking-tight">Formulir Saya</h1>
                            <p className="text-sm text-slate-500 dark:text-slate-400 font-medium mt-0.5">
                                Kelola dan pantau seluruh koleksi formulir Anda.
                            </p>
                        </div>

                        <div className="flex items-center bg-slate-200/80 dark:bg-slate-800 p-1.5 rounded-full border border-slate-200 dark:border-slate-700 self-start md:self-auto">
                            {tabs.map((tab) => (
                                <button
                                    key={tab.id}
                                    onClick={() => setActiveTab(tab.id)}
                                    className={`px-5 py-2 rounded-full text-xs font-bold transition-all cursor-pointer ${
                                        activeTab === tab.id
                                            ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-white shadow-xs'
                                            : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200'
                                    }`}
                                >
                                    {tab.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        <div className="bg-[#005B52] dark:bg-teal-950/60 rounded-2xl p-6 text-white shadow-sm relative overflow-hidden md:col-span-2 lg:col-span-1 border border-teal-800/40">
                            <div className="relative z-10">
                                <p className="text-teal-200 font-bold text-[11px] uppercase tracking-wider mb-1">Total Respons</p>
                                <h2 className="text-3xl font-extrabold tracking-tight">{totalResponses.toLocaleString('id-ID')}</h2>
                            </div>
                            <div className="absolute -right-6 -bottom-6 w-32 h-32 bg-white/10 rounded-full blur-2xl" />
                        </div>

                        <div className="bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-2xl p-6 shadow-sm md:col-span-2 lg:col-span-1">
                            <p className="text-slate-400 dark:text-slate-500 font-bold text-[11px] uppercase tracking-wider mb-1">Formulir Aktif</p>
                            <h2 className="text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">{publishedForms.length}</h2>
                            <p className="text-[#00897B] dark:text-teal-400 flex items-center text-xs font-bold mt-2">
                                <CheckCircle2 className="w-3.5 h-3.5 mr-1" /> Aktif & menerima respons
                            </p>
                        </div>
                    </div>

                    {/* Bulk-select action bar */}
                    <div className="flex items-center gap-3">
                        <button
                            onClick={() => { setSelectMode(m => !m); setSelectedIds(new Set()); }}
                            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer ${selectMode ? 'bg-[#00897B] text-white border-[#00897B]' : 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-[#00897B] hover:text-[#00897B]'}`}
                        >
                            {selectMode ? <CheckSquare size={13} /> : <Square size={13} />}
                            {selectMode ? 'Batalkan Pilihan' : 'Pilih Formulir'}
                        </button>

                        {selectMode && pagedForms.length > 0 && (
                            <button
                                onClick={toggleSelectAll}
                                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 hover:border-[#00897B] hover:text-[#00897B] transition-all cursor-pointer"
                            >
                                {selectedIds.size === pagedForms.length ? <CheckSquare size={13} /> : <Square size={13} />}
                                {selectedIds.size === pagedForms.length ? 'Batalkan Semua' : 'Pilih Semua'}
                            </button>
                        )}

                        {selectMode && selectedIds.size > 0 && (
                            <button
                                onClick={triggerBulkDelete}
                                disabled={actionLoading === 'bulk'}
                                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold bg-red-600 hover:bg-red-700 text-white border border-red-600 transition-all cursor-pointer disabled:opacity-60"
                            >
                                <Trash2 size={13} />
                                Hapus Terpilih ({selectedIds.size})
                            </button>
                        )}
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4" ref={menuRef}>
                        <div
                            onClick={handleCreateNewForm}
                            className="bg-white dark:bg-slate-900 border-2 border-dashed border-slate-200 dark:border-slate-800 rounded-2xl min-h-[260px] flex flex-col items-center justify-center cursor-pointer hover:border-[#00897B] dark:hover:border-teal-400 transition-colors group shadow-sm p-6 text-center"
                        >
                            <div className="w-12 h-12 bg-teal-50 dark:bg-teal-950/60 rounded-full flex items-center justify-center mb-4 group-hover:scale-110 transition-transform text-[#00897B] dark:text-teal-400">
                                <Plus className="w-6 h-6" />
                            </div>
                            <h3 className="text-slate-900 dark:text-white font-bold text-sm mb-1">
                                {creatingForm ? 'Menyiapkan...' : 'Formulir Baru'}
                            </h3>
                            <p className="text-slate-400 dark:text-slate-500 text-xs font-medium max-w-[170px]">
                                Bangun dari awal atau gunakan templat
                            </p>
                        </div>

                        {loading ? (
                            <div className="col-span-full py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                Memuat formulir...
                            </div>
                        ) : filteredForms.length === 0 ? (
                            <div className="col-span-full py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                                {debouncedSearch ? `Tidak ada formulir yang cocok dengan "${debouncedSearch}".` : 'Belum ada formulir pada tab ini.'}
                            </div>
                        ) : (
                            pagedForms.map((form) => {
                                const status = typeof form.status === 'string' ? form.status : 'draft';
                                const isPublished = status.toLowerCase() === 'published';
                                const responseCount = form.responseCount ?? 0;
                                const isActing = actionLoading === form.id;
                                const createdDate = form.createdAt
                                    ? new Date(form.createdAt).toLocaleDateString('id-ID', { month: 'short', day: 'numeric', year: 'numeric' })
                                    : 'Baru saja';

                                const isSelected = selectedIds.has(form.id);

                                return (
                                    <div
                                        key={form.id}
                                        onClick={() => selectMode && toggleSelect(form.id)}
                                        className={`bg-white dark:bg-slate-900 border rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-all flex flex-col justify-between group ${isActing ? 'opacity-60 pointer-events-none' : ''} ${selectMode ? 'cursor-pointer' : ''} ${isSelected ? 'border-[#00897B] ring-2 ring-[#00897B]/30' : 'border-slate-200/80 dark:border-slate-800'}`}
                                    >
                                        <div className="h-36 bg-slate-100 dark:bg-slate-800/80 relative p-4 flex items-start justify-between border-b border-slate-100 dark:border-slate-800 overflow-hidden">
                                            {form.bannerImage ? (
                                                <img 
                                                    src={assetUrl(form.bannerImage)} 
                                                    alt={form.title} 
                                                    className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" 
                                                />
                                            ) : (
                                                <div className="absolute inset-0 flex items-center justify-center bg-linear-to-br from-teal-50/50 to-blue-50/50 dark:from-slate-800 dark:to-slate-900">
                                                    <FileText size={32} className="text-[#00897B]/30 dark:text-teal-400/30" />
                                                </div>
                                            )}

                                            {/* Select checkbox overlay */}
                                            {selectMode && (
                                                <div className="absolute top-2 left-2 z-20" onClick={e => { e.stopPropagation(); toggleSelect(form.id); }}>
                                                    {isSelected
                                                        ? <CheckSquare size={20} className="text-[#00897B] bg-white rounded" />
                                                        : <Square size={20} className="text-slate-400 bg-white/80 rounded" />
                                                    }
                                                </div>
                                            )}

                                            <span className={`relative z-10 px-2.5 py-1 rounded-full text-[10px] font-extrabold uppercase tracking-wider shadow-xs ${selectMode ? 'ml-6' : ''} ${
                                                isPublished 
                                                    ? 'bg-teal-600 text-white' 
                                                    : 'bg-slate-800/90 text-white backdrop-blur-xs'
                                            }`}>
                                                {isPublished ? 'Dipublikasikan' : 'Draf'}
                                            </span>

                                            <div className="relative z-10 ml-auto">
                                                <button
                                                    onClick={() => setOpenMenuId(openMenuId === form.id ? null : form.id)}
                                                    className="p-1.5 bg-white/90 dark:bg-slate-800/90 backdrop-blur-sm rounded-full text-slate-700 dark:text-slate-200 hover:bg-white dark:hover:bg-slate-700 shadow-sm transition-all cursor-pointer"
                                                >
                                                    <MoreVertical className="w-4 h-4" />
                                                </button>

                                                {/* Dropdown Menu */}
                                                {openMenuId === form.id && (
                                                    <div className="absolute right-0 top-8 w-36 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 z-50 py-1 overflow-hidden">
                                                        <button
                                                            onClick={() => triggerDelete(form.id)}
                                                            className="w-full flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 transition-colors cursor-pointer"
                                                        >
                                                            <Trash2 className="w-3.5 h-3.5" /> Hapus
                                                        </button>
                                                    </div>
                                                )}
                                            </div>
                                        </div>

                                        <div className="p-4 flex flex-col flex-1 space-y-3">
                                            <div>
                                                <h3 className="text-sm font-bold text-slate-900 dark:text-white leading-tight line-clamp-1 group-hover:text-[#00897B] dark:group-hover:text-teal-400 transition-colors">
                                                    {form.title || 'Formulir Tanpa Judul'}
                                                </h3>
                                            </div>
                                            <div className="flex items-center gap-3 text-xs font-medium text-slate-400 dark:text-slate-500">
                                                <span className="flex items-center gap-1">
                                                    <MessageSquare className="w-3.5 h-3.5" /> {responseCount} Respons
                                                </span>
                                                <span className="flex items-center gap-1">
                                                    <Calendar className="w-3.5 h-3.5" /> {createdDate}
                                                </span>
                                            </div>
                                            <div className="mt-auto flex gap-2 pt-2 border-t border-slate-100 dark:border-slate-800">
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/edit`)}
                                                    className="flex-1 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700/80 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 font-bold py-1.5 rounded-xl flex items-center justify-center gap-1.5 text-xs transition-colors cursor-pointer"
                                                >
                                                    <Edit3 className="w-3.5 h-3.5" /> Edit
                                                </button>
                                                <button
                                                    onClick={() => navigate(`/forms/${form.id}/responses`)}
                                                    className="flex-1 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700/80 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 font-bold py-1.5 rounded-xl flex items-center justify-center gap-1.5 text-xs transition-colors cursor-pointer"
                                                >
                                                    <Eye className="w-3.5 h-3.5" /> Respons
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })
                        )}
                    </div>

                    {/* Pagination Controls */}
                    {totalPages > 1 && (
                        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t border-slate-200/80 dark:border-slate-800">
                            <p className="text-xs text-slate-500 dark:text-slate-400 font-medium">
                                Menampilkan halaman <span className="font-bold text-slate-900 dark:text-white">{currentPage}</span> dari <span className="font-bold text-slate-900 dark:text-white">{totalPages}</span> (total {filteredForms.length} formulir)
                            </p>
                            <div className="flex items-center gap-1.5">
                                <button
                                    onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                                    disabled={currentPage === 1}
                                    className="p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed transition-all cursor-pointer"
                                    title="Halaman Sebelumnya"
                                >
                                    <ChevronLeft size={16} />
                                </button>
                                {Array.from({ length: totalPages }, (_, i) => i + 1).map(pageNum => (
                                    <button
                                        key={pageNum}
                                        onClick={() => setCurrentPage(pageNum)}
                                        className={`w-8 h-8 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                                            currentPage === pageNum
                                                ? 'bg-[#00897B] text-white shadow-xs'
                                                : 'border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800'
                                        }`}
                                    >
                                        {pageNum}
                                    </button>
                                ))}
                                <button
                                    onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                                    disabled={currentPage === totalPages}
                                    className="p-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed transition-all cursor-pointer"
                                    title="Halaman Selanjutnya"
                                >
                                    <ChevronRight size={16} />
                                </button>
                            </div>
                        </div>
                    )}

                </main>
            </div>

            {/* 5. Render Komponen ConfirmModal di sini */}
            <ConfirmModal 
                isOpen={confirmModal.isOpen}
                onClose={() => setConfirmModal(prev => ({ ...prev, isOpen: false }))}
                onConfirm={executeDelete}
                title={confirmModal.title}
                message={confirmModal.message}
                variant={confirmModal.variant}
                confirmText={confirmModal.confirmText}
                isLoading={actionLoading !== null}
            />
        </div>
    );
};

export default MyForms;