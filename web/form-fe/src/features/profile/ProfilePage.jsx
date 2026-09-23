import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  User, Lock, Upload, Save, CheckCircle2, AlertCircle, Loader2, X, Eye, EyeOff, ShieldCheck, Sun, Moon 
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
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

  // State Mode Gelap / Terang
  const [isDark, setIsDark] = useState(() => {
    return document.documentElement.classList.contains('dark');
  });

  // Form Profil
  const [fullname, setFullname] = useState('');

  // Modal & State Password
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  
  // Toggle visibilitas password
  const [showOldPw, setShowOldPw] = useState(false);
  const [showNewPw, setShowNewPw] = useState(false);
  const [showConfirmPw, setShowConfirmPw] = useState(false);

  const [pwLoading, setPwLoading] = useState(false);
  const [pwError, setPwError] = useState('');

  // Modal Preview Foto
  const [showImagePreview, setShowImagePreview] = useState(false);

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const res = await getMyProfile();
      if (res.status === 401) { clearSession(); navigate('/login'); return; }
      if (res.ok && res.data) {
        const d = res.data;
        setProfile(d);
        setFullname(d.fullname || '');
      }
      setLoading(false);
    };
    load();
  }, [navigate]);

  // Handler Ganti Mode Gelap/Terang
  const toggleDarkMode = () => {
    if (isDark) {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('theme', 'light');
      setIsDark(false);
    } else {
      document.documentElement.classList.add('dark');
      localStorage.setItem('theme', 'dark');
      setIsDark(true);
    }
  };

  const showToast = (msg, type = 'success') => {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3000);
  };

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setSaving(true);
    const res = await updateProfile({ fullname });
    setSaving(false);
    if (res.ok) {
      const updated = { ...profile, fullname };
      setProfile(updated);
      const current = getLocalUser();
      if (current) saveSession({ token: localStorage.getItem('token'), user: { ...current, fullname } });
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
      closePasswordModal();
      showToast('Kata sandi berhasil diperbarui!');
    } else {
      setPwError(res.message || 'Gagal memperbarui kata sandi.');
    }
  };

  const closePasswordModal = () => {
    setShowPasswordModal(false);
    setPwError('');
    setOldPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setShowOldPw(false);
    setShowNewPw(false);
    setShowConfirmPw(false);
  };

  if (loading) return (
    <div className="flex items-center justify-center min-h-screen bg-[#F4F8F7] dark:bg-slate-950">
      <div className="flex items-center gap-3 text-slate-500 dark:text-slate-400 font-medium">
        <Loader2 size={22} className="animate-spin text-[#00897B]" />
        <span>Memuat data profil...</span>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-screen w-full bg-[#F4F8F7] dark:bg-slate-950 font-sans antialiased text-slate-800 dark:text-slate-100 transition-colors">
      <Sidebar />

      <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
        {/* Header Responsif */}
        <header className="relative overflow-hidden bg-white/80 dark:bg-slate-900/80 border-b border-slate-200/80 dark:border-slate-800/80 px-4 sm:px-8 py-4 sm:py-6 sticky top-0 z-30 backdrop-blur-xl">
          <div className="absolute top-0 right-1/4 w-96 h-full bg-gradient-to-r from-teal-500/10 via-emerald-500/5 to-transparent blur-2xl pointer-events-none" />
          <div className="relative z-10 w-full">
            <h1 className="text-xl sm:text-2xl font-bold text-slate-900 dark:text-white tracking-tight">
              Pengaturan Profil
            </h1>
            <p className="text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 mt-0.5 sm:mt-1">
              Kelola informasi akun dan keamanan kata sandi Anda
            </p>
          </div>
        </header>

        {/* Toast Notification Responsif */}
        <AnimatePresence>
          {toast && (
            <motion.div
              initial={{ opacity: 0, y: -20, scale: 0.9 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -10, scale: 0.9 }}
              transition={{ type: "spring", stiffness: 400, damping: 25 }}
              className="fixed top-4 right-4 left-4 sm:left-auto sm:top-6 sm:right-6 z-50"
            >
              <div
                className={`flex items-center justify-center sm:justify-start gap-3 px-4 py-3 sm:px-5 sm:py-3.5 rounded-2xl shadow-xl text-xs sm:text-sm font-semibold text-white backdrop-blur-xl border border-white/20 ${
                  toast.type === "error"
                    ? "bg-red-500/90 shadow-red-500/10"
                    : "bg-teal-600/90 shadow-teal-600/10"
                }`}
              >
                {toast.type === "error" ? (
                  <AlertCircle size={18} />
                ) : (
                  <CheckCircle2 size={18} />
                )}
                <span>{toast.msg}</span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Main Content Area Responsif */}
        <main className="p-4 sm:p-8 w-full max-w-4xl mx-auto space-y-4 sm:space-y-8">
          
          {/* CARD TEMA: HANYA MUNCUL DI HP / MOBILE (sm:hidden) */}
          <motion.div
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            className="block sm:hidden bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800/80 p-5 shadow-sm"
          >
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3.5">
                <div className="p-3 rounded-xl bg-teal-50 dark:bg-teal-950/50 text-[#00897B] dark:text-teal-400 border border-teal-100 dark:border-teal-900/40 shrink-0">
                  {isDark ? <Moon size={20} /> : <Sun size={20} />}
                </div>
                <div>
                  <h2 className="text-sm font-bold text-slate-900 dark:text-white uppercase tracking-wider">
                    Tampilan Aplikasi
                  </h2>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                    {isDark ? 'Mode Gelap Aktif' : 'Mode Terang Aktif'}
                  </p>
                </div>
              </div>

              {/* Toggle Switch */}
              <button
                type="button"
                onClick={toggleDarkMode}
                className={`relative inline-flex h-7 w-12 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none ${
                  isDark ? 'bg-[#00897B]' : 'bg-slate-200'
                }`}
              >
                <span
                  className={`pointer-events-none inline-block h-6 w-6 transform rounded-full bg-white shadow-lg ring-0 transition duration-200 ease-in-out ${
                    isDark ? 'translate-x-5' : 'translate-x-0'
                  }`}
                />
              </button>
            </div>
          </motion.div>

          {/* CARD 1: INFORMASI PENGGUNA */}
          <motion.div
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3 }}
            className="bg-white dark:bg-slate-900 rounded-2xl sm:rounded-3xl border border-slate-200/80 dark:border-slate-800/80 p-5 sm:p-8 shadow-sm space-y-6 sm:space-y-8"
          >
            {/* Foto Profil & Info */}
            <div className="flex flex-col sm:flex-row items-center sm:items-start gap-4 sm:gap-6">
              <div
                className="relative group shrink-0 cursor-pointer"
                onClick={() => setShowImagePreview(true)}
              >
                <div className="p-1 rounded-2xl sm:rounded-3xl bg-slate-200 dark:bg-slate-800">
                  <img
                    src={assetUrl(
                      profile?.profileImage,
                      `https://ui-avatars.com/api/?name=${encodeURIComponent(
                        profile?.fullname || "User"
                      )}&background=00897B&color=fff&size=256`
                    )}
                    alt={profile?.fullname || "Foto Profil"}
                    className="w-20 h-20 sm:w-24 sm:h-24 rounded-[18px] sm:rounded-[22px] object-cover bg-white dark:bg-slate-800"
                  />
                </div>
                <div className="absolute inset-1 bg-slate-900/40 rounded-[18px] sm:rounded-[22px] flex flex-col items-center justify-center opacity-0 group-hover:opacity-100 transition-all duration-200 text-white backdrop-blur-[2px]">
                  <Eye size={18} />
                  <span className="text-[10px] sm:text-xs font-semibold mt-0.5">Lihat</span>
                </div>
              </div>

              <div className="space-y-2 sm:space-y-3 text-center sm:text-left flex-1">
                <div>
                  <h3 className="text-lg sm:text-xl font-bold text-slate-900 dark:text-white">
                    {profile?.fullname || "Pengguna"}
                  </h3>
                  <p className="text-xs sm:text-sm text-slate-500 dark:text-slate-400 break-all">
                    {profile?.email}
                  </p>
                </div>

                <div>
                  <label className="inline-flex items-center gap-2 px-3.5 py-2 bg-slate-100 hover:bg-teal-50 dark:bg-slate-800 dark:hover:bg-teal-950/50 text-slate-700 dark:text-slate-200 hover:text-[#00897B] dark:hover:text-teal-400 text-xs font-semibold rounded-xl cursor-pointer transition-all border border-transparent hover:border-teal-200 dark:hover:border-teal-800/60">
                    <Upload size={14} />
                    <span>Ganti Foto Profil</span>
                    <input
                      type="file"
                      accept="image/*"
                      className="hidden"
                      onChange={handleAvatarUpload}
                    />
                  </label>
                </div>
              </div>
            </div>

            {/* Form Update Fullname */}
            <form onSubmit={handleSaveProfile} className="space-y-4 sm:space-y-6 pt-2">
              <div className="w-full space-y-1.5 sm:space-y-2">
                <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                  Nama Lengkap
                </label>
                <input
                  type="text"
                  required
                  value={fullname}
                  onChange={(e) => setFullname(e.target.value)}
                  placeholder="Nama lengkap Anda"
                  className="w-full border border-slate-200 dark:border-slate-700 rounded-xl sm:rounded-2xl px-3.5 py-2.5 sm:px-4 sm:py-3 text-xs sm:text-sm font-medium bg-slate-50/50 dark:bg-slate-800/50 text-slate-900 dark:text-white focus:bg-white dark:focus:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-[#00897B] transition-all"
                />
              </div>

              <div className="flex justify-end pt-1 sm:pt-2">
                <motion.button
                  whileTap={{ scale: 0.97 }}
                  type="submit"
                  disabled={saving}
                  className="w-full sm:w-auto flex items-center justify-center gap-2 px-6 py-2.5 sm:px-7 sm:py-3 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl sm:rounded-2xl transition-colors cursor-pointer disabled:opacity-60"
                >
                  {saving ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <Save size={16} />
                  )}
                  <span>{saving ? "Menyimpan..." : "Simpan Perubahan"}</span>
                </motion.button>
              </div>
            </form>
          </motion.div>

          {/* CARD 2: KEAMANAN & SANDI */}
          <motion.div
            initial={{ opacity: 0, y: 15 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.3, delay: 0.1 }}
            className="bg-white dark:bg-slate-900 rounded-2xl sm:rounded-3xl border border-slate-200/80 dark:border-slate-800/80 p-5 sm:p-8 shadow-sm flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 sm:gap-6"
          >
            <div className="flex items-start sm:items-center gap-3.5 sm:gap-4">
              <div className="p-3 sm:p-3.5 rounded-xl sm:rounded-2xl bg-teal-50 dark:bg-teal-950/50 text-[#00897B] dark:text-teal-400 border border-teal-100 dark:border-teal-900/40 shrink-0">
                <ShieldCheck size={22} className="sm:w-6 sm:h-6" />
              </div>
              <div>
                <h2 className="text-sm sm:text-base font-bold text-slate-900 dark:text-white uppercase tracking-wider">
                  Keamanan & Sandi
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5 sm:mt-1">
                  Perbarui kata sandi secara berkala untuk menjaga akun tetap aman.
                </p>
              </div>
            </div>

            <button
              type="button"
              onClick={() => setShowPasswordModal(true)}
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-5 py-2.5 sm:px-6 sm:py-3 bg-slate-100 hover:bg-slate-200/80 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-800 dark:text-slate-100 text-xs font-bold rounded-xl sm:rounded-2xl transition-all cursor-pointer border border-slate-200/60 dark:border-slate-700/60 shrink-0"
            >
              <Lock size={15} />
              <span>Ubah Kata Sandi</span>
            </button>
          </motion.div>
        </main>
      </div>

      {/* Modal Ubah Kata Sandi Responsif */}
      <AnimatePresence>
        {showPasswordModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={closePasswordModal}
              className="absolute inset-0 bg-slate-950/60 backdrop-blur-sm"
            />

            <motion.div
              initial={{ opacity: 0, scale: 0.95, y: 15 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95, y: 15 }}
              transition={{ type: "spring", duration: 0.3 }}
              className="relative w-full max-w-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl sm:rounded-3xl shadow-2xl overflow-hidden z-10 max-h-[90vh] flex flex-col"
            >
              <div className="px-5 py-4 sm:px-7 sm:py-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between shrink-0">
                <div className="flex items-center gap-3">
                  <div className="p-2 sm:p-2.5 rounded-xl sm:rounded-2xl bg-teal-50 dark:bg-teal-950/50 text-[#00897B] dark:text-teal-400 border border-teal-100 dark:border-teal-900/40">
                    <Lock size={18} className="sm:w-5 sm:h-5" />
                  </div>
                  <div>
                    <h3 className="text-sm sm:text-base font-bold text-slate-900 dark:text-white">
                      Ubah Kata Sandi
                    </h3>
                    <p className="text-[11px] sm:text-xs text-slate-500 dark:text-slate-400">
                      Masukkan kata sandi lama dan kata sandi baru
                    </p>
                  </div>
                </div>
                <button
                  onClick={closePasswordModal}
                  className="p-1.5 sm:p-2 text-slate-400 hover:text-slate-700 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-all cursor-pointer"
                >
                  <X size={18} />
                </button>
              </div>

              <form onSubmit={handleUpdatePassword} className="p-5 sm:p-7 space-y-4 sm:space-y-5 overflow-y-auto">
                {pwError && (
                  <motion.div
                    initial={{ opacity: 0, y: -5 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="p-3.5 sm:p-4 bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800/60 rounded-xl sm:rounded-2xl text-xs font-semibold text-red-600 dark:text-red-400 flex items-center gap-2.5"
                  >
                    <AlertCircle size={16} className="shrink-0" />
                    <span>{pwError}</span>
                  </motion.div>
                )}

                {/* Kata Sandi Saat Ini */}
                <div className="space-y-1.5 sm:space-y-2">
                  <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                    Kata Sandi Saat Ini
                  </label>
                  <div className="relative">
                    <input
                      type={showOldPw ? "text" : "password"}
                      required
                      value={oldPassword}
                      onChange={(e) => setOldPassword(e.target.value)}
                      placeholder="••••••••"
                      className="w-full border border-slate-200 dark:border-slate-700 rounded-xl sm:rounded-2xl pl-3.5 pr-10 py-2.5 sm:py-3 text-xs sm:text-sm font-medium bg-slate-50/50 dark:bg-slate-800/50 text-slate-900 dark:text-white focus:bg-white dark:focus:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-[#00897B] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowOldPw(!showOldPw)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer p-1"
                    >
                      {showOldPw ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                {/* Kata Sandi Baru */}
                <div className="space-y-1.5 sm:space-y-2">
                  <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                    Kata Sandi Baru
                  </label>
                  <div className="relative">
                    <input
                      type={showNewPw ? "text" : "password"}
                      required
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      placeholder="Minimal 8 karakter"
                      className="w-full border border-slate-200 dark:border-slate-700 rounded-xl sm:rounded-2xl pl-3.5 pr-10 py-2.5 sm:py-3 text-xs sm:text-sm font-medium bg-slate-50/50 dark:bg-slate-800/50 text-slate-900 dark:text-white focus:bg-white dark:focus:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-[#00897B] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowNewPw(!showNewPw)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer p-1"
                    >
                      {showNewPw ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                {/* Konfirmasi Kata Sandi Baru */}
                <div className="space-y-1.5 sm:space-y-2">
                  <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300">
                    Konfirmasi Kata Sandi Baru
                  </label>
                  <div className="relative">
                    <input
                      type={showConfirmPw ? "text" : "password"}
                      required
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Ulangi kata sandi baru"
                      className="w-full border border-slate-200 dark:border-slate-700 rounded-xl sm:rounded-2xl pl-3.5 pr-10 py-2.5 sm:py-3 text-xs sm:text-sm font-medium bg-slate-50/50 dark:bg-slate-800/50 text-slate-900 dark:text-white focus:bg-white dark:focus:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-[#00897B] transition-all"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPw(!showConfirmPw)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 cursor-pointer p-1"
                    >
                      {showConfirmPw ? <EyeOff size={16} /> : <Eye size={16} />}
                    </button>
                  </div>
                </div>

                <div className="pt-2 sm:pt-3 flex flex-col-reverse sm:flex-row items-center justify-end gap-2.5 sm:gap-3">
                  <button
                    type="button"
                    onClick={closePasswordModal}
                    className="w-full sm:w-auto px-5 py-2.5 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs font-semibold rounded-xl sm:rounded-2xl transition-all cursor-pointer"
                  >
                    Batal
                  </button>
                  <motion.button
                    whileTap={{ scale: 0.97 }}
                    type="submit"
                    disabled={pwLoading}
                    className="w-full sm:w-auto flex items-center justify-center gap-2 px-6 py-2.5 bg-[#00897B] hover:bg-[#00796B] text-white text-xs font-bold rounded-xl sm:rounded-2xl transition-colors cursor-pointer disabled:opacity-60"
                  >
                    {pwLoading ? (
                      <Loader2 size={16} className="animate-spin" />
                    ) : (
                      <Lock size={15} />
                    )}
                    <span>
                      {pwLoading ? "Memperbarui..." : "Simpan Kata Sandi"}
                    </span>
                  </motion.button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>

      {/* Modal Preview Foto Profil Responsif */}
      <AnimatePresence>
        {showImagePreview && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowImagePreview(false)}
              className="absolute inset-0 bg-slate-950/80 backdrop-blur-md"
            />
            <motion.div
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              className="relative z-10 max-w-sm sm:max-w-md w-full bg-white dark:bg-slate-900 rounded-3xl p-5 sm:p-6 border border-slate-200 dark:border-slate-800 shadow-2xl flex flex-col items-center"
            >
              <button
                onClick={() => setShowImagePreview(false)}
                className="absolute top-4 right-4 p-2 text-slate-400 hover:text-slate-700 dark:hover:text-white bg-slate-100 dark:bg-slate-800 rounded-full transition-all cursor-pointer"
              >
                <X size={18} />
              </button>
              <img
                src={assetUrl(
                  profile?.profileImage,
                  `https://ui-avatars.com/api/?name=${encodeURIComponent(
                    profile?.fullname || "User"
                  )}&background=00897B&color=fff&size=512`
                )}
                alt="Preview Profil"
                className="w-56 h-56 sm:w-72 sm:h-72 rounded-2xl object-cover my-4"
              />
              <p className="text-sm font-bold text-slate-700 dark:text-slate-300">
                {profile?.fullname || "Pengguna"}
              </p>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}