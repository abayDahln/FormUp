import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from '@studio-freight/lenis';
import { 
  ArrowRight, Smartphone, Check, ChevronDown,
  Layers, BarChart2, QrCode, Globe, Zap, Sparkles, Send,
  FileText, CheckCircle2
} from 'lucide-react';
import { isAuthenticated } from '../../services/apiService';

gsap.registerPlugin(ScrollTrigger);

export default function LandingPage() {
  const navigate = useNavigate();
  const [scrolled, setScrolled] = useState(false);
  const [activeFaq, setActiveFaq] = useState(null);
  const [activePreset, setActivePreset] = useState('quiz');

  // 3D Phone Tilt State
  const [tilt, setTilt] = useState({ x: 0, y: 0 });
  const [glarePos, setGlarePos] = useState({ x: 50, y: 50 });

  const containerRef = useRef(null);
  const heroPhoneRef = useRef(null);
  const storyRef = useRef(null);

  // Redirect if already logged in
  useEffect(() => {
    if (isAuthenticated()) {
      navigate('/dashboard', { replace: true });
    }
  }, [navigate]);

  // Lenis & GSAP Setup
  useEffect(() => {
    // 1. Lenis Smooth Scroll
    const lenis = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      smooth: true,
      smoothTouch: false,
    });

    lenis.on('scroll', ScrollTrigger.update);

    const updateLenis = (time) => {
      lenis.raf(time * 1000);
    };

    gsap.ticker.add(updateLenis);
    gsap.ticker.lagSmoothing(0);

    // 2. Navbar Scroll Listener
    const handleScroll = () => {
      setScrolled(window.scrollY > 50);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });

    // 3. GSAP Animations Context
    const ctx = gsap.context(() => {
      // Hero 3D phone floating levitation
      gsap.to(heroPhoneRef.current, {
        y: -18,
        duration: 3,
        repeat: -1,
        yoyo: true,
        ease: 'sine.inOut'
      });

      // Hero Parallax on Scroll
      gsap.to(heroPhoneRef.current, {
        rotateX: 18,
        rotateY: -10,
        z: -60,
        scale: 0.94,
        ease: 'none',
        scrollTrigger: {
          trigger: '#hero-section',
          start: 'top top',
          end: 'bottom top',
          scrub: 1.2
        }
      });

      // Story Section Typography Reveal
      gsap.fromTo('.story-reveal', 
        { opacity: 0.2, y: 30 },
        {
          opacity: 1,
          y: 0,
          stagger: 0.2,
          duration: 1,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: storyRef.current,
            start: 'top 75%',
            end: 'bottom 70%',
            scrub: 1
          }
        }
      );

      // Workflow Cards Stagger Animation
      gsap.fromTo('.workflow-card',
        { opacity: 0, y: 50, scale: 0.95 },
        {
          opacity: 1,
          y: 0,
          scale: 1,
          stagger: 0.15,
          duration: 0.8,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: '#workflow-section',
            start: 'top 75%'
          }
        }
      );

      // ── PHONE TRIO 3D FAN-OUT / SPREAD ANIMATION ──
      // The left and right phones start tucked behind the center phone,
      // and fan out ONLY when the user scrolls into the trio container.
      const trioTl = gsap.timeline({
        scrollTrigger: {
          trigger: '#trio-container',
          start: 'top 85%',
          end: 'center 55%',
          scrub: 1.2
        }
      });

      trioTl
        .fromTo('.trio-left', 
          { x: 110, y: 0, rotateY: 0, rotateZ: 0, scale: 0.8, opacity: 0 },
          { x: 0, y: 20, rotateY: 20, rotateZ: -10, scale: 0.92, opacity: 0.85, ease: 'power2.out' }, 0)
        .fromTo('.trio-right', 
          { x: -110, y: 0, rotateY: 0, rotateZ: 0, scale: 0.8, opacity: 0 },
          { x: 0, y: 20, rotateY: -20, rotateZ: 10, scale: 0.92, opacity: 0.85, ease: 'power2.out' }, 0)
        .fromTo('.trio-center',
          { scale: 0.92, y: 30 },
          { scale: 1.05, y: -10, ease: 'power2.out' }, 0);

      // FAQ Cards Stagger Reveal on scroll
      gsap.fromTo('.faq-card',
        { opacity: 0, y: 25 },
        {
          opacity: 1,
          y: 0,
          stagger: 0.1,
          duration: 0.7,
          ease: 'power2.out',
          scrollTrigger: {
            trigger: '#faq-section',
            start: 'top 80%'
          }
        }
      );

    }, containerRef);

    return () => {
      ctx.revert();
      lenis.destroy();
      gsap.ticker.remove(updateLenis);
      window.removeEventListener('scroll', handleScroll);
      ScrollTrigger.getAll().forEach(st => st.kill());
    };
  }, []);

  // 3D Mouse Movement Tracker for Hero Phone
  const handleMouseMove = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    
    const rotateX = ((y - centerY) / centerY) * -14;
    const rotateY = ((x - centerX) / centerX) * 14;
    
    setTilt({ x: rotateX, y: rotateY });
    setGlarePos({ x: (x / rect.width) * 100, y: (y / rect.height) * 100 });
  };

  const handleMouseLeave = () => {
    setTilt({ x: 0, y: 0 });
    setGlarePos({ x: 50, y: 50 });
  };

  const faqs = [
    {
      q: 'Apakah FormUp benar-benar gratis?',
      a: 'Ya, Anda bisa membuat formulir, menyebarkannya, dan mengumpulkan respons tanpa batas biaya sepeser pun.'
    },
    {
      q: 'Bagaimana integrasi antara versi web dan mobile?',
      a: 'Akun Anda tersinkronisasi secara instan. Semua form yang dibuat di web langsung tersedia di aplikasi mobile dan sebaliknya.'
    },
    {
      q: 'Apakah ada batasan jumlah respons atau pengisi?',
      a: 'Tidak ada batasan kuota. Anda bebas mengumpulkan ribuan respons dari siswa, peserta, atau responden survei.'
    },
    {
      q: 'Bisakah data hasil diekspor ke Excel / CSV?',
      a: 'Tentu. Anda dapat mengekspor rekapitulasi data ke format CSV dan Excel (XLSX) dengan satu klik dari menu respon.'
    }
  ];

  return (
    <div ref={containerRef} className="min-h-screen bg-[#06080D] text-slate-100 font-sans selection:bg-[#00897B] selection:text-white overflow-x-hidden antialiased">
      
      {/* ── GOOGLE FONT INJECTION (Instrument Serif) ──────── */}
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap');
        .font-serif-italic {
          font-family: 'Instrument Serif', serif;
          font-style: italic;
        }
      `}</style>

      {/* ── NAVBAR ────────────────────────────────────────── */}
      <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 px-6 py-4 ${
        scrolled 
          ? 'bg-[#06080D]/85 backdrop-blur-xl border-b border-white/[0.06] shadow-2xl shadow-black/50' 
          : 'bg-transparent'
      }`}>
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <Link to="/" className="text-xl font-black tracking-tight text-white flex items-center gap-1.5 group">
            <span>Form</span>
            <span className="text-[#00C4B4] transition-colors">Up</span>
          </Link>

          <div className="flex items-center gap-3">
            <Link 
              to="/login" 
              className="px-4 py-2 text-xs font-semibold text-slate-300 hover:text-white transition-colors"
            >
              Masuk
            </Link>
            <Link 
              to="/register" 
              className="px-5 py-2 text-xs font-bold text-slate-950 bg-[#00C4B4] hover:bg-[#00E5D0] rounded-full transition-all duration-200 hover:scale-[1.03] shadow-lg shadow-teal-500/20"
            >
              Daftar Gratis
            </Link>
          </div>
        </div>
      </nav>

      {/* ── CHAPTER 01: HERO (3D PERSPECTIVE PHONE) ───────── */}
      <section id="hero-section" className="relative min-h-[95vh] flex flex-col items-center justify-center text-center px-6 pt-32 pb-20 overflow-hidden">
        {/* Deep Atmospheric Glows */}
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[650px] h-[450px] bg-teal-500/[0.08] blur-[160px] rounded-full pointer-events-none" />
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[320px] h-[320px] bg-[#00897B]/[0.15] blur-[110px] rounded-full pointer-events-none" />

        <div className="max-w-4xl mx-auto space-y-6 relative z-10">
          <h1 className="text-5xl sm:text-7xl md:text-8xl font-extrabold tracking-tight text-white leading-[0.95]">
            Buat formulir,<br />
            <span className="font-serif-italic font-normal text-[#00C4B4] tracking-normal text-6xl sm:text-8xl md:text-9xl">
              dari mana saja.
            </span>
          </h1>

          <p className="text-sm sm:text-base text-slate-400 max-w-lg mx-auto font-normal leading-relaxed">
            FormUp hadir di genggamanmu. Buat kuis interaktif, kumpulkan data survei, dan pantau skor secara instan langsung dari smartphone.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-3.5 pt-2">
            <a 
              href="#download"
              className="w-full sm:w-auto px-8 py-3.5 bg-[#00C4B4] hover:bg-[#00E5D0] text-slate-950 text-xs font-extrabold rounded-full transition-all duration-200 hover:-translate-y-0.5 shadow-xl shadow-teal-500/25 flex items-center justify-center gap-2 group cursor-pointer"
            >
              <Smartphone size={16} />
              <span>Download Mobile App</span>
              <ArrowRight size={14} className="group-hover:translate-x-1 transition-transform" />
            </a>

            <Link 
              to="/login"
              className="w-full sm:w-auto px-8 py-3.5 bg-white/[0.04] hover:bg-white/[0.08] text-slate-300 hover:text-white border border-white/[0.08] hover:border-white/20 text-xs font-semibold rounded-full transition-all duration-200 flex items-center justify-center gap-2"
            >
              <Globe size={15} className="text-slate-400" />
              <span>Coba Versi Web</span>
            </Link>
          </div>
        </div>

        {/* ── 3D INTERACTIVE SMARTPHONE (MOUSE TRACKING TILT) ── */}
        <div 
          className="mt-14 relative z-10 w-full max-w-[310px] sm:max-w-[330px] mx-auto cursor-pointer"
          style={{ perspective: '1200px' }}
          onMouseMove={handleMouseMove}
          onMouseLeave={handleMouseLeave}
        >
          {/* Ambient Ground Reflection */}
          <div className="absolute -bottom-10 left-1/2 -translate-x-1/2 w-48 h-8 bg-teal-500/20 blur-xl rounded-full pointer-events-none" />

          {/* 3D Chassis */}
          <div 
            ref={heroPhoneRef}
            className="relative rounded-[50px] p-3 bg-gradient-to-b from-slate-700/70 via-slate-800/50 to-slate-950 border border-white/20 shadow-[0_30px_90px_-20px_rgba(0,0,0,0.95)] backdrop-blur-xl transition-transform duration-150 ease-out"
            style={{
              transform: `rotateX(${tilt.x}deg) rotateY(${tilt.y}deg) translateZ(10px)`,
              transformStyle: 'preserve-3d',
            }}
          >
            {/* Dynamic Glass Glare Overlay */}
            <div 
              className="absolute inset-0 rounded-[48px] pointer-events-none opacity-40 mix-blend-overlay transition-opacity duration-300"
              style={{
                background: `radial-gradient(circle at ${glarePos.x}% ${glarePos.y}%, rgba(255,255,255,0.6) 0%, transparent 60%)`,
              }}
            />

            {/* Inner Phone Bezel & Screen */}
            <div className="rounded-[40px] bg-[#0A0D14] border border-white/[0.08] overflow-hidden p-5 pt-3 aspect-[9/19] flex flex-col justify-between relative shadow-inner text-left">
              
              {/* Dynamic Island */}
              <div className="w-24 h-4 bg-slate-900 rounded-full mx-auto mb-3 border border-white/[0.06] flex items-center justify-end px-2">
                <div className="w-1.5 h-1.5 rounded-full bg-teal-400/80" />
              </div>

              {/* Preset Switcher (Interactive Tabs) */}
              <div className="space-y-3.5">
                <div className="flex items-center justify-between">
                  <div className="flex gap-1 bg-white/[0.04] p-0.5 rounded-lg border border-white/[0.06]">
                    <button 
                      onClick={() => setActivePreset('quiz')}
                      className={`px-2 py-0.5 text-[9px] font-bold rounded-md transition-all ${activePreset === 'quiz' ? 'bg-[#00897B] text-white' : 'text-slate-400'}`}
                    >
                      Kuis
                    </button>
                    <button 
                      onClick={() => setActivePreset('survey')}
                      className={`px-2 py-0.5 text-[9px] font-bold rounded-md transition-all ${activePreset === 'survey' ? 'bg-[#00897B] text-white' : 'text-slate-400'}`}
                    >
                      Survei
                    </button>
                  </div>
                  <span className="text-[9px] font-mono text-[#00C4B4] flex items-center gap-1">
                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" /> LIVE
                  </span>
                </div>

                {/* Simulated Screen Body */}
                {activePreset === 'quiz' ? (
                  <div className="space-y-2.5">
                    <div>
                      <h4 className="text-xs font-bold text-white leading-tight">Ujian Harian Fisika</h4>
                      <p className="text-[9px] text-slate-400">Poin: 10/10 · Waktu: 15 Menit</p>
                    </div>

                    <div className="p-2.5 rounded-xl bg-white/[0.03] border border-white/[0.06] space-y-1.5">
                      <p className="text-[10px] font-medium text-slate-200">1. Satuan internasional untuk gaya adalah?</p>
                      <div className="grid grid-cols-2 gap-1 pt-1">
                        <div className="p-1 rounded-md bg-[#00897B] text-[8px] font-bold text-center text-white flex items-center justify-center gap-1">
                          <Check size={9} /> Newton
                        </div>
                        <div className="p-1 rounded-md bg-white/[0.04] text-[8px] text-center text-slate-400">Joule</div>
                        <div className="p-1 rounded-md bg-white/[0.04] text-[8px] text-center text-slate-400">Pascal</div>
                        <div className="p-1 rounded-md bg-white/[0.04] text-[8px] text-center text-slate-400">Watt</div>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-2.5">
                    <div>
                      <h4 className="text-xs font-bold text-white leading-tight">Survei Pengalaman Siswa</h4>
                      <p className="text-[9px] text-slate-400">Anonim · 2 Pertanyaan</p>
                    </div>

                    <div className="p-2.5 rounded-xl bg-white/[0.03] border border-white/[0.06] space-y-1.5">
                      <p className="text-[10px] font-medium text-slate-200">Bagaimana kemudahan materi hari ini?</p>
                      <div className="flex gap-1 pt-1">
                        <div className="flex-1 py-1 rounded bg-[#00897B] text-[8px] font-bold text-center text-white">Sangat Jelas</div>
                        <div className="flex-1 py-1 rounded bg-white/[0.04] text-[8px] text-center text-slate-400">Cukup</div>
                      </div>
                    </div>
                  </div>
                )}

                <div className="p-2 rounded-xl bg-teal-500/[0.08] border border-teal-500/20 flex items-center justify-between">
                  <span className="text-[9px] text-teal-300 font-medium">Auto-Sync Database</span>
                  <CheckCircle2 size={12} className="text-[#00C4B4]" />
                </div>
              </div>

              {/* Bottom Simulation Bar */}
              <div className="pt-3 border-t border-white/[0.06] flex items-center justify-between text-[9px] text-slate-400 font-mono">
                <span>formup.app/mobile</span>
                <span className="text-[#00C4B4]">Connected</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ── TICKER LINE ───────────────────────────────────── */}
      <div className="border-y border-white/[0.06] bg-white/[0.01] py-4 overflow-hidden">
        <div className="flex gap-8 whitespace-nowrap text-xs font-mono tracking-widest text-slate-400 uppercase justify-center flex-wrap px-4">
          <span>Formulir Cepat</span>
          <span className="text-teal-500">✦</span>
          <span>Analisis Real-Time</span>
          <span className="text-teal-500">✦</span>
          <span>QR Code Generator</span>
          <span className="text-teal-500">✦</span>
          <span>Kuis & Poin Otomatis</span>
          <span className="text-teal-500">✦</span>
          <span>100% Gratis</span>
        </div>
      </div>

      {/* ── CHAPTER 02: STORYTELLING (THE PHILOSOPHY) ─────── */}
      <section ref={storyRef} className="py-28 px-6 max-w-4xl mx-auto text-center space-y-8">
        {/* <p className="text-[11px] font-mono tracking-widest text-teal-400 uppercase story-reveal">01 — Narasi & Cerita</p> */}
        <h2 className="text-3xl sm:text-5xl md:text-6xl font-bold tracking-tight text-white leading-tight story-reveal">
          Mengapa membuat formulir harus <br className="hidden sm:block" />
          <span className="font-serif-italic font-normal text-[#00C4B4] text-4xl sm:text-6xl md:text-7xl">selalu di depan laptop?</span>
        </h2>
        <p className="text-sm sm:text-base text-slate-400 max-w-2xl mx-auto leading-relaxed story-reveal">
          Di ruang kelas, saat seminar, atau di tengah perjalanan — inspirasi membuat kuis atau survei bisa datang kapan saja. FormUp mengubah ponsel pintar Anda menjadi studio pembuatan formulir yang tangguh dan ringan.
        </p>
      </section>

      {/* ── CHAPTER 03: WORKFLOW JOURNEY (4 STEPS) ────────── */}
      <section id="workflow-section" className="py-16 px-6 max-w-6xl mx-auto space-y-12">
        <div className="text-center space-y-2">
          {/* <p className="text-[11px] font-mono tracking-widest text-teal-400 uppercase">02 — Alur 4 Langkah</p> */}
          <h2 className="text-2xl sm:text-4xl font-bold text-white">Semua Selesai dalam Hitungan Menit</h2>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-5">
          <div className="workflow-card p-6 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 hover:bg-white/[0.04] transition-all duration-300 space-y-3 text-left">
            <span className="text-2xl font-black font-serif-italic text-[#00C4B4]">01</span>
            <h3 className="text-sm font-bold text-white">Rancang Soal</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Tentukan pilihan ganda, essay, atau skala rating lengkap dengan bobot nilai.
            </p>
          </div>

          <div className="workflow-card p-6 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 hover:bg-white/[0.04] transition-all duration-300 space-y-3 text-left">
            <span className="text-2xl font-black font-serif-italic text-[#00C4B4]">02</span>
            <h3 className="text-sm font-bold text-white">Atur Kustomisasi</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Batas waktu, acak urutan soal, dan batas satu pengisian per akun.
            </p>
          </div>

          <div className="workflow-card p-6 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 hover:bg-white/[0.04] transition-all duration-300 space-y-3 text-left">
            <span className="text-2xl font-black font-serif-italic text-[#00C4B4]">03</span>
            <h3 className="text-sm font-bold text-white">Sebar Link & QR</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Dapatkan tautan pendek dan kode QR siap cetak atau dipajang di proyektor.
            </p>
          </div>

          <div className="workflow-card p-6 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 hover:bg-white/[0.04] transition-all duration-300 space-y-3 text-left">
            <span className="text-2xl font-black font-serif-italic text-[#00C4B4]">04</span>
            <h3 className="text-sm font-bold text-white">Analisis Instan</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Lihat grafik nilai langsung dan ekspor rekapan ke spreadsheet Excel.
            </p>
          </div>
        </div>
      </section>

      {/* ── CHAPTER 04: CORE CAPABILITIES ─────────────────── */}
      <section className="py-20 px-6 max-w-6xl mx-auto">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="p-8 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 transition-all space-y-4 text-left">
            <div className="w-12 h-12 rounded-2xl bg-teal-500/10 border border-teal-500/20 flex items-center justify-center text-[#00C4B4]">
              <Layers size={22} />
            </div>
            <h3 className="text-base font-bold text-white">Form Builder Ringan</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Antarmuka bersih tanpa gangguan iklan atau lag. Mudah digunakan di layar smartphone mana pun.
            </p>
          </div>

          <div className="p-8 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 transition-all space-y-4 text-left">
            <div className="w-12 h-12 rounded-2xl bg-teal-500/10 border border-teal-500/20 flex items-center justify-center text-[#00C4B4]">
              <BarChart2 size={22} />
            </div>
            <h3 className="text-base font-bold text-white">Grafik & Rekap Nilai</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Persebaran jawaban dihitung otomatis sehingga Anda tidak perlu membuat rumus manual.
            </p>
          </div>

          <div className="p-8 rounded-3xl bg-white/[0.02] border border-white/[0.06] hover:border-teal-500/30 transition-all space-y-4 text-left">
            <div className="w-12 h-12 rounded-2xl bg-teal-500/10 border border-teal-500/20 flex items-center justify-center text-[#00C4B4]">
              <QrCode size={22} />
            </div>
            <h3 className="text-base font-bold text-white">QR Code Bawaan</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              Cukup tampilkan barcode di layar, audiens bisa langsung memindai dan mulai mengisi.
            </p>
          </div>
        </div>
      </section>

      {/* ── CHAPTER 05: 3D TRIO PHONE SILHOUETTE (FINALE) ─── */}
      <section id="download" className="relative py-28 px-6 border-t border-white/[0.06] overflow-hidden text-center">
        {/* Glow Centerpiece */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[350px] bg-teal-500/[0.09] blur-[160px] rounded-full pointer-events-none" />

        <div className="max-w-3xl mx-auto space-y-6 relative z-10 mb-16">
          {/* <p className="text-[11px] font-mono tracking-widest text-teal-400 uppercase">03 — Mobile App</p> */}
          <h2 className="text-4xl sm:text-6xl font-black text-white tracking-tight leading-[1.05]">
            Di genggaman<br />
            <span className="font-serif-italic font-normal text-[#00C4B4] text-5xl sm:text-7xl">tanganmu.</span>
          </h2>
          <p className="text-sm sm:text-base text-slate-400 max-w-lg mx-auto leading-relaxed">
            Daftar sekarang melalui browser untuk mulai membuat formulir, dan nikmati sinkronisasi otomatis saat aplikasi mobile dirilis.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
            <Link
              to="/register"
              className="px-8 py-3.5 bg-[#00C4B4] hover:bg-[#00E5D0] text-slate-950 text-xs font-black rounded-full shadow-xl shadow-teal-500/20 transition-all hover:scale-[1.03] flex items-center justify-center gap-2"
            >
              <span>Mulai Sekarang — Gratis</span>
              <ArrowRight size={14} />
            </Link>

            <Link
              to="/login"
              className="px-8 py-3.5 bg-white/[0.04] hover:bg-white/[0.08] text-slate-300 hover:text-white border border-white/[0.08] text-xs font-semibold rounded-full transition-all"
            >
              Masuk ke Akun
            </Link>
          </div>
        </div>

        {/* ── 3D PERSPECTIVE PHONE TRIO COMPOSITE (MENCAR 3 PADA SAAT SCROLL) ── */}
        <div 
          id="trio-container"
          className="relative max-w-2xl mx-auto flex items-end justify-center gap-2 sm:gap-6 pt-6 min-h-[380px]"
          style={{ perspective: '1200px' }}
        >
          {/* Left Angled 3D Silhouette */}
          <div className="trio-left hidden sm:block w-36 aspect-[9/19] rounded-[36px] bg-gradient-to-b from-slate-800/60 to-slate-950 border border-white/10 shadow-2xl p-2 z-0">
            <div className="w-full h-full rounded-[28px] bg-[#0A0D14] p-3 flex flex-col justify-center gap-2 text-left">
              <div className="w-8 h-1.5 bg-teal-500/40 rounded-full mx-auto" />
              <div className="text-[8px] font-bold text-slate-400">Analitik Respon</div>
              <div className="w-full h-8 bg-teal-500/10 rounded border border-teal-500/20 flex items-center justify-center text-[8px] text-teal-300">
                98% Selesai
              </div>
              <div className="w-full h-1 bg-white/10 rounded-full" />
            </div>
          </div>

          {/* Center Main 3D Silhouette */}
          <div className="trio-center w-48 sm:w-56 aspect-[9/19] rounded-[44px] bg-gradient-to-b from-slate-700/70 via-slate-800/50 to-slate-950 border border-white/20 shadow-[0_25px_70px_rgba(0,0,0,0.9)] p-2.5 z-20">
            <div className="w-full h-full rounded-[34px] bg-[#0A0D14] p-4 flex flex-col justify-between text-left">
              <div className="w-16 h-3 bg-slate-900 rounded-full mx-auto border border-white/10" />
              <div className="space-y-2">
                <div className="text-[10px] font-bold text-white">FormUp Mobile</div>
                <div className="p-2 rounded-lg bg-teal-500/10 border border-teal-500/20 text-[9px] text-[#00C4B4] font-mono">Real-Time Sync Active</div>
              </div>
              <div className="w-full py-1.5 bg-[#00897B] rounded-lg text-[9px] font-bold text-center text-white">Siap Digunakan</div>
            </div>
          </div>

          {/* Right Angled 3D Silhouette */}
          <div className="trio-right hidden sm:block w-36 aspect-[9/19] rounded-[36px] bg-gradient-to-b from-slate-800/60 to-slate-950 border border-white/10 shadow-2xl p-2 z-0">
            <div className="w-full h-full rounded-[28px] bg-[#0A0D14] p-3 flex flex-col justify-center gap-2 text-left">
              <div className="w-8 h-1.5 bg-teal-500/40 rounded-full mx-auto" />
              <div className="text-[8px] font-bold text-slate-400">QR Code Preview</div>
              <div className="w-12 h-12 bg-white/5 rounded-lg mx-auto flex items-center justify-center border border-white/10">
                <QrCode size={20} className="text-[#00C4B4]" />
              </div>
              <div className="w-full h-1 bg-white/10 rounded-full" />
            </div>
          </div>
        </div>
      </section>

      {/* ── CHAPTER 06: FAQ ACCORDION (SMOOTH ANIMATION) ──── */}
      <section id="faq-section" className="py-20 px-6 max-w-2xl mx-auto space-y-8">
        <div className="text-center space-y-2">
          <p className="text-[11px] font-mono tracking-widest text-teal-400 uppercase">FAQ</p>
          <h2 className="text-2xl sm:text-3xl font-bold text-white">Pertanyaan Umum</h2>
        </div>

        <div className="space-y-3">
          {faqs.map((faq, idx) => {
            const isOpen = activeFaq === idx;
            return (
              <div 
                key={idx} 
                className="faq-card rounded-2xl border border-white/[0.06] bg-white/[0.02] overflow-hidden transition-all duration-300 hover:border-white/10"
              >
                <button
                  onClick={() => setActiveFaq(isOpen ? null : idx)}
                  className="w-full p-4.5 text-left flex items-center justify-between gap-4 font-semibold text-xs sm:text-sm text-slate-200 hover:text-white cursor-pointer transition-colors"
                >
                  <span>{faq.q}</span>
                  <div className={`w-6 h-6 rounded-full flex items-center justify-center transition-transform duration-300 shrink-0 ${isOpen ? 'rotate-180 bg-teal-500/10 text-[#00C4B4]' : 'text-slate-500'}`}>
                    <ChevronDown size={15} />
                  </div>
                </button>
                
                {/* Smooth CSS Grid Expansion Animation */}
                <div 
                  className={`grid transition-all duration-300 ease-in-out ${
                    isOpen ? 'grid-rows-[1fr] opacity-100' : 'grid-rows-[0fr] opacity-0'
                  }`}
                >
                  <div className="overflow-hidden">
                    <div className="px-4.5 pb-4.5 text-xs text-slate-400 leading-relaxed border-t border-white/[0.04] pt-3">
                      {faq.a}
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* ── CHAPTER 07: MINIMAL FOOTER ────────────────────── */}
      <footer className="border-t border-white/[0.06] bg-[#05070B] py-10 px-6 text-slate-400 text-xs">
        <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-center sm:text-left">
          <div className="flex items-center gap-2">
            <span className="font-bold text-white text-sm">FormUp</span>
            <span className="text-slate-600">·</span>
            <span className="text-slate-500">© {new Date().getFullYear()} Hak Cipta Dilindungi.</span>
          </div>

          <div className="flex items-center gap-6">
            <Link to="/login" className="hover:text-slate-200 transition-colors">Masuk</Link>
            <Link to="/register" className="hover:text-slate-200 transition-colors">Daftar</Link>
            <a href="#download" className="hover:text-slate-200 transition-colors">Mobile App</a>
          </div>
        </div>
      </footer>

    </div>
  );
}
