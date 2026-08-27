import { useState, useEffect, useRef } from 'react';
import {
    Code, Calculator, Plus, Trash2, ChevronUp, ChevronDown,
    Type, Sparkles, Copy, Check, Eye, EyeOff
} from 'lucide-react';
import RichContentRenderer from '../../utils/RichContentRenderer';

/**
 * Parse an HTML or Markdown string into structured content blocks
 */
function parseStringToBlocks(rawStr) {
    if (!rawStr || typeof rawStr !== 'string' || !rawStr.trim()) {
        return [{ id: `b_${Date.now()}_0`, type: 'text', content: '' }];
    }

    const blocks = [];
    let text = rawStr.trim();

    // Check if HTML formatted with <pre><code> or <p>$$...$$</p>
    const codeHtmlRegex = /<pre><code(?: class="language-([a-zA-Z0-9_#-]+)")?>([\s\S]*?)<\/code><\/pre>/gi;
    const mathBlockRegex = /<p>\$\$([\s\S]*?)\$\$<\/p>|\$\$([\s\S]*?)\$\$/g;

    // Split text by code blocks first
    const parts = [];
    let lastIndex = 0;
    let match;

    const combinedRegex = /<pre><code(?: class="language-([a-zA-Z0-9_#-]+)")?>([\s\S]*?)<\/code><\/pre>|```([a-zA-Z0-9_#-]*)\n([\s\S]*?)```|<p>\$\$([\s\S]*?)\$\$<\/p>|\$\$([\s\S]+?)\$\$/gi;

    while ((match = combinedRegex.exec(text)) !== null) {
        if (match.index > lastIndex) {
            const beforeText = text.substring(lastIndex, match.index).trim();
            if (beforeText) {
                // Strip wrapping <p>...</p> tags cleanly for editor
                const cleanText = beforeText.replace(/^<p>/i, '').replace(/<\/p>$/i, '').trim();
                if (cleanText) {
                    blocks.push({
                        id: `b_${Date.now()}_${blocks.length}`,
                        type: 'text',
                        content: cleanText
                    });
                }
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
            const cleanText = remaining.replace(/^<p>/i, '').replace(/<\/p>$/i, '').trim();
            if (cleanText) {
                blocks.push({
                    id: `b_${Date.now()}_${blocks.length}`,
                    type: 'text',
                    content: cleanText
                });
            }
        }
    }

    return blocks.length > 0 ? blocks : [{ id: `b_${Date.now()}_0`, type: 'text', content: rawStr }];
}

/**
 * Serialize structured blocks back to standard HTML/Markdown string
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
        // Text block: support inline KaTeX $formula$ and paragraphs
        const txt = b.content || '';
        return `<p>${txt}</p>`;
    }).join('\n');
}

export default function BlockQuestionEditor({ value, onChange, placeholder = 'Tuliskan isi pertanyaan...' }) {
    const [blocks, setBlocks] = useState(() => parseStringToBlocks(value));
    const [activeBlockId, setActiveBlockId] = useState(null);
    const lastEmittedValueRef = useRef(value);

    // Sync external value changes (e.g. template import, form load)
    useEffect(() => {
        if (value !== lastEmittedValueRef.current) {
            lastEmittedValueRef.current = value;
            setBlocks(parseStringToBlocks(value));
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
            // If only 1 block, clear its content instead of removing
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

    const handleInsertInlineMath = (blockId) => {
        const block = blocks.find(b => b.id === blockId);
        if (!block || block.type !== 'text') return;
        const insertFormula = '$x^2 + y^2 = r^2$';
        const newContent = block.content ? `${block.content} ${insertFormula}` : insertFormula;
        handleUpdateBlock(blockId, 'content', newContent);
    };

    return (
        <div className="border border-slate-200 dark:border-slate-800 rounded-2xl bg-slate-50/50 dark:bg-slate-900/50 p-3 sm:p-4 space-y-3 font-sans">
            
            {/* Quick Add Toolbar */}
            <div className="flex flex-wrap items-center justify-between gap-2 pb-2.5 border-b border-slate-200/80 dark:border-slate-800">
                <span className="text-[11px] font-extrabold uppercase tracking-wider text-slate-400 dark:text-slate-500 flex items-center gap-1">
                    <Sparkles size={12} className="text-[#00897B] dark:text-teal-400" />
                    Blok Konten Soal
                </span>

                <div className="flex flex-wrap items-center gap-1.5">
                    <button
                        type="button"
                        onClick={() => handleAddBlock('text')}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xs transition-all cursor-pointer"
                        title="Tambah Paragraf Teks"
                    >
                        <Type size={13} className="text-teal-600 dark:text-teal-400" />
                        <span>+ Teks</span>
                    </button>

                    <button
                        type="button"
                        onClick={() => handleAddBlock('code')}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xs transition-all cursor-pointer"
                        title="Tambah Blok Kode Terisolasi"
                    >
                        <Code size={13} className="text-amber-500" />
                        <span>+ Blok Kode</span>
                    </button>

                    <button
                        type="button"
                        onClick={() => handleAddBlock('math')}
                        className="inline-flex items-center gap-1 px-2.5 py-1 text-xs font-bold text-slate-700 dark:text-slate-200 bg-white dark:bg-slate-800 hover:bg-slate-100 dark:hover:bg-slate-700 border border-slate-200 dark:border-slate-700 rounded-xl shadow-2xs transition-all cursor-pointer"
                        title="Tambah Blok Rumus KaTeX"
                    >
                        <Calculator size={13} className="text-[#00897B] dark:text-teal-400" />
                        <span>+ Rumus KaTeX</span>
                    </button>
                </div>
            </div>

            {/* Blocks List */}
            <div className="space-y-3">
                {blocks.map((block, idx) => (
                    <div
                        key={block.id}
                        onClick={() => setActiveBlockId(block.id)}
                        className={`relative rounded-2xl border transition-all ${
                            activeBlockId === block.id
                                ? 'border-[#00897B] dark:border-teal-500 ring-2 ring-teal-500/20 bg-white dark:bg-slate-800 shadow-xs'
                                : 'border-slate-200 dark:border-slate-700/80 bg-white dark:bg-slate-800/80 hover:border-slate-300 dark:hover:border-slate-600'
                        } p-3.5 space-y-2.5`}
                    >
                        {/* Block Header Controls */}
                        <div className="flex items-center justify-between gap-2 border-b border-slate-100 dark:border-slate-700/60 pb-2 text-xs">
                            <div className="flex items-center gap-2">
                                <span className={`px-2 py-0.5 rounded-lg text-[10px] font-extrabold uppercase tracking-wider ${
                                    block.type === 'code'
                                        ? 'bg-amber-50 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-800'
                                        : block.type === 'math'
                                        ? 'bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 border border-teal-200 dark:border-teal-800'
                                        : 'bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300'
                                }`}>
                                    {block.type === 'code' ? 'Blok Kode' : block.type === 'math' ? 'Rumus KaTeX' : 'Teks Bebas'}
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
                                {block.type === 'text' && (
                                    <button
                                        type="button"
                                        onClick={() => handleInsertInlineMath(block.id)}
                                        className="text-[11px] font-bold text-[#00897B] dark:text-teal-400 hover:underline px-2 py-0.5 rounded cursor-pointer"
                                        title="Sisipkan Rumus Inline ($rumus$) di samping teks"
                                    >
                                        + Inline $Rumus$
                                    </button>
                                )}

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

                        {/* Block Content Editor */}
                        {block.type === 'text' && (
                            <div className="space-y-1.5">
                                <textarea
                                    rows={3}
                                    value={block.content || ''}
                                    onChange={e => handleUpdateBlock(block.id, 'content', e.target.value)}
                                    placeholder={placeholder}
                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-2 text-xs text-slate-900 dark:text-white bg-slate-50/50 dark:bg-slate-900/60 focus:outline-none focus:ring-2 focus:ring-[#00897B] resize-y"
                                />
                                {block.content && block.content.includes('$') && (
                                    <div className="px-3 py-2 bg-teal-50/50 dark:bg-teal-950/30 border border-teal-100 dark:border-teal-900 rounded-xl">
                                        <p className="text-[10px] font-bold uppercase tracking-wider text-slate-400 dark:text-slate-500 mb-0.5">Pratinjau Inline Math:</p>
                                        <RichContentRenderer content={block.content} className="text-xs font-semibold" />
                                    </div>
                                )}
                            </div>
                        )}

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
                                <div className="flex items-center justify-between text-[11px] text-slate-400">
                                    <span>Teks sebelum & sesudah blok kode ini terpisah secara aman.</span>
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
        </div>
    );
}
