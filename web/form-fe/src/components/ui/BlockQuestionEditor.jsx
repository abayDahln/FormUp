import { useState, useEffect, useRef } from 'react';
import {
    Code, Calculator, Plus, Trash2, ChevronUp, ChevronDown,
    Type, Sparkles, Bold, Italic, Underline, Strikethrough,
    AlignLeft, AlignCenter, AlignRight, AlignJustify,
    List, ListOrdered, Quote, Link as LinkIcon, RemoveFormatting,
    Palette, Highlighter
} from 'lucide-react';
import RichContentRenderer from '../../utils/RichContentRenderer';
import VisualFormulaEditor from './VisualFormulaEditor';

const TEXT_COLORS = [
    { name: 'Default', value: 'inherit', class: 'bg-slate-800 dark:bg-slate-200' },
    { name: 'Hitam', value: '#1e293b', class: 'bg-slate-800' },
    { name: 'Merah', value: '#ef4444', class: 'bg-red-500' },
    { name: 'Hijau', value: '#10b981', class: 'bg-emerald-500' },
    { name: 'Teal', value: '#00897b', class: 'bg-[#00897b]' },
    { name: 'Biru', value: '#3b82f6', class: 'bg-blue-500' },
    { name: 'Ungu', value: '#8b5cf6', class: 'bg-purple-500' },
    { name: 'Oranye', value: '#f97316', class: 'bg-orange-500' },
];

const HIGHLIGHT_COLORS = [
    { name: 'None', value: 'transparent', class: 'bg-transparent border border-slate-300' },
    { name: 'Kuning', value: '#fef08a', class: 'bg-yellow-200' },
    { name: 'Hijau', value: '#bbf7d0', class: 'bg-green-200' },
    { name: 'Biru', value: '#bfdbfe', class: 'bg-blue-200' },
    { name: 'Pink', value: '#fbcfe8', class: 'bg-pink-200' },
    { name: 'Oranye', value: '#fed7aa', class: 'bg-orange-200' },
    { name: 'Ungu', value: '#e9d5ff', class: 'bg-purple-200' },
];

/**
 * Parse an HTML or Markdown string into structured content blocks
 */
function parseStringToBlocks(rawStr) {
    if (!rawStr || typeof rawStr !== 'string' || !rawStr.trim()) {
        return [{ id: `b_${Date.now()}_0`, type: 'text', content: '' }];
    }

    const blocks = [];
    const text = rawStr.trim();

    // Combined regex for code blocks, standalone math blocks
    const combinedRegex = /<pre><code(?: class="language-([a-zA-Z0-9_#-]+)")?>([\s\S]*?)<\/code><\/pre>|```([a-zA-Z0-9_#-]*)[ \t\r\n]*([\s\S]*?)```|<p>\$\$([\s\S]*?)\$\$<\/p>|\$\$([\s\S]+?)\$\$/gi;

    let lastIndex = 0;
    let match;

    while ((match = combinedRegex.exec(text)) !== null) {
        if (match.index > lastIndex) {
            const beforeText = text.substring(lastIndex, match.index).trim();
            if (beforeText) {
                blocks.push({
                    id: `b_${Date.now()}_${blocks.length}`,
                    type: 'text',
                    content: beforeText
                });
            }
        }

        if (match[0].startsWith('<pre') || match[0].startsWith('```')) {
            const lang = match[1] || match[3] || 'javascript';
            const code = (match[2] || match[4] || '').trim();
            blocks.push({
                id: `b_${Date.now()}_${blocks.length}`,
                type: 'code',
                language: lang,
                content: code
            });
        } else {
            const formula = (match[5] || match[6] || '').trim();
            blocks.push({
                id: `b_${Date.now()}_${blocks.length}`,
                type: 'math',
                content: formula
            });
        }

        lastIndex = match.index + match[0].length;
    }

    if (lastIndex < text.length) {
        const remaining = text.substring(lastIndex).trim();
        if (remaining) {
            blocks.push({
                id: `b_${Date.now()}_${blocks.length}`,
                type: 'text',
                content: remaining
            });
        }
    }

    return blocks.length > 0 ? blocks : [{ id: `b_${Date.now()}_0`, type: 'text', content: rawStr }];
}

