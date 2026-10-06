// fivex_drone NUI: goggles OSD + WebAudio motor synth (one voice per audible drone).
'use strict';

const $ = (id) => document.getElementById(id);

/* ------------------------------------------------------------------ audio */

let ctx = null;
let master = null;
let noiseBuf = null;
const voices = new Map();

function audio() {
    if (!ctx) {
        ctx = new AudioContext();
        const comp = ctx.createDynamicsCompressor();
        master = ctx.createGain();
        master.gain.value = 0.6;
        master.connect(comp);
        comp.connect(ctx.destination);
        noiseBuf = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
        const ch = noiseBuf.getChannelData(0);
        let b = 0;
        for (let i = 0; i < ch.length; i++) {
            b = 0.97 * b + 0.03 * (Math.random() * 2 - 1); // soft "air" noise
            ch[i] = b * 6 + (Math.random() * 2 - 1) * 0.15;
        }
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
}

// four motors (slightly detuned saws), a whine harmonic, prop wash noise and a lost-drone beeper
class Voice {
    constructor() {
        const c = ctx;
        this.pan = c.createStereoPanner();
        this.pan.connect(master);
        this.out = c.createGain();
        this.out.gain.value = 0;
        this.out.connect(this.pan);
        this.lp = c.createBiquadFilter();
        this.lp.type = 'lowpass';
        this.lp.Q.value = 0.8;
        this.lp.connect(this.out);

        this.motors = [-1, -0.35, 0.35, 1].map((s) => {
            const o = c.createOscillator();
            o.type = 'sawtooth';
            const g = c.createGain();
            g.gain.value = 0.15;
            o.connect(g);
            g.connect(this.lp);
            o.start();
            return { o, s, w: Math.random() * 6.28 };
        });

        this.whine = c.createOscillator();
        this.whine.type = 'triangle';
        const wg = c.createGain();
        wg.gain.value = 0.05;
        this.whine.connect(wg);
        wg.connect(this.lp);
        this.whine.start();

        this.noise = c.createBufferSource();
        this.noise.buffer = noiseBuf;
        this.noise.loop = true;
        this.bp = c.createBiquadFilter();
        this.bp.type = 'bandpass';
        this.bp.Q.value = 0.6;
        this.ng = c.createGain();
        this.ng.gain.value = 0;
        this.noise.connect(this.bp);
        this.bp.connect(this.ng);
        this.ng.connect(this.out);
        this.noise.start();

        this.beepG = c.createGain();
        this.beepG.gain.value = 0;
        this.beepG.connect(this.pan);
        this.beep = c.createOscillator();
        this.beep.type = 'square';
        this.beep.frequency.value = 2700;
        this.beep.connect(this.beepG);
        this.beep.start();
        this.nextBeep = 0;
    }

    update(v, rpm) {
        const t = ctx.currentTime;
        const m = Math.max(0, Math.min(1, v.m));
        const f = ((rpm[0] + (rpm[1] - rpm[0]) * m) / 60) * rpm[2] * v.dop;
        for (const k of this.motors) {
            const hz = f * (1 + k.s * (0.006 + 0.04 * v.a) + 0.003 * Math.sin(t * 3 + k.w));
            k.o.frequency.setTargetAtTime(hz, t, 0.03);
        }
        this.whine.frequency.setTargetAtTime(f * 3.5, t, 0.03);

        const on = m > 0.02 ? 0.2 + 0.8 * m : 0;
        const air = 1 / (1 + v.d / 45); // distance eats the highs
        this.out.gain.setTargetAtTime(v.g * on, t, 0.05);
        this.lp.frequency.setTargetAtTime(Math.max(200, (700 + 6500 * m) * air), t, 0.05);
        this.bp.frequency.setTargetAtTime(250 + 2200 * m, t, 0.05);
        this.ng.gain.setTargetAtTime(0.35 + 0.5 * m, t, 0.05);
        this.pan.pan.setTargetAtTime(v.p, t, 0.05);

        if (v.b && t >= this.nextBeep) {
            const g = Math.min(1, v.g * 5) * 0.25;
            for (const at of [0.02, 0.22]) {
                this.beepG.gain.setValueAtTime(g, t + at);
                this.beepG.gain.setValueAtTime(0, t + at + 0.12);
            }
            this.nextBeep = t + 1.4;
        }
    }

    stop() {
        const t = ctx.currentTime;
        this.out.gain.setTargetAtTime(0, t, 0.05);
        this.beepG.gain.cancelScheduledValues(t);
        this.beepG.gain.setValueAtTime(0, t);
        setTimeout(() => {
            for (const k of this.motors) k.o.stop();
            this.whine.stop();
            this.noise.stop();
            this.beep.stop();
            this.pan.disconnect();
        }, 400);
    }
}

function setVoices(list, volume, rpm) {
    audio();
    master.gain.setTargetAtTime(volume, ctx.currentTime, 0.1);
    const seen = new Set();
    for (const v of list) {
        if (!v) continue;
        seen.add(v.id);
        let voice = voices.get(v.id);
        if (!voice) {
            voice = new Voice();
            voices.set(v.id, voice);
        }
        voice.update(v, rpm);
    }
    for (const [id, voice] of voices) {
        if (!seen.has(id)) {
            voice.stop();
            voices.delete(id);
        }
    }
}

// short goggles / ESC sounds for the pilot
function tones(seq, type = 'square', vol = 0.12) {
    audio();
    let t = ctx.currentTime + 0.01;
    for (const [hz, dur, gap = 0.03] of seq) {
        if (hz > 0) {
            const o = ctx.createOscillator();
            const g = ctx.createGain();
            o.type = type;
            o.frequency.value = hz;
            g.gain.setValueAtTime(0, t);
            g.gain.linearRampToValueAtTime(vol, t + 0.005);
            g.gain.setValueAtTime(vol, t + dur - 0.01);
            g.gain.linearRampToValueAtTime(0, t + dur);
            o.connect(g);
            g.connect(master);
            o.start(t);
            o.stop(t + dur + 0.02);
        }
        t += dur + gap;
    }
}

function thud(vol, len, cutoff) {
    audio();
    const t = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = noiseBuf;
    const lp = ctx.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.value = cutoff;
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + len);
    src.connect(lp);
    lp.connect(g);
    g.connect(master);
    src.start(t, Math.random());
    src.stop(t + len + 0.05);
}

