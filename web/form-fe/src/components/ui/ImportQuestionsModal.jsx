import { useState, useEffect, useRef } from 'react';
import {
    X,
    Upload,
    FileUp,
    Loader2,
    AlertCircle,
    CheckCircle2,
    Download,
    AlertTriangle,
    FileSpreadsheet,
    FileText,
    File
} from 'lucide-react';
import {
    previewImportQuestions,
    templateDownloadUrl
} from '../../services/apiService';

const ACCEPT_FORMATS = '.xlsx,.xls,.csv,.pdf,.docx';
const MAX_DISPLAY_ROWS = 100;

const typeNameMap = {
    1: 'Essay',
    2: 'Pilihan Ganda',
    3: 'Checkbox',
    4: 'DateTime',
    5: 'Benar/Salah',
};

function formatTypeName(typeId) {
    if (!typeId) return '-';
    if (typeof typeId === 'string' && typeId.toLowerCase in typeNameMap) return typeNameMap[typeId.toLowerCase()];
    const id = parseInt(typeId, 10);
    return typeNameMap[id] || (typeof typeId === 'string' ? typeId : `Tipe ${typeId}`);
}

function getFileIcon(fileName) {
    const ext = (fileName || '').split('.').pop().toLowerCase();
    if (['xlsx', 'xls', 'csv'].includes(ext)) return <FileSpreadsheet size={18} className="text-emerald-600" />;
    if (ext === 'docx') return <FileText size={18} className="text-blue-600" />;
    if (ext === 'pdf') return <FileText size={18} className="text-red-600" />;
    return <File size={18} className="text-slate-500" />;
}

function buildErrorMap(errors) {
    const map = new Map();
    if (!Array.isArray(errors)) return map;
    errors.forEach(err => {
        const row = err.rowNumber ?? err.row ?? err.row_number;
        if (row == null) return;
        if (!map.has(row)) map.set(row, []);
        map.get(row).push(err);
    });
    return map;
}

