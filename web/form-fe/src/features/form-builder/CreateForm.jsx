import { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { createForm, clearSession } from '../../services/apiService';

export default function CreateForm() {
    const navigate = useNavigate();
    const location = useLocation();
    const templateData = location.state?.templateData;

    const [title, setTitle] = useState(templateData?.title || '');
    const [description, setDescription] = useState(templateData?.description || '');
    const [creating, setCreating] = useState(false);
    const [error, setError] = useState('');

    const handleCreate = async (e) => {
        e.preventDefault();
        if (!title.trim()) { setError('Title is required.'); return; }
        setCreating(true);
        setError('');
        const res = await createForm({ title: title.trim(), description: description.trim() });
        setCreating(false);
        if (res.status === 401) { clearSession(); navigate('/login'); return; }
        if (res.ok && res.data?.id) {
            navigate(`/forms/${res.data.id}/edit`);
        } else {
            setError(res.message || 'Failed to create form.');
        }
    };

    return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center p-4 font-sans">
            <div className="w-full max-w-md">
                <button
                    onClick={() => navigate('/my-forms')}
                    className="flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800 mb-6"
                >
                    <ArrowLeft size={16} /> Back
                </button>

                <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-8 space-y-5">
                    <div>
                        <h1 className="text-xl font-bold text-slate-800">Create New Form</h1>
                        <p className="text-sm text-slate-500 mt-1">
                            {templateData ? `Using template: ${templateData.title}` : 'Start from scratch'}
                        </p>
                    </div>

                    <form onSubmit={handleCreate} className="space-y-4">
                        <div>
                            <label className="text-xs font-semibold text-slate-600 mb-1 block">Form Title *</label>
                            <input
                                type="text"
                                value={title}
                                onChange={e => setTitle(e.target.value)}
                                placeholder="e.g. Customer Feedback Survey"
                                className="w-full border border-slate-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400"
                                autoFocus
                            />
                        </div>
                        <div>
                            <label className="text-xs font-semibold text-slate-600 mb-1 block">Description (optional)</label>
                            <textarea
                                value={description}
                                onChange={e => setDescription(e.target.value)}
                                placeholder="Brief description of the form..."
                                rows={3}
                                className="w-full border border-slate-200 rounded-lg px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 resize-none"
                            />
                        </div>

                        {error && <p className="text-xs text-red-600 font-medium">{error}</p>}

                        <button
                            type="submit"
                            disabled={creating}
                            className="w-full py-2.5 bg-[#005B52] hover:bg-[#00463F] text-white font-bold text-sm rounded-xl transition-all disabled:opacity-60"
                        >
                            {creating ? 'Creating...' : 'Create Form'}
                        </button>
                    </form>
                </div>
            </div>
        </div>
    );
}
