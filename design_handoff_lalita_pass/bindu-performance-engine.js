// Bindu Performance Engine — Score Data + Performer State
// Cross dance · Ameno (Scott Rill Remix) · 230.1s

const SCORE = {
  hue: 270,
  duration: 230.1,
  phases: [
    { start:0,   name:'Opening',            bg:[270,20,4]  },
    { start:30,  name:'First Reach',         bg:[272,22,5]  },
    { start:75,  name:'Descent',             bg:[268,18,4]  },
    { start:100, name:'Threshold Valley',    bg:[270,8,2]   },
    { start:145, name:'The Crossing',        bg:[275,28,7]  },
    { start:200, name:'Bells in the Dimness',bg:[270,20,5]  },
    { start:228, name:'Return',              bg:[268,18,6]  },
  ],
  beats: [
    { until:25,  hz:8.0  }, { until:75,  hz:7.0  }, { until:100, hz:7.5  },
    { until:130, hz:5.0  }, { until:145, hz:5.5  }, { until:161, hz:4.5  },
    { until:164, hz:7.83 }, { until:166, hz:2.69 }, { until:180, hz:4.5  },
    { until:200, hz:6.0  }, { until:228, hz:8.0  }, { until:230, hz:10.0 },
  ],
  silences: [
    { s:0,     e:4.5  }, { s:7.5,   e:9.5  }, { s:45.5,  e:47   },
    { s:100,   e:130  }, { s:205.5, e:210  },
  ],
  modulator: { rampIn:145, holdStart:160, holdEnd:180, rampOut:195, boost:0.8 },
  mirrorTimes: [25, 70, 115, 160, 210],
  mirrorWords: ['carry','bridge','threshold','cross','rise','stand','trust','ground','hold','love'],
  ensemble: {
    gaia:     { entry:14  },
    sid:      { entry:23  },
    arch:     { entry:31  },
    sakshi:   { entry:25  },
    ashrey:   { entry:0   },
    karishma: { mode:'inverse-energy' },
    shweta:   { firesAt:'peak', duration:2   },
    neev:     { firesAt:'threshold-bookends' },
    lalita:   { firesAt:'fruit-settled'      },
  },
  fruit: {
    core: `You gave this song "{w}". "{w}" reached and fell back. You waited inside the threshold together. "{w}" reached again, and the bells rang to say it had crossed.\n\nYou weren't crossing "{w}". "{w}" was already crossing through you.`,
    weaves: [
      { name:'motion', cases:{ still:'You were still.', swaying:'You were swaying.', moving:'You were moving.' } },
      { name:'count', first:'This is your first crossing.', after:'You have crossed {N} times.' },
    ],
    lalita: 'You have been one of the dancers.',
  },
};

// ── PERFORMER STATE ─────────────────────────────────────────────────
function computePhase(t) {
  let ph = SCORE.phases[0];
  for (const p of SCORE.phases) { if (t >= p.start) ph = p; else break; }
  return ph;
}

function computeBeat(t) {
  for (const b of SCORE.beats) { if (t < b.until) return b.hz; }
  return 10;
}

function computeModulator(t) {
  const m = SCORE.modulator;
  if (t < m.rampIn)    return 0;
  if (t < m.holdStart) return ((t - m.rampIn) / (m.holdStart - m.rampIn)) * m.boost;
  if (t < m.holdEnd)   return m.boost;
  if (t < m.rampOut)   return m.boost * (1 - (t - m.holdEnd) / (m.rampOut - m.holdEnd));
  return 0;
}

function isInSilence(t) {
  return SCORE.silences.some(s => t >= s.s && t < s.e);
}

function computeEnergy(t) {
  // Simulate song energy curve: quiet at Threshold Valley, peak at 160-166
  const base =
    t < 30  ? 0.3 + (t / 30) * 0.3 :
    t < 75  ? 0.5 + Math.sin(((t-30)/45)*Math.PI)*0.3 :
    t < 100 ? 0.5 - ((t-75)/25)*0.3 :
    t < 130 ? 0.15 + Math.sin(((t-100)/30)*Math.PI*2)*0.05 :
    t < 145 ? 0.2 + ((t-130)/15)*0.35 :
    t < 161 ? 0.55 + ((t-145)/16)*0.35 :
    t < 166 ? 0.92 :
    t < 180 ? 0.92 - ((t-166)/14)*0.4 :
    t < 210 ? 0.45 + Math.sin(((t-180)/30)*Math.PI)*0.2 :
              0.35 - ((t-210)/20)*0.15;
  return Math.max(0.05, Math.min(1, base));
}

function computeBeatPulse(t, beatHz) {
  const p = (t * beatHz) % 1;
  return Math.exp(-p * 6) * 0.7 + 0.15; // sharp attack, slow decay
}

function buildPerformer(t) {
  const phase    = computePhase(t);
  const beatHz   = computeBeat(t);
  const modulator = computeModulator(t);
  const inSilence = isInSilence(t);
  const energy   = inSilence ? 0.08 : computeEnergy(t);
  const beatPulse = computeBeatPulse(t, beatHz);
  const silenceDepth = inSilence ? 1 : 0;

  // Archetype presence (0-1)
  const ens = SCORE.ensemble;
  const g = (t,entry) => Math.min(1, Math.max(0,(t - (entry||0)) / 4));
  return {
    t, phase, beatHz, modulator, inSilence, silenceDepth, energy, beatPulse,
    bindu:    1,
    gaia:     g(t, ens.gaia.entry),
    sid:      g(t, ens.sid.entry),
    arch:     g(t, ens.arch.entry),
    sakshi:   g(t, ens.sakshi.entry),
    ashrey:   g(t, ens.ashrey.entry),
    karishma: inSilence ? 0.85 : Math.max(0, 1 - energy) * 0.5,
    shweta:   (t >= 160 && t <= 162) ? Math.min(1, (t-160)/0.5) * (1-Math.max(0,(t-161.5)/0.5)) : 0,
    neev:     (t < 4 || t > 228) ? 0.8 : 0,
    lalita:   t > 204 ? Math.min(1,(t-204)/3) : 0,
    isPeak:   t >= 160 && t <= 166,
  };
}

window.SCORE      = SCORE;
window.buildPerformer = buildPerformer;
