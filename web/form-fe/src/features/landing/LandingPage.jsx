<<<<<<< HEAD
import { useState, useEffect, useRef, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
=======
import { useEffect, useMemo, useRef, useState, Suspense, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html, useTexture } from '@react-three/drei';
import * as THREE from 'three';
>>>>>>> origin/main
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from '@studio-freight/lenis';
import {
<<<<<<< HEAD
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
=======
  ArrowRight, Download, Menu, X, Check, FileText,
  Sparkles, Layers, ShieldCheck, QrCode, BarChart2,
  Copy, Smartphone, ChevronDown, CheckCircle2,
  Share2, Zap, Send, MousePointer2, Sliders, Eye,
  Cloud, Wind, Globe, Users, CheckCheck, Activity, Award
} from 'lucide-react';
import { isAuthenticated } from '../../services/apiService';

import logo from '../../assets/logo.png';
import skyImg from '../../assets/celestial sky.jpg';
import cloudsImg from '../../assets/awan.png';
import islandSingleImg from '../../assets/pulau mengambang individu.png';
import islandMultiImg from '../../assets/pulau mengambang banyak.png';

gsap.registerPlugin(ScrollTrigger);
>>>>>>> origin/main

const APK_URL = 'https://github.com/abayDahln/FormUp/releases/download/v1.0.0/formup-android.apk';
const EXE_URL = 'https://github.com/abayDahln/FormUp/releases/download/v1.0.0/formup-windows-installer.exe';

<<<<<<< HEAD
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
=======
/* ─────────────────────────────────────────────────────────────
   MOUSE TRACKING HOOK
───────────────────────────────────────────────────────────── */
function useMouseRef(enabled = true) {
  const mouse = useRef({ x: 0, y: 0 });

  useEffect(() => {
    if (!enabled) return undefined;

    const onMove = (event) => {
      mouse.current.x = (event.clientX / window.innerWidth - 0.5) * 2;
      mouse.current.y = (event.clientY / window.innerHeight - 0.5) * 2;
    };

    window.addEventListener('pointermove', onMove, { passive: true });
    return () => window.removeEventListener('pointermove', onMove);
  }, [enabled]);

  return mouse;
}

/* ─────────────────────────────────────────────────────────────
   3D CARD TILT HOOK
───────────────────────────────────────────────────────────── */
function useCardTilt() {
  const cardRef = useRef(null);

  const handleMouseMove = useCallback((e) => {
    const card = cardRef.current;
    if (!card) return;
    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const rotateX = ((y - centerY) / centerY) * -6;
    const rotateY = ((x - centerX) / centerX) * 6;

    card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.01, 1.01, 1.01)`;
  }, []);

  const handleMouseLeave = useCallback(() => {
    const card = cardRef.current;
    if (!card) return;
    card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
  }, []);

  return { cardRef, handleMouseMove, handleMouseLeave };
}

/* ─────────────────────────────────────────────────────────────
   HD PHOTOREALISTIC 3D TITANIUM SMARTPHONE
   (Prominent casing, thick metallic frame, physical buttons, screen neatly recessed)
───────────────────────────────────────────────────────────── */
function RealisticPhoneMesh() {
  // Generous phone dimensions: 2.58 x 5.14 so the casing is undeniably prominent
  const phoneGeom = useMemo(() => {
    const shape = new THREE.Shape();
    const w = 2.58, h = 5.14, r = 0.46;
    const x = -w / 2, y = -h / 2;
    shape.moveTo(x + r, y);
    shape.lineTo(x + w - r, y);
    shape.absarc(x + w - r, y + r, r, -Math.PI / 2, 0, false);
    shape.lineTo(x + w, y + h - r);
    shape.absarc(x + w - r, y + h - r, r, 0, Math.PI / 2, false);
    shape.lineTo(x + r, y + h);
    shape.absarc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false);
    shape.lineTo(x, y + r);
    shape.absarc(x + r, y + r, r, Math.PI, Math.PI * 1.5, false);

    const geo = new THREE.ExtrudeGeometry(shape, {
      depth: 0.28,
      bevelEnabled: true,
      bevelSegments: 6,
      steps: 1,
      bevelSize: 0.048,
      bevelThickness: 0.048,
    });
    geo.center();
    return geo;
  }, []);

  // Polished chamfer outer rim that catches golden light reflections
  const chamferRingGeom = useMemo(() => {
    const shape = new THREE.Shape();
    const w = 2.58, h = 5.14, r = 0.46;
    const x = -w / 2, y = -h / 2;
    shape.moveTo(x + r, y);
    shape.lineTo(x + w - r, y);
    shape.absarc(x + w - r, y + r, r, -Math.PI / 2, 0, false);
    shape.lineTo(x + w, y + h - r);
    shape.absarc(x + w - r, y + h - r, r, 0, Math.PI / 2, false);
    shape.lineTo(x + r, y + h);
    shape.absarc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false);
    shape.lineTo(x, y + r);
    shape.absarc(x + r, y + r, r, Math.PI, Math.PI * 1.5, false);

    const geo = new THREE.ExtrudeGeometry(shape, {
      depth: 0.02,
      bevelEnabled: true,
      bevelSegments: 4,
      steps: 1,
      bevelSize: 0.052,
      bevelThickness: 0.02,
    });
    geo.center();
    return geo;
  }, []);

  // Camera Bump Plate on Back
  const cameraPlateGeom = useMemo(() => {
    const shape = new THREE.Shape();
    const w = 1.02, h = 1.02, r = 0.26;
    const x = -w / 2, y = -h / 2;
    shape.moveTo(x + r, y);
    shape.lineTo(x + w - r, y);
    shape.absarc(x + w - r, y + r, r, -Math.PI / 2, 0, false);
    shape.lineTo(x + w, y + h - r);
    shape.absarc(x + w - r, y + h - r, r, 0, Math.PI / 2, false);
    shape.lineTo(x + r, y + h);
    shape.absarc(x + r, y + h - r, r, Math.PI / 2, Math.PI, false);
    shape.lineTo(x, y + r);
    shape.absarc(x + r, y + r, r, Math.PI, Math.PI * 1.5, false);

    return new THREE.ExtrudeGeometry(shape, {
      depth: 0.055,
      bevelEnabled: true,
      bevelSegments: 3,
      bevelSize: 0.02,
      bevelThickness: 0.02,
    });
  }, []);

  return (
    <group>
      {/* ── 1. Phone Body: Brushed Natural Titanium Chassis ── */}
      <mesh geometry={phoneGeom} castShadow receiveShadow>
        <meshStandardMaterial
          color="#383E4A"
          metalness={0.96}
          roughness={0.18}
          envMapIntensity={2.4}
        />
      </mesh>

      {/* ── 2. Polished Outer Chamfer Ring ── */}
      <mesh geometry={chamferRingGeom} position={[0, 0, 0.005]}>
        <meshStandardMaterial
          color="#BAC8D6"
          metalness={0.98}
          roughness={0.06}
          envMapIntensity={3.2}
        />
      </mesh>

      {/* ── 3. Physical Hardware Buttons on Titanium Frame ── */}
      {/* Right Side: Power / Lock Button */}
      <mesh position={[1.35, 0.50, 0]}>
        <boxGeometry args={[0.05, 0.70, 0.09]} />
        <meshStandardMaterial color="#B8C4D2" metalness={0.98} roughness={0.10} />
      </mesh>

      {/* Left Side: Action Button */}
      <mesh position={[-1.35, 1.25, 0]}>
        <boxGeometry args={[0.05, 0.30, 0.09]} />
        <meshStandardMaterial color="#B8C4D2" metalness={0.98} roughness={0.10} />
      </mesh>

      {/* Left Side: Volume Up Button */}
      <mesh position={[-1.35, 0.62, 0]}>
        <boxGeometry args={[0.05, 0.50, 0.09]} />
        <meshStandardMaterial color="#B8C4D2" metalness={0.98} roughness={0.10} />
      </mesh>

      {/* Left Side: Volume Down Button */}
      <mesh position={[-1.35, -0.05, 0]}>
        <boxGeometry args={[0.05, 0.50, 0.09]} />
        <meshStandardMaterial color="#B8C4D2" metalness={0.98} roughness={0.10} />
      </mesh>

      {/* ── 4. Antenna Inset Lines (Chassis Details) ── */}
      <mesh position={[1.35, 1.90, 0]}>
        <boxGeometry args={[0.052, 0.035, 0.28]} />
        <meshBasicMaterial color="#1C2128" />
      </mesh>
      <mesh position={[-1.35, 1.90, 0]}>
        <boxGeometry args={[0.052, 0.035, 0.28]} />
        <meshBasicMaterial color="#1C2128" />
      </mesh>
      <mesh position={[1.35, -1.90, 0]}>
        <boxGeometry args={[0.052, 0.035, 0.28]} />
        <meshBasicMaterial color="#1C2128" />
      </mesh>
      <mesh position={[-1.35, -1.90, 0]}>
        <boxGeometry args={[0.052, 0.035, 0.28]} />
        <meshBasicMaterial color="#1C2128" />
      </mesh>

      {/* ── 5. Front Screen Bezel (Ceramic Shield Jet Black Framing) ── */}
      <mesh position={[0, 0, 0.130]}>
        <planeGeometry args={[2.28, 4.82]} />
        <meshBasicMaterial color="#0A0D12" />
      </mesh>

      {/* Top Receiver Earpiece Slit */}
      <mesh position={[0, 2.36, 0.142]}>
        <boxGeometry args={[0.40, 0.025, 0.015]} />
        <meshBasicMaterial color="#05070A" />
      </mesh>

      {/* Dynamic Island Pill (Hardware Sensor Housing) */}
      <mesh position={[0, 2.06, 0.144]}>
        <capsuleGeometry args={[0.08, 0.32, 8, 16]} />
        <meshBasicMaterial color="#000000" />
      </mesh>

      {/* Front Camera Sensor Glint */}
      <mesh position={[0.11, 2.06, 0.145]}>
        <circleGeometry args={[0.028, 16]} />
        <meshBasicMaterial color="#1A283C" />
      </mesh>

      {/* ── 6. Back Glass Panel & Sapphire Triple Camera ── */}
      <mesh position={[0, 0, -0.130]} rotation={[0, Math.PI, 0]}>
        <planeGeometry args={[2.28, 4.82]} />
        <meshPhysicalMaterial
          color="#242B36"
          roughness={0.28}
          metalness={0.2}
          clearcoat={0.95}
          clearcoatRoughness={0.1}
          envMapIntensity={1.8}
        />
      </mesh>

      {/* Sapphire Camera Island (Back Left) */}
      <mesh geometry={cameraPlateGeom} position={[-0.62, 1.76, -0.165]} rotation={[0, Math.PI, 0]}>
        <meshPhysicalMaterial
          color="#323C4B"
          roughness={0.18}
          metalness={0.8}
          clearcoat={1.0}
          envMapIntensity={2.6}
        />
      </mesh>

      {/* Camera Lens 1 (Top) */}
      <mesh position={[-0.62, 2.00, -0.20]} rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.17, 0.17, 0.05, 24]} />
        <meshStandardMaterial color="#B0BAC6" metalness={0.96} roughness={0.12} />
      </mesh>
      <mesh position={[-0.62, 2.00, -0.228]} rotation={[0, Math.PI, 0]}>
        <circleGeometry args={[0.15, 24]} />
        <meshBasicMaterial color="#080C12" />
      </mesh>

      {/* Camera Lens 2 (Bottom) */}
      <mesh position={[-0.62, 1.52, -0.20]} rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.17, 0.17, 0.05, 24]} />
        <meshStandardMaterial color="#B0BAC6" metalness={0.96} roughness={0.12} />
      </mesh>
      <mesh position={[-0.62, 1.52, -0.228]} rotation={[0, Math.PI, 0]}>
        <circleGeometry args={[0.15, 24]} />
        <meshBasicMaterial color="#080C12" />
      </mesh>

      {/* Camera Lens 3 (Right) */}
      <mesh position={[-0.30, 1.76, -0.20]} rotation={[Math.PI / 2, 0, 0]}>
        <cylinderGeometry args={[0.17, 0.17, 0.05, 24]} />
        <meshStandardMaterial color="#B0BAC6" metalness={0.96} roughness={0.12} />
      </mesh>
      <mesh position={[-0.30, 1.76, -0.228]} rotation={[0, Math.PI, 0]}>
        <circleGeometry args={[0.15, 24]} />
        <meshBasicMaterial color="#080C12" />
      </mesh>

      {/* True Tone Dual Flash & LiDAR Dot */}
      <mesh position={[-0.88, 1.76, -0.19]}>
        <circleGeometry args={[0.065, 16]} />
        <meshBasicMaterial color="#FFF1D6" />
      </mesh>
      <mesh position={[-0.88, 1.52, -0.19]}>
        <circleGeometry args={[0.045, 16]} />
        <meshBasicMaterial color="#10151E" />
      </mesh>
    </group>
  );
}

/* ─────────────────────────────────────────────────────────────
   DYNAMIC INTERACTIVE UI SCREEN INSIDE THE 3D PHONE
   (Comfortable compact size: 260 x 540, neatly framed by casing)
───────────────────────────────────────────────────────────── */
function PhoneScreen({ sceneIndex }) {
  const [selectedOption, setSelectedOption] = useState('B');
  const [showToast, setShowToast] = useState(false);

  const handleSelect = (key) => {
    setSelectedOption(key);
    setShowToast(true);
    setTimeout(() => setShowToast(false), 1800);
  };

  return (
    <div
      style={{ width: 260, height: 540, background: '#FFFFFF' }}
      className="rounded-[32px] overflow-hidden flex flex-col font-['Manrope',sans-serif] text-slate-900 select-none shadow-2xl relative"
    >
      {/* Top Status Bar */}
      <div className="pt-2 px-4 pb-1.5 flex items-center justify-between text-[10px] font-extrabold text-slate-800 shrink-0 bg-slate-50/90 border-b border-slate-100">
        <span>9:41</span>
        <div className="w-18 h-4 rounded-full bg-black/90 flex items-center justify-between px-2">
          <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span className="text-[7.5px] font-mono text-white/90 font-bold">FormUp</span>
          <div className="w-1.5 h-1.5 rounded-full bg-white/20" />
        </div>
        <div className="flex items-center gap-1 text-slate-700">
          <span className="text-[8.5px] font-black">5G</span>
          <div className="w-4 h-2 rounded-xs border border-slate-700 p-0.5 flex items-center">
            <div className="w-1.5 h-full bg-slate-700 rounded-xs" />
          </div>
        </div>
      </div>

      {/* Sub-Header */}
      <div className="px-3.5 py-2 bg-white border-b border-slate-100 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-2">
          <div className="w-5.5 h-5.5 rounded-lg bg-[#18232D] text-white flex items-center justify-center font-black text-[10px] shadow-xs">
            F
          </div>
          <div>
            <h4 className="text-[10px] font-black text-slate-900 leading-tight">Ujian Harian Fisika</h4>
            <p className="text-[8.5px] text-slate-400 font-medium">Kelas X-IPA · 15 Menit</p>
          </div>
        </div>
        <span className="text-[8.5px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
          Aktif
        </span>
      </div>

      {/* Dynamic Content Switching based on Skyfall Milestone */}
      <div className="flex-1 p-3.5 overflow-hidden flex flex-col justify-between bg-[#FBFBFA]">
        {sceneIndex === 0 && (
          <div className="flex-1 flex flex-col justify-center items-center text-center p-2">
            <div className="w-12 h-12 rounded-2xl bg-white border border-slate-200 shadow-sm flex items-center justify-center mb-2.5 text-[#18232D]">
              <FileText size={22} />
            </div>
            <h5 className="text-[11px] font-black text-slate-900 mb-1">Formulir Tanpa Hambatan</h5>
            <p className="text-[9px] text-slate-500 leading-relaxed max-w-[180px]">
              Tampilan bersih, cepat dibuka, dan nyaman diisi dari gawai apapun.
            </p>
            <div className="mt-4 w-full space-y-1.5">
              <div className="h-2 bg-slate-200 rounded-full w-5/6 mx-auto animate-pulse" />
              <div className="h-2 bg-slate-200 rounded-full w-3/5 mx-auto animate-pulse delay-75" />
            </div>
          </div>
        )}

        {sceneIndex === 1 && (
          <div className="space-y-2.5">
            <div className="p-2.5 rounded-xl bg-white border border-slate-200/80 shadow-xs">
              <span className="text-[8px] font-extrabold text-amber-600 uppercase tracking-wider block mb-0.5">
                Pertanyaan 1 dari 10
              </span>
              <p className="text-[10px] font-bold text-slate-900 leading-snug">
                Besaran turunan berikut yang memiliki satuan Newton meter adalah?
              </p>
            </div>
            <div className="space-y-1.5">
              {[
                { key: 'A', text: 'Usaha dan Energi' },
                { key: 'B', text: 'Momen Gaya (Torsi)' },
                { key: 'C', text: 'Daya Listrik' },
                { key: 'D', text: 'Tekanan Hidrostatis' },
              ].map((opt) => (
                <button
                  key={opt.key}
                  type="button"
                  onClick={() => handleSelect(opt.key)}
                  className={`w-full p-2 rounded-lg border text-left text-[10px] font-bold flex items-center justify-between transition-all cursor-pointer ${
                    selectedOption === opt.key
                      ? 'bg-[#18232D] text-white border-[#18232D] shadow-sm'
                      : 'bg-white text-slate-700 border-slate-200 hover:border-slate-300'
                  }`}
                >
                  <span className="flex items-center gap-1.5">
                    <span
                      className={`w-4 h-4 rounded-full flex items-center justify-center text-[8px] font-black ${
                        selectedOption === opt.key ? 'bg-white text-[#18232D]' : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {opt.key}
                    </span>
                    <span>{opt.text}</span>
                  </span>
                  {selectedOption === opt.key && <Check size={11} className="text-white" />}
                </button>
              ))}
            </div>
          </div>
        )}

        {sceneIndex === 2 && (
          <div className="space-y-2.5">
            <div className="p-2.5 rounded-xl bg-white border border-slate-200/80 shadow-xs">
              <span className="text-[8px] font-extrabold text-teal-600 uppercase tracking-wider block mb-0.5">
                Input Interaktif
              </span>
              <p className="text-[10px] font-bold text-slate-900 leading-snug">
                Jelaskan hubungan massa dan percepatan menurut Hukum II Newton:
              </p>
            </div>
            <div className="p-2.5 rounded-xl bg-white border-2 border-dashed border-teal-500/40 text-[9px] text-slate-700 space-y-1.5">
              <p className="italic text-slate-600 font-medium leading-relaxed">
                &ldquo;Percepatan berbanding lurus dengan resultan gaya dan berbanding terbalik dengan massa benda (F = m · a).&rdquo;
              </p>
              <div className="flex items-center justify-between pt-1 border-t border-slate-100 text-[8px] font-bold text-teal-700">
                <span>✓ Tersimpan</span>
                <span>42 kata</span>
              </div>
            </div>
          </div>
        )}

        {sceneIndex === 3 && (
          <div className="space-y-2.5">
            <div className="p-3 rounded-xl bg-white border border-slate-200 text-center shadow-xs">
              <div className="w-9 h-9 rounded-full bg-emerald-50 text-emerald-600 mx-auto flex items-center justify-center mb-1.5">
                <CheckCircle2 size={18} />
              </div>
              <h5 className="text-[10px] font-black text-slate-900 mb-0.5">10 Soal Berhasil Dijawab!</h5>
              <p className="text-[8.5px] text-slate-500">Semua jawaban tersimpan aman.</p>
              <div className="mt-2.5 p-2 rounded-lg bg-slate-50 border border-slate-100 text-left">
                <div className="flex justify-between text-[8px] font-bold text-slate-600 mb-1">
                  <span>Waktu Tersisa:</span>
                  <span className="font-mono text-slate-900">08:45</span>
                </div>
                <div className="w-full bg-slate-200 h-1.5 rounded-full overflow-hidden">
                  <div className="bg-emerald-500 h-full w-4/5" />
                </div>
              </div>
            </div>
          </div>
        )}

        {sceneIndex >= 4 && (
          <div className="space-y-2.5">
            <div className="p-2.5 rounded-xl bg-[#18232D] text-white text-center shadow-md">
              <span className="text-[8px] font-black uppercase tracking-wider text-amber-300 block mb-0.5">
                HASIL INSTAN
              </span>
              <div className="text-xl font-black mb-0.5">95 / 100</div>
              <p className="text-[8.5px] text-white/70">Nilai terhitung otomatis</p>
            </div>
            <div className="space-y-1.5">
              <div className="p-2 rounded-lg bg-white border border-slate-200 flex items-center justify-between text-[10px]">
                <span className="font-bold text-slate-600">Peringkat Kelas</span>
                <span className="font-black text-[#18232D]">#1 dari 36</span>
              </div>
              <div className="p-2 rounded-lg bg-white border border-slate-200 flex items-center justify-between text-[10px]">
                <span className="font-bold text-slate-600">Durasi Pengerjaan</span>
                <span className="font-mono font-bold text-slate-800">06 m 15 dtk</span>
              </div>
            </div>
          </div>
        )}

        {/* Action Button at Screen Bottom */}
        <div className="pt-2 border-t border-slate-100">
          <button
            type="button"
            className="w-full py-2 rounded-lg bg-[#18232D] text-white text-[10px] font-black uppercase tracking-wider shadow-md hover:bg-[#25323e] transition-all flex items-center justify-center gap-1.5"
          >
            <span>{sceneIndex >= 3 ? 'Kirim Jawaban' : 'Lanjut Soal Berikutnya'}</span>
            <ArrowRight size={10} />
          </button>
        </div>

        {/* Feedback Bubble Toast */}
        {showToast && (
          <div className="absolute bottom-14 left-1/2 -translate-x-1/2 px-3 py-1 rounded-full bg-slate-900/90 text-white text-[8px] font-bold shadow-xl animate-bounce">
            Jawaban disimpan!
          </div>
        )}
      </div>
