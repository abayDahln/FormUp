import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    HelpCircle, Loader2, FileText, CheckCircle2,
    Calculator, Code2, Sparkles, ArrowRight
} from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';
import {
    createForm, updateFormSettings, saveQuestions, clearSession
} from '../../../services/apiService';

const TEMPLATES = [
    {
        id: 'tpl-umum',
        title: 'Formulir Pendaftaran & Survei Umum',
        category: 'Form Umum',
        categoryColor: 'text-teal-700 dark:text-teal-300 bg-teal-50 dark:bg-teal-950/60 border border-teal-200 dark:border-teal-800',
        icon: FileText,
        questionCount: 6,
        description: 'Templat serbaguna seperti Google Form dengan urutan soal teracak secara default untuk mengumpulkan biodata, jenis kelamin, hobi, dan kritik/saran.',
        bannerImage: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=800&auto=format&fit=crop&q=80',
        settings: {
            randomizeQuestions: true,
            formTypeId: 1,
            showScore: false,
            oneResponse: false,
            requiredLogin: false,
        },
        questions: [
            {
                typeId: 1,
                question: 'Nama Lengkap',
                isRequired: true,
                options: []
            },
            {
                typeId: 1,
                question: 'Alamat Email',
                isRequired: true,
                options: []
            },
            {
                typeId: 1,
                question: 'Nomor Telepon / WhatsApp',
                isRequired: true,
                options: []
            },
            {
                typeId: 2,
                question: 'Jenis Kelamin',
                isRequired: true,
                options: [
                    { optionText: 'Laki-laki', isCorrect: false },
                    { optionText: 'Perempuan', isCorrect: false }
                ]
            },
            {
                typeId: 3,
                question: 'Hobi & Minat',
                isRequired: false,
                options: [
                    { optionText: 'Membaca Buku', isCorrect: false },
                    { optionText: 'Olahraga & Kebugaran', isCorrect: false },
                    { optionText: 'Musik & Kesenian', isCorrect: false },
                    { optionText: 'Teknologi & Koding', isCorrect: false }
                ]
            },
            {
                typeId: 1,
                question: 'Kritik dan Saran untuk Peningkatan Layanan Kami',
                isRequired: false,
                options: []
            }
        ]
    },
    {
        id: 'tpl-ujian-pg',
        title: 'Ujian Pilihan Ganda & Kuis Akademik',
        category: 'Ujian PG',
        categoryColor: 'text-blue-700 dark:text-blue-300 bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-800',
        icon: CheckCircle2,
        questionCount: 3,
        description: 'Templat ujian pilihan ganda resmi dengan pengaturan otomatis: Timer 30 menit, Batasi 1 respons per pengguna, dan Wajib login akun.',
        bannerImage: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=800&auto=format&fit=crop&q=80',
        settings: {
            timerDuration: 1800,
            oneResponse: true,
            requiredLogin: true,
            showScore: true,
            randomizeQuestions: true,
            formTypeId: 2,
        },
        questions: [
            {
                typeId: 2,
                question: 'Apa nama ibu kota negara Indonesia yang baru yang berlokasi di Kalimantan Timur?',
                isRequired: true,
                correctAnswer: 'Nusantara',
                options: [
                    { optionText: 'Nusantara', isCorrect: true },
                    { optionText: 'Jakarta', isCorrect: false },
                    { optionText: 'Balikpapan', isCorrect: false },
                    { optionText: 'Samarinda', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: 'Berapakah hasil dari 10 + 5?',
                isRequired: true,
                correctAnswer: '15',
                options: [
                    { optionText: '15', isCorrect: true },
                    { optionText: '12', isCorrect: false },
                    { optionText: '20', isCorrect: false },
                    { optionText: '25', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: 'Manakah planet terbesar di dalam tata surya kita?',
                isRequired: true,
                correctAnswer: 'Yupiter',
                options: [
                    { optionText: 'Yupiter', isCorrect: true },
                    { optionText: 'Saturnus', isCorrect: false },
                    { optionText: 'Bumi', isCorrect: false },
                    { optionText: 'Mars', isCorrect: false }
                ]
            }
        ]
    },
    {
        id: 'tpl-matematika',
        title: 'Kuis & Latihan Soal Matematika',
        category: 'Matematika',
        categoryColor: 'text-purple-700 dark:text-purple-300 bg-purple-50 dark:bg-purple-950/60 border border-purple-200 dark:border-purple-800',
        icon: Calculator,
        questionCount: 4,
        description: 'Templat soal matematika interaktif yang memanfaatkan rumus KaTeX rendered LaTeX, aljabar, integral tentu, limit, dan geometri Pythagoras.',
        bannerImage: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb?w=800&auto=format&fit=crop&q=80',
        settings: {
            showScore: true,
            randomizeQuestions: true,
            formTypeId: 1,
            oneResponse: false,
            requiredLogin: false,
        },
        questions: [
            {
                typeId: 2,
                question: '<p>Tentukan himpunan penyelesaian dari persamaan kuadrat berikut jika $$a = 1, b = -5, c = 6$$ menggunakan rumus kuadratik:</p><p>$$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$</p>',
                isRequired: true,
                correctAnswer: 'x = 2 dan x = 3',
                options: [
                    { optionText: 'x = 2 dan x = 3', isCorrect: true },
                    { optionText: 'x = -2 dan x = -3', isCorrect: false },
                    { optionText: 'x = 1 dan x = 6', isCorrect: false },
                    { optionText: 'x = -1 dan x = 5', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: '<p>Berapakah hasil evaluasi dari integral tentu berikut?</p><p>$$\\int_{0}^{2} 3x^2 \\, dx$$</p>',
                isRequired: true,
                correctAnswer: '8',
                options: [
                    { optionText: '8', isCorrect: true },
                    { optionText: '6', isCorrect: false },
                    { optionText: '12', isCorrect: false },
                    { optionText: '4', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: '<p>Hitunglah nilai limit fungsi trigonometri berikut:</p><p>$$\\lim_{x \\to 0} \\frac{\\sin(2x)}{x}$$</p>',
                isRequired: true,
                correctAnswer: '2',
                options: [
                    { optionText: '2', isCorrect: true },
                    { optionText: '0', isCorrect: false },
                    { optionText: '1', isCorrect: false },
                    { optionText: 'Tak Hingga (\\infty)', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: '<p>Diketahui segitiga siku-siku dengan panjang sisi tegak $$a = 6\\text{ cm}$$ dan $$b = 8\\text{ cm}$$. Berapakah panjang sisi miring ($$c$$) berdasarkan teorema Pythagoras $$a^2 + b^2 = c^2$$?</p>',
                isRequired: true,
                correctAnswer: '10 cm',
                options: [
                    { optionText: '10 cm', isCorrect: true },
                    { optionText: '12 cm', isCorrect: false },
                    { optionText: '14 cm', isCorrect: false },
                    { optionText: '15 cm', isCorrect: false }
                ]
            }
        ]
    },
    {
        id: 'tpl-coding',
        title: 'Tes Kompetensi Pemrograman & Koding',
        category: 'Koding',
        categoryColor: 'text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-950/60 border border-emerald-200 dark:border-emerald-800',
        icon: Code2,
        questionCount: 4,
        description: 'Templat tes koding terstruktur dengan blok kode bawaan (syntax highlighting), logika JavaScript, rekursi Python, struktur data LIFO, dan query SQL.',
        bannerImage: 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=800&auto=format&fit=crop&q=80',
        settings: {
            showScore: true,
            oneResponse: true,
            timerDuration: 2700,
            formTypeId: 1,
            randomizeQuestions: false,
            requiredLogin: false,
        },
        questions: [
            {
                typeId: 2,
                question: '<p>Perhatikan potongan kode JavaScript berikut:</p><pre><code class="language-javascript">const numbers = [1, 2, 3, 4];\nconst result = numbers.map(n => n * 2).filter(n => n > 4);\nconsole.log(result);</code></pre><p>Apakah output yang dicetak ke console?</p>',
                isRequired: true,
                correctAnswer: '[6, 8]',
                options: [
                    { optionText: '[6, 8]', isCorrect: true },
                    { optionText: '[4, 6, 8]', isCorrect: false },
                    { optionText: '[2, 4, 6, 8]', isCorrect: false },
                    { optionText: '[8]', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: '<p>Perhatikan fungsi rekursif Python berikut:</p><pre><code class="language-python">def faktorial(n):\n    if n <= 1:\n        return 1\n    return n * faktorial(n - 1)\n\nprint(faktorial(4))</code></pre><p>Berapakah nilai yang dihasilkan saat fungsi tersebut dieksekusi?</p>',
                isRequired: true,
                correctAnswer: '24',
                options: [
                    { optionText: '24', isCorrect: true },
                    { optionText: '12', isCorrect: false },
                    { optionText: '16', isCorrect: false },
                    { optionText: '4', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: '<p>Dalam struktur data pemrograman, operasi <code>push()</code> dan <code>pop()</code> pada Stack mengikuti prinsip dasar apa?</p>',
                isRequired: true,
                correctAnswer: 'LIFO (Last In, First Out)',
                options: [
                    { optionText: 'LIFO (Last In, First Out)', isCorrect: true },
                    { optionText: 'FIFO (First In, First Out)', isCorrect: false },
                    { optionText: 'LILO (Last In, Last Out)', isCorrect: false },
                    { optionText: 'Random Access', isCorrect: false }
                ]
            },
            {
                typeId: 2,
                question: '<p>Perhatikan query SQL berikut:</p><pre><code class="language-sql">SELECT COUNT(*) FROM users WHERE status = \'active\';</code></pre><p>Apa fungsi utama dari klausa <code>COUNT(*)</code> tersebut?</p>',
                isRequired: true,
                correctAnswer: 'Menghitung total baris pengguna yang berstatus aktif',
                options: [
                    { optionText: 'Menghitung total baris pengguna yang berstatus aktif', isCorrect: true },
                    { optionText: 'Mengambil seluruh kolom tabel users', isCorrect: false },
                    { optionText: 'Menjumlahkan nilai kolom status', isCorrect: false },
                    { optionText: 'Menghapus data user yang aktif', isCorrect: false }
                ]
            }
        ]
    }
];

export default function TemplatesPage() {
    const navigate = useNavigate();
    const [cloningId, setCloningId] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');

    const handleCreateFromTemplate = async (template) => {
        if (!template) return;
        setCloningId(template.id);

        try {
            // 1. Buat form baru dengan judul & deskripsi templat
            const formRes = await createForm({
                title: template.title,
                description: template.description,
            });

            if (formRes.status === 401) {
                clearSession();
                navigate('/login');
                return;
            }

            if (formRes.ok && formRes.data?.id) {
                const formId = formRes.data.id;

                // 2. Simpan pengaturan templat jika tersedia
                if (template.settings) {
                    await updateFormSettings(formId, template.settings);
                }

                // 3. Simpan seluruh soal templat beserta kunci jawaban & opsi
                if (template.questions?.length > 0) {
                    const formattedQuestions = template.questions.map((q, idx) => ({
                        typeId: q.typeId,
                        question: q.question,
                        questionFormat: 'html',
                        questionOrder: idx + 1,
                        isRequired: !!q.isRequired,
                        correctAnswer: q.correctAnswer || null,
                        options: (q.options || []).map((o, oi) => ({
                            optionText: o.optionText,
                            isCorrect: !!o.isCorrect,
                            optionOrder: oi + 1,
                        })),
                    }));

                    await saveQuestions(formId, formattedQuestions);
                }

                // 4. Langsung navigasi ke Form Builder dengan data terisi utuh
                navigate(`/forms/${formId}/edit`);
            } else {
                navigate('/create-form');
            }
        } catch (err) {
            console.error('Error using template:', err);
            navigate('/create-form');
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
                        <div className="flex items-center gap-2">
                            <h2 className="text-2xl font-extrabold text-slate-900 dark:text-white tracking-tight">Galeri Templat Pilihan</h2>
                            <Sparkles size={20} className="text-[#00897B] dark:text-teal-400" />
                        </div>
                        <p className="text-xs text-slate-500 dark:text-slate-400 font-medium mt-1 max-w-xl">
                            Pilih templat profesional yang langsung terisi pertanyaan, kunci jawaban, dan pengaturan bawaan.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">

                        {filteredTemplates.map((tpl) => {
                            const IconComponent = tpl.icon;
                            const isCloning = cloningId === tpl.id;

                            return (
                                <div key={tpl.id} className="bg-white dark:bg-slate-900 rounded-3xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all flex flex-col overflow-hidden group">
                                    <div className="h-44 w-full relative bg-slate-100 dark:bg-slate-800 overflow-hidden flex items-center justify-center border-b border-slate-100 dark:border-slate-800">
                                        <img
                                            src={tpl.bannerImage}
                                            alt={tpl.title}
                                            className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                                        />
                                        <div className="absolute inset-0 bg-linear-to-t from-black/60 via-transparent to-transparent" />
                                        
                                        <div className="absolute bottom-3 left-4 right-4 flex items-center justify-between">
                                            <span className={`text-[11px] font-extrabold px-3 py-1 rounded-full shadow-xs backdrop-blur-md ${tpl.categoryColor}`}>
                                                {tpl.category}
                                            </span>
                                            <span className="text-white text-xs font-bold flex items-center gap-1.5 drop-shadow-md">
                                                <HelpCircle size={14} /> {tpl.questionCount} Soal Lengkap
                                            </span>
                                        </div>
                                    </div>

                                    <div className="p-6 flex-1 flex flex-col justify-between space-y-4">
                                        <div className="space-y-2">
                                            <div className="flex items-center gap-2">
                                                <div className="p-2 rounded-xl bg-teal-50 dark:bg-teal-950/60 text-[#00897B] dark:text-teal-400">
                                                    <IconComponent size={18} />
                                                </div>
                                                <h3 className="text-base font-extrabold text-slate-900 dark:text-white line-clamp-1 group-hover:text-[#00897B] dark:group-hover:text-teal-400 transition-colors">
                                                    {tpl.title}
                                                </h3>
                                            </div>
                                            <p className="text-xs text-slate-500 dark:text-slate-400 font-medium leading-relaxed">
                                                {tpl.description}
                                            </p>
                                        </div>

                                        <div className="pt-2 border-t border-slate-100 dark:border-slate-800">
                                            <button
                                                onClick={() => handleCreateFromTemplate(tpl)}
                                                disabled={isCloning}
                                                className="w-full py-3 px-4 bg-[#00897B] hover:bg-[#00796B] active:scale-[0.99] dark:bg-teal-600 dark:hover:bg-teal-700 text-white font-bold text-xs rounded-2xl transition-all flex items-center justify-center gap-2 disabled:opacity-60 cursor-pointer shadow-xs"
                                            >
                                                {isCloning ? (
                                                    <>
                                                        <Loader2 size={15} className="animate-spin" />
                                                        <span>Menyiapkan Formulir & Soal...</span>
                                                    </>
                                                ) : (
                                                    <>
                                                        <span>Gunakan Templat Ini</span>
                                                        <ArrowRight size={14} />
                                                    </>
                                                )}
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            );
                        })}

                    </div>

                    {filteredTemplates.length === 0 && searchQuery && (
                        <div className="py-16 text-center text-slate-400 dark:text-slate-500 text-sm font-medium">
                            Tidak ada templat yang cocok dengan pencarian "{searchQuery}".
                        </div>
                    )}

                </main>
            </div>
        </div>
    );
}