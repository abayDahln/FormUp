import { useState, useEffect } from 'react';
import { ZoomIn, ZoomOut, RotateCcw, X, Download } from 'lucide-react';

export default function ImageLightboxModal({ src, alt = 'Gambar Soal', isOpen, onClose }) {
    const [zoom, setZoom] = useState(1);
    const [position, setPosition] = useState({ x: 0, y: 0 });
    const [isDragging, setIsDragging] = useState(false);
    const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

    useEffect(() => {
        if (isOpen) {
            setZoom(1);
            setPosition({ x: 0, y: 0 });
            document.body.style.overflow = 'hidden';
        } else {
            document.body.style.overflow = 'unset';
        }
        return () => {
            document.body.style.overflow = 'unset';
        };
    }, [isOpen]);

    useEffect(() => {
        const handleKeyDown = (e) => {
            if (e.key === 'Escape' && isOpen) {
                onClose();
            }
        };
        window.addEventListener('keydown', handleKeyDown);
        return () => window.removeEventListener('keydown', handleKeyDown);
    }, [isOpen, onClose]);

    if (!isOpen || !src) return null;

    const handleZoomIn = () => setZoom(prev => Math.min(prev + 0.3, 3.5));
    const handleZoomOut = () => setZoom(prev => Math.max(prev - 0.3, 0.6));
    const handleReset = () => {
        setZoom(1);
        setPosition({ x: 0, y: 0 });
    };

    const handleMouseDown = (e) => {
        if (zoom > 1) {
            setIsDragging(true);
            setDragStart({ x: e.clientX - position.x, y: e.clientY - position.y });
        }
    };

    const handleMouseMove = (e) => {
        if (isDragging && zoom > 1) {
            setPosition({
                x: e.clientX - dragStart.x,
                y: e.clientY - dragStart.y
            });
        }
    };

    const handleMouseUp = () => setIsDragging(false);

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/85 backdrop-blur-md animate-in fade-in duration-200 select-none">
            {/* Top Toolbar */}
            <div className="absolute top-4 left-4 right-4 z-20 flex items-center justify-between pointer-events-none">
                <div className="px-4 py-2 bg-black/60 backdrop-blur-md border border-white/10 rounded-2xl text-white text-xs font-semibold pointer-events-auto">
                    {alt}
                </div>

                <div className="flex items-center gap-2 pointer-events-auto">
                    <div className="flex items-center bg-black/60 backdrop-blur-md border border-white/10 rounded-2xl p-1 text-white">
                        <button
                            type="button"
                            onClick={handleZoomOut}
                            disabled={zoom <= 0.6}
                            className="p-2 hover:bg-white/10 rounded-xl transition-colors disabled:opacity-40 cursor-pointer"
                            title="Perkecil"
                        >
                            <ZoomOut size={16} />
                        </button>
                        <span className="px-2 text-xs font-mono font-bold">
                            {Math.round(zoom * 100)}%
                        </span>
                        <button
                            type="button"
                            onClick={handleZoomIn}
                            disabled={zoom >= 3.5}
                            className="p-2 hover:bg-white/10 rounded-xl transition-colors disabled:opacity-40 cursor-pointer"
                            title="Perbesar"
                        >
                            <ZoomIn size={16} />
                        </button>
                        <button
                            type="button"
                            onClick={handleReset}
                            className="p-2 hover:bg-white/10 rounded-xl transition-colors cursor-pointer"
                            title="Reset Ukuran"
                        >
                            <RotateCcw size={15} />
                        </button>
                        <a
                            href={src}
                            target="_blank"
                            rel="noreferrer"
                            download
                            className="p-2 hover:bg-white/10 rounded-xl transition-colors cursor-pointer text-teal-400"
                            title="Buka / Unduh Resolusi Penuh"
                        >
                            <Download size={15} />
                        </a>
                    </div>

                    <button
                        type="button"
                        onClick={onClose}
                        className="p-2.5 bg-black/60 hover:bg-red-500/80 backdrop-blur-md border border-white/10 rounded-2xl text-white transition-colors cursor-pointer"
                        title="Tutup (Esc)"
                    >
                        <X size={18} />
                    </button>
                </div>
            </div>

            {/* Image Canvas Container */}
            <div
                className={`relative max-w-full max-h-full flex items-center justify-center overflow-hidden ${zoom > 1 ? (isDragging ? 'cursor-grabbing' : 'cursor-grab') : 'cursor-default'}`}
                onMouseDown={handleMouseDown}
                onMouseMove={handleMouseMove}
                onMouseUp={handleMouseUp}
                onMouseLeave={handleMouseUp}
            >
                <img
                    src={src}
                    alt={alt}
                    draggable={false}
                    className="max-h-[85vh] max-w-[90vw] object-contain rounded-2xl shadow-2xl transition-transform duration-100 ease-out"
                    style={{
                        transform: `scale(${zoom}) translate(${position.x / zoom}px, ${position.y / zoom}px)`,
                    }}
                />
            </div>
        </div>
    );
}
