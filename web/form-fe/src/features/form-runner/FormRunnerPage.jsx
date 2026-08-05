import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { getPublicFormByLink, submitPublicFormResponse, assetUrl } from '../../services/apiService';

// Type IDs dari backend
// 1 = Multiple Choice, 2 = Checkboxes, 3 = Short Answer, 4 = Paragraph
// 5 = Dropdown, 6 = Date, 7 = Time, 8 = Rating

export default function FormRunnerPage() {
    const { formLink } = useParams();

    const [loading, setLoading] = useState(true);
    const [submitting, setSubmitting] = useState(false);
    const [formData, setFormData] = useState(null);
    const [answers, setAnswers] = useState({});
    const [submitted, setSubmitted] = useState(false);
    const [error, setError] = useState(null);
    const [tokenInput, setTokenInput] = useState('');
    const [needsToken, setNeedsToken] = useState(false);

    const loadForm = async (token) => {
        setLoading(true);
        setError(null);
        const res = await getPublicFormByLink(formLink, token || undefined);
        if (res.ok && res.data) {
            setFormData(res.data);
            setNeedsToken(false);
        } else if (res.status === 401) {
            setNeedsToken(true);
        } else {
            setError(res.message || 'Form not found or unavailable.');
        }
        setLoading(false);
    };

    useEffect(() => { loadForm(); }, [formLink]);

    const handleTokenSubmit = (e) => {
        e.preventDefault();
        loadForm(tokenInput);
    };

    const setAnswer = (questionId, value) => {
        setAnswers(prev => ({ ...prev, [questionId]: value }));
    };

    const toggleCheckbox = (questionId, optionId) => {
        setAnswers(prev => {
            const current = prev[questionId] || [];
            return {
                ...prev,
                [questionId]: current.includes(optionId)
                    ? current.filter(id => id !== optionId)
                    : [...current, optionId],
            };
        });
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setSubmitting(true);
        setError(null);

        // Validasi required
        for (const q of formData.questions) {
            if (!q.isRequired) continue;
            const ans = answers[q.id];
            if (ans === undefined || ans === '' || (Array.isArray(ans) && ans.length === 0)) {
                setError(`"${q.question}" is required.`);
                setSubmitting(false);
                return;
            }
        }

        // Build payload
        const payloadAnswers = [];
        for (const q of formData.questions) {
            const ans = answers[q.id];
            if (ans === undefined) continue;

            if (q.typeId === 2) {
                // Checkboxes — kirim satu entry per option dipilih
                (ans || []).forEach(optId => {
                    payloadAnswers.push({ questionId: q.id, optionId: optId, answerValue: null });
                });
            } else if ([1, 5].includes(q.typeId)) {
                // Multiple choice / dropdown — optionId
                payloadAnswers.push({ questionId: q.id, optionId: ans, answerValue: null });
            } else {
                // Short answer, paragraph, date, time, rating — answerValue
                payloadAnswers.push({ questionId: q.id, optionId: null, answerValue: String(ans) });
            }
        }

        const payload = { answers: payloadAnswers };

        const res = await submitPublicFormResponse(formLink, payload);
        if (res.ok || res.status === 201) {
            setSubmitted(true);
        } else {
            setError(res.message || 'Failed to submit. Please try again.');
        }
        setSubmitting(false);
    };

    // ── Render states ──────────────────────────────────────────────────────────

    if (loading) return (
        <div className="min-h-screen bg-gray-50 flex items-center justify-center">
            <p className="text-gray-500 text-sm">Loading form...</p>
        </div>
    );

    if (needsToken) return (
        <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-8 max-w-sm w-full space-y-4">
                <h2 className="font-bold text-gray-800 text-lg">Token Required</h2>
                <p className="text-sm text-gray-500">This form requires an access token to view.</p>
                <form onSubmit={handleTokenSubmit} className="space-y-3">
                    <input
                        type="text"
                        value={tokenInput}
                        onChange={e => setTokenInput(e.target.value)}
                        placeholder="Enter token..."
                        className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                        required
                    />
                    {error && <p className="text-xs text-red-500">{error}</p>}
                    <button type="submit" className="w-full py-2 bg-teal-600 text-white text-sm font-bold rounded-lg hover:bg-teal-700">
                        Submit Token
                    </button>
                </form>
            </div>
        </div>
    );

    if (error && !formData) return (
        <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
            <div className="text-center space-y-2">
                <p className="text-2xl">🔒</p>
                <h2 className="font-bold text-gray-700 text-lg">Form Unavailable</h2>
                <p className="text-sm text-gray-500">{error}</p>
            </div>
        </div>
    );

    if (submitted) return (
        <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
            <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-10 max-w-md w-full text-center space-y-3">
                <div className="text-4xl">✅</div>
                <h2 className="text-xl font-bold text-gray-800">Response Submitted!</h2>
                <p className="text-sm text-gray-500">Thank you for filling out the form.</p>
            </div>
        </div>
    );

    const { questions } = formData;

    return (
        <div className="min-h-screen bg-gray-50 py-8 px-4">
            <div className="max-w-2xl mx-auto space-y-4">

                {/* Header */}
                <div className="bg-white rounded-xl border border-gray-200 overflow-hidden shadow-sm">
                    {formData.bannerImage && (
                        <img
                            src={assetUrl(formData.bannerImage)}
                            alt="Banner"
                            className="w-full h-36 object-cover"
                        />
                    )}
                    <div className="p-6 border-t-4 border-teal-500">
                        <h1 className="text-2xl font-extrabold text-gray-800">{formData.title}</h1>
                        {formData.description && (
                            <p className="text-sm text-gray-600 mt-1">{formData.description}</p>
                        )}
                    </div>
                </div>

                {/* Questions */}
                <form onSubmit={handleSubmit} className="space-y-4">
                    {questions.map((q, idx) => (
                        <div key={q.id} className="bg-white rounded-xl border border-gray-200 p-5 shadow-sm">
                            <label className="block text-sm font-semibold text-gray-800 mb-3">
                                {idx + 1}. {q.question}
                                {q.isRequired && <span className="text-red-500 ml-1">*</span>}
                            </label>

                            {/* Short Answer */}
                            {q.typeId === 3 && (
                                <input
                                    type="text"
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswer(q.id, e.target.value)}
                                    placeholder="Your answer"
                                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                />
                            )}

                            {/* Paragraph */}
                            {q.typeId === 4 && (
                                <textarea
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswer(q.id, e.target.value)}
                                    placeholder="Your answer"
                                    rows={4}
                                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 resize-none"
                                />
                            )}

                            {/* Multiple Choice */}
                            {q.typeId === 1 && (
                                <div className="space-y-2">
                                    {q.options?.map(opt => (
                                        <label key={opt.id} className="flex items-center gap-3 cursor-pointer group">
                                            <input
                                                type="radio"
                                                name={`q_${q.id}`}
                                                required={q.isRequired}
                                                checked={answers[q.id] === opt.id}
                                                onChange={() => setAnswer(q.id, opt.id)}
                                                className="w-4 h-4 text-teal-600"
                                            />
                                            <span className="text-sm text-gray-700 group-hover:text-gray-900">{opt.optionText}</span>
                                        </label>
                                    ))}
                                </div>
                            )}

                            {/* Checkboxes */}
                            {q.typeId === 2 && (
                                <div className="space-y-2">
                                    {q.options?.map(opt => (
                                        <label key={opt.id} className="flex items-center gap-3 cursor-pointer group">
                                            <input
                                                type="checkbox"
                                                checked={(answers[q.id] || []).includes(opt.id)}
                                                onChange={() => toggleCheckbox(q.id, opt.id)}
                                                className="w-4 h-4 text-teal-600 rounded"
                                            />
                                            <span className="text-sm text-gray-700 group-hover:text-gray-900">{opt.optionText}</span>
                                        </label>
                                    ))}
                                </div>
                            )}

                            {/* Dropdown */}
                            {q.typeId === 5 && (
                                <select
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswer(q.id, parseInt(e.target.value))}
                                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                >
                                    <option value="">Select an option</option>
                                    {q.options?.map(opt => (
                                        <option key={opt.id} value={opt.id}>{opt.optionText}</option>
                                    ))}
                                </select>
                            )}

                            {/* Date */}
                            {q.typeId === 6 && (
                                <input
                                    type="date"
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswer(q.id, e.target.value)}
                                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                />
                            )}

                            {/* Time */}
                            {q.typeId === 7 && (
                                <input
                                    type="time"
                                    required={q.isRequired}
                                    value={answers[q.id] || ''}
                                    onChange={e => setAnswer(q.id, e.target.value)}
                                    className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                />
                            )}

                            {/* Rating */}
                            {q.typeId === 8 && (
                                <div className="flex gap-2">
                                    {[1, 2, 3, 4, 5].map(n => (
                                        <button
                                            key={n}
                                            type="button"
                                            onClick={() => setAnswer(q.id, String(n))}
                                            className={`w-10 h-10 rounded-full text-sm font-bold border-2 transition-all ${
                                                answers[q.id] === String(n)
                                                    ? 'bg-teal-600 border-teal-600 text-white'
                                                    : 'border-gray-300 text-gray-600 hover:border-teal-400'
                                            }`}
                                        >
                                            {n}
                                        </button>
                                    ))}
                                </div>
                            )}
                        </div>
                    ))}

                    {error && (
                        <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-lg text-sm font-medium">
                            {error}
                        </div>
                    )}

                    <button
                        type="submit"
                        disabled={submitting}
                        className="w-full py-3 bg-teal-600 hover:bg-teal-700 text-white font-bold rounded-xl transition-colors disabled:opacity-60 text-sm"
                    >
                        {submitting ? 'Submitting...' : 'Submit'}
                    </button>
                </form>
            </div>
        </div>
    );
}
