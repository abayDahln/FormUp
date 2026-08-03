import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, HelpCircle } from 'lucide-react';
import Sidebar from '../../../components/layout/Sidebar';
import Topbar from '../../../components/layout/Topbar';

const TEMPLATES = [
    {
        id: 'tpl-1',
        title: 'Customer Satisfaction Survey',
        category: 'Marketing',
        categoryColor: 'text-teal-600 bg-teal-50',
        questionCount: 12,
        description: 'Measure customer happiness and gather actionable insights for product improvement.',
        bannerImage: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-2',
        title: 'Event Registration',
        category: 'Business',
        categoryColor: 'text-orange-600 bg-orange-50',
        questionCount: 8,
        description: 'Collect attendee information, dietary preferences, and session choices easily.',
        bannerImage: 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-3',
        title: 'Job Application Form',
        category: 'HR',
        categoryColor: 'text-indigo-600 bg-indigo-50',
        questionCount: 15,
        description: 'Streamline your hiring process with a structured candidate application form.',
        bannerImage: 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-4',
        title: 'Course Feedback',
        category: 'Education',
        categoryColor: 'text-blue-600 bg-blue-50',
        questionCount: 10,
        description: 'Help educators improve curriculum and teaching styles through student feedback.',
        bannerImage: 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-5',
        title: 'Order Request Form',
        category: 'Sales',
        categoryColor: 'text-emerald-600 bg-emerald-50',
        questionCount: 10,
        description: 'A streamlined way for clients to request product orders and quotes.',
        bannerImage: 'https://images.unsplash.com/photo-1556742049-0a670f4a4591?w=600&auto=format&fit=crop&q=80'
    },
    {
        id: 'tpl-6',
        title: 'Bug Report Form',
        category: 'Product',
        categoryColor: 'text-purple-600 bg-purple-50',
        questionCount: 6,
        description: 'Collect detailed bug reports from users including environment & steps.',
        bannerImage: 'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=600&auto=format&fit=crop&q=80'
    }
];

const TemplatesPage = () => {
    const navigate = useNavigate();
    const [cloningId, setCloningId] = useState(null);

    const handleUseTemplate = (template) => {
        setCloningId(template.id);
        navigate('/create-form', { state: { templateData: template } });
        setCloningId(null);
    };

    return (
        <div className="flex min-h-screen w-full bg-[#F4F8F7] font-sans antialiased text-slate-800">
            <Sidebar />

            <div className="flex-1 flex flex-col min-w-0 overflow-y-auto">
                <main className="flex-1 w-full p-4 sm:p-6 lg:p-8 space-y-6">

                    <Topbar />

                    <div>
                        <h2 className="text-2xl font-bold text-slate-900">Template Gallery</h2>
                        <p className="text-xs text-slate-500 font-medium mt-1 max-w-xl">
                            Jumpstart your workflow with our professionally crafted templates, optimized for conversion and clarity.
                        </p>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">

                        <div
                            onClick={() => navigate('/create-form')}
                            className="bg-white/70 rounded-2xl border-2 border-dashed border-slate-300 shadow-sm hover:border-[#6DBFB3] hover:bg-white transition-all flex flex-col items-center justify-center text-center cursor-pointer min-h-[340px] p-6 group"
                        >
                            <div className="w-12 h-12 rounded-full bg-teal-50 text-[#00897B] flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                                <Plus size={24} />
                            </div>
                            <h4 className="text-sm font-bold text-slate-800">Blank Form</h4>
                            <p className="text-xs text-slate-400 font-medium mt-1 max-w-[180px]">
                                Start from scratch and build your own unique experience.
                            </p>
                        </div>

                        {TEMPLATES.map((tpl) => (
                            <div key={tpl.id} className="bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-md transition-all flex flex-col overflow-hidden">
                                <div className="h-40 w-full relative bg-slate-100 overflow-hidden">
                                    <img
                                        src={tpl.bannerImage}
                                        alt={tpl.title}
                                        className="w-full h-full object-cover hover:scale-105 transition-transform duration-300"
                                    />
                                </div>

                                <div className="p-4 flex-1 flex flex-col justify-between space-y-3">
                                    <div>
                                        <div className="flex items-center justify-between text-[11px] font-bold mb-2">
                                            <span className={`px-2 py-0.5 rounded-md ${tpl.categoryColor}`}>
                                                {tpl.category}
                                            </span>
                                            <span className="text-slate-400 font-medium flex items-center gap-1">
                                                <HelpCircle size={12} /> {tpl.questionCount} Questions
                                            </span>
                                        </div>

                                        <h4 className="text-sm font-bold text-slate-900 line-clamp-1">{tpl.title}</h4>
                                        <p className="text-xs text-slate-400 font-medium mt-1 line-clamp-2 leading-relaxed">
                                            {tpl.description}
                                        </p>
                                    </div>

                                    <button
                                        onClick={() => handleUseTemplate(tpl)}
                                        disabled={cloningId === tpl.id}
                                        className="w-full py-2.5 px-4 bg-[#005B52] hover:bg-[#00463F] text-white font-bold text-xs rounded-xl transition-all flex items-center justify-center gap-2 disabled:opacity-50"
                                    >
                                        {cloningId === tpl.id ? 'Loading...' : 'Use Template'}
                                    </button>
                                </div>
                            </div>
                        ))}

                    </div>

                </main>
            </div>
        </div>
    );
};

export default TemplatesPage;