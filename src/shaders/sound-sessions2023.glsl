#version 300 es
precision mediump float;
uniform float iSampleRate;
uniform float iBlockOffset;

vec2 mainSound(int samp, float time);

out vec4 outColor;
void main() {
    float t = iBlockOffset + ((gl_FragCoord.x - 0.5) + (gl_FragCoord.y - 0.5) * 512.0) / iSampleRate;
    vec2 y = mainSound(int(iSampleRate), t);
    vec2 v = floor((0.5 + 0.5 * y) * 65536.0);
    vec2 vl = mod(v, 256.0) / 255.0;
    vec2 vh = floor(v / 256.0) / 255.0;
    outColor = vec4(vl.x, vh.x, vl.y, vh.y);
}

//--------------------
// ここから下を書き換える
//--------------------

// The code below is split into several parts.
// UTILS - Constants and hash functions and stuff
// WAVEFORMS - Basic noise and tone generators
// INSTRUMENTS - Stuff that makes notes
// PHRASES AND SONG PARTS - What to play, how to play it, up to the final mix.


///////////////////////////////
/////////// UTILS /////////////
///////////////////////////////

#define TAU (2.*3.1415926)
// Convert MIDI note number to cycles per second
#define midicps(n) (440.*exp(log(2.)*(n-69.)/12.))

float rand(float p)
{
    // Hash function by Dave Hoskins
    // https://www.shadertoy.com/view/4djSRW
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

vec2 rand2(float p)
{
    // Hash function by Dave Hoskins
    // https://www.shadertoy.com/view/4djSRW
	vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);
}

////////////////////////////////////
/////////// WAVEFORMS //////////////
////////////////////////////////////

float noise(float s){
    // Noise is sampled at every integer s
    // If s = t*f, the resulting signal is close to a white noise
    // with a sharp cutoff at frequency f.
    
    // For some reason float(int(x)+1) is sometimes not the same as floor(x)+1.,
    // and the former produces fewer artifacts?
    int si = int(floor(s));
    float sf = fract(s);
    sf = sf*sf*(3.-2.*sf); // smoothstep(0,1,sf)
    //sf = sf*sf*sf*(sf*(sf*6.0-15.0)+10.0); // quintic curve
    // see https://iquilezles.org/articles/texture
    return mix(rand(float(si)), rand(float(si+1)), sf) * 2. - 1.;
}

vec2 noise2(float s){
    int si = int(floor(s));
    float sf = fract(s);
    sf = sf*sf*(3.-2.*sf); // smoothstep(0,1,sf)
    return mix(rand2(float(si)), rand2(float(si+1)), sf) * 2. - 1.;
}


float coloredNoise(float t, float fc, float df)
{
    // Noise peak centered around frequency fc
    // containing frequencies between fc-df and fc+df
    
    // Assumes fc is an integer, to avoid problems with sin(large number).
    
    // Modulate df-wide noise by an fc-frequency sinusoid
    //float n1 = noise(t*df);
    //float n2 = noise(t*df - 100000.);
    //vec2 modul = vec2(cos(TAU*fc*t), sin(TAU*fc*t));
    return sin(TAU*fc*fract(t))*noise(t*df);
}

vec2 coloredNoise2(float t, float fc, float df)
{
    // Noise peak centered around frequency fc
    // containing frequencies between fc-df and fc+df
    vec2 noiz = noise2(t*df);
    vec2 modul = vec2(cos(TAU*fc*t), sin(TAU*fc*t));
    return modul*noiz;
}


float window(float a, float b, float t)
{
    return smoothstep(a, (a+b)*0.5, t) * smoothstep(b, (a+b)*0.5, t);
}

