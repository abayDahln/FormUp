import { useState, useEffect } from 'react';
import { Copy, Check, Code as CodeIcon } from 'lucide-react';

export default function RichContentRenderer({ content, format = 'text', className = '' }) {
    const [katexLoaded, setKatexLoaded] = useState(false);

    useEffect(() => {
        if (window.katex) {
            setKatexLoaded(true);
            return;
        }

        const loadCSS = (url) => {
            if (document.querySelector(`link[href="${url}"]`)) return;
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = url;
            document.head.appendChild(link);
        };

        const loadScript = (url) => {
            return new Promise((resolve, reject) => {
                if (document.querySelector(`script[src="${url}"]`)) {
                    resolve();
                    return;
                }
                const script = document.createElement('script');
                script.src = url;
                script.async = true;
                script.onload = resolve;
                script.onerror = reject;
                document.body.appendChild(script);
            });
        };

        loadCSS('https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css');
        loadScript('https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js')
            .then(() => setKatexLoaded(true))
            .catch(() => setKatexLoaded(false));
    }, []);

    if (!content) return null;

    const rawStr = String(content);

    return (
        <div className={`rich-text-content leading-relaxed break-words break-all [overflow-wrap:anywhere] ${className}`}>
            {parseMixedContent(rawStr)}
        </div>
    );
}

// Helper to remove excessive leading tabs/spaces and blank lines from code blocks
function dedentCode(str) {
    if (!str) return '';

    let text = str
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'");

    const lines = text.split(/\r?\n/);

    // Remove leading empty lines
    while (lines.length > 0 && lines[0].trim() === '') lines.shift();
    // Remove trailing empty lines
    while (lines.length > 0 && lines[lines.length - 1].trim() === '') lines.pop();

    if (lines.length === 0) return '';

    // Calculate common minimum indentation across non-empty lines
    let minIndent = Infinity;
    lines.forEach(line => {
        if (line.trim().length > 0) {
            const match = line.match(/^[\s\t]+/);
            const indent = match ? match[0].length : 0;
            if (indent < minIndent) minIndent = indent;
        }
    });

    if (minIndent !== Infinity && minIndent > 0) {
        return lines.map(line => line.length >= minIndent ? line.slice(minIndent) : line).join('\n');
    }

    return lines.join('\n');
}

/**
 * Universal Parser that breaks down text into Code Blocks, Math Blocks, Headers, Lists, Quotes, Tables, and Formatted Text
 */
function parseMixedContent(text) {
    if (!text) return null;

    // Combined regex for Code Blocks (both markdown ```...``` and HTML <pre><code>...</code></pre>)
    const codeBlockRegex = /<pre><code(?: class="language-([a-zA-Z0-9_#-]+)")?>([\s\S]*?)<\/code><\/pre>|```([a-zA-Z0-9_#-]*)[ \t\r\n]*([\s\S]*?)```/gi;

    const sections = [];
    let lastIndex = 0;
    let match;

    while ((match = codeBlockRegex.exec(text)) !== null) {
        if (match.index > lastIndex) {
            const beforeText = text.substring(lastIndex, match.index);
            if (beforeText) {
                sections.push({ type: 'markdown', content: beforeText });
            }
        }

        const isHtmlPre = match[0].startsWith('<pre');
        const lang = (isHtmlPre ? match[1] : match[3]) || 'code';
        const rawCode = (isHtmlPre ? match[2] : match[4]) || '';
        const cleanCode = rawCode.replace(/<[^>]+>/g, '').trim();

        sections.push({
            type: 'code',
            code: cleanCode,
            language: lang.trim().toLowerCase() || 'code',
            key: `code_${match.index}`
        });

        lastIndex = match.index + match[0].length;
    }

    if (lastIndex < text.length) {
        const remaining = text.substring(lastIndex);
        if (remaining) {
            sections.push({ type: 'markdown', content: remaining });
        }
    }

    return sections.map((sec, secIdx) => {
        if (sec.type === 'code') {
            return <CodeBlock key={sec.key || `sec_code_${secIdx}`} code={sec.code} language={sec.language} />;
        }
        return renderMarkdownBlocks(sec.content, `sec_md_${secIdx}`);
    });
}

/**
 * Parses block-level markdown (headers, blockquotes, lists, hr, paragraphs)
 */
