// Bindu Ensemble Engine — Live Generative Visualization
// 7 dancers driven by binaural frequencies + sacred geometry emergence

const { useEffect, useRef } = React;
const hsl = (h, s, l, a = 1) => `hsla(${h | 0},${s | 0}%,${l | 0}%,${a})`;

const ELEMENT_CFG = {
  Earth:       { hue: 15,  bgSat: 18 },
  Water:       { hue: 210, bgSat: 24 },
  Fire:        { hue: 35,  bgSat: 15 },
  Air:         { hue: 200, bgSat: 24 },
  Light:       { hue: 248, bgSat: 20 },
  Crown:       { hue: 280, bgSat: 15 },
  Soul:        { hue: 265, bgSat: 18 },
  Dissolution: { hue: 190, bgSat: 22 },
  Meditate:    { hue: 200, bgSat: 20 },
  Family:      { hue: 155, bgSat: 20 },
};

class Dancer {
  constructor(hue, r, maxRings) {
    this.hue = hue; this.r = r; this.maxRings = maxRings;
    this.x = 0; this.y = 0; this.tx = 0; this.ty = 0;
    this.p = 0; this.tp = 0; this.ds = 1;
    this.oA = Math.random() * Math.PI * 2;
    this.rings = []; this._st = 0;
  }

  tick(e, maxR) {
    this._st++;
    const rate = Math.max(3, Math.floor(10 - e * 7));
    if (this.p > 0.05 && this._st % rate === 0) {
      this.rings.push({
        x: this.x, y: this.y, r: 0,
        mr: maxR * (0.06 + e * 0.14),
        spd: 1 + e * 2.5, a: 0.35 * this.p
      });
      while (this.rings.length > this.maxRings) this.rings.shift();
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const rn = this.rings[i];
      rn.r += rn.spd; rn.a *= 0.97;
      if (rn.r >= rn.mr || rn.a < 0.005) this.rings.splice(i, 1);
    }
  }

  draw(ctx, hue) {
    if (this.p < 0.01) return;
    const { x, y, r, p, ds } = this;

    for (const rn of this.rings) {
      const prog = rn.r / rn.mr;
      ctx.save();
      ctx.globalAlpha = Math.min(rn.a * p * (1 - prog * 0.6), 0.28);
      ctx.strokeStyle = hsl(hue, 42 + prog * 18, 55 + prog * 22);
      ctx.lineWidth = Math.max(0.3, (1 - prog) * 1.5);
      ctx.beginPath(); ctx.arc(rn.x, rn.y, rn.r, 0, Math.PI * 2); ctx.stroke();
      ctx.restore();
    }

    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    ctx.globalAlpha = p * 0.13;
    const g2 = ctx.createRadialGradient(x, y, 0, x, y, r * 13);
    g2.addColorStop(0, hsl(hue, 50, 68, 0.22)); g2.addColorStop(1, hsl(hue, 35, 40, 0));
    ctx.fillStyle = g2; ctx.beginPath(); ctx.arc(x, y, r * 13, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = p * 0.22;
    const g = ctx.createRadialGradient(x, y, 0, x, y, r * 6);
    g.addColorStop(0, hsl(hue + 15, 45, 80, 0.35)); g.addColorStop(1, hsl(hue, 40, 55, 0));
    ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r * 6, 0, Math.PI * 2); ctx.fill();
    ctx.restore();

    ctx.save(); ctx.globalAlpha = p;
    ctx.fillStyle = hsl(hue, 55, 65);
    ctx.beginPath(); ctx.arc(x, y, r * ds, 0, Math.PI * 2); ctx.fill();
    ctx.globalAlpha = p * 0.6; ctx.fillStyle = hsl(hue + 20, 35, 88);
    ctx.beginPath(); ctx.arc(x, y, r * ds * 0.35, 0, Math.PI * 2); ctx.fill();
    ctx.restore();
    this.ds += (1 - this.ds) * 0.08;
  }
}