export default function ImportQuestionsModal({ isOpen, onClose, formId, hasResponses, onImported }) {
    const [file, setFile] = useState(null);
    const [dragOver, setDragOver] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [preview, setPreview] = useState(null);
    const [committing, setCommitting] = useState(false);
    const fileInputRef = useRef(null);

    useEffect(() => {
        if (isOpen) {
            setFile(null);
            setError(null);
            setPreview(null);
            setLoading(false);
            setCommitting(false);
        }
    }, [isOpen]);

    if (!isOpen) return null;

    const handleSelectFile = (e) => {
        const f = e.target.files?.[0];
        if (!f) return;
        setFile(f);
        setError(null);
        setPreview(null);
        void handlePreview(f);
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    const handleDrop = (e) => {
        e.preventDefault();
        setDragOver(false);
        const f = e.dataTransfer?.files?.[0];
        if (!f) return;
        setFile(f);
        setError(null);
        setPreview(null);
        void handlePreview(f);
    };

    const handlePreview = async (f) => {
        if (!formId) return;
        setLoading(true);
        setError(null);
        try {
            const res = await previewImportQuestions(formId, f);
            if (res.ok) {
                setPreview(res.data || {});
            } else {
                setError(res.message || 'Gagal memproses preview file.');
                setPreview(null);
            }
        } catch (e) {
            console.error('[Import Preview Error]:', e);
            setError('Terjadi kesalahan jaringan saat membaca file.');
            setPreview(null);
        } finally {
            setLoading(false);
        }
    };

    const handleCommit = async () => {
        if (!file || !formId) return;
        setCommitting(true);
        setError(null);
        try {
            // Preview is read-only. Return the parsed rows to the builder so
            // the normal explicit Save action remains the only commit path.
            if (typeof onImported === 'function') onImported({
                ...(preview || {}),
                questions: previewRows,
                totalImported: previewRows.length,
            });
            if (preview) {
                onClose();
            }
        } catch (e) {
            console.error('[Import Commit Error]:', e);
            setError('Terjadi kesalahan jaringan saat menyimpan hasil import.');
        } finally {
            setCommitting(false);
        }
    };

    const previewRows = (preview?.questions) ? (Array.isArray(preview.questions) ? preview.questions : Object.values(preview.questions)) : [];
    const errorMap = buildErrorMap(preview?.errors || preview?.validationErrors || []);
    const totalRows = preview?.totalRows ?? previewRows.length;
    const successCount = preview?.successCount ?? (previewRows.length - errorMap.size);
    const errorCount = preview?.errorCount ?? errorMap.size;
    const blocked = !!hasResponses;
    const canCommit = !blocked && preview && (successCount > 0) && !loading && !committing;

    return (
        <div className="fixed inset-0 z-[120] flex items-center justify-center p-4 sm:p-6 animate-fadeIn" role="dialog" aria-modal="true" aria-labelledby="import-questions-modal-title">
            <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" onClick={onClose} />
            <div className="relative z-10 w-full max-w-5xl max-h-[88vh] bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-2xl flex flex-col overflow-hidden">
                <div className="flex items-center justify-between px-5 sm:px-6 py-4 border-b border-slate-200 dark:border-slate-800">
                    <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-500 text-white flex items-center justify-center shadow-xs">
                            <Upload size={18} />
                        </div>
                        <div>
                            <h2 id="import-questions-modal-title" className="text-base sm:text-lg font-extrabold text-slate-900 dark:text-white tracking-tight">
                                Import Soal dari File
                            </h2>
                            <p className="text-[11px] text-slate-500 dark:text-slate-400">
                                Mendukung .xlsx, .xls, .csv, .pdf, .docx — preview dulu sebelum disimpan
                            </p>
                        </div>
                    </div>
                    <button
                        type="button"
                        onClick={onClose}
                        disabled={committing || loading}
                        className="p-2 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-all disabled:opacity-40 cursor-pointer"
                        title="Tutup"
                    >
                        <X size={18} />
                    </button>
                </div>

                <div className="flex-1 overflow-y-auto px-5 sm:px-6 py-4 space-y-4">
                    {error && (
                        <div className="p-3.5 bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-900/50 rounded-xl flex items-start gap-2.5 animate-fadeIn">
                            <AlertCircle size={16} className="text-red-600 dark:text-red-400 mt-0.5 shrink-0" />
                            <div className="flex-1 text-xs text-red-800 dark:text-red-300 font-medium">
                                {error}
                            </div>
                        </div>
                    )}

                    {blocked && (
                        <div className="p-3.5 bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-900/50 rounded-xl flex items-start gap-2.5 animate-fadeIn">
                            <AlertTriangle size={16} className="text-red-600 dark:text-red-400 mt-0.5 shrink-0" />
                            <div className="flex-1 text-xs text-red-800 dark:text-red-300 font-medium">
                                Formulir ini sudah memiliki <b>{hasResponses}</b> respons responden. Untuk menjaga integritas data, penambahan / import soal baru sudah dikunci. Anda dapat menduplikasi formulir ini lalu mengimpor ke salinan yang baru.
                            </div>
                        </div>
                    )}

                    <div>
                        <p className="text-[11px] font-bold text-slate-500 dark:text-slate-400 mb-2">
                            Download Template (opsional):
                        </p>
                        <div className="flex flex-wrap gap-2">
                            {['csv', 'xlsx', 'docx'].map(fmt => (
                                <a
                                    key={fmt}
                                    href={templateDownloadUrl(fmt)}
                                    download
                                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl text-[11px] font-bold transition-all"
                                >
                                    <Download size={12} />
                                    Template .{fmt.toUpperCase()}
                                </a>
                            ))}
                        </div>
                    </div>

                    <div
                        onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
                        onDragLeave={() => setDragOver(false)}
                        onDrop={handleDrop}
                        className={`border-2 border-dashed rounded-2xl p-6 sm:p-8 text-center transition-all cursor-pointer ${dragOver
                            ? 'border-blue-500 bg-blue-50 dark:bg-blue-950/30'
                            : 'border-slate-300 dark:border-slate-700 hover:border-blue-400 hover:bg-slate-50 dark:hover:bg-slate-800/50'
                        }`}
                        onClick={() => fileInputRef.current && fileInputRef.current.click()}
                    >
                        <input
                            ref={fileInputRef}
                            type="file"
                            accept={ACCEPT_FORMATS}
                            className="hidden"
                            onChange={handleSelectFile}
                            disabled={loading || committing}
                        />
                        <div className="flex flex-col items-center gap-2">
                            <div className={`w-12 h-12 rounded-2xl flex items-center justify-center ${dragOver ? 'bg-blue-500 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-400'}`}>
                                <FileUp size={22} />
                            </div>
                            <div>
                                <p className="text-xs font-bold text-slate-700 dark:text-slate-200">
                                    {file ? file.name : 'Klik untuk pilih atau drag-drop file di sini'}
                                </p>
                                <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
                                    {file ? `${(file.size / 1024).toFixed(1)} KB` : 'Format yang didukung: .xlsx, .xls, .csv, .pdf, .docx'}
                                </p>
                            </div>
                            {file && (
                                <div className="mt-2 inline-flex items-center gap-2 px-3 py-1.5 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-lg shadow-xs">
                                    {getFileIcon(file.name)}
                                    <span className="text-[11px] font-semibold text-slate-700 dark:text-slate-200">{file.name}</span>
                                </div>
                            )}
                            {loading && (
                                <div className="mt-3 inline-flex items-center gap-2 px-3 py-1.5 bg-blue-50 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-900/50 rounded-lg">
                                    <Loader2 size={13} className="animate-spin text-blue-600 dark:text-blue-400" />
                                    <span className="text-[11px] font-bold text-blue-700 dark:text-blue-300">Membaca dan memproses file...</span>
                                </div>
                            )}
                        </div>
                    </div>

                    {preview && (
                        <div className="space-y-3 pt-2 border-t border-slate-100 dark:border-slate-800 animate-fadeIn">
                            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                                <div className="p-3 bg-slate-50 dark:bg-slate-800/60 rounded-xl border border-slate-100 dark:border-slate-700">
                                    <p className="text-[10px] uppercase font-extrabold text-slate-400 tracking-wider">Total Baris</p>
                                    <p className="text-lg font-black text-slate-900 dark:text-white mt-0.5">{totalRows}</p>
                                </div>
                                <div className="p-3 bg-emerald-50 dark:bg-emerald-950/30 rounded-xl border border-emerald-100 dark:border-emerald-900/50">
                                    <p className="text-[10px] uppercase font-extrabold text-emerald-600 dark:text-emerald-400 tracking-wider">Berhasil Dibaca</p>
                                    <p className="text-lg font-black text-emerald-700 dark:text-emerald-300 mt-0.5">{successCount}</p>
                                </div>
                                <div className={`p-3 rounded-xl border ${errorCount > 0 ? 'bg-red-50 dark:bg-red-950/30 border-red-100 dark:border-red-900/50' : 'bg-slate-50 dark:bg-slate-800/60 border-slate-100 dark:border-slate-700'}`}>
                                    <p className={`text-[10px] uppercase font-extrabold tracking-wider ${errorCount > 0 ? 'text-red-600 dark:text-red-400' : 'text-slate-400'}`}>Baris Error</p>
                                    <p className={`text-lg font-black mt-0.5 ${errorCount > 0 ? 'text-red-700 dark:text-red-300' : 'text-slate-900 dark:text-white'}`}>{errorCount}</p>
                                </div>
                                <div className="p-3 bg-blue-50 dark:bg-blue-950/30 rounded-xl border border-blue-100 dark:border-blue-900/50">
                                    <p className="text-[10px] uppercase font-extrabold text-blue-600 dark:text-blue-400 tracking-wider">Akan Diimport</p>
                                    <p className="text-lg font-black text-blue-700 dark:text-blue-300 mt-0.5">{preview?.totalImported ?? successCount}</p>
                                </div>
                            </div>

                            {previewRows.length > 0 && (
                                <div className="rounded-2xl border border-slate-200 dark:border-slate-800 overflow-hidden">
                                    <div className="px-4 py-2.5 bg-slate-50 dark:bg-slate-800/60 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
                                        <p className="text-[11px] font-extrabold text-slate-700 dark:text-slate-200">
                                            Preview Hasil Parsing{previewRows.length > MAX_DISPLAY_ROWS ? ` (${MAX_DISPLAY_ROWS} dari ${previewRows.length} ditampilkan)` : ''}
                                        </p>
                                        {errorMap.size > 0 && (
                                            <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-red-100 dark:bg-red-900/40 text-red-700 dark:text-red-300 rounded-md text-[10px] font-bold">
                                                <AlertCircle size={10} /> {errorMap.size} baris bermasalah
                                            </span>
                                        )}
                                    </div>
                                    <div className="max-h-80 overflow-auto">
                                        <table className="w-full text-left border-collapse min-w-[720px]">
                                            <thead className="sticky top-0 bg-slate-100 dark:bg-slate-800 z-10">
                                                <tr>
                                                    <th className="px-3 py-2 text-[10px] font-extrabold text-slate-500 dark:text-slate-400 uppercase tracking-wider w-14">No</th>
                                                    <th className="px-3 py-2 text-[10px] font-extrabold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Soal</th>
                                                    <th className="px-3 py-2 text-[10px] font-extrabold text-slate-500 dark:text-slate-400 uppercase tracking-wider w-28">Tipe</th>
                                                    <th className="px-3 py-2 text-[10px] font-extrabold text-slate-500 dark:text-slate-400 uppercase tracking-wider w-36">Kunci Jawaban</th>
                                                    <th className="px-3 py-2 text-[10px] font-extrabold text-slate-500 dark:text-slate-400 uppercase tracking-wider w-20">Bobot</th>
                                                    <th className="px-3 py-2 text-[10px] font-extrabold text-slate-500 dark:text-slate-400 uppercase tracking-wider w-52">Catatan / Error</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {previewRows.slice(0, MAX_DISPLAY_ROWS).map((row, i) => {
                                                    const rowNum = row.rowNumber ?? row.row ?? row.row_number ?? (preview?.errors?.length ? null : (i + 1));
                                                    const hasErr = rowNum != null && errorMap.has(rowNum);
                                                    const errList = rowNum != null ? (errorMap.get(rowNum) || []) : [];
                                                    const qText = row.question ?? row.Question ?? row.questionText ?? '';
                                                    const displayQ = typeof qText === 'string' ? qText.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').slice(0, 200) : '';
                                                    const keyText = (row.correctAnswer ?? row.correct_answer ?? row.kunciJawaban ?? row.answer ?? '-');
                                                    const displayKey = Array.isArray(keyText) ? keyText.join(', ') : (typeof keyText === 'string' ? keyText.slice(0, 80) : String(keyText ?? '-'));
                                                    return (
                                                        <tr
                                                            key={row._key ?? i}
                                                            className={`border-t border-slate-100 dark:border-slate-800 ${hasErr ? 'bg-red-50 dark:bg-red-950/20' : 'hover:bg-slate-50 dark:hover:bg-slate-800/30'}`}
                                                        >
                                                            <td className="px-3 py-2 text-[11px] font-bold text-slate-500 dark:text-slate-400 align-top">
                                                                {row.questionOrder ?? row.order ?? row.rowNumber ?? i + 1}
                                                            </td>
                                                            <td className="px-3 py-2 text-[11px] text-slate-800 dark:text-slate-200 align-top">
                                                                {displayQ || <span className="text-slate-400 italic">(kosong)</span>}
                                                            </td>
                                                            <td className="px-3 py-2 text-[11px] text-slate-700 dark:text-slate-300 align-top">
                                                                {formatTypeName(row.typeId ?? row.type_id ?? row.type)}
                                                            </td>
                                                            <td className="px-3 py-2 text-[11px] text-slate-700 dark:text-slate-300 align-top font-semibold">
                                                                {displayKey}
                                                            </td>
                                                            <td className="px-3 py-2 text-[11px] text-slate-700 dark:text-slate-300 align-top">
                                                                {row.points ?? row.Points ?? row.bobot ?? row.weight ?? '-'}
                                                            </td>
                                                            <td className="px-3 py-2 align-top">
                                                                {hasErr ? (
                                                                    <div className="space-y-1">
                                                                        {errList.map((err, j) => (
                                                                            <div key={j} className="flex items-start gap-1">
                                                                                <AlertCircle size={11} className="text-red-600 dark:text-red-400 mt-0.5 shrink-0" />
                                                                                <div>
                                                                                    {err.field && <span className="font-bold text-[10px] text-red-700 dark:text-red-300">[{err.field}] </span>}
                                                                                    <span className="text-[10px] text-red-700 dark:text-red-300">{err.message || err.Message || 'Data tidak valid'}</span>
                                                                                </div>
                                                                            </div>
                                                                        ))}
                                                                    </div>
                                                                ) : (
                                                                    <div className="flex items-center gap-1 text-emerald-700 dark:text-emerald-400">
                                                                        <CheckCircle2 size={11} />
                                                                        <span className="text-[10px] font-bold">OK</span>
                                                                    </div>
                                                                )}
                                                            </td>
                                                        </tr>
                                                    );
                                                })}
                                            </tbody>
                                        </table>
                                    </div>
                                </div>
                            )}
                        </div>
                    )}
                </div>

                <div className="flex items-center justify-between gap-3 px-5 sm:px-6 py-4 border-t border-slate-200 dark:border-slate-800 bg-slate-50/70 dark:bg-slate-900/80">
                    <div className="text-[11px] text-slate-500 dark:text-slate-400">
                        {!preview ? 'Pilih file untuk melihat preview.' : 'Periksa hasil preview, klik Import Sekarang untuk menyimpan ke database.'}
                    </div>
                    <div className="flex items-center gap-2">
                        <button
                            type="button"
                            onClick={onClose}
                            disabled={committing || loading}
                            className="px-4 py-2 rounded-xl text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-800 transition-all disabled:opacity-50 cursor-pointer"
                        >
                            Batal
                        </button>
                        <button
                            type="button"
                            onClick={handleCommit}
                            disabled={!canCommit}
                            className={`px-5 py-2 rounded-xl text-xs font-bold text-white shadow-xs flex items-center gap-2 transition-all cursor-pointer ${canCommit
                                ? 'bg-gradient-to-r from-blue-600 to-indigo-500 hover:from-blue-700 hover:to-indigo-600 active:scale-[0.98]'
                                : 'bg-slate-300 dark:bg-slate-700 text-slate-500 cursor-not-allowed'
                            } disabled:cursor-not-allowed`}
                        >
                            {committing ? (
                                <>
                                    <Loader2 size={13} className="animate-spin" />
                                    Menyimpan...
                                </>
                            ) : (
                                <>
                                    <Upload size={13} />
                                    Import Sekarang
                                </>
                            )}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