>>>>>>> origin/main
    </div>
  );
}

<<<<<<< HEAD
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
              {/* Tombol download APK */}
              <Magnetic className="hero-cta w-full sm:w-auto">
                <a href={APK_URL} download="formup-android.apk" target="_blank" rel="noopener noreferrer"
                  className="w-full sm:w-auto px-7 py-3.5 text-[#F6F4ED] text-sm font-semibold rounded-full transition-colors duration-300 flex items-center justify-center gap-2"
                  style={{ backgroundColor: GREEN }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = GREEN_DEEP)}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = GREEN)}
                >
                  <Smartphone size={16} /> Unduh APK (Android) <ArrowUpRight size={15} />
                </a>
              </Magnetic>
              {/* Tombol download Windows installer */}
              <Magnetic className="hero-cta w-full sm:w-auto">
                <a href={EXE_URL} download="formup-windows-installer.exe" target="_blank" rel="noopener noreferrer"
                  className="w-full sm:w-auto px-7 py-3.5 text-[#F6F4ED] text-sm font-semibold rounded-full transition-colors duration-300 flex items-center justify-center gap-2"
                  style={{ backgroundColor: INK }}
                  onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = DARK)}
                  onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = INK)}
                >
                  <Download size={16} /> Unduh Installer (Windows) <ArrowUpRight size={15} />
                </a>
              </Magnetic>
              {/* Tombol buka di browser */}
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
=======
/* ─────────────────────────────────────────────────────────────
   PHONE 3D RIG (Spacious Titanium Chassis framing Screen)
───────────────────────────────────────────────────────────── */
function PhoneRig({ progressRef, sceneIndex }) {
  const group = useRef();
  const mouse = useMouseRef();
  const { viewport } = useThree();

  const isDesktop = viewport.width > 8.5;
  const baseRightX = isDesktop ? 2.85 : 0.0;

  const smooth = useRef({ x: baseRightX, y: 0.15, z: 0, scale: 1.05, rx: 0.05, ry: -0.30 });

  useFrame(() => {
    if (!group.current) return;
    const p = progressRef.current;

    let targetX = baseRightX;
    let targetY = 0.15;
    let targetZ = 0.0;
    let targetScale = isDesktop ? 1.05 : 0.90;
    let targetRX = 0.06;
    let targetRY = -0.30;

    // Narrative Stages (0.0 -> 0.65) & Atmospheric Transition (0.65 -> 1.0)
    if (p < 0.20) {
      const t = p / 0.20;
      targetX = baseRightX + THREE.MathUtils.lerp(-0.10, 0, t);
      targetY = THREE.MathUtils.lerp(0.50, 0.20, t);
      targetScale = THREE.MathUtils.lerp(1.02, 1.05, t);
      targetRY = THREE.MathUtils.lerp(-0.36, -0.28, t);
      targetRX = THREE.MathUtils.lerp(0.10, 0.06, t);
    } else if (p < 0.45) {
      const t = (p - 0.20) / 0.25;
      targetX = baseRightX + THREE.MathUtils.lerp(0, 0.06, t);
      targetY = THREE.MathUtils.lerp(0.20, 0.02, t);
      targetScale = THREE.MathUtils.lerp(1.05, 1.08, t);
      targetRY = THREE.MathUtils.lerp(-0.28, -0.22, t);
    } else if (p < 0.65) {
      const t = (p - 0.45) / 0.20;
      targetX = baseRightX + THREE.MathUtils.lerp(0.06, -0.04, t);
      targetY = THREE.MathUtils.lerp(0.02, -0.06, t);
      targetScale = 1.08;
      targetRY = THREE.MathUtils.lerp(-0.22, -0.16, t);
    } else if (p < 0.82) {
      // Transition Stage 1: Aerodynamic forward dive and begin shrinking
      const t = (p - 0.65) / 0.17;
      targetX = baseRightX + THREE.MathUtils.lerp(-0.04, 0.05, t);
      targetY = THREE.MathUtils.lerp(-0.06, -0.30, t);
      targetZ = THREE.MathUtils.lerp(0, -3.0, t);
      targetScale = THREE.MathUtils.lerp(1.08, 0.55, t); // shrinks down to 0.55
      targetRY = THREE.MathUtils.lerp(-0.16, -0.04, t);
      targetRX = THREE.MathUtils.lerp(0.06, 0.25, t); // tilts forward into dive
    } else {
      // Transition Stage 2: Plunges and shrinks into the distance until completely gone!
      const t = Math.min(1, (p - 0.82) / 0.12);
      targetX = baseRightX + THREE.MathUtils.lerp(0.05, 0.20, t);
      targetY = THREE.MathUtils.lerp(-0.30, -2.5, t);
      targetZ = THREE.MathUtils.lerp(-3.0, -12.0, t);
      targetScale = THREE.MathUtils.lerp(0.55, 0.0, t); // shrinks completely to 0!
      targetRY = THREE.MathUtils.lerp(-0.04, 0.02, t);
      targetRX = THREE.MathUtils.lerp(0.25, 0.40, t);
    }

    // Aerodynamic breathing float & wind vibration during transition
    const time = performance.now() * 0.0014;
    const floatY = Math.sin(time) * 0.035;
    const floatRotZ = Math.cos(time * 0.8) * 0.015;

    // Atmospheric turbulence during transition (p > 0.65)
    let turbulence = 0;
    if (p > 0.65) {
      const shakeFactor = Math.min(1, (p - 0.65) / 0.25);
      turbulence = (Math.sin(time * 35) * 0.012 + Math.cos(time * 48) * 0.008) * shakeFactor;
    }

    // Responsive mouse tilt
    const mouseRX = mouse.current.y * 0.07;
    const mouseRY = mouse.current.x * 0.09;

    smooth.current.x += (targetX + turbulence - smooth.current.x) * 0.08;
    smooth.current.y += (targetY + floatY + turbulence - smooth.current.y) * 0.08;
    smooth.current.z += (targetZ - smooth.current.z) * 0.08;
    smooth.current.scale += (targetScale - smooth.current.scale) * 0.08;
    smooth.current.rx += (targetRX + mouseRX - smooth.current.rx) * 0.08;
    smooth.current.ry += (targetRY + mouseRY - smooth.current.ry) * 0.08;

    group.current.position.set(smooth.current.x, smooth.current.y, smooth.current.z);
    const clampedScale = Math.max(0, smooth.current.scale);
    group.current.scale.setScalar(clampedScale);
    group.current.rotation.set(smooth.current.rx, smooth.current.ry, floatRotZ);
    group.current.visible = clampedScale > 0.01;
  });

  return (
    <group ref={group} position={[baseRightX, 0.15, 0]} scale={1.05}>
      <RealisticPhoneMesh />
      {/* Screen fits inside casing, fading and shrinking with phone until it vanishes */}
      <Html
        transform
        position={[0, -0.04, 0.144]}
        distanceFactor={3.55}
        style={{
          pointerEvents: smooth.current.scale > 0.4 ? 'auto' : 'none',
          opacity: Math.max(0, Math.min(1, (smooth.current.scale - 0.05) * 2.0)),
        }}
      >
        <PhoneScreen sceneIndex={sceneIndex} />
      </Html>
    </group>
  );
}