float formantSin(float phase, float form)
{
    // Inspired by the wavetable "formant" option
    // in software synthesizer Surge (super cool freeware synth!)
    phase = fract(phase);
    phase = min(phase*form, 1.);
    return sin(TAU*phase);
}
vec2 formantSin2(vec2 phase, vec2 form)
{
    // Inspired by the wavetable "formant" option
    // in software synthesizer Surge (super cool freeware synth!)
    phase = fract(phase);
    phase = min(phase*form, 1.);
    return sin(TAU*phase);
}


float lpfSaw(float t, float f, float fc, float Q)
{
    // Low-pass-filtered sawtooth wave
    // arguments are time, frequency, cutoff frequency, and resonance quality factor
    float omega_c = 2.*3.14159*fc/f; // relative
    t = f*t - floor(f*t);
    // Compute the exact response of a second order system with those parameters
    // (value and derivative are continuous)
    // It is expressed as
    // 1 - 2t + A exp(-omega_c*t/Q) * cos(omega_c*t+phi)
    // We need to compute the amplitude A and phase phi.
    float alpha = omega_c/Q, beta=exp(-alpha), c = cos(omega_c), s = sin(omega_c);
    float tanphi = (alpha*beta*c + beta*omega_c*s - alpha) / (omega_c + alpha*beta*s - beta*omega_c*c);
    // We could use more trigonometric identities to avoid computing the arctangent, but whatever.
    float phi = atan(tanphi);
    float A = -2./(cos(phi) - beta*cos(omega_c+phi));
    
    float v = 1.-2.*t + A*exp(-alpha*t) * cos(omega_c*t+phi);
    return v;
}

vec2 lpfSaw(float t, vec2 f, float fc, float Q)
{
    // Low-pass-filtered sawtooth wave
    // arguments are time, frequency, cutoff frequency, and resonance quality factor
    vec2 omega_c = 2.*3.14159*fc/f; // relative
    vec2 t2 = f*t - floor(f*t);
    // Compute the exact response of a second order system with those parameters
    // (value and derivative are continuous)
    // It is expressed as
    // 1 - 2t + A exp(-omega_c*t/Q) * cos(omega_c*t+phi)
    // We need to compute the amplitude A and phase phi.
    vec2 alpha = omega_c/Q, beta=exp(-alpha), c = cos(omega_c), s = sin(omega_c);
    vec2 tanphi = (alpha*beta*c + beta*omega_c*s - alpha) / (omega_c + alpha*beta*s - beta*omega_c*c);
    // We could use more trigonometric identities to avoid computing the arctangent, but whatever.
    vec2 phi = atan(tanphi);
    vec2 A = -2./(cos(phi) - beta*cos(omega_c+phi));
    
    vec2 v = 1.-2.*t2 + A*exp(-alpha*t2) * cos(omega_c*t2+phi);
    return v;
}


///////////////////////////////////
//////// INSTRUMENTS //////////////
///////////////////////////////////

vec2 hat1(float t)
{
    // Smooth hi-hat, almost shaker-like
    return coloredNoise2(t, 10000., 5000.) * smoothstep(0.,0.02,t) * smoothstep(0.06,0.01,t) * 0.1;
}

vec2 hat2(float t, float fc)
{
    // Short hi-hat with tuneable center frequency
    return coloredNoise2(t, fc, fc-1000.) * smoothstep(0.,0.001,t) * smoothstep(0.03,0.01,t) * 0.1;
}

vec2 snare1(float t)
{
    // Composite snare
    float body = (sin(TAU*t*250.) + sin(TAU*t*320.)) * smoothstep(0.1,0.0,t) * 1.;
    vec2 timbre = coloredNoise2(t, 1000., 7000.) * exp(-12.*t) * smoothstep(0.5,0.,t) * 8.;
    vec2 sig = (body+timbre) * smoothstep(0.,0.001,t);
    sig = sig/(1.+abs(sig)); // distort
    sig *= (1. + smoothstep(0.02,0.0,t)); // increase transient
    return sig * 0.1;
}