const SFX = {
    esc: () => tones([[1047, 0.12], [1319, 0.12], [1568, 0.2, 0.35], [1568, 0.08, 0.08], [1568, 0.08]], 'square', 0.08),
    connect: () => tones([[1568, 0.06]], 'square', 0.08),
    arm: () => tones([[880, 0.08], [1320, 0.12]], 'square', 0.1),
    disarm: () => tones([[1320, 0.08], [880, 0.12]], 'square', 0.1),
    click: () => tones([[2000, 0.03]], 'square', 0.06),
    bump: (v) => thud(0.5 * (v || 0.5), 0.1, 1400),
    crash: () => { thud(0.9, 0.4, 900); thud(0.4, 0.15, 4000); },
};

/* -------------------------------------------------------------------- OSD */

const osd = $('osd');
const cache = {};

function set(id, text) {
    if (cache[id] === text) return; // patch only what changed
    cache[id] = text;
    $(id).textContent = text;
}

function cls(id, name, on) {
    const key = id + '.' + name;
    if (cache[key] === on) return;
    cache[key] = on;
    $(id).classList.toggle(name, on);
}

function mmss(s) {
    s = Math.floor(s);
    return String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
}

let noiseLevel = 0;
let shown = false;

function showOsd(on) {
    if (on === shown) return;
    shown = on;
    osd.classList.toggle('hidden', !on);
    if (!on) noiseLevel = 0;
}

function updateOsd(d) {
    cls('batt', 'hidden', !d.batt);
    set('volt', d.volt.toFixed(1) + 'V');
    set('cell', d.cell.toFixed(2));
    cls('volt', 'low', d.low);
    set('mah', Math.round(d.mah) + 'mAh');
    set('time', mmss(d.time));
    set('lq', String(Math.round(d.lq)));
    set('mode', d.mode);
    set('thr', String(Math.round(d.thr)));
    set('tilt', String(d.tilt));
    set('alt', String(Math.round(d.alt)));
    set('spd', String(Math.round(d.spd)));
    set('home', String(Math.round(d.home)));
    set('warn', d.warn);
    set('kami', d.kami || '');
    cls('warn', 'blink', d.warn !== '');

    const k = window.innerHeight / 90;
    const tr = `rotate(${(-d.roll).toFixed(1)}deg) translateY(${(d.pitch * k).toFixed(0)}px)`;
    if (cache.hz !== tr) {
        cache.hz = tr;
        $('horizon').style.transform = tr;
    }
    noiseLevel = d.noise;
}

// analog video breakup: static + tearing bars, only drawn while there is noise
const canvas = $('noise');
const g2 = canvas.getContext('2d');
const img = g2.createImageData(canvas.width, canvas.height);

function drawNoise() {
    requestAnimationFrame(drawNoise);
    if (!shown) return;
    const n = noiseLevel;
    const op = n < 0.03 ? 0 : Math.min(1, Math.pow(n, 1.3) * 1.15);
    canvas.style.opacity = op;
    if (op === 0) return;
    const px = img.data;
    const w = canvas.width;
    let bar = -1;
    for (let y = 0; y < canvas.height; y++) {
        if (Math.random() < 0.02 * n) bar = 6 + Math.random() * 20;
        const tear = bar-- > 0 ? 90 : 0;
        for (let x = 0; x < w; x++) {
            const i = (y * w + x) * 4;
            const v = Math.min(255, Math.random() * 255 + tear);
            px[i] = px[i + 1] = px[i + 2] = v;
            px[i + 3] = 255;
        }
    }
    g2.putImageData(img, 0, 0);
}
requestAnimationFrame(drawNoise);

/* ---------------------------------------------------------------- messages */

window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.t) return;
    switch (d.t) {
        case 'osd':
            showOsd(!!d.show);
            if (d.show && d.data) updateOsd(d.data);
            break;
        case 'voices':
            setVoices(d.list || [], d.volume ?? 0.6, d.rpm || [5000, 28000, 2]);
            break;
        case 'sfx':
            if (SFX[d.name]) SFX[d.name](d.v);
            break;
    }
});