/* ─────────────────────────────────────────────────────────────
   CONTINUOUS SKY TIER (Clouds & Islands Floating Upwards)
───────────────────────────────────────────────────────────── */
function ContinuousSkyLayer({
  texture,
  basePos,
  scale,
  opacity = 1,
  speed = 1.0,
  progressRef,
  drift = 0,
  fadeRange = null,
}) {
  const ref = useRef();
  const mouse = useMouseRef();
  const time = useRef(Math.random() * 10);

  useFrame((_, delta) => {
    if (!ref.current) return;
    time.current += delta;
    const p = progressRef.current;

    const ambientX = Math.sin(time.current * 0.15 + basePos[2]) * drift;
    const ambientY = Math.cos(time.current * 0.12 + basePos[2]) * drift * 0.5;

    // Smooth upward speed
    const upwardOffset = p * speed * 6.5;

    const tx = basePos[0] - mouse.current.x * 0.35 + ambientX;
    const ty = basePos[1] - mouse.current.y * 0.20 + upwardOffset + ambientY;

    ref.current.position.x += (tx - ref.current.position.x) * 0.035;
    ref.current.position.y += (ty - ref.current.position.y) * 0.035;

    if (fadeRange) {
      const [start, peak] = fadeRange;
      const factor = Math.max(0, Math.min(1, (p - start) / (peak - start)));
      ref.current.material.opacity = opacity * factor;
      ref.current.visible = factor > 0.005;
    }
  });

  return (
    <mesh ref={ref} position={basePos} scale={[scale, scale * 0.58, 1]}>
      <planeGeometry args={[1, 1]} />
      <meshBasicMaterial
        map={texture}
        transparent
        opacity={fadeRange ? 0 : opacity}
        depthWrite={false}
      />
    </mesh>
  );
}

/* ─────────────────────────────────────────────────────────────
   INTENSE VERTICAL WIND STREAKS (Rushing upward motion lines)
───────────────────────────────────────────────────────────── */
function WindStreaks({ progressRef }) {
  const lineCount = 110;
  const linesRef = useRef();

  const [positions, speeds, lengths] = useMemo(() => {
    const pos = new Float32Array(lineCount * 6);
    const spd = new Float32Array(lineCount);
    const len = new Float32Array(lineCount);

    for (let i = 0; i < lineCount; i++) {
      const x = (Math.random() - 0.5) * 22;
      const y = (Math.random() - 0.5) * 24;
      const z = -0.5 - Math.random() * 9;
      const l = 1.4 + Math.random() * 3.2;

      pos[i * 6] = x;
      pos[i * 6 + 1] = y;
      pos[i * 6 + 2] = z;

      pos[i * 6 + 3] = x;
      pos[i * 6 + 4] = y + l;
      pos[i * 6 + 5] = z;

      spd[i] = 4.5 + Math.random() * 8.0;
      len[i] = l;
    }
    return [pos, spd, len];
  }, [lineCount]);

  useFrame((_, delta) => {
    if (!linesRef.current) return;
    const p = progressRef.current;

    // Wind streaks ONLY appear when transition begins (p >= 0.58)
    let opacity = 0;
    if (p >= 0.58) {
      opacity = Math.min(0.85, ((p - 0.58) / 0.12) * 0.85);
    }
    linesRef.current.material.opacity = opacity;
    linesRef.current.visible = opacity > 0.005;

    if (opacity <= 0.005) return; // Skip updating positions when invisible!

    const pos = linesRef.current.geometry.attributes.position.array;
    const transitionFactor = Math.max(0, (p - 0.58) / 0.42);
    const speedMult = 2.0 + Math.pow(transitionFactor, 2.0) * 32.0;

    for (let i = 0; i < lineCount; i++) {
      const dy = speeds[i] * delta * speedMult;
      pos[i * 6 + 1] += dy;
      pos[i * 6 + 4] += dy;

      if (pos[i * 6 + 1] > 14) {
        const newX = (Math.random() - 0.5) * 22;
        const newY = -14 - Math.random() * 4;
        const l = lengths[i];
        pos[i * 6] = newX;
        pos[i * 6 + 1] = newY;
        pos[i * 6 + 3] = newX;
        pos[i * 6 + 4] = newY + l;
      }
    }
    linesRef.current.geometry.attributes.position.needsUpdate = true;
  });

  return (
    <lineSegments ref={linesRef} visible={false}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <lineBasicMaterial
        color="#FFF6E0"
        transparent
        opacity={0}
        blending={THREE.AdditiveBlending}
        depthWrite={false}
      />
    </lineSegments>
  );
}

/* ─────────────────────────────────────────────────────────────
   WIND PARTICLES (350+ Upward Streaming Celestial Particles)
───────────────────────────────────────────────────────────── */
function WindParticles({ progressRef }) {
  const count = 360;
  const pointsRef = useRef();

  const [positions, speeds] = useMemo(() => {
    const pos = new Float32Array(count * 3);
    const spd = new Float32Array(count);
    for (let i = 0; i < count; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 28;
      pos[i * 3 + 1] = (Math.random() - 0.5) * 22;
      pos[i * 3 + 2] = -0.5 - Math.random() * 11;
      spd[i] = 2.5 + Math.random() * 5.0;
    }
    return [pos, spd];
  }, [count]);

  useFrame((_, delta) => {
    if (!pointsRef.current) return;
    const p = progressRef.current;

    // Wind particles ONLY appear when transition begins (p >= 0.58)
    let opacity = 0;
    if (p >= 0.58) {
      opacity = Math.min(0.85, ((p - 0.58) / 0.12) * 0.85);
    }
    pointsRef.current.material.opacity = opacity;
    pointsRef.current.visible = opacity > 0.005;

    if (opacity <= 0.005) return;

    const pos = pointsRef.current.geometry.attributes.position.array;
    const transitionFactor = Math.max(0, (p - 0.58) / 0.42);
    const speedMult = 2.0 + Math.pow(transitionFactor, 2.0) * 26.0;

    for (let i = 0; i < count; i++) {
      pos[i * 3 + 1] += speeds[i] * delta * speedMult;
      if (pos[i * 3 + 1] > 14) {
        pos[i * 3 + 1] = -14;
        pos[i * 3] = (Math.random() - 0.5) * 28;
      }
    }
    pointsRef.current.geometry.attributes.position.needsUpdate = true;
  });

  return (
    <points ref={pointsRef} visible={false}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial
        size={0.08}
        color="#FFF4DC"
        transparent
        opacity={0}
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  );
}

/* ─────────────────────────────────────────────────────────────
   FALLING SKY 3D SCENE (LONG TRANSITION & EXACT COLOR BLEND #E6EEF2)
───────────────────────────────────────────────────────────── */
function FallingSkyCanvas({ progressRef, sceneIndex }) {
  const { gl, scene } = useThree();
  const sky = useTexture(skyImg);
  const clouds = useTexture(cloudsImg);
  const islandSingle = useTexture(islandSingleImg);
  const islandMulti = useTexture(islandMultiImg);
  const skyMeshRef = useRef();
  const mouse = useMouseRef();

  useEffect(() => {
    sky.colorSpace = THREE.SRGBColorSpace;
    clouds.colorSpace = THREE.SRGBColorSpace;
    islandSingle.colorSpace = THREE.SRGBColorSpace;
    islandMulti.colorSpace = THREE.SRGBColorSpace;

    const pmrem = new THREE.PMREMGenerator(gl);
    pmrem.compileEquirectangularShader();
    const envRenderTarget = pmrem.fromEquirectangular(sky);
    scene.environment = envRenderTarget.texture;

    return () => {
      pmrem.dispose();
      envRenderTarget.dispose();
    };
  }, [gl, scene, sky, clouds, islandSingle, islandMulti]);

  useFrame(() => {
    const p = progressRef.current;

    // Pure Three.js transition into exact #E6EEF2 of #build section
    // Starts fading at p = 0.65, completely 100% #E6EEF2 at p >= 0.96
    const transitionT = Math.max(0, Math.min(1, (p - 0.65) / 0.31));

    const startFogColor = new THREE.Color('#DCE8F0');
    const endFogColor = new THREE.Color('#E6EEF2'); // Exact matching background!
    const fogColor = startFogColor.lerp(endFogColor, transitionT);

    // Thickening atmospheric fog during descent
    const baseDensity = THREE.MathUtils.lerp(0.010, 0.024, Math.sin(p * Math.PI));
    const fogDensity = baseDensity + transitionT * 0.055;
    scene.fog = new THREE.FogExp2(fogColor, fogDensity);
    gl.setClearColor(fogColor);

    // Sky quad texture fades out to reveal pure #E6EEF2 atmosphere
    if (skyMeshRef.current) {
      const ty = -mouse.current.y * 0.12 + (p * 2.5);
      skyMeshRef.current.position.y += (ty - skyMeshRef.current.position.y) * 0.02;
      skyMeshRef.current.material.opacity = Math.max(0, 1 - transitionT * 1.15);
    }
  });

  return (
    <>
      {/* Warm Golden Sunlight */}
      <ambientLight intensity={1.2} color={0xFFF7EC} />
      <hemisphereLight intensity={0.7} skyColor={0xDCEAF4} groundColor={0xEBD8BF} />
      <directionalLight position={[7, 10, 5]} intensity={2.6} color={0xFFE8C8} castShadow={false} />
      <directionalLight position={[-5, 4, -4]} intensity={0.5} color={0xD0E4F5} />

      {/* Sun Mesh in Top Right */}
      <mesh position={[8.5, 7.5, -15]}>
        <circleGeometry args={[2.8, 32]} />
        <meshBasicMaterial color="#FFF5D6" transparent opacity={0.65} blending={THREE.AdditiveBlending} depthWrite={false} />
      </mesh>

      {/* Deep Sky Quad that smoothly dissolves into #E6EEF2 */}
      <mesh ref={skyMeshRef} position={[0, 0, -24]} scale={[66, 42, 1]}>
        <planeGeometry args={[1, 1]} />
        <meshBasicMaterial map={sky} transparent opacity={1} toneMapped={false} />
      </mesh>

      {/* ── TIER 1: HIGH ALTITUDE (Pristine Celestial Sky & Floating Islands) ── */}
      <ContinuousSkyLayer
        texture={islandMulti}
        basePos={[-7.2, -2.4, -15]}
        scale={12.0}
        opacity={0.92}
        speed={0.65}
        progressRef={progressRef}
        drift={0.02}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[-5.8, -3.8, -14]}
        scale={12.0}
        opacity={0.14}
        speed={0.75}
        progressRef={progressRef}
        drift={0.03}
      />

      {/* ── TIER 2: MID ALTITUDE ISLAND SANCTUARY ── */}
      <ContinuousSkyLayer
        texture={islandSingle}
        basePos={[6.4, -2.8, -7.5]}
        scale={8.2}
        opacity={0.98}
        speed={1.35}
        progressRef={progressRef}
        drift={0.03}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[6.0, -4.2, -10]}
        scale={13.0}
        opacity={0.16}
        speed={1.25}
        progressRef={progressRef}
        drift={0.04}
      />

      {/* Procedural Realistic Phone */}
      <Suspense fallback={null}>
        <PhoneRig progressRef={progressRef} sceneIndex={sceneIndex} />
      </Suspense>

      {/* ── TIER 3: APPROACHING THE CLOUD DECK (Fades in dynamically p >= 0.48) ── */}
      <ContinuousSkyLayer
        texture={islandMulti}
        basePos={[-5.5, -4.8, -10]}
        scale={13}
        opacity={0.92}
        speed={1.65}
        progressRef={progressRef}
        drift={0.02}
      />
      <ContinuousSkyLayer
        texture={islandSingle}
        basePos={[-6.2, -4.2, -5.5]}
        scale={7.0}
        opacity={0.95}
        speed={1.85}
        progressRef={progressRef}
        drift={0.03}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[3.2, -5.2, -3.5]}
        scale={16}
        opacity={0.35}
        speed={2.1}
        progressRef={progressRef}
        drift={0.05}
        fadeRange={[0.48, 0.68]}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[-3.6, -5.6, -2.5]}
        scale={16}
        opacity={0.38}
        speed={2.3}
        progressRef={progressRef}
        drift={0.05}
        fadeRange={[0.48, 0.68]}
      />

      {/* ── TIER 4: TRANSITION CLOUD DECK (Soft plunge into clouds p >= 0.56 -> 0.95) ── */}
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[0, -5.0, -2.2]}
        scale={24}
        opacity={0.65}
        speed={3.2}
        progressRef={progressRef}
        drift={0.04}
        fadeRange={[0.56, 0.76]}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[-3.8, -6.0, -1.5]}
        scale={22}
        opacity={0.70}
        speed={3.5}
        progressRef={progressRef}
        drift={0.05}
        fadeRange={[0.58, 0.78]}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[3.8, -6.0, -1.5]}
        scale={22}
        opacity={0.70}
        speed={3.5}
        progressRef={progressRef}
        drift={0.05}
        fadeRange={[0.58, 0.78]}
      />
      <ContinuousSkyLayer
        texture={clouds}
        basePos={[0, -7.0, -1.0]}
        scale={26}
        opacity={0.75}
        speed={4.0}
        progressRef={progressRef}
        drift={0.03}
        fadeRange={[0.60, 0.82]}
      />

      {/* ── INTENSE WIND: 110 Upward Streaks + 360 Fast Particles ── */}
      <WindStreaks progressRef={progressRef} />
      <WindParticles progressRef={progressRef} />
    </>
  );
}

