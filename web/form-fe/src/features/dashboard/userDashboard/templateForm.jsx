import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, HelpCircle, Loader2 } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import { createForm, clearSession } from '../../../services/apiService';

const TEMPLATES = [
    {
        id: 'tpl-1',
        title: 'Survei Kepuasan Pelanggan',
        category: 'Pemasaran',
        categoryColor: 'text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950/60',
        questionCount: 12,
        description: 'Ukur tingkat kepuasan pelanggan dan kumpulkan wawasan penting untuk pengembangan produk.',
        bannerImage: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-2',
        title: 'Pendaftaran Acara & Workshop',
        category: 'Bisnis',
        categoryColor: 'text-orange-600 dark:text-orange-400 bg-orange-50 dark:bg-orange-950/60',
        questionCount: 8,
        description: 'Kumpulkan informasi peserta, preferensi konsumsi, dan pilihan sesi dengan mudah.',
        bannerImage: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-3',
        title: 'Formulir Lamaran Kerja',
        category: 'SDM',
        categoryColor: 'text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60',
        questionCount: 15,
        description: 'Permudah proses rekrutmen kandidat Anda dengan struktur formulir lamaran yang terarah.',
        bannerImage: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-4',
        title: 'Umpan Balik Kelas & Pelatihan',
        category: 'Pendidikan',
        categoryColor: 'text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-950/60',
        questionCount: 10,
        description: 'Bantu pengajar mengevaluasi kurikulum dan metode belajar melalui ulasan siswa.',
        bannerImage: 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-5',
        title: 'Formulir Pemesanan Barang',
        category: 'Penjualan',
        categoryColor: 'text-emerald-600 dark:text-emerald-400 bg-emerald-50 dark:bg-emerald-950/60',
        questionCount: 10,
        description: 'Alur praktis bagi pelanggan untuk mengajukan pesanan produk dan penawaran harga.',
        bannerImage: 'https://images.unsplash.com/photo-1556742049-0a670f4a4591?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-6',
        title: 'Laporan Masalah & Bug',
        category: 'Produk',
        categoryColor: 'text-purple-600 dark:text-purple-400 bg-purple-50 dark:bg-purple-950/60',
        questionCount: 6,
        description: 'Kumpulkan laporan kendala teknis dari pengguna beserta langkah reproduksi masalah.',
        bannerImage: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=600&auto=format&fit=crop&q=80'
    }
];

const TemplatesPage = () => {
    const navigate = useNavigate();
    const [cloningId, setCloningId] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');

    const handleCreateFromTemplate = async (template = null) => {
        const idKey = template ? template.id : 'blank';
        setCloningId(idKey);
        try {
            const payload = {
                title: template ? template.title : 'Formulir Tanpa Judul',
                description: template ? template.description : '',
            };
            const res = await createForm(payload);
            if (res.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }
            if (res.ok && res.data?.id) {
                navigate(`/forms/${res.data.id}/edit`);
            } else {
                navigate('/create-form', { state: { templateData: template } });
            }
        } catch (err) {
            console.error('Error using template:', err);
            navigate('/create-form', { state: { templateData: template } });
        } finally {
            setCloningId(null);
        }
    };

    const filteredTemplates = TEMPLATES.filter((tpl) => {
        if (!searchQuery.trim()) return true;
        const q = searchQuery.toLowerCase();
        return (
            tpl.title.toLowerCase().includes(q) ||
            tpl.description.toLowerCase().includes(q) ||
            tpl.category.toLowerCase().includes(q)
        );
    });

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar 
                        searchQuery={searchQuery} 
                        onSearchChange={setSearchQuery} 
                        placeholder="Cari templat atau kategori..." 
                    />

                    <div>
                        <h2 className="text-2xl font-bold text-slate-900 dark:text-white">Galeri Templat</h2>
                        <p className="text-xs text-slate-500 dark:text-slate-400 font-medium mt-1 max-w-xl">
                            Mulai alur kerja Anda lebih cepat dengan templat yang dirancang secara profesional dan siap pakai.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">

                        {/* <div
                            onClick={() => handleCreateFromTemplate(null)}
                            className="bg-white dark:bg-slate-900 rounded-2xl border-2 border-dashed border-slate-300 dark:border-slate-800 shadow-sm hover:border-[#00897B] dark:hover:border-teal-400 transition-all flex flex-col items-center justify-center text-center cursor-pointer min-h-[340px] p-6 group"
                        >
                            <div className="w-12 h-12 rounded-full bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                                {cloningId === 'blank' ? <Loader2 size={24} className="animate-spin" /> : <Plus size={24} />}
                            </div>
                            <h4 className="text-sm font-bold text-slate-800 dark:text-slate-200">
                                {cloningId === 'blank' ? 'Menyiapkan...' : 'Formulir Kosong'}
                            </h4>
                            <p className="text-xs text-slate-400 dark:text-slate-500 font-medium mt-1 max-w-[180px]">
                                Mulai dari awal dan bangun formulir unik sesuai kebutuhan Anda.
                            </p>
                        </div> */}

                        {filteredTemplates.map((tpl) => (
                            <div key={tpl.id} className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all flex flex-col overflow-hidden group">
                                <div className="h-40 w-full relative bg-slate-100 dark:bg-slate-800 overflow-hidden flex items-center justify-center border-b border-slate-100 dark:border-slate-800">
                                    <img
                                        src={tpl.bannerImage}
                                        alt={tpl.title}
                                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                                    />
                                </div>

                                <div className="p-4 flex-1 flex flex-col justify-between space-y-3">
                                    <div>
                                        <div className="flex items-center justify-between text-[11px] font-bold mb-2">
                                            <span className={`px-2 py-0.5 rounded-md ${tpl.categoryColor}`}>
                                                {tpl.category}
                                            </span>
                                            <span className="text-slate-400 dark:text-slate-500 font-medium flex items-center gap-1">
                                                <HelpCircle size={12} /> {tpl.questionCount} Soal
                                            </span>
                                        </div>

                                        <h4 className="text-sm font-bold text-slate-900 dark:text-white line-clamp-1 group-hover:text-[#00897B] dark:group-hover:text-teal-400 transition-colors">
                                            {tpl.title}
                                        </h4>
                                        <p className="text-xs text-slate-400 dark:text-slate-500 font-medium mt-1 line-clamp-2 leading-relaxed">
                                            {tpl.description}
                                        </p>
                                    </div>

                                    <button
                                        onClick={() => handleCreateFromTemplate(tpl)}
                                        disabled={cloningId === tpl.id}
                                        className="w-full py-2.5 px-4 bg-[#005B52] hover:bg-[#00463F] dark:bg-teal-600 dark:hover:bg-teal-700 text-white font-bold text-xs rounded-xl transition-all flex items-center justify-center gap-2 disabled:opacity-60 cursor-pointer shadow-xs"
                                    >
                                        {cloningId === tpl.id ? (
                                            <><Loader2 size={14} className="animate-spin" /> Menyiapkan...</>
                                        ) : (
                                            'Gunakan Templat'
                                        )}
                                    </button>
                                </div>
                            </div>
                        ))}

                    </div>

                    {filteredTemplates.length === 0 && searchQuery && (
                        <div className="py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                            Tidak ada templat yang cocok dengan "{searchQuery}".
                        </div>
                    )}

                </main>
            </div>
        </div>
    );
};

export default TemplatesPage;