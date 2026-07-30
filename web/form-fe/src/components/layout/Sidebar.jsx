import {  
    FileText,  
    LayoutDashboard, 
    Folder, 
    MessageSquare, 
    LayoutTemplate, 
    LogOut,
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';


export default function Sidebar() {
    const navigate = useNavigate();

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        navigate('/login');
    };

    return (
        <aside className="w-64 bg-[#6DBFB3] text-white flex-col justify-between p-6 shadow-lg hidden md:flex shrink-0">
            <div className="space-y-8">
                <div className="flex items-center gap-3">
                    <div className="p-2 bg-white/20 rounded-xl">
                        <FileText size={24} className="text-white" />
                    </div>
                    <div>
                        <h1 className="text-xl font-bold tracking-tight leading-none">FormUp</h1>
                        <span className="text-[10px] text-teal-100 font-medium">Pro Workspace</span>
                    </div>
                </div>

                <nav className="space-y-1">
                    <a href="#dashboard" className="flex items-center gap-3 px-4 py-3 bg-white/20 font-semibold rounded-xl text-white transition-all">
                        <LayoutDashboard size={18} />
                        <span>Dashboard</span>
                    </a>
                    <a href="#my-forms" className="flex items-center gap-3 px-4 py-3 font-semibold rounded-xl text-teal-50 hover:bg-white/10 transition-all">
                        <Folder size={18} />
                        <span>My Forms</span>
                    </a>
                    <a href="#responses" className="flex items-center gap-3 px-4 py-3 font-semibold rounded-xl text-teal-50 hover:bg-white/10 transition-all">
                        <MessageSquare size={18} />
                        <span>Responses</span>
                    </a>
                    <a href="#templates" className="flex items-center gap-3 px-4 py-3 font-semibold rounded-xl text-teal-50 hover:bg-white/10 transition-all">
                        <LayoutTemplate size={18} />
                        <span>Templates</span>
                    </a>
                </nav>
            </div>

            <button
                onClick={handleLogout}
                className="flex items-center gap-3 px-4 py-3 font-semibold text-teal-100 hover:text-white hover:bg-white/10 rounded-xl transition-all"
            >
                <LogOut size={18} />
                <span>Logout</span>
            </button>
        </aside>
    )
}