vec2 snare2(float t)
{
    // Basic noise-based snare
    float noi = coloredNoise(t, 4000., 1000.) + coloredNoise(t, 4000., 3800.) + coloredNoise(t,8000.,7500.) * 0.5;
    float env = smoothstep(0.,0.001,t) * smoothstep(0.2,0.05,t);
    env *= (1. + smoothstep(0.02,0.0,t)); // increase transient
    env *= (1. - 0.5*window(0.02,0.1,t)); // fake compression
    vec2 sig = vec2(noi) * env;
    sig = sig/(1.+abs(sig));
    return sig * 0.1;
}

float kick1(float t)
{
    // Composite kick
    
    // Kick is composed of a decaying sine tone, and a burst of noise,
    // all of it distorted and shaped with a nice envelope.
    
    // frequency is assumed to be f0 + df*exp(-t/dftime);
    float f0 = 50., df=500., dftime=0.02;
    float phase = TAU * (f0*t - df*dftime*exp(-t/dftime));
    float body = sin(phase) * smoothstep(0.15,0.,t) * 2.;
    float click = coloredNoise(t, 8000., 2000.) * smoothstep(0.01,0.0,t);
    //float boom = sin(f0*TAU*t) * smoothstep(0.,0.02,t) * smoothstep(0.15,0.,t);
    float sig = body + click;
    sig = sig/(1.+abs(sig));
    //sig += boom;
    sig *= (1. + smoothstep(0.02,0.0,t)); // increase transient
    sig *= (1. + window(0.05,0.15,t)); // increase tail
    return sig * 0.2;
}

vec2 bass1(float t, float f, float cutoff)
{
    // Composite bass
    // (I'm very happy about this one!)
    
    // "Cutoff" is not actually the cutoff frequency of a filter,
    // but it controls the amount of high frequencies
    // we bring in using the "formantSin" waveform.
    cutoff *= exp(-t*5.);
    float formant = max(cutoff/f, 1.);
    // Pure sine tone
    float funda = sin(TAU*f*t);
    // Phase-modulated sine gives more "body" to the sound
    float body = sin(2.*TAU*f*t + (0.2*formant)*sin(TAU*f*t));
    // Gritty attack using a truncated sinusoid waveform
    // (dephased for stereo effect)
    vec2 highs = formantSin2(f*t + vec2(0,0.5), vec2(formant)) * exp(-t*10.);
    vec2 sig = body + highs + funda;
    // Two-rate envelope with a strong transient and long decay
    sig *= (2.*exp(-t*20.) + exp(-t*2.));
    sig *= (1. + 0.3*smoothstep(0.05,0.0,t)); // increase transient
    
    // Finally, add some distortion
    //sig = sig / (1. + abs(sig)); // Feel free to try how this one sounds.
    sig = sin(sig); // This one gives lovely sidebands when pushed hard.
    return sig * 0.1;
}

vec2 pad1(float t, vec4 f, float fc, float Q)
{
    // Filtered sawtooth-based pad, playing four-note chords
    
    // f: frequencies of the four notes
    // fc, Q: cutoff frequency and quality factor of the 12dB/octave lowpass filter
    vec2 sig = vec2(0);
    sig += lpfSaw(t, f.x+vec2(-2,2), fc, Q);
    sig += lpfSaw(t, f.y+vec2(1.7,-1.7), fc, Q);
    sig += lpfSaw(t, f.z+vec2(-0.5,0.5), fc, Q);
    sig += lpfSaw(t, f.w+vec2(1.5,-1.5), fc, Q);
    return sig * 0.02;
}

vec2 arp1(float t, vec4 f, float fc, float dur)
{
    // Plucky arpeggiator, playing 16th notes.
    
    // dur: decay time of the notes (amplitude and filter)
    vec2 sig = vec2(0);
    vec4 ts = mod(t-vec4(0,0.125,0.25,0.375), 0.5);
    sig += lpfSaw(t, f.x, fc*exp(-ts.x/dur), 10.) * smoothstep(0.0,0.01,ts.x) * exp(-ts.x/dur);
    sig += lpfSaw(t, f.y, fc*exp(-ts.y/dur), 10.) * smoothstep(0.0,0.01,ts.y) * exp(-ts.y/dur);
    sig += lpfSaw(t, f.z, fc*exp(-ts.z/dur), 10.) * smoothstep(0.0,0.01,ts.z) * exp(-ts.z/dur);
    sig += lpfSaw(t, f.w, fc*exp(-ts.w/dur), 10.) * smoothstep(0.0,0.01,ts.w) * exp(-ts.w/dur);
    return sig * 0.04;
}

vec2 marimba1(float t, float f)
{
    // Simple phase-modulation based marimba
    
    vec2 sig = vec2(0);
    // Super basic marimba sound
    sig += sin(TAU*f*t + exp(-50.*t)*sin(TAU*7.*f*t)) * exp(-5.*t) * step(0.,t);
    // Fake reverb effect: long-decay, stereo-detuned fundamental
    sig += sin(TAU*(f+vec2(-2,2))*t) * exp(-1.5*t) * 0.5;
    return vec2(sig) * 0.05;
}

vec2 pad2(float t, vec4 f, float fres)
{
    // Four-note, phase-modulation-based pad.
    
    // fres: center frequency of the faked "spectral aliasing"
    
    vec2 sig = vec2(0);
    // Index of modulation
    // https://en.wikipedia.org/wiki/Frequency_modulation#Modulation_index
    vec4 iom1 = 2.+0.5*sin(t + vec4(0,1,2,3));
    // Play an octave lower than asked
    f *= 0.5;
    // Modulator has frequency 2f -> odd harmonics only
    sig += sin(TAU*t*f.x + iom1.x * sin(2.*TAU*t*(f.x+vec2(-1,1)))) * vec2(1,0);
    sig += sin(TAU*t*f.y + iom1.y * sin(2.*TAU*t*(f.y+vec2(-1.2,0.8)))) * vec2(0.7,0.3);
    sig += sin(TAU*t*f.z + iom1.z * sin(2.*TAU*t*(f.z+vec2(-0.5,1.5)))) * vec2(0.3,0.7);
    sig += sin(TAU*t*f.w + iom1.w * sin(2.*TAU*t*(f.w+vec2(-1.3,0.7)))) * vec2(0,1);
    
    // Fake spectral aliasing, to add some high-end
    vec2 warped = vec2(0);
    warped += sin(TAU*t*fres + 5.*sin(TAU*t*f.x)) * vec2(1,0);
    warped += sin(TAU*t*fres + 5.*sin(TAU*t*f.y)) * vec2(0.7,0.3);
    warped += sin(TAU*t*fres + 5.*sin(TAU*t*f.z)) * vec2(0.3,0.7);
    warped += sin(TAU*t*fres + 5.*sin(TAU*t*f.w)) * vec2(0,1);
    
    // Mix to taste
    sig = (sig + 0.01*warped) * 0.02;
    // Reduce stereo image
    sig = mix(sig.xy, sig.yx, 0.1);
    return sig;
}


////////////////////////////////////////////
/////// PHRASES AND SONG PARTS /////////////
////////////////////////////////////////////


float leadphrasenote(float t)
{
    // Four-bar lead synth phrase in the final chorus
    // MIDI note number (or 0. if silence)
    float note =
        (t<0.5) ? 69. : (t<1.) ? 71. : (t<1.5) ? 72. : (t<1.75) ? 76. :
        (t<3.0) ? 74. : (t<3.25) ? 0. : (t<3.5) ? 72. : (t<3.75) ? 74. :
        (t<5.5) ? 76. : (t<5.75) ? 79. : (t<7.5) ? 71. : 0.;
    return note;
}

vec2 leadphrase1(float t, float fc)
{
    // Four-bar lead synth phrase in the final chorus
    
    float note = leadphrasenote(t);
    // Add some vibrato
    float vibStrength = window(2.,3.,t) + window(4.,5.5,t) + window(6.,8.,t);
    float f = midicps(note + vibStrength*0.01*sin(5.*TAU*t)/(t+0.1));
    // Cut silence
    float env = (note > 0.) ? 1. : 0.;
    
    // "Super-saw" lead
    vec2 sig = lpfSaw(t, f+vec2(-2,2), fc, 1.);
    sig += lpfSaw(t, f+vec2(3.2,-3.2), fc, 1.);
    sig += lpfSaw(t, f, fc, 1.);
    
    // Distort
    sig *= 2.;
    sig = sig/(1.+abs(sig));
    
    return sig * 0.05 * env;
}

vec2 leadchorus(float t, float fc)
{
    // Four-bar lead synth phrase in the final chorus
    // Add delay effect
    vec2 sig = leadphrase1(t, fc);
    sig = mix(sig, sig.yx, 0.3);
    sig += leadphrase1(mod(t-0.25,8.), fc*0.7).yx * vec2(0.5,-0.5);
    sig += leadphrase1(mod(t-1., 8.), 1000.) * 0.5;
    return sig;
}

vec2 basschorus(float t, float fc)
{
    // Bass of the final chorus:
    // Simply play the fundamental of each bar, with octave jumps
    
    // Every second 8th note is an octave above
    float octave = 12.*step(0.25,mod(t,0.5));
    // Fundamental of each of the four bars
    float note = (t<2.) ? 69.-36.+octave : 
                 (t<4.) ? 62.-36.+octave :
                 (t<6.) ? 60.-36.+octave :
                 67.-36.+octave;
    
    float t1 = mod(t, 0.25);
    vec2 sig = bass1(t1, midicps(note), fc);
    
    return sig;
}

vec2 padchorus(float t, float fc, float Q)
{
    // Pad part for the final chorus
    // Simply play the (slightly rich) chords
    // ||: Am(add9) | Dm7 | C(add9) | G(add9) :||
    vec4 chord = (t<2.) ? vec4(57,60,64,71) : (t<4.) ? vec4(57,62,65,72) : (t<6.) ? vec4(60,62,64,67) : vec4(59,62,67,69);
    
    vec2 pad = pad1(t, midicps(chord), fc, Q);
    return pad;
}


vec2 arpchorus(float t, float fc, float dur)
{
    // Arpeggiator part for the final chorus
    // Simply arpeggiate the four chords
    vec4 chord = (t<2.) ? vec4(57,60,64,71) : (t<4.) ? vec4(57,62,65,72) : (t<6.) ? vec4(60,62,64,67) : vec4(59,62,67,69);
    vec2 arp = arp1(t, midicps(chord+12.), fc, dur);
    return arp;
}


vec2 fullChorus(float time)
{
    // Full mix for the final chorus
    time = mod(time, 8.);
    vec2 v = vec2(0);
    
    // Percussions (with a slight 16th-note swing)
    v += hat1(mod(time, 0.25)) * vec2(0.8,1.0);
    v += hat1(mod(time-0.14, 0.25)) * vec2(0.3,-0.2);
    v += snare1(mod(time-0.5, 1.));
    v += kick1(mod(time, 0.5));
    
    // Low-frequency oscillator on a macro control
    float cutoff = 300. + 200.*sin(time);
    
    float t = mod(time, 0.5);
    // Another LFO for fake sidechain compression ("pumping" effect)
    float pumping = mix(smoothstep(0.0,0.25,t), smoothstep(0.0,0.5,t), 0.2);
    
    v += basschorus(mod(time,8.), cutoff) *mix(pumping, 1.,0.3);
    
    vec2 pads = padchorus(mod(time, 8.), 8000.-1000.*sin(time), 2.);
    pads *= mix(pumping, 1., 0.1);
    v += pads;
    
    // A third LFO to vary the note length of the arpeggiator
    float dur = 0.2 * exp(0.2*sin(time*0.6));
    vec2 arp = arpchorus(mod(time, 8.), 5000.-1000.*cos(0.7*time), dur);
    v += arp * mix(pumping, 1.,0.2);
    
    v += leadchorus(mod(time,8.), 10000.) * mix(pumping,1.,0.5);
    
    return v;
}

