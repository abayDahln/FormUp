import { useState, useEffect } from 'react';
import {
    Sparkles, X, Loader2, Key, Check, Eye, EyeOff, ExternalLink,
    Trash2, ShieldCheck, AlertCircle, CheckCircle2, RotateCcw, Clock,
    Calculator, Code
} from 'lucide-react';
import { getGeminiApiKey, saveGeminiApiKey, removeGeminiApiKey } from '../../services/aiService';
import { createForm, saveQuestions } from '../../services/apiService';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function AIFormBuilderModal({ isOpen, onClose, onFormCreated }) {
    const [prompt, setPrompt] = useState('');
    const [includeMath, setIncludeMath] = useState(false);
    const [includeCode, setIncludeCode] = useState(false);
    const [apiKey, setApiKey] = useState('');
    const [inputKey, setInputKey] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [showKeyEditor, setShowKeyEditor] = useState(false);
    const [generating, setGenerating] = useState(false);
    const [creating, setCreating] = useState(false);
    const [error, setError] = useState('');
    const [status, setStatus] = useState('');
    const [elapsed, setElapsed] = useState(0);
    const [preview, setPreview] = useState(null);

    useEffect(() => {
        if (!isOpen) return;
        setPrompt(''); setError(''); setStatus(''); setPreview(null); setElapsed(0);
        setIncludeMath(false); setIncludeCode(false);
        const saved = getGeminiApiKey();
        setApiKey(saved); setInputKey(saved); setShowKeyEditor(!saved);
    }, [isOpen]);

    useEffect(() => {
        if (!generating) return;
        setElapsed(0);
        const timer = setInterval(() => setElapsed(prev => prev + 1), 1000);
        return () => clearInterval(timer);
    }, [generating]);

    if (!isOpen) return null;

    const handleSaveKey = (e) => {
        if (e) e.preventDefault();
        const trimmed = inputKey.trim();
        if (!trimmed) { setError('Masukkan Gemini API Key yang valid.'); return; }
        saveGeminiApiKey(trimmed); setApiKey(trimmed); setShowKeyEditor(false); setError('');
    };

    const handleGenerate = async () => {
        if (!apiKey.trim()) { setShowKeyEditor(true); setError('Masukkan API Key terlebih dahulu.'); return; }
        if (!prompt.trim()) { setError('Tulis deskripsi form yang ingin dibuat.'); return; }
        setError(''); setGenerating(true); setStatus('Menghubungkan ke Google AI Studio...');

        // A-6: Include LaTeX and code block instructions in prompt
        const mathCodeInstructions = [];
        if (includeMath) mathCodeInstructions.push('- Untuk rumus matematika/fisika, gunakan format LaTeX inline $...$ atau blok $$...$$');
        if (includeCode) mathCodeInstructions.push('- Untuk kode program, gunakan format ```bahasa\\nkode\\n```');

        const promptText = `Anda adalah asisten pembuat formulir pendidikan profesional. Berdasarkan deskripsi berikut, buat sebuah formulir lengkap beserta soal-soalnya.

Deskripsi: ${prompt.trim()}

PANDUAN FORMAT KONTEN:
${mathCodeInstructions.length > 0 ? mathCodeInstructions.join('\n') : '- Gunakan teks biasa untuk soal dan opsi jawaban.'}
- Gunakan bahasa Indonesia yang baik dan baku

ATURAN SOAL:
- typeId: 1=Essay, 2=Pilihan Ganda (4 opsi), 3=Checkbox, 5=Benar/Salah
- Pilihan Ganda (typeId 2): tepat 1 opsi isCorrect: true
- Essay (typeId 1): options boleh [], isi correctAnswer dengan contoh jawaban
- Benar/Salah (typeId 5): correctAnswer = "Benar" atau "Salah"
- Buat 5-10 soal yang relevan, bervariasi tingkat kesulitan

Kembalikan HANYA JSON valid tanpa teks pembuka/penutup:
{
  "title": "Judul Form",
  "description": "Deskripsi singkat form",
  "questions": [
    {
      "question": "Teks pertanyaan${includeMath ? ' (boleh mengandung LaTeX $...$)' : ''}${includeCode ? ' (boleh mengandung kode ```...```)' : ''}",
      "typeId": 2,
      "isRequired": true,
      "isScorable": true,
      "correctAnswer": "",
      "options": [
        {"optionText": "Pilihan A", "isCorrect": false},
        {"optionText": "Pilihan B", "isCorrect": true},
        {"optionText": "Pilihan C", "isCorrect": false},
        {"optionText": "Pilihan D", "isCorrect": false}
      ]
    }
  ]
}`;

        try {
            const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey.trim()}`;
            setStatus('AI sedang menyusun formulir dan soal-soal...');
            const resp = await fetch(endpoint, {
                method: 'POST', headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ contents: [{ parts: [{ text: promptText }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.7 } })
            });
            if (!resp.ok) {
                const err = await resp.json().catch(() => ({}));
                const msg = err.error?.message || `HTTP ${resp.status}`;
                setError(resp.status === 429 ? 'Rate limit tercapai. Coba lagi beberapa saat.' : `Gagal: ${msg}`);
                setGenerating(false); return;
            }
            const data = await resp.json();
            let text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
            text = text.trim().replace(/^```json\s*/,'').replace(/\s*```$/,'').replace(/^```\s*/,'');
            const parsed = JSON.parse(text);
            if (!parsed.title || !Array.isArray(parsed.questions)) throw new Error('Format JSON tidak valid');
            setStatus('Selesai! Tinjau sebelum membuat.');
            setPreview(parsed);
        } catch (err) {
            setError('Gagal memproses hasil AI: ' + err.message);
        } finally {
            setGenerating(false);
        }
    };

    const handleCreateForm = async () => {
        if (!preview) return;
        setCreating(true); setError('');
        try {
            const formRes = await createForm({ title: preview.title, description: preview.description || '' });
            if (!formRes.ok || !formRes.data?.id) throw new Error(formRes.message || 'Gagal membuat form');
            const newId = formRes.data.id;
            if (preview.questions && preview.questions.length > 0) {
                await saveQuestions(newId, preview.questions.map((q, i) => ({
                    typeId: parseInt(q.typeId, 10) || 2,
                    question: q.question || '',
                    questionFormat: 'text',
                    questionOrder: i + 1,
                    isRequired: q.isRequired !== false,
                    correctAnswer: q.correctAnswer || null,
                    points: null,
                    options: (q.options || []).map(o => ({ optionText: String(o.optionText || ''), isCorrect: Boolean(o.isCorrect) })),
                })));
            }
            onClose();
            if (onFormCreated) onFormCreated(newId);
        } catch (err) {
            setError('Gagal membuat form: ' + err.message);
        } finally {
            setCreating(false);
        }
    };

    const maskKey = (key) => (!key || key.length < 8) ? '****' : `${key.substring(0, 6)}...${key.substring(key.length - 4)}`;

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <div className="fixed inset-0 bg-slate-900/60 dark:bg-black/80 backdrop-blur-xs" onClick={onClose} />
            <div className="relative bg-white dark:bg-slate-900 border border-slate-200/80 dark:border-slate-800 rounded-3xl w-full max-w-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh] z-10">

                {/* Header */}
                <div className="px-6 py-4 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between bg-gradient-to-r from-teal-500/10 via-emerald-500/5 to-transparent">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-teal-600 to-emerald-400 text-white flex items-center justify-center shadow-md"><Sparkles size={20} /></div>
                        <div>
                            <h2 className="text-base font-extrabold text-slate-900 dark:text-white">Buat Form dengan AI</h2>
                            <p className="text-xs text-slate-500 dark:text-slate-400">Deskripsikan form yang ingin dibuat, AI menyusun judul, deskripsi & soal.</p>
                        </div>
                    </div>
                    <div className="flex items-center gap-1.5">
                        <button type="button" onClick={() => setShowKeyEditor(!showKeyEditor)} className={`px-2.5 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1 border transition-all cursor-pointer ${apiKey ? 'text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 border-teal-200 dark:border-teal-800' : 'text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-950/60 border-amber-200 dark:border-amber-800'}`}>
                            <Key size={12} />{apiKey ? maskKey(apiKey) : 'Atur Key'}
                        </button>
                        <button type="button" onClick={onClose} className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl cursor-pointer"><X size={18} /></button>
                    </div>
                </div>

                {showKeyEditor && (
                    <div className="p-4 bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 space-y-2">
                        <div className="flex items-center justify-between gap-2">
                            <p className="text-xs font-bold text-slate-700 dark:text-slate-200 flex items-center gap-1.5"><ShieldCheck size={13} className="text-emerald-500" /> Tersimpan hanya di browser Anda</p>
                            <a href="https://aistudio.google.com/app/apikey" target="_blank" rel="noreferrer" className="text-[11px] text-teal-600 dark:text-teal-400 font-bold flex items-center gap-1 hover:underline">Dapatkan Key Gratis <ExternalLink size={11} /></a>
                        </div>
                        <form onSubmit={handleSaveKey} className="flex gap-2">
                            <div className="relative flex-1">
                                <input type={showPassword ? 'text' : 'password'} value={inputKey} onChange={e => setInputKey(e.target.value)} placeholder="AIzaSy..." className="w-full pl-3 pr-9 py-2 bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-500 text-slate-900 dark:text-white" />
                                <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 cursor-pointer">{showPassword ? <EyeOff size={14} /> : <Eye size={14} />}</button>
                            </div>
                            <button type="submit" className="px-3 py-2 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold cursor-pointer flex items-center gap-1"><Check size={13} /> Simpan</button>
                            {apiKey && <button type="button" onClick={() => { removeGeminiApiKey(); setApiKey(''); setInputKey(''); setShowKeyEditor(true); }} className="px-2.5 py-2 border border-red-200 dark:border-red-900 text-red-500 rounded-xl text-xs cursor-pointer"><Trash2 size={13} /></button>}
                        </form>
                    </div>
                )}

                <div className="flex-1 overflow-y-auto p-6 space-y-4">
                    {error && <div className="p-3.5 bg-red-50 dark:bg-red-950/60 border border-red-200 dark:border-red-900 rounded-2xl flex items-start gap-2.5 text-xs text-red-700 dark:text-red-300"><AlertCircle size={15} className="shrink-0 mt-0.5" /><span>{error}</span></div>}

                    {!preview ? (
                        <div className="space-y-4">
                            <div className="space-y-1.5">
                                <label className="text-xs font-extrabold text-slate-800 dark:text-slate-200">Deskripsi Form yang Ingin Dibuat <span className="text-red-500">*</span></label>
                                <textarea rows={5} value={prompt} onChange={e => setPrompt(e.target.value)}
                                    placeholder="Contoh: Buat kuis 10 soal tentang Persamaan Kuadrat untuk SMA kelas 10. Sertakan soal dengan rumus LaTeX dan beberapa soal analisis HOTS."
                                    className="w-full px-4 py-3 bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-2xl text-xs text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    disabled={generating} />
                                {/* A-1: KaTeX & Code Block toggle buttons - same style as AI Question Builder */}
                                <div className="flex items-center gap-2 flex-wrap pt-1">
                                    <span className="text-[11px] text-slate-400 dark:text-slate-500 font-medium">Sertakan:</span>
                                    <button
                                        type="button"
                                        onClick={() => setIncludeMath(prev => !prev)}
                                        disabled={generating}
                                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer disabled:opacity-50 ${
                                            includeMath
                                                ? 'bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300 border-teal-300 dark:border-teal-700'
                                                : 'bg-white dark:bg-slate-800 text-slate-500 dark:text-slate-400 border-slate-200 dark:border-slate-700 hover:border-teal-300 hover:text-teal-600'
                                        }`}
                                    >
                                        <Calculator size={13} />
                                        <span>Rumus (KaTeX)</span>
                                        {includeMath && <span className="w-1.5 h-1.5 rounded-full bg-teal-500 shrink-0" />}
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => setIncludeCode(prev => !prev)}
                                        disabled={generating}
                                        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold border transition-all cursor-pointer disabled:opacity-50 ${
                                            includeCode
                                                ? 'bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border-indigo-300 dark:border-indigo-700'
                                                : 'bg-white dark:bg-slate-800 text-slate-500 dark:text-slate-400 border-slate-200 dark:border-slate-700 hover:border-indigo-300 hover:text-indigo-600'
                                        }`}
                                    >
                                        <Code size={13} />
                                        <span>Code Block</span>
                                        {includeCode && <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 shrink-0" />}
                                    </button>
                                </div>
                            </div>
                            {generating && (
                                <div className="p-4 rounded-2xl bg-teal-50 dark:bg-teal-950/50 border border-teal-200 dark:border-teal-800 flex items-center gap-3">
                                    <Loader2 size={22} className="animate-spin text-[#00897B] shrink-0" />
                                    <div>
                                        <p className="text-xs font-extrabold text-teal-900 dark:text-teal-100">{status}</p>
                                        <p className="text-[11px] text-teal-600 dark:text-teal-400 flex items-center gap-1 mt-0.5"><Clock size={11} /> {elapsed} detik</p>
                                    </div>
                                </div>
                            )}
                        </div>
                    ) : (
                        // A-8: polished preview with RichContentRenderer
                        <div className="space-y-4">
                            <div className="flex items-center justify-between">
                                <div>
                                    <p className="text-xs font-extrabold text-slate-800 dark:text-slate-200">✨ Form Siap Ditinjau</p>
                                    <p className="text-[11px] text-slate-400">{preview.questions?.length} soal dibuat</p>
                                </div>
                                <button type="button" onClick={() => setPreview(null)} className="text-xs font-bold text-teal-600 dark:text-teal-400 hover:underline flex items-center gap-1 cursor-pointer"><RotateCcw size={13} /> Buat Ulang</button>
                            </div>
                            <div className="p-4 bg-teal-50/50 dark:bg-teal-950/30 border border-teal-200/60 dark:border-teal-800/60 rounded-2xl space-y-1">
                                <p className="text-sm font-extrabold text-slate-900 dark:text-white">{preview.title}</p>
                                {preview.description && <p className="text-xs text-slate-500 dark:text-slate-400">{preview.description}</p>}
                            </div>
                            <div className="space-y-2 max-h-64 overflow-y-auto pr-1">
                                {preview.questions?.map((q, i) => {
                                    const typeLabels = { 1: 'Essay', 2: 'Pilihan Ganda', 3: 'Checkbox', 5: 'Benar/Salah' };
                                    const typeColors = { 1: 'bg-blue-50 text-blue-700 dark:bg-blue-950/50 dark:text-blue-300', 2: 'bg-teal-50 text-teal-700 dark:bg-teal-950/50 dark:text-teal-300', 3: 'bg-indigo-50 text-indigo-700 dark:bg-indigo-950/50 dark:text-indigo-300', 5: 'bg-amber-50 text-amber-700 dark:bg-amber-950/50 dark:text-amber-300' };
                                    return (
                                        <div key={i} className="p-3 bg-white dark:bg-slate-800 rounded-xl border border-slate-200/70 dark:border-slate-700 space-y-1.5">
                                            <div className="flex items-start gap-2">
                                                <span className="text-[10px] font-extrabold bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300 px-1.5 py-0.5 rounded shrink-0">{i + 1}</span>
                                                <span className={`text-[10px] font-extrabold px-1.5 py-0.5 rounded shrink-0 ${typeColors[q.typeId] || 'bg-slate-100 text-slate-600'}`}>{typeLabels[q.typeId] || 'Soal'}</span>
                                            </div>
                                            <div className="text-xs font-bold text-slate-800 dark:text-slate-100 leading-relaxed pl-2">
                                                <RichContentRenderer content={q.question} />
                                            </div>
                                            {q.options && q.options.length > 0 && (
                                                <div className="pl-2 grid grid-cols-2 gap-1">
                                                    {q.options.map((o, oi) => (
                                                        <div key={oi} className={`text-[11px] px-2 py-0.5 rounded-lg flex items-start gap-1 ${o.isCorrect ? 'bg-emerald-50 dark:bg-emerald-950/50 text-emerald-700 dark:text-emerald-300 font-bold' : 'text-slate-600 dark:text-slate-400'}`}>
                                                            <span className="shrink-0">{String.fromCharCode(65 + oi)}.</span>
                                                            <span><RichContentRenderer content={o.optionText} /></span>
                                                            {o.isCorrect && <span className="text-emerald-500 shrink-0">✓</span>}
                                                        </div>
                                                    ))}
                                                </div>
                                            )}
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}
                </div>

                <div className="px-6 py-4 bg-slate-50 dark:bg-slate-800/50 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                    <div className="text-xs text-slate-400">
                        {apiKey ? <span className="text-emerald-600 dark:text-emerald-400 font-bold flex items-center gap-1"><CheckCircle2 size={13} /> {maskKey(apiKey)}</span> : <span className="text-amber-600 font-bold">⚠ Harap atur API Key</span>}
                    </div>
                    <div className="flex items-center gap-2">
                        <button type="button" onClick={onClose} className="px-4 py-2.5 text-xs font-bold text-slate-600 dark:text-slate-400 hover:text-slate-900 rounded-xl cursor-pointer">Batal</button>
                        {!preview ? (
                            <button type="button" onClick={handleGenerate} disabled={generating || !prompt.trim()} className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold flex items-center gap-2 cursor-pointer disabled:opacity-60">
                                {generating ? <><Loader2 size={14} className="animate-spin" /> Membuat... ({elapsed}s)</> : <><Sparkles size={14} /> Generate Form</>}
                            </button>
                        ) : (
                            <button type="button" onClick={handleCreateForm} disabled={creating} className="px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white rounded-xl text-xs font-bold flex items-center gap-2 cursor-pointer disabled:opacity-60">
                                {creating ? <><Loader2 size={14} className="animate-spin" /> Membuat Form...</> : <><CheckCircle2 size={14} /> Buat Form Ini</>}
                            </button>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
