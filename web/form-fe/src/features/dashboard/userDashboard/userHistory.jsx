import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    FileText,
    Award,
    Eye,
    Edit3,
    BarChart2,
    Plus
} from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';

export default function History() {
    const navigate = useNavigate();
    const [activeTab, setActiveTab] = useState('completed'); // 'completed' | 'created'

    // Data 1: Form yang pernah dikerjakan pengguna
    const completedHistory = [
        {
            id: 1,
            title: 'Mathematics Final Exam 2024',
            date: 'Oct 24, 2023',
            status: 'Submitted',
            score: '92/100',
        },
        {
            id: 2,
            title: 'General Course Evaluation',
            date: 'Oct 18, 2023',
            status: 'Under Review',
            score: 'N/A',
        },
        {
            id: 3,
            title: 'HR Onboarding Feedback',
            date: 'Oct 05, 2023',
            status: 'Reviewed',
            score: 'Reviewed',
        },
    ];

    // Data 2: Form yang dibuat oleh pengguna
    const createdFormsHistory = [
        {
            id: 101,
            title: 'Customer Feedback Q3',
            category: 'Marketing Campaign',
            status: 'Published',
            createdDate: 'Oct 24, 2023',
            responses: 412,
        },
        {
            id: 102,
            title: 'Employee Onboarding 2024',
            category: 'Internal HR',
            status: 'Draft',
            createdDate: 'Nov 02, 2023',
            responses: 0,
        },
        {
            id: 103,
            title: 'Event Registration: TechConf',
            category: 'Events Team',
            status: 'Published',
            createdDate: 'Oct 12, 2023',
            responses: 856,
        },
    ];

    return (
        <div className="flex min-h-screen w-full bg-slate-50 font-sans">
            {/* Sidebar Left */}
            <Sidebar />

            {/* Main Content Area (Memenuhi sisa space/full-width) */}
            <div className="flex-1 flex flex-col min-w-0 min-h-screen overflow-y-auto">
                <div className="p-8 space-y-8 w-full flex-1">
                    
                    {/* Topbar / Header */}
                    <Topbar />

                    {/* Page Title Header */}
                    <div>
                        <h1 className="text-2xl font-bold text-slate-800">History & Activity</h1>
                        <p className="text-sm text-slate-500 mt-1">
                            Track your submissions and manage your form life cycles.
                        </p>
                    </div>

                    {/* Stats Grid */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full">
                        
                        {/* Stat Card 1: Total Submissions */}
                        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div className="space-y-2">
                                <div className="p-2.5 bg-teal-50 w-fit rounded-xl text-[#6DBFB3]">
                                    <FileText size={22} />
                                </div>
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                                    Total Submissions
                                </p>
                                <h3 className="text-3xl font-extrabold text-slate-800">48</h3>
                            </div>
                            <span className="self-start text-xs font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full">
                                +12%
                            </span>
                        </div>

                        {/* Stat Card 2: Average Score */}
                        <div className="bg-white p-6 rounded-2xl border border-slate-100 shadow-sm flex items-center justify-between">
                            <div className="space-y-2">
                                <div className="p-2.5 bg-indigo-50 w-fit rounded-xl text-indigo-500">
                                    <Award size={22} />
                                </div>
                                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
                                    Average Score
                                </p>
                                <h3 className="text-3xl font-extrabold text-slate-800">88.5%</h3>
                            </div>
                            <span className="self-start text-xs font-bold text-emerald-600 bg-emerald-50 px-2.5 py-1 rounded-full">
                                +24%
                            </span>
                        </div>

                    </div>

                    {/* Main Content Container */}
                    <div className="bg-white rounded-2xl border border-slate-100 shadow-sm overflow-hidden w-full">
                        
                        {/* Navigation Tabs */}
                        <div className="flex border-b border-slate-100 px-6 pt-4 gap-8">
                            <button
                                onClick={() => setActiveTab('completed')}
                                className={`pb-4 text-sm font-bold border-b-2 transition-all ${
                                    activeTab === 'completed'
                                        ? 'border-[#6DBFB3] text-[#6DBFB3]'
                                        : 'border-transparent text-slate-400 hover:text-slate-600'
                                }`}
                            >
                                Completed Tasks
                            </button>
                            <button
                                onClick={() => setActiveTab('created')}
                                className={`pb-4 text-sm font-bold border-b-2 transition-all ${
                                    activeTab === 'created'
                                        ? 'border-[#6DBFB3] text-[#6DBFB3]'
                                        : 'border-transparent text-slate-400 hover:text-slate-600'
                                }`}
                            >
                                Created Forms
                            </button>
                        </div>

                        {/* TAB 1: COMPLETED TASKS TABLE */}
                        {activeTab === 'completed' && (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-left border-collapse">
                                    <thead>
                                        <tr className="bg-slate-50/50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                            <th className="py-4 px-6">Form Title</th>
                                            <th className="py-4 px-6">Completion Date</th>
                                            <th className="py-4 px-6">Status</th>
                                            <th className="py-4 px-6">Score / Result</th>
                                            <th className="py-4 px-6 text-right">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 text-sm">
                                        {completedHistory.map((item) => (
                                            <tr key={item.id} className="hover:bg-slate-50/60 transition-colors">
                                                <td className="py-4 px-6">
                                                    <div className="flex items-center gap-3">
                                                        <div className="p-2 bg-slate-100 rounded-lg text-slate-500">
                                                            <FileText size={18} />
                                                        </div>
                                                        <span className="font-semibold text-slate-800">
                                                            {item.title}
                                                        </span>
                                                    </div>
                                                </td>
                                                <td className="py-4 px-6 text-slate-500 font-medium">
                                                    {item.date}
                                                </td>
                                                <td className="py-4 px-6">
                                                    <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${
                                                        item.status === 'Submitted' || item.status === 'Reviewed'
                                                            ? 'bg-emerald-50 text-emerald-600'
                                                            : 'bg-amber-50 text-amber-600'
                                                    }`}>
                                                        {item.status}
                                                    </span>
                                                </td>
                                                <td className="py-4 px-6 font-bold text-slate-700">
                                                    {item.score}
                                                </td>
                                                <td className="py-4 px-6 text-right">
                                                    <button 
                                                        onClick={() => navigate(`/responses/${item.id}`)}
                                                        className="inline-flex items-center gap-1.5 text-xs font-bold text-[#6DBFB3] hover:underline"
                                                    >
                                                        <Eye size={14} />
                                                        <span>View Submission</span>
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}

                        {/* TAB 2: CREATED FORMS TABLE */}
                        {activeTab === 'created' && (
                            <div className="overflow-x-auto w-full">
                                <table className="w-full text-left border-collapse">
                                    <thead>
                                        <tr className="bg-slate-50/50 text-[11px] font-bold uppercase tracking-wider text-slate-400 border-b border-slate-100">
                                            <th className="py-4 px-6">Form Title</th>
                                            <th className="py-4 px-6">Status</th>
                                            <th className="py-4 px-6">Created Date</th>
                                            <th className="py-4 px-6">Responses</th>
                                            <th className="py-4 px-6 text-right">Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100 text-sm">
                                        {createdFormsHistory.map((form) => (
                                            <tr key={form.id} className="hover:bg-slate-50/60 transition-colors">
                                                <td className="py-4 px-6">
                                                    <div className="flex items-center gap-3">
                                                        <div className="p-2 bg-teal-50 rounded-lg text-[#6DBFB3]">
                                                            <FileText size={18} />
                                                        </div>
                                                        <div>
                                                            <h4 className="font-semibold text-slate-800">{form.title}</h4>
                                                            <p className="text-[11px] text-slate-400 font-medium">{form.category}</p>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td className="py-4 px-6">
                                                    <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold ${
                                                        form.status === 'Published'
                                                            ? 'bg-teal-50 text-[#6DBFB3]'
                                                            : 'bg-slate-100 text-slate-500'
                                                    }`}>
                                                        {form.status}
                                                    </span>
                                                </td>
                                                <td className="py-4 px-6 text-slate-500 font-medium">
                                                    {form.createdDate}
                                                </td>
                                                <td className="py-4 px-6 font-bold text-slate-700">
                                                    {form.responses}
                                                </td>
                                                <td className="py-4 px-6 text-right">
                                                    <div className="flex items-center justify-end gap-3">
                                                        <button 
                                                            onClick={() => navigate(`/form-builder/${form.id}`)}
                                                            className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg transition-colors"
                                                            title="Edit Form"
                                                        >
                                                            <Edit3 size={16} />
                                                        </button>
                                                        <button 
                                                            onClick={() => navigate(`/responses`)}
                                                            className="p-1.5 text-slate-400 hover:text-[#6DBFB3] rounded-lg transition-colors"
                                                            title="View Analytics"
                                                        >
                                                            <BarChart2 size={16} />
                                                        </button>
                                                    </div>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        )}

                    </div>

                </div>
            </div>
        </div>
    );
}