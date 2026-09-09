import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from '@studio-freight/lenis';
import {
  ArrowUpRight, Smartphone, Check, ChevronDown,
  Layers, BarChart2, QrCode, Globe, Download, Plus
} from 'lucide-react';
import { isAuthenticated } from '../../services/apiService';
import logo from "../../assets/logo.png";

gsap.registerPlugin(ScrollTrigger);
ScrollTrigger.config({ ignoreMobileResize: true });

/* ─────────────────────────────────────────────
   PALET — krem hangat + hijau (warna app)
───────────────────────────────────────────── */
const CREAM = '#F6F4ED';
const INK = '#1C2620';
const GREEN = '#157A4E';
const GREEN_DEEP = '#0E5A3A';
const DARK = '#0D1F17';
const TINT = '#ECEFE4';
const LIGHT = '#5BC98C';

/* ─────────────────────────────────────────────
   DATA
───────────────────────────────────────────── */
const RITUAL_LINES = [
  'Buka laptop, tunggu loading.',
  'Rancang formulir dari nol.',
  'Tempel link ke tiap grup chat.',
  'Susun nilai manual di spreadsheet.',
  'Ulangi semuanya besok pagi.',
];

const WORKFLOW = [
  { num: '01', title: 'Rancang',
    desc: 'Pilihan ganda, essay, atau skala penilaian — lengkap dengan bobot nilai per soal.' },
  { num: '02', title: 'Atur',
    desc: 'Batas waktu, acak urutan soal, dan batasi satu kali pengisian per responden.' },
  { num: '03', title: 'Bagikan',
    desc: 'Link pendek dan QR code siap ditampilkan di proyektor, papan tulis, atau story.' },
  { num: '04', title: 'Pantau',
    desc: 'Rekap nilai dan grafik jawaban terhitung otomatis. Ekspor ke CSV / XLSX satu klik.' },
];

const BEATS = [
  { num: '01', screen: 'build', title: 'Rancang',
    desc: 'Susun kuis atau survei lewat builder yang ringan — tersedia di web dan aplikasi Android.' },
  { num: '02', screen: 'share', title: 'Bagikan',
    desc: 'Satu link, satu QR code. Peserta mengisi lewat browser tanpa perlu memasang apa pun.' },
  { num: '03', screen: 'track', title: 'Pantau',
    desc: 'Respons masuk real-time. Nilai dan grafik terhitung otomatis, siap diekspor kapan pun.' },
];

const FEATURES = [
  { icon: Layers, title: 'Form builder yang ringan',
    desc: 'Antarmuka bersih, tanpa iklan, nyaman dipakai di layar kecil maupun besar.' },
  { icon: BarChart2, title: 'Hasil terhitung otomatis',
    desc: 'Grafik jawaban dan rekap nilai langsung jadi. Tidak ada rumus spreadsheet manual.' },
  { icon: QrCode, title: 'QR code bawaan',
    desc: 'Peserta pindai, langsung mengisi. Tidak perlu mengetik alamat apa pun.' },
];

const MANIFESTO =
  'Ide untuk kuis atau survei bisa muncul kapan saja — di kelas, di perjalanan, di sela rapat. FormUp membuat satu akunmu cukup: rancang di web, bagikan dan pantau dari mana saja. Data tidak perlu menunggu kamu duduk di depan laptop.';

const FAQS = [
  { q: 'Apakah FormUp gratis?',
    a: 'Ya. Membuat formulir, membagikan, dan mengumpulkan respons tidak dikenakan biaya.' },
  { q: 'Bagaimana sinkronisasi web dan mobile?',
    a: 'Satu akun untuk keduanya. Formulir yang dibuat di web langsung muncul di aplikasi Android, dan sebaliknya.' },
  { q: 'Ada batas jumlah respons?',
    a: 'Tidak ada. Kumpulkan respons sebanyak apa pun dari siswa, peserta, atau responden survei.' },
  { q: 'Bisakah hasil diekspor?',
    a: 'Bisa. Rekapitulasi dapat diekspor ke CSV dan XLSX dari halaman respons.' },
];

const APK_URL = 'https://github.com/abayDahln/FormUp/releases/download/v1.0.0/FormUp.apk';

/* ─────────────────────────────────────────────
   MAGNETIC
───────────────────────────────────────────── */
function Magnetic({ children, className = '', strength = 0.35 }) {
  const ref = useRef(null);
  const xTo = useRef(null);
  const yTo = useRef(null);

  useEffect(() => {
    xTo.current = gsap.quickTo(ref.current, 'x', { duration: 0.5, ease: 'power3.out' });
    yTo.current = gsap.quickTo(ref.current, 'y', { duration: 0.5, ease: 'power3.out' });
  }, []);

  const onMove = useCallback((e) => {
    const rect = ref.current.getBoundingClientRect();
    xTo.current((e.clientX - (rect.left + rect.width / 2)) * strength);
    yTo.current((e.clientY - (rect.top + rect.height / 2)) * strength);
  }, [strength]);
  const onLeave = useCallback(() => { xTo.current(0); yTo.current(0); }, []);

  return (
    <div ref={ref} onMouseMove={onMove} onMouseLeave={onLeave} className={`inline-block ${className}`}>
      {children}
    </div>
  );
}

