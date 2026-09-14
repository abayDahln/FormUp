import { useEffect, useState } from 'react';
import { CheckCircle2, RotateCcw, X } from 'lucide-react';

export default function InteractiveQuizOfferCard({ quizId, questions = [], onClose }) {
    const key = `formup_interactive_quiz_${quizId}`;
    const [open, setOpen] = useState(false);
    const [state, setState] = useState(() => { try { return JSON.parse(localStorage.getItem(key)) || {}; } catch { return {}; } });
    const quizQuestions = questions.length ? questions : [{ question: 'Apa konsep utama yang perlu Anda latih?', options: ['Konsep A', 'Konsep B', 'Konsep C', 'Konsep D'], correctIndex: 0 }];
    const choose = (q, index) => {
        const next = { ...state, [q]: index };
        setState(next); localStorage.setItem(key, JSON.stringify(next));
    };
    const reset = () => { setState({}); localStorage.removeItem(key); };
    return <>
        <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
            <div className="p-3 rounded-xl bg-teal-50 dark:bg-teal-950/40 border border-teal-200 dark:border-teal-800 space-y-2">
                <p className="text-xs font-bold text-teal-800 dark:text-teal-200">Mau melatih pemahaman dengan kuis interaktif?</p>
                <button type="button" onClick={() => setOpen(true)} className="px-3 py-2 bg-teal-600 text-white rounded-xl text-xs font-bold">Buka Kuis Interaktif</button>
            </div>
        </div>
        {open && <div className="fixed inset-0 z-50 flex items-center justify-center p-4"><div className="fixed inset-0 bg-slate-900/60" onClick={() => setOpen(false)} /><div className="relative z-10 bg-white dark:bg-slate-900 rounded-3xl p-6 max-w-lg w-full max-h-[90vh] overflow-y-auto space-y-4"><div className="flex justify-between items-center"><h3 className="font-extrabold text-sm">Kuis Interaktif</h3><button type="button" onClick={() => setOpen(false)}><X size={18} /></button></div>{quizQuestions.map((item, qi) => <div key={qi} className="space-y-2"><p className="text-xs font-bold">{qi + 1}. {item.question}</p>{item.options.map((option, oi) => { const selected = state[qi] === oi; const answered = state[qi] != null; const correct = oi === item.correctIndex; return <button key={oi} type="button" onClick={() => !answered && choose(qi, oi)} className={`w-full text-left p-2 rounded-lg border text-xs ${answered && correct ? 'border-emerald-500 bg-emerald-50' : answered && selected ? 'border-red-500 bg-red-50' : 'border-slate-200 dark:border-slate-700'}`}><span>{String.fromCharCode(65 + oi)}. {option}</span>{answered && selected && <span className="ml-2 font-bold">{correct ? 'Benar' : 'Salah'}</span>}</button>; })}</div>)}<button type="button" onClick={reset} className="inline-flex items-center gap-1 text-xs font-bold text-teal-600"><RotateCcw size={13} /> Ulangi Kuis</button><div className="text-[10px] text-slate-400 flex items-center gap-1"><CheckCircle2 size={12} /> Latihan ini tidak memengaruhi Responses atau skor form.</div></div></div>}
    </>;
}
