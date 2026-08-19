import React from 'react';
import { AlertTriangle, HelpCircle, CheckCircle2 } from 'lucide-react';

const ConfirmModal = ({ 
  isOpen, 
  onClose, 
  onConfirm, 
  title, 
  message, 
  confirmText = 'Ya, Lanjutkan', 
  cancelText = 'Batal',
  variant = 'danger', 
  isLoading = false 
}) => {
  if (!isOpen) return null;

  const variantStyles = {
    danger: {
      bgIcon: 'bg-red-100 dark:bg-red-950/50 text-red-600 dark:text-red-400',
      btn: 'bg-red-600 hover:bg-red-700 text-white',
      icon: <AlertTriangle className="w-6 h-6" />
    },
    primary: {
      bgIcon: 'bg-teal-100 dark:bg-teal-950/50 text-teal-600 dark:text-teal-400',
      btn: 'bg-[#00897B] hover:bg-[#00796B] text-white',
      icon: <CheckCircle2 className="w-6 h-6" />
    },
    warning: {
      bgIcon: 'bg-amber-100 dark:bg-amber-950/50 text-amber-600 dark:text-amber-400',
      btn: 'bg-amber-600 hover:bg-amber-700 text-white',
      icon: <HelpCircle className="w-6 h-6" />
    }
  };

  const currentVariant = variantStyles[variant] || variantStyles.primary;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-xs animate-in fade-in duration-200">
      <div 
        className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-6 max-w-sm w-full shadow-2xl space-y-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-3">
          <div className={`p-2.5 rounded-full ${currentVariant.bgIcon}`}>
            {currentVariant.icon}
          </div>
          <div>
            <h3 className="text-base font-bold text-slate-900 dark:text-white">
              {title}
            </h3>
          </div>
        </div>

        <p className="text-sm text-slate-500 dark:text-slate-400 font-medium">
          {message}
        </p>

        <div className="flex items-center gap-2 pt-2">
          <button
            type="button"
            disabled={isLoading}
            onClick={onClose}
            className="flex-1 px-4 py-2 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-xs font-bold rounded-xl transition-colors cursor-pointer disabled:opacity-50"
          >
            {cancelText}
          </button>
          <button
            type="button"
            disabled={isLoading}
            onClick={onConfirm}
            className={`flex-1 px-4 py-2 text-xs font-bold rounded-xl transition-colors cursor-pointer disabled:opacity-50 ${currentVariant.btn}`}
          >
            {isLoading ? 'Memproses...' : confirmText}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmModal;