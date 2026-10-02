import { writeFile } from 'node:fs/promises';

const seconds = 34;
const rate = 48000;
const frames = seconds * rate;
const samples = Buffer.alloc(frames * 4);
let noiseSeed = 1729;
const rand = () => { noiseSeed = (1664525 * noiseSeed + 1013904223) >>> 0; return noiseSeed / 4294967296; };
function envelope(t, a, b, rise = .15, fall = .5) {
  if (t < a || t > b) return 0;
  return Math.min(1, (t - a) / rise, (b - t) / fall);
}
for (let i = 0; i < frames; i++) {
  const t = i / rate;
  const opening = envelope(t, 0, 8, 1.4, 1.3);
  const middle = envelope(t, 8, 26, 1.4, 1.5);
  const closing = envelope(t, 26, 34, 1.3, 2.0);
  const chord = Math.sin(2 * Math.PI * 146.83 * t) * .18 + Math.sin(2 * Math.PI * 220 * t) * .13 + Math.sin(2 * Math.PI * 293.66 * t) * .08;
  const breath = (rand() * 2 - 1) * .035;
  let pulse = 0;
  for (const beat of [1.1, 4.25, 8.9, 10.1, 11.4, 12.6, 14, 15.25, 16.5, 18.4, 26.4, 29.4]) {
    const dt = t - beat;
    if (dt >= 0 && dt < .55) pulse += Math.sin(2 * Math.PI * (72 - 30 * dt) * dt) * Math.exp(-11 * dt) * .35;
  }
  const amp = opening * .55 + middle * .75 + closing * .63;
  const v = Math.max(-1, Math.min(1, (chord + breath) * amp + pulse));
  const pan = .09 * Math.sin(t * .4);
  samples.writeInt16LE(Math.round(v * (1 - pan) * 32767), i * 4);
  samples.writeInt16LE(Math.round(v * (1 + pan) * 32767), i * 4 + 2);
}
const header = Buffer.alloc(44);
header.write('RIFF', 0); header.writeUInt32LE(36 + samples.length, 4); header.write('WAVEfmt ', 8);
header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(2, 22);
header.writeUInt32LE(rate, 24); header.writeUInt32LE(rate * 4, 28); header.writeUInt16LE(4, 32); header.writeUInt16LE(16, 34);
header.write('data', 36); header.writeUInt32LE(samples.length, 40);
await writeFile(new URL('./score.wav', import.meta.url), Buffer.concat([header, samples]));
