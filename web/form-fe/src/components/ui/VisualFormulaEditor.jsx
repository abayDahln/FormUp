import { useMemo, useState } from 'react';
import { Beaker, Calculator } from 'lucide-react';
import RichContentRenderer from '../../utils/RichContentRenderer';

const templates = {
    matematika: [
        ['Fraksi', '\\frac{a}{b}'], ['Akar', '\\sqrt{x}'], ['Akar-n', '\\sqrt[n]{x}'],
        ['Integral berbatas', '\\int_{a}^{b} f(x)\\,dx'], ['Limit', '\\lim_{x\\to a} f(x)'],
        ['Sigma', '\\sum_{i=1}^{n} i'], ['Phi besar', '\\prod_{i=1}^{n} i'],
        ['Matriks 2×2', '\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}'],
        ['α β θ π', '\\alpha+\\beta+\\theta+\\pi'], ['± ∞', '\\pm\\infty'],
    ],
    kimia: [
        ['Subskrip H₂O', 'H_{2}O'], ['Ion sulfat', 'SO_{4}^{2-}'],
        ['Superskrip', 'Na^{+}'], ['Reaksi →', 'A \\rightarrow B'],
        ['Kesetimbangan ⇌', 'A \\rightleftharpoons B'], ['Ikatan tunggal', 'A-B'],
        ['Ikatan rangkap', 'A=B'],
    ],
};

export default function VisualFormulaEditor({ value, onChange, append = true }) {
    const [category, setCategory] = useState('matematika');
    const preview = useMemo(() => value?.trim() || '\\frac{a}{b}', [value]);
    return (
        <div className="space-y-3">
            <div className="flex gap-2">
                <button type="button" onClick={() => setCategory('matematika')} className={`px-3 py-1.5 rounded-lg text-xs font-bold ${category === 'matematika' ? 'bg-teal-600 text-white' : 'bg-slate-100 dark:bg-slate-800'}`}><Calculator size={13} className="inline mr-1" />Matematika</button>
                <button type="button" onClick={() => setCategory('kimia')} className={`px-3 py-1.5 rounded-lg text-xs font-bold ${category === 'kimia' ? 'bg-teal-600 text-white' : 'bg-slate-100 dark:bg-slate-800'}`}><Beaker size={13} className="inline mr-1" />Kimia</button>
            </div>
            <div className="flex flex-wrap gap-1.5">
                {templates[category].map(([label, latex]) => <button key={label} type="button" onClick={() => onChange(append && value?.trim() ? `${value}${latex}` : latex)} className="px-2 py-1 rounded-lg bg-slate-100 dark:bg-slate-800 hover:bg-teal-50 dark:hover:bg-teal-950 text-[11px] font-bold">+ {label}</button>)}
            </div>
            <p className="text-[11px] text-slate-400">Klik template lalu ubah placeholder di syntax jika diperlukan.</p>
            <textarea value={value} onChange={e => onChange(e.target.value)} rows={3} spellCheck={false} className="w-full rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-3 text-xs font-mono" aria-label="Syntax LaTeX hasil editor visual" />
            <div className="min-h-16 rounded-xl border border-teal-100 dark:border-teal-900 bg-teal-50/40 dark:bg-teal-950/30 p-4 flex items-center justify-center"><RichContentRenderer content={`$$${preview}$$`} /></div>
        </div>
    );
}