/* ─────────────────────────────────────────────
   STAT — count-up mandiri via IntersectionObserver
───────────────────────────────────────────── */
function Stat({ value, suffix, label }) {
  const [n, setN] = useState(value);
  const started = useRef(false);
  const ref = useRef(null);

  useEffect(() => {
    const el = ref.current;
    const io = new IntersectionObserver(([e]) => {
      if (!e.isIntersecting || started.current) return;
      started.current = true;
      io.disconnect();
      const start = performance.now();
      const dur = 1400;
      const tick = (t) => {
        const p = Math.min(1, (t - start) / dur);
        setN(Math.round(value * (1 - Math.pow(1 - p, 3))));
        if (p < 1) requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    }, { threshold: 0.4 });
    io.observe(el);
    return () => io.disconnect();
  }, [value]);

  return (
    <div ref={ref}>
      <p className="text-5xl md:text-6xl font-extrabold tracking-tight" style={{ color: INK }}>
        {n}<span style={{ color: GREEN }}>{suffix}</span>
      </p>
      <p className="text-sm mt-3 leading-relaxed" style={{ color: `${INK}80` }}>{label}</p>
    </div>
  );
}

/* ─────────────────────────────────────────────
   LAYAR PONSEL CERITA (build / share / track)
───────────────────────────────────────────── */
function StoryPhone({ screen }) {
  return (
    <div className="relative w-[250px]">
      <div className="absolute -bottom-8 left-1/2 -translate-x-1/2 w-48 h-7 rounded-full blur-2xl"
        style={{ backgroundColor: `${GREEN}40` }} />
      <div className="relative rounded-[40px] p-2.5 border border-white/25"
        style={{
          background: 'linear-gradient(180deg, #2E3B33 0%, #141D18 100%)',
          boxShadow: '0 36px 80px -22px rgba(13,31,23,0.55)',
        }}>
        <div className="rounded-[32px] p-5 aspect-[9/18] flex flex-col gap-4 text-left overflow-hidden"
          style={{ backgroundColor: '#0D1512' }}>
          <div className="w-20 h-4 rounded-full mx-auto flex items-center justify-end px-2"
            style={{ backgroundColor: '#16211B' }}>
            <div className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: `${LIGHT}CC` }} />
          </div>

          {screen === 'build' && (
            <>
              <div>
                <p className="text-xs font-bold text-white">Formulir baru</p>
                <p className="text-[10px] mt-0.5" style={{ color: '#5BC98C' }}>Draf tersimpan otomatis</p>
              </div>
              <div className="rounded-xl p-3 space-y-2" style={{ backgroundColor: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}>
                <div className="h-2 w-3/4 rounded-full" style={{ backgroundColor: 'rgba(255,255,255,0.18)' }} />
                <div className="h-6 rounded-md flex items-center px-2 text-[9px] text-stone-400" style={{ backgroundColor: 'rgba(255,255,255,0.06)' }}>
                  Pilihan ganda
                </div>
                <div className="h-6 rounded-md flex items-center px-2 text-[9px] text-stone-400" style={{ backgroundColor: 'rgba(255,255,255,0.06)' }}>
                  Essay
                </div>
              </div>
              <div className="rounded-xl px-3 py-2.5 flex items-center justify-center gap-1.5 text-[10px] font-bold text-white"
                style={{ backgroundColor: GREEN }}>
                <Plus size={11} /> Tambah pertanyaan
              </div>
            </>
          )}

          {screen === 'share' && (
            <>
              <div>
                <p className="text-xs font-bold text-white">Ujian Harian Fisika</p>
                <p className="text-[10px] mt-0.5 text-stone-400">Siap dibagikan</p>
              </div>
              <div className="rounded-xl p-4 flex flex-col items-center gap-3"
                style={{ backgroundColor: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}>
                <div className="w-24 h-24 rounded-xl flex items-center justify-center"
                  style={{ backgroundColor: '#F6F4ED' }}>
                  <QrCode size={64} style={{ color: INK }} />
                </div>
                <p className="text-[10px] font-semibold" style={{ color: LIGHT }}>formup.app/f/8x2k</p>
              </div>
              <div className="rounded-xl px-3 py-2 flex items-center justify-between"
                style={{ backgroundColor: `${GREEN}1F`, border: `1px solid ${GREEN}40` }}>
                <span className="text-[10px] font-medium" style={{ color: LIGHT }}>Siap dipindai</span>
                <Check size={13} style={{ color: LIGHT }} />
              </div>
            </>
          )}

          {screen === 'track' && (
            <>
              <div>
                <p className="text-xs font-bold text-white">Rekap respons</p>
                <p className="text-[10px] mt-0.5" style={{ color: LIGHT }}>128 dari 140 sudah mengisi</p>
              </div>
              <div className="rounded-xl p-4 space-y-2.5"
                style={{ backgroundColor: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}>
                <p className="text-[10px] text-stone-400">Persebaran nilai</p>
                <div className="flex items-end gap-1.5 h-20">
                  {[35, 55, 80, 100, 70, 45].map((h, i) => (
                    <div key={i} className="flex-1 rounded-t-sm" style={{ height: `${h}%`, backgroundColor: i === 3 ? LIGHT : GREEN }} />
                  ))}
                </div>
                <div className="flex justify-between text-[8px] text-stone-500">
                  <span>0</span><span>50</span><span>100</span>
                </div>
              </div>
              <div className="rounded-xl px-3 py-2 flex items-center justify-between"
                style={{ backgroundColor: `${GREEN}1F`, border: `1px solid ${GREEN}40` }}>
                <span className="text-[10px] font-medium" style={{ color: LIGHT }}>Ekspor CSV / XLSX</span>
                <Download size={12} style={{ color: LIGHT }} />
              </div>
            </>
          )}

          <div className="mt-auto pt-3 flex items-center justify-between text-[10px] text-stone-500"
            style={{ borderTop: '1px solid rgba(255,255,255,0.07)' }}>
            <span>formup.app</span>
            <span style={{ color: LIGHT }}>Terhubung</span>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────
   MAIN
───────────────────────────────────────────── */
export default function LandingPage() {
  const navigate = useNavigate();
  const [scrolled, setScrolled] = useState(false);
  const [openFaq, setOpenFaq] = useState(null);
  const [preset, setPreset] = useState('quiz');
  const [beat, setBeat] = useState(0);
  const [screen, setScreen] = useState('build');

  const containerRef = useRef(null);
  const phoneIntroRef = useRef(null);
  const phoneFloatRef = useRef(null);
  const phoneFallRef = useRef(null);
  const phoneTiltRef = useRef(null);
  const glareRef = useRef(null);
  const rotXTo = useRef(null);
  const rotYTo = useRef(null);

  useEffect(() => {
    if (isAuthenticated()) navigate('/dashboard', { replace: true });
  }, [navigate]);

  /* ── TILT 3D hero ── */
  useEffect(() => {
    if (!phoneTiltRef.current) return;
    rotXTo.current = gsap.quickTo(phoneTiltRef.current, 'rotationX', { duration: 0.6, ease: 'power3.out' });
    rotYTo.current = gsap.quickTo(phoneTiltRef.current, 'rotationY', { duration: 0.6, ease: 'power3.out' });
  }, []);

  const handleMouseMove = useCallback((e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const px = (e.clientX - rect.left) / rect.width;
    const py = (e.clientY - rect.top) / rect.height;
    rotXTo.current?.((py - 0.5) * -18);
    rotYTo.current?.((px - 0.5) * 22);
    if (glareRef.current) {
      glareRef.current.style.background =
        `radial-gradient(circle at ${px * 100}% ${py * 100}%, rgba(255,255,255,0.4) 0%, transparent 55%)`;
    }
  }, []);
  const handleMouseLeave = useCallback(() => {
    rotXTo.current?.(0);
    rotYTo.current?.(0);
    if (glareRef.current) {
      glareRef.current.style.background =
        'radial-gradient(circle at 50% 20%, rgba(255,255,255,0.18) 0%, transparent 55%)';
    }
  }, []);

  /* ── LENIS + GSAP ── */
  useEffect(() => {
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    let lenis = null;
    if (!reduced) {
      lenis = new Lenis({ duration: 1.15, smoothWheel: true });
      lenis.on('scroll', ScrollTrigger.update);
    }
    const raf = (time) => lenis?.raf(time * 1000);
    gsap.ticker.add(raf);
    gsap.ticker.lagSmoothing(0);

    const onScroll = () => setScrolled(window.scrollY > 24);
    window.addEventListener('scroll', onScroll, { passive: true });

    const mm = gsap.matchMedia();

    const ctx = gsap.context(() => {
      /* ── progress bar halaman ── */
      gsap.to('#page-progress', {
        scaleX: 1, ease: 'none',
        scrollTrigger: { trigger: document.body, start: 'top top', end: 'bottom bottom', scrub: 0.3 },
      });

      /* ── HERO ENTRANCE (time-based, pasti jalan) ── */
      gsap.timeline({ defaults: { ease: 'power4.out' } })
        .fromTo('.nav-item', { y: -18, opacity: 0 }, { y: 0, opacity: 1, stagger: 0.08, duration: 0.8 }, 0.1)
        .fromTo('.hero-kicker', { y: 16, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8 }, 0.25)
        .fromTo('.hero-line', { yPercent: 110 }, { yPercent: 0, stagger: 0.12, duration: 1.1 }, 0.3)
        .fromTo('.hero-sub', { y: 20, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8 }, 0.7)
        .fromTo('.hero-cta', { y: 16, opacity: 0 }, { y: 0, opacity: 1, stagger: 0.1, duration: 0.7 }, 0.85)
        .fromTo('.hero-meta', { opacity: 0 }, { opacity: 1, duration: 0.9 }, 1)
        .fromTo(phoneIntroRef.current, { y: 80, opacity: 0, scale: 0.94 },
          { y: 0, opacity: 1, scale: 1, duration: 1.3, ease: 'power3.out' }, 0.45);

      /* levitasi */
      gsap.to(phoneFloatRef.current, { y: -12, duration: 3.2, repeat: -1, yoyo: true, ease: 'sine.inOut' });

      /* hp "jatuh" keluar hero — scrub di wrapper terluar, tween tunggal */
      gsap.to(phoneFallRef.current, {
        y: 340, rotate: -14, opacity: 0, ease: 'none',
        scrollTrigger: { trigger: '#hero', start: 'top top', end: 'bottom top', scrub: 1 },
      });

      /* ── RITUAL — stacked pinning (konten nyata, anti blank) ── */
      mm.add('(min-width: 768px)', () => {
        gsap.utils.toArray('.ritual-panel').forEach((panel) => {
          gsap.from(panel.querySelector('.ritual-inner'), {
            y: 70, opacity: 0, duration: 1, ease: 'power3.out',
            scrollTrigger: { trigger: panel, start: 'top 62%', toggleActions: 'play none none reverse' },
          });
          ScrollTrigger.create({ trigger: panel, start: 'top top', pin: true, pinSpacing: false });
        });
      });

      mm.add('(max-width: 767px)', () => {
        gsap.utils.toArray('.m-reveal').forEach((el) => {
          gsap.from(el, {
            y: 36, opacity: 0, duration: 0.9, ease: 'power3.out',
            scrollTrigger: { trigger: el, start: 'top 88%', once: true },
          });
        });
      });

      /* ── MANIFESTO — kata menyala ── */
      gsap.fromTo('.mword', { opacity: 0.15 }, {
        opacity: 1, stagger: 0.05, ease: 'none',
        scrollTrigger: {
          trigger: '#manifesto', start: 'top 78%', end: 'bottom 65%',
          scrub: 1, invalidateOnRefresh: true,
        },
      });

      /* ── ALUR — GSAP PIN (bukan CSS sticky, fixes overflow-x bug).
         Track mulai dari posisi natural → walau tween gagal, kartu pertama tetap terlihat. ── */
      mm.add('(min-width: 768px)', () => {
        const track = document.querySelector('.wf-track');
        const dist = () => Math.max(0, track.scrollWidth - window.innerWidth + 60);
        gsap.to(track, {
          x: () => -dist(), ease: 'none',
          scrollTrigger: {
            trigger: '#alur', start: 'top top',
            end: () => '+=' + dist(),
            scrub: 1, pin: true, anticipatePin: 1, invalidateOnRefresh: true,
          },
        });
        gsap.fromTo('.wf-progress', { scaleX: 0 }, {
          scaleX: 1, ease: 'none',
          scrollTrigger: {
            trigger: '#alur', start: 'top top',
            end: () => '+=' + dist(), scrub: 1, invalidateOnRefresh: true,
          },
        });
      });

      /* ── CERITA — ponsel menemani scroll 2,5 layar.
         Beat pakai toggleClass (CSS transition) → tidak ada konten yang
         nyangkut hidden walau pengukuran meleset. ── */
      mm.add('(min-width: 768px)', () => {
        ScrollTrigger.create({
          trigger: '#cerita', start: 'top top', end: '+=250%',
          pin: '.cerita-stage', anticipatePin: 1,
        });

        const beats = gsap.utils.toArray('.beat');
        const step = () => window.innerHeight * 0.8;
        beats.forEach((b, i) => {
          ScrollTrigger.create({
            trigger: '#cerita',
            start: () => 'top+=' + i * step() + ' top',
            end: () => 'top+=' + (i + 1) * step() + ' top',
            onToggle: (self) => {
              if (!self.isActive) return;
              beats.forEach((x) => x.classList.remove('beat-active'));
              b.classList.add('beat-active');
              setBeat(i);
              setScreen(BEATS[i].screen);
            },
          });
        });

        /* gerak ponsel: melayang → jatuh keluar di akhir */
        gsap.timeline({
          scrollTrigger: { trigger: '#cerita', start: 'top top', end: '+=250%', scrub: 1 },
        })
          .fromTo('.cerita-phone', { y: 90, rotate: 5 }, { y: -30, rotate: -4, ease: 'none', duration: 3 })
          .to('.cerita-phone', { y: 320, rotate: 16, opacity: 0, ease: 'power1.in', duration: 1 });
      });

      /* ── FITUR ── */
      gsap.from('.feature-card', {
        y: 56, opacity: 0, duration: 0.9, stagger: 0.12, ease: 'power3.out',
        scrollTrigger: { trigger: '#fitur', start: 'top 78%', once: true },
      });

      /* ── TRIO FAN-OUT 3D (play-once) ── */
      const trioTl = gsap.timeline({
        scrollTrigger: { trigger: '#trio', start: 'top 85%', once: true },
        defaults: { duration: 1.1, ease: 'power3.out' },
      });
      trioTl
        .fromTo('.trio-left',
          { x: 90, rotateY: 0, rotateZ: 0, scale: 0.72, opacity: 0 },
          { x: 0, rotateY: 22, rotateZ: -8, scale: 0.9, opacity: 1 }, 0)
        .fromTo('.trio-right',
          { x: -90, rotateY: 0, rotateZ: 0, scale: 0.72, opacity: 0 },
          { x: 0, rotateY: -22, rotateZ: 8, scale: 0.9, opacity: 1 }, 0)
        .fromTo('.trio-center', { scale: 0.88, y: 36 }, { scale: 1.04, y: -6 }, 0);

      /* ── FAQ ── */
      gsap.from('.faq-card', {
        y: 28, opacity: 0, duration: 0.7, stagger: 0.08, ease: 'power2.out',
        scrollTrigger: { trigger: '#faq', start: 'top 82%', once: true },
      });
    }, containerRef);

    /* refresh setelah font, gambar, dan layout stabil */
    if (document.fonts?.ready) document.fonts.ready.then(() => ScrollTrigger.refresh());
    const onLoad = () => ScrollTrigger.refresh();
    window.addEventListener('load', onLoad);
    const t = setTimeout(() => ScrollTrigger.refresh(), 600);

    return () => {
      clearTimeout(t);
      ctx.revert();
      mm.revert();
      gsap.ticker.remove(raf);
      lenis?.destroy();
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('load', onLoad);
    };
  }, []);

  const setActiveBeat = (i) => { setBeat(i); setScreen(BEATS[i].screen); };

  return (
    <div ref={containerRef} className="min-h-screen overflow-x-clip antialiased"
      style={{ backgroundColor: CREAM, color: INK, fontFamily: "'Inter', system-ui, sans-serif" }}>

      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=Instrument+Serif:ital@0;1&display=swap');
        .font-serifit { font-family: 'Instrument Serif', Georgia, serif; }

        @keyframes blink { 50% { opacity: .2 } }
        .blink { animation: blink 1.6s ease-in-out infinite; }

        /* beat cerita — desktop: tumpukan absolut; mobile: alur normal */
        @media (min-width: 768px) {
          .beat {
            position: absolute; inset: 0;
            display: flex; flex-direction: column; justify-content: center;
            opacity: 0; transform: translateY(28px);
            transition: opacity .55s ease, transform .55s ease;
            pointer-events: none;
          }
          .beat-active { opacity: 1 !important; transform: none !important; pointer-events: auto; }
        }
        @media (prefers-reduced-motion: reduce) {
          .blink { animation: none !important; }
          .beat { transition: none !important; }
        }
      `}</style>

      <div id="page-progress" className="fixed top-0 left-0 right-0 h-[3px] origin-left scale-x-0 z-[60]"
        style={{ backgroundColor: GREEN }} />

      {/* ── NAVBAR ── */}
      <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 px-6 ${
        scrolled ? 'backdrop-blur-md border-b py-3' : 'bg-transparent py-5'
      }`} style={scrolled ? { backgroundColor: `${CREAM}D9`, borderColor: `${INK}1A` } : {}}>
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <Link to="/" className="nav-item flex items-center gap-2.5">
            <img src={logo} alt="FormUp" className="w-8 h-8 object-contain" />
            <span className="text-lg font-bold tracking-tight">Form<span style={{ color: GREEN }}>Up</span></span>
          </Link>
          <div className="flex items-center gap-2 sm:gap-4">
            <Link to="/login" className="nav-item px-3 py-2 text-sm font-medium transition-colors"
              style={{ color: `${INK}99` }}>
              Masuk
            </Link>
            <Magnetic>
              <Link to="/register"
                className="nav-item px-5 py-2.5 text-sm font-semibold text-[#F6F4ED] rounded-full transition-colors duration-300"
                style={{ backgroundColor: INK }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = GREEN)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = INK)}
              >
                Daftar gratis
              </Link>
            </Magnetic>
          </div>
        </div>
      </nav>

      {/* ═══ HERO ═══ */}
      <section id="hero" className="relative px-6 pt-36 pb-24 lg:pt-40 overflow-hidden">
        <div className="max-w-6xl mx-auto grid lg:grid-cols-[1.1fr_0.9fr] gap-16 items-center">
          <div>
            <p className="hero-kicker text-xs font-bold tracking-[0.18em] uppercase mb-7 flex items-center gap-2.5"
              style={{ color: GREEN }}>
              <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: GREEN }} />
              Form builder untuk web &amp; mobile
            </p>
            <h1 className="text-5xl sm:text-7xl lg:text-[5.4rem] font-extrabold tracking-[-0.03em] leading-[1.02]">
              <span className="block overflow-hidden pb-1"><span className="hero-line block">Buat formulir,</span></span>
              <span className="block overflow-hidden pb-2">
                <span className="hero-line block">
                  <span className="font-serifit italic font-normal" style={{ color: GREEN }}>dari mana saja.</span>
                </span>
              </span>
            </h1>
            <p className="hero-sub text-base max-w-md leading-relaxed mt-7" style={{ color: `${INK}99` }}>
              Kuis, survei, dan pantauan nilai dalam hitungan menit. Rancang di browser,
              bagikan lewat link atau QR, pantau hasilnya langsung.
            </p>
            <div className="flex flex-col sm:flex-row items-start gap-3.5 mt-9">
              <Magnetic className="hero-cta w-full sm:w-auto">
                <a href={APK_URL} download="FormUp.apk" target="_blank" rel="noopener noreferrer"
                  className="w-full sm:w-auto px-7 py-3.5 text-[#F6F4ED] text-sm font-semibold rounded-full transition-colors duration-300 flex items-center justify-center gap-2"
                  style={{ backgroundColor: GREEN }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = GREEN_DEEP)}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = GREEN)}
                >
                  <Smartphone size={16} /> Unduh aplikasi <ArrowUpRight size={15} />
                </a>
              </Magnetic>
              <Magnetic className="hero-cta w-full sm:w-auto" strength={0.25}>
                <Link to="/login"
                  className="w-full sm:w-auto px-7 py-3.5 text-sm font-semibold rounded-full border transition-all flex items-center justify-center gap-2"
                  style={{ borderColor: `${INK}33`, color: INK }}
                  onMouseEnter={(e) => { e.currentTarget.style.borderColor = `${INK}80`; e.currentTarget.style.backgroundColor = `${INK}0D`; }}
                  onMouseLeave={(e) => { e.currentTarget.style.borderColor = `${INK}33`; e.currentTarget.style.backgroundColor = 'transparent'; }}
                >
                  <Globe size={16} style={{ color: `${INK}80` }} /> Buka di browser
                </Link>
              </Magnetic>
            </div>
            <p className="hero-meta text-sm mt-9 font-medium" style={{ color: `${INK}66` }}>
              Gratis tanpa batas respons
              <span className="mx-2.5" style={{ color: GREEN }}>•</span>
              Sinkron web &amp; mobile
              <span className="mx-2.5" style={{ color: GREEN }}>•</span>
              QR code bawaan
            </p>
          </div>

          {/* ponsel hero: intro → fall wrapper → float → tilt */}
          <div className="flex justify-center lg:justify-end" style={{ perspective: '1400px' }}>
            <div ref={phoneFallRef}>
              <div ref={phoneIntroRef}>
                <div ref={phoneFloatRef}>
                  <div className="relative w-[270px]" onMouseMove={handleMouseMove} onMouseLeave={handleMouseLeave}>
                    <div className="absolute -bottom-8 left-1/2 -translate-x-1/2 w-52 h-7 rounded-full blur-2xl"
                      style={{ backgroundColor: `${GREEN}40` }} />
                    <div ref={phoneTiltRef}
                      className="relative rounded-[44px] p-2.5 border border-white/25"
                      style={{
                        transformStyle: 'preserve-3d',
                        background: 'linear-gradient(180deg, #33413A 0%, #17211C 100%)',
                        boxShadow: '0 36px 80px -22px rgba(28,38,32,0.55)',
                      }}
                    >
                      <div ref={glareRef}
                        className="absolute inset-0 rounded-[42px] pointer-events-none opacity-60 mix-blend-overlay"
                        style={{ background: 'radial-gradient(circle at 50% 20%, rgba(255,255,255,0.18) 0%, transparent 55%)' }}
                      />
                      <div className="rounded-[34px] p-5 aspect-[9/18] flex flex-col gap-4 text-left overflow-hidden"
                        style={{ backgroundColor: '#0E1613' }}>
                        <div className="w-20 h-4 rounded-full mx-auto flex items-center justify-end px-2"
                          style={{ backgroundColor: '#182420' }}>
                          <div className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: `${LIGHT}CC` }} />
                        </div>

                        <div className="flex items-center justify-between">
                          <div className="flex gap-1 p-1 rounded-lg" style={{ backgroundColor: 'rgba(255,255,255,0.05)' }}>
                            {[['quiz', 'Kuis'], ['survey', 'Survei']].map(([id, label]) => (
                              <button key={id} onClick={() => setPreset(id)}
                                className={`px-3 py-1 text-[11px] font-semibold rounded-md transition-colors duration-200 ${preset === id ? 'text-white' : 'text-stone-400 hover:text-stone-200'}`}
                                style={preset === id ? { backgroundColor: GREEN } : {}}>
                                {label}
                              </button>
                            ))}
                          </div>
                          <span className="text-[10px] font-semibold flex items-center gap-1.5 blink" style={{ color: LIGHT }}>
                            <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: LIGHT }} /> LIVE
                          </span>
                        </div>

                        {preset === 'quiz' ? (
                          <div className="rounded-xl p-3.5 space-y-2.5"
                            style={{ backgroundColor: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}>
                            <div>
                              <p className="text-xs font-bold text-white">Ujian Harian Fisika</p>
                              <p className="text-[10px] text-stone-400 mt-0.5">10 soal · 15 menit</p>
                            </div>
                            <p className="text-[11px] text-stone-200">1. Satuan SI untuk gaya adalah…</p>
                            <div className="grid grid-cols-2 gap-1.5">
                              <div className="py-1.5 rounded-md text-[10px] font-semibold text-center text-white flex items-center justify-center gap-1"
                                style={{ backgroundColor: GREEN }}>
                                <Check size={10} /> Newton
                              </div>
                              {['Joule', 'Pascal', 'Watt'].map((o) => (
                                <div key={o} className="py-1.5 rounded-md text-[10px] text-center text-stone-400"
                                  style={{ backgroundColor: 'rgba(255,255,255,0.05)' }}>{o}</div>
                              ))}
                            </div>
                          </div>
                        ) : (
                          <div className="rounded-xl p-3.5 space-y-2.5"
                            style={{ backgroundColor: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,0.07)' }}>
                            <div>
                              <p className="text-xs font-bold text-white">Survei Kepuasan Kelas</p>
                              <p className="text-[10px] text-stone-400 mt-0.5">Anonim · 2 pertanyaan</p>
                            </div>
                            <p className="text-[11px] text-stone-200">Seberapa jelas materi hari ini?</p>
                            <div className="flex gap-1.5">
                              <div className="flex-1 py-1.5 rounded-md text-[10px] font-semibold text-center text-white"
                                style={{ backgroundColor: GREEN }}>Sangat jelas</div>
                              <div className="flex-1 py-1.5 rounded-md text-[10px] text-center text-stone-400"
                                style={{ backgroundColor: 'rgba(255,255,255,0.05)' }}>Cukup</div>
                            </div>
                          </div>
                        )}

                        <div className="rounded-xl px-3 py-2 flex items-center justify-between"
                          style={{ backgroundColor: `${GREEN}1F`, border: `1px solid ${GREEN}40` }}>
                          <span className="text-[10px] font-medium" style={{ color: LIGHT }}>Tersinkron dengan web</span>
                          <Check size={13} style={{ color: LIGHT }} />
                        </div>

                        <div className="mt-auto pt-3 flex items-center justify-between text-[10px] text-stone-500"
                          style={{ borderTop: '1px solid rgba(255,255,255,0.07)' }}>
                          <span>formup.app</span>
                          <span style={{ color: LIGHT }}>Terhubung</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ═══ RITUAL — stacked pinning ═══ */}
      <section className="relative">
        {RITUAL_LINES.map((line, i) => (
          <div key={i} className="ritual-panel relative min-h-[85vh] md:min-h-screen flex items-center justify-center px-6"
            style={{ backgroundColor: i % 2 === 1 ? TINT : CREAM, zIndex: i + 2 }}>
            <div className="ritual-inner text-center max-w-3xl">
              <p className="text-xs font-bold tracking-[0.2em] uppercase mb-6" style={{ color: GREEN }}>
                Ritual lama · {i + 1} dari {RITUAL_LINES.length}
              </p>
              <p className="text-4xl sm:text-6xl font-extrabold tracking-tight leading-[1.08]">{line}</p>
            </div>
          </div>
        ))}
        <div className="ritual-panel relative min-h-[85vh] md:min-h-screen flex items-center justify-center px-6"
          style={{ backgroundColor: GREEN, zIndex: RITUAL_LINES.length + 2 }}>
          <div className="ritual-inner text-center max-w-3xl">
            <p className="text-xs font-bold tracking-[0.2em] uppercase mb-7" style={{ color: '#F6F4EDB3' }}>
              Lalu FormUp bertanya
            </p>
            <p className="text-5xl sm:text-7xl font-extrabold tracking-tight leading-[1.05] text-[#F6F4ED]">
              Kenapa harus{' '}
              <span className="font-serifit italic font-normal">sesulit itu?</span>
            </p>
          </div>
        </div>
      </section>

      {/* ═══ MANIFESTO ═══ */}
      <section id="manifesto" className="relative px-6 py-28 md:py-40" style={{ backgroundColor: CREAM, zIndex: 10 }}>
        <div className="max-w-3xl mx-auto">
          <p className="m-reveal text-xs font-bold tracking-[0.18em] uppercase mb-8" style={{ color: GREEN }}>
            Manifesto
          </p>
          <p className="text-2xl sm:text-3xl md:text-[2.4rem] font-medium leading-snug md:leading-[1.35] tracking-[-0.01em]">
            {MANIFESTO.split(' ').map((w, i) => (
              <span key={i} className="mword inline-block mr-[0.28em]">{w}</span>
            ))}
          </p>
        </div>
      </section>

      {/* ═══ ALUR — GSAP pin horizontal scrub ═══ */}
      <section id="alur" className="relative" style={{ backgroundColor: TINT, zIndex: 10 }}>
        <div className="wf-progress absolute top-0 left-0 right-0 h-1 origin-left scale-x-0 z-30" style={{ backgroundColor: GREEN }} />
        <div className="min-h-screen flex flex-col justify-center overflow-hidden py-24 md:py-0">
          <div className="px-6 md:px-[7vw] mb-10 md:mb-14 flex items-end justify-between gap-6">
            <div>
              <p className="m-reveal text-xs font-bold tracking-[0.18em] uppercase mb-4" style={{ color: GREEN }}>
                Cara kerja
              </p>
              <h2 className="m-reveal text-3xl sm:text-5xl font-extrabold tracking-tight leading-[1.05]">
                Empat langkah.<br />
                <span className="font-serifit italic font-normal" style={{ color: GREEN }}>Nol ribet.</span>
              </h2>
            </div>
            <p className="hidden md:flex items-center gap-2 text-xs font-semibold tracking-wide uppercase" style={{ color: `${INK}66` }}>
              Scroll <ArrowUpRight size={14} />
            </p>
          </div>

          <div className="wf-track flex flex-col md:flex-row gap-5 md:gap-[2.5vw] px-6 md:px-[7vw] md:w-max will-change-transform">
            {WORKFLOW.map((step) => (
              <article key={step.num}
                className="group relative shrink-0 p-8 md:p-10 rounded-3xl border overflow-hidden md:w-[36vw] lg:w-[28vw] transition-colors duration-500"
                style={{ backgroundColor: CREAM, borderColor: `${INK}1A` }}
                onMouseEnter={(e) => (e.currentTarget.style.borderColor = `${GREEN}80`)}
                onMouseLeave={(e) => (e.currentTarget.style.borderColor = `${INK}1A`)}
              >
                <div className="absolute -top-8 -right-3 text-[10rem] font-extrabold leading-none select-none pointer-events-none"
                  style={{ color: `${INK}08` }}>
                  {step.num}
                </div>
                <p className="text-sm font-extrabold mb-6 relative" style={{ color: GREEN }}>{step.num}</p>
                <h3 className="text-2xl font-extrabold mb-3 relative">{step.title}</h3>
                <p className="text-sm leading-relaxed relative" style={{ color: `${INK}99` }}>{step.desc}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      {/* ═══ CERITA — ponsel menemani scroll 2,5 layar ═══ */}
      <section id="cerita" className="relative" style={{ backgroundColor: CREAM, zIndex: 10 }}>
        <div className="cerita-stage relative h-screen overflow-hidden">
          <div className="max-w-6xl mx-auto h-full px-6 grid md:grid-cols-2 gap-10 items-center">
            <div className="relative md:h-[420px] py-10 md:py-0">
              {BEATS.map((b, i) => (
                <div key={b.num}
                  className={`beat ${i === 0 ? 'beat-active' : ''} max-w-md`}
                  onClick={() => setActiveBeat(i)}>
                  <p className="text-xs font-bold tracking-[0.2em] uppercase mb-5" style={{ color: GREEN }}>
                    {b.num} — {BEATS.length} langkah utama
                  </p>
                  <h3 className="text-4xl sm:text-6xl font-extrabold tracking-tight mb-5">
                    {b.title}
                    <span className="font-serifit italic font-normal" style={{ color: GREEN }}>.</span>
                  </h3>
                  <p className="text-base leading-relaxed" style={{ color: `${INK}99` }}>{b.desc}</p>
                </div>
              ))}
              <div className="hidden md:flex absolute -bottom-2 left-0 gap-2">
                {BEATS.map((b, i) => (
                  <span key={b.num} className="h-1.5 rounded-full transition-all duration-500"
                    style={{
                      width: beat === i ? 28 : 10,
                      backgroundColor: beat === i ? GREEN : `${INK}26`,
                    }} />
                ))}
              </div>
            </div>
            <div className="hidden md:flex justify-center" style={{ perspective: '1400px' }}>
              <div className="cerita-phone">
                <StoryPhone screen={screen} />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ═══ FITUR + STATISTIK ═══ */}
      <section id="fitur" className="relative px-6 py-24 md:py-32" style={{ backgroundColor: CREAM, zIndex: 10 }}>
        <div className="max-w-6xl mx-auto">
          <p className="text-xs font-bold tracking-[0.18em] uppercase mb-4" style={{ color: GREEN }}>
            Kemampuan utama
          </p>
          <h2 className="text-3xl sm:text-5xl font-extrabold tracking-tight mb-14">
            Yang kamu butuhkan,{' '}
            <span className="font-serifit italic font-normal" style={{ color: GREEN }}>tidak lebih.</span>
          </h2>
          <div className="grid md:grid-cols-3 gap-5 mb-20">
            {FEATURES.map((f) => (
              <article key={f.title}
                className="feature-card group relative p-8 rounded-3xl border bg-white transition-all duration-500 hover:-translate-y-1.5"
                style={{ borderColor: `${INK}14`, boxShadow: '0 1px 2px rgba(28,38,32,0.05)' }}
                onMouseEnter={(e) => (e.currentTarget.style.borderColor = `${GREEN}66`)}
                onMouseLeave={(e) => (e.currentTarget.style.borderColor = `${INK}14`)}
              >
                <div className="w-11 h-11 rounded-xl flex items-center justify-center mb-6 transition-transform duration-500 group-hover:scale-110"
                  style={{ backgroundColor: `${GREEN}14`, color: GREEN }}>
                  <f.icon size={20} />
                </div>
                <h3 className="text-base font-bold mb-2.5">{f.title}</h3>
                <p className="text-sm leading-relaxed" style={{ color: `${INK}99` }}>{f.desc}</p>
              </article>
            ))}
          </div>
          <div className="grid sm:grid-cols-3 gap-y-12 gap-x-8 pt-12" style={{ borderTop: `1px solid ${INK}14` }}>
            <Stat value={3} suffix=" menit" label="rata-rata waktu membuat satu formulir" />
            <Stat value={100} suffix="%" label="gratis, tanpa batas jumlah respons" />
            <Stat value={1} suffix=" klik" label="untuk ekspor rekap ke CSV / XLSX" />
          </div>
        </div>
      </section>

      {/* ═══ FAQ ═══ */}
      <section id="faq" className="relative px-6 pb-24 md:pb-32" style={{ backgroundColor: CREAM, zIndex: 10 }}>
        <div className="max-w-2xl mx-auto">
          <h2 className="text-3xl sm:text-4xl font-extrabold tracking-tight text-center mb-12">
            Pertanyaan umum
          </h2>
          <div className="space-y-3">
            {FAQS.map((faq, i) => {
              const open = openFaq === i;
              return (
                <div key={i} className="faq-card rounded-2xl border bg-white overflow-hidden transition-colors duration-300"
                  style={{ borderColor: open ? `${GREEN}80` : `${INK}14` }}>
                  <button onClick={() => setOpenFaq(open ? null : i)}
                    className="w-full p-5 text-left flex items-center justify-between gap-4 font-semibold text-sm transition-colors"
                    style={{ color: open ? GREEN : INK }}>
                    <span>{faq.q}</span>
                    <div className="w-7 h-7 rounded-full flex items-center justify-center shrink-0 transition-transform duration-300"
                      style={{
                        transform: open ? 'rotate(180deg)' : 'none',
                        backgroundColor: open ? `${GREEN}1F` : `${INK}0D`,
                        color: open ? GREEN : `${INK}80`,
                      }}>
                      <ChevronDown size={15} />
                    </div>
                  </button>
                  <div className="grid transition-all duration-300 ease-in-out"
                    style={{ gridTemplateRows: open ? '1fr' : '0fr', opacity: open ? 1 : 0 }}>
                    <div className="overflow-hidden">
                      <p className="px-5 pb-5 text-sm leading-relaxed pt-4"
                        style={{ color: `${INK}99`, borderTop: `1px solid ${INK}0F` }}>
                        {faq.a}
                      </p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ═══ FINALE — tepat satu layar penuh ═══ */}
      <section className="relative text-[#F6F4ED] overflow-hidden flex flex-col"
        style={{ height: '100vh', background: `linear-gradient(180deg, ${CREAM} 0%, ${DARK} 14%, ${DARK} 100%)`, zIndex: 10 }}>
        <div className="flex-1 flex flex-col items-center justify-center text-center px-6 max-w-3xl mx-auto w-full pt-20">
          <p className="m-reveal text-xs font-bold tracking-[0.18em] uppercase mb-5" style={{ color: LIGHT }}>
            Aplikasi Android
          </p>
          <h2 className="m-reveal text-4xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight leading-[1.05] mb-5">
            Bawa FormUp{' '}
            <span className="font-serifit italic font-normal" style={{ color: LIGHT }}>ke mana-mana.</span>
          </h2>
          <p className="m-reveal text-sm sm:text-base max-w-md mx-auto leading-relaxed mb-8" style={{ color: '#F6F4EDA6' }}>
            Daftar lewat browser sekarang, pasang aplikasinya sesudahnya —
            semua formulirmu sudah menunggu di sana.
          </p>
          <div className="m-reveal flex flex-col sm:flex-row items-center justify-center gap-3.5">
            <Magnetic>
              <a href={APK_URL} download="FormUp.apk" target="_blank" rel="noopener noreferrer"
                className="px-7 py-3.5 text-sm font-bold rounded-full flex items-center gap-2 transition-colors duration-300"
                style={{ backgroundColor: GREEN, color: '#F6F4ED' }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = LIGHT)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = GREEN)}
              >
                <Download size={16} /> Unduh FormUp.apk
              </a>
            </Magnetic>
            <Link to="/register"
              className="px-7 py-3.5 text-sm font-semibold rounded-full border transition-all"
              style={{ borderColor: '#F6F4ED33', color: '#F6F4EDCC' }}
              onMouseEnter={(e) => { e.currentTarget.style.borderColor = '#F6F4ED80'; e.currentTarget.style.backgroundColor = '#F6F4ED0D'; }}
              onMouseLeave={(e) => { e.currentTarget.style.borderColor = '#F6F4ED33'; e.currentTarget.style.backgroundColor = 'transparent'; }}
            >
              Daftar gratis <ArrowUpRight size={15} />
            </Link>
          </div>
        </div>

        {/* trio 3D (desktop saja, agar muat satu layar) */}
        <div id="trio" className="hidden md:flex items-end justify-center gap-6 lg:gap-8 px-6 shrink-0"
          style={{ perspective: '1400px' }}>
          <div className="trio-left w-28 lg:w-32 shrink-0 rounded-[28px] border border-white/15 p-2 shadow-2xl"
            style={{ background: 'linear-gradient(180deg, #2E3B33 0%, #131C17 100%)' }}>
            <div className="w-full h-full rounded-[22px] p-3 flex flex-col justify-center gap-2 text-left aspect-[9/19]"
              style={{ backgroundColor: '#0B1210' }}>
              <div className="w-8 h-1.5 rounded-full mx-auto" style={{ backgroundColor: '#5BC98C66' }} />
              <div className="text-[9px] font-bold text-stone-400">Analitik respon</div>
              <div className="w-full h-9 rounded-lg flex items-center justify-center text-[9px] font-bold"
                style={{ backgroundColor: `${GREEN}26`, border: `1px solid ${GREEN}59`, color: LIGHT }}>
                98% selesai
              </div>
              <div className="w-full h-1 rounded-full" style={{ backgroundColor: 'rgba(255,255,255,0.1)' }} />
            </div>
          </div>

          <div className="trio-center w-36 lg:w-44 shrink-0 rounded-[34px] border border-white/25 p-2.5"
            style={{ background: 'linear-gradient(180deg, #38473E 0%, #131C17 100%)', boxShadow: '0 30px 70px rgba(0,0,0,0.5)' }}>
            <div className="w-full h-full rounded-[26px] p-4 flex flex-col justify-between text-left aspect-[9/19]"
              style={{ backgroundColor: '#0B1210' }}>
              <div className="w-16 h-3 rounded-full mx-auto" style={{ backgroundColor: '#16211B' }} />
              <div className="space-y-2">
                <div className="text-xs font-bold text-white">FormUp Mobile</div>
                <div className="p-2 rounded-lg text-[10px] font-semibold"
                  style={{ backgroundColor: `${GREEN}26`, border: `1px solid ${GREEN}59`, color: LIGHT }}>
                  Sinkronisasi aktif
                </div>
              </div>
              <div className="w-full py-2.5 rounded-lg text-[10px] font-bold text-center text-white"
                style={{ backgroundColor: GREEN }}>
                Siap digunakan
              </div>
            </div>
          </div>

          <div className="trio-right w-28 lg:w-32 shrink-0 rounded-[28px] border border-white/15 p-2 shadow-2xl"
            style={{ background: 'linear-gradient(180deg, #2E3B33 0%, #131C17 100%)' }}>
            <div className="w-full h-full rounded-[22px] p-3 flex flex-col justify-center gap-2 text-left aspect-[9/19]"
              style={{ backgroundColor: '#0B1210' }}>
              <div className="w-8 h-1.5 rounded-full mx-auto" style={{ backgroundColor: '#5BC98C66' }} />
              <div className="text-[9px] font-bold text-stone-400">QR code</div>
              <div className="w-12 h-12 rounded-lg mx-auto flex items-center justify-center border border-white/10"
                style={{ backgroundColor: 'rgba(255,255,255,0.05)' }}>
                <QrCode size={20} style={{ color: LIGHT }} />
              </div>
              <div className="w-full h-1 rounded-full" style={{ backgroundColor: 'rgba(255,255,255,0.1)' }} />
            </div>
          </div>
        </div>

        {/* footer bar di dalam layar penuh */}
        <footer className="px-6 pt-5 pb-6 shrink-0" style={{ backgroundColor: DARK }}>
          <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4 text-sm"
            style={{ color: '#F6F4ED66', borderTop: '1px solid rgba(246,244,237,0.08)', paddingTop: '1.25rem' }}>
            <div className="flex items-center gap-2">
              <img src={logo} alt="FormUp" className="w-5 h-5 object-contain opacity-70" />
              <span className="font-bold text-[#F6F4EDCC]">FormUp</span>
              <span className="mx-1">·</span>
              <span>© {new Date().getFullYear()}</span>
            </div>
            <div className="flex items-center gap-7">
              <Link to="/login" className="hover:text-[#F6F4ED] transition-colors">Masuk</Link>
              <Link to="/register" className="hover:text-[#F6F4ED] transition-colors">Daftar</Link>
              <a href={APK_URL} target="_blank" rel="noopener noreferrer" className="hover:text-[#F6F4ED] transition-colors">Aplikasi Android</a>
            </div>
          </div>
        </footer>
      </section>

    </div>
  );
}