function renderMarkdownBlocks(text, keyPrefix) {
    if (!text) return null;

    const lines = text.split(/\r?\n/);
    const blocks = [];
    let currentList = null; // { type: 'ul'|'ol', items: [] }

    const flushList = (blockIdx) => {
        if (currentList) {
            if (currentList.type === 'ul') {
                blocks.push(
                    <ul key={`${keyPrefix}_ul_${blockIdx}`} className="list-disc list-inside space-y-1 my-2 pl-2">
                        {currentList.items.map((item, iIdx) => (
                            <li key={iIdx} className="leading-relaxed">
                                {renderInlineMarkdownAndMath(item, `${keyPrefix}_li_${blockIdx}_${iIdx}`)}
                            </li>
                        ))}
                    </ul>
                );
            } else {
                blocks.push(
                    <ol key={`${keyPrefix}_ol_${blockIdx}`} className="list-decimal list-inside space-y-1 my-2 pl-2">
                        {currentList.items.map((item, iIdx) => (
                            <li key={iIdx} className="leading-relaxed">
                                {renderInlineMarkdownAndMath(item, `${keyPrefix}_oli_${blockIdx}_${iIdx}`)}
                            </li>
                        ))}
                    </ol>
                );
            }
            currentList = null;
        }
    };

    lines.forEach((line, lIdx) => {
        const trimmed = line.trim();

        // Empty line
        if (!trimmed) {
            flushList(lIdx);
            blocks.push(<div key={`${keyPrefix}_sp_${lIdx}`} className="h-2" />);
            return;
        }

        // Horizontal Rule --- or ***
        if (/^(\*{3,}|-{3,}|_{3,})$/.test(trimmed)) {
            flushList(lIdx);
            blocks.push(<hr key={`${keyPrefix}_hr_${lIdx}`} className="my-3 border-slate-200 dark:border-slate-800" />);
            return;
        }

        // Headers: #, ##, ###, ####
        const headerMatch = trimmed.match(/^(#{1,6})\s+(.+)$/);
        if (headerMatch) {
            flushList(lIdx);
            const level = headerMatch[1].length;
            const title = headerMatch[2];
            const sizeClass =
                level === 1 ? 'text-lg sm:text-xl font-extrabold my-3 text-slate-900 dark:text-white' :
                level === 2 ? 'text-base sm:text-lg font-bold my-2.5 text-slate-900 dark:text-white' :
                level === 3 ? 'text-sm sm:text-base font-bold my-2 text-slate-800 dark:text-slate-100' :
                'text-xs sm:text-sm font-bold my-1.5 text-slate-800 dark:text-slate-200';

            blocks.push(
                <div key={`${keyPrefix}_h_${lIdx}`} className={sizeClass}>
                    {renderInlineMarkdownAndMath(title, `${keyPrefix}_ht_${lIdx}`)}
                </div>
            );
            return;
        }

        // Blockquote: > quote
        if (trimmed.startsWith('>')) {
            flushList(lIdx);
            const quoteContent = trimmed.replace(/^>\s*/, '');
            blocks.push(
                <blockquote key={`${keyPrefix}_bq_${lIdx}`} className="border-l-4 border-teal-500 pl-3 my-2 text-slate-600 dark:text-slate-300 italic bg-teal-50/40 dark:bg-teal-950/20 py-1 rounded-r-xl">
                    {renderInlineMarkdownAndMath(quoteContent, `${keyPrefix}_bqt_${lIdx}`)}
                </blockquote>
            );
            return;
        }

        // Unordered List item: * item or - item
        const ulMatch = line.match(/^[\s]*[-*+]\s+(.+)$/);
        if (ulMatch) {
            if (!currentList || currentList.type !== 'ul') {
                flushList(lIdx);
                currentList = { type: 'ul', items: [] };
            }
            currentList.items.push(ulMatch[1]);
            return;
        }

        // Ordered List item: 1. item
        const olMatch = line.match(/^[\s]*\d+\.\s+(.+)$/);
        if (olMatch) {
            if (!currentList || currentList.type !== 'ol') {
                flushList(lIdx);
                currentList = { type: 'ol', items: [] };
            }
            currentList.items.push(olMatch[1]);
            return;
        }

        // Regular Paragraph Line
        flushList(lIdx);
        blocks.push(
            <p key={`${keyPrefix}_p_${lIdx}`} className="my-1 leading-relaxed">
                {renderInlineMarkdownAndMath(line, `${keyPrefix}_pt_${lIdx}`)}
            </p>
        );
    });

    flushList(lines.length);
    return blocks;
}

/**
 * Parses inline formatting: **bold**, *italic*, `code`, math ($...$, $$...$$), links [text](url)
 */
function renderInlineMarkdownAndMath(text, keyPrefix) {
    if (!text) return null;

    // Split by Math ($$formula$$ or $formula$) and Inline Code (`code`)
    const tokenRegex = /(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$|`[^`\n]+?`)/g;
    const parts = text.split(tokenRegex);

    return parts.map((part, idx) => {
        if (!part) return null;

        // Block Math $$...$$
        if (part.startsWith('$$') && part.endsWith('$$') && part.length > 4) {
            const formula = part.slice(2, -2).trim();
            return <MathBlock key={`${keyPrefix}_m_${idx}`} formula={formula} block={true} />;
        }

        // Inline Math $...$
        if (part.startsWith('$') && part.endsWith('$') && part.length > 2) {
            const formula = part.slice(1, -1).trim();
            return <MathBlock key={`${keyPrefix}_m_${idx}`} formula={formula} block={false} />;
        }

        // Inline Code `...`
        if (part.startsWith('`') && part.endsWith('`') && part.length > 2) {
            const inlineCode = part.slice(1, -1);
            return (
                <code
                    key={`${keyPrefix}_c_${idx}`}
                    className="inline-block px-1.5 py-0.5 mx-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-teal-600 dark:text-teal-400 font-mono text-[11px] font-bold border border-slate-200 dark:border-slate-700"
                >
                    {inlineCode}
                </code>
            );
        }

        // Format Markdown Bold (**text**), Italic (*text*), and Links ([text](url))
        return <span key={`${keyPrefix}_t_${idx}`}>{parseInlineMarkdownStyles(part, `${keyPrefix}_s_${idx}`)}</span>;
    });
}

function parseInlineMarkdownStyles(text, keyPrefix) {
    if (!text) return null;

    // Tokenize bold (**bold**), italic (*italic* or _italic_), and markdown links [text](url)
    const styleRegex = /(\*\*[^*]+\*\*|\*[^*]+\*|_[^_]+_|\[[^\]]+\]\([^)]+\))/g;
    const pieces = text.split(styleRegex);

    return pieces.map((piece, pIdx) => {
        if (!piece) return null;

        // **Bold**
        if (piece.startsWith('**') && piece.endsWith('**') && piece.length >= 4) {
            return (
                <strong key={`${keyPrefix}_b_${pIdx}`} className="font-extrabold text-slate-900 dark:text-white">
                    {piece.slice(2, -2)}
                </strong>
            );
        }

        // *Italic* or _Italic_
        if ((piece.startsWith('*') && piece.endsWith('*') && piece.length >= 2) ||
            (piece.startsWith('_') && piece.endsWith('_') && piece.length >= 2)) {
            return (
                <em key={`${keyPrefix}_i_${pIdx}`} className="italic">
                    {piece.slice(1, -1)}
                </em>
            );
        }

        // Link [label](url)
        const linkMatch = piece.match(/^\[([^\]]+)\]\(([^)]+)\)$/);
        if (linkMatch) {
            return (
                <a
                    key={`${keyPrefix}_l_${pIdx}`}
                    href={linkMatch[2]}
                    target="_blank"
                    rel="noreferrer"
                    className="text-teal-600 dark:text-teal-400 font-bold underline hover:text-teal-700 inline-flex items-center gap-0.5"
                >
                    {linkMatch[1]}
                </a>
            );
        }

        return piece;
    });
}

// ── Code Block Component ──────────────────────────────────────────────────────
export function CodeBlock({ code, language = 'code' }) {
    const [copied, setCopied] = useState(false);
    const cleanCode = dedentCode(code);

    const handleCopy = (e) => {
        if (e) e.stopPropagation();
        navigator.clipboard.writeText(cleanCode);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    const lines = cleanCode.split('\n');

    return (
        <div className="my-3 rounded-2xl overflow-hidden bg-slate-900 border border-slate-800 shadow-md font-mono text-xs text-slate-100 text-left">
            {/* Header bar */}
            <div className="flex items-center justify-between px-4 py-2 bg-slate-950/90 border-b border-slate-800/80 text-slate-400 text-[11px] font-semibold">
                <div className="flex items-center gap-2">
                    <CodeIcon size={14} className="text-teal-400" />
                    <span className="uppercase tracking-wider font-bold text-slate-300">
                        {language || 'code'}
                    </span>
                </div>
                <button
                    type="button"
                    onClick={handleCopy}
                    className="flex items-center gap-1.5 px-2.5 py-1 text-slate-400 hover:text-white hover:bg-slate-800/80 rounded-lg transition-all cursor-pointer font-sans"
                    title="Salin Kode"
                >
                    {copied ? <Check size={13} className="text-teal-400" /> : <Copy size={13} />}
                    <span className="text-[11px] font-bold">{copied ? 'Tersalin!' : 'Salin'}</span>
                </button>
            </div>

            {/* Code Body with Line Numbers */}
            <div className="p-4 max-h-96 overflow-y-auto overflow-x-auto leading-relaxed flex gap-4">
                <div className="select-none text-slate-600 text-right pr-2 border-r border-slate-800 font-mono text-xs">
                    {lines.map((_, i) => (
                        <div key={i}>{i + 1}</div>
                    ))}
                </div>
                <pre className="flex-1 font-mono text-slate-200 font-normal whitespace-pre border-0 p-0 m-0 bg-transparent text-xs">
                    <code>{cleanCode}</code>
                </pre>
            </div>
        </div>
    );
}

// ── Math / Formula Component ──────────────────────────────────────────────────
export function MathBlock({ formula, block = false }) {
    const html = renderKaTeXHtml(formula, block);

    if (block) {
        return (
            <div className="my-3 p-3 bg-teal-50/60 dark:bg-teal-950/40 border border-teal-200/80 dark:border-teal-800/80 rounded-2xl text-center font-serif text-base text-slate-800 dark:text-slate-100 shadow-xs overflow-x-auto">
                <div className="inline-block px-3 py-1 tracking-wide" dangerouslySetInnerHTML={{ __html: html }} />
            </div>
        );
    }

    return (
        <span
            className="inline-block px-1.5 py-0.5 bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800 rounded font-serif text-sm text-slate-800 dark:text-slate-100 mx-0.5"
            dangerouslySetInnerHTML={{ __html: html }}
        />
    );
}

function renderKaTeXHtml(formula, block = false) {
    if (!formula) return '';
    const trimmed = formula.trim();

    if (window.katex) {
        try {
            return window.katex.renderToString(trimmed, {
                displayMode: block,
                throwOnError: false,
            });
        } catch (e) {
            // Fallback if KaTeX fails
        }
    }

    return formatLaTeXFallback(trimmed, block);
}

function formatLaTeXFallback(expr, block) {
    if (!expr) return '';
    let html = expr;

    html = html.replace(/\\frac\{([^}]+)\}\{([^}]+)\}/g, '<span class="inline-flex flex-col text-center align-middle mx-1 font-serif"><span class="border-b border-slate-700 dark:border-slate-300 px-1 text-xs font-semibold">$1</span><span class="px-1 text-xs font-semibold">$2</span></span>');
    html = html.replace(/\\sqrt\{([^}]+)\}/g, '<span class="font-serif">√<span class="border-t border-slate-700 dark:border-slate-300 px-0.5">$1</span></span>');
    html = html.replace(/\\sqrt\s*([a-zA-Z0-9]+)/g, '√$1');
    html = html.replace(/\^{([^}]+)\}/g, '<sup>$1</sup>');
    html = html.replace(/\^([0-9a-zA-Z]+)/g, '<sup>$1</sup>');
    html = html.replace(/_{([^}]+)\}/g, '<sub>$1</sub>');
    html = html.replace(/_([0-9a-zA-Z]+)/g, '<sub>$1</sub>');

    const symbols = {
        '\\alpha': 'α', '\\beta': 'β', '\\gamma': 'γ', '\\delta': 'δ', '\\epsilon': 'ε',
        '\\theta': 'θ', '\\lambda': 'λ', '\\mu': 'μ', '\\pi': 'π', '\\sigma': 'σ',
        '\\sum': '∑', '\\int': '∫', '\\infty': '∞', '\\pm': '±', '\\times': '×',
        '\\div': '÷', '\\neq': '≠', '\\leq': '≤', '\\geq': '≥', '\\approx': '≈'
    };

    Object.entries(symbols).forEach(([k, v]) => {
        html = html.replaceAll(k, v);
    });

    return html;
}
