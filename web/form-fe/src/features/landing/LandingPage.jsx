import { useEffect, useMemo, useRef, useState, Suspense, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import { Html, useTexture } from '@react-three/drei';
import * as THREE from 'three';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from '@studio-freight/lenis';
import {
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

const APK_URL = 'https://github.com/abayDahln/FormUp/releases/download/v1.0.0/formup-android.apk';
const EXE_URL = 'https://github.com/abayDahln/FormUp/releases/download/v1.0.0/formup-windows-installer.exe';

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
    </div>
  );
}

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
                </div>
              );
            })}
          </div>
        </div>

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
            </div>
          </div>
        </div>

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
    </div>
  );
}
