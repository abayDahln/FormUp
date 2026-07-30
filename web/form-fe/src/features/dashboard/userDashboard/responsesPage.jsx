import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Plus,
    FileText,
    MoreVertical,
    Download,
    Filter,
    Clock,
    Calendar,
    Share2,
    Trash2,
    BarChart3,
    CheckCircle2
} from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';

const ResponsesPage = () => {
    const navigate = useNavigate();
    const [user, setUser] = useState({});

    // Data Dummy 
    const responseSummaries = [
        {
            id: 1,
            title: 'Customer Feedback Q3',
            description: 'Final quarterly survey for retail branches.',
            status: 'Published',
            totalResponses: '1,284',
            completionRate: '94%',
            lastResponse: '5 mins ago',
            createdAt: 'Jul 12',
            iconColor: 'bg-teal-50 text-teal-600'
        },
        {
            id: 2,
            title: 'Employee Onboarding',
            description: 'Standard intake for new HR hires.',
            status: 'Closed',
            totalResponses: '42',
            completionRate: '100%',
            lastResponse: '2 days ago',
            createdAt: 'Jun 05',
            iconColor: 'bg-indigo-50 text-indigo-600'
        }
    ];

    useEffect(() => {
        const savedUser = JSON.parse(localStorage.getItem('user') || '{}');
        setUser(savedUser);
    }, []);

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            {/* SIDEBAR */}
            <Sidebar />

            {/* MAIN CONTENT */}
            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">
                    
                    {/* TOPBAR */}
                    <Topbar user={user} />

                    {/* HEADER & TOP ACTIONS (Sesuai Figma) */}
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div>
                            <h2 className="text-2xl font-bold text-slate-900 tracking-tight">Form Responses Summary</h2>
                            <p className="text-sm text-slate-500 font-medium mt-1">
                                Performance overview for all your active surveys.
                            </p>
                        </div>

                        <div className="flex items-center gap-3">
                            <button className="flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-50 transition-all shadow-sm">
                                <Filter size={16} /> Filters
                            </button>
                            <button className="flex items-center gap-2 px-4 py-2 bg-[#005B52] rounded-xl text-xs font-bold text-white hover:bg-[#00463F] transition-all shadow-md">
                                <Download size={16} /> Bulk Export
                            </button>
                        </div>
                    </div>

                    {/* RESPONSES GRID */}
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 pt-2">
                        
                        {responseSummaries.map((form) => (
                            <div key={form.id} className="bg-white rounded-[24px] border border-slate-100 shadow-sm p-6 flex flex-col space-y-6">
                                
                                {/* TOP AREA: ICON & STATUS */}
                                <div className="flex items-center justify-between">
                                    <div className={`p-2.5 rounded-xl ${form.iconColor}`}>
                                        <BarChart3 size={20} />
                                    </div>
                                    <span className={`text-[10px] font-extrabold px-3 py-1 rounded-full uppercase tracking-widest ${
                                        form.status === 'Published' 
                                            ? 'bg-teal-50 text-teal-600' 
                                            : 'bg-slate-100 text-slate-500'
                                    }`}>
                                        ● {form.status}
                                    </span>
                                </div>

                                {/* TITLE & DESC */}
                                <div>
                                    <h3 className="text-xl font-bold text-slate-900">{form.title}</h3>
                                    <p className="text-sm text-slate-400 font-medium mt-1">{form.description}</p>
                                </div>

                                {/* STATS BENTO (Sesuai Figma) */}
                                <div className="grid grid-cols-2 gap-4">
                                    <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100/50">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Total Responses</p>
                                        <h4 className="text-2xl font-extrabold text-teal-600">{form.totalResponses}</h4>
                                    </div>
                                    <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100/50">
                                        <p className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-2">Completion Rate</p>
                                        <h4 className="text-2xl font-extrabold text-slate-800">{form.completionRate}</h4>
                                    </div>
                                </div>

                                {/* FOOTER INFO */}
                                <div className="flex items-center gap-6 text-[11px] font-bold text-slate-400">
                                    <span className="flex items-center gap-1.5">
                                        <Clock size={14} /> {form.lastResponse}
                                    </span>
                                    <span className="flex items-center gap-1.5">
                                        <Calendar size={14} /> Created {form.createdAt}
                                    </span>
                                </div>

                                {/* ACTIONS ROW */}
                                <div className="flex items-center gap-2 pt-2">
                                    <button 
                                        onClick={() => navigate(`/responses/${form.id}`)}
                                        className="flex-1 py-3 px-4 bg-[#005B52] hover:bg-[#00463F] text-white font-bold text-xs rounded-xl transition-all shadow-sm"
                                    >
                                        View Summary
                                    </button>
                                    <button className="p-3 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-50 transition-all">
                                        <Share2 size={16} />
                                    </button>
                                    <button className="p-3 bg-white border border-slate-200 rounded-xl text-slate-400 hover:text-red-500 hover:bg-red-50 transition-all">
                                        <Trash2 size={16} />
                                    </button>
                                </div>
                            </div>
                        ))}

                        {/* EMPTY STATE / CREATE NEW PLACEHOLDER (Sesuai Figma) */}
                        <div className="bg-teal-50/30 rounded-[24px] border-2 border-dashed border-teal-100 p-8 flex flex-col items-center justify-center text-center space-y-4">
                            <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center shadow-sm text-teal-600">
                                <Plus size={24} />
                            </div>
                            <div className="space-y-1">
                                <h4 className="text-sm font-bold text-slate-800">Ready to start collecting?</h4>
                                <p className="text-xs text-slate-500 font-medium">Launch a new form to start seeing analytics here.</p>
                            </div>
                            <button 
                                onClick={() => navigate('/create-form')}
                                className="text-xs font-bold text-teal-600 hover:underline flex items-center gap-1"
                            >
                                Create New Form →
                            </button>
                        </div>

                    </div>
                </main>
            </div>
        </div>
    );
};

export default ResponsesPage;