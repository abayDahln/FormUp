import { useState, useEffect, useCallback, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import {
    Save, Plus, Trash2, ChevronUp, ChevronDown,
    Globe, Lock, ArrowLeft, Upload, FileUp, Image, Music, Download,
    Code, Calculator, Eye, EyeOff, X, Sparkles,
    Copy, Undo2, Redo2, FileDown, Wand2, ToggleLeft, ToggleRight,
    ShieldAlert, Palette, CheckSquare, MoreHorizontal, ChevronDown as ChevDown
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import ConfirmModal from '../../components/ui/ConfirmModal';
import {
    getFormById, getQuestions, saveQuestions, updateForm,
    togglePublishForm, updateFormSettings, getFormShare,
    uploadFormBanner, clearSession, assetUrl,
    deleteQuestion, importQuestions, uploadQuestionImage, uploadQuestionAudio,
    templateDownloadUrl, createForm
} from '../../services/apiService';
import { getGeminiApiKey, AVAILABLE_MODELS } from '../../services/aiService';
import RichContentRenderer from '../../utils/RichContentRenderer';
import BlockQuestionEditor from '../../components/ui/BlockQuestionEditor';
import MathAndCodeModal from '../../components/ui/MathAndCodeModal';
import ImageLightboxModal from '../../components/ui/ImageLightboxModal';
import AIGeneratorModal from '../../components/ui/AIGeneratorModal';
import AIFormBuilderModal from '../../components/ui/AIFormBuilderModal';

const envUrl = import.meta.env.VITE_API_BASE_URL;
const API_BASE_URL = (envUrl !== undefined && envUrl !== '')
    ? envUrl 
    : (import.meta.env.DEV ? '' : 'https://api.formup.my.id');
const FRONTEND_BASE_URL = import.meta.env.VITE_FRONTEND_URL || (typeof window !== 'undefined' ? window.location.origin : 'https://formup.my.id');

const QUESTION_TYPES = [
    { id: 1, label: 'Essay / Short Answer' },
    { id: 2, label: 'Multiple Choice' },
    { id: 3, label: 'Checkbox' },
    { id: 4, label: 'Date Time' },
    { id: 5, label: 'True / False' },
];

const newQuestion = (order) => ({
    _id: `q_new_${Date.now()}_${order}`,
    id: null,
    question: '',
    typeId: 2,
    questionOrder: order,
    isRequired: true,
    isScorable: true,
    points: null,
    correctAnswer: '',
    options: [{ optionText: '', isCorrect: false }, { optionText: '', isCorrect: false }],
    questionImage: null,
    questionAudio: null,
});

const needsOptions = (typeId) => [2, 3].includes(typeId);

export default function FormBuilder() {
    const { id } = useParams();
    const navigate = useNavigate();

    const [form, setForm] = useState(null);
    const [questions, setQuestions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [publishing, setPublishing] = useState(false);
    const [activeTab, setActiveTab] = useState('questions');
    const [shareInfo, setShareInfo] = useState(null);
    const [qrBlobUrl, setQrBlobUrl] = useState(null);
    const [toast, setToast] = useState(null);
    const [importLoading, setImportLoading] = useState(false);
    const [copiedLink, setCopiedLink] = useState(false);
    const [lightboxImage, setLightboxImage] = useState(null);

    // Modal state for Code & KaTeX Math insertion (for Question or Option)
    const [modalOpen, setModalOpen] = useState(false);
    const [modalMode, setModalMode] = useState('math');
    const [modalTarget, setModalTarget] = useState({ type: 'question', qIdx: null, oIdx: null });

    // AI Quiz Generator Modal state
    const [aiModalOpen, setAiModalOpen] = useState(false);

    // AI Form Builder Modal state
    const [aiFormBuilderOpen, setAiFormBuilderOpen] = useState(false);

    // AI Revise per-question inline panel
    const [aiReviseOpenIdx, setAiReviseOpenIdx] = useState(null);
    const [aiReviseInstruction, setAiReviseInstruction] = useState('');
    const [aiRevising, setAiRevising] = useState(false);
    const [aiReviseError, setAiReviseError] = useState('');

    // A-7: Bulk AI revise
    const [bulkReviseMode, setBulkReviseMode] = useState(false);
    const [bulkReviseSelected, setBulkReviseSelected] = useState(new Set());
    const [bulkReviseInstruction, setBulkReviseInstruction] = useState('');
    const [bulkRevising, setBulkRevising] = useState(false);
    const [bulkRevisePreview, setBulkRevisePreview] = useState([]); // [{idx, original, revised}]
    const [bulkRevisePreviewOpen, setBulkRevisePreviewOpen] = useState(false);

    // Live preview toggle per question
    const [previewVisibility, setPreviewVisibility] = useState({});

    // A-2: Actions dropdown menu
    const [actionsMenuOpen, setActionsMenuOpen] = useState(false);
    const actionsMenuRef = useRef(null);

    // BUG-3: ConfirmModal state (replaces window.confirm)
    const [confirmModal, setConfirmModal] = useState({ isOpen: false, title: '', message: '', onConfirm: null, variant: 'danger' });

    // FEAT-11: Dirty state indicator
    const [isDirty, setIsDirty] = useState(false);

    // FEAT-12: Undo/Redo history
    const [history, setHistory] = useState([]);
    const [historyIndex, setHistoryIndex] = useState(-1);
    const historyUpdatingRef = useRef(false);

    // FEAT-14: Autosave
    const [autosaveEnabled, setAutosaveEnabled] = useState(() => {
        try { return localStorage.getItem('formup_autosave_pref') === 'true'; } catch { return false; }
    });
    const autosaveIntervalRef = useRef(null);
    const [autosaveToast, setAutosaveToast] = useState('');
    const [autosaveLastSaved, setAutosaveLastSaved] = useState('');

    // A-6: Floating quick-action button (FAB) on scroll
    const mainScrollRef = useRef(null);
    const [scrolledPastHeader, setScrolledPastHeader] = useState(false);
    const [fabMenuOpen, setFabMenuOpen] = useState(false);

    useEffect(() => {
        const scrollEl = mainScrollRef.current;
        const handleScroll = () => {
            const top = scrollEl ? scrollEl.scrollTop : window.scrollY;
            setScrolledPastHeader(top > 120);
        };
        if (scrollEl) {
            scrollEl.addEventListener('scroll', handleScroll, { passive: true });
        }
        window.addEventListener('scroll', handleScroll, { passive: true });
        return () => {
            if (scrollEl) scrollEl.removeEventListener('scroll', handleScroll);
            window.removeEventListener('scroll', handleScroll);
        };
    }, []);

    // Form settings state
    const [settings, setSettings] = useState({
        formTypeId: 1,
        showScore: false,
        randomizeQuestions: false,
        oneResponse: false,
        requiredLogin: false,
        formToken: '',
        timerDuration: '',
        openFormTime: '',
        closeFormTime: '',
        customFormLink: '',
        isExamMode: false,
        disableCopyPaste: false,
        detectTabSwitch: false,
        autoSubmitOnTabSwitch: false,
        maxTabSwitch: 3,
        themePrimaryColor: '',
        themeBackgroundColor: '',
    });

    // BUG-3: Helper functions for deterministic dirty check (ignoring transient _id timestamps)
    const serializeQuestionsForDirty = useCallback((qList) => {
        if (!Array.isArray(qList)) return '[]';
        return JSON.stringify(qList.map(q => ({
            typeId: parseInt(q.typeId, 10) || 2,
            question: (q.question || '').trim(),
            questionFormat: q.questionFormat || 'text',
            isRequired: !!q.isRequired,
            correctAnswer: (q.correctAnswer || '').trim(),
            points: q.points ?? null,
            questionImage: q.questionImage || null,
            questionAudio: q.questionAudio || null,
            options: (q.options || []).map(o => ({
                optionText: (o.optionText || '').trim(),
                isCorrect: !!o.isCorrect,
            })),
        })));
    }, []);

    const serializeSettingsForDirty = useCallback((s) => {
        if (!s || typeof s !== 'object') return '{}';
        return JSON.stringify({
            formTypeId: parseInt(s.formTypeId, 10) || 1,
            showScore: !!s.showScore,
            randomizeQuestions: !!s.randomizeQuestions,
            oneResponse: !!s.oneResponse,
            requiredLogin: !!s.requiredLogin,
            formToken: (s.formToken || '').trim(),
            timerDuration: s.timerDuration ? String(s.timerDuration) : '',
            openFormTime: s.openFormTime || '',
            closeFormTime: s.closeFormTime || '',
            customFormLink: (s.customFormLink || '').trim(),
            isExamMode: !!s.isExamMode,
            disableCopyPaste: !!s.disableCopyPaste,
            detectTabSwitch: !!s.detectTabSwitch,
            autoSubmitOnTabSwitch: !!s.autoSubmitOnTabSwitch,
            maxTabSwitch: s.maxTabSwitch ? parseInt(s.maxTabSwitch, 10) : 3,
            themePrimaryColor: s.themePrimaryColor || '',
            themeBackgroundColor: s.themeBackgroundColor || '',
        });
    }, []);

    // Single source of truth baseline snapshot for dirty tracking
    const baselineRef = useRef({ questions: '', settings: '' });

    // Mark dirty when questions or settings deviate from baseline snapshot
    useEffect(() => {
        if (loading) return;
        if (!baselineRef.current.questions && !baselineRef.current.settings) return;

        const currentQStr = serializeQuestionsForDirty(questions);
        const currentSStr = serializeSettingsForDirty(settings);

        const qDirty = currentQStr !== baselineRef.current.questions;
        const sDirty = currentSStr !== baselineRef.current.settings;

        setIsDirty(qDirty || sDirty);
    }, [questions, settings, loading, serializeQuestionsForDirty, serializeSettingsForDirty]);

    // FEAT-11: beforeunload guard
    useEffect(() => {
        const handler = (e) => {
            if (isDirty) {
                e.preventDefault();
                e.returnValue = '';
            }
        };
        window.addEventListener('beforeunload', handler);
        return () => window.removeEventListener('beforeunload', handler);
    }, [isDirty]);

    // A-2: Close actions menu on outside click
    useEffect(() => {
        const handler = (e) => {
            if (actionsMenuRef.current && !actionsMenuRef.current.contains(e.target)) {
                setActionsMenuOpen(false);
            }
        };
        document.addEventListener('mousedown', handler);
        return () => document.removeEventListener('mousedown', handler);
    }, []);

    // FEAT-11: document.title indicator
    useEffect(() => {
        if (form?.title) {
            document.title = isDirty ? `• ${form.title} — FormUp` : `${form.title} — FormUp`;
        }
        return () => { document.title = 'FormUp'; };
    }, [isDirty, form?.title]);

    // FEAT-12: Push to history when questions change due to structural ops
    const pushHistory = useCallback((newQuestions) => {
        if (historyUpdatingRef.current) return;
        setHistory(prev => {
            const sliced = prev.slice(0, historyIndex + 1);
            const next = [...sliced, JSON.parse(JSON.stringify(newQuestions))].slice(-20);
            return next;
        });
        setHistoryIndex(prev => Math.min(prev + 1, 19));
    }, [historyIndex]);

    // FEAT-12: Keyboard listener for Ctrl+Z / Ctrl+Y
    useEffect(() => {
        const handler = (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
                e.preventDefault();
                handleUndo();
            } else if ((e.ctrlKey || e.metaKey) && (e.key === 'y' || (e.key === 'z' && e.shiftKey))) {
                e.preventDefault();
                handleRedo();
            }
        };
        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, [history, historyIndex]);

    const handleUndo = () => {
        if (historyIndex <= 0) return;
        const newIdx = historyIndex - 1;
        historyUpdatingRef.current = true;
        setQuestions(JSON.parse(JSON.stringify(history[newIdx])));
        setHistoryIndex(newIdx);
        setTimeout(() => { historyUpdatingRef.current = false; }, 0);
    };

    const handleRedo = () => {
        if (historyIndex >= history.length - 1) return;
        const newIdx = historyIndex + 1;
        historyUpdatingRef.current = true;
        setQuestions(JSON.parse(JSON.stringify(history[newIdx])));
        setHistoryIndex(newIdx);
        setTimeout(() => { historyUpdatingRef.current = false; }, 0);
    };

    // FEAT-14: Autosave interval
    useEffect(() => {
        localStorage.setItem('formup_autosave_pref', String(autosaveEnabled));
        if (autosaveIntervalRef.current) clearInterval(autosaveIntervalRef.current);
        if (autosaveEnabled) {
            autosaveIntervalRef.current = setInterval(async () => {
                if (!isDirty) return;
                const ok = await handleSaveAll();
                if (ok) {
                    const now = new Date();
                    const hhmm = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
                    setAutosaveToast(`Tersimpan otomatis pukul ${hhmm}`);
                    setAutosaveLastSaved(`Tersimpan ${new Date().toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}`);
                    setTimeout(() => setAutosaveToast(''), 2500);
                }
            }, 15000);
        }
        return () => { if (autosaveIntervalRef.current) clearInterval(autosaveIntervalRef.current); };
    }, [autosaveEnabled, isDirty, activeTab]);

    const toLocalDatetimeInput = (dateVal) => {
        if (!dateVal) return '';
        const d = new Date(dateVal);
        if (isNaN(d.getTime())) return '';
        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        const hours = String(d.getHours()).padStart(2, '0');
        const minutes = String(d.getMinutes()).padStart(2, '0');
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    };

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const [formRes, qRes] = await Promise.all([getFormById(id), getQuestions(id)]);

            if (formRes.status === 401) { clearSession(); navigate('/login'); return; }

            let loadedSettings = { ...settings };
            if (formRes.ok && formRes.data) {
                const f = formRes.data;
                setForm(f);
                const s = f.settings || {};
                loadedSettings = {
                    formTypeId: s.formTypeId ?? 1,
                    showScore: s.showScore ?? false,
                    randomizeQuestions: s.randomizeQuestions ?? false,
                    oneResponse: s.oneResponse ?? false,
                    requiredLogin: s.requiredLogin ?? false,
                    formToken: s.formToken ?? '',
                    timerDuration: s.timerDuration ? Math.round(s.timerDuration / 60) : '',
                    openFormTime: toLocalDatetimeInput(s.openFormTime),
                    closeFormTime: toLocalDatetimeInput(s.closeFormTime),
                    customFormLink: f.formLink || '',
                    isExamMode: s.isExamMode ?? false,
                    disableCopyPaste: s.disableCopyPaste ?? false,
                    detectTabSwitch: s.detectTabSwitch ?? false,
                    autoSubmitOnTabSwitch: s.autoSubmitOnTabSwitch ?? false,
                    maxTabSwitch: s.maxTabSwitch ?? 3,
                    themePrimaryColor: s.themePrimaryColor ?? '',
                    themeBackgroundColor: s.themeBackgroundColor ?? '',
                };
                setSettings(loadedSettings);
            }

            let loadedQuestions = [];
            if (qRes.ok && Array.isArray(qRes.data) && qRes.data.length > 0) {
                loadedQuestions = qRes.data.map((q) => {
                    const hasCorrectOption = (q.options || []).some(o => o.isCorrect === true);
                    const hasCorrectAnswer = !!(q.correctAnswer && q.correctAnswer.trim());
                    const isScorable = q.isScorable !== undefined ? q.isScorable : (hasCorrectOption || hasCorrectAnswer);

                    return {
                        ...q,
                        _id: `q_${q.id}`,
                        isScorable: isScorable,
                        options: q.options || [],
                    };
                });
            } else {
                loadedQuestions = [newQuestion(1)];
            }
            setQuestions(loadedQuestions);

            // Establish clean baseline snapshot for new/loaded form
            baselineRef.current = {
                questions: serializeQuestionsForDirty(loadedQuestions),
                settings: serializeSettingsForDirty(loadedSettings),
            };
            setIsDirty(false);
            setLoading(false);
        };
        load();
    }, [id, navigate, serializeQuestionsForDirty, serializeSettingsForDirty]);

    const handleSaveQuestions = async () => {
        setSaving(true);
        // 0 soal diperbolehkan: kirim array kosong -> backend hapus semua soal
        const payloadQuestions = questions.map((q, i) => {
            const scorable = q.isScorable !== false;
            return {
                id: q.id ?? undefined,
                typeId: parseInt(q.typeId),
                question: q.question || '',
                questionFormat: q.questionFormat || 'text',
                questionOrder: i + 1,
                isRequired: !!q.isRequired,
                correctAnswer: scorable ? (q.correctAnswer || null) : null,
                points: scorable && q.points ? parseInt(q.points, 10) : null,
                questionImage: q.questionImage || null,
                questionAudio: q.questionAudio || null,
                options: (q.options || []).map(opt => ({
                    optionText: opt.optionText || '',
                    isCorrect: scorable ? !!opt.isCorrect : false,
                })),
            };
        });

        const res = await saveQuestions(id, payloadQuestions);
        setSaving(false);

        if (res.ok) {
            showToast(payloadQuestions.length === 0 ? 'Semua soal berhasil dihapus!' : 'Soal berhasil disimpan!');
            let freshQuestions = [];
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                if (qRes.data.length === 0) {
                    freshQuestions = [];
                } else {
                    freshQuestions = qRes.data.map((q, i) => ({
                        ...q,
                        _id: questions[i]?._id || `q_${q.id}`,
                        isScorable: questions[i]?.isScorable ?? ((q.options || []).some(o => o.isCorrect === true) || !!(q.correctAnswer && q.correctAnswer.trim())),
                        points: q.points ?? null,
                        options: q.options || [],
                    }));
                }
                setQuestions(freshQuestions);
                // Jika form kehabisan soal, status otomatis kembali draft
                const refreshed = await getFormById(id);
                if (refreshed.ok && refreshed.data) setForm(refreshed.data);
            } else {
                freshQuestions = questions;
            }

            baselineRef.current.questions = serializeQuestionsForDirty(freshQuestions);
            const sDirty = serializeSettingsForDirty(settings) !== baselineRef.current.settings;
            setIsDirty(sDirty);
            return true;
        } else {
            showToast(res.message || 'Gagal menyimpan soal.', 'error');
            return false;
        }
    };

    const handleClearAllQuestions = () => {
        if (questions.length === 0) return;
        setConfirmModal({
            isOpen: true,
            title: 'Hapus Semua Soal?',
            message: 'Hapus semua soal? Perubahan berlaku setelah Simpan.',
            variant: 'danger',
            onConfirm: () => {
                pushHistory(questions);
                setQuestions([]);
                showToast('Semua soal dihapus dari draf. Tekan Simpan untuk menyimpan perubahan.', 'success');
                setConfirmModal(prev => ({ ...prev, isOpen: false }));
            },
        });
    };

    const handleSaveSettings = async () => {
        setSaving(true);
        if (settings.customFormLink && settings.customFormLink !== form.formLink) {
            const formRes = await updateForm(id, {
                title: form.title,
                description: form.description,
                formLink: settings.customFormLink,
            });
            if (!formRes.ok) {
                showToast(formRes.message || 'Gagal memperbarui slug tautan formulir', 'error');
                setSaving(false);
                return false;
            }
            setForm(prev => ({ ...prev, formLink: settings.customFormLink }));
        }

        const parsedTimer = parseInt(settings.timerDuration, 10);
        const timerValue = !isNaN(parsedTimer) && parsedTimer > 0 ? parsedTimer * 60 : null;

        const res = await updateFormSettings(id, {
            formTypeId: parseInt(settings.formTypeId, 10) || 1,
            showScore: !!settings.showScore,
            randomizeQuestions: !!settings.randomizeQuestions,
            oneResponse: !!settings.oneResponse,
            requiredLogin: !!settings.requiredLogin,
            formToken: settings.formToken ? settings.formToken.trim() : null,
            timerDuration: timerValue,
            openFormTime: settings.openFormTime ? new Date(settings.openFormTime).toISOString() : null,
            closeFormTime: settings.closeFormTime ? new Date(settings.closeFormTime).toISOString() : null,
            isExamMode: !!settings.isExamMode,
            disableCopyPaste: !!settings.disableCopyPaste,
            detectTabSwitch: !!settings.detectTabSwitch,
            autoSubmitOnTabSwitch: !!settings.autoSubmitOnTabSwitch,
            maxTabSwitch: settings.maxTabSwitch ? parseInt(settings.maxTabSwitch, 10) : null,
            themePrimaryColor: settings.themePrimaryColor || null,
            themeBackgroundColor: settings.themeBackgroundColor || null,
        });

        setSaving(false);

        if (res.ok) {
            let nextSettings = { ...settings };
            const refreshed = await getFormById(id);
            if (refreshed.ok && refreshed.data) {
                const f = refreshed.data;
                setForm(f);
                const s = f.settings || {};
                nextSettings = {
                    formTypeId: s.formTypeId ?? 1,
                    showScore: s.showScore ?? false,
                    randomizeQuestions: s.randomizeQuestions ?? false,
                    oneResponse: s.oneResponse ?? false,
                    requiredLogin: s.requiredLogin ?? false,
                    formToken: s.formToken ?? '',
                    timerDuration: s.timerDuration ? Math.round(s.timerDuration / 60) : '',
                    openFormTime: toLocalDatetimeInput(s.openFormTime),
                    closeFormTime: toLocalDatetimeInput(s.closeFormTime),
                    customFormLink: f.formLink || '',
                    isExamMode: s.isExamMode ?? false,
                    disableCopyPaste: s.disableCopyPaste ?? false,
                    detectTabSwitch: s.detectTabSwitch ?? false,
                    autoSubmitOnTabSwitch: s.autoSubmitOnTabSwitch ?? false,
                    maxTabSwitch: s.maxTabSwitch ?? 3,
                    themePrimaryColor: s.themePrimaryColor ?? '',
                    themeBackgroundColor: s.themeBackgroundColor ?? '',
                };
                setSettings(nextSettings);
            }

            baselineRef.current.settings = serializeSettingsForDirty(nextSettings);
            const qDirty = serializeQuestionsForDirty(questions) !== baselineRef.current.questions;
            setIsDirty(qDirty);
            showToast('Pengaturan formulir berhasil disimpan!');
            return true;
        } else {
            showToast(res.message || 'Gagal menyimpan pengaturan', 'error');
            return false;
        }
    };

    // BUG-3: Unified save handler that saves questions, settings, or both based on dirty state
    const handleSaveAll = async () => {
        const qDirty = serializeQuestionsForDirty(questions) !== baselineRef.current.questions;
        const sDirty = serializeSettingsForDirty(settings) !== baselineRef.current.settings;

        let okQ = true;
        let okS = true;

        if (qDirty || activeTab === 'questions') {
            okQ = await handleSaveQuestions();
        }

        if (sDirty || activeTab === 'settings') {
            okS = await handleSaveSettings();
        }

        return okQ && okS;
    };

    const handleTogglePublish = async () => {
        setPublishing(true);
        const res = await togglePublishForm(id);
        if (res.ok) {
            const updated = await getFormById(id);
            if (updated.ok) setForm(updated.data);
            showToast(res.message || 'Status publikasi formulir berhasil diubah!');
        } else {
            showToast(res.message || 'Gagal mengubah status publikasi', 'error');
        }
        setPublishing(false);
    };

    const handleLoadShare = useCallback(async () => {
        const res = await getFormShare(id);
        if (res.ok) {
            setShareInfo(res.data);
            const token = localStorage.getItem('token');
            const qrRes = await fetch(
                `${API_BASE_URL}/api/forms/${id}/share/qr?frontendUrl=${encodeURIComponent(FRONTEND_BASE_URL)}`,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            if (qrRes.ok) {
                const blob = await qrRes.blob();
                setQrBlobUrl(URL.createObjectURL(blob));
            }
        }
    }, [id]);

    const handleBannerUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const res = await uploadFormBanner(id, file);
        if (res.ok) {
            const updated = await getFormById(id);
            if (updated.ok) setForm(updated.data);
            showToast('Banner formulir berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah banner', 'error');
        }
    };

    const handleImportFile = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setImportLoading(true);
        const res = await importQuestions(id, file);
        setImportLoading(false);
        if (res.ok) {
            showToast(`Berhasil mengimpor ${res.data?.totalImported ?? 0} soal!`);
            const qRes = await getQuestions(id);
            if (qRes.ok && Array.isArray(qRes.data)) {
                setQuestions(qRes.data.map((q, i) => ({
                    ...q,
                    _id: `q_${q.id}`,
                    question: q.question || '',
                    typeId: q.typeId || 2,
                    questionOrder: q.questionOrder ?? i + 1,
                    isRequired: q.isRequired ?? false,
                    correctAnswer: q.correctAnswer ?? '',
                    questionImage: q.questionImage ?? null,
                    questionAudio: q.questionAudio ?? null,
                    options: q.options?.length > 0 ? q.options : [{ optionText: '', isCorrect: false }],
                })));
            }
        } else {
            showToast(res.message || 'Gagal mengimpor berkas', 'error');
        }
        e.target.value = '';
    };

    const handleDeleteQuestion = async (idx) => {
        const q = questions[idx];
        if (q.id) {
            const res = await deleteQuestion(id, q.id);
            if (!res.ok) { showToast(res.message || 'Gagal menghapus soal', 'error'); return; }
        }
        const next = questions.filter((_, i) => i !== idx);
        pushHistory(next);
        setQuestions(next);
        showToast('Soal berhasil dihapus');
    };

    // FEAT-10a: Duplicate question
    const handleDuplicateQuestion = (idx) => {
        const orig = questions[idx];
        const dupe = {
            ...JSON.parse(JSON.stringify(orig)),
            _id: `q_dup_${Date.now()}`,
            id: null,
        };
        setQuestions(prev => {
            const next = [...prev];
            next.splice(idx + 1, 0, dupe);
            pushHistory(next);
            return next;
        });
        showToast('Soal berhasil diduplikasi');
    };

    // FEAT-8: Export questions as CSV
    const handleExportQuestions = () => {
        if (questions.length === 0) { showToast('Tidak ada soal untuk diekspor.', 'error'); return; }
        const rows = [
            ['question', 'type_id', 'order', 'is_required', 'correct_answer', 'options']
        ];
        questions.forEach((q, i) => {
            const optionsStr = (q.options || []).map(o => (o.isCorrect ? `*${o.optionText}` : o.optionText)).join('|');
            const cleanQ = (q.question || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
            rows.push([
                `"${cleanQ.replace(/"/g, '""')}"`,
                q.typeId || 2,
                i + 1,
                q.isRequired ? 'true' : 'false',
                `"${(q.correctAnswer || '').replace(/"/g, '""')}"`,
                `"${optionsStr.replace(/"/g, '""')}"`,
            ]);
        });
        const csv = '\uFEFF' + rows.map(r => r.join(',')).join('\r\n');
        const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `soal-${(form?.title || 'formulir').replace(/\s+/g, '_')}-${Date.now()}.csv`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        showToast('File soal CSV berhasil diunduh!');
    };

    // AI-2: Revise question with AI
    const handleAiRevise = async (idx) => {
        const q = questions[idx];
        const apiKey = getGeminiApiKey();
        if (!apiKey) { setAiReviseError('API Key Gemini belum diatur.'); return; }
        if (!aiReviseInstruction.trim()) { setAiReviseError('Masukkan instruksi revisi.'); return; }
        setAiRevising(true);
        setAiReviseError('');
        try {
            const cleanQ = (q.question || '').replace(/<[^>]*>/g, '').trim();
            const optionsText = (q.options || []).map((o, i) => `${String.fromCharCode(65+i)}. ${o.optionText}${o.isCorrect?' (jawaban benar)':''}`).join('\n');
            const prompt = `Anda adalah asisten penyusun soal ujian. Revisi soal berikut sesuai instruksi.

Soal asli:
${cleanQ}

Pilihan jawaban:
${optionsText || '(tidak ada opsi)'}

Kunci jawaban: ${q.correctAnswer || ''}

Instruksi revisi: ${aiReviseInstruction.trim()}

Kembalikan HANYA JSON valid (satu objek, bukan array) dengan struktur:
{
  "question": "teks soal yang direvisi",
  "typeId": ${q.typeId},
  "isRequired": ${q.isRequired},
  "isScorable": ${q.isScorable},
  "correctAnswer": "kunci jawaban",
  "options": [{"optionText":"...", "isCorrect": false}]
}`;
            const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
            const resp = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [{ parts: [{ text: prompt }] }],
                    generationConfig: { responseMimeType: 'application/json', temperature: 0.7 }
                })
            });
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            const data = await resp.json();
            let textRes = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
            textRes = textRes.trim().replace(/^```json\s*/,'').replace(/\s*```$/,'').replace(/^```\s*/,'');
            const revised = JSON.parse(textRes);
            updateQuestion(idx, 'question', revised.question || q.question);
            if (revised.options && revised.options.length > 0) {
                setQuestions(prev => prev.map((qq, qi) => qi === idx ? { ...qq, question: revised.question || qq.question, options: revised.options, correctAnswer: revised.correctAnswer || qq.correctAnswer } : qq));
            } else {
                updateQuestion(idx, 'correctAnswer', revised.correctAnswer || q.correctAnswer);
            }
            setAiReviseOpenIdx(null);
            setAiReviseInstruction('');
            showToast('Soal berhasil direvisi oleh AI!');
        } catch (err) {
            setAiReviseError('Gagal merevisi soal: ' + err.message);
        } finally {
            setAiRevising(false);
        }
    };

    // A-7: Bulk AI Revise handler
    const handleBulkAiRevise = async () => {
        const apiKey = getGeminiApiKey();
        if (!apiKey) { showToast('API Key Gemini belum diatur.', 'error'); return; }
        if (!bulkReviseInstruction.trim()) { showToast('Masukkan instruksi revisi.', 'error'); return; }
        if (bulkReviseSelected.size === 0) { showToast('Pilih minimal 1 soal untuk direvisi.', 'error'); return; }
        setBulkRevising(true);
        const results = [];
        for (const idx of Array.from(bulkReviseSelected)) {
            const q = questions[idx];
            try {
                const cleanQ = (q.question || '').replace(/<[^>]*>/g, '').trim();
                const optionsText = (q.options || []).map((o, i) => `${String.fromCharCode(65+i)}. ${o.optionText}${o.isCorrect?' (jawaban benar)':''}`).join('\n');
                const prompt = `Revisi soal berikut sesuai instruksi. Kembalikan HANYA JSON valid.\n\nSoal: ${cleanQ}\nOpsi:\n${optionsText || '(tidak ada)'}\nKunci: ${q.correctAnswer || ''}\n\nInstruksi: ${bulkReviseInstruction.trim()}\n\nJSON output:\n{"question":"...","typeId":${q.typeId},"isRequired":${q.isRequired},"isScorable":${q.isScorable},"correctAnswer":"...","options":[{"optionText":"...","isCorrect":false}]}`;
                const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`;
                const resp = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.7 } }) });
                if (!resp.ok) continue;
                const data = await resp.json();
                let textRes = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
                textRes = textRes.trim().replace(/^```json\s*/,'').replace(/\s*```$/,'');
                const revised = JSON.parse(textRes);
                results.push({ idx, original: q, revised });
            } catch {}
        }
        setBulkRevising(false);
        if (results.length > 0) {
            setBulkRevisePreview(results);
            setBulkRevisePreviewOpen(true);
        } else {
            showToast('Tidak ada soal yang berhasil direvisi.', 'error');
        }
    };

    const applyBulkReviseItem = (idx, revised) => {
        setQuestions(prev => prev.map((q, qi) => qi === idx ? { ...q, question: revised.question || q.question, options: revised.options?.length > 0 ? revised.options : q.options, correctAnswer: revised.correctAnswer || q.correctAnswer } : q));
    };

    // Auto-save questions helper for unsaved questions before uploading image/audio
    const autoSaveBeforeUpload = async (idx) => {
        let currentQ = questions[idx];
        if (!currentQ.id) {
            const success = await handleSaveQuestions();
            if (!success) return null;
            const updatedList = await getQuestions(id);
            if (updatedList.ok && Array.isArray(updatedList.data) && updatedList.data[idx]) {
                return updatedList.data[idx].id;
            }
        }
        return currentQ.id;
    };

    const handleUploadQuestionImage = async (idx, file) => {
        const qId = await autoSaveBeforeUpload(idx);
        if (!qId) { showToast('Gagal memproses soal sebelum mengunggah gambar', 'error'); return; }

        const res = await uploadQuestionImage(id, qId, file);
        if (res.ok) {
            updateQuestion(idx, 'questionImage', res.data?.questionImage ?? null);
            showToast('Gambar soal berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah gambar', 'error');
        }
    };

    const handleUploadQuestionAudio = async (idx, file) => {
        const qId = await autoSaveBeforeUpload(idx);
        if (!qId) { showToast('Gagal memproses soal sebelum mengunggah audio', 'error'); return; }

        const res = await uploadQuestionAudio(id, qId, file);
        if (res.ok) {
            updateQuestion(idx, 'questionAudio', res.data?.questionAudio ?? null);
            showToast('Audio soal berhasil diunggah!');
        } else {
            showToast(res.message || 'Gagal mengunggah audio', 'error');
        }
    };

    const handleRemoveQuestionImage = (idx) => {
        updateQuestion(idx, 'questionImage', null);
    };

    const handleRemoveQuestionAudio = (idx) => {
        updateQuestion(idx, 'questionAudio', null);
    };

    const addQuestion = () => setQuestions(prev => {
        const next = [...prev, newQuestion(prev.length + 1)];
        pushHistory(next);
        return next;
    });

    const handleAddAIQuestions = (newGeneratedQuestions) => {
        if (!newGeneratedQuestions || newGeneratedQuestions.length === 0) return;
        setQuestions(prev => {
            const startOrder = prev.length + 1;
            const mapped = newGeneratedQuestions.map((q, idx) => ({
                ...q,
                _id: `q_ai_${Date.now()}_${idx}`,
                questionOrder: startOrder + idx,
            }));
            return [...prev, ...mapped];
        });
        showToast(`Berhasil menambahkan ${newGeneratedQuestions.length} butir soal dari AI!`, 'success');
    };

    const moveQuestion = (idx, dir) => {
        setQuestions(prev => {
            const arr = [...prev];
            const target = idx + dir;
            if (target < 0 || target >= arr.length) return arr;
            [arr[idx], arr[target]] = [arr[target], arr[idx]];
            pushHistory(arr);
            return arr;
        });
    };

    const updateQuestion = (idx, field, value) =>
        setQuestions(prev => prev.map((q, i) => i === idx ? { ...q, [field]: value } : q));

    const openInsertModal = (qIdx, mode, targetType = 'question', oIdx = null) => {
        setModalTarget({ type: targetType, qIdx, oIdx });
        setModalMode(mode);
        setModalOpen(true);
    };

    const handleInsertFromModal = (snippetHtml) => {
        const { type, qIdx, oIdx } = modalTarget;
        if (qIdx === null) return;

        if (type === 'option' && oIdx !== null) {
            const current = questions[qIdx]?.options?.[oIdx]?.optionText || '';
            updateOption(qIdx, oIdx, 'optionText', current + (current ? ' ' : '') + snippetHtml);
        } else {
            const current = questions[qIdx]?.question || '';
            updateQuestion(qIdx, 'question', current + snippetHtml);
        }
    };

    const togglePreview = (idx) => {
        setPreviewVisibility(prev => ({ ...prev, [idx]: !prev[idx] }));
    };

    const addOption = (qIdx) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: [...q.options, { optionText: '', isCorrect: false }] } : q
        ));

    const removeOption = (qIdx, oIdx) =>
        setQuestions(prev => prev.map((q, i) =>
            i === qIdx ? { ...q, options: q.options.filter((_, oi) => oi !== oIdx) } : q
        ));

    const updateOption = (qIdx, oIdx, field, val) =>
        setQuestions(prev => prev.map((q, i) => {
            if (i !== qIdx) return q;
            const opts = q.options.map((opt, oi) => {
                if (oi !== oIdx) return opt;
                return { ...opt, [field]: val };
            });
            return { ...q, options: opts };
        }));

    if (loading) {
        return (
            <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
                <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat builder formulir...</p>
            </div>
        );
    }

    const isPublished = form?.status?.toLowerCase() === 'published';

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div ref={mainScrollRef} className="flex-1 flex flex-col min-w-0 min-h-screen overflow-y-auto">

                {/* Top Header */}
                <div className="sticky top-0 z-30 bg-white/90 dark:bg-slate-900/90 backdrop-blur-md border-b border-slate-200/80 dark:border-slate-800 px-4 sm:px-6 py-3 flex items-center justify-between gap-4 shadow-xs">
                    <div className="flex items-center gap-3 min-w-0">
                        <button onClick={() => navigate('/my-forms')} className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-xl transition-all cursor-pointer">
                            <ArrowLeft size={18} />
                        </button>
                        <div className="min-w-0">
                            <div className="flex items-center gap-2">
                                <h1 className="text-sm sm:text-base font-extrabold text-slate-900 dark:text-white truncate">{form?.title || 'Formulir Tanpa Judul'}</h1>
                                <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full ${isPublished ? 'bg-teal-50 text-[#00897B] dark:bg-teal-950/60 dark:text-teal-400 border border-teal-200 dark:border-teal-800' : 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400'}`}>
                                    {isPublished ? 'Publik' : 'Draf'}
                                </span>
                            </div>
                            <p className="text-[11px] text-slate-400 dark:text-slate-500 font-mono">/f/{form?.formLink}</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0">
                        <button
                            onClick={handleTogglePublish}
                            disabled={publishing}
                            className={`flex items-center gap-1.5 px-3 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${isPublished ? 'bg-amber-50 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-800 hover:bg-amber-100' : 'bg-[#00897B] hover:bg-[#00796B] text-white shadow-xs'}`}
                        >
                            {isPublished ? <Lock size={14} /> : <Globe size={14} />}
                            <span className="hidden sm:inline">{publishing ? 'Memproses...' : isPublished ? 'Jadikan Draf' : 'Publikasikan'}</span>
                        </button>

                        {/* FEAT-13: Preview button */}
                        <button
                            type="button"
                            title="Lihat sebagai Responden (Preview)"
                            onClick={() => window.open(`/f/${form?.formLink}?preview=true&formId=${form?.id}`, '_blank')}
                            className="hidden sm:flex items-center gap-1.5 px-3 py-2 text-xs font-bold rounded-xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 border border-slate-200 dark:border-slate-700 transition-all cursor-pointer"
                        >
                            <Eye size={14} />
                            <span>Preview</span>
                        </button>

                        {/* FEAT-14: Autosave toggle */}
                        <div className="hidden lg:flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800">
                            <button
                                type="button"
                                onClick={() => setAutosaveEnabled(prev => !prev)}
                                className={`flex items-center gap-1.5 text-xs font-bold transition-all cursor-pointer ${autosaveEnabled ? 'text-teal-600 dark:text-teal-400' : 'text-slate-400 dark:text-slate-500'}`}
                                title="Simpan perubahan otomatis setiap 15 detik saat ada perubahan"
                            >
                                {autosaveEnabled ? <ToggleRight size={16} /> : <ToggleLeft size={16} />}
                                <span>Auto-Save {autosaveEnabled ? 'ON' : 'OFF'}</span>
                            </button>
                            {autosaveEnabled && autosaveLastSaved && (
                                <span className="text-[10px] text-slate-400 dark:text-slate-500 font-medium">
                                    {autosaveLastSaved}
                                </span>
                            )}
                        </div>

                        <button
                            onClick={handleSaveAll}
                            disabled={saving}
                            className={`relative flex items-center gap-1.5 px-4 py-2 text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer disabled:opacity-60 ${
                                isDirty
                                    ? 'bg-orange-500 hover:bg-orange-600 text-white animate-pulse'
                                    : 'bg-slate-900 hover:bg-slate-800 dark:bg-slate-700 dark:hover:bg-slate-600 text-white'
                            }`}
                        >
                            <Save size={14} />
                            <span>{saving ? 'Menyimpan...' : isDirty ? '⚠ Simpan Sekarang' : 'Simpan Perubahan'}</span>
                        </button>
                    </div>
                </div>

                {toast && (
                    <div className={`fixed top-16 right-6 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-[#00897B]'}`}>
                        {toast.msg}
                    </div>
                )}

                {autosaveToast && (
                    <div className="fixed top-16 right-6 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white bg-teal-600 flex items-center gap-2">
                        <Save size={13} /> {autosaveToast}
                    </div>
                )}

                {/* Sub-Header Tabs */}
                <div className="flex border-b border-slate-200/80 dark:border-slate-800 bg-white dark:bg-slate-900 px-6">
                    {[
                        { key: 'questions', label: 'Pertanyaan & Soal' },
                        { key: 'settings', label: 'Pengaturan & Aturan' },
                        { key: 'share', label: 'Bagikan & Kode QR' },
                    ].map(t => (
                        <button
                            key={t.key}
                            onClick={() => {
                                setActiveTab(t.key);
                                if (t.key === 'share') handleLoadShare();
                            }}
                            className={`py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all cursor-pointer whitespace-nowrap ${activeTab === t.key ? 'border-[#00897B] text-[#00897B] dark:border-teal-400 dark:text-teal-400' : 'border-transparent text-slate-400 dark:text-slate-500 hover:text-slate-700 dark:hover:text-slate-300'}`}
                        >
                            {t.label}
                        </button>
                    ))}
                </div>

                <div className="p-4 sm:p-6 lg:p-8 max-w-4xl mx-auto w-full space-y-6 flex-1">

                    {/* ── QUESTIONS TAB ── */}
                    {activeTab === 'questions' && (
                        <>
                            {/* Form Header Info Card */}
                            <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs">
                                <div>
                                    <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">Judul Formulir</label>
                                    <input
                                        type="text"
                                        value={form?.title || ''}
                                        onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
                                        onBlur={() => updateForm(id, { title: form.title, description: form.description })}
                                        placeholder="Judul Formulir..."
                                        className="w-full text-xl font-extrabold bg-transparent text-slate-900 dark:text-white border-b border-transparent hover:border-slate-200 dark:hover:border-slate-700 focus:border-[#00897B] focus:outline-none py-1 transition-all"
                                    />
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">Deskripsi Formulir</label>
                                    <BlockQuestionEditor
                                        value={form?.description || ''}
                                        onChange={(newHtml) => setForm(f => ({ ...f, description: newHtml }))}
                                        placeholder="Tuliskan petunjuk atau deskripsi umum formulir..."
                                    />
                                </div>

                                {/* Banner Image Upload */}
                                <div className="pt-2 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                                    <div className="flex items-center gap-3">
                                        {form?.bannerImage && (
                                            <img src={assetUrl(form.bannerImage)} alt="Banner" className="w-16 h-10 object-cover rounded-lg border border-slate-200 dark:border-slate-700" />
                                        )}
                                        <span className="text-xs font-bold text-slate-600 dark:text-slate-300">
                                            {form?.bannerImage ? 'Gambar Banner Terpasang' : 'Belum Ada Gambar Banner'}
                                        </span>
                                    </div>
                                    <label className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-700 dark:text-slate-200 rounded-xl text-xs font-bold cursor-pointer transition-all">
                                        <Upload size={13} /> {form?.bannerImage ? 'Ubah Banner' : 'Unggah Banner'}
                                        <input type="file" accept="image/*" className="hidden" onChange={handleBannerUpload} />
                                    </label>
                                </div>

                                {/* AI Generator & File Import Bar */}
                                <div className="pt-3 border-t border-slate-100 dark:border-slate-800 space-y-3">
                                    {/* AI Generator Banner Card */}
                                    <div className="p-3.5 rounded-2xl bg-gradient-to-r from-teal-500/15 via-emerald-500/10 to-teal-500/5 border border-teal-500/25 dark:border-teal-500/20 flex flex-wrap items-center justify-between gap-3 shadow-xs">
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-teal-600 to-emerald-400 text-white flex items-center justify-center shadow-xs">
                                                <Sparkles size={16} />
                                            </div>
                                            <div>
                                                <p className="text-xs font-extrabold text-slate-900 dark:text-white flex items-center gap-1.5">
                                                    Buat Soal Otomatis dengan AI
                                                    {/* <span className="text-[9px] uppercase px-1.5 py-0.5 rounded-md bg-teal-600 text-white font-extrabold tracking-wider">
                                                        Gemini
                                                    </span> */}
                                                </p>
                                                <p className="text-[11px] text-slate-500 dark:text-slate-400">
                                                    Ketik topik atau paste materi, AI menyusun soal, opsi, dan kunci jawaban instan.
                                                </p>
                                            </div>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => setAiModalOpen(true)}
                                            className="px-4 py-2 bg-gradient-to-r from-teal-600 to-emerald-500 hover:from-teal-700 hover:to-emerald-600 text-white rounded-xl text-xs font-bold shadow-xs flex items-center gap-1.5 transition-all cursor-pointer hover:scale-[1.02] active:scale-[0.98]"
                                        >
                                            <Sparkles size={13} />
                                            <span>Generate Soal AI</span>
                                        </button>
                                    </div>

                                    {/* Question Import Bar */}
                                    <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
                                        <div className="flex items-center gap-2">
                                            <span className="text-[11px] text-slate-400 dark:text-slate-500 font-medium">Template:</span>
                                            {['csv', 'xlsx', 'docx'].map(fmt => (
                                                <a
                                                    key={fmt}
                                                    href={templateDownloadUrl(fmt)}
                                                    download
                                                    className="inline-flex items-center gap-1 px-2 py-1 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-300 rounded-lg text-[11px] font-bold transition-all"
                                                >
                                                    <Download size={11} /> .{fmt.toUpperCase()}
                                                </a>
                                            ))}
                                        </div>
                                        <label className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 text-slate-700 dark:text-slate-200 rounded-xl text-xs font-bold cursor-pointer transition-all shrink-0">
                                            <FileUp size={13} /> {importLoading ? 'Mengimpor...' : 'Impor File Soal'}
                                            <input type="file" accept=".xlsx,.csv,.docx,.pdf" className="hidden" onChange={handleImportFile} disabled={importLoading} />
                                        </label>
                                    </div>
                                </div>
                            </div>

                            {/* Question Cards List */}
                            <div className="space-y-5">
                                {questions.map((q, idx) => (
                                    <div
                                        key={q._id || idx}
                                        className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-4 shadow-xs hover:border-slate-300 dark:hover:border-slate-700 transition-all"
                                    >
                                        {/* Card Header Controls */}
                                        <div className="flex items-center justify-between gap-2 border-b border-slate-100 dark:border-slate-800 pb-3">
                                            <div className="flex items-center gap-2">
                                                {bulkReviseMode && (
                                                    <input
                                                        type="checkbox"
                                                        checked={bulkReviseSelected.has(idx)}
                                                        onChange={e => {
                                                            setBulkReviseSelected(prev => {
                                                                const next = new Set(prev);
                                                                if (e.target.checked) next.add(idx); else next.delete(idx);
                                                                return next;
                                                            });
                                                        }}
                                                        className="w-4 h-4 text-purple-600 rounded cursor-pointer"
                                                    />
                                                )}
                                                <span className="text-xs font-extrabold text-slate-500 dark:text-slate-400 bg-slate-100 dark:bg-slate-800 px-2.5 py-1 rounded-lg">
                                                    Soal #{idx + 1}
                                                </span>
                                            </div>

                                            <div className="flex items-center gap-1">
                                                <button
                                                    type="button"
                                                    onClick={() => togglePreview(idx)}
                                                    className={`p-1.5 rounded-lg transition-all cursor-pointer ${previewVisibility[idx] ? 'bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400' : 'text-slate-400 hover:text-slate-600 dark:hover:text-slate-300'}`}
                                                    title="Toggle Live Preview"
                                                >
                                                    {previewVisibility[idx] ? <EyeOff size={15} /> : <Eye size={15} />}
                                                </button>

                                                {/* AI-2: Revisi AI per soal */}
                                                <button
                                                    type="button"
                                                    onClick={() => { setAiReviseOpenIdx(aiReviseOpenIdx === idx ? null : idx); setAiReviseInstruction(''); setAiReviseError(''); }}
                                                    className={`p-1.5 rounded-lg transition-all cursor-pointer ${aiReviseOpenIdx === idx ? 'bg-purple-50 dark:bg-purple-950/60 text-purple-600 dark:text-purple-400' : 'text-slate-400 hover:text-purple-500 dark:hover:text-purple-400'}`}
                                                    title="Revisi soal dengan AI"
                                                >
                                                    <Wand2 size={15} />
                                                </button>

                                                <div className="h-4 w-px bg-slate-200 dark:bg-slate-700 mx-1" />

                                                <button onClick={() => moveQuestion(idx, -1)} disabled={idx === 0} className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 disabled:opacity-30 cursor-pointer" title="Pindah Naik">
                                                    <ChevronUp size={16} />
                                                </button>
                                                <button onClick={() => moveQuestion(idx, 1)} disabled={idx === questions.length - 1} className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 disabled:opacity-30 cursor-pointer" title="Pindah Turun">
                                                    <ChevronDown size={16} />
                                                </button>
                                                {/* FEAT-10a: Duplikat soal */}
                                                <button onClick={() => handleDuplicateQuestion(idx)} className="p-1 text-blue-400 hover:text-blue-600 cursor-pointer" title="Duplikat Soal">
                                                    <Copy size={15} />
                                                </button>
                                                <button onClick={() => handleDeleteQuestion(idx)} className="p-1 text-red-400 hover:text-red-600 cursor-pointer" title="Hapus Soal">
                                                    <Trash2 size={16} />
                                                </button>
                                            </div>
                                        </div>

                                        {/* Media Attachments at the TOP of the Question */}
                                        <div className="pb-3 border-b border-slate-100 dark:border-slate-800 space-y-2">
                                            <div className="flex flex-wrap items-center gap-3">
                                                {/* Image attachment */}
                                                {q.questionImage ? (
                                                    <div className="flex items-center gap-2 bg-slate-50 dark:bg-slate-800 p-2 rounded-xl border border-slate-200 dark:border-slate-700">
                                                        <img
                                                            src={assetUrl(q.questionImage)}
                                                            alt="Soal"
                                                            className="h-14 w-24 object-cover rounded-lg cursor-zoom-in hover:opacity-90 transition-opacity"
                                                            onClick={() => setLightboxImage({ src: assetUrl(q.questionImage), alt: 'Gambar Soal' })}
                                                            title="Klik untuk memperbesar gambar"
                                                        />
                                                        <div className="flex flex-col gap-1">
                                                            <label className="text-[11px] font-bold text-[#00897B] dark:text-teal-400 cursor-pointer hover:underline">
                                                                Ganti Gambar
                                                                <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                            </label>
                                                            <button
                                                                type="button"
                                                                onClick={() => handleRemoveQuestionImage(idx)}
                                                                className="text-[10px] font-bold text-red-500 hover:underline flex items-center gap-1 cursor-pointer"
                                                            >
                                                                <X size={11} /> Hapus Gambar
                                                            </button>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 cursor-pointer hover:border-[#00897B] hover:text-[#00897B] transition-all">
                                                        <Image size={13} /> Tambah Gambar Soal
                                                        <input type="file" accept="image/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionImage(idx, e.target.files[0])} />
                                                    </label>
                                                )}

                                                {/* Audio attachment */}
                                                {q.questionAudio ? (
                                                    <div className="flex items-center gap-2 bg-slate-50 dark:bg-slate-800 p-2 rounded-xl border border-slate-200 dark:border-slate-700">
                                                        <audio controls src={assetUrl(q.questionAudio)} className="h-8 max-w-[200px]" />
                                                        <div className="flex flex-col gap-1">
                                                            <label className="text-[11px] font-bold text-[#00897B] dark:text-teal-400 cursor-pointer hover:underline">
                                                                Ganti Audio
                                                                <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                            </label>
                                                            <button
                                                                type="button"
                                                                onClick={() => handleRemoveQuestionAudio(idx)}
                                                                className="text-[10px] font-bold text-red-500 hover:underline flex items-center gap-1 cursor-pointer"
                                                            >
                                                                <X size={11} /> Hapus Audio
                                                            </button>
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <label className="flex items-center gap-1.5 px-3 py-1.5 border border-dashed border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 cursor-pointer hover:border-[#00897B] hover:text-[#00897B] transition-all">
                                                        <Music size={13} /> Tambah Audio Soal
                                                        <input type="file" accept="audio/*" className="hidden" onChange={e => e.target.files?.[0] && handleUploadQuestionAudio(idx, e.target.files[0])} />
                                                    </label>
                                                )}
                                            </div>
                                        </div>

                                        {/* Question Block Editor (Modular Notion-style) */}
                                        <div className="space-y-2">
                                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block">Isi Pertanyaan Soal</label>
                                            <BlockQuestionEditor
                                                value={q.question || ''}
                                                onChange={(newHtml) => updateQuestion(idx, 'question', newHtml)}
                                                placeholder="Tuliskan teks pertanyaan soal, kode program, atau rumus..."
                                            />
                                        </div>

                                        {/* Live Preview Box with Word Wrap Fix */}
                                        {previewVisibility[idx] && (
                                            <div className="p-4 bg-slate-50 dark:bg-slate-800/80 rounded-xl border border-slate-200/80 dark:border-slate-700 space-y-2 overflow-hidden">
                                                <div className="flex items-center justify-between text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                                                    <span>Live Preview</span>
                                                </div>
                                                <div className="break-words break-all [overflow-wrap:anywhere]">
                                                    <RichContentRenderer content={q.question} format={q.questionFormat} className="text-sm font-semibold text-slate-800 dark:text-slate-100" />
                                                </div>
                                            </div>
                                        )}

                                        {/* AI-2: Inline AI Revise Panel */}
                                        {aiReviseOpenIdx === idx && (
                                            <div className="p-3.5 bg-purple-50 dark:bg-purple-950/40 rounded-xl border border-purple-200 dark:border-purple-800 space-y-2">
                                                <p className="text-xs font-bold text-purple-700 dark:text-purple-300 flex items-center gap-1.5">
                                                    <Wand2 size={13} /> Revisi Soal dengan AI
                                                </p>
                                                {aiReviseError && <p className="text-[11px] text-red-500">{aiReviseError}</p>}
                                                <div className="flex gap-2">
                                                    <input
                                                        type="text"
                                                        value={aiReviseInstruction}
                                                        onChange={e => setAiReviseInstruction(e.target.value)}
                                                        placeholder="Instruksi: Buat lebih sulit, ganti konteks ke ekosistem laut..."
                                                        className="flex-1 px-3 py-1.5 text-xs border border-purple-200 dark:border-purple-700 rounded-xl bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-purple-500"
                                                        disabled={aiRevising}
                                                    />
                                                    <button
                                                        type="button"
                                                        onClick={() => handleAiRevise(idx)}
                                                        disabled={aiRevising || !aiReviseInstruction.trim()}
                                                        className="px-3 py-1.5 bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold rounded-xl transition-all cursor-pointer disabled:opacity-50 flex items-center gap-1"
                                                    >
                                                        {aiRevising ? <span className="animate-spin">⋯</span> : <Wand2 size={13} />}
                                                        Revisi
                                                    </button>
                                                </div>
                                            </div>
                                        )}

                                        {/* Question Type & Settings */}
                                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                            <div>
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">Tipe Soal</label>
                                                <select
                                                    value={q.typeId}
                                                    onChange={e => updateQuestion(idx, 'typeId', parseInt(e.target.value))}
                                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                >
                                                    {QUESTION_TYPES.map(t => (
                                                        <option key={t.id} value={t.id}>{t.label}</option>
                                                    ))}
                                                </select>
                                            </div>

                                            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-end gap-4 pt-1 sm:pt-5">
                                                <label className="flex items-center gap-2 text-xs font-bold text-slate-700 dark:text-slate-300 cursor-pointer">
                                                    <input
                                                        type="checkbox"
                                                        checked={q.isScorable !== false}
                                                        onChange={e => updateQuestion(idx, 'isScorable', e.target.checked)}
                                                        className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                                    />
                                                    <span>Hitung ke Skor (Dinilai)</span>
                                                </label>

                                                <label className="flex items-center gap-2 text-xs font-bold text-slate-700 dark:text-slate-300 cursor-pointer">
                                                    <input
                                                        type="checkbox"
                                                        checked={!!q.isRequired}
                                                        onChange={e => updateQuestion(idx, 'isRequired', e.target.checked)}
                                                        className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                                    />
                                                    <span>Soal Wajib Diisi</span>
                                                </label>
                                            </div>
                                        </div>

                                        {/* Points input — visible only when scorable */}
                                        {q.isScorable !== false && (
                                            <div className="flex items-center gap-3">
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 whitespace-nowrap">Poin Soal</label>
                                                <input
                                                    type="number"
                                                    min="0"
                                                    step="1"
                                                    placeholder="Kosongi = bobot sama rata"
                                                    value={q.points ?? ''}
                                                    onChange={e => updateQuestion(idx, 'points', e.target.value === '' ? null : parseInt(e.target.value, 10))}
                                                    className="w-40 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                />
                                                <span className="text-[10px] text-slate-400 dark:text-slate-500 italic">opsional — biarkan kosong untuk bobot sama rata</span>
                                            </div>
                                        )}

                                        {/* Non-Scorable Notice */}
                                        {q.isScorable === false ? (
                                            <div className="p-3 bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-700/80 rounded-xl flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                                                <span className="w-2 h-2 rounded-full bg-slate-400 shrink-0" />
                                                <span>Soal ini <b>Tidak Dinilai</b> (digunakan untuk pengumpulan data seperti Nama, Email, NIM, atau survei umum). Tidak memerlukan kunci jawaban dan tidak memengaruhi skor.</span>
                                            </div>
                                        ) : null}

                                                {needsOptions(q.typeId) && (
                                            <div className="space-y-3 pt-3 border-t border-slate-100 dark:border-slate-800">
                                                <div className="flex items-center justify-between">
                                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block">Pilihan Jawaban:</label>
                                                    {q.isScorable !== false && (
                                                        <span className="text-[11px] text-slate-400 dark:text-slate-500">
                                                            {q.typeId === 2
                                                                ? '● Pilih 1 jawaban benar (radio)'
                                                                : '☑ Centang semua jawaban benar'}
                                                        </span>
                                                    )}
                                                </div>
                                                {q.options.map((opt, oIdx) => (
                                                    <div key={oIdx} className="space-y-1">
                                                        <div className="flex items-center gap-2">
                                                            {q.isScorable !== false ? (
                                                                <label className="flex items-center gap-1 cursor-pointer">
                                                                    {q.typeId === 2 ? (
                                                                        // TASK 3: Multiple Choice → radio (single-select)
                                                                        <input
                                                                            type="radio"
                                                                            name={`correct_q${idx}`}
                                                                            checked={!!opt.isCorrect}
                                                                            onChange={() => {
                                                                                setQuestions(prev => prev.map((qq, qi) => {
                                                                                    if (qi !== idx) return qq;
                                                                                    return {
                                                                                        ...qq,
                                                                                        options: qq.options.map((o, oi) => ({
                                                                                            ...o,
                                                                                            isCorrect: oi === oIdx,
                                                                                        })),
                                                                                    };
                                                                                }));
                                                                            }}
                                                                            className="w-4 h-4 shrink-0 cursor-pointer accent-[#00897B]"
                                                                            title="Tandai sebagai satu-satunya jawaban benar"
                                                                        />
                                                                    ) : (
                                                                        // TASK 3: Checkbox type → checkbox (multi-select unchanged)
                                                                        <input
                                                                            type="checkbox"
                                                                            checked={!!opt.isCorrect}
                                                                            onChange={e => updateOption(idx, oIdx, 'isCorrect', e.target.checked)}
                                                                            className="w-4 h-4 text-[#00897B] rounded shrink-0 cursor-pointer"
                                                                            title="Tandai sebagai jawaban benar"
                                                                        />
                                                                    )}
                                                                    {opt.isCorrect && <span className="text-[10px] font-extrabold text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60 px-1.5 py-0.5 rounded">✓ Benar</span>}
                                                                </label>
                                                            ) : (
                                                                <span className="w-5 h-5 flex items-center justify-center text-[10px] font-bold text-slate-400 bg-slate-100 dark:bg-slate-800 rounded-full shrink-0">
                                                                    {String.fromCharCode(65 + oIdx)}
                                                                </span>
                                                            )}

                                                            <div className="flex-1 flex items-center gap-1">
                                                                <input
                                                                    placeholder={`Pilihan ${oIdx + 1}`}
                                                                    value={opt.optionText}
                                                                    onChange={e => updateOption(idx, oIdx, 'optionText', e.target.value)}
                                                                    className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                                />
                                                                <button
                                                                    type="button"
                                                                    onClick={() => openInsertModal(idx, 'math', 'option', oIdx)}
                                                                    className="p-1 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 rounded cursor-pointer"
                                                                    title="Sisipkan Rumus (KaTeX)"
                                                                >
                                                                    <Calculator size={14} />
                                                                </button>
                                                                <button
                                                                    type="button"
                                                                    onClick={() => openInsertModal(idx, 'code', 'option', oIdx)}
                                                                    className="p-1 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 rounded cursor-pointer"
                                                                    title="Sisipkan Kode Block"
                                                                >
                                                                    <Code size={14} />
                                                                </button>
                                                                {/* FEAT-7: Image upload per option */}
                                                                <label
                                                                    className="p-1 text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 rounded cursor-pointer"
                                                                    title="Tambah Gambar Opsi (maks 500KB)"
                                                                >
                                                                    <Image size={14} />
                                                                    <input
                                                                        type="file"
                                                                        accept="image/*"
                                                                        className="hidden"
                                                                        onChange={e => {
                                                                            const file = e.target.files?.[0];
                                                                            if (!file) return;
                                                                            if (file.size > 500 * 1024) {
                                                                                showToast('Gambar opsi terlalu besar (maks 500KB).', 'error');
                                                                                return;
                                                                            }
                                                                            const reader = new FileReader();
                                                                            reader.onload = (ev) => {
                                                                                const current = opt.optionText || '';
                                                                                const imgTag = `<img src="${ev.target.result}" style="max-height:80px;display:inline-block;vertical-align:middle;" alt="opsi" />`;
                                                                                updateOption(idx, oIdx, 'optionText', current + (current ? ' ' : '') + imgTag);
                                                                            };
                                                                            reader.readAsDataURL(file);
                                                                            e.target.value = '';
                                                                        }}
                                                                    />
                                                                </label>
                                                            </div>

                                                            <button onClick={() => removeOption(idx, oIdx)} className="text-red-400 hover:text-red-600 p-1 shrink-0 cursor-pointer">
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>

                                                        {/* Option Rich Content Preview if formula/code/image inserted */}
                                                        {(opt.optionText?.includes('$') || opt.optionText?.includes('<pre') || opt.optionText?.includes('<code') || opt.optionText?.includes('<img')) && (
                                                            <div className="ml-6 p-2 bg-slate-50 dark:bg-slate-800/60 rounded-lg text-xs border border-slate-200/60 dark:border-slate-700">
                                                                <RichContentRenderer content={opt.optionText} format="text" className="text-xs" />
                                                            </div>
                                                        )}
                                                    </div>
                                                ))}
                                                <button onClick={() => addOption(idx)} className="text-xs font-bold text-[#00897B] dark:text-teal-400 hover:underline mt-1 cursor-pointer">
                                                    + Tambah Pilihan
                                                </button>
                                            </div>
                                        )}

                                        {/* Answer Key for Essay / Date / True-False (Only if isScorable !== false) */}
                                        {q.isScorable !== false && [1, 4, 5].includes(q.typeId) && (
                                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                                <label className="text-xs font-bold text-slate-500 dark:text-slate-400 block mb-1">
                                                    Jawaban Benar yang Diharapkan (untuk penilaian otomatis & skor):
                                                </label>
                                                {q.typeId === 5 ? (
                                                    <select
                                                        value={(() => {
                                                            const v = q.correctAnswer || 'Benar';
                                                            return (v === 'True' || v === 'true') ? 'Benar' : (v === 'False' || v === 'false') ? 'Salah' : v;
                                                        })()}
                                                        onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold focus:outline-none focus:ring-2 focus:ring-[#00897B] bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100"
                                                    >
                                                        <option value="Benar">Benar</option>
                                                        <option value="Salah">Salah</option>
                                                    </select>
                                                ) : (
                                                    <input
                                                        placeholder="contoh: 4 atau Soekarno"
                                                        value={q.correctAnswer}
                                                        onChange={e => updateQuestion(idx, 'correctAnswer', e.target.value)}
                                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                                    />
                                                )}
                                            </div>
                                        )}
                                    </div>
                                ))}
                            </div>

                            {questions.length === 0 && (
                                <div className="py-8 text-center border-2 border-dashed border-slate-200 dark:border-slate-700 rounded-2xl bg-white/60 dark:bg-slate-900/60">
                                    <p className="text-sm font-bold text-slate-500 dark:text-slate-400">Belum ada soal</p>
                                    <p className="text-xs text-slate-400 dark:text-slate-500 mt-1">Form tanpa soal akan tersimpan kosong (0 soal) dan otomatis kembali menjadi draf.</p>
                                </div>
                            )}
                            {/* A-2: Reorganized toolbar — Tambah Soal + Aksi Lainnya dropdown */}
                            <div className="flex flex-wrap gap-2 items-center">
                                {/* Primary action: Tambah Soal Manual — always visible */}
                                <button
                                    onClick={addQuestion}
                                    className="flex-1 min-w-[180px] py-3.5 border-2 border-dashed border-slate-300 dark:border-slate-700 rounded-2xl text-xs font-extrabold text-slate-600 dark:text-slate-400 hover:border-[#00897B] dark:hover:border-teal-400 hover:text-[#00897B] dark:hover:text-teal-400 transition-all flex items-center justify-center gap-2 bg-white/60 dark:bg-slate-900/60 cursor-pointer"
                                >
                                    <Plus size={18} /> Tambah Soal Manual
                                </button>

                                {/* A-2: Aksi Lainnya dropdown */}
                                <div className="relative" ref={actionsMenuRef}>
                                    <button
                                        type="button"
                                        onClick={() => setActionsMenuOpen(prev => !prev)}
                                        className="flex items-center gap-1.5 px-4 py-3.5 border border-slate-200 dark:border-slate-700 rounded-2xl text-xs font-extrabold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-all bg-white dark:bg-slate-900 cursor-pointer shadow-xs"
                                    >
                                        <MoreHorizontal size={16} />
                                        <span>Aksi Lainnya</span>
                                        <ChevDown size={13} className={`transition-transform duration-200 ${actionsMenuOpen ? 'rotate-180' : ''}`} />
                                    </button>

                                    {actionsMenuOpen && (
                                        <div className="absolute bottom-full mb-2 left-0 z-30 w-52 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-xl overflow-hidden animate-in fade-in zoom-in-95 duration-150">
                                            <button type="button" onClick={() => { setActionsMenuOpen(false); setAiModalOpen(true); }} className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-teal-50 dark:hover:bg-teal-950/40 hover:text-teal-700 dark:hover:text-teal-300 transition-colors cursor-pointer">
                                                <Sparkles size={14} className="text-teal-600 dark:text-teal-400 shrink-0" /> Buat dengan AI
                                            </button>
                                            <button type="button" onClick={() => { setActionsMenuOpen(false); setBulkReviseMode(prev => !prev); setBulkReviseSelected(new Set()); }} className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-purple-50 dark:hover:bg-purple-950/40 hover:text-purple-700 dark:hover:text-purple-300 transition-colors cursor-pointer">
                                                <Wand2 size={14} className="text-purple-600 dark:text-purple-400 shrink-0" /> {bulkReviseMode ? 'Selesai Pilih (Revisi)' : 'Revisi Massal AI'}
                                            </button>
                                            <div className="h-px bg-slate-100 dark:bg-slate-800 mx-3 my-1" />
                                            <button type="button" onClick={() => { setActionsMenuOpen(false); handleUndo(); }} disabled={historyIndex <= 0} className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed">
                                                <Undo2 size={14} className="text-slate-500 shrink-0" /> Undo <span className="ml-auto text-[10px] font-normal text-slate-400">Ctrl+Z</span>
                                            </button>
                                            <button type="button" onClick={() => { setActionsMenuOpen(false); handleRedo(); }} disabled={historyIndex >= history.length - 1} className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed">
                                                <Redo2 size={14} className="text-slate-500 shrink-0" /> Redo <span className="ml-auto text-[10px] font-normal text-slate-400">Ctrl+Y</span>
                                            </button>
                                            <div className="h-px bg-slate-100 dark:bg-slate-800 mx-3 my-1" />
                                            <button type="button" onClick={() => { setActionsMenuOpen(false); handleExportQuestions(); }} disabled={questions.length === 0} className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs font-bold text-slate-700 dark:text-slate-200 hover:bg-blue-50 dark:hover:bg-blue-950/40 hover:text-blue-700 dark:hover:text-blue-300 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed">
                                                <FileDown size={14} className="text-blue-600 dark:text-blue-400 shrink-0" /> Export Soal (CSV)
                                            </button>
                                            <button type="button" onClick={() => { setActionsMenuOpen(false); handleClearAllQuestions(); }} disabled={questions.length === 0} className="w-full flex items-center gap-2.5 px-4 py-2.5 text-xs font-bold text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed">
                                                <Trash2 size={14} className="shrink-0" /> Hapus Semua Soal
                                            </button>
                                        </div>
                                    )}
                                </div>
                            </div>
                            {bulkReviseMode && (
                                <div className="sticky bottom-4 z-20 bg-white dark:bg-slate-900 border border-purple-200 dark:border-purple-800 rounded-2xl shadow-xl p-4 flex flex-wrap items-center gap-3">
                                    <div className="flex items-center gap-2 text-xs font-bold text-purple-700 dark:text-purple-300">
                                        <Wand2 size={14} />
                                        <span>{bulkReviseSelected.size} soal dipilih</span>
                                        <button type="button" onClick={() => setBulkReviseSelected(new Set(questions.map((_, i) => i)))} className="text-purple-500 underline cursor-pointer">Pilih Semua</button>
                                    </div>
                                    <input
                                        type="text"
                                        value={bulkReviseInstruction}
                                        onChange={e => setBulkReviseInstruction(e.target.value)}
                                        placeholder="Instruksi revisi untuk semua soal terpilih..."
                                        className="flex-1 min-w-[200px] px-3 py-1.5 text-xs border border-purple-200 dark:border-purple-700 rounded-xl bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-purple-500"
                                    />
                                    <button
                                        type="button"
                                        onClick={handleBulkAiRevise}
                                        disabled={bulkRevising || bulkReviseSelected.size === 0 || !bulkReviseInstruction.trim()}
                                        className="px-4 py-1.5 bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold rounded-xl cursor-pointer disabled:opacity-50 flex items-center gap-1.5"
                                    >
                                        {bulkRevising ? <span className="animate-spin">⋯</span> : <Wand2 size={13} />}
                                        {bulkRevising ? 'Merevisi...' : 'Revisi Sekarang'}
                                    </button>
                                </div>
                            )}
                        </>
                    )}

                    {/* ── SETTINGS TAB ── */}
                    {activeTab === 'settings' && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-6 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-900 dark:text-white border-b border-slate-100 dark:border-slate-800 pb-3">
                                Konfigurasi & Aturan Formulir
                            </h2>

                            <div className="space-y-4">
                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Slug Tautan Khusus</label>
                                    <div className="flex items-center gap-2">
                                        <span className="text-xs font-mono text-slate-400 dark:text-slate-500 bg-slate-100 dark:bg-slate-800 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700">
                                            {FRONTEND_BASE_URL}/f/
                                        </span>
                                        <input
                                            value={settings.customFormLink}
                                            onChange={e => setSettings(s => ({ ...s, customFormLink: e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, '') }))}
                                            placeholder="tautan-khusus-saya"
                                            className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                    <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-1">Hanya huruf kecil, angka, dan tanda hubung (-).</p>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Tipe Tata Letak Formulir</label>
                                        <select
                                            value={settings.formTypeId}
                                            onChange={e => setSettings(s => ({ ...s, formTypeId: parseInt(e.target.value) }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        >
                                            <option value={1}>Semua Soal dalam Satu Halaman</option>
                                            <option value={2}>Satu Soal per Halaman (Langkah)</option>
                                        </select>
                                        {/* A-5: Clarify independence from exam mode */}
                                        <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-1">Pilihan tampilan — bebas dikombinasikan dengan Mode Ujian.</p>
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Durasi Timer (Menit, Opsional)</label>
                                        <input
                                            type="number"
                                            min="0"
                                            value={settings.timerDuration}
                                            onChange={e => setSettings(s => ({ ...s, timerDuration: e.target.value }))}
                                            placeholder="contoh: 30"
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Waktu Buka Formulir (Opsional)</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.openFormTime}
                                            onChange={e => setSettings(s => ({ ...s, openFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>

                                    <div>
                                        <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Waktu Tutup Formulir (Opsional)</label>
                                        <input
                                            type="datetime-local"
                                            value={settings.closeFormTime}
                                            onChange={e => setSettings(s => ({ ...s, closeFormTime: e.target.value }))}
                                            className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Token Kata Sandi Formulir (Opsional)</label>
                                    <input
                                        type="text"
                                        value={settings.formToken}
                                        onChange={e => setSettings(s => ({ ...s, formToken: e.target.value }))}
                                        placeholder="contoh: RAHASIA123"
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>

                                <div className="space-y-3 pt-2">
                                    {[
                                        { key: 'showScore', label: 'Tampilkan Skor & Kunci Jawaban setelah Pengisian' },
                                        { key: 'randomizeQuestions', label: 'Acak Urutan Soal untuk Setiap Responden' },
                                        { key: 'oneResponse', label: 'Batasi 1 Kali Pengisian per Responden/Sesi' },
                                        { key: 'requiredLogin', label: 'Wajib Login Akun FormUp sebelum Mengisi' },
                                    ].map(({ key, label }) => (
                                        <label key={key} className="flex items-center gap-3 cursor-pointer">
                                            <input
                                                type="checkbox"
                                                checked={settings[key]}
                                                onChange={e => setSettings(s => ({ ...s, [key]: e.target.checked }))}
                                                className="w-4 h-4 text-[#00897B] rounded cursor-pointer"
                                            />
                                            <span className="text-xs font-bold text-slate-700 dark:text-slate-300">{label}</span>
                                        </label>
                                    ))}
                                </div>

                                {/* B-1: Exam Mode Settings */}
                                <div className="pt-4 border-t border-slate-100 dark:border-slate-800 space-y-3">
                                    <div className="flex items-center gap-2 mb-2">
                                        <ShieldAlert size={15} className="text-red-500" />
                                        <h3 className="text-xs font-extrabold text-slate-900 dark:text-white uppercase tracking-wider">Mode Ujian</h3>
                                        <span className="text-[10px] px-1.5 py-0.5 bg-red-50 dark:bg-red-950/60 text-red-600 dark:text-red-400 rounded font-bold">Experimental</span>
                                    </div>
                                    <label className="flex items-center gap-3 cursor-pointer">
                                        <input type="checkbox" checked={settings.isExamMode} onChange={e => setSettings(s => ({ ...s, isExamMode: e.target.checked }))} className="w-4 h-4 text-red-500 rounded cursor-pointer" />
                                        <span className="text-xs font-bold text-slate-700 dark:text-slate-300">Aktifkan Mode Ujian</span>
                                    </label>
                                    {settings.isExamMode && (
                                        <div className="ml-7 space-y-2.5 p-3 bg-red-50/60 dark:bg-red-950/20 rounded-xl border border-red-100 dark:border-red-900/40">
                                            <label className="flex items-center gap-3 cursor-pointer">
                                                <input type="checkbox" checked={settings.disableCopyPaste} onChange={e => setSettings(s => ({ ...s, disableCopyPaste: e.target.checked }))} className="w-4 h-4 text-red-500 rounded cursor-pointer" />
                                                <span className="text-xs font-medium text-slate-700 dark:text-slate-300">Nonaktifkan Copy-Paste & Klik Kanan</span>
                                            </label>
                                            <label className="flex items-center gap-3 cursor-pointer">
                                                <input type="checkbox" checked={settings.detectTabSwitch} onChange={e => setSettings(s => ({ ...s, detectTabSwitch: e.target.checked }))} className="w-4 h-4 text-red-500 rounded cursor-pointer" />
                                                <span className="text-xs font-medium text-slate-700 dark:text-slate-300">Deteksi Pindah Tab / Minimize</span>
                                            </label>
                                            {settings.detectTabSwitch && (
                                                <div className="space-y-2 ml-7">
                                                    <label className="flex items-center gap-3 cursor-pointer">
                                                        <input type="checkbox" checked={settings.autoSubmitOnTabSwitch} onChange={e => setSettings(s => ({ ...s, autoSubmitOnTabSwitch: e.target.checked }))} className="w-4 h-4 text-red-500 rounded cursor-pointer" />
                                                        <span className="text-xs font-medium text-slate-700 dark:text-slate-300">Auto-Submit Saat Melewati Batas Pelanggaran</span>
                                                    </label>
                                                    <div className="flex items-center gap-2">
                                                        <label className="text-xs font-medium text-slate-600 dark:text-slate-400 whitespace-nowrap">Maks. Pelanggaran:</label>
                                                        <input type="number" min="1" max="20" value={settings.maxTabSwitch} onChange={e => setSettings(s => ({ ...s, maxTabSwitch: parseInt(e.target.value) || 3 }))} className="w-16 border border-slate-200 dark:border-slate-700 rounded-lg px-2 py-1 text-xs font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-red-400" />
                                                        <span className="text-xs text-slate-400">kali sebelum otomatis dikumpulkan</span>
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    )}
                                </div>

                                {/* B-2: Custom Theme */}
                                <div className="pt-4 border-t border-slate-100 dark:border-slate-800 space-y-3">
                                    <div className="flex items-center gap-2 mb-2">
                                        <Palette size={15} className="text-indigo-500" />
                                        <h3 className="text-xs font-extrabold text-slate-900 dark:text-white uppercase tracking-wider">Tema Form (Warna Kustom)</h3>
                                    </div>
                                    <p className="text-[11px] text-slate-400 dark:text-slate-500">Warna ini diterapkan pada tampilan form saat diisi oleh responden.</p>
                                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                        <div>
                                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Warna Utama (Tombol, Aksen)</label>
                                            <div className="flex items-center gap-2">
                                                <input type="color" value={settings.themePrimaryColor || '#00897B'} onChange={e => setSettings(s => ({ ...s, themePrimaryColor: e.target.value }))} className="w-10 h-10 rounded-xl border border-slate-200 dark:border-slate-700 cursor-pointer p-0.5 bg-white dark:bg-slate-800" />
                                                <input type="text" value={settings.themePrimaryColor} onChange={e => setSettings(s => ({ ...s, themePrimaryColor: e.target.value }))} placeholder="#00897B" maxLength={7} className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
                                                {settings.themePrimaryColor && <button type="button" onClick={() => setSettings(s => ({ ...s, themePrimaryColor: '' }))} className="text-slate-400 hover:text-red-500 cursor-pointer"><X size={14} /></button>}
                                            </div>
                                        </div>
                                        <div>
                                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Warna Latar Belakang Form</label>
                                            <div className="flex items-center gap-2">
                                                <input type="color" value={settings.themeBackgroundColor || '#F4F8F7'} onChange={e => setSettings(s => ({ ...s, themeBackgroundColor: e.target.value }))} className="w-10 h-10 rounded-xl border border-slate-200 dark:border-slate-700 cursor-pointer p-0.5 bg-white dark:bg-slate-800" />
                                                <input type="text" value={settings.themeBackgroundColor} onChange={e => setSettings(s => ({ ...s, themeBackgroundColor: e.target.value }))} placeholder="#F4F8F7" maxLength={7} className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-2 text-xs font-mono font-bold bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-[#00897B]" />
                                                {settings.themeBackgroundColor && <button type="button" onClick={() => setSettings(s => ({ ...s, themeBackgroundColor: '' }))} className="text-slate-400 hover:text-red-500 cursor-pointer"><X size={14} /></button>}
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div className="pt-4 border-t border-slate-100 dark:border-slate-800 flex justify-end">
                                    <button
                                        type="button"
                                        onClick={handleSaveSettings}
                                        disabled={saving}
                                        className="px-5 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl shadow-xs transition-all flex items-center gap-2 cursor-pointer disabled:opacity-60"
                                    >
                                        <Save size={14} />
                                        <span>{saving ? 'Menyimpan...' : 'Simpan Pengaturan'}</span>
                                    </button>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ── SHARE TAB ── */}
                    {activeTab === 'share' && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 space-y-6 shadow-xs">
                            <h2 className="text-sm font-extrabold text-slate-900 dark:text-white border-b border-slate-100 dark:border-slate-800 pb-3">
                                Bagikan Tautan & Kode QR Formulir
                            </h2>

                            <div className="space-y-4">
                                <div>
                                    <label className="text-xs font-bold text-slate-600 dark:text-slate-400 block mb-1">Tautan Publik Formulir</label>
                                    <div className="flex items-center gap-2">
                                        <input
                                            type="text"
                                            readOnly
                                            value={`${FRONTEND_BASE_URL}/f/${form?.formLink}`}
                                            className="flex-1 border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-mono font-bold bg-slate-50 dark:bg-slate-800 text-slate-800 dark:text-slate-100"
                                        />
                                        <button
                                            onClick={() => {
                                                navigator.clipboard.writeText(`${FRONTEND_BASE_URL}/f/${form?.formLink}`);
                                                setCopiedLink(true);
                                                setTimeout(() => setCopiedLink(false), 2000);
                                            }}
                                            className="px-4 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white font-bold text-xs rounded-xl shadow-xs transition-all cursor-pointer"
                                        >
                                            {copiedLink ? '✓ Tersalin!' : 'Salin Tautan'}
                                        </button>
                                    </div>
                                </div>

                                {qrBlobUrl && (
                                    <div className="pt-4 border-t border-slate-100 dark:border-slate-800 flex flex-col items-center gap-3">
                                        <label className="text-xs font-bold text-slate-600 dark:text-slate-400 block">Kode QR Gambar PNG</label>
                                        <img src={qrBlobUrl} alt="Kode QR" className="w-44 h-44 border border-slate-200 dark:border-slate-700 rounded-2xl p-2 bg-white shadow-xs" />
                                        <a
                                            href={qrBlobUrl}
                                            download={`qr-${form?.formLink}.png`}
                                            className="px-4 py-2 bg-slate-900 hover:bg-slate-800 dark:bg-slate-700 dark:hover:bg-slate-600 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-xs transition-all"
                                        >
                                            <Download size={13} /> Unduh Kode QR PNG
                                        </a>
                                    </div>
                                )}
                            </div>
                        </div>
                    )}

                </div>
            </div>

            {/* A-7: Bulk Revise Preview Modal */}
            {bulkRevisePreviewOpen && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-black/50 backdrop-blur-xs" onClick={() => setBulkRevisePreviewOpen(false)} />
                    <div className="relative bg-white dark:bg-slate-900 w-full max-w-2xl max-h-[85vh] rounded-3xl shadow-2xl flex flex-col overflow-hidden border border-slate-200 dark:border-slate-800 z-10">
                        <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
                            <h3 className="text-sm font-extrabold text-slate-900 dark:text-white flex items-center gap-2"><Wand2 size={16} className="text-purple-600" /> Preview Hasil Revisi AI ({bulkRevisePreview.length} soal)</h3>
                            <button type="button" onClick={() => setBulkRevisePreviewOpen(false)} className="p-1 text-slate-400 hover:text-slate-700 cursor-pointer"><X size={18} /></button>
                        </div>
                        <div className="flex-1 overflow-y-auto p-5 space-y-4">
                            {bulkRevisePreview.map(({ idx, original, revised }) => (
                                <div key={idx} className="border border-slate-200 dark:border-slate-700 rounded-2xl overflow-hidden">
                                    <div className="p-3 bg-slate-50 dark:bg-slate-800 text-xs text-slate-500">Soal #{idx + 1} — Original</div>
                                    <div className="p-3 text-xs text-slate-700 dark:text-slate-300">{(original.question || '').replace(/<[^>]*>/g,'')}</div>
                                    <div className="p-3 bg-purple-50 dark:bg-purple-950/30 text-xs text-slate-500 border-t border-slate-100 dark:border-slate-700">Hasil Revisi AI</div>
                                    <div className="p-3 text-xs font-bold text-slate-900 dark:text-white">{(revised.question || '').replace(/<[^>]*>/g,'')}</div>
                                    <div className="p-3 border-t border-slate-100 dark:border-slate-700 flex gap-2">
                                        <button type="button" onClick={() => { applyBulkReviseItem(idx, revised); setBulkRevisePreview(prev => prev.filter(p => p.idx !== idx)); if (bulkRevisePreview.length <= 1) { setBulkRevisePreviewOpen(false); setBulkReviseMode(false); showToast('Revisi berhasil diterapkan!'); } }} className="px-3 py-1.5 bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold rounded-xl cursor-pointer">Terapkan</button>
                                        <button type="button" onClick={() => setBulkRevisePreview(prev => prev.filter(p => p.idx !== idx))} className="px-3 py-1.5 border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 text-xs font-bold rounded-xl cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800">Lewati</button>
                                    </div>
                                </div>
                            ))}
                        </div>
                        <div className="p-4 border-t border-slate-100 dark:border-slate-800 flex justify-between">
                            <button type="button" onClick={() => { bulkRevisePreview.forEach(({ idx, revised }) => applyBulkReviseItem(idx, revised)); setBulkRevisePreviewOpen(false); setBulkReviseMode(false); showToast(`${bulkRevisePreview.length} soal berhasil direvisi!`); }} className="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold rounded-xl cursor-pointer">Terapkan Semua</button>
                            <button type="button" onClick={() => setBulkRevisePreviewOpen(false)} className="px-4 py-2 border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 text-xs font-bold rounded-xl cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800">Tutup</button>
                        </div>
                    </div>
                </div>
            )}

            {/* BUG-3: ConfirmModal (replaces window.confirm) */}
            <ConfirmModal
                isOpen={confirmModal.isOpen}
                onClose={() => setConfirmModal(prev => ({ ...prev, isOpen: false }))}
                onConfirm={confirmModal.onConfirm}
                title={confirmModal.title}
                message={confirmModal.message}
                variant={confirmModal.variant || 'danger'}
                confirmText="Ya, Hapus"
            />

            {/* Modal Rumus & Kode */}
            <MathAndCodeModal
                isOpen={modalOpen}
                mode={modalMode}
                onClose={() => setModalOpen(false)}
                onInsert={handleInsertFromModal}
            />

            {/* AI Question Generator Modal */}
            <AIGeneratorModal
                isOpen={aiModalOpen}
                onClose={() => setAiModalOpen(false)}
                onAddQuestions={handleAddAIQuestions}
                formTitle={form?.title || ''}
            />

            {/* AI Form Builder Modal */}
            <AIFormBuilderModal
                isOpen={aiFormBuilderOpen}
                onClose={() => setAiFormBuilderOpen(false)}
                onFormCreated={(newId) => navigate(`/forms/${newId}/builder`)}
            />

            {/* Lightbox Modal */}
            <ImageLightboxModal
                isOpen={!!lightboxImage}
                src={lightboxImage?.src}
                alt={lightboxImage?.alt}
                onClose={() => setLightboxImage(null)}
            />

            {/* Quick Action Scroll Menu */}
            <div className={`fixed bottom-6 right-6 z-40 flex flex-col items-end gap-2 transition-all duration-300 ease-out transform ${
                scrolledPastHeader 
                    ? 'opacity-100 translate-y-0 scale-100 pointer-events-auto' 
                    : 'opacity-0 translate-y-6 scale-90 pointer-events-none'
            }`}>
                    {fabMenuOpen && (
                        <div className="bg-white dark:bg-slate-900 rounded-2xl shadow-2xl border border-slate-200 dark:border-slate-800 p-2.5 flex flex-col gap-1.5 w-56 animate-in zoom-in-95 duration-150">
                            {/* Save */}
                            <button
                                type="button"
                                onClick={() => {
                                    setFabMenuOpen(false);
                                    handleSaveAll();
                                }}
                                disabled={saving}
                                className={`flex items-center gap-2.5 px-3 py-2 text-xs font-bold rounded-xl transition-all cursor-pointer ${
                                    isDirty
                                        ? 'bg-orange-500 hover:bg-orange-600 text-white animate-pulse'
                                        : 'bg-slate-900 hover:bg-slate-800 dark:bg-slate-800 dark:hover:bg-slate-700 text-white'
                                }`}
                            >
                                <Save size={14} />
                                <span>{saving ? 'Menyimpan...' : isDirty ? '⚠ Simpan Sekarang' : 'Simpan Perubahan'}</span>
                            </button>

                            {/* Preview */}
                            <button
                                type="button"
                                onClick={() => {
                                    setFabMenuOpen(false);
                                    window.open(`/f/${form?.formLink}?preview=true&formId=${form?.id}`, '_blank');
                                }}
                                className="flex items-center gap-2.5 px-3 py-2 text-xs font-bold rounded-xl text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-all cursor-pointer"
                            >
                                <Eye size={14} className="text-teal-600 dark:text-teal-400" />
                                <span>Preview Responden</span>
                            </button>

                            {/* Publish / Draft */}
                            <button
                                type="button"
                                onClick={() => {
                                    setFabMenuOpen(false);
                                    handleTogglePublish();
                                }}
                                disabled={publishing}
                                className="flex items-center gap-2.5 px-3 py-2 text-xs font-bold rounded-xl text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-all cursor-pointer"
                            >
                                {isPublished ? <Lock size={14} className="text-amber-500" /> : <Globe size={14} className="text-teal-600 dark:text-teal-400" />}
                                <span>{publishing ? 'Memproses...' : isPublished ? 'Jadikan Draf' : 'Publikasikan'}</span>
                            </button>

                            {/* Auto-Save Toggle */}
                            <button
                                type="button"
                                onClick={() => setAutosaveEnabled(prev => !prev)}
                                className="flex items-center justify-between px-3 py-2 text-xs font-bold rounded-xl text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-all cursor-pointer"
                            >
                                <div className="flex items-center gap-2.5">
                                    {autosaveEnabled ? <ToggleRight size={14} className="text-teal-600 dark:text-teal-400" /> : <ToggleLeft size={14} className="text-slate-400" />}
                                    <span>Auto-Save</span>
                                </div>
                                <span className={`text-[10px] px-1.5 py-0.5 rounded font-extrabold ${autosaveEnabled ? 'bg-teal-50 text-teal-700 dark:bg-teal-950 dark:text-teal-300' : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'}`}>
                                    {autosaveEnabled ? 'ON' : 'OFF'}
                                </span>
                            </button>

                            <div className="h-px bg-slate-100 dark:bg-slate-800 my-0.5" />

                            {/* Scroll to Top */}
                            <button
                                type="button"
                                onClick={() => {
                                    setFabMenuOpen(false);
                                    if (mainScrollRef.current) {
                                        mainScrollRef.current.scrollTo({ top: 0, behavior: 'smooth' });
                                    }
                                    window.scrollTo({ top: 0, behavior: 'smooth' });
                                }}
                                className="flex items-center gap-2.5 px-3 py-2 text-xs font-semibold text-slate-500 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all cursor-pointer"
                            >
                                <ChevronUp size={14} />
                                <span>Scroll ke Atas</span>
                            </button>
                        </div>
                    )}

                    {/* FAB Main Button */}
                    <button
                        type="button"
                        onClick={() => setFabMenuOpen(prev => !prev)}
                        title="Menu Tindakan Cepat"
                        className={`relative w-12 h-12 rounded-full shadow-xl flex items-center justify-center transition-all transform hover:scale-105 active:scale-95 cursor-pointer ${
                            isDirty
                                ? 'bg-orange-500 text-white shadow-orange-500/30'
                                : 'bg-teal-600 hover:bg-teal-700 text-white shadow-teal-600/30'
                        }`}
                    >
                        {isDirty && (
                            <span className="absolute -top-1 -right-1 w-3.5 h-3.5 rounded-full bg-red-500 border-2 border-white dark:border-slate-900 animate-ping" />
                        )}
                        {isDirty && (
                            <span className="absolute -top-1 -right-1 w-3.5 h-3.5 rounded-full bg-red-500 border-2 border-white dark:border-slate-900" />
                        )}
                        {fabMenuOpen ? <X size={20} /> : <Save size={20} />}
                    </button>
                </div>
        </div>
    );
}
