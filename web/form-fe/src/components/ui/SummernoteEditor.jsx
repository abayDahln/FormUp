import { useEffect, useRef, useState } from 'react';

export default function SummernoteEditor({ value, onChange, placeholder = '', className = '' }) {
    const textareaRef = useRef(null);
    const [scriptsLoaded, setScriptsLoaded] = useState(false);

    useEffect(() => {
        const getjQuery = () => window.jQuery || window.$;

        if (getjQuery() && getjQuery()?.fn?.summernote) {
            setScriptsLoaded(true);
            return;
        }

        const loadCSS = (url) => {
            if (document.querySelector(`link[href="${url}"]`)) return;
            const link = document.createElement('link');
            link.rel = 'stylesheet';
            link.href = url;
            document.head.appendChild(link);
        };

        const loadScript = (url) => {
            return new Promise((resolve, reject) => {
                if (document.querySelector(`script[src="${url}"]`)) {
                    resolve();
                    return;
                }
                const script = document.createElement('script');
                script.src = url;
                script.async = true;
                script.onload = resolve;
                script.onerror = reject;
                document.body.appendChild(script);
            });
        };

        loadCSS('https://cdn.jsdelivr.net/npm/summernote@0.9.0/dist/summernote-lite.min.css');
        loadScript('https://code.jquery.com/jquery-3.6.0.min.js')
            .then(() => loadScript('https://cdn.jsdelivr.net/npm/summernote@0.9.0/dist/summernote-lite.min.js'))
            .then(() => {
                if (window.jQuery && !window.$) window.$ = window.jQuery;
                setScriptsLoaded(true);
            })
            .catch(err => console.error('Failed to load Summernote dependencies:', err));
    }, []);

    useEffect(() => {
        if (!scriptsLoaded || !textareaRef.current) return;

        const $ = window.jQuery || window.$;
        if (typeof $ !== 'function' || !$.fn?.summernote) return;

        const $el = $(textareaRef.current);

        try {
            $el.summernote({
                placeholder: placeholder,
                tabsize: 2,
                height: 140,
                toolbar: [
                    ['style', ['style']],
                    ['font', ['bold', 'italic', 'underline', 'clear']],
                    ['color', ['color']],
                    ['para', ['ul', 'ol', 'paragraph']],
                    ['insert', ['link', 'picture', 'video']],
                    ['view', ['codeview', 'help']]
                ],
                callbacks: {
                    onChange: (contents) => {
                        if (onChange) onChange(contents);
                    }
                }
            });

            if (value && $el.summernote('code') !== value) {
                $el.summernote('code', value);
            }
        } catch (e) {
            console.error('Summernote init error:', e);
        }

        return () => {
            try {
                if ($el && $.fn?.summernote) {
                    $el.summernote('destroy');
                }
            } catch (e) {
                // Cleanup silent
            }
        };
    }, [scriptsLoaded]);

    // Sync value changes if value changes externally
    useEffect(() => {
        if (!scriptsLoaded || !textareaRef.current) return;
        const $ = window.jQuery || window.$;
        if (typeof $ !== 'function' || !$.fn?.summernote) return;

        const $el = $(textareaRef.current);
        try {
            const currentCode = $el.summernote('code');
            if (value !== undefined && currentCode !== value) {
                $el.summernote('code', value || '');
            }
        } catch (e) {
            // silent catch
        }
    }, [value, scriptsLoaded]);

    return (
        <div className={`summernote-editor-wrapper ${className}`}>
            <textarea ref={textareaRef} style={{ display: 'none' }} />
        </div>
    );
}
