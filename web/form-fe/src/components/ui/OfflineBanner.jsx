import { useState, useEffect } from 'react';
import { WifiOff, RefreshCw } from 'lucide-react';

export default function OfflineBanner() {
    const [isOnline, setIsOnline] = useState(() =>
        typeof navigator !== 'undefined' ? navigator.onLine : true
    );

    useEffect(() => {
        const handleOnline = () => setIsOnline(true);
        const handleOffline = () => setIsOnline(false);

        window.addEventListener('online', handleOnline);
        window.addEventListener('offline', handleOffline);

        return () => {
            window.removeEventListener('online', handleOnline);
            window.removeEventListener('offline', handleOffline);
        };
    }, []);

    if (isOnline) return null;

    return (
        <div className="fixed top-0 left-0 right-0 z-50 bg-amber-600 text-white text-xs font-bold px-4 py-2 flex items-center justify-between shadow-md transition-all animate-fadeIn">
            <div className="flex items-center gap-2">
                <WifiOff size={15} />
                <span>Koneksi terputus. Beberapa fitur memerlukan jaringan internet untuk bekerja.</span>
            </div>
            <button
                type="button"
                onClick={() => window.location.reload()}
                className="px-2.5 py-1 bg-amber-700 hover:bg-amber-800 rounded-lg text-[11px] font-extrabold flex items-center gap-1 cursor-pointer"
            >
                <RefreshCw size={12} /> Coba Hubungkan
            </button>
        </div>
    );
}
