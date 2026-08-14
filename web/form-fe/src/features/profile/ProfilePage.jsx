import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Camera, Save, Lock, User, ArrowLeft, CheckCircle, AlertCircle, Eye, EyeOff } from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    getMyProfile, updateProfile, changePassword, uploadProfileImage,
    saveSession, clearSession, assetUrl
} from '../../services/apiService';

export default function ProfilePage() {
    const navigate = useNavigate();
    const fileInputRef = useRef(null);

    const [profile, setProfile] = useState(null);
    const [loading, setLoading] = useState(true);
    const [activeTab, setActiveTab] = useState('profile');

    // Profile form
    const [fullname, setFullname] = useState('');
    const [username, setUsername] = useState('');
    const [birthdate, setBirthdate] = useState('');
    const [profileSaving, setProfileSaving] = useState(false);

    // Password form
    const [currentPassword, setCurrentPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showCurrent, setShowCurrent] = useState(false);
    const [showNew, setShowNew] = useState(false);
    const [passwordSaving, setPasswordSaving] = useState(false);

    // Photo upload
    const [photoUploading, setPhotoUploading] = useState(false);
    const [photoPreview, setPhotoPreview] = useState(null);

    // Feedback
    const [toast, setToast] = useState(null);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3500);
    };

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
                setBirthdate(d.birthdate ? d.birthdate.split('T')[0] : '');
            }
            setLoading(false);
        };
        load();
    }, [navigate]);

    const handleProfileSave = async (e) => {
        e.preventDefault();
        setProfileSaving(true);
        const res = await updateProfile({ fullname, username, birthdate: birthdate || null });
        setProfileSaving(false);
        if (res.ok) {
            // Update localStorage user data too
            const freshRes = await getMyProfile();
            if (freshRes.ok && freshRes.data) {
                saveSession({ user: freshRes.data });
                setProfile(freshRes.data);
            }
            showToast('Profil berhasil diperbarui!');
        } else {
            showToast(res.message || 'Gagal memperbarui profil.', 'error');
        }
    };

    const handlePasswordSave = async (e) => {
        e.preventDefault();
        if (newPassword !== confirmPassword) {
            showToast('Password baru dan konfirmasi tidak sama.', 'error');
            return;
        }
        if (newPassword.length < 8) {
            showToast('Password baru minimal 8 karakter.', 'error');
            return;
        }
        setPasswordSaving(true);
        const res = await changePassword(currentPassword, newPassword);
        setPasswordSaving(false);
        if (res.ok) {
            setCurrentPassword('');
            setNewPassword('');
            setConfirmPassword('');
            showToast('Password berhasil diubah!');
        } else {
            showToast(res.message || 'Gagal mengganti password.', 'error');
        }
    };

    const handlePhotoChange = async (e) => {
        const file = e.target.files?.[0];
        if (!file) return;

        // Preview locally first
        const reader = new FileReader();
        reader.onload = (ev) => setPhotoPreview(ev.target.result);
        reader.readAsDataURL(file);

        setPhotoUploading(true);
        const res = await uploadProfileImage(file);
        setPhotoUploading(false);

        if (res.ok && res.data?.profileImage) {
            const freshRes = await getMyProfile();
            if (freshRes.ok && freshRes.data) {
                saveSession({ user: freshRes.data });
                setProfile(freshRes.data);
            }
            showToast('Foto profil berhasil diperbarui!');
        } else {
            setPhotoPreview(null);
            showToast(res.message || 'Gagal upload foto.', 'error');
        }
    };

    if (loading) return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            <Sidebar />
            <div className="flex-1 flex items-center justify-center">
                <div className="flex flex-col items-center gap-3">
                    <div className="w-8 h-8 border-2 border-teal-500 border-t-transparent rounded-full animate-spin" />
                    <p className="text-xs text-slate-400 font-medium">Memuat profil...</p>
                </div>
            </div>
        </div>
    );

    const avatarSrc = photoPreview || assetUrl(profile?.profileImage, `https://ui-avatars.com/api/?name=${encodeURIComponent(profile?.fullname || 'U')}&background=6DBFB3&color=fff&size=128`);

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            <Sidebar />

            {/* Toast Notification */}
            {toast && (
                <div className={`fixed top-5 right-5 z-50 flex items-center gap-2.5 px-4 py-3 rounded-2xl shadow-xl text-sm font-bold text-white transition-all animate-in slide-in-from-top-4 ${toast.type === 'error' ? 'bg-red-500' : 'bg-teal-600'}`}>
                    {toast.type === 'error' ? <AlertCircle size={16} /> : <CheckCircle size={16} />}
                    {toast.msg}
                </div>
            )}

            <div className="flex-1 overflow-y-auto">
                {/* Top bar */}
                <div className="sticky top-0 z-20 bg-white border-b border-slate-200 px-6 py-4 flex items-center gap-3">
                    <button onClick={() => navigate('/dashboard')} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg transition-colors">
                        <ArrowLeft size={18} />
                    </button>
                    <div>
                        <h1 className="text-base font-extrabold text-slate-900">Pengaturan Akun</h1>
                        <p className="text-xs text-slate-400">Kelola profil, foto, dan keamanan akun Anda</p>
                    </div>
                </div>

                <div className="max-w-3xl mx-auto px-6 py-8 space-y-6">

                    {/* Profile Photo Card */}
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs">
                        <div className="flex items-center gap-6">
                            <div className="relative shrink-0">
                                <img
                                    src={avatarSrc}
                                    alt="Foto Profil"
                                    className="w-20 h-20 rounded-full object-cover border-2 border-teal-200 shadow"
                                />
                                {photoUploading && (
                                    <div className="absolute inset-0 rounded-full bg-black/40 flex items-center justify-center">
                                        <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                    </div>
                                )}
                                <button
                                    onClick={() => fileInputRef.current?.click()}
                                    className="absolute -bottom-1 -right-1 w-7 h-7 bg-teal-600 hover:bg-teal-700 text-white rounded-full flex items-center justify-center shadow transition-colors"
                                    title="Ubah foto profil"
                                >
                                    <Camera size={13} />
                                </button>
                                <input
                                    ref={fileInputRef}
                                    type="file"
                                    accept="image/jpg,image/jpeg,image/png,image/gif,image/webp"
                                    className="hidden"
                                    onChange={handlePhotoChange}
                                />
                            </div>
                            <div>
                                <h2 className="text-base font-extrabold text-slate-900">{profile?.fullname}</h2>
                                <p className="text-xs text-slate-400 mt-0.5">@{profile?.username || '—'}</p>
                                <p className="text-xs text-slate-400">{profile?.email}</p>
                                <span className={`mt-1.5 inline-block text-[10px] font-bold px-2 py-0.5 rounded-full ${profile?.role === 'ADMIN' ? 'bg-purple-50 text-purple-600' : 'bg-teal-50 text-teal-600'}`}>
                                    {profile?.role}
                                </span>
                            </div>
                        </div>
                        <p className="text-[11px] text-slate-400 mt-4">Format: JPG, PNG, GIF, WebP · Maks 10 MB</p>
                    </div>

                    {/* Tabs */}
                    <div className="flex border-b border-slate-200 bg-white rounded-t-2xl px-4">
                        {[
                            { key: 'profile', label: 'Data Profil', icon: User },
                            { key: 'password', label: 'Keamanan', icon: Lock },
                        ].map(tab => {
                            const Icon = tab.icon;
                            return (
                                <button
                                    key={tab.key}
                                    onClick={() => setActiveTab(tab.key)}
                                    className={`flex items-center gap-2 py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all ${activeTab === tab.key ? 'border-teal-600 text-teal-600' : 'border-transparent text-slate-400 hover:text-slate-700'}`}
                                >
                                    <Icon size={14} />{tab.label}
                                </button>
                            );
                        })}
                    </div>

                    {/* Profile Tab */}
                    {activeTab === 'profile' && (
                        <div className="bg-white rounded-b-2xl rounded-tr-2xl border border-slate-200 border-t-0 p-6 shadow-xs">
                            <form onSubmit={handleProfileSave} className="space-y-5">
                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-5">
                                    <div>
                                        <label className="block text-xs font-bold text-slate-700 mb-1.5">Nama Lengkap</label>
                                        <input
                                            type="text"
                                            value={fullname}
                                            onChange={e => setFullname(e.target.value)}
                                            placeholder="Nama lengkap Anda"
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                                        />
                                    </div>
                                    <div>
                                        <label className="block text-xs font-bold text-slate-700 mb-1.5">Username</label>
                                        <input
                                            type="text"
                                            value={username}
                                            onChange={e => setUsername(e.target.value)}
                                            placeholder="username_anda"
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                                        />
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 mb-1.5">Email</label>
                                    <input
                                        type="email"
                                        value={profile?.email || ''}
                                        disabled
                                        className="w-full border border-slate-100 rounded-xl px-3.5 py-2.5 text-sm bg-slate-50 text-slate-400 cursor-not-allowed"
                                    />
                                    <p className="text-[11px] text-slate-400 mt-1">Email tidak dapat diubah.</p>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 mb-1.5">Tanggal Lahir</label>
                                    <input
                                        type="date"
                                        value={birthdate}
                                        onChange={e => setBirthdate(e.target.value)}
                                        className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                                    />
                                </div>

                                <div className="pt-2 flex justify-end">
                                    <button
                                        type="submit"
                                        disabled={profileSaving}
                                        className="flex items-center gap-2 px-6 py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-bold text-sm rounded-xl shadow-sm transition-all disabled:opacity-60"
                                    >
                                        <Save size={15} />
                                        {profileSaving ? 'Menyimpan...' : 'Simpan Perubahan'}
                                    </button>
                                </div>
                            </form>
                        </div>
                    )}

                    {/* Password Tab */}
                    {activeTab === 'password' && (
                        <div className="bg-white rounded-b-2xl rounded-tr-2xl border border-slate-200 border-t-0 p-6 shadow-xs">
                            <form onSubmit={handlePasswordSave} className="space-y-5">
                                <div>
                                    <label className="block text-xs font-bold text-slate-700 mb-1.5">Password Saat Ini</label>
                                    <div className="relative">
                                        <input
                                            type={showCurrent ? 'text' : 'password'}
                                            value={currentPassword}
                                            onChange={e => setCurrentPassword(e.target.value)}
                                            required
                                            placeholder="Masukkan password lama"
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 pr-11 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                                        />
                                        <button type="button" onClick={() => setShowCurrent(v => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700">
                                            {showCurrent ? <EyeOff size={16} /> : <Eye size={16} />}
                                        </button>
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 mb-1.5">Password Baru</label>
                                    <div className="relative">
                                        <input
                                            type={showNew ? 'text' : 'password'}
                                            value={newPassword}
                                            onChange={e => setNewPassword(e.target.value)}
                                            required
                                            placeholder="Minimal 8 karakter"
                                            className="w-full border border-slate-200 rounded-xl px-3.5 py-2.5 pr-11 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all"
                                        />
                                        <button type="button" onClick={() => setShowNew(v => !v)} className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700">
                                            {showNew ? <EyeOff size={16} /> : <Eye size={16} />}
                                        </button>
                                    </div>
                                </div>

                                <div>
                                    <label className="block text-xs font-bold text-slate-700 mb-1.5">Konfirmasi Password Baru</label>
                                    <input
                                        type="password"
                                        value={confirmPassword}
                                        onChange={e => setConfirmPassword(e.target.value)}
                                        required
                                        placeholder="Ulangi password baru"
                                        className={`w-full border rounded-xl px-3.5 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-400 transition-all ${confirmPassword && confirmPassword !== newPassword ? 'border-red-300 bg-red-50' : 'border-slate-200'}`}
                                    />
                                    {confirmPassword && confirmPassword !== newPassword && (
                                        <p className="text-[11px] text-red-500 font-bold mt-1">Password tidak cocok.</p>
                                    )}
                                </div>

                                <div className="pt-2 flex justify-end">
                                    <button
                                        type="submit"
                                        disabled={passwordSaving}
                                        className="flex items-center gap-2 px-6 py-2.5 bg-teal-600 hover:bg-teal-700 text-white font-bold text-sm rounded-xl shadow-sm transition-all disabled:opacity-60"
                                    >
                                        <Lock size={15} />
                                        {passwordSaving ? 'Menyimpan...' : 'Ubah Password'}
                                    </button>
                                </div>
                            </form>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
