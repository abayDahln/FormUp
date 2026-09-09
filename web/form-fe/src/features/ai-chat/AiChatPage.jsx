import { useState, useEffect, useRef, useMemo } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
    Sparkles, Send, Bot, User, Trash2, ArrowRight, Download,
    FileSpreadsheet, BarChart2, Loader2, AlertCircle, CheckCircle2,
    RefreshCw, ExternalLink, HelpCircle, FileText, CornerDownLeft,
    Clock, Layers, Plus, ShieldCheck, Key, CheckSquare, Square,
    Filter, ChevronRight, X, AlertTriangle, UserCheck, ShieldAlert
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import Topbar from '../../components/layout/Topbar';
import RichContentRenderer from '../../utils/RichContentRenderer';
import {
    getGeminiApiKey,
    saveGeminiApiKey,
    removeGeminiApiKey,
    AVAILABLE_MODELS
} from '../../services/aiService';
import {
    getMyForms,
    getFormById,
    getQuestions,
    getFormResponses,
    getExamMonitoring,
    getFormAnalytics,
    exportFormResponses,
    getLocalUser
} from '../../services/apiService';

export default function AiChatPage() {
    const navigate = useNavigate();
    const [user] = useState(() => getLocalUser());
    const userId = user?.id || 'guest';
    const storageKey = `formup_ai_chat_${userId}`;

    // Chat states
    const [messages, setMessages] = useState(() => {
        try {
            const saved = localStorage.getItem(storageKey);
            return saved ? JSON.parse(saved) : [];
        } catch {
            return [];
        }
    });
    const [input, setInput] = useState('');
    const [loading, setLoading] = useState(false);
    const [userForms, setUserForms] = useState([]);
    const [selectedForm, setSelectedForm] = useState(null);

    // Mention @ Autocomplete
    const [showMentionMenu, setShowMentionMenu] = useState(false);
    const [mentionFilter, setMentionFilter] = useState('');
    const [mentionCursorPos, setMentionCursorPos] = useState(0);

    // Bulk export modal / selection state
    const [showBulkModal, setShowBulkModal] = useState(false);
    const [selectedFormIdsForExport, setSelectedFormIdsForExport] = useState([]);
    const [bulkDaysFilter, setBulkDaysFilter] = useState('all'); // '1' | '3' | '7' | '30' | 'all'
    const [bulkExporting, setBulkExporting] = useState(false);
    const [bulkProgress, setBulkProgress] = useState(null);

    // API Key Drawer
    const [apiKey, setApiKey] = useState('');
    const [inputKey, setInputKey] = useState('');
    const [showKeyEditor, setShowKeyEditor] = useState(false);

    const messagesEndRef = useRef(null);
    const chatContainerRef = useRef(null);
    const inputRef = useRef(null);
    const abortControllerRef = useRef(null);

    useEffect(() => {
        const savedKey = getGeminiApiKey();
        setApiKey(savedKey);
        setInputKey(savedKey);

        // Fetch user forms for @mention and context
        getMyForms().then(res => {
            if (res.ok && Array.isArray(res.data)) {
                setUserForms(res.data);
                setSelectedFormIdsForExport(res.data.map(f => f.id));
            }
        }).catch(() => {});
    }, []);

    useEffect(() => {
        try {
            localStorage.setItem(storageKey, JSON.stringify(messages));
        } catch {}
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [messages, storageKey]);

    const handleClearHistory = () => {
        if (window.confirm('Hapus seluruh riwayat percakapan AI Assistant?')) {
            if (abortControllerRef.current) abortControllerRef.current.abort();
            setMessages([]);
            setSelectedForm(null);
            try { localStorage.removeItem(storageKey); } catch {}
        }
    };

    const handleSaveKey = (e) => {
        if (e) e.preventDefault();
        const trimmed = inputKey.trim();
        if (!trimmed) return;
        saveGeminiApiKey(trimmed);
        setApiKey(trimmed);
        setShowKeyEditor(false);
    };

    // Handle typing and @mention trigger
    const handleInputChange = (e) => {
        const val = e.target.value;
        const pos = e.target.selectionStart;
        setInput(val);

        // Check if cursor is right after an '@'
        const textBeforeCursor = val.slice(0, pos);
        const lastAtMatch = textBeforeCursor.match(/@([a-zA-Z0-9_\s]*)$/);

        if (lastAtMatch) {
            setShowMentionMenu(true);
            setMentionFilter(lastAtMatch[1].toLowerCase());
            setMentionCursorPos(pos);
        } else {
            setShowMentionMenu(false);
        }
    };

    const handleSelectMentionForm = (form) => {
        const textBeforeCursor = input.slice(0, mentionCursorPos);
        const textAfterCursor = input.slice(mentionCursorPos);
        const atIndex = textBeforeCursor.lastIndexOf('@');
        
        const newText = textBeforeCursor.slice(0, atIndex) + `@${form.title} ` + textAfterCursor;
        setInput(newText);
        setSelectedForm(form);
        setShowMentionMenu(false);
        if (inputRef.current) {
            inputRef.current.focus();
        }
    };

    // Filter forms based on bulkDaysFilter
    const filteredFormsForBulk = useMemo(() => {
        if (bulkDaysFilter === 'all') return userForms;
        const days = parseInt(bulkDaysFilter, 10);
        const cutoff = new Date();
        cutoff.setDate(cutoff.getDate() - days);
        return userForms.filter(f => f.createdAt && new Date(f.createdAt) >= cutoff);
    }, [userForms, bulkDaysFilter]);

    const toggleSelectAllBulk = () => {
        const currentFilteredIds = filteredFormsForBulk.map(f => f.id);
        const allSelected = currentFilteredIds.every(id => selectedFormIdsForExport.includes(id));
        if (allSelected) {
            setSelectedFormIdsForExport(prev => prev.filter(id => !currentFilteredIds.includes(id)));
        } else {
            setSelectedFormIdsForExport(prev => Array.from(new Set([...prev, ...currentFilteredIds])));
        }
    };

    const toggleSelectFormForBulk = (id) => {
        setSelectedFormIdsForExport(prev => 
            prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]
        );
    };

    // Single export trigger
    const handleSingleExport = async (formId, formTitle, format = 'csv') => {
        try {
            await exportFormResponses(formId, format);
            setMessages(prev => [
                ...prev,
                {
                    id: Date.now(),
                    sender: 'bot',
                    text: `Berhasil mengunduh berkas respons **"${formTitle}"** dalam format **${format.toUpperCase()}**.`,
                    timestamp: new Date().toISOString()
                }
            ]);
        } catch (err) {
            alert(`Gagal mengekspor form: ${err.message}`);
        }
    };

    // Bulk Export Functionality
    const executeBulkExport = async (targetForms, timeRangeLabel = 'Terpilih') => {
        if (targetForms.length === 0) return;
        setBulkExporting(true);
        setBulkProgress({ current: 0, total: targetForms.length, name: '' });
        setShowBulkModal(false);

        try {
            for (let i = 0; i < targetForms.length; i++) {
                const f = targetForms[i];
                setBulkProgress({ current: i + 1, total: targetForms.length, name: f.title });
                
                try {
                    await exportFormResponses(f.id, 'csv');
                } catch {}

                // Small delay to prevent browser download throttling
                await new Promise(r => setTimeout(r, 600));
            }

            setMessages(prev => [
                ...prev,
                {
                    id: Date.now(),
                    sender: 'bot',
                    text: `✅ **Bulk Export Selesai!** Berhasil mengunduh file CSV terpisah untuk **${targetForms.length} formulir** (${timeRangeLabel}).`,
                    timestamp: new Date().toISOString()
                }
            ]);
        } catch (err) {
            setMessages(prev => [
                ...prev,
                {
                    id: Date.now(),
                    sender: 'bot',
                    text: `⚠️ Terjadi kendala saat melakukan bulk export: ${err.message}`,
                    timestamp: new Date().toISOString()
                }
            ]);
        } finally {
            setBulkExporting(false);
            setBulkProgress(null);
        }
    };

    // Deep context aggregator for Gemini
    const buildDeepFormContext = async (targetForm) => {
        if (!targetForm) return '';

        try {
            const [formDetail, questionsRes, responsesRes, monitoringRes, analyticsRes] = await Promise.all([
                getFormById(targetForm.id).catch(() => ({})),
                getQuestions(targetForm.id).catch(() => ({})),
                getFormResponses(targetForm.id, { pageSize: 100 }).catch(() => ({})),
                getExamMonitoring(targetForm.id).catch(() => ({})),
                getFormAnalytics(targetForm.id).catch(() => ({}))
            ]);

            const fData = formDetail.data || targetForm;
            const qList = Array.isArray(questionsRes.data) ? questionsRes.data : [];
            const rList = Array.isArray(responsesRes.data) ? responsesRes.data : [];
            const mData = monitoringRes.data || {};
            const aData = analyticsRes.data || {};

            // 1. Scoring & Ranking statistics
            const scoredResponses = rList
                .filter(r => r.score != null && !isNaN(Number(r.score)))
                .map(r => ({
                    name: r.respondentName || r.userEmail || `Responden #${r.id}`,
                    score: Number(r.score),
                    submittedAt: r.submittedAt || '-',
                    durationMinutes: r.durationMinutes || '-',
                }))
                .sort((a, b) => b.score - a.score);

            const totalRespondents = rList.length;
            const highestScorer = scoredResponses.length > 0 ? scoredResponses[0] : null;
            const lowestScorer = scoredResponses.length > 0 ? scoredResponses[scoredResponses.length - 1] : null;
            const avgScore = scoredResponses.length > 0
                ? (scoredResponses.reduce((acc, curr) => acc + curr.score, 0) / scoredResponses.length).toFixed(1)
                : '-';

            // 2. Anti-cheating & Exam Monitoring statistics
            const sessions = Array.isArray(mData.sessions) ? mData.sessions : [];
            const tabSwitchers = sessions
                .filter(s => (s.tabSwitchCount && s.tabSwitchCount > 0) || (s.violations && s.violations.length > 0))
                .map(s => ({
                    name: s.studentName || s.respondentName || 'Siswa',
                    tabSwitches: s.tabSwitchCount || 0,
                    status: s.status || 'Active',
                    violations: (s.violations || []).map(v => `${v.eventType} pada ${v.timestamp}`).join(', ')
                }));

            // 3. Question difficulty details
            const questionStats = qList.map((q, idx) => {
                const correctOpt = q.options?.find(o => o.isCorrect)?.optionText || q.correctAnswer || '-';
                return `${idx + 1}. [Tipe: ${q.typeId === 2 ? 'PG' : q.typeId === 1 ? 'Essay' : q.typeId === 5 ? 'Benar/Salah' : 'Checkbox'}] "${q.question}" (Kunci: ${correctOpt})`;
            });

            return `
=== DATA LENGKAP FORMULIR: "${fData.title || targetForm.title}" ===
- ID: ${targetForm.id}
- Deskripsi: ${fData.description || '-'}
- Status: ${fData.status || 'Published'}
- Total Pertanyaan: ${qList.length} butir
- Total Responden Selesai: ${totalRespondents} orang

--- STATISTIK SKOR & PERINGKAT RESPONDEN ---
- Nilai Rata-rata: ${avgScore}
- Nilai Tertinggi: ${highestScorer ? `${highestScorer.name} (Skor: ${highestScorer.score})` : 'Belum ada data nilai'}
- Nilai Terendah: ${lowestScorer ? `${lowestScorer.name} (Skor: ${lowestScorer.score})` : 'Belum ada data nilai'}
- Daftar Lengkap Ranking Responden:
${scoredResponses.length > 0 
    ? scoredResponses.map((r, i) => `  ${i + 1}. ${r.name} - Skor: ${r.score} (Selesai: ${r.submittedAt})`).join('\n')
    : '  (Belum ada respons dengan nilai terhitung)'}

--- MONITORING UJIAN & LOG PELANGGARAN (TAB SWITCH / KECURANGAN) ---
- Total Peserta Ujian Sedang Berlangsung: ${mData.inProgressCount || 0}
- Log Pelanggaran & Pindah Tab Siswa:
${tabSwitchers.length > 0 
    ? tabSwitchers.map(s => `  * ${s.name}: ${s.tabSwitches}x pindah tab / alt-tab | Status: ${s.status} ${s.violations ? `| Log: ${s.violations}` : ''}`).join('\n')
    : '  * Tidak ada kecurangan atau pelanggaran pindah tab yang terdeteksi.'}

--- DAFTAR BUTIR SOAL & KUNCI JAWABAN ---
${questionStats.join('\n')}
`;
        } catch (err) {
            return `
=== DATA FORMULIR: "${targetForm.title}" ===
Gagal memuat detail mendalam: ${err.message}.
`;
        }
    };

    const handleSendMessage = async (e) => {
        if (e) e.preventDefault();
        const query = input.trim();
        if (!query || loading) return;

        const curKey = (apiKey || getGeminiApiKey()).trim();
        if (!curKey) {
            setShowKeyEditor(true);
            return;
        }

        // Auto-detect target form if mentioned in query or if single form exists
        let activeTargetForm = selectedForm;
        if (!activeTargetForm) {
            const matched = userForms.find(f => 
                query.toLowerCase().includes(f.title.toLowerCase())
            );
            if (matched) {
                activeTargetForm = matched;
                setSelectedForm(matched);
            } else if (userForms.length === 1 && (query.toLowerCase().includes('form') || query.toLowerCase().includes('kuis') || query.toLowerCase().includes('nilai') || query.toLowerCase().includes('curang'))) {
                activeTargetForm = userForms[0];
            }
        }

        const userMsg = {
            id: Date.now(),
            sender: 'user',
            text: query,
            formContext: activeTargetForm ? { id: activeTargetForm.id, title: activeTargetForm.title } : null,
            timestamp: new Date().toISOString()
        };

        setMessages(prev => [...prev, userMsg]);
        setInput('');
        setShowMentionMenu(false);
        setLoading(true);

        const lowerQuery = query.toLowerCase();

        // ── INTENT 1: EXPORT INTENT (SINGLE OR BULK) ────────────────────────
        const isExportIntent = lowerQuery.includes('export') || lowerQuery.includes('ekspor') || lowerQuery.includes('unduh') || lowerQuery.includes('download');
        const isBulk = lowerQuery.includes('7 hari') || lowerQuery.includes('3 hari') || lowerQuery.includes('bulk') || lowerQuery.includes('semua form') || lowerQuery.includes('semua formulir');

        if (isExportIntent) {
            if (isBulk || (!activeTargetForm && userForms.length > 0)) {
                // Show bulk export selector modal / action card
                setMessages(prev => [
                    ...prev,
                    {
                        id: Date.now() + 1,
                        sender: 'bot',
                        text: `Berikut opsi **Bulk Export Respons**. Anda dapat memilih formulir yang ingin diunduh atau memfilter berdasarkan rentang waktu pengerjaan:`,
                        actionCard: {
                            type: 'bulk_selector',
                            totalForms: userForms.length
                        },
                        timestamp: new Date().toISOString()
                    }
                ]);
                setShowBulkModal(true);
                setLoading(false);
                return;
            } else if (activeTargetForm) {
                // Single form download action card
                setMessages(prev => [
                    ...prev,
                    {
                        id: Date.now() + 1,
                        sender: 'bot',
                        text: `Siap! Anda dapat langsung mengunduh rekapitulasi data respons untuk **"${activeTargetForm.title}"** melalui tombol di bawah:`,
                        actionCard: {
                            type: 'single_export',
                            form: activeTargetForm
                        },
                        timestamp: new Date().toISOString()
                    }
                ]);
                setLoading(false);
                return;
            }
        }

        // ── INTENT 2: OUT-OF-SCOPE REDIRECTS (FORM BUILDER / EDIT / CREATE) ──
        const isEditQuestion = (lowerQuery.includes('edit soal') || lowerQuery.includes('ubah soal') || lowerQuery.includes('tambah opsi') || lowerQuery.includes('revisi soal')) && (activeTargetForm || userForms.length > 0);
        const isCreateNewFormIntent = lowerQuery.includes('buat form') || lowerQuery.includes('bikin form') || lowerQuery.includes('buat kuis') || lowerQuery.includes('bikin kuis');

        if (isEditQuestion) {
            const target = activeTargetForm || userForms[0];
            setMessages(prev => [
                ...prev,
                {
                    id: Date.now() + 1,
                    sender: 'bot',
                    text: `Untuk merevisi atau menambah butir soal pada formulir **"${target.title}"**, Anda dapat langsung membukanya di **Form Builder** visual:`,
                    redirectAction: {
                        label: `Buka Form Builder: ${target.title}`,
                        path: `/forms/${target.id}/edit`,
                        icon: 'edit'
                    },
                    timestamp: new Date().toISOString()
                }
            ]);
            setLoading(false);
            return;
        }

        if (isCreateNewFormIntent && !lowerQuery.includes('rekomendasi') && !lowerQuery.includes('ide') && !lowerQuery.includes('contoh')) {
            setMessages(prev => [
                ...prev,
                {
                    id: Date.now() + 1,
                    sender: 'bot',
                    text: `Anda dapat membuat formulir baru secara manual atau otomatis menggunakan generator cerdas AI. Silakan pilih opsi:`,
                    redirectAction: {
                        label: 'Buka Dashboard FormUp',
                        path: '/dashboard',
                        icon: 'plus'
                    },
                    timestamp: new Date().toISOString()
                }
            ]);
            setLoading(false);
            return;
        }

        // ── INTENT 3: DEEP ANALYTICS & SSE STREAMING WITH GEMINI ──────────────
        let deepContext = '';
        if (activeTargetForm) {
            deepContext = await buildDeepFormContext(activeTargetForm);
        } else {
            deepContext = `
DAFTAR FORMULIR MILIK PENGGUNA (${userForms.length} formulir):
${userForms.map((f, i) => `${i + 1}. "${f.title}" (ID: ${f.id}, Status: ${f.status || 'Active'}, Total Respons: ${f.responseCount || 0})`).join('\n')}
`;
        }

        const systemPrompt = `
PERAN: Anda adalah FormUp AI Assistant cerdas, analitis, dan ramah khusus untuk pendidik, guru, dan pembuat kuis di platform FormUp.
TUGAS ANDA:
1. Menjawab pertanyaan pengguna secara TEPAT, SPESIFIK, dan AKURAT menggunakan data formulir aktual yang disediakan di bawah ini.
2. Jika ditanya tentang nilai tertinggi/terendah/rata-rata, sebutkan nama siswa dan nilai persisnya dari data ranking.
3. Jika ditanya tentang kecurangan, siswa yang curang, atau log pindah tab, jelaskan data pelanggaran yang tertera di log monitoring.
4. Jika ditanya tentang analisis soal sulit/mudah, jelaskan berdasarkan data butir soal dan kunci jawaban.
5. Format jawaban selalu menggunakan Markdown yang rapi (gunakan **bold**, bullet points, numbered list, blockquotes).
6. Jika menuliskan rumus matematika/fisika, WAJIB gunakan format LaTeX $...$ untuk inline atau $$...$$ untuk baris terpisah.

${deepContext}
`.trim();

        // Add placeholder bot message for real-time SSE streaming
        const botMessageId = Date.now() + 1;
        setMessages(prev => [
            ...prev,
            {
                id: botMessageId,
                sender: 'bot',
                text: '',
                formContext: activeTargetForm ? { id: activeTargetForm.id, title: activeTargetForm.title } : null,
                timestamp: new Date().toISOString()
            }
        ]);

        try {
            abortControllerRef.current = new AbortController();
            const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent?key=${curKey}&alt=sse`;
            
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    contents: [
                        { role: 'user', parts: [{ text: `${systemPrompt}\n\nPertanyaan Pengguna: "${query}"` }] }
                    ],
                    generationConfig: { temperature: 0.7 }
                }),
                signal: abortControllerRef.current.signal
            });

            if (!response.ok) {
                const errData = await response.json().catch(() => ({}));
                const errMsg = errData.error?.message || `HTTP ${response.status}`;
                throw new Error(errMsg);
            }

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let accumulatedText = '';
            let buffer = '';

            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                buffer += decoder.decode(value, { stream: true });
                const lines = buffer.split('\n');
                buffer = lines.pop() || '';

                for (const line of lines) {
                    if (!line.startsWith('data: ')) continue;
                    const dataStr = line.slice(6).trim();
                    if (dataStr === '[DONE]') continue;

                    try {
                        const parsed = JSON.parse(dataStr);
                        const chunk = parsed.candidates?.[0]?.content?.parts?.[0]?.text || '';
                        if (chunk) {
                            accumulatedText += chunk;
                            setMessages(prev =>
                                prev.map(msg =>
                                    msg.id === botMessageId
                                        ? { ...msg, text: accumulatedText }
                                        : msg
                                )
                            );
                        }
                    } catch {}
                }
            }

            if (!accumulatedText.trim()) {
                setMessages(prev =>
                    prev.map(msg =>
                        msg.id === botMessageId
                            ? { ...msg, text: 'Maaf, saya tidak dapat merumuskan tanggapan untuk pertanyaan tersebut.' }
                            : msg
                    )
                );
            }
        } catch (err) {
            if (err.name !== 'AbortError') {
                setMessages(prev =>
                    prev.map(msg =>
                        msg.id === botMessageId
                            ? { ...msg, text: `Terjadi kendala saat menghubungi AI: ${err.message}. Periksa koneksi atau API Key Anda.` }
                            : msg
                    )
                );
            }
        } finally {
            setLoading(false);
            abortControllerRef.current = null;
        }
    };

    const filteredMentionForms = userForms.filter(f =>
        (f.title || '').toLowerCase().includes(mentionFilter)
    );

    return (
        <div className="flex h-screen bg-[#F4F8F7] dark:bg-slate-950 font-sans overflow-hidden">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 h-screen overflow-hidden">
                <Topbar />

                <main className="flex-1 flex flex-col min-h-0 w-full overflow-hidden p-3 sm:p-6">
                    {/* Header bar */}
                    <div className="flex items-center justify-between pb-3 border-b border-slate-200/80 dark:border-slate-800 shrink-0">
                        <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-teal-600 to-emerald-400 text-white flex items-center justify-center shadow-md shrink-0">
                                <Bot size={22} />
                            </div>
                            <div>
                                <h1 className="text-base sm:text-lg font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
                                    FormUp AI Assistant
                                    <span className="text-[10px] uppercase px-2 py-0.5 rounded-full bg-teal-100 dark:bg-teal-950 text-teal-700 dark:text-teal-300 font-extrabold tracking-wide">
                                        Gemini 2.5
                                    </span>
                                </h1>
                                <p className="text-xs text-slate-500 dark:text-slate-400 hidden sm:block">
                                    Analisis nilai responden, deteksi kecurangan, bulk export, saran evaluasi butir soal kuis.
                                </p>
                            </div>
                        </div>

                        <div className="flex items-center gap-2">
                            <button
                                type="button"
                                onClick={() => setShowBulkModal(true)}
                                className="px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-slate-700 dark:text-slate-200 hover:border-teal-500 hover:text-teal-600 transition-all cursor-pointer shadow-xs"
                            >
                                <Download size={13} className="text-teal-600" />
                                <span className="hidden sm:inline">Bulk Export</span>
                            </button>

                            <button
                                type="button"
                                onClick={() => setShowKeyEditor(!showKeyEditor)}
                                className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 border transition-all cursor-pointer ${
                                    apiKey
                                        ? 'text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 border-teal-200 dark:border-teal-800'
                                        : 'text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-950/60 border-amber-200 dark:border-amber-800'
                                }`}
                            >
                                <Key size={13} />
                                <span>{apiKey ? 'API Key Siap' : 'Atur API Key'}</span>
                            </button>

                            {messages.length > 0 && (
                                <button
                                    type="button"
                                    onClick={handleClearHistory}
                                    title="Hapus riwayat chat"
                                    className="p-2 text-slate-400 hover:text-red-500 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/40 rounded-xl transition-all cursor-pointer"
                                >
                                    <Trash2 size={16} />
                                </button>
                            )}
                        </div>
                    </div>

                    {/* API Key drawer if opened */}
                    {showKeyEditor && (
                        <div className="p-4 my-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-sm space-y-2 shrink-0">
                            <div className="flex items-center justify-between">
                                <span className="text-xs font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1.5">
                                    <ShieldCheck size={14} className="text-emerald-500" /> Masukkan Google Gemini API Key
                                </span>
                                <a
                                    href="https://aistudio.google.com/app/apikey"
                                    target="_blank"
                                    rel="noreferrer"
                                    className="text-[11px] text-teal-600 dark:text-teal-400 font-bold flex items-center gap-1 hover:underline"
                                >
                                    Dapatkan Key Gratis <ExternalLink size={11} />
                                </a>
                            </div>
                            <form onSubmit={handleSaveKey} className="flex gap-2">
                                <input
                                    type="password"
                                    value={inputKey}
                                    onChange={e => setInputKey(e.target.value)}
                                    placeholder="AIzaSy..."
                                    className="flex-1 px-3.5 py-2 bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-500 text-slate-900 dark:text-white"
                                />
                                <button
                                    type="submit"
                                    className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold cursor-pointer"
                                >
                                    Simpan
                                </button>
                            </form>
                        </div>
                    )}

                    {/* Chat Messages Container with robust wheel scroll */}
                    <div 
                        ref={chatContainerRef}
                        className="flex-1 min-h-0 overflow-y-auto overscroll-contain py-4 space-y-4 pr-1 sm:pr-2 scroll-smooth"
                    >
                        {messages.length === 0 ? (
                            <div className="h-full flex flex-col items-center justify-center text-center p-6 space-y-6">
                                <div className="w-16 h-16 rounded-3xl bg-teal-50 dark:bg-teal-950/60 text-teal-600 dark:text-teal-400 flex items-center justify-center shadow-inner">
                                    <Sparkles size={32} />
                                </div>
                                <div className="max-w-md space-y-1.5">
                                    <h3 className="text-base font-extrabold text-slate-900 dark:text-white">
                                        Ada yang bisa saya bantu hari ini?
                                    </h3>
                                    <p className="text-xs text-slate-500 dark:text-slate-400">
                                        Ketik <code className="px-1.5 py-0.5 bg-slate-200 dark:bg-slate-800 rounded font-bold text-teal-600">@nama_form</code> untuk analisis mendalam nilai responden & kecurangan, atau pilih aksi cepat berikut:
                                    </p>
                                </div>

                                {/* Suggestion Chips */}
                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-xl w-full text-left">
                                    <button
                                        type="button"
                                        onClick={() => setInput('Siapa responden yang mendapatkan nilai tertinggi dan nilai terendah di form ini?')}
                                        className="p-3.5 bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-2xl hover:border-teal-500 hover:bg-teal-50/30 dark:hover:bg-teal-950/30 transition-all cursor-pointer group space-y-1 shadow-xs"
                                    >
                                        <div className="flex items-center gap-2 text-xs font-bold text-slate-800 dark:text-slate-200 group-hover:text-teal-600">
                                            <UserCheck size={14} className="text-teal-500" />
                                            <span>Nilai Tertinggi & Ranking</span>
                                        </div>
                                        <p className="text-[11px] text-slate-400">Analisis peraih skor terbaik & distribusi nilai</p>
                                    </button>

                                    <button
                                        type="button"
                                        onClick={() => setInput('Siapa saja responden yang terdeteksi melakukan pelanggaran atau sering pindah tab saat ujian?')}
                                        className="p-3.5 bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-2xl hover:border-teal-500 hover:bg-teal-50/30 dark:hover:bg-teal-950/30 transition-all cursor-pointer group space-y-1 shadow-xs"
                                    >
                                        <div className="flex items-center gap-2 text-xs font-bold text-slate-800 dark:text-slate-200 group-hover:text-teal-600">
                                            <ShieldAlert size={14} className="text-amber-500" />
                                            <span>Deteksi Kecurangan & Tab Switch</span>
                                        </div>
                                        <p className="text-[11px] text-slate-400">Log alt-tab dan pelanggaran sesi ujian</p>
                                    </button>

                                    <button
                                        type="button"
                                        onClick={() => setInput('Analisis butir soal yang paling sering salah dijawab dan memiliki daya beda rendah')}
                                        className="p-3.5 bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-2xl hover:border-teal-500 hover:bg-teal-50/30 dark:hover:bg-teal-950/30 transition-all cursor-pointer group space-y-1 shadow-xs"
                                    >
                                        <div className="flex items-center gap-2 text-xs font-bold text-slate-800 dark:text-slate-200 group-hover:text-teal-600">
                                            <BarChart2 size={14} className="text-teal-500" />
                                            <span>Evaluasi Butir Soal Sulit</span>
                                        </div>
                                        <p className="text-[11px] text-slate-400">Tingkat kesulitan & rekomendasi revisi</p>
                                    </button>

                                    <button
                                        type="button"
                                        onClick={() => { setShowBulkModal(true); }}
                                        className="p-3.5 bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-2xl hover:border-teal-500 hover:bg-teal-50/30 dark:hover:bg-teal-950/30 transition-all cursor-pointer group space-y-1 shadow-xs"
                                    >
                                        <div className="flex items-center gap-2 text-xs font-bold text-slate-800 dark:text-slate-200 group-hover:text-teal-600">
                                            <Download size={14} className="text-teal-500" />
                                            <span>Bulk Export Formulir</span>
                                        </div>
                                        <p className="text-[11px] text-slate-400">Unduh CSV multi-form dengan filter rentang waktu</p>
                                    </button>
                                </div>
                            </div>
                        ) : (
                            messages.map((m) => (
                                <div
                                    key={m.id}
                                    className={`flex items-start gap-3 ${
                                        m.sender === 'user' ? 'justify-end' : 'justify-start'
                                    }`}
                                >
                                    {m.sender === 'bot' && (
                                        <div className="w-8 h-8 rounded-xl bg-teal-600 text-white flex items-center justify-center shrink-0 mt-1 shadow-xs">
                                            <Bot size={16} />
                                        </div>
                                    )}

                                    <div
                                        className={`max-w-[90%] sm:max-w-[80%] rounded-2xl p-4 text-xs sm:text-sm shadow-xs space-y-2 leading-relaxed ${
                                            m.sender === 'user'
                                                ? 'bg-teal-600 text-white rounded-tr-xs'
                                                : 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 border border-slate-200/80 dark:border-slate-800 rounded-tl-xs'
                                        }`}
                                    >
                                        {/* Form Context Tag if available */}
                                        {m.formContext && (
                                            <div className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md bg-teal-500/20 text-[10px] font-bold">
                                                <FileText size={10} />
                                                <span>@{m.formContext.title}</span>
                                            </div>
                                        )}

                                        {/* Message Body with Rich Formatting */}
                                        <div className="leading-relaxed">
                                            {m.text ? (
                                                <RichContentRenderer content={m.text} />
                                            ) : (
                                                <div className="flex items-center gap-2 text-xs text-slate-400">
                                                    <Loader2 size={14} className="animate-spin text-teal-600" />
                                                    <span>Menulis tanggapan...</span>
                                                </div>
                                            )}
                                        </div>

                                        {/* Action Card for Single Export */}
                                        {m.actionCard?.type === 'single_export' && m.actionCard.form && (
                                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800 flex flex-wrap gap-2">
                                                <button
                                                    type="button"
                                                    onClick={() => handleSingleExport(m.actionCard.form.id, m.actionCard.form.title, 'csv')}
                                                    className="px-3 py-2 bg-teal-50 dark:bg-teal-950/60 hover:bg-teal-100 text-teal-700 dark:text-teal-300 border border-teal-200 dark:border-teal-800 rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer"
                                                >
                                                    <Download size={13} />
                                                    <span>Unduh Format CSV</span>
                                                </button>
                                                <button
                                                    type="button"
                                                    onClick={() => handleSingleExport(m.actionCard.form.id, m.actionCard.form.title, 'xlsx')}
                                                    className="px-3 py-2 bg-emerald-50 dark:bg-emerald-950/60 hover:bg-emerald-100 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800 rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer"
                                                >
                                                    <FileSpreadsheet size={13} />
                                                    <span>Unduh Format Excel (XLSX)</span>
                                                </button>
                                            </div>
                                        )}

                                        {/* Action Card for Bulk Selector */}
                                        {m.actionCard?.type === 'bulk_selector' && (
                                            <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                                <button
                                                    type="button"
                                                    onClick={() => setShowBulkModal(true)}
                                                    className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold flex items-center gap-2 cursor-pointer shadow-xs"
                                                >
                                                    <Download size={13} />
                                                    <span>Buka Menu Bulk Export ({userForms.length} Formulir)</span>
                                                </button>
                                            </div>
                                        )}

                                        {/* Redirect CTA Action Button if suggested by bot */}
                                        {m.redirectAction && (
                                            <div className="pt-2">
                                                <Link
                                                    to={m.redirectAction.path}
                                                    className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800 text-teal-700 dark:text-teal-300 text-xs font-bold hover:bg-teal-100 transition-all"
                                                >
                                                    <span>{m.redirectAction.label}</span>
                                                    <ArrowRight size={13} />
                                                </Link>
                                            </div>
                                        )}
                                    </div>

                                    {m.sender === 'user' && (
                                        <div className="w-8 h-8 rounded-xl bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-200 flex items-center justify-center shrink-0 mt-1">
                                            <User size={16} />
                                        </div>
                                    )}
                                </div>
                            ))
                        )}

                        {bulkExporting && bulkProgress && (
                            <div className="p-4 bg-teal-50 dark:bg-teal-950/50 border border-teal-200 dark:border-teal-800 rounded-2xl flex items-center gap-3 shrink-0">
                                <Loader2 size={20} className="animate-spin text-teal-600 shrink-0" />
                                <div className="flex-1 min-w-0">
                                    <p className="text-xs font-bold text-teal-900 dark:text-teal-100">
                                        Mengunduh CSV ({bulkProgress.current}/{bulkProgress.total}): {bulkProgress.name}
                                    </p>
                                    <div className="w-full bg-teal-200/60 dark:bg-teal-900/60 h-1.5 rounded-full mt-1.5 overflow-hidden">
                                        <div
                                            className="bg-teal-600 h-full transition-all duration-300 rounded-full"
                                            style={{ width: `${(bulkProgress.current / bulkProgress.total) * 100}%` }}
                                        />
                                    </div>
                                </div>
                            </div>
                        )}

                        <div ref={messagesEndRef} />
                    </div>

                    {/* Mention @ Popover Menu */}
                    {showMentionMenu && filteredMentionForms.length > 0 && (
                        <div className="mb-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-xl p-2 max-h-48 overflow-y-auto space-y-1 shrink-0 z-20">
                            <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider px-2 py-1">
                                Pilih Formulir Terkait:
                            </p>
                            {filteredMentionForms.map(f => (
                                <button
                                    key={f.id}
                                    type="button"
                                    onClick={() => handleSelectMentionForm(f)}
                                    className="w-full text-left px-3 py-2 text-xs font-bold text-slate-800 dark:text-slate-200 hover:bg-teal-50 dark:hover:bg-teal-950/40 rounded-xl flex items-center justify-between transition-colors cursor-pointer"
                                >
                                    <span className="truncate">{f.title}</span>
                                    <span className="text-[10px] text-slate-400 font-normal shrink-0 ml-2">
                                        {f.responseCount || 0} respons
                                    </span>
                                </button>
                            ))}
                        </div>
                    )}

                    {/* Active Form Pin Badge */}
                    {selectedForm && (
                        <div className="mb-2 flex items-center gap-2 px-3 py-1.5 bg-teal-50 dark:bg-teal-950/40 border border-teal-200 dark:border-teal-800 rounded-xl w-fit text-xs shrink-0">
                            <FileText size={12} className="text-teal-600" />
                            <span className="text-slate-700 dark:text-slate-300">
                                Konteks aktif: <b className="text-teal-700 dark:text-teal-300">{selectedForm.title}</b>
                            </span>
                            <button
                                type="button"
                                onClick={() => setSelectedForm(null)}
                                className="text-slate-400 hover:text-red-500 font-bold ml-1 cursor-pointer"
                            >
                                ×
                            </button>
                        </div>
                    )}

                    {/* Input Bar */}
                    <form onSubmit={handleSendMessage} className="relative flex items-center gap-2 pt-2 shrink-0">
                        <div className="relative flex-1">
                            <textarea
                                ref={inputRef}
                                rows={1}
                                value={input}
                                onChange={handleInputChange}
                                onKeyDown={(e) => {
                                    if (e.key === 'Enter' && !e.shiftKey) {
                                        e.preventDefault();
                                        handleSendMessage(e);
                                    }
                                }}
                                placeholder="Tanyakan ranking responden, deteksi kecurangan, atau ketik @ untuk memilih formulir..."
                                className="w-full pl-4 pr-12 py-3.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl text-xs sm:text-sm text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500 shadow-sm resize-none"
                                disabled={loading || bulkExporting}
                            />
                            <button
                                type="submit"
                                disabled={loading || !input.trim() || bulkExporting}
                                className="absolute right-2.5 top-1/2 -translate-y-1/2 p-2 bg-teal-600 hover:bg-teal-700 text-white rounded-xl transition-all cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed shadow-xs"
                            >
                                <Send size={15} />
                            </button>
                        </div>
                    </form>
                </main>
            </div>

            {/* Bulk Export Modal with Checkboxes and Date Filters */}
            {showBulkModal && (
                <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
                    <div className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs" onClick={() => setShowBulkModal(false)} />
                    <div className="relative bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 max-w-lg w-full shadow-2xl space-y-4 z-10 max-h-[85vh] flex flex-col">
                        <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
                            <div className="flex items-center gap-2.5">
                                <div className="p-2 rounded-xl bg-teal-50 dark:bg-teal-950/60 text-teal-600">
                                    <Download size={18} />
                                </div>
                                <div>
                                    <h3 className="text-sm font-extrabold text-slate-900 dark:text-white">Bulk Export Respons Formulir</h3>
                                    <p className="text-[11px] text-slate-400">Unduh berkas CSV terpisah untuk setiap formulir yang dipilih.</p>
                                </div>
                            </div>
                            <button
                                type="button"
                                onClick={() => setShowBulkModal(false)}
                                className="p-1.5 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-xl cursor-pointer"
                            >
                                <X size={16} />
                            </button>
                        </div>

                        {/* Date Range Quick Filters */}
                        <div className="space-y-1.5">
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300">Filter Rentang Waktu Pembuatan:</label>
                            <div className="grid grid-cols-5 gap-1.5">
                                {[
                                    { key: '1', label: '1 Hari' },
                                    { key: '3', label: '3 Hari' },
                                    { key: '7', label: '7 Hari' },
                                    { key: '30', label: '30 Hari' },
                                    { key: 'all', label: 'Semua' }
                                ].map(t => (
                                    <button
                                        key={t.key}
                                        type="button"
                                        onClick={() => setBulkDaysFilter(t.key)}
                                        className={`py-1.5 text-xs font-bold rounded-xl border transition-all cursor-pointer ${
                                            bulkDaysFilter === t.key
                                                ? 'bg-teal-600 text-white border-teal-600 shadow-xs'
                                                : 'bg-slate-50 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-teal-400'
                                        }`}
                                    >
                                        {t.label}
                                    </button>
                                ))}
                            </div>
                        </div>

                        {/* Form List with Checkboxes */}
                        <div className="space-y-2 flex-1 min-h-0 flex flex-col">
                            <div className="flex items-center justify-between text-xs font-bold text-slate-600 dark:text-slate-300">
                                <span>Daftar Formulir ({filteredFormsForBulk.length}):</span>
                                <button
                                    type="button"
                                    onClick={toggleSelectAllBulk}
                                    className="text-teal-600 dark:text-teal-400 hover:underline cursor-pointer"
                                >
                                    Pilih Semua
                                </button>
                            </div>

                            <div className="flex-1 overflow-y-auto border border-slate-200 dark:border-slate-800 rounded-2xl p-2 space-y-1 divide-y divide-slate-100 dark:divide-slate-800/60 max-h-48">
                                {filteredFormsForBulk.length === 0 ? (
                                    <p className="text-center py-6 text-xs text-slate-400">Tidak ada formulir dalam rentang waktu ini.</p>
                                ) : (
                                    filteredFormsForBulk.map(f => {
                                        const isChecked = selectedFormIdsForExport.includes(f.id);
                                        return (
                                            <div
                                                key={f.id}
                                                onClick={() => toggleSelectFormForBulk(f.id)}
                                                className="flex items-center justify-between p-2 hover:bg-slate-50 dark:hover:bg-slate-800/60 rounded-xl cursor-pointer transition-colors pt-2"
                                            >
                                                <div className="flex items-center gap-2.5 min-w-0 pr-2">
                                                    {isChecked ? (
                                                        <CheckSquare size={16} className="text-teal-600 shrink-0" />
                                                    ) : (
                                                        <Square size={16} className="text-slate-400 shrink-0" />
                                                    )}
                                                    <span className="text-xs font-semibold text-slate-800 dark:text-slate-200 truncate">{f.title}</span>
                                                </div>
                                                <span className="text-[10px] text-slate-400 shrink-0">
                                                    {f.responseCount || 0} respons
                                                </span>
                                            </div>
                                        );
                                    })
                                )}
                            </div>
                        </div>

                        {/* Footer CTA */}
                        <div className="flex items-center gap-2 pt-2 border-t border-slate-100 dark:border-slate-800">
                            <button
                                type="button"
                                onClick={() => setShowBulkModal(false)}
                                className="flex-1 py-2.5 bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 text-xs font-bold rounded-xl cursor-pointer hover:bg-slate-200"
                            >
                                Batal
                            </button>
                            <button
                                type="button"
                                disabled={selectedFormIdsForExport.length === 0 || bulkExporting}
                                onClick={() => {
                                    const forms = userForms.filter(f => selectedFormIdsForExport.includes(f.id));
                                    executeBulkExport(forms, `${selectedFormIdsForExport.length} formulir terpilih`);
                                }}
                                className="flex-1 py-2.5 bg-teal-600 hover:bg-teal-700 disabled:opacity-50 text-white text-xs font-bold rounded-xl cursor-pointer flex items-center justify-center gap-2 shadow-xs"
                            >
                                <Download size={14} />
                                <span>Unduh ({selectedFormIdsForExport.length}) Formulir</span>
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}