vec2 padPhraseVerse(float time, float fc)
{
    // Pad during the verse: play three chords in four bars
    // ||: Am(add11) | FMaj7 | Em7 | Em7 :||
    float t = mod(time, 8.);
    vec4 chord = (t<2.) ? vec4(57,60,62,64) : (t<4.) ? vec4(53,57,60,64) : vec4(52,55,62,64);
    // Smoothe out the transitions from one chord to the next,
    // as they are not masked by percussion.
    float env = 1. - window(-0.1,0.1,t) - window(1.9,2.1,t) - window(3.9,4.1,t) - window(7.9,8.1,t);
    // Add some movement with volume automation
    env *= 1. + 0.2*window(0.25,0.5,mod(t,0.5));
    return pad1(t, midicps(chord), fc*0.7, 2.) * env;
}

vec2 padVerse(float time, float fc)
{
    // Verse pad with delay effect
    return padPhraseVerse(time, fc) + 0.5*padPhraseVerse(time-0.5,fc).yx + 0.2*padPhraseVerse(time-1.5,fc);
}

vec2 marimbaVerse(float t, float fc)
{
    // Marimba part for the verse:
    // just a few notes, always the same.
    vec2 v = vec2(0);
    v += marimba1(mod(t-0.00,8.), midicps(72.));
    v += marimba1(mod(t-0.75,8.), midicps(71.));
    v += marimba1(mod(t-1.50,8.), midicps(69.));
    v += marimba1(mod(t-2.25,8.), midicps(64.));
    v += marimba1(mod(t-7.50,8.), midicps(69.));
    v += marimba1(mod(t-7.75,8.), midicps(71.));
    return v;
}

vec2 arpVerse(float time, float fc, float dur)
{
    // Verse arpeggiator: just arpeggiate the chords
    // (different notes than the pad this time).
    // Cutoff frequency and note duration will be varied for tension.
    float t = mod(time, 8.);
    vec4 chord = (t<2.) ? vec4(57,64,69,71) : (t<4.) ? vec4(57,64,65,72) : vec4(59,64,69,74);
    return arp1(t, midicps(chord), fc, dur);
}

vec2 fullVerse(float time)
{
    vec2 v = vec2(0);
    // Cutoff frequency: dark sound initially,
    // but with a riser in the last four bars.
    float fc = 400. - 100.*cos(time) + 10000. * pow(clamp((time-24.)/(32.-24.),0.,1.), 4.);
    v += padVerse(time, fc) * 0.5;
    v += marimbaVerse(time, fc);
    if(time > 16.)
    {
        // Arpeggiator comes in after 8 bars, and note duration increases
        // during the riser.
        float dur = mix(0.05,0.5, smoothstep(24.,32.,time));
        v += arpVerse(time, fc, dur) * smoothstep(16.,18.,time);
    }
    return v;
}

