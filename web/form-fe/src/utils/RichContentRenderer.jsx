import { useState, useEffect } from 'react';
import { Copy, Check, Code } from 'lucide-react';

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

    // If text contains HTML tags (from Summernote or rich text)
    const isHtml = /<[a-z][\s\S]*>/i.test(rawStr);

    if (isHtml) {
        // Pre-process HTML to replace $$...$$ or $...$ with rendered KaTeX or styled code blocks
        const processedHtml = processHtmlContent(rawStr);
        return (
            <div 
                className={`rich-text-content leading-relaxed ${className}`}
                dangerouslySetInnerHTML={{ __html: processedHtml }}
            />
        );
    }

    // Process string content (supports ```code blocks```, $$math$$, $math$, line breaks)
    return (
        <div className={`rich-text-content leading-relaxed ${className}`}>
            {parseMixedText(rawStr)}
        </div>
    );
}

function processHtmlContent(htmlStr) {
    if (!htmlStr) return '';
    let result = htmlStr;

    // Process math $$formula$$ or $formula$ inside HTML
    result = result.replace(/\$\$([\s\S]+?)\$\$/g, (match, formula) => {
        return renderKaTeXHtml(formula, true);
    });

    result = result.replace(/\$([^\$\n]+?)\$/g, (match, formula) => {
        return renderKaTeXHtml(formula, false);
    });

    // Style pre/code blocks in HTML to look like StackOverflow code blocks
    result = result.replace(/<pre>(?:<code(?: class="language-([a-zA-Z0-9_#-]+)")?>)?([\s\S]*?)(?:<\/code>)?<\/pre>/gi, (match, lang, codeText) => {
        const cleanCode = codeText ? codeText.replace(/<[^>]+>/g, '').trim() : '';
        const language = lang || 'code';
        return `
            <div class="my-3 rounded-xl overflow-hidden bg-slate-900 border border-slate-800 shadow-md font-mono text-xs text-slate-100">
                <div class="flex items-center justify-between px-4 py-2 bg-slate-950/80 border-b border-slate-800 text-slate-400 text-[11px] font-semibold">
                    <span class="uppercase tracking-wider font-bold text-teal-400">${language}</span>
                </div>
                <div class="p-4 overflow-x-auto font-mono text-slate-200 text-xs whitespace-pre">
                    <code>${cleanCode}</code>
                </div>
            </div>
        `;
    });

    return result;
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

    // Backup SVG / HTML Math Formatter
    return formatLaTeXFallback(trimmed, block);
}

function parseMixedText(text) {
    if (!text) return null;

    // Check for code blocks (```lang \n code \n ```)
    const codeBlockRegex = /```([a-zA-Z0-9_#-]*)\n([\s\S]*?)```/g;
    const parts = [];
    let lastIndex = 0;
    let match;

    while ((match = codeBlockRegex.exec(text)) !== null) {
        if (match.index > lastIndex) {
            parts.push(renderTextWithMath(text.substring(lastIndex, match.index), `txt_${lastIndex}`));
        }
        const lang = match[1] || 'code';
        const code = match[2].trim();
        parts.push(<CodeBlock key={`code_${match.index}`} code={code} language={lang} />);
        lastIndex = match.index + match[0].length;
    }

    if (lastIndex < text.length) {
        parts.push(renderTextWithMath(text.substring(lastIndex), `txt_${lastIndex}`));
    }

    return parts;
}

function renderTextWithMath(text, keyPrefix) {
    if (!text) return null;

    const mathRegex = /(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$)/g;
    const segments = text.split(mathRegex);

    return (
        <div key={keyPrefix} className="whitespace-pre-wrap inline">
            {segments.map((seg, i) => {
                if (!seg) return null;
                if (seg.startsWith('$$') && seg.endsWith('$$')) {
                    const formula = seg.slice(2, -2).trim();
                    return <MathBlock key={i} formula={formula} block={true} />;
                }
                if (seg.startsWith('$') && seg.endsWith('$') && seg.length > 2) {
                    const formula = seg.slice(1, -1).trim();
                    return <MathBlock key={i} formula={formula} block={false} />;
                }
                return <span key={i}>{seg}</span>;
            })}
        </div>
    );
}

// ── StackOverflow-Style Code Block Component ─────────────────────────────────
export function CodeBlock({ code, language = 'code' }) {
    const [copied, setCopied] = useState(false);

    const handleCopy = () => {
        navigator.clipboard.writeText(code);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
    };

    const lines = code.split('\n');

    return (
        <div className="my-3 rounded-xl overflow-hidden bg-slate-900 border border-slate-800 shadow-md font-mono text-xs text-slate-100">
            <div className="flex items-center justify-between px-4 py-2 bg-slate-950/80 border-b border-slate-800 text-slate-400 text-[11px] font-semibold">
                <div className="flex items-center gap-2">
                    <Code size={13} className="text-teal-400" />
                    <span className="uppercase tracking-wider font-bold text-slate-300">{language || 'code'}</span>
                </div>
                <button
                    type="button"
                    onClick={handleCopy}
                    className="flex items-center gap-1 px-2 py-1 hover:text-white hover:bg-slate-800 rounded transition-all"
                    title="Copy code"
                >
                    {copied ? <Check size={12} className="text-teal-400" /> : <Copy size={12} />}
                    <span>{copied ? 'Copied!' : 'Copy'}</span>
                </button>
            </div>

            <div className="p-4 overflow-x-auto leading-relaxed flex gap-4">
                <div className="select-none text-slate-600 text-right pr-2 border-r border-slate-800 font-mono text-xs">
                    {lines.map((_, i) => (
                        <div key={i}>{i + 1}</div>
                    ))}
                </div>
                <pre className="flex-1 font-mono text-slate-200 font-normal whitespace-pre">
                    <code>{code}</code>
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
            <div className="my-3 p-3 bg-teal-50/60 border border-teal-200/80 rounded-xl text-center font-serif text-base text-slate-800 shadow-sm overflow-x-auto">
                <div className="inline-block px-3 py-1 font-math tracking-wide" dangerouslySetInnerHTML={{ __html: html }} />
            </div>
        );
    }

    return (
        <span
            className="inline-block px-1.5 py-0.5 bg-teal-50 border border-teal-200 rounded font-serif text-sm text-slate-800 mx-0.5"
            dangerouslySetInnerHTML={{ __html: html }}
        />
    );
}

function formatLaTeXFallback(expr, block) {
    if (!expr) return '';
    let html = expr;

    html = html.replace(/\\frac\{([^}]+)\}\{([^}]+)\}/g, '<span class="inline-flex flex-col text-center align-middle mx-1 font-serif"><span class="border-b border-slate-700 px-1 text-xs font-semibold">$1</span><span class="px-1 text-xs font-semibold">$2</span></span>');
    html = html.replace(/\\sqrt\{([^}]+)\}/g, '<span class="font-serif">√<span class="border-t border-slate-700 px-0.5">$1</span></span>');
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
