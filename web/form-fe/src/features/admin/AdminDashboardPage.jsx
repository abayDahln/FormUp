import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Users, FileText, MessageSquare, Shield, Ban, CheckCircle,
    Trash2, Eye, ShieldAlert, ArrowLeft, X, Calendar, Hash
} from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    adminGetUsers, adminGetUserDetail, adminBanUser, adminActivateUser, adminDeleteUser,
    adminGetForms, adminGetFormDetail, adminTakedownForm, adminRestoreForm, adminDeleteForm,
    adminGetFeedback, adminDeleteFeedback, adminTakedownFormFromFeedback, adminRestoreFormFromFeedback,
    getLocalUser, clearSession
} from '../../services/apiService';

const formatDate = (d) => d
    ? new Date(d).toLocaleString('id-ID', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
    : '—';

export default function AdminDashboardPage() {
    const navigate = useNavigate();
    const currentUser = getLocalUser();

    const [activeTab, setActiveTab] = useState('users');
    const [loading, setLoading] = useState(true);
    const [toast, setToast] = useState(null);

    const [users, setUsers] = useState([]);
    const [forms, setForms] = useState([]);
    const [feedbacks, setFeedbacks] = useState([]);

    // Detail modals
    const [userDetail, setUserDetail] = useState(null);
    const [userDetailLoading, setUserDetailLoading] = useState(false);
    const [formDetail, setFormDetail] = useState(null);
    const [formDetailLoading, setFormDetailLoading] = useState(false);

    useEffect(() => {
        if (currentUser?.role !== 'ADMIN') {
            navigate('/dashboard');
            return;
        }
        loadData();
    }, [activeTab]);

    const showToast = (msg, type = 'success') => {
        setToast({ msg, type });
        setTimeout(() => setToast(null), 3000);
    };

    const loadData = async () => {
        setLoading(true);
        if (activeTab === 'users') {
            const res = await adminGetUsers();
            if (res.status === 401) { clearSession(); navigate('/login'); return; }
            if (res.ok) setUsers(Array.isArray(res.data) ? res.data : res.data?.users || []);
        } else if (activeTab === 'forms') {
            const res = await adminGetForms();
            if (res.status === 401) { clearSession(); navigate('/login'); return; }
            if (res.ok) setForms(Array.isArray(res.data) ? res.data : res.data?.forms || []);
        } else if (activeTab === 'feedback') {
            const res = await adminGetFeedback();
            if (res.status === 401) { clearSession(); navigate('/login'); return; }
            if (res.ok) setFeedbacks(Array.isArray(res.data) ? res.data : res.data?.feedbacks || []);
        }
        setLoading(false);
    };

    // ── User Detail Modal ─────────────────────────────────────────────────────
    const openUserDetail = async (userId) => {
        setUserDetailLoading(true);
        setUserDetail({ _loading: true });
        const res = await adminGetUserDetail(userId);
        setUserDetailLoading(false);
        if (res.ok && res.data) setUserDetail(res.data);
        else setUserDetail(null);
    };

    // ── Form Detail Modal ─────────────────────────────────────────────────────
    const openFormDetail = async (formId) => {
        setFormDetailLoading(true);
        setFormDetail({ _loading: true });
        const res = await adminGetFormDetail(formId);
        setFormDetailLoading(false);
        if (res.ok && res.data) setFormDetail(res.data);
        else setFormDetail(null);
    };

    // ── User Actions ──────────────────────────────────────────────────────────
    const handleBanUser = async (userId) => {
        const res = await adminBanUser(userId);
        if (res.ok) { showToast('User banned'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    const handleActivateUser = async (userId) => {
        const res = await adminActivateUser(userId);
        if (res.ok) { showToast('User activated'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    const handleDeleteUser = async (userId) => {
        if (!window.confirm('Hapus user ini?')) return;
        const res = await adminDeleteUser(userId);
        if (res.ok) { showToast('User deleted'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    // ── Form Actions ──────────────────────────────────────────────────────────
    const handleTakedownForm = async (formId) => {
        const res = await adminTakedownForm(formId);
        if (res.ok) { showToast('Form taken down'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    const handleRestoreForm = async (formId) => {
        const res = await adminRestoreForm(formId);
        if (res.ok) { showToast('Form restored'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    const handleDeleteForm = async (formId) => {
        if (!window.confirm('Hapus form ini?')) return;
        const res = await adminDeleteForm(formId);
        if (res.ok) { showToast('Form deleted'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    // ── Feedback Actions ──────────────────────────────────────────────────────
    const handleDeleteFeedback = async (feedbackId) => {
        const res = await adminDeleteFeedback(feedbackId);
        if (res.ok) { showToast('Feedback removed'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    const handleTakedownFromFeedback = async (feedbackId) => {
        const res = await adminTakedownFormFromFeedback(feedbackId);
        if (res.ok) { showToast('Associated form taken down'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    const handleRestoreFromFeedback = async (feedbackId) => {
        const res = await adminRestoreFormFromFeedback(feedbackId);
        if (res.ok) { showToast('Form restored'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center gap-3">
                    <button onClick={() => navigate('/dashboard')} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg">
                        <ArrowLeft size={18} />
                    </button>
                    <div>
                        <h1 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                            <Shield className="text-teal-600" size={18} /> Admin Control Center
                        </h1>
                        <p className="text-xs text-slate-400">Manage users, forms, and reported feedback across FormUp</p>
                    </div>
                </div>

                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-xs font-bold text-white ${toast.type === 'error' ? 'bg-red-500' : 'bg-teal-600'}`}>
                        {toast.msg}
                    </div>
                )}

                {/* Tabs */}
                <div className="flex border-b border-slate-200 bg-white px-6">
                    {[
                        { key: 'users', label: '👥 User Management' },
                        { key: 'forms', label: '📋 All Forms' },
                        { key: 'feedback', label: '⚠️ Feedback Reports' },
                    ].map(tab => (
                        <button
                            key={tab.key}
                            onClick={() => setActiveTab(tab.key)}
                            className={`py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all ${activeTab === tab.key ? 'border-teal-600 text-teal-600' : 'border-transparent text-slate-400 hover:text-slate-700'}`}
                        >
                            {tab.label}
                        </button>
                    ))}
                </div>

                <div className="p-6 max-w-6xl mx-auto w-full">
                    {loading ? (
                        <div className="text-center py-16 text-slate-400 text-sm">Loading admin data...</div>
                    ) : (
                        <>
                            {/* ── USERS TAB ── */}
                            {activeTab === 'users' && (
                                <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
                                    <table className="w-full text-sm text-left">
                                        <thead>
                                            <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                                <th className="py-3 px-4">User</th>
                                                <th className="py-3 px-4">Role</th>
                                                <th className="py-3 px-4">Status</th>
                                                <th className="py-3 px-4">Forms</th>
                                                <th className="py-3 px-4 text-right">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100">
                                            {users.length === 0 && (
                                                <tr><td colSpan={5} className="py-10 text-center text-slate-400 text-xs">No users found.</td></tr>
                                            )}
                                            {users.map(u => (
                                                <tr key={u.id} className="hover:bg-slate-50">
                                                    <td className="py-3 px-4">
                                                        <div className="font-bold text-slate-900">{u.fullname || u.username}</div>
                                                        <div className="text-xs text-slate-400">{u.email}</div>
                                                    </td>
                                                    <td className="py-3 px-4">
                                                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${u.role === 'ADMIN' ? 'bg-purple-50 text-purple-600' : 'bg-slate-100 text-slate-600'}`}>
                                                            {u.role}
                                                        </span>
                                                    </td>
                                                    <td className="py-3 px-4">
                                                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${u.isActive ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600'}`}>
                                                            {u.isActive ? 'Active' : 'Banned'}
                                                        </span>
                                                    </td>
                                                    <td className="py-3 px-4 text-xs font-semibold text-slate-600">{u.formCount ?? 0}</td>
                                                    <td className="py-3 px-4 text-right">
                                                        <div className="flex items-center justify-end gap-1.5">
                                                            <button
                                                                onClick={() => openUserDetail(u.id)}
                                                                className="p-1 text-teal-500 hover:text-teal-700 rounded"
                                                                title="Lihat Detail"
                                                            >
                                                                <Eye size={14} />
                                                            </button>
                                                            {u.isActive ? (
                                                                <button onClick={() => handleBanUser(u.id)} className="px-2.5 py-1 bg-amber-50 text-amber-700 text-xs font-bold rounded-lg hover:bg-amber-100">
                                                                    <Ban size={12} className="inline mr-1" /> Ban
                                                                </button>
                                                            ) : (
                                                                <button onClick={() => handleActivateUser(u.id)} className="px-2.5 py-1 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100">
                                                                    <CheckCircle size={12} className="inline mr-1" /> Activate
                                                                </button>
                                                            )}
                                                            <button onClick={() => handleDeleteUser(u.id)} className="p-1 text-red-400 hover:text-red-600 rounded">
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )}

                            {/* ── FORMS TAB ── */}
                            {activeTab === 'forms' && (
                                <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
                                    <table className="w-full text-sm text-left">
                                        <thead>
                                            <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                                <th className="py-3 px-4">Form</th>
                                                <th className="py-3 px-4">Owner</th>
                                                <th className="py-3 px-4">Status</th>
                                                <th className="py-3 px-4">Responses</th>
                                                <th className="py-3 px-4 text-right">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100">
                                            {forms.length === 0 && (
                                                <tr><td colSpan={5} className="py-10 text-center text-slate-400 text-xs">No forms found.</td></tr>
                                            )}
                                            {forms.map(f => (
                                                <tr key={f.id} className="hover:bg-slate-50">
                                                    <td className="py-3 px-4">
                                                        <div className="font-bold text-slate-900">{f.title}</div>
                                                        <div className="text-xs font-mono text-slate-400">/f/{f.formLink}</div>
                                                    </td>
                                                    <td className="py-3 px-4 text-xs">
                                                        <div className="font-semibold text-slate-800">{f.ownerName || 'Unknown'}</div>
                                                        <div className="text-slate-400">{f.ownerEmail}</div>
                                                    </td>
                                                    <td className="py-3 px-4">
                                                        {f.takenDownAt ? (
                                                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-700">Taken Down</span>
                                                        ) : (
                                                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-50 text-teal-600">{f.status}</span>
                                                        )}
                                                    </td>
                                                    <td className="py-3 px-4 text-xs font-semibold text-slate-600">{f.responseCount ?? 0}</td>
                                                    <td className="py-3 px-4 text-right">
                                                        <div className="flex items-center justify-end gap-1.5">
                                                            <button
                                                                onClick={() => openFormDetail(f.id)}
                                                                className="p-1 text-teal-500 hover:text-teal-700 rounded"
                                                                title="Lihat Detail"
                                                            >
                                                                <Eye size={14} />
                                                            </button>
                                                            {f.takenDownAt ? (
                                                                <button onClick={() => handleRestoreForm(f.id)} className="px-2.5 py-1 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100">
                                                                    Restore
                                                                </button>
                                                            ) : (
                                                                <button onClick={() => handleTakedownForm(f.id)} className="px-2.5 py-1 bg-amber-50 text-amber-700 text-xs font-bold rounded-lg hover:bg-amber-100">
                                                                    <ShieldAlert size={12} className="inline mr-1" /> Takedown
                                                                </button>
                                                            )}
                                                            <button onClick={() => handleDeleteForm(f.id)} className="p-1 text-red-400 hover:text-red-600 rounded">
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )}

                            {/* ── FEEDBACK TAB ── */}
                            {activeTab === 'feedback' && (
                                <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
                                    <table className="w-full text-sm text-left">
                                        <thead>
                                            <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                                <th className="py-3 px-4">Reason</th>
                                                <th className="py-3 px-4">Description</th>
                                                <th className="py-3 px-4">Form</th>
                                                <th className="py-3 px-4">Reporter</th>
                                                <th className="py-3 px-4 text-right">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100">
                                            {feedbacks.length === 0 && (
                                                <tr><td colSpan={5} className="py-10 text-center text-slate-400 text-xs">No feedback reports found.</td></tr>
                                            )}
                                            {feedbacks.map(fb => (
                                                <tr key={fb.id} className="hover:bg-slate-50">
                                                    <td className="py-3 px-4 font-bold text-slate-900 text-xs">{fb.reason}</td>
                                                    <td className="py-3 px-4 text-xs text-slate-600 max-w-xs truncate">{fb.description || '—'}</td>
                                                    <td className="py-3 px-4 text-xs font-semibold text-slate-800">{fb.formTitle || `Form #${fb.formId}`}</td>
                                                    <td className="py-3 px-4 text-xs text-slate-500">{fb.userName || '—'}</td>
                                                    <td className="py-3 px-4 text-right">
                                                        <div className="flex items-center justify-end gap-1.5">
                                                            <button
                                                                onClick={() => handleTakedownFromFeedback(fb.id)}
                                                                className="px-2.5 py-1 bg-amber-50 text-amber-700 text-xs font-bold rounded-lg hover:bg-amber-100"
                                                            >
                                                                <ShieldAlert size={11} className="inline mr-1" /> Takedown
                                                            </button>
                                                            <button
                                                                onClick={() => handleRestoreFromFeedback(fb.id)}
                                                                className="px-2.5 py-1 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100"
                                                            >
                                                                Restore
                                                            </button>
                                                            <button onClick={() => handleDeleteFeedback(fb.id)} className="p-1 text-red-400 hover:text-red-600 rounded">
                                                                <Trash2 size={14} />
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>
                            )}
                        </>
                    )}
                </div>
            </div>

            {/* ── USER DETAIL MODAL ── */}
            {userDetail && (
                <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4">
                    <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md">
                        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100">
                            <h3 className="text-sm font-extrabold text-slate-900">Detail User</h3>
                            <button onClick={() => setUserDetail(null)} className="text-slate-400 hover:text-slate-700 rounded-lg p-1">
                                <X size={17} />
                            </button>
                        </div>

                        {userDetailLoading || userDetail._loading ? (
                            <div className="py-12 text-center text-slate-400 text-xs">Memuat data...</div>
                        ) : (
                            <div className="p-5 space-y-5">
                                {/* Avatar + name */}
                                <div className="flex items-center gap-4">
                                    <div className="w-14 h-14 rounded-full bg-teal-100 text-teal-700 flex items-center justify-center text-xl font-extrabold shrink-0">
                                        {(userDetail.fullname || userDetail.username || 'U').charAt(0).toUpperCase()}
                                    </div>
                                    <div>
                                        <p className="text-base font-extrabold text-slate-900">{userDetail.fullname || '—'}</p>
                                        <p className="text-xs text-slate-400">@{userDetail.username || '—'}</p>
                                        <p className="text-xs text-slate-400">{userDetail.email}</p>
                                    </div>
                                    <div className="ml-auto flex flex-col gap-1 items-end">
                                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${userDetail.role === 'ADMIN' ? 'bg-purple-50 text-purple-600' : 'bg-slate-100 text-slate-600'}`}>
                                            {userDetail.role}
                                        </span>
                                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${userDetail.isActive ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600'}`}>
                                            {userDetail.isActive ? 'Active' : 'Banned'}
                                        </span>
                                    </div>
                                </div>

                                {/* Stats */}
                                <div className="grid grid-cols-2 gap-3">
                                    <div className="bg-slate-50 rounded-xl px-4 py-3">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Forms</p>
                                        <p className="text-xl font-extrabold text-slate-900 mt-0.5">{userDetail.formCount ?? 0}</p>
                                    </div>
                                    <div className="bg-slate-50 rounded-xl px-4 py-3">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Responses</p>
                                        <p className="text-xl font-extrabold text-slate-900 mt-0.5">{userDetail.responseCount ?? 0}</p>
                                    </div>
                                </div>

                                {/* Dates */}
                                <div className="space-y-2 text-xs">
                                    {userDetail.birthdate && (
                                        <div className="flex items-center gap-2 text-slate-600">
                                            <Calendar size={13} className="text-slate-400" />
                                            <span className="font-semibold">Lahir:</span>
                                            <span>{userDetail.birthdate?.split('T')[0]}</span>
                                        </div>
                                    )}
                                    <div className="flex items-center gap-2 text-slate-600">
                                        <Hash size={13} className="text-slate-400" />
                                        <span className="font-semibold">ID:</span>
                                        <span className="font-mono">{userDetail.id}</span>
                                    </div>
                                    <div className="flex items-center gap-2 text-slate-600">
                                        <span className="font-semibold">Bergabung:</span>
                                        <span>{formatDate(userDetail.createdAt)}</span>
                                    </div>
                                    {userDetail.deletedAt && (
                                        <div className="flex items-center gap-2 text-red-600 font-bold">
                                            <span>Deleted:</span>
                                            <span>{formatDate(userDetail.deletedAt)}</span>
                                        </div>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* ── FORM DETAIL MODAL ── */}
            {formDetail && (
                <div className="fixed inset-0 z-50 bg-black/40 backdrop-blur-sm flex items-center justify-center p-4">
                    <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[85vh] flex flex-col">
                        <div className="flex items-center justify-between px-5 py-4 border-b border-slate-100 shrink-0">
                            <h3 className="text-sm font-extrabold text-slate-900">Detail Form</h3>
                            <button onClick={() => setFormDetail(null)} className="text-slate-400 hover:text-slate-700 rounded-lg p-1">
                                <X size={17} />
                            </button>
                        </div>

                        {formDetailLoading || formDetail._loading ? (
                            <div className="py-12 text-center text-slate-400 text-xs">Memuat data...</div>
                        ) : (
                            <div className="overflow-y-auto p-5 space-y-4">
                                {/* Form header */}
                                <div>
                                    <div className="flex items-start justify-between gap-2">
                                        <h4 className="text-base font-extrabold text-slate-900 leading-tight">{formDetail.title}</h4>
                                        <div className="flex flex-col gap-1 items-end shrink-0">
                                            {formDetail.takenDownAt ? (
                                                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-700">Taken Down</span>
                                            ) : (
                                                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-50 text-teal-600">{formDetail.status}</span>
                                            )}
                                        </div>
                                    </div>
                                    <p className="text-xs font-mono text-slate-400 mt-1">/f/{formDetail.formLink}</p>
                                    {formDetail.description && (
                                        <p className="text-xs text-slate-600 mt-2 line-clamp-3">{formDetail.description}</p>
                                    )}
                                </div>

                                {/* Stats */}
                                <div className="grid grid-cols-2 gap-3">
                                    <div className="bg-slate-50 rounded-xl px-4 py-3">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Responses</p>
                                        <p className="text-xl font-extrabold text-slate-900 mt-0.5">{formDetail.responseCount ?? 0}</p>
                                    </div>
                                    <div className="bg-slate-50 rounded-xl px-4 py-3">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Form ID</p>
                                        <p className="text-xl font-extrabold text-slate-900 mt-0.5 font-mono">#{formDetail.id}</p>
                                    </div>
                                </div>

                                {/* Owner */}
                                {formDetail.owner && (
                                    <div className="bg-slate-50 rounded-xl p-4">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Owner</p>
                                        <div className="flex items-center gap-3">
                                            <div className="w-8 h-8 rounded-full bg-teal-100 text-teal-700 flex items-center justify-center text-xs font-extrabold">
                                                {(formDetail.owner.fullname || 'U').charAt(0)}
                                            </div>
                                            <div>
                                                <p className="text-xs font-bold text-slate-900">{formDetail.owner.fullname}</p>
                                                <p className="text-[11px] text-slate-400">{formDetail.owner.email}</p>
                                            </div>
                                        </div>
                                    </div>
                                )}

                                {/* Settings */}
                                {formDetail.settings && (
                                    <div>
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1.5">Settings</p>
                                        <pre className="bg-slate-900 text-teal-300 text-[11px] rounded-xl p-3 overflow-x-auto font-mono leading-relaxed">
                                            {JSON.stringify(formDetail.settings, null, 2)}
                                        </pre>
                                    </div>
                                )}

                                {/* Dates */}
                                <div className="space-y-1.5 text-xs text-slate-600">
                                    <div className="flex gap-2"><span className="font-bold w-24 shrink-0">Dibuat:</span><span>{formatDate(formDetail.createdAt)}</span></div>
                                    <div className="flex gap-2"><span className="font-bold w-24 shrink-0">Diupdate:</span><span>{formatDate(formDetail.updatedAt)}</span></div>
                                    {formDetail.takenDownAt && (
                                        <div className="flex gap-2 text-red-600 font-bold"><span className="w-24 shrink-0">Taken Down:</span><span>{formatDate(formDetail.takenDownAt)}</span></div>
                                    )}
                                    {formDetail.deletedAt && (
                                        <div className="flex gap-2 text-red-600 font-bold"><span className="w-24 shrink-0">Deleted:</span><span>{formatDate(formDetail.deletedAt)}</span></div>
                                    )}
                                </div>
                            </div>
                        )}
                    </div>
                </div>
            )}
        </div>
    );
}
