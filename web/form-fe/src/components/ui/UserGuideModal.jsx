import { useState } from 'react';
import { 
    X, 
    BookOpen, 
    Sparkles, 
    FileText, 
    Share2, 
    BarChart3, 
    PlayCircle, 
    CheckCircle2, 
    ShieldCheck, 
    HelpCircle,
    ChevronRight,
    QrCode,
    Sliders,
    Layers
} from 'lucide-react';

export default function UserGuideModal({
    isOpen = false,
    onClose = () => {},
    onStartTour = () => {}
}) {
    const [activeTab, setActiveTab] = useState('overview');

    if (!isOpen) return null;

    const tabs = [
        { id: 'overview', label: 'Ringkasan Cepat', icon: BookOpen },
        { id: 'builder', label: 'Editor Formulir & Kuis', icon: FileText },
        { id: 'ai', label: 'Kecerdasan AI', icon: Sparkles },
        { id: 'sharing', label: 'Membagikan & Ujian', icon: Share2 },
        { id: 'analytics', label: 'Respons & Penilaian', icon: BarChart3 },
    ];

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 sm:p-6 select-none animate-in fade-in duration-200">
            {/* Backdrop */}
            <div 
                className="fixed inset-0 bg-slate-900/60 backdrop-blur-xs transition-opacity cursor-pointer"
                onClick={onClose}
            />

            {/* Modal Box */}
            <div className="relative bg-white dark:bg-slate-900 rounded-3xl shadow-2xl border border-slate-200/80 dark:border-slate-800 w-full max-w-3xl max-h-[90vh] flex flex-col overflow-hidden z-10 animate-in zoom-in-95 duration-200">
                {/* Modal Header */}
                <div className="px-6 py-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between bg-slate-50/50 dark:bg-slate-900/50">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-2xl bg-teal-50 dark:bg-teal-950/60 flex items-center justify-center text-[#00897B] dark:text-teal-400 border border-teal-200/60 dark:border-teal-800/60 shadow-xs">
                            <BookOpen size={20} />
                        </div>
                        <div>
                            <h2 className="text-lg font-bold text-slate-900 dark:text-white tracking-tight flex items-center gap-2">
                                Panduan Pengguna FormUp
                                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-teal-100 dark:bg-teal-900/60 text-teal-700 dark:text-teal-300">
                                    Bantuan
                                </span>
                            </h2>
                            <p className="text-xs text-slate-500 dark:text-slate-400">
                                Pelajari cara memaksimalkan fitur formulir, kuis interaktif, dan evaluasi otomatis.
                            </p>
                        </div>
                    </div>

                    <button
                        type="button"
                        onClick={onClose}
                        className="p-2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors cursor-pointer"
                        title="Tutup Modal (Esc)"
                    >
                        <X size={20} />
                    </button>
                </div>

                {/* Tab Navigation */}
                <div className="flex items-center gap-1.5 px-6 pt-3 border-b border-slate-100 dark:border-slate-800 overflow-x-auto no-scrollbar bg-white dark:bg-slate-900">
                    {tabs.map((tab) => {
                        const Icon = tab.icon;
                        const isActive = activeTab === tab.id;
                        return (
                            <button
                                key={tab.id}
                                type="button"
                                onClick={() => setActiveTab(tab.id)}
                                className={`flex items-center gap-2 px-3.5 py-2.5 text-xs font-bold rounded-t-xl border-b-2 whitespace-nowrap transition-all cursor-pointer ${
                                    isActive
                                        ? 'border-teal-600 text-teal-600 dark:border-teal-400 dark:text-teal-400 bg-teal-50/40 dark:bg-teal-950/30'
                                        : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800/50'
                                }`}
                            >
                                <Icon size={15} />
                                <span>{tab.label}</span>
                            </button>
                        );
                    })}
                </div>

                {/* Modal Content Body */}
                <div className="flex-1 overflow-y-auto p-6 text-slate-700 dark:text-slate-300 text-sm space-y-4">
                    {activeTab === 'overview' && (
                        <div className="space-y-4">
                            <div className="p-4 rounded-2xl bg-gradient-to-br from-teal-500/10 via-emerald-500/5 to-transparent border border-teal-500/20">
                                <h3 className="font-bold text-slate-900 dark:text-white text-base mb-1 flex items-center gap-2">
                                    🚀 Selamat Datang di FormUp!
                                </h3>
                                <p className="text-xs text-slate-600 dark:text-slate-300 leading-relaxed">
                                    FormUp dirancang untuk mempermudah siapa saja membuat formulir pendaftaran, survei kepuasan, hingga kuis & ujian online terstruktur dengan sistem penilaian instan.
                                </p>
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
                                <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-800 space-y-1.5">
                                    <div className="flex items-center gap-2 text-teal-600 dark:text-teal-400 font-bold text-xs uppercase tracking-wide">
                                        <FileText size={16} />
                                        <span>1. Buat Formulir</span>
                                    </div>
                                    <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                                        Pilih <b>Buat Formulir Baru</b> atau manfaatkan <b>Buat dengan AI</b> untuk menyusun pertanyaan kuis secara otomatis dalam hitungan detik.
                                    </p>
                                </div>

                                <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-800 space-y-1.5">
                                    <div className="flex items-center gap-2 text-indigo-600 dark:text-indigo-400 font-bold text-xs uppercase tracking-wide">
                                        <Share2 size={16} />
                                        <span>2. Bagikan & Ujian</span>
                                    </div>
                                    <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                                        Sebarkan link formulir, unduh QR Code, atau aktifkan <b>Mode Ujian</b> untuk mengunci layar dan mendeteksi kecurangan responden secara langsung.
                                    </p>
                                </div>

                                <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-800 space-y-1.5">
                                    <div className="flex items-center gap-2 text-emerald-600 dark:text-emerald-400 font-bold text-xs uppercase tracking-wide">
                                        <BarChart3 size={16} />
                                        <span>3. Pantau Respons</span>
                                    </div>
                                    <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                                        Buka tab <b>Respons</b> untuk melihat submission, skor otomatis PG, analisis jawaban, hingga ekspor data ke Excel atau CSV.
                                    </p>
                                </div>

                                <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-800 space-y-1.5">
                                    <div className="flex items-center gap-2 text-amber-600 dark:text-amber-400 font-bold text-xs uppercase tracking-wide">
                                        <Sliders size={16} />
                                        <span>4. Evaluasi Fleksibel</span>
                                    </div>
                                    <p className="text-xs text-slate-600 dark:text-slate-400 leading-relaxed">
                                        Gunakan fitur koreksi manual essay, bantuan penilaian holistik Gemini AI, atau penyesuaian skor massal untuk nilai akhir.
                                    </p>
                                </div>
                            </div>
                        </div>
                    )}

                    {activeTab === 'builder' && (
                        <div className="space-y-4 text-xs leading-relaxed">
                            <h3 className="font-bold text-slate-900 dark:text-white text-sm">
                                Fitur Utama Editor Formulir
                            </h3>
                            <ul className="space-y-2.5">
                                <li className="flex items-start gap-2.5">
                                    <CheckCircle2 size={16} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <div>
                                        <strong className="text-slate-900 dark:text-white">Ragam Tipe Pertanyaan:</strong> Mendukung Pilihan Ganda, Checkbox, Dropdown, Jawaban Singkat, Paragraf/Essay, hingga Skala Linear & Upload File.
                                    </div>
                                </li>
                                <li className="flex items-start gap-2.5">
                                    <CheckCircle2 size={16} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <div>
                                        <strong className="text-slate-900 dark:text-white">Format Kaya (WYSIWYG & KaTeX):</strong> Tambahkan teks tebal, miring, rumus matematika KaTeX, hingga blok kode pemrograman langsung di soal.
                                    </div>
                                </li>
                                <li className="flex items-start gap-2.5">
                                    <CheckCircle2 size={16} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <div>
                                        <strong className="text-slate-900 dark:text-white">Sistem Kuis & Kunci Jawaban:</strong> Tentukan kunci jawaban yang benar dan bobot poin per soal untuk penilaian otomatis.
                                    </div>
                                </li>
                                <li className="flex items-start gap-2.5">
                                    <CheckCircle2 size={16} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <div>
                                        <strong className="text-slate-900 dark:text-white">Pengaturan Pintar:</strong> Acak urutan soal, batas waktu pengerjaan (timer otomatis), batasi 1 kali pengisian, dan kustomisasi pesan terima kasih.
                                    </div>
                                </li>
                            </ul>
                        </div>
                    )}

                    {activeTab === 'ai' && (
                        <div className="space-y-4 text-xs leading-relaxed">
                            <div className="p-4 rounded-2xl bg-teal-50/50 dark:bg-teal-950/40 border border-teal-200/60 dark:border-teal-800/60 flex items-start gap-3">
                                <Sparkles size={22} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                <div className="space-y-1">
                                    <h4 className="font-bold text-slate-900 dark:text-white text-sm">Pembuat Formulir Otomatis dengan AI</h4>
                                    <p className="text-slate-600 dark:text-slate-300">
                                        Cukup ketik topik atau deskripsikan kebutuhan kuis Anda (contoh: <i>"Buat 5 soal pilihan ganda tentang Hukum Newton untuk kelas 10 SMA"</i>), dan FormUp AI akan menyusun soal, opsi pilihan, serta kunci jawabannya secara instan.
                                    </p>
                                </div>
                            </div>

                            <h4 className="font-bold text-slate-900 dark:text-white text-sm">Langkah Menggunakan AI Builder:</h4>
                            <ol className="list-decimal list-inside space-y-2 text-slate-600 dark:text-slate-300">
                                <li>Klik tombol <b>"Buat dengan AI"</b> di dashboard atau menu utama.</li>
                                <li>Ketik topik materi atau upload file acuan dokumen/silabus.</li>
                                <li>Pilih jumlah soal dan tingkat kesulitan yang diinginkan.</li>
                                <li>Klik <b>Generate</b>, preview hasilnya, lalu klik <b>Simpan ke Form Builder</b> untuk mengedit lebih lanjut.</li>
                            </ol>
                        </div>
                    )}

                    {activeTab === 'sharing' && (
                        <div className="space-y-4 text-xs leading-relaxed">
                            <h3 className="font-bold text-slate-900 dark:text-white text-sm">
                                Distribusi & Mode Pengawasan Ujian
                            </h3>
                            <div className="space-y-3">
                                <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-800 flex items-start gap-3">
                                    <QrCode size={18} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <div>
                                        <strong className="text-slate-900 dark:text-white">QR Code & Link Publik:</strong> Bagikan tautan langsung atau unduh gambar QR Code formulir untuk ditempel pada poster, ruang kelas, atau media sosial.
                                    </div>
                                </div>

                                <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-800 flex items-start gap-3">
                                    <ShieldCheck size={18} className="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
                                    <div>
                                        <strong className="text-slate-900 dark:text-white">Mode Ujian Aman:</strong> Memaksa layar penuh (fullscreen), memblokir pindah tab, mencegah copy-paste dan inspect element, serta mencatat log pelanggaran secara real-time.
                                    </div>
                                </div>
                            </div>
                        </div>
                    )}

                    {activeTab === 'analytics' && (
                        <div className="space-y-4 text-xs leading-relaxed">
                            <h3 className="font-bold text-slate-900 dark:text-white text-sm">
                                Rekap Nilai & Analisis Jawaban
                            </h3>
                            <p className="text-slate-600 dark:text-slate-400">
                                Semua respons yang dikirimkan oleh audiens akan tercatat rapi di halaman <b>Respons</b>. Anda dapat:
                            </p>
                            <ul className="space-y-2">
                                <li className="flex items-start gap-2">
                                    <CheckCircle2 size={15} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <span><b>Koreksi Jawaban Essay:</b> Nilai jawaban uraian siswa dan berikan catatan evaluasi secara manual atau bantuan AI.</span>
                                </li>
                                <li className="flex items-start gap-2">
                                    <CheckCircle2 size={15} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <span><b>Penyesuaian Skor Massal:</b> Tambahkan nilai bonus atau normalisasi batas nilai kelulusan sekaligus.</span>
                                </li>
                                <li className="flex items-start gap-2">
                                    <CheckCircle2 size={15} className="text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                                    <span><b>Ekspor Data:</b> Unduh lembar jawaban ke format Microsoft Excel (.xlsx) atau CSV untuk arsip.</span>
                                </li>
                            </ul>
                        </div>
                    )}
                </div>

                {/* Modal Footer */}
                <div className="px-6 py-4 border-t border-slate-100 dark:border-slate-800 flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-50/50 dark:bg-slate-900/50">
                    <button
                        type="button"
                        onClick={() => {
                            onClose();
                            onStartTour();
                        }}
                        className="inline-flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-teal-600 to-emerald-600 hover:from-teal-700 hover:to-emerald-700 text-white font-bold text-xs rounded-xl shadow-xs transition-all active:scale-95 cursor-pointer w-full sm:w-auto justify-center"
                    >
                        <PlayCircle size={16} />
                        <span>Mulai Tur Interaktif (Spotlight)</span>
                    </button>

                    <button
                        type="button"
                        onClick={onClose}
                        className="px-5 py-2.5 text-xs font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors cursor-pointer w-full sm:w-auto"
                    >
                        Tutup Panduan
                    </button>
                </div>
            </div>
        </div>
    );
}
