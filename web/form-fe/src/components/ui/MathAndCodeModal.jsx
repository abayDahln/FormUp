import { useState } from 'react';
import { Calculator, Code, Check, X } from 'lucide-react';
import RichContentRenderer from '../../utils/RichContentRenderer';

export default function MathAndCodeModal({ isOpen, mode, onClose, onInsert }) {
    const [mathInput, setMathInput] = useState('\\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}');
    const [codeLanguage, setCodeLanguage] = useState('javascript');
    const [codeInput, setCodeInput] = useState('function calculateSum(a, b) {\n    return a + b;\n}');

    if (!isOpen) return null;

    const handleInsert = () => {
        if (mode === 'math') {
            const formula = mathInput.trim();
            if (formula) {
                // Insert as LaTeX math block
                onInsert(`<p>$$${formula}$$</p><p><br></p>`);
            }
        } else if (mode === 'code') {
            const code = codeInput.trim();
            if (code) {
                // Insert as clean pre/code block
                onInsert(`<pre><code class="language-${codeLanguage}">${code}</code></pre><p><br></p>`);
            }
        }
        onClose();
    };

    const insertMathSymbol = (sym) => {
        setMathInput(prev => prev + sym);
    };

    return (
        <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-xs flex items-center justify-center p-4">
            <div className="bg-white rounded-2xl border border-slate-200 shadow-2xl max-w-lg w-full p-6 space-y-4 font-sans text-slate-800">
                
                {/* Header */}
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                    <div className="flex items-center gap-2">
                        {mode === 'math' ? (
                            <div className="p-2 bg-teal-50 text-teal-600 rounded-xl">
                                <Calculator size={18} />
                            </div>
                        ) : (
                            <div className="p-2 bg-slate-900 text-teal-400 rounded-xl">
                                <Code size={18} />
                            </div>
                        )}
                        <h3 className="text-sm font-extrabold text-slate-900">
                            {mode === 'math' ? 'Insert KaTeX Math Formula' : 'Insert Code Snippet'}
                        </h3>
                    </div>
                    <button type="button" onClick={onClose} className="p-1 text-slate-400 hover:text-slate-700 rounded-lg">
                        <X size={18} />
                    </button>
                </div>

                {/* Mode: MATH */}
                {mode === 'math' && (
                    <div className="space-y-4">
                        <div>
                            <label className="text-xs font-bold text-slate-700 block mb-1.5">Quick LaTeX Symbols:</label>
                            <div className="flex flex-wrap gap-1.5">
                                {[
                                    { label: 'Fraction (a/b)', sym: '\\frac{a}{b}' },
                                    { label: 'Square Root (√x)', sym: '\\sqrt{x}' },
                                    { label: 'Power (x²)', sym: 'x^2' },
                                    { label: 'Subscript (x₁)', sym: 'x_1' },
                                    { label: 'Sum (∑)', sym: '\\sum_{i=1}^{n}' },
                                    { label: 'Integral (∫)', sym: '\\int_{a}^{b}' },
                                    { label: 'Plus-Minus (±)', sym: '\\pm' },
                                    { label: 'Infinity (∞)', sym: '\\infty' },
                                    { label: 'Pi (π)', sym: '\\pi' },
                                ].map((s, i) => (
                                    <button
                                        key={i}
                                        type="button"
                                        onClick={() => insertMathSymbol(s.sym)}
                                        className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-700 text-[11px] font-mono font-bold rounded-lg transition-all"
                                    >
                                        {s.label}
                                    </button>
                                ))}
                            </div>
                        </div>

                        <div>
                            <label className="text-xs font-bold text-slate-700 block mb-1">LaTeX Input Expression</label>
                            <textarea
                                rows={3}
                                value={mathInput}
                                onChange={e => setMathInput(e.target.value)}
                                placeholder="e.g. \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"
                                className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-400"
                            />
                        </div>

                        {/* Live KaTeX Preview */}
                        <div>
                            <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-wider block mb-1">Formula Live Preview:</label>
                            <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 min-h-16 flex items-center justify-center">
                                <RichContentRenderer content={`$$${mathInput || '...'}$$`} className="text-sm font-bold" />
                            </div>
                        </div>
                    </div>
                )}

                {/* Mode: CODE */}
                {mode === 'code' && (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <label className="text-xs font-bold text-slate-700">Language:</label>
                            <select
                                value={codeLanguage}
                                onChange={e => setCodeLanguage(e.target.value)}
                                className="border border-slate-200 rounded-xl px-3 py-1.5 text-xs font-bold text-slate-700 focus:outline-none focus:ring-2 focus:ring-teal-400 bg-white"
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
                            <label className="text-xs font-bold text-slate-700 block mb-1">Code Snippet Input</label>
                            <textarea
                                rows={5}
                                value={codeInput}
                                onChange={e => setCodeInput(e.target.value)}
                                placeholder="Paste or type code snippet here..."
                                className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-xs font-mono focus:outline-none focus:ring-2 focus:ring-teal-400"
                            />
                        </div>

                        {/* Live Code Preview */}
                        <div>
                            <label className="text-[11px] font-extrabold text-slate-400 uppercase tracking-wider block mb-1">Code Live Preview (StackOverflow style):</label>
                            <div className="max-h-40 overflow-y-auto rounded-xl">
                                <RichContentRenderer content={`<pre><code class="language-${codeLanguage}">${codeInput || '// ...'}</code></pre>`} />
                            </div>
                        </div>
                    </div>
                )}

                {/* Actions */}
                <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                    <button
                        type="button"
                        onClick={onClose}
                        className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl"
                    >
                        Cancel
                    </button>
                    <button
                        type="button"
                        onClick={handleInsert}
                        className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold rounded-xl shadow-xs flex items-center gap-1.5"
                    >
                        <Check size={14} /> Insert Once
                    </button>
                </div>

            </div>
        </div>
    );
}
