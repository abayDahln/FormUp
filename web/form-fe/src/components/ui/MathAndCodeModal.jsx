import { useState } from 'react';
import { Calculator, Code, Check, X } from 'lucide-react';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function MathAndCodeModal({ isOpen, mode, onClose, onInsert }) {
    const [mathInput, setMathInput] = useState('\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}');
    const [mathFormat, setMathFormat] = useState('inline'); // 'inline' or 'block'
    const [codeLanguage, setCodeLanguage] = useState('javascript');
    const [codeInput, setCodeInput] = useState('function calculateSum(a, b) {\n    return a + b;\n}');

    if (!isOpen) return null;

    const handleInsert = () => {
        if (mode === 'math') {
            const formula = mathInput.trim();
            if (formula) {
                if (mathFormat === 'inline') {
                    onInsert(`$${formula}$ `);
                } else {
                    onInsert(`<p>$$${formula}$$</p><p><br></p>`);
                }
            }
        } else if (mode === 'code') {
            const code = codeInput.trim();
            if (code) {
                onInsert(`<pre><code class="language-${codeLanguage}">${code}</code></pre><p><br></p>`);
            }
        }
        onClose();
    };

    const insertMathSymbol = (sym) => {
        setMathInput(prev => prev + sym);
    };

    return (
        <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
            <div className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800 shadow-2xl max-w-lg w-full p-6 space-y-4 font-sans text-slate-800 dark:text-slate-100 animate-in fade-in zoom-in-95 duration-150">
                
                {/* Header */}
                <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-800 pb-3">
                    <div className="flex items-center gap-2.5">
                        {mode === 'math' ? (
                            <div className="p-2 bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 rounded-xl">
                                <Calculator size={18} />
                            </div>
                        ) : (
                            <div className="p-2 bg-slate-900 dark:bg-slate-800 text-teal-400 rounded-xl">
                                <Code size={18} />
                            </div>
                        )}
                        <h3 className="text-sm font-extrabold text-slate-900 dark:text-white">
                            {mode === 'math' ? 'Sisipkan Rumus Matematika (KaTeX)' : 'Sisipkan Blok Kode (Syntax Highlight)'}
                        </h3>
                    </div>
                    <button type="button" onClick={onClose} className="p-1 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 rounded-lg cursor-pointer">
                        <X size={18} />
                    </button>
                </div>

                {/* Mode: MATH */}
                {mode === 'math' && (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300">Format Penempatan Rumus:</label>
                            <div className="flex items-center gap-1 bg-slate-100 dark:bg-slate-800 p-1 rounded-xl">
                                <button
                                    type="button"
                                    onClick={() => setMathFormat('inline')}
                                    className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                                        mathFormat === 'inline'
                                            ? 'bg-white dark:bg-slate-700 text-[#00897B] dark:text-teal-400 shadow-2xs'
                                            : 'text-slate-500 hover:text-slate-700 dark:text-slate-400'
                                    }`}
                                >
                                    Inline ($teks samping$)
                                </button>
                                <button
                                    type="button"
                                    onClick={() => setMathFormat('block')}
                                    className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                                        mathFormat === 'block'
                                            ? 'bg-white dark:bg-slate-700 text-[#00897B] dark:text-teal-400 shadow-2xs'
                                            : 'text-slate-500 hover:text-slate-700 dark:text-slate-400'
                                    }`}
                                >
                                    Blok Baris ($$tengah$$)
                                </button>
                            </div>
                        </div>

                        <div>
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1.5">Simbol Cepat LaTeX:</label>
                            <div className="flex flex-wrap gap-1.5">
                                {[
                                    { label: 'Pecahan (a/b)', sym: '\\frac{a}{b}' },
                                    { label: 'Akar (√x)', sym: '\\sqrt{x}' },
                                    { label: 'Pangkat (x²)', sym: 'x^2' },
                                    { label: 'Subskrip (x₁)', sym: 'x_1' },
                                    { label: 'Sigma (∑)', sym: '\\sum_{i=1}^{n}' },
                                    { label: 'Integral (∫)', sym: '\\int_{a}^{b}' },
                                    { label: 'Plus-Minus (±)', sym: '\\pm' },
                                    { label: 'Tak Hingga (∞)', sym: '\\infty' },
                                    { label: 'Pi (π)', sym: '\\pi' },
                                ].map((s, i) => (
                                    <button
                                        key={i}
                                        type="button"
                                        onClick={() => insertMathSymbol(s.sym)}
                                        className="px-2.5 py-1 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-[11px] font-mono font-bold rounded-lg transition-all cursor-pointer"
                                    >
                                        {s.label}
                                    </button>
                                ))}
                            </div>
                        </div>

                        <div>
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Ekspresi Rumus LaTeX</label>
                            <textarea
                                rows={3}
                                value={mathInput}
                                onChange={e => setMathInput(e.target.value)}
                                placeholder="contoh: \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"
                                className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-mono bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                            />
                        </div>

                        {/* Live KaTeX Preview */}
                        <div>
                            <label className="text-[11px] font-extrabold text-slate-400 dark:text-slate-500 uppercase tracking-wider block mb-1">Pratinjau Rumus:</label>
                            <div className="bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 rounded-xl p-4 min-h-16 flex items-center justify-center">
                                <RichContentRenderer content={`$$${mathInput || '...'}$$`} className="text-sm font-bold" />
                            </div>
                        </div>
                    </div>
                )}

                {/* Mode: CODE */}
                {mode === 'code' && (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300">Bahasa Pemrograman:</label>
                            <select
                                value={codeLanguage}
                                onChange={e => setCodeLanguage(e.target.value)}
                                className="border border-slate-200 dark:border-slate-700 rounded-xl px-3 py-1.5 text-xs font-bold text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-[#00897B] bg-white dark:bg-slate-800"
                            >
                                <option value="javascript">JavaScript</option>
                                <option value="python">Python</option>
                                <option value="csharp">C#</option>
                                <option value="html">HTML / CSS</option>
                                <option value="sql">SQL</option>
                                <option value="java">Java</option>
                                <option value="cpp">C++</option>
                                <option value="json">JSON</option>
                            </select>
                        </div>

                        <div>
                            <label className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-1">Kode Sumber</label>
                            <textarea
                                rows={5}
                                value={codeInput}
                                onChange={e => setCodeInput(e.target.value)}
                                placeholder="Ketik atau tempel potongan kode di sini..."
                                className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2.5 text-xs font-mono bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                            />
                        </div>

                        {/* Live Code Preview */}
                        <div>
                            <label className="text-[11px] font-extrabold text-slate-400 dark:text-slate-500 uppercase tracking-wider block mb-1">Pratinjau Kode:</label>
                            <div className="max-h-40 overflow-y-auto rounded-xl">
                                <RichContentRenderer content={`<pre><code class="language-${codeLanguage}">${codeInput || '// ...'}</code></pre>`} />
                            </div>
                        </div>
                    </div>
                )}

                {/* Actions */}
                <div className="flex justify-end gap-2 pt-2 border-t border-slate-100 dark:border-slate-800">
                    <button
                        type="button"
                        onClick={onClose}
                        className="px-4 py-2 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs font-bold rounded-xl cursor-pointer"
                    >
                        Batal
                    </button>
                    <button
                        type="button"
                        onClick={handleInsert}
                        className="px-4 py-2 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl shadow-xs flex items-center gap-1.5 cursor-pointer"
                    >
                        <Check size={14} /> Sisipkan ke Soal
                    </button>
                </div>

            </div>
        </div>
    );
}
