import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, Lock, Upload, Save, ArrowLeft } from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    getMyProfile, updateProfile, changePassword, uploadProfileImage,
    clearSession, assetUrl, saveSession, getLocalUser
} from '../../services/apiService';

export default function ProfilePage() {
    const navigate = useNavigate();
    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [saving, setSaving] = useState(false);
    const [toast, setToast] = useState(null);

    // Profile form
    const [fullname, setFullname] = useState('');
    const [username, setUsername] = useState('');
    const [email, setEmail] = useState('');
    const [birthdate, setBirthdate] = useState('');

    // Password form
    const [oldPassword, setOldPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [pwLoading, setPwLoading] = useState(false);
    const [pwError, setPwError] = useState('');

    useEffect(() => {
        const load = async () => {
            setLoading(true);
            const res = await getMyProfile();
            if (res.status === 401) { clearSession(); navigate('/login'); return; }
            if (res.ok && res.data) {
                const d = res.data;
                setProfile(d);
                setFullname(d.fullname || '');
                setUsername(d.username || '');
                setEmail(d.email || '');
                setBirthdate(d.birthdate ? d.birthdate.substring(0, 10) : '');
            }
            setLoading(false);
        };
        load();
    }, [navigate]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    const handleSaveProfile = async (e) => {
        e.preventDefault();
        setSaving(true);
        const res = await updateProfile({ fullname, username, birthdate });
        setSaving(false);
        if (res.ok) {
            const updated = { ...profile, fullname, username, birthdate };
            setProfile(updated);
            const current = getLocalUser();
            if (current) saveSession({ token: localStorage.getItem('token'), user: { ...current, fullname, username } });
            showToast('Profil berhasil diperbarui!');
        } else {
            showToast(res.message || 'Gagal memperbarui profil', 'error');
        }
    };

    const handleAvatarUpload = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;
        const res = await uploadProfileImage(file);
        if (res.ok) {
            const updated = await getMyProfile();
            if (updated.ok) {
                setProfile(updated.data);
                const current = getLocalUser();
                if (current) saveSession({ token: localStorage.getItem('token'), user: { ...current, profileImage: updated.data.profileImage } });
            }
            showToast('Foto profil berhasil diubah!');
        } else {
            showToast(res.message || 'Gagal mengunggah foto profil', 'error');
        }
    };

    const handleUpdatePassword = async (e) => {
        e.preventDefault();
        setPwError('');
        if (newPassword !== confirmPassword) {
            setPwError('Kata sandi baru dan konfirmasi tidak cocok.');
            return;
        }
        if (newPassword.length < 8) {
            setPwError('Kata sandi minimal harus 8 karakter.');
            return;
        }
        setPwLoading(true);
        const res = await changePassword(oldPassword, newPassword);
        setPwLoading(false);
        if (res.ok) {
            setOldPassword('');
            setNewPassword('');
            setConfirmPassword('');
            showToast('Kata sandi berhasil diperbarui!');
        } else {
            setPwError(res.message || 'Gagal memperbarui kata sandi.');
        }
    };

    if (loading) return (
        <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
            <p className="text-slate-400 dark:text-slate-500 text-sm font-medium">Memuat data profil...</p>
        </div>
    );

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 px-6 py-4 flex items-center gap-3">
                    <button onClick={() => navigate('/dashboard')} className="p-2 text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all">
                        <ArrowLeft size={18} />
                    </button>
                    <div>
                        <h1 className="text-base font-extrabold text-slate-900 dark:text-white">Pengaturan Akun & Profil</h1>
                        <p className="text-xs text-slate-400 dark:text-slate-500">Kelola informasi identitas, foto profil, dan kata sandi Anda.</p>
                    </div>
                </div>

                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-2xl shadow-xl text-xs font-bold text-white transition-all ${toast.type === 'error' ? 'bg-red-500' : 'bg-[#00897B]'}`}>
                        {toast.msg}
                    </div>
                )}

                <div className="p-6 max-w-2xl mx-auto w-full space-y-6">

                    {/* Avatar Card */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 shadow-xs flex items-center gap-6">
                        <div className="relative group">
                            <img
                                src={assetUrl(
                                    profile?.profileImage,
                                    `https://ui-avatars.com/api/?name=${encodeURIComponent(profile?.fullname || 'U')}&background=00897B&color=fff&size=128`
                                )}
                                alt={profile?.fullname}
                                className="w-20 h-20 rounded-2xl object-cover border-2 border-[#00897B]/30 dark:border-teal-500/40 shadow-sm"
                            />
                            <label className="absolute inset-0 bg-black/40 rounded-2xl flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity cursor-pointer text-white">
                                <Upload size={18} />
                                <input type="file" accept="image/*" className="hidden" onChange={handleAvatarUpload} />
                            </label>
                        </div>
                        <div className="space-y-1">
                            <h2 className="text-base font-bold text-slate-900 dark:text-white">{profile?.fullname}</h2>
                            <p className="text-xs text-slate-400 dark:text-slate-500 font-mono">@{profile?.username}</p>
                            <label className="inline-flex items-center gap-1.5 text-xs font-bold text-[#00897B] dark:text-teal-400 hover:underline cursor-pointer pt-1">
                                <Upload size={12} /> Ubah Foto Profil
                                <input type="file" accept="image/*" className="hidden" onChange={handleAvatarUpload} />
                            </label>
                        </div>
                    </div>

                    {/* Profile Information Form */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 shadow-xs space-y-4">
                        <div className="flex items-center gap-2 border-b border-slate-100 dark:border-slate-800 pb-3">
                            <User size={16} className="text-[#00897B] dark:text-teal-400" />
                            <h3 className="text-xs font-extrabold text-slate-900 dark:text-white uppercase tracking-wider">Informasi Pribadi</h3>
                        </div>

                        <form onSubmit={handleSaveProfile} className="space-y-4">
                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Nama Lengkap</label>
                                    <input
                                        type="text"
                                        required
                                        value={fullname}
                                        onChange={e => setFullname(e.target.value)}
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Nama Pengguna (Username)</label>
                                    <input
                                        type="text"
                                        required
                                        value={username}
                                        onChange={e => setUsername(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-mono font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>
                            </div>

                            <div>
                                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Alamat Email</label>
                                <input
                                    type="email"
                                    disabled
                                    value={email}
                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-slate-50 dark:bg-slate-800/50 text-slate-400 dark:text-slate-500 cursor-not-allowed"
                                />
                                <p className="text-[11px] text-slate-400 dark:text-slate-500 mt-1">Alamat email terdaftar tidak dapat diubah secara langsung.</p>
                            </div>

                            <div>
                                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Tanggal Lahir</label>
                                <input
                                    type="date"
                                    value={birthdate}
                                    onChange={e => setBirthdate(e.target.value)}
                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                />
                            </div>

                            <div className="pt-2 flex justify-end">
                                <button
                                    type="submit"
                                    disabled={saving}
                                    className="flex items-center gap-1.5 px-5 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer disabled:opacity-60"
                                >
                                    <Save size={14} /> {saving ? 'Menyimpan...' : 'Simpan Perubahan'}
                                </button>
                            </div>
                        </form>
                    </div>

                    {/* Change Password Form */}
                    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 p-6 shadow-xs space-y-4">
                        <div className="flex items-center gap-2 border-b border-slate-100 dark:border-slate-800 pb-3">
                            <Lock size={16} className="text-[#00897B] dark:text-teal-400" />
                            <h3 className="text-xs font-extrabold text-slate-900 dark:text-white uppercase tracking-wider">Ubah Kata Sandi</h3>
                        </div>

                        {pwError && (
                            <div className="px-4 py-2.5 bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 rounded-xl text-xs font-bold text-red-600 dark:text-red-400">
                                {pwError}
                            </div>
                        )}

                        <form onSubmit={handleUpdatePassword} className="space-y-4">
                            <div>
                                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Kata Sandi Saat Ini</label>
                                <input
                                    type="password"
                                    required
                                    value={oldPassword}
                                    onChange={e => setOldPassword(e.target.value)}
                                    placeholder="Masukkan kata sandi saat ini"
                                    className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                />
                            </div>

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Kata Sandi Baru</label>
                                    <input
                                        type="password"
                                        required
                                        value={newPassword}
                                        onChange={e => setNewPassword(e.target.value)}
                                        placeholder="Min. 8 karakter"
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">Konfirmasi Kata Sandi Baru</label>
                                    <input
                                        type="password"
                                        required
                                        value={confirmPassword}
                                        onChange={e => setConfirmPassword(e.target.value)}
                                        placeholder="Ulangi kata sandi baru"
                                        className="w-full border border-slate-200 dark:border-slate-700 rounded-xl px-3.5 py-2 text-xs font-semibold bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-[#00897B]"
                                    />
                                </div>
                            </div>

                            <div className="pt-2 flex justify-end">
                                <button
                                    type="submit"
                                    disabled={pwLoading}
                                    className="flex items-center gap-1.5 px-5 py-2.5 bg-slate-900 hover:bg-slate-800 dark:bg-teal-600 dark:hover:bg-teal-700 text-white text-xs font-bold rounded-xl shadow-xs transition-all cursor-pointer disabled:opacity-60"
                                >
                                    <Lock size={14} /> {pwLoading ? 'Memperbarui...' : 'Perbarui Kata Sandi'}
                                </button>
                            </div>
                        </form>
                    </div>

                </div>
            </div>
        </div>
    );
}