/**
 * Serialize structured blocks back to standard HTML string
 */
function serializeBlocksToString(blocks) {
    if (!blocks || blocks.length === 0) return '';

    return blocks.map(b => {
        if (b.type === 'code') {
            const cleanCode = b.content ? b.content.trim() : '';
            return `<pre><code class="language-${b.language || 'javascript'}">${cleanCode}</code></pre>`;
        }
        if (b.type === 'math') {
            const formula = b.content ? b.content.trim() : '';
            return `<p>$$${formula}$$</p>`;
        }
        return b.content || '';
    }).join('\n');
}

export default function BlockQuestionEditor({ value, onChange, placeholder = 'Tuliskan isi pertanyaan...' }) {
    const [blocks, setBlocks] = useState(() => parseStringToBlocks(value));
    const [activeBlockId, setActiveBlockId] = useState(null);
    const [colorPickerOpen, setColorPickerOpen] = useState(null);
    const [highlightPickerOpen, setHighlightPickerOpen] = useState(null);
    const [visualFormulaBlockId, setVisualFormulaBlockId] = useState(null);
    const [visualFormulaValue, setVisualFormulaValue] = useState('');
    const editorRefs = useRef({});
    const lastEmittedValueRef = useRef(value);

    // Sync external value changes
    useEffect(() => {
        if (value !== lastEmittedValueRef.current) {
            lastEmittedValueRef.current = value;
            const newBlocks = parseStringToBlocks(value);
            setBlocks(newBlocks);
            newBlocks.forEach(b => {
                if (b.type === 'text' && editorRefs.current[b.id]) {
                    const el = editorRefs.current[b.id];
                    if (el && el.innerHTML !== (b.content || '') && document.activeElement !== el) {
                        el.innerHTML = b.content || '';
                    }
                }
            });
        }
    }, [value]);

    const updateBlocksAndEmit = (newBlocks) => {
        setBlocks(newBlocks);
        const serialized = serializeBlocksToString(newBlocks);
        lastEmittedValueRef.current = serialized;
        if (onChange) onChange(serialized);
    };

    const handleUpdateBlock = (id, field, val) => {
        const next = blocks.map(b => b.id === id ? { ...b, [field]: val } : b);
        updateBlocksAndEmit(next);
    };

    const handleAddBlock = (type, afterIndex = null) => {
        const newBlock = {
            id: `b_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`,
            type: type,
            language: type === 'code' ? 'javascript' : undefined,
            content: type === 'math' ? '\\frac{a}{b}' : ''
        };

        let next;
        if (afterIndex !== null && afterIndex >= 0) {
            next = [...blocks];
            next.splice(afterIndex + 1, 0, newBlock);
        } else {
            next = [...blocks, newBlock];
        }

        updateBlocksAndEmit(next);
        setActiveBlockId(newBlock.id);
    };

    const handleDeleteBlock = (id) => {
        if (blocks.length <= 1) {
            updateBlocksAndEmit([{ id: `b_${Date.now()}_0`, type: 'text', content: '' }]);
            return;
        }
        const next = blocks.filter(b => b.id !== id);
        updateBlocksAndEmit(next);
    };

    const handleMoveBlock = (index, dir) => {
        const target = index + dir;
        if (target < 0 || target >= blocks.length) return;
        const next = [...blocks];
        [next[index], next[target]] = [next[target], next[index]];
        updateBlocksAndEmit(next);
    };

    // WYSIWYG Formatting Helpers for contentEditable
    const applyFormatting = (blockId, formatType, payload = null) => {
        const editor = editorRefs.current[blockId];
        if (!editor) return;

        editor.focus();

        switch (formatType) {
            case 'bold':
                document.execCommand('bold', false, null);
                break;
            case 'italic':
                document.execCommand('italic', false, null);
                break;
            case 'underline':
                document.execCommand('underline', false, null);
                break;
            case 'strike':
                document.execCommand('strikeThrough', false, null);
                break;
            case 'color':
                document.execCommand('foreColor', false, payload === 'inherit' ? '#1e293b' : payload);
                break;
            case 'highlight':
                if (payload === 'transparent') {
                    document.execCommand('removeFormat', false, null);
                } else {
                    if (!document.execCommand('hiliteColor', false, payload)) {
                        document.execCommand('backColor', false, payload);
                    }
                }
                break;
            case 'h2':
                document.execCommand('formatBlock', false, '<h2>');
                break;
            case 'h3':
                document.execCommand('formatBlock', false, '<h3>');
                break;
            case 'small':
                document.execCommand('fontSize', false, '2');
                break;
            case 'align':
                document.execCommand('justify' + (payload === 'center' ? 'Center' : payload === 'right' ? 'Right' : payload === 'justify' ? 'Full' : 'Left'), false, null);
                break;
            case 'ul':
                document.execCommand('insertUnorderedList', false, null);
                break;
            case 'ol':
                document.execCommand('insertOrderedList', false, null);
                break;
            case 'quote':
                document.execCommand('formatBlock', false, '<blockquote>');
                break;
            case 'code':
                document.execCommand('formatBlock', false, '<pre>');
                break;
            case 'math': {
                const sel = window.getSelection();
                const selText = sel ? sel.toString() : '';
                document.execCommand('insertHTML', false, `$${selText || 'x^2'}$`);
                break;
            }
            case 'link': {
                const url = window.prompt('Masukkan alamat URL tautan (contoh: https://google.com):', 'https://');
                if (url) {
                    document.execCommand('createLink', false, url);
                }
                break;
            }
            case 'clear':
                document.execCommand('removeFormat', false, null);
                document.execCommand('formatBlock', false, '<div>');
                break;
            default:
                return;
        }

        handleUpdateBlock(blockId, 'content', editor.innerHTML);
        setColorPickerOpen(null);
        setHighlightPickerOpen(null);
    };

    return (
        <div className="border border-slate-200 dark:border-slate-800 rounded-2xl bg-slate-50/50 dark:bg-slate-900/50 p-3 sm:p-4 space-y-3 font-sans transition-colors">
            
            {/* Quick Add Toolbar */}
            <div className="flex flex-wrap items-center justify-end gap-2 pb-2.5 border-b border-slate-200/80 dark:border-slate-800">

                <div className="flex flex-wrap items-center gap-1.5">
                    <button
                        type="button"
                        onClick={() => handleAddBlock('text')}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xs transition-all cursor-pointer"
                        title="Tambah Blok Teks Bebas / WYSIWYG"
                    >
                        <Type size={13} className="text-teal-600 dark:text-teal-400" />
                        <span>+ Teks WYSIWYG</span>
                    </button>

                    <button
                        type="button"
                        onClick={() => handleAddBlock('code')}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xs transition-all cursor-pointer"
                        title="Tambah Blok Kode Terisolasi (Syntax Highlighted)"
                    >
                        <Code size={13} className="text-amber-500" />
                        <span>+ Blok Kode</span>
                    </button>

                    <button
                        type="button"
                        onClick={() => handleAddBlock('math')}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xs transition-all cursor-pointer"
                        title="Tambah Blok Rumus Matematika (KaTeX)"
                    >
                        <Calculator size={13} className="text-[#00897B] dark:text-teal-400" />
                        <span>+ Rumus KaTeX</span>
                    </button>
                </div>
            </div>

            {/* Blocks List */}
            <div className="space-y-3.5">
                {blocks.map((block, idx) => (
                    <div
                        key={block.id}
                        onClick={() => setActiveBlockId(block.id)}
                        className={`relative rounded-2xl border transition-all ${
                            activeBlockId === block.id
                                ? 'border-[#00897B] dark:border-teal-500 ring-2 ring-teal-500/20 bg-white dark:bg-slate-800 shadow-sm'
                                : 'border-slate-200 dark:border-slate-700/80 bg-white dark:bg-slate-800/80 hover:border-slate-300 dark:hover:border-slate-600'
                        } p-3.5 space-y-3`}
                    >
                        {/* Block Header Controls */}
                        <div className="flex items-center justify-between gap-2 border-b border-slate-100 dark:border-slate-700/60 pb-2 text-xs">
                            <div className="flex items-center gap-2">
                                <span className={`px-2 py-0.5 rounded-lg text-[10px] font-extrabold uppercase tracking-wider ${
                                    block.type === 'code'
                                        ? 'bg-amber-50 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-800'
                                        : block.type === 'math'
                                        ? 'bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 border border-teal-200 dark:border-teal-800'
                                        : 'bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 font-bold'
                                }`}>
                                    {block.type === 'code' ? 'Blok Kode' : block.type === 'math' ? 'Rumus KaTeX' : `Blok Teks #${idx + 1}`}
                                </span>

                                {block.type === 'code' && (
                                    <select
                                        value={block.language || 'javascript'}
                                        onChange={e => handleUpdateBlock(block.id, 'language', e.target.value)}
                                        className="text-[11px] font-bold border border-slate-200 dark:border-slate-700 rounded-lg px-2 py-0.5 bg-slate-50 dark:bg-slate-900 text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-1 focus:ring-[#00897B]"
                                    >
                                        <option value="javascript">JavaScript</option>
                                        <option value="python">Python</option>
                                        <option value="csharp">C#</option>
                                        <option value="html">HTML / CSS</option>
                                        <option value="sql">SQL</option>
                                        <option value="java">Java</option>
                                        <option value="cpp">C++</option>
                                        <option value="json">JSON</option>
                                        <option value="php">PHP</option>
                                    </select>
                                )}
                            </div>

                            <div className="flex items-center gap-1">
                                <button
                                    type="button"
                                    onClick={() => handleMoveBlock(idx, -1)}
                                    disabled={idx === 0}
                                    className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 disabled:opacity-30 cursor-pointer"
                                    title="Pindah ke Atas"
                                >
                                    <ChevronUp size={14} />
                                </button>
                                <button
                                    type="button"
                                    onClick={() => handleMoveBlock(idx, 1)}
                                    disabled={idx === blocks.length - 1}
                                    className="p-1 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 disabled:opacity-30 cursor-pointer"
                                    title="Pindah ke Bawah"
                                >
                                    <ChevronDown size={14} />
                                </button>
                                <button
                                    type="button"
                                    onClick={() => handleDeleteBlock(block.id)}
                                    className="p-1 text-red-400 hover:text-red-600 cursor-pointer"
                                    title="Hapus Blok"
                                >
                                    <Trash2 size={14} />
                                </button>
                            </div>
                        </div>

                        {/* ── 1. TEXT BLOCK WITH FULL WYSIWYG FORMATTING TOOLBAR ── */}
                        {block.type === 'text' && (
                            <div className="space-y-2">
                                
                                {/* Rich Formatting Toolbar */}
                                <div onMouseDown={e => e.preventDefault()} className="flex flex-wrap items-center gap-1 p-1.5 bg-slate-100/80 dark:bg-slate-900/80 border border-slate-200 dark:border-slate-700 rounded-xl text-slate-700 dark:text-slate-300">
                                    
                                    {/* Text Styles */}
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'bold')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
                                        title="Tebal (Bold)"
                                    >
                                        <Bold size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'italic')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
                                        title="Miring (Italic)"
                                    >
                                        <Italic size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'underline')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
                                        title="Garis Bawah (Underline)"
                                    >
                                        <Underline size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'strike')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 hover:text-slate-900 dark:hover:text-white transition-colors cursor-pointer"
                                        title="Coret (Strikethrough)"
                                    >
                                        <Strikethrough size={13} />
                                    </button>

                                    <div className="h-4 w-px bg-slate-300 dark:bg-slate-700 mx-0.5" />

                                    {/* Colors & Highlights */}
                                    <div className="relative">
                                        <button
                                            type="button"
                                            onClick={() => {
                                                setColorPickerOpen(colorPickerOpen === block.id ? null : block.id);
                                                setHighlightPickerOpen(null);
                                            }}
                                            className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 text-teal-600 dark:text-teal-400 transition-colors flex items-center gap-0.5 cursor-pointer"
                                            title="Warna Font Teks"
                                        >
                                            <Palette size={13} />
                                        </button>

                                        {colorPickerOpen === block.id && (
                                            <div className="absolute top-full left-0 mt-1 z-30 p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl shadow-xl flex gap-1.5 animate-in fade-in zoom-in-95 duration-100">
                                                {TEXT_COLORS.map(c => (
                                                    <button
                                                        key={c.name}
                                                        type="button"
                                                        onClick={() => applyFormatting(block.id, 'color', c.value)}
                                                        className={`w-5 h-5 rounded-full ${c.class} hover:scale-110 transition-transform cursor-pointer shadow-xs`}
                                                        title={c.name}
                                                    />
                                                ))}
                                            </div>
                                        )}
                                    </div>

                                    <div className="relative">
                                        <button
                                            type="button"
                                            onClick={() => {
                                                setHighlightPickerOpen(highlightPickerOpen === block.id ? null : block.id);
                                                setColorPickerOpen(null);
                                            }}
                                            className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 text-amber-500 transition-colors flex items-center gap-0.5 cursor-pointer"
                                            title="Warna Sorot (Highlight Background)"
                                        >
                                            <Highlighter size={13} />
                                        </button>

                                        {highlightPickerOpen === block.id && (
                                            <div className="absolute top-full left-0 mt-1 z-30 p-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl shadow-xl flex gap-1.5 animate-in fade-in zoom-in-95 duration-100">
                                                {HIGHLIGHT_COLORS.map(h => (
                                                    <button
                                                        key={h.name}
                                                        type="button"
                                                        onClick={() => applyFormatting(block.id, 'highlight', h.value)}
                                                        className={`w-5 h-5 rounded-full ${h.class} hover:scale-110 transition-transform cursor-pointer shadow-xs`}
                                                        title={h.name}
                                                    />
                                                ))}
                                            </div>
                                        )}
                                    </div>

                                    <div className="h-4 w-px bg-slate-300 dark:bg-slate-700 mx-0.5" />

                                    {/* Font Size & Headings */}
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'h2')}
                                        className="px-1.5 py-1 text-[11px] font-extrabold rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Judul Besar (H2)"
                                    >
                                        H2
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'h3')}
                                        className="px-1.5 py-1 text-[11px] font-extrabold rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Judul Sedang (H3)"
                                    >
                                        H3
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'small')}
                                        className="px-1.5 py-1 text-[10px] font-semibold rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Teks Kecil"
                                    >
                                        Kecil
                                    </button>

                                    <div className="h-4 w-px bg-slate-300 dark:bg-slate-700 mx-0.5" />

                                    {/* Text Alignment */}
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'align', 'left')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Rata Kiri"
                                    >
                                        <AlignLeft size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'align', 'center')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Rata Tengah"
                                    >
                                        <AlignCenter size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'align', 'right')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Rata Kanan"
                                    >
                                        <AlignRight size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'align', 'justify')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Rata Kiri Kanan (Justify)"
                                    >
                                        <AlignJustify size={13} />
                                    </button>

                                    <div className="h-4 w-px bg-slate-300 dark:bg-slate-700 mx-0.5" />

                                    {/* Lists & Inserts */}
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'ul')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Daftar Poin (Bullet List)"
                                    >
                                        <List size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'ol')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Daftar Nomor (Numbered List)"
                                    >
                                        <ListOrdered size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'quote')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Kutipan (Blockquote)"
                                    >
                                        <Quote size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'link')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 transition-colors cursor-pointer"
                                        title="Sisipkan Tautan URL"
                                    >
                                        <LinkIcon size={13} />
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'math')}
                                        className="px-2 py-1 text-[11px] font-bold text-[#00897B] dark:text-teal-400 hover:bg-white dark:hover:bg-slate-800 rounded-lg transition-colors cursor-pointer"
                                        title="Sisipkan Rumus Inline ($rumus$)"
                                    >
                                        $Rumus$
                                    </button>
                                    <button
                                        type="button"
                                        onClick={() => { setVisualFormulaValue(''); setVisualFormulaBlockId(block.id); }}
                                        className="px-2 py-1 text-[11px] font-bold text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/40 rounded-lg cursor-pointer"
                                    >
                                        Editor Rumus Visual
                                    </button>

                                    <div className="h-4 w-px bg-slate-300 dark:bg-slate-700 mx-0.5" />

                                    <button
                                        type="button"
                                        onClick={() => applyFormatting(block.id, 'clear')}
                                        className="p-1.5 rounded-lg hover:bg-white dark:hover:bg-slate-800 text-slate-400 hover:text-red-500 transition-colors cursor-pointer"
                                        title="Hapus Format (Clear Formatting)"
                                    >
                                        <RemoveFormatting size={13} />
                                    </button>
                                </div>

                                {/* Native rich-text surface: toolbar commands operate on this DOM. */}
                                <div
                                    ref={el => {
                                        editorRefs.current[block.id] = el;
                                        if (el && document.activeElement !== el && el.innerHTML !== (block.content || '')) {
                                            el.innerHTML = block.content || '';
                                        }
                                    }}
                                    contentEditable
                                    suppressContentEditableWarning
                                    role="textbox"
                                    aria-multiline="true"
                                    data-placeholder={placeholder}
                                    onInput={e => handleUpdateBlock(block.id, 'content', e.currentTarget.innerHTML)}
                                    onFocus={() => setActiveBlockId(block.id)}
                                    className="min-h-20 w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-900 focus:outline-none focus:ring-2 focus:ring-[#00897B] dark:focus:ring-teal-400 leading-relaxed transition-colors empty:before:content-[attr(data-placeholder)] empty:before:text-slate-400 dark:empty:before:text-slate-500"
                                />
                            </div>
                        )}

                        {/* ── 2. CODE BLOCK (ISOLATED) ── */}
                        {block.type === 'code' && (
                            <div className="space-y-2">
                                <div className="relative rounded-xl overflow-hidden bg-slate-950 border border-slate-800">
                                    <textarea
                                        rows={5}
                                        value={block.content || ''}
                                        onChange={e => handleUpdateBlock(block.id, 'content', e.target.value)}
                                        placeholder="// Tulis atau tempel kode sumber di sini..."
                                        className="w-full p-3 font-mono text-xs text-teal-300 bg-transparent focus:outline-none resize-y leading-relaxed"
                                        spellCheck={false}
                                    />
                                </div>
                                <div className="flex items-center justify-between text-[11px] text-slate-400 dark:text-slate-500">
                                    <span>Teks sebelum & sesudah blok kode ini terpisah secara aman tanpa tertelan.</span>
                                    <button
                                        type="button"
                                        onClick={() => handleAddBlock('text', idx)}
                                        className="text-[#00897B] dark:text-teal-400 font-bold hover:underline cursor-pointer"
                                    >
                                        + Tambah Teks di Bawah Kode
                                    </button>
                                </div>
                            </div>
                        )}

                        {/* ── 3. MATH BLOCK (KATEX) ── */}
                        {block.type === 'math' && (
                            <div className="space-y-2">
                                <div className="flex flex-wrap gap-1">
                                    {[
                                        { l: 'Pecahan', s: '\\frac{a}{b}' },
                                        { l: 'Akar √', s: '\\sqrt{x}' },
                                        { l: 'x²', s: 'x^2' },
                                        { l: 'x₁', s: 'x_1' },
                                        { l: '∑', s: '\\sum_{i=1}^n' },
                                        { l: '∫', s: '\\int_{a}^b' },
                                        { l: '±', s: '\\pm' },
                                        { l: 'π', s: '\\pi' },
                                        { l: '∞', s: '\\infty' },
                                    ].map((sym, sIdx) => (
                                        <button
                                            key={sIdx}
                                            type="button"
                                            onClick={() => handleUpdateBlock(block.id, 'content', (block.content || '') + sym.s)}
                                            className="px-2 py-0.5 bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 rounded text-[10px] font-mono font-bold text-slate-700 dark:text-slate-200 cursor-pointer"
                                        >
                                            {sym.l}
                                        </button>
                                    ))}
                                </div>
                                <textarea
                                    rows={2}
                                    value={block.content || ''}
                                    onChange={e => handleUpdateBlock(block.id, 'content', e.target.value)}
                                    placeholder="Ekspresi LaTeX, contoh: \frac{-b \pm \sqrt{b^2-4ac}}{2a}"
                                    className="w-full font-mono border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white bg-slate-50/50 dark:bg-slate-900/60 focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                />
                                <button type="button" onClick={() => { setVisualFormulaValue(block.content || ''); setVisualFormulaBlockId(block.id); }} className="px-2.5 py-1.5 rounded-lg bg-teal-50 dark:bg-teal-950/40 text-teal-700 dark:text-teal-300 text-[11px] font-bold cursor-pointer">Buka Editor Rumus Visual</button>
                                <div className="p-3 bg-teal-50/40 dark:bg-teal-950/40 border border-teal-100 dark:border-teal-900/60 rounded-xl flex items-center justify-center">
                                    <RichContentRenderer content={`$$${block.content || '...'}$$`} className="text-sm font-bold" />
                                </div>
                            </div>
                        )}
                    </div>
                ))}
            </div>

            {/* Bottom Add Bar */}
            <div className="pt-2 flex items-center justify-center gap-2 border-t border-slate-200/60 dark:border-slate-800">
                <button
                    type="button"
                    onClick={() => handleAddBlock('text')}
                    className="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all cursor-pointer"
                >
                    <Plus size={13} /> Tambah Paragraf Teks
                </button>
            </div>

            {visualFormulaBlockId && (() => {
                const target = blocks.find(b => b.id === visualFormulaBlockId);
                if (!target) return null;
                return <div className="fixed inset-0 z-50 bg-black/50 flex items-center justify-center p-4">
                    <div className="relative bg-white dark:bg-slate-900 rounded-2xl shadow-2xl w-full max-w-xl max-h-[90vh] overflow-y-auto p-5 space-y-4">
                        <div className="flex items-center justify-between"><h3 className="text-sm font-extrabold">Editor Rumus Visual</h3><button type="button" onClick={() => setVisualFormulaBlockId(null)} className="text-slate-400 cursor-pointer">✕</button></div>
                        <VisualFormulaEditor value={visualFormulaValue} onChange={setVisualFormulaValue} />
                        <button type="button" onClick={() => {
                            if (target.type === 'text') {
                                const snippet = visualFormulaValue.trim();
                                if (snippet) handleUpdateBlock(target.id, 'content', `${target.content || ''} $${snippet}$ `);
                            } else {
                                handleUpdateBlock(target.id, 'content', visualFormulaValue);
                            }
                            setVisualFormulaBlockId(null);
                        }} className="w-full py-2 rounded-xl bg-teal-600 text-white text-xs font-bold cursor-pointer">Sisipkan ke Soal</button>
                    </div>
                </div>;
            })()}
        </div>
    );
}
