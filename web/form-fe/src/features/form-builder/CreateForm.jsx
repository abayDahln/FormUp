import { useEffect, useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Loader2, ArrowLeft, AlertCircle } from 'lucide-react';
import { createForm, clearSession } from '../../services/apiService';

export default function CreateForm() {
    const navigate = useNavigate();
    const location = useLocation();
    const templateData = location.state?.templateData;

    const [error, setError] = useState('');
    const [creating, setCreating] = useState(true);

    useEffect(() => {
        let isMounted = true;

        const initForm = async () => {
            try {
                setCreating(true);
                setError('');

                const payload = {
                    title: templateData?.title || 'Formulir Tanpa Judul',
                    description: templateData?.description || '',
                };

                const res = await createForm(payload);

                if (!isMounted) return;

                if (res.status === 401) {
                    clearSession();
                    navigate('/login');
                    return;
                }

                if (res.ok && res.data?.id) {
                    navigate(`/forms/${res.data.id}/edit`, { replace: true });
                } else {
                    setError(res.message || 'Gagal membuat formulir baru.');
                    setCreating(false);
                }
            } catch (err) {
                if (!isMounted) return;
                console.error('Create form error:', err);
                setError('Terjadi kesalahan saat membuat formulir.');
                setCreating(false);
            }
        };

        initForm();

        return () => {
            isMounted = false;
        };
    }, [navigate, templateData]);

    return (
        <div className="min-h-screen bg-[#F4F8F7] dark:bg-slate-950 flex items-center justify-center p-4 font-sans text-slate-800 dark:text-slate-100">
            <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800 shadow-xl p-8 text-center space-y-5">
                {creating ? (
                    <div className="space-y-4 py-6">
                        <Loader2 className="w-10 h-10 text-[#00897B] dark:text-teal-400 animate-spin mx-auto" />
                        <div>
                            <h2 className="text-base font-extrabold text-slate-900 dark:text-white">Menyiapkan Formulir Baru...</h2>
                            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Anda akan langsung diarahkan ke Form Builder.</p>
                        </div>
                    </div>
                ) : (
                    <div className="space-y-4">
                        <div className="w-12 h-12 rounded-full bg-red-100 dark:bg-red-950/50 text-red-600 dark:text-red-400 flex items-center justify-center mx-auto">
                            <AlertCircle size={24} />
                        </div>
                        <div>
                            <h2 className="text-base font-extrabold text-slate-900 dark:text-white">Gagal Membuat Formulir</h2>
                            <p className="text-xs text-red-500 dark:text-red-400 mt-1">{error}</p>
                        </div>
                        <div className="flex gap-3 pt-2">
                            <button
                                onClick={() => navigate('/my-forms')}
                                className="flex-1 py-2.5 px-4 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 font-bold text-xs rounded-xl flex items-center justify-center gap-1.5 transition-all"
                            >
                                <ArrowLeft size={14} /> Kembali
                            </button>
                            <button
                                onClick={() => window.location.reload()}
                                className="flex-1 py-2.5 px-4 bg-[#00897B] hover:bg-[#00796B] text-white font-bold text-xs rounded-xl transition-all"
                            >
                                Coba Lagi
                            </button>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
