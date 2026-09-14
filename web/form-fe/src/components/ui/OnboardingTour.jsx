import { useState, useEffect, useRef, useCallback } from 'react';
import { X, ChevronRight, ChevronLeft, Check, Sparkles } from 'lucide-react';

/**
 * OnboardingTour - Komponen Guided Onboarding Tour dengan Spotlight Pattern
 * Pola Duolingo & Anthropic yang disempurnakan:
 * - Overlay gelap fokus (rgba(0, 0, 0, 0.72))
 * - Cutout spotlight target yang presisi dengan dynamic bounding rect
 * - Border glowing elegan: teal-400 dengan glow halus
 * - Card penjelasan menempel di dekat target dengan pointer penunjuk
 * - Safe clamping agar card tidak pernah terpotong di atas viewport (search bar / browser bar)
 * - Navigasi Kembali & Lanjut/Selesai, keyboard shortcuts, dan auto-scroll
 */
export default function OnboardingTour({
    steps = [],
    isOpen = false,
    onClose = () => {},
    onComplete = () => {},
}) {
    const [currentStep, setCurrentStep] = useState(0);
    const [targetRect, setTargetRect] = useState(null);
    const [cardPlacement, setCardPlacement] = useState('bottom');
    const [showWelcome, setShowWelcome] = useState(true);

    const step = steps[currentStep] || null;

    // Hitung posisi elemen target
    const updateTargetPosition = useCallback(() => {
        if (!isOpen || showWelcome || !step) {
            setTargetRect(null);
            return;
        }

        const selector = step.selector;
        const targetElement = typeof selector === 'string' 
            ? document.querySelector(selector) 
            : selector?.current;

        if (!targetElement) {
            // Jangan tampilkan card di area kosong. Lewati langkah yang targetnya
            // sudah tidak ada (misalnya tombol yang berubah karena state UI).
            setTargetRect(null);
            const nextAvailable = steps.findIndex((candidate, index) => index > currentStep && document.querySelector(candidate.selector));
            if (nextAvailable >= 0) setCurrentStep(nextAvailable);
            else if (currentStep < steps.length - 1) setCurrentStep(currentStep + 1);
            else { onComplete(); onClose(); }
            return;
        }

        // Auto-scroll ke target jika di luar viewport atau terlalu mepet ke atas
        const rect = targetElement.getBoundingClientRect();
        const minTopMargin = 80;
        const isInViewport = (
            rect.top >= minTopMargin &&
            rect.left >= 0 &&
            rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) - 40 &&
            rect.right <= (window.innerWidth || document.documentElement.clientWidth)
        );

        if (!isInViewport) {
            targetElement.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' });
        }

        // Ambil koordinat terbaru setelah scroll/posisi
        const updatedRect = targetElement.getBoundingClientRect();
        setTargetRect({
            top: updatedRect.top,
            left: updatedRect.left,
            width: updatedRect.width,
            height: updatedRect.height,
            bottom: updatedRect.bottom,
            right: updatedRect.right,
        });

        // BUG FIX: Tentukan penempatan card penjelasan
        // Jika target berada di bagian atas layar (seperti sidebar menu atau topbar), pastikan card tidak pernah terpotong di atas viewport
        const spaceBelow = window.innerHeight - updatedRect.bottom;
        const spaceAbove = updatedRect.top;
        const neededCardHeight = 260;

        if (step.placement) {
            setCardPlacement(step.placement);
        } else if (window.innerWidth >= 1024 && updatedRect.left < 320 && updatedRect.right <= 360) {
            // Jika elemen berada di sidebar kiri (desktop), posisikan card di sebelah kanan elemen
            setCardPlacement('right');
        } else if (spaceAbove > neededCardHeight + 100 && spaceBelow < 220) {
            // Hanya gunakan 'top' jika space di atas benar-benar lega dan tidak mepet browser bar
            setCardPlacement('top');
        } else {
            setCardPlacement('bottom');
        }
    }, [isOpen, showWelcome, step, steps, currentStep]);

    useEffect(() => {
        if (!isOpen) {
            setCurrentStep(0);
            setShowWelcome(true);
            return;
        }

        // Beri sedikit jeda agar DOM render sempurna
        const timer = setTimeout(() => {
            updateTargetPosition();
        }, 100);

        const handleResizeOrScroll = () => {
            updateTargetPosition();
        };

        window.addEventListener('resize', handleResizeOrScroll);
        window.addEventListener('scroll', handleResizeOrScroll, true);

        return () => {
            clearTimeout(timer);
            window.removeEventListener('resize', handleResizeOrScroll);
            window.removeEventListener('scroll', handleResizeOrScroll, true);
        };
    }, [isOpen, currentStep, updateTargetPosition]);

    // Keyboard navigation (ArrowRight/Enter untuk lanjut, Escape untuk lewati)
    useEffect(() => {
        if (!isOpen) return;

        const handleKeyDown = (e) => {
            if (e.key === 'Escape') {
                e.preventDefault();
                handleSkip();
            } else if (e.key === 'ArrowRight' || e.key === 'Enter') {
                e.preventDefault();
                handleNext();
            }
        };

        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [isOpen, currentStep, steps.length]);

    if (!isOpen) return null;

    if (showWelcome) {
        return (
            <div className="fixed inset-0 z-[99990] flex items-center justify-center bg-slate-950/45 p-4">
                <div className="w-full max-w-sm rounded-2xl border border-slate-200 bg-white p-5 text-slate-800 shadow-xl dark:border-slate-700 dark:bg-slate-900 dark:text-white">
                    <div className="space-y-2">
                        <p className="text-[10px] font-bold uppercase tracking-wider text-teal-600 dark:text-teal-400">Halo, selamat datang!</p>
                        <h3 className="text-lg font-extrabold">Siap membuat formulir pertamamu?</h3>
                        <p className="text-xs leading-relaxed text-slate-500 dark:text-slate-400">Kami akan menemani kamu mengenal fitur-fitur penting FormUp, dari membuat soal sampai membagikan formulir. Cuma sebentar kok.</p>
                    </div>
                    <div className="mt-5 flex justify-end gap-2">
                        <button type="button" onClick={() => { onComplete(); onClose(); }} className="rounded-xl px-3 py-2 text-xs font-bold text-slate-500 hover:bg-slate-100 dark:text-slate-400 dark:hover:bg-slate-800">Nanti dulu</button>
                        <button type="button" onClick={() => setShowWelcome(false)} className="rounded-xl bg-teal-600 px-4 py-2 text-xs font-bold text-white hover:bg-teal-700">Yuk, mulai</button>
                    </div>
                </div>
            </div>
        );
    }

    if (!step) return null;

    const isLastStep = currentStep === steps.length - 1;
    const isFirstStep = currentStep === 0;

    const handleNext = () => {
        if (isLastStep) {
            onComplete();
            onClose();
        } else {
            const nextIdx = currentStep + 1;
            const nextStep = steps[nextIdx];
            if (step?.onLeaveStep) {
                step.onLeaveStep();
            }
            if (nextStep?.action) {
                nextStep.action();
            }
            setCurrentStep(nextIdx);
        }
    };

    const handlePrev = () => {
        if (currentStep > 0) {
            setCurrentStep(prev => prev - 1);
        }
    };

    const handleSkip = () => {
        onComplete(); // Tetap tandai selesai agar tidak mengganggu lagi
        onClose();
    };

    // Hitung posisi card tooltip secara responsif
    const getCardStyle = () => {
        if (!targetRect) {
            // Jika target tidak ditemukan, tempatkan card di tengah layar
            return {
                position: 'fixed',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                maxWidth: '92vw',
                width: '440px',
                zIndex: 99999,
            };
        }

        const padding = 16;
        const cardWidth = Math.min(440, window.innerWidth - 32);

        // Horizontal alignment: tengahkan card terhadap target namun tetap di dalam viewport
        let cardLeft = targetRect.left + (targetRect.width / 2) - (cardWidth / 2);
        if (cardLeft < 16) cardLeft = 16;
        if (cardLeft + cardWidth > window.innerWidth - 16) {
            cardLeft = window.innerWidth - cardWidth - 16;
        }

        if (cardPlacement === 'right') {
            const rightPos = Math.min(window.innerWidth - cardWidth - 16, targetRect.right + padding);
            let topPos = Math.max(80, targetRect.top);
            if (topPos + 300 > window.innerHeight) {
                topPos = Math.max(80, window.innerHeight - 320);
            }
            return {
                position: 'fixed',
                top: `${topPos}px`,
                left: `${rightPos}px`,
                width: `${cardWidth}px`,
                zIndex: 99999,
            };
        }

        if (cardPlacement === 'top') {
            const bottomPos = Math.max(16, window.innerHeight - targetRect.top + padding);
            return {
                position: 'fixed',
                bottom: `${bottomPos}px`,
                left: `${cardLeft}px`,
                width: `${cardWidth}px`,
                zIndex: 99999,
            };
        }

        const topPos = Math.max(80, targetRect.bottom + padding);
        return {
            position: 'fixed',
            top: `${topPos}px`,
            left: `${cardLeft}px`,
            width: `${cardWidth}px`,
            zIndex: 99999,
        };
    };

    // Posisi ekor pointer segitiga
    const getPointerLeft = () => {
        if (!targetRect || cardPlacement === 'right') return '50%';
        const cardWidth = Math.min(440, window.innerWidth - 32);
        let cardLeft = targetRect.left + (targetRect.width / 2) - (cardWidth / 2);
        if (cardLeft < 16) cardLeft = 16;
        if (cardLeft + cardWidth > window.innerWidth - 16) {
            cardLeft = window.innerWidth - cardWidth - 16;
        }
        const targetCenter = targetRect.left + (targetRect.width / 2);
        const relativePointer = targetCenter - cardLeft;
        // Clamp agar tidak keluar dari sudut rounded card
        return `${Math.max(24, Math.min(cardWidth - 24, relativePointer))}px`;
    };

    return (
        <div className="fixed inset-0 z-[99990] select-none">
            {/* Latar Belakang & Spotlight Cutout */}
            {targetRect ? (
                <>
                    {/* Elemen spotlight cutout dengan box-shadow raksasa dan border teal glow */}
                    <div
                        className="fixed transition-all duration-300 ease-out pointer-events-none rounded-2xl ring-4 ring-teal-400/90 shadow-[0_0_35px_rgba(20,184,166,0.65)]"
                        style={{
                            top: `${Math.max(8, targetRect.top - 6)}px`,
                            left: `${Math.max(8, targetRect.left - 6)}px`,
                            width: `${targetRect.width + 12}px`,
                            height: `${targetRect.height + 12}px`,
                            boxShadow: '0 0 0 9999px rgba(3, 7, 18, 0.72)',
                            zIndex: 99991,
                        }}
                    />
                    {/* Layer transparan di atas target untuk mencegah klik sembarangan selama tour */}
                    <div 
                        className="fixed inset-0 z-[99992] cursor-default"
                        onClick={(e) => e.stopPropagation()}
                    />
                </>
            ) : (
                <div className="fixed inset-0 bg-slate-950/75 backdrop-blur-xs z-[99991]" />
            )}

            {/* Card Penjelasan Spotlight */}
            <div 
                style={getCardStyle()} 
                className="animate-in fade-in zoom-in-95 duration-200"
            >
                {/* Ekor pointer (Arrow) */}
                {targetRect && cardPlacement !== 'right' && (
                    <div
                        className="absolute w-4 h-4 bg-slate-900 border-teal-500/60 transform rotate-45"
                        style={{
                            left: getPointerLeft(),
                            marginLeft: '-8px',
                            ...(cardPlacement === 'top'
                                ? { bottom: '-8px', borderRightWidth: '1px', borderBottomWidth: '1px' }
                                : { top: '-8px', borderLeftWidth: '1px', borderTopWidth: '1px' }),
                            zIndex: 100000,
                        }}
                    />
                )}

                {/* Ekor pointer di samping jika cardPlacement right */}
                {targetRect && cardPlacement === 'right' && (
                    <div
                        className="absolute w-4 h-4 bg-slate-900 border-teal-500/60 transform rotate-45"
                        style={{
                            left: '-8px',
                            top: '28px',
                            borderLeftWidth: '1px',
                            borderBottomWidth: '1px',
                            zIndex: 100000,
                        }}
                    />
                )}

                {/* Body Card */}
                <div className="relative bg-white dark:bg-slate-900 text-slate-800 dark:text-white p-4 sm:p-5 rounded-2xl shadow-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
                    {/* Header Card: Progress & Tombol Lewati */}
                    <div className="flex items-center justify-between gap-2 mb-2.5">
                        <div className="flex items-center gap-2">
                            <span className="px-2.5 py-1 rounded-lg bg-teal-50 dark:bg-teal-950/50 text-black dark:text-white font-extrabold text-[11px] border border-teal-200 dark:border-teal-800 flex items-center gap-1.5">
                                <Sparkles size={12} className="text-teal-600 dark:text-teal-400" />
                                {currentStep + 1}/{steps.length}
                            </span>
                            {step.badge && (
                                <span className="px-2 py-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-300 font-bold text-[10px] border border-slate-200 dark:border-slate-700">
                                    {step.badge}
                                </span>
                            )}
                        </div>
                        <button
                            type="button"
                            onClick={handleSkip}
                            className="text-xs font-bold text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-white px-2.5 py-1 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer flex items-center gap-1"
                        >
                            <span>Lewati</span>
                            <X size={14} />
                        </button>
                    </div>

                    {/* Konten Utama */}
                    <div className="space-y-1.5 mb-3">
                        <h4 className="text-sm font-extrabold text-slate-900 dark:text-white flex items-center gap-2 tracking-tight">
                            {step.icon && (
                                <div className="w-7 h-7 rounded-lg bg-teal-50 dark:bg-teal-950/50 border border-teal-200 dark:border-teal-800 flex items-center justify-center text-teal-600 dark:text-teal-300 shrink-0">
                                    {step.icon}
                                </div>
                            )}
                            <span>{step.title}</span>
                        </h4>
                        <p className="text-[11px] sm:text-xs text-slate-600 dark:text-slate-300 leading-relaxed font-normal">
                            {step.description}
                        </p>
                    </div>

                    {/* Optional Highlight Action Button inside card */}
                    {step.actionButton && (
                        <div className="mb-4 pt-1">
                            <button
                                type="button"
                                onClick={() => {
                                    if (step.actionButton.onClick) {
                                        step.actionButton.onClick();
                                    }
                                }}
                                className="w-full py-2.5 px-4 rounded-xl bg-teal-500 hover:bg-teal-400 text-slate-950 font-extrabold text-xs flex items-center justify-center gap-2 shadow-sm transition-colors cursor-pointer"
                            >
                                {step.actionButton.icon}
                                <span>{step.actionButton.text}</span>
                                <ChevronRight size={14} />
                            </button>
                        </div>
                    )}

                    {/* Footer Navigasi: Step dots, Tombol Kembali & Lanjut */}
                    <div className="flex items-center justify-between pt-2.5 border-t border-slate-200 dark:border-slate-800 gap-2">
                        {/* Step Dots Indicator */}
                        <div className="flex items-center gap-1.5">
                            {steps.map((_, idx) => (
                                <button
                                    key={idx}
                                    type="button"
                                    onClick={() => setCurrentStep(idx)}
                                    className={`h-1.5 rounded-full transition-all cursor-pointer ${
                                        idx === currentStep
                                            ? 'w-6 bg-teal-500'
                                            : idx < currentStep
                                            ? 'w-2 bg-teal-600'
                                            : 'w-2 bg-slate-300 dark:bg-slate-700'
                                    }`}
                                    title={`Ke langkah ${idx + 1}`}
                                />
                            ))}
                        </div>

                        {/* Navigation Buttons: Kembali & Lanjut */}
                        <div className="flex items-center gap-2">
                            {!isFirstStep && (
                                <button
                                    type="button"
                                    onClick={handlePrev}
                                    className="inline-flex items-center gap-1 px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white font-bold text-xs rounded-xl transition-all cursor-pointer"
                                >
                                    <ChevronLeft size={14} />
                                    <span>Kembali</span>
                                </button>
                            )}

                            <button
                                type="button"
                                onClick={handleNext}
                                className="inline-flex items-center gap-1.5 px-4 py-2 bg-teal-500 hover:bg-teal-400 text-slate-950 font-extrabold text-xs rounded-xl shadow-sm transition-colors cursor-pointer"
                            >
                                    <span>{isLastStep ? 'Selesai' : (step.nextBtnText || 'Lanjut')}</span>
                                {isLastStep ? <Check size={15} /> : <ChevronRight size={15} />}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
