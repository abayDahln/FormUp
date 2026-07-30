import {  
    FileText,  
    LayoutDashboard, 
    Folder, 
    MessageSquare, 
    LayoutTemplate, 
    LogOut,
} from 'lucide-react';
import { useNavigate, useLocation, Link } from 'react-router-dom';

export default function Sidebar() {
    const navigate = useNavigate();
    const location = useLocation(); // Hook untuk mendapatkan URL (path) saat ini

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        navigate('/login');
    };

    // Daftar menu disimpan dalam array agar lebih rapi
    const menuItems = [
        { path: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
        { path: '/my-forms', icon: Folder, label: 'My Forms' },
        { path: '/responses', icon: MessageSquare, label: 'Responses' },
        { path: '/templates', icon: LayoutTemplate, label: 'Templates' },
    ];

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
                    {menuItems.map((item) => {
                        const Icon = item.icon;
                        // Cek apakah URL saat ini cocok dengan path menu
                        const isActive = location.pathname.startsWith(item.path);

                        return (
                            <Link 
                                key={item.path}
                                to={item.path} 
                                className={`flex items-center gap-3 px-4 py-3 font-semibold rounded-xl transition-all ${
                                    isActive 
                                        ? 'bg-white/20 text-white' 
                                        : 'text-teal-50 hover:bg-white/10' 
                                }`}
                            >
                                <Icon size={18} />
                                <span>{item.label}</span>
                            </Link>
                        );
                    })}
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
    );
}