vec2 bassDrop1(float time)
{
    // Groovy four-bar phrase of the bass during the drop.
    
    // (In fact, it is the only part of this song with
    // some melodic/rhythmic complexity and variation.
    // The rest is extremely mechanical.)
    
    vec2 v = vec2(0);
    
    time = mod(time, 8.);
    
    float sx = floor(time / 0.125); // sixteenth note number
    float st = mod(time, 0.125);
    bool isShort = true; // True for 16th note, false for 8th note
    vec2 nn = vec2(0.,0.); // note number, trigger short note
    nn = (sx == 0. || sx == 5. || sx==8.) ? vec2(33,1) : 
         (sx == 2.) ? vec2(48,1) :
         (sx == 3.) ? vec2(45,1) :
         (sx == 14.) ? vec2(35,1) :
         (sx == 15. || sx == 35.) ? vec2(36,1) :
         (sx == 16. || sx == 21. || sx == 24. || sx == 30. || sx == 31.) ? vec2(26,1) :
         (sx == 18.) ? vec2(41,1) :
         (sx == 19.) ? vec2(38,1) :
         (sx == 32. || sx == 37. || sx == 38. || sx == 40.) ? vec2(24,1) :
         (sx == 34.) ? vec2(40,1) :
         (sx == 46.) ? vec2(28,1) :
         (sx == 47.) ? vec2(29,1) :
         (sx == 48. || sx == 53. || sx == 54. || sx == 56. || sx == 57.) ? vec2(31,1) :
         (sx == 50.) ? vec2(47,1) :
         (sx == 51. || sx == 58.) ? vec2(43,1) :
         (sx == 60. || sx == 61.) ? vec2(32,1) :
         (sx == 62.) ? vec2(44,1) :
         vec2(0,0);
    
    
    if(sx == 30. || sx == 56. || sx == 60.)
    { // First half of 8th notes
        isShort = false;
    }
    if(sx == 31. || sx == 57. || sx == 61.)
    {  // Second half of 8th notes
        st += 0.125;
        isShort = false;
    }
    
    
    float fc = 400. + 50.*sin(TAU*time);
    v += bass1(st, midicps(nn.x), fc) * nn.y;
    
    // Decay end of note to avoid clicks
    if(isShort) v *= smoothstep(0.125,0.12,st);
    else v *= smoothstep(0.125,0.12,st-0.125);
    
    return v;
}

vec2 padDrop1(float time, float fres)
{
    // Pad part for the drop : uses pad2 (the phase-modulation based pad)
    vec2 v = vec2(0);
    
    float t = mod(time, 8.);
    // Very sparse choice of notes.
    // Chord transitions happen after the start of the bar.
    vec4 chord = (t < 2.75) ? vec4(69,72,69,72) : 
    (t < 4.75) ? vec4(69,72,69,74) : (t < 6.75) ? vec4(69,72,67,72) : vec4(69,72,69,71);
    // Funky automation to avoid boredom
    float env = (0.05 + window(0.,4.,t) + window(4.,8.,t)) * exp(-5.*mod(-t, 0.25));
    v += pad2(time, midicps(chord), fres) * env;
    
    return v;
}

vec2 fullDrop1(float time)
{
    // Full mix of the bass drop.
    vec2 v = vec2(0);
    float t = mod(time, 0.5);
    // Fake sidechain compression again
    float pumping = mix(smoothstep(0.0,0.25,t), smoothstep(0.0,0.5,t), 0.2);
    // Hi-hat timbre rises from "dull" to "harsh"
    float fhat = 5000. + 3000.*smoothstep(24.,32.,time);
    
    v += bassDrop1(time) * mix(pumping, 1., 0.8);
    v += kick1(mod(time, 0.5) + 0.008);
    
    v += padDrop1(time, 8000.) * mix(pumping, 1., 0.05);
    
    if(time > 8.)
    {
        // Snare comes in after 4 bars.
        v += snare2(mod(time-0.5, 1.));
    }
    if(time > 16.)
    {
        // Hi-hat comes in after 8 bars
        // Short hi-hat sound with fast attack and decay. Slight swing.
        v += hat2(mod(time, 0.25), fhat) * vec2(0.8,1.0) * 0.7;
        v += hat2(mod(time-0.14, 0.25), fhat) * vec2(0.3,-0.2) * 0.7;
    }
    return v;
}

