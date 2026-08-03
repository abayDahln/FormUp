import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getPublicFormByLink, submitFormResponse, assetUrl } from '../../services/apiService';

export default function FormRunnerPage() {
    const { formLink } = useParams();
    const navigate = useNavigate();

    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);
    const [formData, setFormData] = useState(null);
    const [answers, setAnswers] = useState({});
    const [submitted, setSubmitted] = useState(false);
    const [error, setError] = useState(null);

    useEffect(() => {
        const loadForm = async () => {
            const res = await getPublicFormByLink(formLink);
            if (res.ok && res.data) {
                setFormData(res.data);
            } else {
                setError(res.message || 'Form not found or unavailable');
            }
            setLoading(false);
        };
        loadForm();
    }, [formLink]);

    const handleAnswer = (questionId, value) => {
        setAnswers(prev => ({ ...prev, [questionId]: value }));
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        setError(null);

        const payloadAnswers = Object.entries(answers).map(([qId, val]) => {
            const q = formData.questions.find(x => x.id === parseInt(qId));
            if (!q) return null;
            if ([1, 2, 5].includes(q.typeId)) {
                // For choice types, value is optionId
                return { questionId: q.id, optionId: val, answerValue: '' };
            }
            return { questionId: q.id, optionId: null, answerValue: val };
        }).filter(Boolean);

        const payload = { answers: payloadAnswers };
        if (formData.settings?.formToken) {
            payload.token = prompt('This form requires a token to submit:');
        }

        const res = await submitFormResponse(formData.form.id, payload);
        if (res.ok) {
            setSubmitted(true);
        } else {
            setError(res.message || 'Failed to submit response');
        }
        setSubmitting(false);
    };

    if (loading) return <div className="min-h-screen bg-slate-50 flex items-center justify-center">Loading...</div>;
    if (error && !formData) return <div className="min-h-screen bg-slate-50 flex items-center justify-center text-red-500 font-bold">{error}</div>;

    if (submitted) return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4">
            <div className="bg-white p-8 rounded-xl shadow-sm text-center max-w-md w-full border border-slate-200">
                <h2 className="text-2xl font-bold text-teal-600 mb-2">Thank you!</h2>
                <p className="text-slate-600 text-sm">Your response has been recorded successfully.</p>
                <button onClick={() => navigate('/')} className="mt-6 text-sm text-teal-600 font-bold hover:underline">
                    Go Home
                </button>
            </div>
        </div>
    );

    const { form, questions } = formData;

    return (
        <div className="min-h-screen bg-slate-50 py-8 px-4 font-sans text-slate-800">
            <div className="max-w-3xl mx-auto space-y-6">
                
                <div className="bg-white rounded-xl border border-slate-200 overflow-hidden shadow-sm">
                    {form.bannerImage && (
                        <img src={assetUrl(form.bannerImage)} alt="Banner" className="w-full h-32 sm:h-48 object-cover" />
                    )}
                    <div className="p-6 border-t-8 border-teal-500">
                        <h1 className="text-3xl font-extrabold text-slate-800 mb-2">{form.title}</h1>
                        {form.description && <p className="text-sm text-slate-600">{form.description}</p>}
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    {questions.map((q, i) => (
                        <div key={q.id} className="bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
                            <h3 className="text-sm font-bold text-slate-800 mb-4">
                                {i + 1}. {q.question1}
                                {q.isRequired && <span className="text-red-500 ml-1">*</span>}
                            </h3>
                            
                            {[3, 4].includes(q.typeId) && (
                                <textarea
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => handleAnswer(q.id, e.target.value)}
                                    className="w-full border border-slate-200 rounded-lg p-3 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 min-h-[80px]"
                                    placeholder="Your answer..."
                                />
                            )}
                            
                            {[1, 5].includes(q.typeId) && (
                                <div className="space-y-2">
                                    {q.options?.map(opt => (
                                        <label key={opt.id} className="flex items-center gap-3 cursor-pointer">
                                            <input 
                                                type="radio" 
                                                name={`q_${q.id}`} 
                                                required={q.isRequired}
                                                checked={answers[q.id] === opt.id}
                                                onChange={() => handleAnswer(q.id, opt.id)}
                                                className="w-4 h-4 text-teal-600 focus:ring-teal-500 border-gray-300"
                                            />
                                            <span className="text-sm text-slate-700">{opt.optionText}</span>
                                        </label>
                                    ))}
                                </div>
                            )}
                        </div>
                    ))}

                    {error && (
                        <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-lg text-sm font-semibold">
                            {error}
                        </div>
                    )}

                    <div className="flex justify-end">
                        <button 
                            type="submit" 
                            disabled={submitting}
                            className="px-6 py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-bold rounded-xl disabled:opacity-60 transition-colors"
                        >
                            {submitting ? 'Submitting...' : 'Submit Response'}
                        </button>
                    </div>
                </form>

            </div>
        </div>
    );
}