/* ─────────────────────────────────────────────────────────────
   5 STORY STAGES (Living Narrative Throughout Skyfall)
───────────────────────────────────────────────────────────── */
const STORY_STAGES = [
  {
    stage: '01',
    headline: 'Forms don’t have to be boring.',
    body: 'Create beautiful forms, collect responses, and turn ideas into action with effortless elegance.',
    caption: 'Nothing gets in the way. A clean slate before the noise begins.',
  },
  {
    stage: '02',
    headline: 'Give the question a direction.',
    body: 'Shape prompts in the order a real conversation would happen. Let each answer lead somewhere meaningful.',
    caption: 'Focus on what truly matters to learn. The path begins to take shape.',
  },
  {
    stage: '03',
    headline: 'Make the path feel obvious.',
    body: 'Clean modern inputs with natural rhythm. No rigid grids, sluggish loads, or bloated templates.',
    caption: 'Gliding past floating waterfalls. The form becomes uniquely yours.',
  },
  {
    stage: '04',
    headline: 'Ready? Send one link.',
    body: 'No explanation threads. No logins or scavenger hunts. Put the link wherever conversation lives.',
    caption: 'One universal link is enough. Zero friction for respondents.',
  },
  {
    stage: '05',
    headline: 'Now let the answers travel back.',
    body: 'Responses stream in real-time. Watch patterns form and turn signals into actionable decisions.',
    caption: 'The form has landed. Responses are live and ready to explore.',
  },
];

