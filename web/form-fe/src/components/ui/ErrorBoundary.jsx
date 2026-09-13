import React from 'react';
import { AlertTriangle, RefreshCw, Home } from 'lucide-react';

export default class ErrorBoundary extends React.Component {
    constructor(props) {
        super(props);
        this.state = { hasError: false, error: null, errorInfo: null };
    }

    static getDerivedStateFromError(error) {
        return { hasError: true, error };
    }

    componentDidCatch(error, errorInfo) {
        this.setState({ errorInfo });
        console.error('[ErrorBoundary caught error]:', error, errorInfo);
    }

    handleReload = () => {
        window.location.reload();
    };

    handleReset = () => {
        this.setState({ hasError: false, error: null, errorInfo: null });
    };

    render() {
        if (this.state.hasError) {
            return (
                <div className="min-h-[400px] w-full p-6 flex flex-col items-center justify-center text-center bg-slate-50 dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800 shadow-sm my-6">
                    <div className="w-14 h-14 rounded-2xl bg-amber-100 dark:bg-amber-950/60 text-amber-600 dark:text-amber-400 flex items-center justify-center mb-4">
                        <AlertTriangle size={28} />
                    </div>
                    <h2 className="text-lg font-extrabold text-slate-900 dark:text-white mb-2">
                        Terjadi Kendala pada Tampilan
                    </h2>
                    <p className="text-xs text-slate-500 dark:text-slate-400 max-w-md mb-6 leading-relaxed">
                        {this.state.error?.message || 'Aplikasi mengalami kesalahan tak terduga saat memuat komponen ini.'}
                    </p>
                    <div className="flex items-center gap-3 flex-wrap justify-center">
                        <button
                            type="button"
                            onClick={this.handleReset}
                            className="px-4 py-2.5 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-2"
                        >
                            <RefreshCw size={14} /> Coba Lagi
                        </button>
                        <a
                            href="/dashboard"
                            className="px-4 py-2.5 bg-slate-200 dark:bg-slate-800 hover:bg-slate-300 text-slate-700 dark:text-slate-200 rounded-xl text-xs font-bold transition-all cursor-pointer flex items-center gap-2"
                        >
                            <Home size={14} /> Kembali ke Dashboard
                        </a>
                    </div>
                </div>
            );
        }

        return this.props.children;
    }
}
