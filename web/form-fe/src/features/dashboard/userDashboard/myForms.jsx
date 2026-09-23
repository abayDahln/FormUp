import { useState, useEffect, useRef, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import ConfirmModal from '../../../components/ui/ConfirmModal';
import AIFormBuilderModal from '../../../components/ui/AIFormBuilderModal';

// Import Material Web Components
import '@material/web/checkbox/checkbox.js';
import '@material/web/button/outlined-button.js';
import '@material/web/button/filled-button.js';
import '@material/web/icon/icon.js';

import {
    Plus, MoreVertical, MessageSquare, Calendar,
    Edit3, Eye, Trash2, FileText,
    ChevronLeft, ChevronRight, ChevronDown, Copy, Sparkles, Loader2, CheckSquare
} from 'lucide-react';
import { getMyForms, deleteForm, clearSession, assetUrl, createForm, bulkDeleteForms, getQuestions, saveQuestions } from '../../../services/apiService';
import useDebounce from '../../../hooks/useDebounce';

const ITEMS_PER_PAGE = 8; // Disesuaikan untuk grid 4 kolom

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
    const createMenuRef = useRef(null);

    const [showCreateMenu, setShowCreateMenu] = useState(false);

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

    // AI Form Builder
    const [aiFormBuilderOpen, setAiFormBuilderOpen] = useState(false);

    // Duplicate form state
    const [duplicatingId, setDuplicatingId] = useState(null);

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
            if (createMenuRef.current && !createMenuRef.current.contains(e.target)) {
                setShowCreateMenu(false);
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

    const publishedForms = myForms.filter(f => f.status?.toLowerCase() === 'published');
    const draftForms = myForms.filter(f => f.status?.toLowerCase() === 'draft');

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

    // Reset ke halaman 1 jika pencarian atau tab berubah
    useEffect(() => {
        setCurrentPage(1);
    }, [activeTab, debouncedSearch]);

    const totalPages = Math.max(1, Math.ceil(filteredForms.length / ITEMS_PER_PAGE));
    const pagedForms = useMemo(() => {
        const start = (currentPage - 1) * ITEMS_PER_PAGE;
        return filteredForms.slice(start, start + ITEMS_PER_PAGE);
    }, [filteredForms, currentPage]);

    // ==========================================
    // LOGIKA DIATAS PENGGUNAAN MATERIAL CHECKBOX
    // ==========================================
    const isAllSelected = pagedForms.length > 0 && selectedIds.size === pagedForms.length;
    const isSomeSelected = selectedIds.size > 0 && selectedIds.size < pagedForms.length;

    const toggleSelect = (id) => {
        setSelectedIds(prev => {
            const next = new Set(prev);
            if (next.has(id)) next.delete(id); else next.add(id);
            return next;
        });
    };

    const toggleSelectAll = () => {
        if (isAllSelected) {
            setSelectedIds(new Set());
        } else {
            setSelectedIds(new Set(pagedForms.map(f => f.id)));
        }
    };

    const handleMainSelectToggle = () => {
        if (!selectMode) {
            setSelectMode(true);
        } else {
            toggleSelectAll();
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

    const handleDuplicateForm = async (formId, formTitle) => {
        setOpenMenuId(null);
        setDuplicatingId(formId);
        try {
            const qRes = await getQuestions(formId);
            const createRes = await createForm({ title: `Salinan dari ${formTitle || 'Formulir'}`, description: '' });
            if (!createRes.ok || !createRes.data?.id) {
                setDuplicatingId(null);
                return;
            }
            const newId = createRes.data.id;
            if (qRes.ok && Array.isArray(qRes.data) && qRes.data.length > 0) {
                const payload = qRes.data.map((q, i) => ({
                    id: undefined,
                    typeId: q.typeId,
                    question: q.question || '',
                    questionFormat: q.questionFormat || 'text',
                    questionOrder: i + 1,
                    isRequired: !!q.isRequired,
                    correctAnswer: q.correctAnswer || null,
                    points: q.points || null,
                    questionImage: null,
                    questionAudio: null,
                    options: (q.options || []).map(o => ({ optionText: o.optionText || '', isCorrect: !!o.isCorrect })),
                }));
                await saveQuestions(newId, payload);
            }
            navigate(`/forms/${newId}/edit`);
        } catch (err) {
            console.error('Duplicate form error:', err);
        } finally {
            setDuplicatingId(null);
        }
    };

    const tabs = [
        { id: 'All', label: `Semua (${myForms.length})` },
        { id: 'Published', label: `Dipublikasikan (${publishedForms.length})` },
        { id: 'Draft', label: `Draf (${draftForms.length})` },
    ];

    return (
    <div className="flex h-screen w-full bg-[#F8FAFC] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 overflow-hidden transition-colors">
        
        <Sidebar />

        <div className="flex-1 flex flex-col h-full min-w-0 overflow-y-auto">
            <main className="flex-1 w-full p-6 sm:p-8 lg:p-10 space-y-6">

                <Topbar 
                    searchQuery={searchQuery} 
                    onSearchChange={setSearchQuery} 
                    placeholder="Cari formulir Anda..." 
                />

                {/* Header, Tombol Buat Baru, & Filter Tabs */}
                <div className="flex flex-col gap-5">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                        <div>
                            <h1 className="text-2xl sm:text-3xl font-extrabold text-slate-900 dark:text-white tracking-tight">Formulir Saya</h1>
                            <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 font-medium mt-1">
                                Kelola dan pantau seluruh koleksi formulir Anda.
                            </p>
                        </div>

                        {/* Action: Buat Form Baru */}
                        <div className="relative" ref={createMenuRef}>
                            <button
                                type="button"
                                onClick={(e) => { e.stopPropagation(); setShowCreateMenu(!showCreateMenu); }}
                                className="flex items-center gap-2.5 px-5 py-2.5 rounded-2xl bg-[#00897B] hover:bg-[#00796B] text-white text-xs sm:text-sm font-bold transition-all shadow-xs hover:shadow-md active:scale-95 cursor-pointer"
                            >
                                <Plus size={18} /> 
                                <span>Buat Formulir Baru</span>
                                <ChevronDown size={16} className={`transition-transform duration-200 ${showCreateMenu ? 'rotate-180' : ''}`} />
                            </button>

                            {showCreateMenu && (
                                <div className="absolute right-0 top-full mt-2 w-64 bg-white dark:bg-slate-900 rounded-2xl shadow-xl border border-slate-200 dark:border-slate-800 overflow-hidden z-30 p-1.5 animate-in fade-in slide-in-from-top-2 duration-200">
                                    <button
                                        type="button"
                                        onClick={() => { setShowCreateMenu(false); handleCreateNewForm(); }}
                                        disabled={creatingForm}
                                        className="w-full p-3 rounded-xl text-left hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer disabled:opacity-60"
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className="w-9 h-9 rounded-xl bg-slate-100 dark:bg-slate-800 flex items-center justify-center text-slate-600 dark:text-slate-300 shrink-0">
                                                <Edit3 size={18} />
                                            </div>
                                            <div>
                                                <p className="text-xs font-bold text-slate-900 dark:text-white">
                                                    {creatingForm ? 'Menyiapkan...' : 'Buat Manual'}
                                                </p>
                                                <p className="text-[10px] text-slate-400 dark:text-slate-500 font-medium mt-0.5">
                                                    Susun soal dari awal
                                                </p>
                                            </div>
                                        </div>
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => { setShowCreateMenu(false); setAiFormBuilderOpen(true); }}
                                        className="w-full p-3 rounded-xl text-left hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className="w-9 h-9 rounded-xl bg-teal-50 dark:bg-teal-950/50 flex items-center justify-center text-teal-600 dark:text-teal-400 border border-teal-100 dark:border-teal-900/50 shrink-0">
                                                <Sparkles size={18} />
                                            </div>
                                            <div>
                                                <p className="text-xs font-bold text-slate-900 dark:text-white">
                                                    Buat dengan AI
                                                </p>
                                                <p className="text-[10px] text-slate-400 dark:text-slate-500 font-medium mt-0.5">
                                                    Deskripsikan, AI susun soal
                                                </p>
                                            </div>
                                        </div>
                                    </button>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Filter Tabs & Selection Mode */}
                    <div className="flex flex-wrap items-center justify-between gap-3">
    {/* Tab Navigasi */}
    <div className="inline-flex items-center bg-slate-100 dark:bg-slate-800/80 p-1 rounded-xl border border-slate-200/80 dark:border-slate-700/50 gap-1">
        {tabs.map((tab) => (
            <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`px-3.5 py-1.5 rounded-lg text-xs font-semibold transition-all cursor-pointer whitespace-nowrap ${
                    activeTab === tab.id
                        ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-xs'
                        : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200'
                }`}
            >
                {tab.label}
            </button>
        ))}
    </div>

    {/* Kontrol Seleksi Massal dengan Checkbox & Tombol X */}
    <div className="flex items-center gap-2">
    {selectMode ? (
        <div className="inline-flex items-center bg-slate-200/60 dark:bg-slate-800/80 p-1 rounded-xl border border-slate-200/80 dark:border-slate-700/60 gap-1.5">
            {/* Checkbox + Label Pilih Semua */}
            <button
                type="button"
                onClick={toggleSelectAll}
                className="flex items-center gap-2.5 px-3 py-1.5 rounded-lg text-xs font-bold text-teal-600 dark:text-teal-400 hover:bg-white/50 dark:hover:bg-slate-700/50 transition-all cursor-pointer whitespace-nowrap"
            >
                <div className={`w-4 h-4 rounded border flex items-center justify-center transition-all ${
                    selectedIds.size === pagedForms.length && pagedForms.length > 0
                        ? 'bg-teal-500 border-teal-500 text-slate-950'
                        : 'border-slate-400 dark:border-slate-500 bg-transparent'
                }`}>
                    {selectedIds.size === pagedForms.length && pagedForms.length > 0 && (
                        <svg className="w-3 h-3 stroke-[3]" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                            <polyline points="20 6 9 17 4 12" />
                        </svg>
                    )}
                </div>
                <span>
                    {selectedIds.size === pagedForms.length && pagedForms.length > 0
                        ? 'Batal Pilih Semua'
                        : 'Pilih Semua'}
                </span>
            </button>

            {/* Separator Tipis */}
            <div className="h-4 w-[1px] bg-slate-300 dark:bg-slate-700" />

            {/* Tombol Batal Berupa Ikon Silang (X) */}
            <button
                type="button"
                onClick={() => {
                    setSelectMode(false);
                    setSelectedIds(new Set());
                }}
                title="Tutup Mode Pilih"
                className="p-1.5 rounded-lg text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-white/60 dark:hover:bg-slate-700/50 transition-all cursor-pointer"
            >
                <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <line x1="18" y1="6" x2="6" y2="18" />
                    <line x1="6" y1="6" x2="18" y2="18" />
                </svg>
            </button>
        </div>
    ) : (
        /* Tombol Masuk Mode Pilih - Disamakan Style & Ukurannya dengan Tab Navigasi */
        <div className="inline-flex items-center bg-slate-200/60 dark:bg-slate-800/80 p-1 rounded-xl border border-slate-200/80 dark:border-slate-700/60">
            <button
                type="button"
                onClick={() => setSelectMode(true)}
                className="flex items-center gap-2.5 px-4 py-1.5 rounded-lg text-xs font-bold text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white hover:bg-white/50 dark:hover:bg-slate-700/50 transition-all cursor-pointer whitespace-nowrap"
            >
                <div className="w-4 h-4 rounded border-2 border-slate-400 dark:border-slate-500" />
                <span>Hapus Form</span>
            </button>
        </div>
    )}
</div>
</div>
                </div>

                {selectMode && selectedIds.size > 0 && (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 animate-in fade-in slide-in-from-bottom-3 duration-200">
        <div className="bg-slate-900 border border-slate-800 text-white px-4 py-2.5 rounded-2xl shadow-xl flex items-center gap-4">
            
            {/* Status / Count */}
            <span className="text-xs font-medium text-slate-300">
                <strong className="text-white font-bold">{selectedIds.size}</strong> item dipilih
            </span>

            {/* Separator */}
            <div className="h-4 w-[1px] bg-slate-800" />

            {/* Actions */}
            <div className="flex items-center gap-2">
                {/* <button
                    type="button"
                    onClick={() => {
                        setSelectMode(false);
                        setSelectedIds(new Set());
                    }}
                    className="text-xs font-medium text-slate-400 hover:text-white px-2.5 py-1.5 rounded-lg hover:bg-slate-800 transition-colors cursor-pointer"
                >
                    Batal
                </button> */}

                <button
                    type="button"
                    onClick={triggerBulkDelete}
                    disabled={actionLoading === 'bulk'}
                    className="flex items-center gap-1.5 bg-rose-600 hover:bg-rose-500 text-white text-xs font-semibold px-3.5 py-1.5 rounded-xl transition-colors active:scale-95 disabled:opacity-60 cursor-pointer"
                >
                    <Trash2 size={14} />
                    <span>Hapus</span>
                </button>
            </div>

        </div>
    </div>
)}

                {/* Cards Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 sm:gap-5" ref={menuRef}>
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
                                    className={`bg-white dark:bg-slate-900 border rounded-2xl overflow-hidden shadow-2xs hover:shadow-lg hover:-translate-y-1 transition-all duration-200 flex flex-col justify-between group ${
                                        isActing ? 'opacity-60 pointer-events-none' : ''
                                    } ${selectMode ? 'cursor-pointer' : ''} ${
                                        isSelected 
                                            ? 'border-[#00897B] ring-2 ring-[#00897B]/30' 
                                            : 'border-slate-200/80 dark:border-slate-800'
                                    }`}
                                >
                                    {/* Banner Header Card */}
                                    <div className="h-28 relative p-3 flex items-start justify-between overflow-hidden">
                                        {form.bannerImage ? (
                                            <img 
                                                src={assetUrl(form.bannerImage)} 
                                                alt={form.title} 
                                                className="absolute inset-0 w-full h-full object-cover group-hover:scale-105 transition-transform duration-300 ease-out" 
                                            />
                                        ) : (
                                            <div className="absolute inset-0 bg-gradient-to-br from-[#005B52] to-[#00897B] flex items-center justify-center overflow-hidden">
                                                <div className="absolute -right-6 -top-6 w-24 h-24 bg-white/10 rounded-full blur-lg pointer-events-none" />
                                                <FileText size={36} className="text-white/25 group-hover:scale-105 group-hover:text-white/35 transition-all duration-200 relative z-0" />
                                            </div>
                                        )}

                                        {/* Material Design Checkbox Overlay on Cards */}
                                        {selectMode && (
                                            <div 
                                                className="absolute top-3 left-3 z-20 flex items-center justify-center" 
                                                onClick={e => { e.stopPropagation(); toggleSelect(form.id); }}
                                            >
                                                <label className="relative flex items-center justify-center p-1.5 rounded-full hover:bg-black/10 dark:hover:bg-white/10 transition-colors cursor-pointer">
                                                    <input
                                                        type="checkbox"
                                                        checked={isSelected}
                                                        onChange={() => {}}
                                                        className="peer appearance-none w-5 h-5 rounded-[5px] border-2 border-white/90 bg-slate-900/40 backdrop-blur-xs checked:bg-[#00897B] checked:border-[#00897B] transition-all cursor-pointer focus:outline-none shadow-sm"
                                                    />
                                                    <svg
                                                        className="absolute w-3.5 h-3.5 text-white opacity-0 peer-checked:opacity-100 transition-opacity duration-150 pointer-events-none stroke-current stroke-[3]"
                                                        viewBox="0 0 24 24"
                                                        fill="none"
                                                    >
                                                        <polyline points="20 6 9 17 4 12" />
                                                    </svg>
                                                </label>
                                            </div>
                                        )}

                                        {/* Status Badge */}
                                        <span className={`relative z-10 px-2.5 py-1 rounded-full text-[10px] font-extrabold tracking-wide flex items-center gap-1.5 backdrop-blur-md shadow-2xs ${selectMode ? 'ml-8' : ''} ${
                                            isPublished 
                                                ? 'bg-emerald-500/90 text-white border border-emerald-400/30' 
                                                : 'bg-slate-900/75 text-slate-200 border border-slate-700/50'
                                        }`}>
                                            <span className={`w-1.5 h-1.5 rounded-full ${isPublished ? 'bg-white animate-pulse' : 'bg-slate-400'}`} />
                                            {isPublished ? 'Dipublikasikan' : 'Draf'}
                                        </span>

                                        {/* Menu Action Dot */}
                                        <div className="relative z-10 ml-auto">
                                            <button
                                                onClick={(e) => { e.stopPropagation(); setOpenMenuId(openMenuId === form.id ? null : form.id); }}
                                                className="p-1.5 bg-white/90 dark:bg-slate-800/90 backdrop-blur-md rounded-lg text-slate-700 dark:text-slate-200 hover:bg-white dark:hover:bg-slate-700 shadow-2xs transition-all cursor-pointer"
                                            >
                                                <MoreVertical className="w-3.5 h-3.5" />
                                            </button>

                                            {openMenuId === form.id && (
                                                <div className="absolute right-0 top-8 w-40 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200/80 dark:border-slate-700 z-50 p-1 overflow-hidden animate-in fade-in zoom-in-95 duration-150">
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); handleDuplicateForm(form.id, form.title); }}
                                                        disabled={duplicatingId === form.id}
                                                        className="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-xs font-bold text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/50 transition-colors cursor-pointer disabled:opacity-60"
                                                    >
                                                        {duplicatingId === form.id ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <Copy className="w-3.5 h-3.5" />}
                                                        {duplicatingId === form.id ? 'Menduplikasi...' : 'Duplikat Form'}
                                                    </button>
                                                    <button
                                                        onClick={(e) => { e.stopPropagation(); triggerDelete(form.id); }}
                                                        className="w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-xs font-bold text-rose-600 dark:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/50 transition-colors cursor-pointer"
                                                    >
                                                        <Trash2 className="w-3.5 h-3.5" /> Hapus
                                                    </button>
                                                </div>
                                            )}
                                        </div>
                                    </div>

                                    {/* Card Body */}
                                    <div className="p-4 flex flex-col flex-1 space-y-3">
                                        <div>
                                            <h3 className="text-sm font-extrabold text-slate-900 dark:text-white leading-snug line-clamp-1 group-hover:text-[#00897B] dark:group-hover:text-teal-400 transition-colors">
                                                {form.title || 'Formulir Tanpa Judul'}
                                            </h3>
                                        </div>

                                        <div className="flex items-center gap-3 text-[11px] font-semibold text-slate-400 dark:text-slate-500">
                                            <span className="flex items-center gap-1">
                                                <MessageSquare className="w-3.5 h-3.5 text-slate-400" /> {responseCount} Respons
                                            </span>
                                            <span className="flex items-center gap-1">
                                                <Calendar className="w-3.5 h-3.5 text-slate-400" /> {createdDate}
                                            </span>
                                        </div>

                                        {/* Action Buttons */}
                                        <div className="mt-auto flex gap-2 pt-3 border-t border-slate-100 dark:border-slate-800/80">
                                            <button
                                                onClick={(e) => { e.stopPropagation(); navigate(`/forms/${form.id}/edit`); }}
                                                className="flex-1 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800/80 dark:hover:bg-slate-700/80 border border-slate-200/80 dark:border-slate-700/80 text-slate-700 dark:text-slate-200 font-bold py-2 rounded-xl flex items-center justify-center gap-1.5 text-xs transition-all cursor-pointer active:scale-95"
                                            >
                                                <Edit3 className="w-3.5 h-3.5" /> Edit
                                            </button>
                                            <button
                                                onClick={(e) => { e.stopPropagation(); navigate(`/forms/${form.id}/responses`); }}
                                                className="flex-1 bg-slate-50 hover:bg-slate-100 dark:bg-slate-800/80 dark:hover:bg-slate-700/80 border border-slate-200/80 dark:border-slate-700/80 text-slate-700 dark:text-slate-200 font-bold py-2 rounded-xl flex items-center justify-center gap-1.5 text-xs transition-all cursor-pointer active:scale-95"
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

                {/* Pagination */}
                {totalPages > 1 && (
                    <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-4 border-t border-slate-200/80 dark:border-slate-800">
                        <p className="text-xs text-slate-500 dark:text-slate-400 font-medium">
                            Menampilkan halaman <span className="font-bold text-slate-900 dark:text-white">{currentPage}</span> dari <span className="font-bold text-slate-900 dark:text-white">{totalPages}</span> (total {filteredForms.length} formulir)
                        </p>
                        <div className="flex items-center gap-1.5">
                            <button
                                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
                                disabled={currentPage === 1}
                                className="p-1.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed transition-all cursor-pointer shadow-2xs"
                                title="Halaman Sebelumnya"
                            >
                                <ChevronLeft size={16} />
                            </button>
                            {Array.from({ length: totalPages }, (_, i) => i + 1).map(pageNum => (
                                <button
                                    key={pageNum}
                                    onClick={() => setCurrentPage(pageNum)}
                                    className={`w-7 h-7 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                                        currentPage === pageNum
                                            ? 'bg-[#00897B] text-white shadow-2xs'
                                            : 'border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800'
                                    }`}
                                >
                                    {pageNum}
                                </button>
                            ))}
                            <button
                                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
                                disabled={currentPage === totalPages}
                                className="p-1.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800 disabled:opacity-40 disabled:cursor-not-allowed transition-all cursor-pointer shadow-2xs"
                                title="Halaman Selanjutnya"
                            >
                                <ChevronRight size={16} />
                            </button>
                        </div>
                    </div>
                )}

            </main>
        </div>

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

        {/* AI Form Builder Modal */}
        <AIFormBuilderModal
            isOpen={aiFormBuilderOpen}
            onClose={() => setAiFormBuilderOpen(false)}
            onFormCreated={(newId) => navigate(`/forms/${newId}/edit`)}
        />
    </div>
);
};

export default MyForms;