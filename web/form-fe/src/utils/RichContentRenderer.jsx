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
 * Universal Parser that breaks down text into Code Blocks, Math Blocks, Inline Code, and Formatted Text
 */
function parseMixedContent(text) {
    if (!text) return null;

    // Combined regex for Code Blocks (both markdown ```...``` and HTML <pre><code>...</code></pre>)
    // Handles whitespace, newlines, and unescaped HTML inside
    const codeBlockRegex = /<pre><code(?: class="language-([a-zA-Z0-9_#-]+)")?>([\s\S]*?)<\/code><\/pre>|```([a-zA-Z0-9_#-]*)[ \t\r\n]*([\s\S]*?)```/gi;

    const elements = [];
    let lastIndex = 0;
    let match;

    while ((match = codeBlockRegex.exec(text)) !== null) {
        // Text before the code block
        if (match.index > lastIndex) {
            const beforeText = text.substring(lastIndex, match.index);
            if (beforeText) {
                elements.push(renderTextSegment(beforeText, `txt_${lastIndex}`));
            }
        }

        // Extract language and code content
        const isHtmlPre = match[0].startsWith('<pre');
        const lang = (isHtmlPre ? match[1] : match[3]) || 'code';
        const rawCode = (isHtmlPre ? match[2] : match[4]) || '';
        const cleanCode = rawCode.replace(/<[^>]+>/g, '').trim();

        elements.push(
            <CodeBlock
                key={`code_${match.index}`}
                code={cleanCode}
                language={lang.trim().toLowerCase() || 'code'}
            />
        );

        lastIndex = match.index + match[0].length;
    }

    // Remaining text after last code block
    if (lastIndex < text.length) {
        const remaining = text.substring(lastIndex);
        if (remaining) {
            elements.push(renderTextSegment(remaining, `txt_${lastIndex}`));
        }
    }

    return elements.length > 0 ? elements : text;
}

/**
 * Parses inline math ($...$), block math ($$...$$), and inline code (`...`) inside a text segment
 */
function renderTextSegment(text, keyPrefix) {
    if (!text) return null;

    // Split by Math ($$formula$$ or $formula$) and Inline Code (`inlineCode`)
    const tokenRegex = /(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$|`[^`\n]+?`)/g;
    const parts = text.split(tokenRegex);

    return (
        <span key={keyPrefix} className="whitespace-pre-wrap">
            {parts.map((part, idx) => {
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

                // If text contains simple HTML like <b>, <i>, <u>, <p>, <span>
                if (/<[a-z][\s\S]*>/i.test(part)) {
                    return (
                        <span
                            key={`${keyPrefix}_h_${idx}`}
                            dangerouslySetInnerHTML={{ __html: part }}
                        />
                    );
                }

                return <span key={`${keyPrefix}_t_${idx}`}>{part}</span>;
            })}
        </span>
    );
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