vec2 fermata1(float time)
{
    // 2-bar fermata after verse
    vec2 v = vec2(0);
    // Let the last marimba note decay
    v += marimba1(time, midicps(69.));
    // Let the pad go from bright to dark
    float fc = 10000. * exp(-5.*smoothstep(0.,4.,time));
    v += pad1(time, midicps(vec4(57,60,62,64)), fc, 2.) * smoothstep(0.,0.1,time) * smoothstep(4.,0.,time);
    
    // Riser before drop:
    // Lots of low-frequency noise + a bit of high-frequency
    vec2 noise = (coloredNoise2(time, 250., 250.) + 0.1*coloredNoise2(time, 8000., 2000.)) * 0.2 * exp(-6.*smoothstep(4.,1.,time)) * smoothstep(4.,3.99,time);
    v += noise;
    
    return v;
}


vec2 teller1(float time)
{
    // 1-bar riser before chorus
    vec2 v = vec2(0);
    float t = mod(time, 0.5);
    float fc = 10000.*exp(2.*(time-2.));
    // Noise riser
    vec2 riser = coloredNoise2(time, fc*0.3, fc*0.3);
    v += riser * smoothstep(0.,2.,time) * 0.3 * exp((time-2.)*3.);
    // Announce the "middle A" played by the lead synth on the chorus
    vec2 teller = pad1(time, midicps(vec4(69)), fc, 2.);
    v += teller;
    return v;
}


vec2 verseTeller(float time)
{
    // Pre-announce the first note played by the marimba.
    float fC5 = midicps(72.);
    return (sin(TAU*(fC5+vec2(-2,2))*time) + 0.5*sin(TAU*(fC5+vec2(3,-3))*time)) * 0.1 * exp(-5.*(2.-time));
    
}

vec2 fullSong(float time)
{
    // Combine all parts of the song into a structured whole.
    
    vec2 v = vec2(0);
    
    if(0.<time && time < 2.)
    {
        v += verseTeller(time);
    }
    
    time -= 2.;
    
    if(0. < time && time < 32.)
    {
        v += fullVerse(time);
    }
        
    time -= 32.;
    
    if(0. < time && time < 4.)
    {
        v += padVerse(time, 10000.) * smoothstep(0.5,0.,time);
        v += fermata1(time);
    }
    
    time -= 4.;
    
    if(0. < time && time < 32.)
    {
        v += fullDrop1(time);
    }
    
    time -= 32.;
    
    if(0. < time && time < 4.)
    {
        v += bass1(time, midicps(33.), 400.);
        v += pad2(time, midicps(vec4(69,71,69,72)), 8000.) * (0.5 + 0.3*cos(2.*TAU*time)) 
             * smoothstep(0.,0.5,time) * smoothstep(4.,0.,time);
        v += verseTeller(time-2.);
    }
    
    time -= 4.;
    
    if(0. < time && time < 16.)
    {
        v += fullVerse(time+16.);
    }
    
    time -= 16.;
    
    if(0. < time && time < 4.)
    {
        v += fermata1(time);
        v += teller1(time-2.) * smoothstep(2.,4.,time);
    }
    
    time -= 4.;
    
    if(0. < time)
    {
        v += fullChorus(time) * smoothstep(48.,32.,time); // fade out on chorus
    }
    
    return v;
}

vec2 mainSound( int samp, float time )
{
    vec2 v = vec2(0);
    // v += fullSong(time);
    // v += bassDrop1(time);

    v += hat1(mod(time, 0.25)) * vec2(0.8,1.0);
    v += hat1(mod(time-0.14, 0.25)) * vec2(0.3,-0.2);
    v += snare1(mod(time, 1.));
    v += kick1(mod(time + 0.5, 1.));

    //v = fullChorus(time);
    //v += vec2(kick1(mod(time, 0.5)));
    
    //v = fullDrop1(time);
    
    // v += pad1(mod(time, 4.0), vec4(440.0, 200.0, 300.0, 660.) * (mod(time, 4.0) < 2. ? 1.0 : 2.0), 8000., 2.0);
    
    // Avoid clicks at the beginning
    return v * smoothstep(0.,0.01,time);
}