/* ─────────────────────────────────────────────────────────────
   INTERACTIVE STEP CARDS (Section 1: Shape the Flow)
───────────────────────────────────────────────────────────── */
function ShapeFlowSection() {
  const [activeStep, setActiveStep] = useState(0);
  const { cardRef, handleMouseMove, handleMouseLeave } = useCardTilt();

  const steps = [
    {
      num: '01',
      stage: 'OPEN',
      prompt: 'What brings you here today?',
      desc: 'Short text input',
      icon: MousePointer2,
      preview: {
        title: 'Pembuka yang Mengalir',
        tag: 'Text Input',
        question: 'Apa tujuan utama Anda bergabung di FormUp?',
        sampleInput: 'Mencari cara mudah mengumpulkan kuis kelas...',
      },
    },
    {
      num: '02',
      stage: 'FOLLOW',
      prompt: 'What would make it better?',
      desc: 'Single choice options',
      icon: Sliders,
      preview: {
        title: 'Opsi Cepat & Tepat',
        tag: 'Pilihan Ganda',
        question: 'Fitur mana yang paling sering Anda gunakan?',
        options: ['Rekap Nilai Otomatis', 'AI Quiz Generator', 'Export Excel / CSV'],
      },
    },
    {
      num: '03',
      stage: 'CLOSE',
      prompt: 'Anything else you would like to add?',
      desc: 'Long paragraph essay',
      icon: Eye,
      preview: {
        title: 'Masukan Mendalam',
        tag: 'Essay / Paragraf',
        question: 'Tuliskan catatan atau saran tambahan untuk kami:',
        sampleInput: 'Aplikasi sangat responsif dan UI-nya sangat memanjakan mata!',
      },
    },
  ];

  return (
    <section id="build" className="min-h-screen w-full flex flex-col py-20 px-6 sm:px-12 lg:px-16 bg-[#E6EEF2] border-b border-[#18232D]/10 relative">
      <div className="max-w-7xl mx-auto w-full grid lg:grid-cols-12 gap-16 items-center">
        
        {/* Left Column: Editorial & Interactive Selectors */}
        <div className="lg:col-span-6 scroll-reveal-item">
          <h2 className="text-4xl sm:text-6xl font-extrabold text-[#18232D] tracking-tight leading-[1.08] mb-8">
            Shape the flow.<br />
            <em className="font-normal italic">Keep it moving.</em>
          </h2>

          <p className="text-base sm:text-xl text-[#68747D] leading-relaxed mb-10">
            Arrange prompts in the natural cadence of a genuine conversation. Keep optional details out of the way. Let each question guide respondents seamlessly forward.
          </p>

          {/* Interactive Step Selectors with Animated Progress Indicator */}
          <div className="flex flex-col gap-4 relative">
            <div className="absolute left-7 top-6 bottom-6 w-0.5 bg-[#18232D]/15 -z-0" />

            {steps.map((step, idx) => {
              const isActive = activeStep === idx;
              return (
                <div
                  key={step.num}
                  onClick={() => setActiveStep(idx)}
                  className={`p-6 rounded-2xl border transition-all duration-300 flex items-center justify-between group cursor-pointer relative z-10 ${
                    isActive
                      ? 'bg-white border-[#18232D] shadow-xl translate-x-2'
                      : 'bg-white/70 border-[#18232D]/10 hover:bg-white hover:border-[#18232D]/25'
                  }`}
                >
                  <div className="flex items-center gap-5">
                    <div
                      className={`w-12 h-12 rounded-xl flex items-center justify-center font-black text-lg transition-all duration-300 ${
                        isActive
                          ? 'bg-[#18232D] text-white shadow-md scale-105'
                          : 'bg-[#E6EEF2] text-[#18232D] group-hover:bg-[#18232D] group-hover:text-white'
                      }`}
                    >
                      {step.num}
                    </div>
                    <div>
                      <span className="text-[10px] font-black uppercase tracking-widest text-[#68747D] block mb-0.5">
                        {step.stage}
                      </span>
                      <strong className="text-base sm:text-lg font-bold text-[#18232D] block">
                        {step.prompt}
                      </strong>
                    </div>
                  </div>
                  <span
                    className={`text-xs font-bold px-3 py-1.5 rounded-lg transition-all hidden sm:block ${
                      isActive ? 'bg-[#18232D] text-white' : 'bg-[#E6EEF2] text-[#68747D]'
                    }`}
                  >
                    {step.desc}
                  </span>
>>>>>>> origin/main
                </div>
              );
            })}
          </div>
        </div>
<<<<<<< HEAD
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
            {/* Tombol download APK */}
            <Magnetic>
              <a href={APK_URL} download="formup-android.apk" target="_blank" rel="noopener noreferrer"
                className="px-7 py-3.5 text-sm font-bold rounded-full flex items-center gap-2 transition-colors duration-300"
                style={{ backgroundColor: GREEN, color: '#F6F4ED' }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = LIGHT)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = GREEN)}
              >
                <Smartphone size={16} /> Unduh APK (Android)
              </a>
            </Magnetic>
            {/* Tombol download Windows installer */}
            <Magnetic>
              <a href={EXE_URL} download="formup-windows-installer.exe" target="_blank" rel="noopener noreferrer"
                className="px-7 py-3.5 text-sm font-bold rounded-full flex items-center gap-2 transition-colors duration-300"
                style={{ backgroundColor: INK, color: '#F6F4ED' }}
                onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = DARK)}
                onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = INK)}
              >
                <Download size={16} /> Unduh Installer (Windows)
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
=======

        {/* Right Column: Live Dynamic Preview Card with 3D Mouse Tilt */}
        <div className="lg:col-span-6 scroll-reveal-item">
          <div
            ref={cardRef}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            className="p-10 sm:p-12 rounded-3xl bg-white border border-[#18232D]/10 shadow-2xl transition-transform duration-200 ease-out relative overflow-hidden"
            style={{ transformStyle: 'preserve-3d' }}
          >
            {/* Card Top Bar */}
            <div className="flex items-center justify-between pb-6 border-b border-[#18232D]/10">
              <div className="flex items-center gap-2">
                <div className="w-3 h-3 rounded-full bg-red-400" />
                <div className="w-3 h-3 rounded-full bg-amber-400" />
                <div className="w-3 h-3 rounded-full bg-emerald-400" />
                <span className="ml-2 text-xs font-mono font-bold text-slate-400">formup.co/preview</span>
              </div>
            </div>

            {/* Dynamic Step Content */}
            <div className="py-8 min-h-[260px] flex flex-col justify-center">
              <div className="inline-flex items-center gap-1.5 text-xs font-extrabold text-amber-700 uppercase tracking-widest mb-3">
                <span className="w-2 h-2 rounded-full bg-amber-500 animate-ping" />
                <span>{steps[activeStep].preview.tag}</span>
              </div>
              <h3 className="text-xl sm:text-2xl font-black text-[#18232D] mb-6 leading-snug">
                {steps[activeStep].preview.question}
              </h3>

              {activeStep === 0 && (
                <div className="p-4 rounded-xl bg-[#F4F1EA] border border-[#18232D]/10 font-medium text-sm text-[#18232D]/80 flex items-center justify-between animate-fadeIn">
                  <span>{steps[0].preview.sampleInput}</span>
                  <span className="w-0.5 h-5 bg-[#18232D] animate-pulse" />
                </div>
              )}

              {activeStep === 1 && (
                <div className="space-y-2.5 animate-fadeIn">
                  {steps[1].preview.options.map((opt, i) => (
                    <div
                      key={opt}
                      className={`p-3.5 rounded-xl border text-xs sm:text-sm font-bold flex items-center justify-between transition-all cursor-pointer ${
                        i === 0
                          ? 'bg-[#18232D] text-white border-[#18232D] shadow-md'
                          : 'bg-[#F4F1EA] text-slate-700 border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <span>{opt}</span>
                      {i === 0 && <Check size={16} className="text-white" />}
                    </div>
                  ))}
                </div>
              )}

              {activeStep === 2 && (
                <div className="p-4 rounded-xl bg-[#F4F1EA] border border-[#18232D]/10 text-xs sm:text-sm text-slate-700 space-y-3 animate-fadeIn">
                  <p className="italic leading-relaxed">{steps[2].preview.sampleInput}</p>
                  <div className="flex justify-between items-center text-[10px] font-bold text-slate-500 pt-2 border-t border-slate-200">
                    <span>Terisi otomatis</span>
                    <span>12 kata</span>
                  </div>
                </div>
              )}
            </div>

            {/* Bottom Meta */}
            <div className="pt-6 border-t border-[#18232D]/10 flex items-center justify-between text-xs text-[#68747D] font-medium">
              <span>Rangkaian otomatis terhubung</span>
              <span className="font-mono font-bold text-[#18232D]">Step {activeStep + 1} of 3</span>
            </div>
          </div>
        </div>

      </div>

      {/* ── Bottom Stats Bar fills remaining screen height ── */}
      <div className="flex-1 flex items-end max-w-7xl mx-auto w-full pb-10 pt-8">
        <div className="w-full grid grid-cols-3 gap-6 border-t border-[#18232D]/10 pt-10">
          {[
            { num: '50+', label: 'Tipe input & komponen siap pakai' },
            { num: '3s', label: 'Rata-rata waktu membangun satu soal' },
            { num: '100%', label: 'Tanpa coding — drag, drop, selesai' },
          ].map((stat) => (
            <div key={stat.num} className="scroll-reveal-item">
              <div className="text-3xl sm:text-5xl font-black text-[#18232D] tracking-tight mb-1">{stat.num}</div>
              <p className="text-xs sm:text-sm text-[#68747D] font-medium leading-snug">{stat.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ─────────────────────────────────────────────────────────────
   INTERACTIVE SHARE HUB (Section 2: Sharing Everywhere)
───────────────────────────────────────────────────────────── */
function ShareHubSection({ handleCopy, copiedLink }) {
  const { cardRef, handleMouseMove, handleMouseLeave } = useCardTilt();
  const [showQr, setShowQr] = useState(false);

  return (
    <section id="share" className="min-h-screen w-full flex flex-col py-20 px-6 sm:px-12 lg:px-16 bg-[#F4F1EA] border-b border-[#18232D]/10 relative">
      <div className="max-w-7xl mx-auto w-full grid lg:grid-cols-12 gap-16 items-center">
        
        {/* Left Column: Interactive Share Card */}
        <div className="lg:col-span-6 scroll-reveal-item order-2 lg:order-1">
          <div
            ref={cardRef}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            className="p-10 sm:p-14 rounded-3xl bg-white border border-[#18232D]/10 shadow-xl hover:shadow-2xl transition-all duration-300 relative overflow-hidden"
            style={{ transformStyle: 'preserve-3d' }}
          >
            {/* Live Distribution Tag */}
            <div className="flex items-center justify-between text-xs font-black uppercase tracking-wider text-[#68747D] pb-6 border-b border-[#18232D]/10">
              <span className="flex items-center gap-2">
                <Globe size={15} className="text-[#18232D]" />
                <span>PUBLIC DISTRIBUTION</span>
              </span>
            </div>

            {/* Central Short Link Display */}
            <div className="py-10">
              <span className="text-xs font-bold text-[#68747D] uppercase tracking-wider block mb-2">
                Instant Universal Link
              </span>
              <div className="text-2xl sm:text-4xl font-mono font-black text-[#18232D] tracking-tight hover:text-teal-700 transition-colors">
                formup.co/your-story
              </div>
            </div>

            {/* Floating Live Activity Ticker */}
            <div className="mb-8 p-3.5 rounded-2xl bg-[#F4F1EA] border border-[#18232D]/10 flex items-center justify-between text-xs">
              <div className="flex items-center gap-2.5">
                <Users size={15} className="text-amber-600" />
                <span className="font-bold text-slate-800">14 peserta sedang membuka formulir</span>
              </div>
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
            </div>

            {/* Interactive Buttons */}
            <div className="flex flex-col sm:flex-row items-center gap-4 pt-6 border-t border-[#18232D]/10">
              <button
                type="button"
                onClick={handleCopy}
                className="w-full sm:w-auto flex-1 inline-flex items-center justify-center gap-2.5 px-8 py-4 rounded-full bg-[#18232D] text-white text-xs font-extrabold uppercase tracking-wider hover:bg-[#25323e] transition-all cursor-pointer shadow-lg active:scale-95"
              >
                {copiedLink ? <CheckCheck size={16} className="text-emerald-400" /> : <Copy size={15} />}
                <span>{copiedLink ? 'Copied to Clipboard!' : 'Copy Public Link'}</span>
              </button>

              <button
                type="button"
                onClick={() => setShowQr(!showQr)}
                className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-6 py-4 rounded-full bg-[#F4F1EA] hover:bg-slate-200 border border-[#18232D]/15 text-[#18232D] text-xs font-extrabold uppercase tracking-wider transition-all cursor-pointer shadow-xs"
              >
                <QrCode size={16} />
                <span>{showQr ? 'Tutup QR' : 'QR Code'}</span>
              </button>
            </div>

            {/* QR Code Pop-Down Modal */}
            {showQr && (
              <div className="mt-6 p-6 rounded-2xl bg-[#18232D] text-white text-center animate-fadeIn flex flex-col items-center">
                <div className="w-32 h-32 bg-white rounded-xl p-2 flex items-center justify-center shadow-lg mb-3">
                  <QrCode size={110} className="text-[#18232D]" />
                </div>
                <p className="text-xs font-bold">Pindai langsung via kamera ponsel</p>
                <span className="text-[10px] text-white/60">Tidak perlu unduh aplikasi tambahan</span>
              </div>
            )}
          </div>
        </div>

        {/* Right Column: Narrative */}
        <div className="lg:col-span-6 scroll-reveal-item order-1 lg:order-2">
          <h2 className="text-4xl sm:text-6xl font-extrabold text-[#18232D] tracking-tight leading-[1.08] mb-8">
            One link is enough.<br />
            <em className="font-normal italic">Let people in.</em>
          </h2>

          <p className="text-base sm:text-xl text-[#68747D] leading-relaxed mb-10">
            No explanation threads. No login gates or forced registrations. Put your form wherever conversations already happen—classroom group chats, presentation slides, or social channels.
          </p>

          <div className="flex items-center gap-4 text-xs font-bold uppercase tracking-wider text-[#18232D]">
            <div className="w-10 h-px bg-[#18232D]" />
            <span>Instant Cross-Platform Compatibility</span>
          </div>
        </div>

      </div>

      {/* ── Bottom Distribution Channels Bar ── */}
      <div className="flex-1 flex items-end max-w-7xl mx-auto w-full pb-10 pt-8">
        <div className="w-full grid grid-cols-1 sm:grid-cols-3 gap-6 border-t border-[#18232D]/10 pt-10">
          {[
            { tag: 'Direct Link & QR', desc: 'Buka langsung di browser tanpa install aplikasi apapun' },
            { tag: 'Auto Social Preview', desc: 'Thumbnail & ringkasan otomatis rapi di WhatsApp & Telegram' },
            { tag: 'Zero Login Gate', desc: 'Responden langsung mengisi dalam 1 klik tanpa hambatan akun' },
          ].map((item, idx) => (
            <div key={idx} className="scroll-reveal-item">
              <div className="text-base sm:text-lg font-black text-[#18232D] mb-1 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-teal-600" />
                <span>{item.tag}</span>
              </div>
              <p className="text-xs sm:text-sm text-[#68747D] font-medium leading-relaxed">{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ─────────────────────────────────────────────────────────────
   REAL-TIME RESPONSES (Section 3: Analytics & Live Surge)
───────────────────────────────────────────────────────────── */
function ResponsesSection() {
  const [activeRange, setActiveRange] = useState('7d');
  const [counts, setCounts] = useState({ responses: 284, completion: '94.2%', avgTime: '1m 24s' });
  const { cardRef, handleMouseMove, handleMouseLeave } = useCardTilt();

  const datasets = {
    '1d': [22, 35, 60, 48, 85, 95, 70, 80],
    '7d': [38, 56, 44, 78, 64, 92, 74, 98, 82, 90],
    '30d': [50, 65, 72, 84, 60, 78, 88, 92, 85, 96, 75, 94],
  };

  const handleRangeChange = (range) => {
    setActiveRange(range);
    if (range === '1d') setCounts({ responses: 54, completion: '96.1%', avgTime: '1m 12s' });
    else if (range === '7d') setCounts({ responses: 284, completion: '94.2%', avgTime: '1m 24s' });
    else setCounts({ responses: 1240, completion: '92.8%', avgTime: '1m 35s' });

    gsap.fromTo(
      '.response-chart-bar',
      { scaleY: 0.2, transformOrigin: 'bottom' },
      { scaleY: 1, duration: 0.6, stagger: 0.04, ease: 'back.out(1.7)' }
    );
  };

  return (
    <section id="responses" className="min-h-screen w-full flex flex-col py-20 px-6 sm:px-12 lg:px-16 bg-[#18232D] text-white border-b border-white/10 relative">
      <div className="max-w-7xl mx-auto w-full grid lg:grid-cols-12 gap-16 items-center">
        
        {/* Left Column: Narrative */}
        <div className="lg:col-span-5 scroll-reveal-item">
          <h2 className="text-4xl sm:text-6xl font-extrabold text-white tracking-tight leading-[1.08] mb-8">
            The answers arrive.<br />
            <em className="font-normal italic text-[#f4f1ea]">See the signal.</em>
          </h2>

          <p className="text-base sm:text-xl text-white/80 leading-relaxed mb-10">
            Responses should be immediately legible. Watch patterns emerge in real-time, inspect individual submissions, and export clean data to spreadsheets whenever decisions need data.
          </p>

          <div className="flex items-center gap-4 text-xs font-bold uppercase tracking-wider text-white/80">
            <div className="w-10 h-px bg-white/40" />
            <span>Live Synced Response Analytics</span>
          </div>
        </div>

        {/* Right Column: Surging Live Chart Card with 3D Tilt */}
        <div className="lg:col-span-7 scroll-reveal-item">
          <div
            ref={cardRef}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            className="p-8 sm:p-14 rounded-3xl bg-white/5 border border-white/10 backdrop-blur-md shadow-2xl hover:border-white/25 transition-all duration-300"
            style={{ transformStyle: 'preserve-3d' }}
          >
            {/* Header with Live Status & Range Selector */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-8 border-b border-white/10 gap-4">
              <div>
                <span className="text-xs font-bold uppercase tracking-wider text-white/60 block mb-1">
                  TOTAL RESPONSES
                </span>
                <strong className="text-3xl sm:text-4xl font-black text-white">
                  {counts.responses} answers
                </strong>
              </div>

              {/* Range Filters */}
              <div className="flex items-center gap-2 bg-white/10 p-1.5 rounded-2xl">
                {[
                  { key: '1d', label: 'Hari Ini' },
                  { key: '7d', label: '7 Hari' },
                  { key: '30d', label: '30 Hari' },
                ].map((tab) => (
                  <button
                    key={tab.key}
                    type="button"
                    onClick={() => handleRangeChange(tab.key)}
                    className={`px-3.5 py-1.5 rounded-xl text-xs font-extrabold uppercase transition-all cursor-pointer ${
                      activeRange === tab.key
                        ? 'bg-white text-[#18232D] shadow-sm'
                        : 'text-white/70 hover:text-white'
                    }`}
                  >
                    {tab.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Micro Stats Bar */}
            <div className="grid grid-cols-2 gap-4 py-6 border-b border-white/10 text-xs">
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-emerald-500/20 text-emerald-300 flex items-center justify-center font-black">
                  ✓
                </div>
                <div>
                  <span className="text-white/60 block">Tingkat Penyelesaian</span>
                  <strong className="text-sm font-black text-white">{counts.completion}</strong>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <div className="w-9 h-9 rounded-xl bg-amber-500/20 text-amber-300 flex items-center justify-center font-black">
                  ⏱
                </div>
                <div>
                  <span className="text-white/60 block">Rata-rata Waktu</span>
                  <strong className="text-sm font-black text-white">{counts.avgTime}</strong>
                </div>
              </div>
            </div>

            {/* Animated Growing Bar Chart with Hover Tooltip */}
            <div className="h-56 flex items-end justify-between gap-2.5 sm:gap-3 pt-10 pb-4">
              {datasets[activeRange].map((height, i) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-2 h-full justify-end group/bar relative">
                  <div className="absolute -top-9 opacity-0 group-hover/bar:opacity-100 transition-opacity bg-white text-[#18232D] text-[10px] font-black px-2 py-1 rounded-md shadow-md pointer-events-none whitespace-nowrap">
                    {height} resp
                  </div>
                  <div
                    className="response-chart-bar w-full rounded-t-xl bg-gradient-to-t from-white/75 to-white hover:from-amber-300 hover:to-white transition-colors duration-200 cursor-pointer shadow-xs"
                    style={{ height: `${height}%` }}
                  />
                </div>
              ))}
            </div>

            {/* Bottom Timeline Indicator */}
            <div className="flex items-center justify-between pt-6 border-t border-white/10 text-xs font-bold tracking-widest text-white/50">
              <span>AWAL PERIODE</span>
              <div className="flex items-center gap-1.5 text-emerald-300">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                <span>STREAMING REAL-TIME</span>
              </div>
              <span>SEKARANG</span>
>>>>>>> origin/main
            </div>
          </div>
        </div>

<<<<<<< HEAD
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

=======
      </div>

      {/* ── Bottom Analytics Capabilities Bar ── */}
      <div className="flex-1 flex items-end max-w-7xl mx-auto w-full pb-10 pt-8">
        <div className="w-full grid grid-cols-1 sm:grid-cols-3 gap-6 border-t border-white/10 pt-10">
          {[
            { title: 'Live Streaming Websockets', desc: 'Jawaban masuk seketika tanpa perlu refresh halaman' },
            { title: '1-Click CSV & XLSX Export', desc: 'Ekspor tabel terstruktur siap olah di Excel atau Google Sheets' },
            { title: 'AI Answer Summaries', desc: 'Ringkas ratusan jawaban essay secara cerdas dalam hitungan detik' },
          ].map((item, idx) => (
            <div key={idx} className="scroll-reveal-item">
              <div className="text-base sm:text-lg font-black text-white mb-1 flex items-center gap-2">
                <span className="w-2 h-2 rounded-full bg-emerald-400" />
                <span>{item.title}</span>
              </div>
              <p className="text-xs sm:text-sm text-white/60 font-medium leading-relaxed">{item.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ─────────────────────────────────────────────────────────────
   MAIN COMPONENT (FULL VIEWPORT SCREENS, EXTENDED TRANSITION)
───────────────────────────────────────────────────────────── */
export default function LandingPage() {
  const navigate = useNavigate();
  const heroRef = useRef(null);
  const stickyRef = useRef(null);
  const progressRef = useRef(0);
  const [scrollProgress, setScrollProgress] = useState(0);
  const [sceneIndex, setSceneIndex] = useState(0);
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);

  useEffect(() => {
    if (isAuthenticated()) {
      navigate('/dashboard', { replace: true });
    }
  }, [navigate]);

  // Smooth Lenis Scroll + GSAP ScrollTrigger
  useEffect(() => {
    const lenis = new Lenis({ duration: 1.2, smoothWheel: true });
    lenis.on('scroll', ScrollTrigger.update);
    const raf = (time) => lenis.raf(time * 1000);
    gsap.ticker.add(raf);
    gsap.ticker.lagSmoothing(0);

    const onScroll = () => setScrolled(window.scrollY > 40);
    window.addEventListener('scroll', onScroll, { passive: true });

    // 600vh Skyfall ScrollTrigger: gives a dedicated, substantial transition zone!
    const heroTrigger = ScrollTrigger.create({
      trigger: heroRef.current,
      pin: stickyRef.current,
      pinSpacing: false,
      start: 'top top',
      end: 'bottom bottom',
      scrub: 0.5,
      onUpdate: (self) => {
        progressRef.current = self.progress;
        setScrollProgress(self.progress);
        // Stages 0 to 4 play out in the first 65% of scroll; remaining 35% is the breakthrough transition!
        const nextScene = Math.min(4, Math.floor((self.progress / 0.65) * 5));
        setSceneIndex(nextScene);
      },
    });

    // Bar chart animation in Responses Section
    const chartTrigger = gsap.fromTo(
      '.response-chart-bar',
      { scaleY: 0, transformOrigin: 'bottom' },
      {
        scaleY: 1,
        duration: 0.85,
        stagger: 0.05,
        ease: 'power3.out',
        scrollTrigger: {
          trigger: '#responses',
          start: 'top 70%',
          toggleActions: 'play none none reverse',
        },
      }
    );

    // Staggered card reveal animations with safe initial visibility
    const cardTriggers = gsap.utils.toArray('.scroll-reveal-item').map((el) => {
      return gsap.fromTo(
        el,
        { y: 35, opacity: 0.2 },
        {
          y: 0,
          opacity: 1,
          duration: 0.7,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: el,
            start: 'top 95%',
            toggleActions: 'play none none none',
          },
        }
      );
    });

    return () => {
      heroTrigger.kill();
      chartTrigger.kill();
      cardTriggers.forEach((t) => t.kill());
      gsap.ticker.remove(raf);
      lenis.destroy();
      window.removeEventListener('scroll', onScroll);
    };
  }, []);

  const handleCopy = useCallback(() => {
    navigator.clipboard.writeText('https://formup.co/your-story');
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2400);
  }, []);

  const currentStage = STORY_STAGES[sceneIndex] || STORY_STAGES[0];

  // Headline & CTA opacity smoothly fades during breakthrough transition (p > 0.68)
  const textOpacity = scrollProgress < 0.68 ? 1 : Math.max(0, 1 - (scrollProgress - 0.68) / 0.12);

  return (
    <div className="bg-[#F4F1EA] text-[#18232D] font-['Manrope',sans-serif] selection:bg-[#18232D] selection:text-white antialiased overflow-x-clip">
      
      {/* ── TOP NAVBAR ── */}
      <nav
        className={`fixed top-0 inset-x-0 z-50 transition-all duration-300 ${
          scrolled
            ? 'py-3.5 bg-[#18232D]/85 backdrop-blur-md border-b border-white/10 text-white shadow-xs'
            : 'py-6 bg-transparent text-white'
        }`}
      >
        <div className="max-w-7xl mx-auto px-6 sm:px-12 flex items-center justify-between">
          <Link to="/" className="inline-flex items-center gap-2.5 font-extrabold tracking-tight text-lg">
            <img src={logo} alt="FormUp" className="w-7 h-7 object-contain" />
            <span>FormUp</span>
          </Link>

          <div className="hidden md:flex items-center gap-8 text-xs font-bold uppercase tracking-wider">
            {[['#top', 'Home'], ['#build', 'Build'], ['#share', 'Share'], ['#responses', 'Responses']].map(([href, label]) => (
              <a
                key={label}
                href={href}
                className="text-white/75 hover:text-white transition-colors duration-200"
              >
                {label}
              </a>
            ))}
          </div>

          <div className="hidden md:flex items-center gap-4">
            <Link
              to="/login"
              className="text-xs font-bold uppercase tracking-wider text-white/80 hover:text-white transition-colors px-3 py-1.5"
            >
              Sign In
            </Link>
            <Link
              to="/register"
              className="px-5 py-2.5 rounded-full bg-white text-[#18232D] hover:bg-[#F4F1EA] text-xs font-extrabold tracking-wide uppercase shadow-sm transition-all duration-200"
            >
              Get Started
            </Link>
          </div>

          <button
            type="button"
            onClick={() => setMenuOpen(!menuOpen)}
            className="md:hidden p-2 text-white"
          >
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
        </div>
      </nav>

      {/* Mobile Menu Drawer */}
      {menuOpen && (
        <div className="fixed inset-0 z-40 bg-[#18232D]/95 backdrop-blur-xl flex flex-col items-center justify-center gap-6 md:hidden p-8 text-white">
          <Link to="/" onClick={() => setMenuOpen(false)} className="text-2xl font-black mb-4">
            FormUp
          </Link>
          {[['#top', 'Home'], ['#build', 'Build'], ['#share', 'Share'], ['#responses', 'Responses']].map(([href, label]) => (
            <a
              key={label}
              href={href}
              onClick={() => setMenuOpen(false)}
              className="text-lg font-bold text-white/80 hover:text-white"
            >
              {label}
            </a>
          ))}
          <div className="w-48 h-px bg-white/20 my-2" />
          <Link
            to="/login"
            onClick={() => setMenuOpen(false)}
            className="text-base font-bold text-white/80"
          >
            Sign In
          </Link>
          <Link
            to="/register"
            onClick={() => setMenuOpen(false)}
            className="w-full max-w-xs py-3 rounded-full bg-white text-[#18232D] text-center font-extrabold"
          >
            Get Started →
          </Link>
        </div>
      )}

      {/* ─────────────────────────────────────────────────────────────
          1. HERO SKYFALL (600VH EXTENDED ATMOSPHERIC PLUNGE & TRANSITION)
      ───────────────────────────────────────────────────────────── */}
      <section ref={heroRef} id="top" className="relative h-[600vh]">
        <div ref={stickyRef} className="sticky top-0 h-screen w-full overflow-hidden bg-[#9db7c6]">
          
          {/* Full-bleed 3D WebGL Canvas Layer */}
          <div className="absolute inset-0 z-0">
            <Canvas
              camera={{ position: [0, 0, 8.5], fov: 45, near: 0.1, far: 100 }}
              dpr={typeof window !== 'undefined' && window.innerWidth < 768 ? [1, 1.2] : [1, 1.5]}
              gl={{ antialias: true, alpha: false, powerPreference: 'high-performance' }}
            >
              <Suspense fallback={null}>
                <FallingSkyCanvas progressRef={progressRef} sceneIndex={sceneIndex} />
              </Suspense>
            </Canvas>
          </div>

          {/* Left-Aligned Spacious Text (Fades smoothly as breakthrough begins) */}
          <div
            className="relative z-10 max-w-7xl mx-auto px-6 sm:px-12 lg:px-16 w-full h-full flex items-center pointer-events-none transition-opacity duration-300"
            style={{ opacity: textOpacity }}
          >
            <div className="w-full max-w-lg lg:max-w-[500px] xl:max-w-[530px] mr-auto pointer-events-auto">
              
              {/* Milestone Headline */}
              <h1 className="text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white tracking-tight leading-[1.06] mb-6 drop-shadow-md">
                {currentStage.headline}
              </h1>

              {/* Milestone Body Copy */}
              <p className="text-base sm:text-lg text-white/90 font-medium leading-relaxed mb-10 max-w-md drop-shadow-xs">
                {currentStage.body}
              </p>

              {/* Interactive Actions */}
              <div className="flex items-center gap-4">
                <Link
                  to="/register"
                  className="inline-flex items-center gap-2 px-8 py-4 rounded-full bg-[#18232D] text-white hover:bg-[#25323e] text-sm font-extrabold tracking-wide uppercase shadow-xl transition-all duration-200"
                >
                  <span>Build your first form</span>
                  <ArrowRight size={16} />
                </Link>
                <a
                  href={APK_URL}
                  download
                  className="inline-flex items-center gap-2 px-6 py-4 rounded-full bg-white/20 hover:bg-white/30 backdrop-blur-md border border-white/30 text-white text-xs font-extrabold uppercase tracking-wide transition-all duration-200"
                >
                  <Smartphone size={15} />
                  <span>Android APK</span>
                </a>
              </div>
            </div>
          </div>

          {/* Transition Wind Breakthrough Notice (Appears during the deep plunge) */}
          {/* {scrollProgress >= 0.72 && scrollProgress < 0.95 && (
            <div className="absolute inset-x-0 bottom-24 z-20 flex justify-center pointer-events-none animate-fadeIn">
              <div className="flex items-center gap-2.5 px-6 py-3 rounded-full bg-[#18232D]/40 backdrop-blur-md border border-white/20 text-white/90 text-xs font-bold tracking-widest uppercase shadow-lg">
                <Wind size={15} className="text-amber-300 animate-pulse" />
                <span>Menembus Lapisan Awan...</span>
              </div>
            </div>
          )} */}

          {/* Bottom Left Storytelling Caption */}
          <div
            className="absolute left-6 sm:left-12 lg:left-16 bottom-10 z-20 pointer-events-none transition-opacity duration-300"
            style={{ opacity: textOpacity }}
          >
            <div className="bg-[#18232D]/75 backdrop-blur-md border border-white/20 text-white rounded-2xl px-5 py-3.5 max-w-xs shadow-lg transition-all duration-300">
              <span className="text-[10px] font-black tracking-widest uppercase text-white/60 block mb-1">
                Phase {currentStage.stage} of 05
              </span>
              <p className="text-xs sm:text-sm font-bold leading-relaxed text-white/95">
                &ldquo;{currentStage.caption}&rdquo;
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ─────────────────────────────────────────────────────────────
          2. SECTION: SHAPE THE FLOW (FULL-SCREEN MIN-H-SCREEN)
      ───────────────────────────────────────────────────────────── */}
      <ShapeFlowSection />

      {/* ─────────────────────────────────────────────────────────────
          3. SECTION: SHARING EVERYWHERE (FULL-SCREEN MIN-H-SCREEN)
      ───────────────────────────────────────────────────────────── */}
      <ShareHubSection handleCopy={handleCopy} copiedLink={copiedLink} />

      {/* ─────────────────────────────────────────────────────────────
          4. SECTION: REAL-TIME RESPONSES (FULL-SCREEN MIN-H-SCREEN)
      ───────────────────────────────────────────────────────────── */}
      <ResponsesSection />

      {/* ─────────────────────────────────────────────────────────────
          5. FINAL HORIZON CTA (FULL-SCREEN MIN-H-SCREEN)
      ───────────────────────────────────────────────────────────── */}
      <section className="min-h-screen w-full flex flex-col justify-center items-center py-28 px-6 sm:px-12 lg:px-16 bg-[#F4F1EA] text-center relative overflow-hidden">
        <div className="absolute -top-20 -left-20 w-96 h-96 rounded-full bg-amber-200/25 blur-3xl pointer-events-none" />
        <div className="absolute -bottom-20 -right-20 w-96 h-96 rounded-full bg-teal-200/25 blur-3xl pointer-events-none" />

        <div className="max-w-4xl mx-auto scroll-reveal-item relative z-10">
          <h2 className="text-5xl sm:text-7xl lg:text-8xl font-extrabold text-[#18232D] tracking-tight leading-[1.04] mb-8">
            Questions can feel natural.
          </h2>

          <p className="text-lg sm:text-2xl text-[#68747D] max-w-2xl mx-auto leading-relaxed mb-12">
            Open the canvas, write what you need to know, and share it with the people who have the answers.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            <Link
              to="/register"
              className="w-full sm:w-auto inline-flex items-center justify-center gap-3 px-10 py-4 rounded-full bg-[#18232D] text-white hover:bg-[#25323e] text-sm font-extrabold tracking-wide uppercase shadow-xl hover:shadow-2xl transition-all duration-200 active:scale-95"
            >
              <span>Build your first form</span>
              <ArrowRight size={17} />
            </Link>
            <a
              href={APK_URL}
              download
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-8 py-4 rounded-full bg-white hover:bg-[#E6EEF2] border border-[#18232D]/15 text-[#18232D] text-xs font-extrabold uppercase tracking-wide transition-all duration-200 shadow-sm"
            >
              <Smartphone size={16} />
              <span>Download Android APK</span>
            </a>
            <a
              href={EXE_URL}
              download
              className="w-full sm:w-auto inline-flex items-center justify-center gap-2 px-8 py-4 rounded-full bg-white hover:bg-[#E6EEF2] border border-[#18232D]/15 text-[#18232D] text-xs font-extrabold uppercase tracking-wide transition-all duration-200 shadow-sm"
            >
              <Download size={16} />
              <span>Windows App</span>
            </a>
          </div>
        </div>
      </section>

      {/* ── FOOTER ── */}
      <footer className="py-14 px-6 sm:px-12 bg-[#18232D] text-white/50 border-t border-white/10 text-xs">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-3">
            <img src={logo} alt="FormUp" className="w-5 h-5 object-contain opacity-70" />
            <span className="font-bold text-white/80">FormUp</span>
            <span>·</span>
            <span>A better way to ask questions.</span>
          </div>

          <div className="flex items-center gap-6 font-bold uppercase tracking-wider">
            <Link to="/login" className="hover:text-white transition-colors">Sign In</Link>
            <Link to="/register" className="hover:text-white transition-colors">Get Started</Link>
            <a href={APK_URL} target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">Android</a>
            <a href={EXE_URL} target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">Windows</a>
          </div>

          <div>
            <span>© {new Date().getFullYear()} FormUp Platform</span>
          </div>
        </div>
      </footer>
>>>>>>> origin/main
    </div>
  );
}