function BinduEnsemble({ track, playing = false, toneOn = true, dimmed = false }) {
  const cvs = useRef(null);
  const audioRef = useRef({});

  useEffect(() => {
    const canvas = cvs.current;
    if (!canvas) return;

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const W = 393, H = 720;
    canvas.width = W * dpr; canvas.height = H * dpr;
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const cx = W / 2, cy = H / 2, maxR = Math.min(W, H) * 0.45;

    const el = ELEMENT_CFG[track?.element] || ELEMENT_CFG.Meditate;
    const hue = el.hue;
    const carrier = track?.carrier || 136;
    const beat = track?.beat || 7;
    const bState = track?.state || 'alpha';

    // Binaural audio
    let leftOsc, rightOsc, gainNode, analyser, audioCtx;
    const initAudio = () => {
      try {
        audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        analyser = audioCtx.createAnalyser(); analyser.fftSize = 256;
        gainNode = audioCtx.createGain(); gainNode.gain.value = toneOn ? 0.04 : 0;
        const merger = audioCtx.createChannelMerger(2);
        leftOsc = audioCtx.createOscillator(); rightOsc = audioCtx.createOscillator();
        leftOsc.type = 'sine'; leftOsc.frequency.value = carrier;
        rightOsc.type = 'sine'; rightOsc.frequency.value = carrier + beat;
        leftOsc.connect(merger, 0, 0); rightOsc.connect(merger, 0, 1);
        merger.connect(gainNode); gainNode.connect(analyser);
        if (toneOn) analyser.connect(audioCtx.destination);
        leftOsc.start(); rightOsc.start();
        audioRef.current = { audioCtx, leftOsc, rightOsc, gainNode, analyser };
      } catch (e) {}
    };
    if (playing) initAudio();

    // Energy simulation — beat-frequency-driven
    const simE = t => {
      const phase = (t % (1 / beat)) / (1 / beat);
      const pulse = Math.exp(-phase * 7) * 0.55;
      const base = { delta: 0.22, theta: 0.36, 'theta-alpha': 0.43, alpha: 0.5 }[bState] || 0.36;
      return Math.min(1, Math.max(0, base + pulse + 0.1 * Math.sin(t * 0.11) + Math.sin(t * 6.7) * Math.sin(t * 11.3) * 0.08 + 0.08));
    };
    const simEB = t => Math.min(1, simE(t) * 0.75 + 0.1 * Math.sin(t * 0.3));
    const simEM = t => Math.min(1, simE(t) * 0.55 + 0.08 * Math.sin(t * 2.2));

    // Seven dancers
    const bindu    = new Dancer(hue,      7,   50);
    const gaia     = new Dancer(hue + 10, 6,   35);
    const sid      = new Dancer(hue + 20, 5.5, 28);
    const arch     = new Dancer(hue - 15, 5.5, 40);
    const karishma = new Dancer(hue + 40, 5,   30);
    const sakshi   = new Dancer(hue - 20, 5,   22);
    const ashrey   = new Dancer(hue,      4.5, 28);
    const AD = [bindu, gaia, sid, arch, karishma, sakshi, ashrey];
    for (const d of AD) { d.x = cx; d.y = cy; d.tx = cx; d.ty = cy; }

    let impactRings = [], particles = [];
    const spawnImpact = (x, y, intensity) => {
      impactRings.push({ x, y, r: 4, mr: maxR * (0.28 + intensity * 0.45), spd: 2 + intensity * 3.5, op: intensity * 0.32, lw: 0.6 + intensity * 2.2 });
      if (impactRings.length > 18) impactRings.shift();
    };
    const spawnParts = (x, y, n, e) => {
      for (let i = 0; i < n; i++) {
        const a = Math.random() * Math.PI * 2, sp = 0.5 + Math.random() * 2 * e;
        particles.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp, life: 1, decay: 0.007 + Math.random() * 0.01, r: 0.8 + Math.random() * 1.6, h: hue + Math.random() * 28 - 14 });
      }
      if (particles.length > 180) particles.splice(0, particles.length - 180);
    };

    let bloom = 0, orbBase = 0, t = 0, lastBeat = 0;
    const beatPeriod = 1 / beat;
    let raf;

    const animate = () => {
      raf = requestAnimationFrame(animate);
      t += 0.016;
      const e = simE(t), eb = simEB(t), em = simEM(t);
      const bt = Math.min(e * 1.2, 1);
      bloom += bt > bloom ? (bt - bloom) * 0.06 : (bt - bloom) * 0.012;
      orbBase += 0.0018 + e * 0.004;

      // Beat impulse
      const phase = (t % beatPeriod) / beatPeriod;
      if (phase < 0.05 && t - lastBeat > beatPeriod * 0.5) {
        lastBeat = t; spawnImpact(bindu.x, bindu.y, e);
        bindu.ds = 1 + e * 0.65;
        if (bloom > 0.3) spawnParts(bindu.x, bindu.y, Math.floor(e * 8), e);
      }

      ctx.clearRect(0, 0, W, H);

      // Background
      const globalAlpha = dimmed ? 0.45 : 1;
      ctx.save(); ctx.globalAlpha = globalAlpha;
      const bg = ctx.createRadialGradient(cx, cy * 0.85, 0, cx, cy, Math.max(W, H) * 0.75);
      bg.addColorStop(0, hsl(hue, el.bgSat, 3.5 + e * 2));
      bg.addColorStop(0.55, hsl(hue - 5, el.bgSat - 5, 2 + e));
      bg.addColorStop(1, hsl(hue - 12, el.bgSat - 10, 1));
      ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);
      ctx.restore();

      ctx.save(); ctx.globalAlpha = dimmed ? 0.3 : 1;

      // Interference field (ambient sacred geometry)
      for (let ring = 1; ring <= 6; ring++) {
        const r = maxR * ring * 0.18;
        ctx.globalAlpha = (0.055 - ring * 0.006) * (0.4 + bloom * 0.6) * (dimmed ? 0.5 : 1);
        ctx.strokeStyle = hsl(hue, 38, 60); ctx.lineWidth = 0.4;
        ctx.beginPath(); ctx.arc(cx, cy, r * (1 + Math.sin(t * beat * Math.PI * 2 + ring) * 0.025), 0, Math.PI * 2); ctx.stroke();
      }

      // Impact rings
      for (let i = impactRings.length - 1; i >= 0; i--) {
        const rn = impactRings[i]; rn.r += rn.spd;
        const life = rn.r / rn.mr;
        if (life >= 1) { impactRings.splice(i, 1); continue; }
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = rn.op * (1 - life) * (dimmed ? 0.4 : 1);
        ctx.strokeStyle = hsl(hue, 50, 60); ctx.lineWidth = rn.lw * (1 - life);
        ctx.beginPath(); ctx.arc(rn.x, rn.y, rn.r, 0, Math.PI * 2); ctx.stroke();
        ctx.globalCompositeOperation = 'source-over';
      }

      // Particles
      for (let i = particles.length - 1; i >= 0; i--) {
        const pt = particles[i];
        pt.x += pt.vx; pt.y += pt.vy; pt.vx *= 0.994; pt.vy *= 0.994; pt.life -= pt.decay;
        if (pt.life <= 0) { particles.splice(i, 1); continue; }
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = pt.life * pt.life * 0.22 * (dimmed ? 0.4 : 1);
        ctx.fillStyle = hsl(pt.h, 52, 72);
        ctx.beginPath(); ctx.arc(pt.x, pt.y, pt.r * pt.life, 0, Math.PI * 2); ctx.fill();
        ctx.globalCompositeOperation = 'source-over';
      }

      // Aperture rings (bloom > 0.2)
      if (bloom > 0.2) {
        const alpha = (bloom - 0.2) * 0.9 * (dimmed ? 0.5 : 1);
        const nW = 4 + Math.floor(bloom * 5);
        const wR = maxR * (0.18 + bloom * 0.38 + e * 0.1);
        for (let w = 0; w < nW; w++) {
          const wf = (w + 1) / (nW + 1), r = wf * wR;
          const pulse = 1 + Math.sin(t * 2.8 - w * 0.9) * 0.04 * e;
          const nSeg = 9 + w * 2;
          ctx.lineWidth = (1.1 + bloom * 0.7) * (1 - wf * 0.4);
          for (let s = 0; s < nSeg; s++) {
            const sa = Math.PI * 2 * s / nSeg + orbBase * 0.14;
            const ea = sa + Math.PI * 2 / nSeg * 0.68;
            const np = Math.sin(t * 1.6 + s * 1.2 + w * 0.7);
            ctx.globalAlpha = Math.min(alpha * 0.32 * (1 - wf * 0.4) * (0.3 + Math.abs(np) * 0.7), 0.38);
            ctx.strokeStyle = hsl(hue + w * 4, 48 + np * 10, 62 + wf * 16);
            ctx.beginPath(); ctx.arc(bindu.x, bindu.y, r * pulse, sa, ea); ctx.stroke();
          }
        }
      }

      // 16-Petal Lotus (bloom > 0.42)
      if (bloom > 0.42) {
        const alpha = (bloom - 0.42) * 1.25 * (dimmed ? 0.5 : 1);
        const lotR = maxR * (0.22 + bloom * 0.32) * (0.3 + bloom * 0.55);
        const openness = Math.min((bloom - 0.42) / 0.32, 1);
        const rot = t * 0.024;
        for (let i = 0; i < 16; i++) {
          const a = rot + Math.PI * 2 * i / 16;
          const pa = a + Math.sin(t * 3.4 + i * 1.2) * em * 0.07;
          const perp = pa + Math.PI / 2;
          const w = lotR * 0.17 * (0.3 + openness * 0.7);
          const len = lotR * (0.44 + openness * 0.56) * (1 + em * 0.1);
          const tipX = bindu.x + Math.cos(pa) * len, tipY = bindu.y + Math.sin(pa) * len;
          const cpLx = bindu.x + Math.cos(pa) * len * 0.54 + Math.cos(perp) * w;
          const cpLy = bindu.y + Math.sin(pa) * len * 0.54 + Math.sin(perp) * w;
          const cpRx = bindu.x + Math.cos(pa) * len * 0.54 - Math.cos(perp) * w;
          const cpRy = bindu.y + Math.sin(pa) * len * 0.54 - Math.sin(perp) * w;
          ctx.globalAlpha = alpha * (0.11 + openness * 0.09 + em * 0.06);
          const pg = ctx.createLinearGradient(bindu.x, bindu.y, tipX, tipY);
          pg.addColorStop(0, hsl(hue + 8, 55, 65, 0.5)); pg.addColorStop(1, hsl(hue - 12, 42, 45, 0));
          ctx.fillStyle = pg;
          ctx.beginPath();
          ctx.moveTo(bindu.x + Math.cos(perp) * w * 0.18, bindu.y + Math.sin(perp) * w * 0.18);
          ctx.quadraticCurveTo(cpLx, cpLy, tipX, tipY);
          ctx.quadraticCurveTo(cpRx, cpRy, bindu.x - Math.cos(perp) * w * 0.18, bindu.y - Math.sin(perp) * w * 0.18);
          ctx.closePath(); ctx.fill();
          ctx.globalAlpha = alpha * 0.18;
          ctx.strokeStyle = hsl(hue + 12, 50, 68 + em * 10);
          ctx.lineWidth = 0.55 + bloom * 0.4; ctx.stroke();
        }
      }

      ctx.restore();

      // Vignette
      const vig = ctx.createRadialGradient(cx, cy, maxR * 0.32, cx, cy, maxR * 1.25);
      vig.addColorStop(0, 'rgba(0,0,0,0)');
      vig.addColorStop(1, `rgba(0,1,4,${0.45 + bloom * 0.1})`);
      ctx.fillStyle = vig; ctx.fillRect(0, 0, W, H);

      // Ensemble positions
      const sp = 0.28 + bloom * 0.52;
      bindu.tp = 1;
      bindu.tx = cx + Math.cos(t * 0.22) * maxR * 0.2 * sp;
      bindu.ty = cy + Math.sin(t * 0.27) * maxR * 0.16 * sp - (0.5 - e) * maxR * 0.1;

      gaia.tp = bloom > 0.1 ? Math.min((bloom - 0.1) / 0.12, 1) : 0;
      gaia.tx = cx + Math.sin(t * 0.26) * maxR * 0.85 * sp * eb + Math.cos(t * 0.13) * maxR * 0.22;
      gaia.ty = cy + H * 0.08 + Math.sin(t * 0.1) * maxR * 0.08 + eb * maxR * 0.1;
      gaia.r = 5.5 + eb * 3.5;

      sid.tp = bloom > 0.18 ? Math.min((bloom - 0.18) / 0.12, 1) : 0;
      sid.oA += 0.007 + e * 0.004;
      sid.tx = cx + Math.cos(sid.oA) * maxR * 0.58 * sp;
      sid.ty = cy + Math.sin(sid.oA) * maxR * 0.48 * sp;

      arch.tp = bloom > 0.12 ? Math.min((bloom - 0.12) / 0.1, 1) : 0;
      arch.tx = cx - (bindu.x - cx) * 1.35 * sp + Math.sin(t * 0.4) * maxR * 0.18 * sp;
      arch.ty = cy - (bindu.y - cy) * 0.8 * sp + Math.cos(t * 0.3) * em * maxR * 0.22 * sp;
      arch.r = 5.5 + em * 4;

      karishma.tp = bloom > 0.05 && bloom < 0.35 ? (0.35 - bloom) * 2.5 : 0;
      karishma.tx = cx + Math.sin(t * 0.15) * maxR * 0.72 * (1 - bloom * 0.6);
      karishma.ty = cy + Math.cos(t * 0.12) * maxR * 0.52 * (1 - bloom * 0.6);

      sakshi.tp = bloom > 0.3 ? Math.min((bloom - 0.3) / 0.14, 1) : 0;
      sakshi.tx = cx + Math.cos(t * 0.07) * maxR * 0.95 * sp;
      sakshi.ty = cy + Math.sin(t * 0.055) * maxR * 0.78 * sp;

      ashrey.tp = bloom > 0.62 ? Math.min((bloom - 0.62) / 0.14, 1) : 0;
      let ax = 0, ay = 0, nc = 0;
      for (const d of AD) { if (d !== ashrey && d.p > 0.1) { ax += d.x; ay += d.y; nc++; } }
      if (nc > 0) { ashrey.tx = ax / nc; ashrey.ty = ay / nc; }
      ashrey.hue = (t * 11) % 360;

      ctx.globalCompositeOperation = 'source-over';
      for (const d of AD) {
        d.p += (d.tp - d.p) * 0.04;
        d.x += (d.tx - d.x) * 0.05;
        d.y += (d.ty - d.y) * 0.05;
        d.tick(e, maxR);
        d.draw(ctx, d.hue || hue);
      }

      // Status label
      if (!dimmed) {
        ctx.save(); ctx.globalAlpha = 0.2 + bloom * 0.08;
        ctx.font = `italic 10px Lora, Georgia, serif`;
        ctx.fillStyle = hsl(hue, 38, 72); ctx.textAlign = 'center';
        ctx.fillText(`${carrier} Hz · ${beat} Hz · ${bState}`, cx, H - 28);
        ctx.restore();
      }
    };

    animate();

    return () => {
      cancelAnimationFrame(raf);
      try {
        const a = audioRef.current;
        a.leftOsc && a.leftOsc.stop();
        a.rightOsc && a.rightOsc.stop();
        a.audioCtx && a.audioCtx.close();
      } catch (e) {}
    };
  }, [track && track.id, playing, toneOn, dimmed]);

  return <canvas ref={cvs} style={{ width: '100%', height: '100%', display: 'block' }} />;
}

Object.assign(window, { BinduEnsemble, ELEMENT_CFG });
