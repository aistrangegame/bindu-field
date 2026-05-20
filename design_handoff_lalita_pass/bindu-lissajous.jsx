// Bindu — Singular Lissajous Visualization
// One point. One path. One field.
// The intimate mode: a single consciousness moving through void.

const { useEffect: useEffect_lis, useRef: useRef_lis } = React;

function BinduLissajous({ hue = 280, speed = 1.0, beat = 7.0, dimmed = false }) {
  const cvs = useRef_lis(null);

  useEffect_lis(() => {
    const canvas = cvs.current;
    if (!canvas) return;

    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    let W = 0, H = 0, ctx;
    let lastTs = 0;

    function resize() {
      const rect = canvas.getBoundingClientRect();
      const nW = Math.round(rect.width) || 393;
      const nH = Math.round(rect.height) || 432;
      if (nW === W && nH === H) return;
      W = nW; H = nH;
      canvas.width = W * dpr;
      canvas.height = H * dpr;
      ctx = canvas.getContext('2d');
      ctx.scale(dpr, dpr);
    }
    resize();

    // ── Simulation state ─────────────────────────────────────────
    let t = 0;
    const TRAIL = 120;
    const trailX = new Float32Array(TRAIL);
    const trailY = new Float32Array(TRAIL);
    let trailHead = 0;
    let trailCount = 0;

    const rings = [];
    let lastRingT = -10;
    const RING_PERIOD = 0.92; // ~65 BPM — musical breath tempo

    let raf;

    const draw = (ts) => {
      raf = requestAnimationFrame(draw);
      const dt = Math.min(0.05, (ts - (lastTs || ts)) / 1000);
      lastTs = ts;
      t += dt * speed * 0.85;
      resize();

      const cx = W / 2;
      const cy = H / 2;
      const maxR = Math.min(W, H) * (dimmed ? 0.28 : 0.30);

      // ── Multi-harmonic Lissajous ──────────────────────────────
      // Primary: figure-8 (a=2, b=1, δ=π/2)
      // Secondary: slow drift harmonic — makes it feel alive, not mechanical
      const breathe  = 1 + Math.sin(t * 0.19) * 0.065;
      const drift    = Math.sin(t * 0.07) * 0.14;

      const bx = cx + (
        Math.sin(2 * t + Math.PI / 2) * 0.88 +
        Math.sin(3 * t + 0.52)        * 0.12 +
        Math.sin(t * 0.28 + 1.2)      * drift
      ) * maxR * breathe;

      const by = cy + (
        Math.sin(t)                   * 0.84 +
        Math.cos(2.2 * t + 0.9)       * 0.14 * Math.sin(t * 0.11)
      ) * maxR * 0.70 * breathe;

      // ── Trail ─────────────────────────────────────────────────
      trailX[trailHead] = bx;
      trailY[trailHead] = by;
      trailHead = (trailHead + 1) % TRAIL;
      if (trailCount < TRAIL) trailCount++;

      // ── Beat rings ────────────────────────────────────────────
      if (t - lastRingT > RING_PERIOD) {
        lastRingT = t;
        rings.push({
          x: bx, y: by,
          r: 2,
          maxR: maxR * (1.35 + Math.random() * 0.35),
          life: 1,
          spd: 1.55 + Math.random() * 0.4,
        });
      }
      for (let i = rings.length - 1; i >= 0; i--) {
        rings[i].r    += rings[i].spd;
        rings[i].life -= 0.017;
        if (rings[i].life <= 0 || rings[i].r >= rings[i].maxR) rings.splice(i, 1);
      }

      // ── Render ────────────────────────────────────────────────
      ctx.clearRect(0, 0, W, H);

      // Void
      ctx.fillStyle = '#020208';
      ctx.fillRect(0, 0, W, H);

      // Element atmosphere — soft radial tint
      if (!dimmed) {
        const atm = ctx.createRadialGradient(cx, cy, 0, cx, cy, maxR * 2.6);
        atm.addColorStop(0,   `hsla(${hue}, 50%, 20%, 0.14)`);
        atm.addColorStop(0.5, `hsla(${hue}, 38%, 12%, 0.05)`);
        atm.addColorStop(1,   'transparent');
        ctx.fillStyle = atm;
        ctx.fillRect(0, 0, W, H);
      }

      // ── Beat rings ────────────────────────────────────────────
      for (const ring of rings) {
        const prog = ring.r / ring.maxR;
        ctx.save();
        ctx.globalAlpha = ring.life * (1 - prog * 0.65) * (dimmed ? 0.10 : 0.26);
        ctx.strokeStyle  = `hsl(${hue}, 54%, 68%)`;
        ctx.lineWidth    = Math.max(0.3, (1 - prog) * 1.6);
        ctx.shadowColor  = `hsl(${hue}, 62%, 65%)`;
        ctx.shadowBlur   = 5;
        ctx.beginPath();
        ctx.arc(ring.x, ring.y, ring.r, 0, Math.PI * 2);
        ctx.stroke();
        ctx.restore();
      }

      // ── Comet trail ───────────────────────────────────────────
      for (let i = 0; i < trailCount - 1; i++) {
        const idx      = (trailHead - 1 - i + TRAIL) % TRAIL;
        const px       = trailX[idx];
        const py       = trailY[idx];
        const progress = 1 - i / trailCount;                          // 1=newest 0=oldest
        const alpha    = Math.pow(progress, 2.0) * (dimmed ? 0.22 : 0.70);
        const r        = Math.max(0.3, progress * 3.8);
        const h        = hue + (1 - progress) * 22;                   // subtle hue shift
        const l        = 58 + progress * 14;

        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.fillStyle   = `hsl(${h}, 58%, ${l}%)`;
        ctx.beginPath();
        ctx.arc(px, py, r, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }

      // ── Halo glow ─────────────────────────────────────────────
      if (!dimmed) {
        ctx.save();
        ctx.globalCompositeOperation = 'lighter';
        ctx.globalAlpha = 0.38;
        const halo = ctx.createRadialGradient(bx, by, 0, bx, by, 42);
        halo.addColorStop(0,   `hsl(${hue}, 72%, 76%)`);
        halo.addColorStop(0.35, `hsl(${hue}, 58%, 54%)`);
        halo.addColorStop(1,   'transparent');
        ctx.fillStyle = halo;
        ctx.beginPath();
        ctx.arc(bx, by, 42, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }

      // ── The Bindu ─────────────────────────────────────────────
      const pulse = 0.5 + 0.5 * Math.sin(t * 2.6);
      const dotR  = (dimmed ? 2.5 : 4.2) + pulse * (dimmed ? 0.5 : 1.8);

      // Outer glow
      ctx.save();
      ctx.fillStyle  = `hsl(${hue}, 64%, 72%)`;
      ctx.shadowColor = `hsl(${hue}, 75%, 70%)`;
      ctx.shadowBlur  = (dimmed ? 5 : 16) + pulse * 12;
      ctx.beginPath();
      ctx.arc(bx, by, dotR, 0, Math.PI * 2);
      ctx.fill();
      // White hot center
      ctx.fillStyle  = 'rgba(255,255,255,0.90)';
      ctx.shadowBlur = 0;
      ctx.beginPath();
      ctx.arc(bx, by, dotR * 0.3, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    };

    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [hue, speed, beat, dimmed]);

  return (
    <canvas
      ref={cvs}
      style={{ width: '100%', height: '100%', display: 'block' }}
    />
  );
}

Object.assign(window, { BinduLissajous });
