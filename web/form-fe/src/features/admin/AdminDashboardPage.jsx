import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Users, FileText, MessageSquare, Shield, Ban, CheckCircle, Trash2, Eye, ShieldAlert, ArrowLeft } from 'lucide-react';
import Sidebar from '../../components/layout/Sidebar';
import {
    adminGetUsers, adminBanUser, adminActivateUser, adminDeleteUser,
    adminGetForms, adminTakedownForm, adminRestoreForm, adminDeleteForm,
    adminGetFeedback, adminDeleteFeedback, adminTakedownFormFromFeedback, adminRestoreFormFromFeedback,
    getLocalUser, clearSession
} from '../../services/apiService';

export default function AdminDashboardPage() {
    const navigate = useNavigate();
    const currentUser = getLocalUser();

    const [activeTab, setActiveTab] = useState('users');
    const [loading, setLoading] = useState(true);
    const [toast, setToast] = useState(null);

    // Data lists
    const [users, setUsers] = useState([]);
    const [forms, setForms] = useState([]);
    const [feedbacks, setFeedbacks] = useState([]);

    useEffect(() => {
        if (currentUser?.role !== 'ADMIN') {
            // Not an admin
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

    // User Actions
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
        if (!window.confirm('Delete this user?')) return;
        const res = await adminDeleteUser(userId);
        if (res.ok) { showToast('User deleted'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    // Form Actions
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
        if (!window.confirm('Delete this form?')) return;
        const res = await adminDeleteForm(formId);
        if (res.ok) { showToast('Form deleted'); loadData(); }
        else showToast(res.message || 'Action failed', 'error');
    };

    // Feedback Actions
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

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <div className="bg-white border-b border-slate-200 px-6 py-4 flex items-center justify-between gap-4">
                    <div className="flex items-center gap-3">
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
                </div>

                {toast && (
                    <div className={`fixed top-4 right-4 z-50 px-4 py-3 rounded-xl shadow-lg text-xs font-bold text-white ${toast.type === 'error' ? 'bg-red-500' : 'bg-teal-600'}`}>
                        {toast.msg}
                    </div>
                )}

                {/* Tabs */}
                <div className="flex border-b border-slate-200 bg-white px-6">
                    {[
                        { key: 'users', label: '👥 User Management', icon: Users },
                        { key: 'forms', label: '📋 All Forms', icon: FileText },
                        { key: 'feedback', label: '⚠️ Feedback Reports', icon: MessageSquare },
                    ].map(tab => (
                        <button
                            key={tab.key}
                            onClick={() => setActiveTab(tab.key)}
                            className={`py-3.5 px-5 text-xs font-extrabold border-b-2 transition-all flex items-center gap-2 ${activeTab === tab.key ? 'border-teal-600 text-teal-600' : 'border-transparent text-slate-400 hover:text-slate-700'}`}
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
                            {/* USERS TAB */}
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
                                                            {u.isActive ? (
                                                                <button onClick={() => handleBanUser(u.id)} className="px-2.5 py-1 bg-amber-50 text-amber-700 text-xs font-bold rounded-lg hover:bg-amber-100" title="Ban user">
                                                                    <Ban size={12} className="inline mr-1" /> Ban
                                                                </button>
                                                            ) : (
                                                                <button onClick={() => handleActivateUser(u.id)} className="px-2.5 py-1 bg-emerald-50 text-emerald-700 text-xs font-bold rounded-lg hover:bg-emerald-100" title="Activate user">
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

                            {/* FORMS TAB */}
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

                            {/* FEEDBACK TAB */}
                            {activeTab === 'feedback' && (
                                <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-xs">
                                    <table className="w-full text-sm text-left">
                                        <thead>
                                            <tr className="bg-slate-50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                                <th className="py-3 px-4">Reason</th>
                                                <th className="py-3 px-4">Description</th>
                                                <th className="py-3 px-4">Form</th>
                                                <th className="py-3 px-4 text-right">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody className="divide-y divide-slate-100">
                                            {feedbacks.map(fb => (
                                                <tr key={fb.id} className="hover:bg-slate-50">
                                                    <td className="py-3 px-4 font-bold text-slate-900 text-xs">{fb.reason}</td>
                                                    <td className="py-3 px-4 text-xs text-slate-600 max-w-xs truncate">{fb.description || '—'}</td>
                                                    <td className="py-3 px-4 text-xs font-semibold text-slate-800">{fb.formTitle || `Form #${fb.formId}`}</td>
                                                    <td className="py-3 px-4 text-right">
                                                        <div className="flex items-center justify-end gap-1.5">
                                                            <button onClick={() => handleTakedownFromFeedback(fb.id)} className="px-2.5 py-1 bg-amber-50 text-amber-700 text-xs font-bold rounded-lg hover:bg-amber-100">
                                                                Takedown Form
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
        </div>
    );
}
