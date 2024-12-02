import { Chromatiq } from "./chromatiq";
import { mix, clamp, saturate, Vector3, remap, remapFrom, remapTo, easeInOutCubic, easeInOutCubicVelocity, fbm } from "./math";

// for Webpack DefinePlugin
declare const PRODUCTION: boolean;

export const initBpm = 80;  // BPM
export const chromatiq = new Chromatiq(
  178.703, // デモの長さ（秒）
  require("./shaders/build-in/vertex.glsl").default,

  // Image Shaders
  require("./shaders/common-header.glsl").default,
  [
    // require("./shaders/raymarching-mandel.glsl").default,
    require("./shaders/raymarching-sessions2024.glsl").default,
    require("./shaders/raymarching-transparent.glsl").default,
    require("./shaders/raymarching-cloud.glsl").default,
    require("./shaders/text-sessions2024.glsl").default,
    require("./shaders/post-effect.glsl").default,
    // require("./shaders/effects/debug-circle.glsl").default,
  ],

  // Bloom
  4, // 無効化するなら -1
  5,
  require("./shaders/build-in/bloom-prefilter.glsl").default,
  require("./shaders/build-in/bloom-downsample.glsl").default,
  require("./shaders/build-in/bloom-upsample.glsl").default,
  require("./shaders/build-in/bloom-final.glsl").default,

  // Sound Shader
  require("./shaders/sound-test.glsl").default,

  // Text Texture
  (gl) => {
    const canvas = document.createElement("canvas");
    const textCtx = canvas.getContext("2d");
    // window.document.body.appendChild(canvas);

    // 128 * 27  px
    const texts = [
      // 0-4: タイトルとクレジット
      "GUARDI" + String.fromCharCode(0x25B2) + "N",
      "GRAPHICS",
      "gam0022",
      "MUSIC",
      "HADHAD",

      // 5-9: 戦闘機用
      "Renard",
      "sadakkey",
      "kaneta",
      "setchi",
      "FL1NE",

      // 10-26: 天使たち
      "AROMA",
      "MIKAN",

      "SACHIEL",
      "SHAMSHEL",
      "RAMIEL",
      "GAGHIEL",
      "ISRAFEL",
      "SANDALPHON",
      "MATRIEL",
      "SAHAQUIEL",
      "IREUL",
      "LELIEL",
      "BARDIEL",
      "ZERUEL",
      "ARAEL",
      "ALMISAEL",
      "TABRIS",
    ];

    const greetings = [
      "_baku89",
      "0b5vr",
      "0x4015 & YET1",
      "AFWD",
      "Alcatraz",
      "Aldroid ",
      "anticore",
      "AriakeShima",
      "birth_freedial",
      "butadiene121",
      "c5h12",
      "Callisto / Gpo^Flush^Vital motion",
      "Celken",
      "chirality ",
      "ciosai_tw",
      "Conspiracy",
      "Crimson_Apple",
      "Ctrl-Alt-Test",
      "d0117_0",
      "DESiRE ",
      "Die Kantorei",
      "Dilik",
      "DJ SHARPNEL",
      "doxas",
      "ewaldhew",
      "Exca",
      "Fairlight",
      "Farbrausch",
      "Filippp",
      "FL1NE",
      "Flashira / Frontation",
      "Flopine",
      "fotfla",
      "Futuris",
      "gaz",
      "h013",
      "hacha",
      "Haru86",
      "hiyohiyo",
      "I.C.U.P.",
      "Ivan Dianov",
      "jaezu",
      "jirohcl",
      "Jugem_T",
      "kaiware007",
      "Kamoshika",
      "kaneta",
      "kazpulse",
      "kinankomoti",
      "kioku",
      "kostik",
      "LJ",
      "logicoma",
      "Los Pat Moritas",
      "lox",
      "Machia",
      "machiaworks",
      "MERCURY",
      "mikkabouzu",
      "minimalartifact",
      "moistpeace",
      "monnokazue",
      "MoscowMule",
      "mrdoob",
      "Murasaqi",
      "Musk",
      "New-C-Rex",
      "nikhotmsk",
      "Niko_14",
      "nikq",
      "Nunu",
      "NuSan",
      "Peregrine",
      "phi16",
      "Polarity",
      "Poo-Brain",
      "prakashph",
      "Prismbeings",
      "rakurai",
      "Reflex",
      "Renard",
      "RGBA & TBC",
      "RIKUPI-X",
      "rimina",
      "sadakkey",
      "SainaKey",
      "setchi",
      "Shampagne",
      "shivaduke",
      "Shoch0922",
      "sola_117",
      "soma_arc",
      "sp4ghet",
      "spaztron64 & ShinkoNet",
      String.fromCharCode(0x00bd) + "-bit Cheese",
      "Superogue ",
      "SystemK",
      "TheDuccinator",
      "tktk",
      "TOCHKA",
      "tokkyo",
      "totetmatt",
      "TsumikiRoom",
      "TYA-PA-",
      "ukeyshima",
      "ukonpower",
      "uma_helmet",
      "Virtua Point Zero",
      "visy ",
      "W0NYV",
      "wbcbz7",
      "wrighter",
      "yahagi_day",
      "ymg",
      "yumcyawiz",
      "Zavie",
      String.fromCharCode(0x72EC, 0x697D, 0x56DE, 0x3057) + "eddy",
    ];

    canvas.width = 2048;
    canvas.height = 8096;
    textCtx.clearRect(0, 0, canvas.width, canvas.height);

    textCtx.fillStyle = "black";
    textCtx.fillRect(0, 0, canvas.width, canvas.height);

    textCtx.font = "110px arial";
    textCtx.textAlign = "center";
    textCtx.textBaseline = "middle";
    textCtx.fillStyle = "white";
    texts.forEach((text, index) => {
      textCtx.fillText(text, canvas.width / 2, 64 + index * 128);
    });

    textCtx.font = "40px arial";

    for (let i = 0; i < greetings.length / 3; i++) {
      for (let j = 0; j < 3; j++) {
        const index = i * 3 + j;
        textCtx.fillText(greetings[index], canvas.width / 2 + 700 * (j - 1), 128 * texts.length + 350 + i * 100);
      }
    }

    textCtx.font = "70px arial";
    textCtx.fillText("GREETINGS", canvas.width / 2, 128 * texts.length + 100);
    textCtx.fillText(String.fromCharCode(0x25B2) + "LL @ SESSIONS 2024", canvas.width / 2, 128 * texts.length + 550 + 100 * (greetings.length / 3));

    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, canvas);
    gl.generateMipmap(gl.TEXTURE_2D);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return tex;
  }
);

class Timeline {
  begin: number;
  done: boolean;

  constructor(public input: number) {
    this.begin = 0;
    this.done = false;
  }

  then(end: number, event: (offset: number, rate: number) => void): Timeline {
    if (this.done || this.input < this.begin) {
      return this;
    }

    if (this.input >= end) {
      this.begin = end;
      return this;
    }

    const offset = this.input - this.begin;
    const duration = end - this.begin;
    event(offset, offset / duration);
    this.done = true;
    return this;
  }

  over(event: (offset: number) => void): Timeline {
    if (this.done) {
      return this;
    }

    event(this.input - this.begin);
    this.done = true;
    return this;
  }
}

export const animateUniforms = (time: number, debugCamera: boolean, debugDisableReset: boolean): void => {
  let beat = (time * initBpm) / 60;
  let camera = new Vector3(0, 0, 10);
  let target = new Vector3(0, 0, 0);
  let bpm = initBpm;

  // reset values
  chromatiq.uniformArray.forEach((uniform) => {
    // debug時は値の毎フレームリセットをしない
    if (!PRODUCTION) {
      if (debugDisableReset) return;
      if (debugCamera && uniform.key.includes("gCamera")) return;
      if (uniform.key === "gBeat" || uniform.key === "gBPM") return;
    }

    chromatiq.uniforms[uniform.key] = uniform.initValue;
  });

  // これ以降にタイムライン処理を書く
  new Timeline(time)
    .then(33, t => {
      bpm = 80;
      beat = t * bpm / 60;
    })
    .then(60 + 45, t => {
      bpm = 130;
      beat = t * bpm / 60 + 44;
    })
    .then(147.666, t => {
      bpm = 180;
      beat = t * bpm / 60 + 200;
    })
    .then(178.703, t => {
      bpm = 80;
      beat = t * bpm / 60 + 328;
    })
    .over(t => {
      bpm = 80;
      beat = t * bpm / 60 + 364;
    });

  chromatiq.uniforms.gBeat = beat;
  chromatiq.uniforms.gBPM = bpm;
  const beatTau = beat * Math.PI * 2;

  new Timeline(beat)
    .then(8, (t, r) => {
      // 0-8
      // 雲が下がり、天界が現れる
      camera = new Vector3(4.1490156637056055, 1.0968469279843944, -11.353784659725086).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.016955454750722403, 0.14793101675967354, 0.501058853108791);
      chromatiq.uniforms.gCameraFov = 40 - 0.5 * t;
      chromatiq.uniforms.gCloudHeight = mix(0.7, -0.9, r);
      chromatiq.uniforms.gCloudSpeed = 0.5;
    })
    .then(12, (t, r) => {
      // 8-12
      // 天界をゆっくり映す、上にパン
      var pan = new Vector3(0, 0.07 + 0.01 * t, 0);
      camera = new Vector3(0.5883591660612857, 0.10203406202581011, -4.336503476625776).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-1.005859797144463, -0.8048280190594688, 2.6203543580318014).add(camera);
      chromatiq.uniforms.gCameraFov = 38;
      chromatiq.uniforms.gCloudHeight = mix(0.0, 0.2, r);
    })
    .then(16, t => {
      // 12-16
      // 天界をゆっくり映す、右にパン
      var pan = new Vector3(0.01 * t, 0, 0);
      camera = new Vector3(-1.3634260346223213, 0.3289286293461975, -3.8304745798817974).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(0.7710197212562542, -0.8374311636162176, 2.688865312556434).add(camera);
      chromatiq.uniforms.gCameraFov = 38;
      chromatiq.uniforms.gCloudHeight = 0.0;
    })
    .then(24, t => {
      // 16-24
      // 天界をゆっくり映す、奥にパン
      var pan = new Vector3(0, 0, 0.01 * t);
      camera = new Vector3(1.3451020450332654, 0.4265453623988059, -3.88028568662969).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-0.6832839590262174, -0.43574021978182065, -1.2840699938762166).add(pan);
      chromatiq.uniforms.gCameraFov = 38;
      chromatiq.uniforms.gCloudHeight = 0.0;
    })
    .then(32, t => {
      // 28-32
      // 巨大なビルを見上げる
      var pan = new Vector3(0, 0.007 * t, 0);
      camera = new Vector3(0.7762015646847797, 0.18667372736253335, 2.590082972635911).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-2.016479763310498, -0.5062397407539351, -1.3945418659683448).add(camera).add(pan.scale(30 * easeInOutCubic(t / 8)));
      chromatiq.uniforms.gCameraFov = 38;
      chromatiq.uniforms.gCloudHeight = -0.1;
    })
    .then(36, (t, r) => {
      // 32-36
      // 地下に落下
      var pan = new Vector3(0, -2.5 * easeInOutCubic(r), 0);
      camera = new Vector3(0.10131840571789869, 0.7237780896903708, 2.43513514852811).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-0.19381820721716034, -0.12692619634252622, -0.9670370800538417).add(camera);
      chromatiq.uniforms.gCameraFov = 40;
      chromatiq.uniforms.gBlend = -remapFrom(t, 2, 4);
    })
    .then(44, (t, r) => {
      // 36-44
      // 溶岩の中心を遠くから眺める
      camera = new Vector3(-30.414387535624794, 1.208886712672777, 35.46309070547005).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0, 1.3, 0);
      chromatiq.uniforms.gCameraFov = 40 - 10 * easeInOutCubic(r * 2);
      chromatiq.uniforms.gBossPosY = 0.2 + 0.2 * Math.sin(beatTau / 8);
      chromatiq.uniforms.gBlend = -remapFrom(t, 2, 0);
    })
    .then(52, t => {
      // 44-52
      // BPM: 80 -> 130
      // ボスが成長するカット1
      target = new Vector3(0, 2, 0);
      camera = new Vector3(12 * Math.sin(t * Math.PI / 64 + 0.3), 0.7, -12 * Math.cos(t * Math.PI / 64 + 0.3)).add(Vector3.fbm(t).scale(0.01)).add(target);
      chromatiq.uniforms.gCameraFov = 40;
      chromatiq.uniforms.gBossPosY = 0.1 + 0.04 * t;
    })
    .then(60, t => {
      // 52-60
      // ボスが成長するカット2
      camera = new Vector3(-30.414387535624794, 1.208886712672777, 35.46309070547005).add(Vector3.fbm(t).scale(0.01));
      target = new Vector3(-0.26035536713600466, 0.9378391512667532, -0.0514174491045528);
      chromatiq.uniforms.gCameraFov = 40;
      chromatiq.uniforms.gBossPosY = 0.1 + 0.04 * (t + 8);
    })
    .then(68, t => {
      // 60-68
      // ボスが天界に移動、雲から顔を出す
      camera = new Vector3(1.015697439944079, 0.26856329350311603, 3.194015696080416).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(-0.1739156356938652, 0.03997550509389635, 4.204060038900983);
      chromatiq.uniforms.gCameraFov = 40 - t;
      chromatiq.uniforms.gBossPosY = mix(-0.15, 0.15, t / 16);
      chromatiq.uniforms.gBossPosZ = 4;

      target.y = chromatiq.uniforms.gBossPosY;
    })
    .then(76, t => {
      // 68-76 = 8
      // ボスが天界が天界の中心に向かって移動
      camera = new Vector3(0.6289319872711973, 0.31161288082395, 1.8296485320439615).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(-0.16262073673928468, 0.03875486207428894, 4.219007989769242);
      chromatiq.uniforms.gCameraFov = 40;
      chromatiq.uniforms.gBossPosY = 0.25;
      chromatiq.uniforms.gBossPosZ = mix(4, 3, t / 16);

      target.y = chromatiq.uniforms.gBossPosY;
      target.z = chromatiq.uniforms.gBossPosZ;
    })
    .then(84, (t, r) => {
      // 76-84 = 8
      // 戦闘機の出撃1
      camera = new Vector3(0.10520794198197293, 0.14594567981915546, -2.6349042345704783).add(Vector3.fbm(t).scale(0.001));
      // target = new Vector3(0, 0, 0);
      chromatiq.uniforms.gCameraFov = 40;

      chromatiq.uniforms.gFighterGroupPosY = mix(0.01, 0.05, easeInOutCubic(r));
      chromatiq.uniforms.gFighterGroupPosZ = -2.765;

      target.y = chromatiq.uniforms.gFighterGroupPosY;
      target.z = chromatiq.uniforms.gFighterGroupPosZ;

      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 1.46;

      chromatiq.uniforms.gCloudHeight = 0.3;
    })
    .then(92, (t, r) => {
      // 84-92 = 8
      // 戦闘機の出撃2
      camera = new Vector3(0.39360887299201974, 0.2320533691394181, -2.6318401869916643).add(Vector3.fbm(t).scale(0.001));
      // target = new Vector3(0, 0, 0);
      chromatiq.uniforms.gCameraFov = mix(10, 20, r);

      chromatiq.uniforms.gFighterGroupPosY = 0.05 + 0.05 * r;
      chromatiq.uniforms.gFighterGroupPosZ = -2.765 + 0.1 * r;

      target.y = chromatiq.uniforms.gFighterGroupPosY;
      target.z = chromatiq.uniforms.gFighterGroupPosZ;

      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gCloudHeight = mix(0.5, 0.2, r);
    })
    // .then(108, (t, r) => {
    //   // 92-108 = 16
    //   // 戦闘機の大群の出撃1
    //   chromatiq.uniforms.gFighterGroupPosZ = mix(-1.5, -1.4, r);
    //   var pan = new Vector3(0.1 * r, 0.03 * r, 0);
    //   target = new Vector3(0, 0.2, -1.2).add(pan);
    //   camera = new Vector3(0.3, 0.05, 0.2).add(target).add(Vector3.fbm(t).scale(0.001));
    //   chromatiq.uniforms.gCameraFov = mix(5, 30, r);

    //   chromatiq.uniforms.gBossPosY = 0.15;
    //   chromatiq.uniforms.gBossPosZ = 1.46;
    //   chromatiq.uniforms.gMotionBlur = 0;
    // })
    .then(100, (t, r) => {
      // 92-100 = 8
      // 戦闘機の大群の出撃1
      camera = new Vector3(0.3286409183831848, 0.2081418847419012, -1.025724148917415).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.26153162651606055, 0.19479044179417726, -1.081551264291201);
      chromatiq.uniforms.gCameraFov = mix(20, 35, r);

      chromatiq.uniforms.gFighterGroupPosZ = mix(-1.5, -1.4, r);
      // target.z = chromatiq.uniforms.gFighterGroupPosZ + 0.3;

      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gMotionBlur = 0;
    })
    .then(108, (t, r) => {
      // 100-108 = 8
      // 戦闘機の大群の出撃2
      camera = new Vector3(0.4565254859955332, 0.250176488494367, -1.060860747302358).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.36186610611673775, 0.24453569146779303, -1.1858573704750741);
      chromatiq.uniforms.gCameraFov = mix(40, 50, r);

      chromatiq.uniforms.gFighterGroupPosZ = mix(-1.5, -1.4, r);
      // target.z = chromatiq.uniforms.gFighterGroupPosZ;

      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gMotionBlur = 0;
    })
    .then(112, (t, r) => {
      // 108-112 = 4
      // 戦闘開始
      var a = easeInOutCubic(r);
      camera = new Vector3(0.9569849083338932, 0.10538987873824357 + 0.02 * a, -0.8059784805517212).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(-0.15292178315526947, 0.16312791530474327, 0.23201799782991506);
      chromatiq.uniforms.gCameraFov = mix(30, 35, a);

      chromatiq.uniforms.gFighterGroupPosZ = mix(-0.15, 0, r);
      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 0.55;
    })
    .then(128, t => {
      // 112-128
      // 戦闘機の攻撃
      camera = new Vector3(0.3521396961132017, 0.21872926328342923, 0.00796151574640172).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.22148730300588362, 0.19441097812607036, 0.21923801071625135);
      chromatiq.uniforms.gCameraFov = 40 + t;

      chromatiq.uniforms.gFighterGroupPosZ = -0.2;
      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 0.55;
    })
    .then(144, t => {
      // 128-144
      // 戦闘機の攻撃
      camera = new Vector3(1.318511195785962, 1.187587640960162, -0.5082985541038505).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.2244010806010996, 0.3353839813438386, 0.25090122193944875);
      chromatiq.uniforms.gCameraFov = 20 + t;

      chromatiq.uniforms.gFighterGroupPosZ = 0;
      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 0.55;
    })
    .then(150, t => {
      // 144-150
      // ピンチ
      var pan = new Vector3(0, 0, 0.01 * t);
      camera = new Vector3(0.7287323131667214, 0.6017210946462093, -1.9300953337998892).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-0.010157056059408342, 0.11745198344163901, 0.02605032199186473);
      chromatiq.uniforms.gCameraFov = 32 + t;

      chromatiq.uniforms.gFighterGroupPosZ = 0;
      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 0.55;
      chromatiq.uniforms.gCloudHeight = -0.7;
    })
    .then(162, t => {
      // 150-162
      // ピンチ
      camera = new Vector3(0.5925284396821858, 0.17559657845363058, 0.08645722197619565).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.137447990061727, 0.1425306622833842, 0.37040967737115676);
      chromatiq.uniforms.gCameraFov = 37 + t;

      chromatiq.uniforms.gFighterGroupPosZ = 0;
      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 0.55;
      chromatiq.uniforms.gBossEmissive = mix(2, 6, remapFrom(t, 0, 12));
    })
    .then(184, t => {
      // 162-184
      // 172-176: ボスのビーム乱射で戦闘機が全滅
      // 176-184: 余韻？
      var pan = new Vector3(0, 0, 0.02 * t);
      camera = new Vector3(0.9027724788680807, 0.6908531997751391, -0.8414048675965144).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(0.044367482273849845, 0.15203883161389553, 0.3102999060901639);
      chromatiq.uniforms.gCameraFov = 37 + t;

      chromatiq.uniforms.gFighterGroupPosZ = 0;
      chromatiq.uniforms.gBossPosY = 0.15;
      chromatiq.uniforms.gBossPosZ = 0.55;

      let emi = mix(6, 10, remapFrom(t, 0, 4));
      emi = mix(emi, 0, remapFrom(beat, 176, 178));
      chromatiq.uniforms.gBossEmissive = emi;

      if (beat < 168) {
        chromatiq.uniforms.gBossWingSpeed = 2;
      }
      else if (beat < 176) {
        chromatiq.uniforms.gBossWingSpeed = 4;
      }
      else {
        chromatiq.uniforms.gBossWingSpeed = 1;
      }
    })
    .then(200, t => {
      // 184-200
      // 悲しい音楽
      camera = new Vector3(0.6361788271820872, 0.5007125496953408, 0.6419374585984107).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(-0.017530907512146685, -0.0031504604838091714, -0.002766890200959478);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gFighterGroupPosZ = -0.2;
      chromatiq.uniforms.gGuardianPosY = mix(-0.5, 0, t / 16.);
      target.y = Math.max(target.y, chromatiq.uniforms.gGuardianPosY);
      chromatiq.uniforms.gBossWingSpeed = 0;
    })
    .then(216, t => {
      // 200-216
      // ガーディアンが上昇
      camera = new Vector3(0.40674250705959913, 0.06405314502448023, 0.7910462918202227).add(Vector3.fbm(t).scale(0.0003));
      target = new Vector3(-0.0053021436605017735, 0.052236671573974935, -0.006721153310921296);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gFighterGroupPosZ = -0.2;
      chromatiq.uniforms.gGuardianPosY = mix(0, 0.2, t / 16.);
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossWingSpeed = 0.5;
    })
    .then(232, t => {
      // 216-232
      // ガーディアン変形1
      camera = new Vector3(0.3565781031990457, 0.3229760946823658, 0.700940786474596).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0, 0.30, 0);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossEmissive = 6;

      chromatiq.uniforms.gGuardianIfsRotZ = mix(0.65, 0.56, easeInOutCubic(remapFrom(t, 0, 16)));
      chromatiq.uniforms.gBossWingSpeed = 0.5;
    })
    .then(248, t => {
      // 232-248
      // ガーディアン変形2
      target = new Vector3(0, 0.30, 0);
      camera = new Vector3(1 * Math.sin(t * Math.PI / 128 + 0.3), -0.1 + 0.01 * t, -1 * Math.cos(t * Math.PI / 128 + 0.3)).add(Vector3.fbm(t).scale(0.001)).add(target);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossEmissive = 6;

      chromatiq.uniforms.gGuardianIteration = mix(6, 8, easeInOutCubic(remapFrom(t, 0, 16)));
      chromatiq.uniforms.gGuardianIfsRotZ = 0.56;
      chromatiq.uniforms.gBossWingSpeed = 0.5;
    })
    .then(264, (t, r) => {
      // 264-248=16
      // ガーディアン変形3
      var pan = new Vector3(0, 0.01 * t, 0);
      camera = new Vector3(0.4103258350034801, 0.5200795536137296, 0.666833121363178).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(0.0342308810296187, 0.3259537491254461, 0.026786841137827717);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossEmissive = 6;

      chromatiq.uniforms.gGuardianIteration = 8;
      chromatiq.uniforms.gGuardianIfsRotZ = mix(0.56, 0.65, easeInOutCubic(remapFrom(t, 0, 16)));

      // チャージ
      const e = easeInOutCubic(r);
      chromatiq.uniforms.gGuardianChargePosZ = 0.12 * e;
      chromatiq.uniforms.gGuardianChargeRadius = e * 0.02;
      chromatiq.uniforms.gGuardianChargeBrightness = mix(0.4, 1, e);
      chromatiq.uniforms.gBossWingSpeed = 0.5;
    })
    .then(280, (t, r) => {
      // 280-264=16
      // ガーディアン発射の準備1
      var pan = new Vector3(0, 0, 0.02 * t);
      camera = new Vector3(1.4463773600031598, 0.6443200591994414, 1.500070430410814).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-0.1665650796557814, 0.28390746403789546, 0.13058171330095478);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gBossPosY = 0.3;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossEmissive = 6;

      chromatiq.uniforms.gGuardianIteration = 8;
      chromatiq.uniforms.gGuardianIfsRotZ = 0.65;

      chromatiq.uniforms.gGuardianChargePosZ = 0.2;
      chromatiq.uniforms.gGuardianChargeRadius = mix(0.02, 0.05, r);
      chromatiq.uniforms.gGuardianChargeBrightness = mix(1, 1.5, r);
      chromatiq.uniforms.gBossWingSpeed = 0.5;

      chromatiq.uniforms.gCloudHeight = -0.7;
    })
    .then(296, (t, r) => {
      // 296-280=16
      // ガーディアン発射の準備2
      var pan = new Vector3(0, 0.01 * t, 0);
      camera = new Vector3(1.1679609279134675, 0.5089960588357236, -1.258965041135092).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-0.20079253570820935, 0.26694990675996494, 0.7545348681571291).add(pan);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gBossPosY = 0.32;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossEmissive = 6;

      chromatiq.uniforms.gGuardianIteration = 8;
      chromatiq.uniforms.gGuardianIfsRotZ = 0.65;

      chromatiq.uniforms.gGuardianChargePosZ = 0.3;
      chromatiq.uniforms.gGuardianChargeRadius = mix(0.05, 0.1, r);
      chromatiq.uniforms.gGuardianChargeBrightness = 1.5;
      chromatiq.uniforms.gBossWingSpeed = 0.5;

      chromatiq.uniforms.gCloudHeight = -0.7;
    })
    .then(312, (t, r) => {
      // 312-296=16
      // ガーディアン発射の準備3
      var pan = new Vector3(0, 0.01 * t, 0);
      camera = new Vector3(0.896988194098362, 0.7322015336024654, 2.344642480326849).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(-0.4779126808898529, 0.05902671027996144, 0.36782234880991616).add(pan);
      chromatiq.uniforms.gCameraFov = 37;

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gBossPosY = 0.32;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      target.y = chromatiq.uniforms.gGuardianPosY + 0.1;
      chromatiq.uniforms.gBossEmissive = 6;

      chromatiq.uniforms.gGuardianIteration = 8;
      chromatiq.uniforms.gGuardianIfsRotZ = 0.65;

      chromatiq.uniforms.gGuardianChargePosZ = 0.3;
      chromatiq.uniforms.gGuardianChargeRadius = mix(0.1, 0.2, r);
      chromatiq.uniforms.gGuardianChargeBrightness = 1.5;
      chromatiq.uniforms.gBossWingSpeed = 0.5;

      chromatiq.uniforms.gCloudHeight = -0.7;
    })
    .then(328, (t, r) => {
      // 328-312=16
      // ガーディアン発射
      // ボスの体がバラバラに砕け散る
      camera = new Vector3(0.2255128681883477, 0.41599811240477513, 1.9473740975834108).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(-0.1030129773932712, 0.25904623564108065, 1.0217582621717909);
      chromatiq.uniforms.gCameraFov = mix(60, 38, easeInOutCubic(r));

      chromatiq.uniforms.gBossPosZ = 1.46;
      chromatiq.uniforms.gBossPosY = 0.32;
      chromatiq.uniforms.gGuardianPosY = 0.2;
      chromatiq.uniforms.gBossEmissive = 2;

      chromatiq.uniforms.gGuardianIteration = 8;
      chromatiq.uniforms.gGuardianIfsRotZ = 0.65;

      chromatiq.uniforms.gGuardianChargePosZ = 0.3;
      chromatiq.uniforms.gGuardianChargeRadius = t < 8 ? mix(0.2, 0.3, easeInOutCubic(t / 8)) : mix(0.3, 0.0, easeInOutCubic(saturate((t - 8) / 2)));
      chromatiq.uniforms.gGuardianChargeBrightness = 1.5;
      chromatiq.uniforms.gGlitchIntensity = remapFrom(t, 14, 16) * saturate(Math.sin(4 * t * Math.PI));

      chromatiq.uniforms.gBossIfsOffsetX = mix(1.79, 5.79, Math.pow(saturate(remap(t, 8, 16, 0, 1)), 3.));
      chromatiq.uniforms.gFlash = remapFrom(t, 12, 13);
      chromatiq.uniforms.gFlashSpeed = 30;
      chromatiq.uniforms.gBossWingSpeed = 0.5;

      chromatiq.uniforms.gCloudHeight = -0.7;
    })
    .then(344, (t, r) => {
      // 344-328=16
      // BPM変更、平和が戻った感じ
      // タイトルロゴ + クレジット
      camera = new Vector3(0.25941887099470284, 0.05360544026345058, -0.5573098133260462).add(Vector3.fbm(t).scale(0.0001));
      target = new Vector3(0.1895955929649168, 0.06407429882707884, -0.41725624859135374);
      chromatiq.uniforms.gCameraFov = mix(50, 60, r);

      chromatiq.uniforms.gGuardianPosY = 0.0;
      chromatiq.uniforms.gCloudHeight = mix(0.0, -0.1, r);
    })
    .then(352, t => {
      // 352-344=8
      // 左にパン
      var pan = new Vector3(-0.01 * t, 0, 0);
      camera = new Vector3(-1.3634260346223213, 0.3289286293461975, -3.8304745798817974).add(Vector3.fbm(t).scale(0.001)).add(pan);
      target = new Vector3(0.7710197212562542, -0.8374311636162176, 2.688865312556434).add(camera);
      chromatiq.uniforms.gCameraFov = 38;

      chromatiq.uniforms.gGuardianPosY = 0.0;
      chromatiq.uniforms.gCloudHeight = 0.0;

    })
    .then(360, (t, r) => {
      // 360-352=8
      // 天界の全体を映す
      camera = new Vector3(4.056362816201517, 1.4916691087030716, -3.846339729267867).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.3083362310731234, -0.10502872950562746, -0.29008143765527644);
      camera = new Vector3(4.056362816201517, 1.4916691087030716, -3.846339729267867).add(Vector3.fbm(t).scale(0.001));
      target = new Vector3(0.3083362310731234, -0.10502872950562746, -0.29008143765527644);
      chromatiq.uniforms.gCameraFov = mix(60, 40, r);
      chromatiq.uniforms.gGuardianPosY = 0.0;
      chromatiq.uniforms.gCloudHeight = 0.2;
    })
    .then(368, (t, r) => {
      // 368-360=8
      // 怪獣の体がピクピクしている描写とともに終了
      camera = new Vector3(0.27407179394828574, 0.1213481921600677, 0.5182301731977972).add(Vector3.fbm(t).scale(0.002));
      target = new Vector3(0.24758064643898853, 0.07899595887525789, 0.5541475614398711);
      chromatiq.uniforms.gCameraFov = 35.10919999999959 - t;

      chromatiq.uniforms.gBossIfsOffsetX = 4.49;
      chromatiq.uniforms.gBossPosX = 0.1;
      chromatiq.uniforms.gBossPosY = -0.045;
      chromatiq.uniforms.gBossPosZ = 0.48;
      chromatiq.uniforms.gBossEmissive = 4 * saturate(Math.sin(Math.PI * r));
      chromatiq.uniforms.gBossWingSpeed = 0;

      // chromatiq.uniforms.gGlitchIntensity = 0.01 * saturate(Math.sin(t * Math.PI));
      chromatiq.uniforms.gBlend = -remapFrom(t, 3, 4);

      chromatiq.uniforms.gGuardianPosY = 0.0;
      chromatiq.uniforms.gCloudHeight = 0.3;

    })
    .over(t => {
      // デモ終了後
      chromatiq.uniforms.gBlend = -1;
    });

  if (!PRODUCTION && debugCamera) {
    return;
  }

  chromatiq.uniforms.gCameraEyeX = camera.x;
  chromatiq.uniforms.gCameraEyeY = camera.y;
  chromatiq.uniforms.gCameraEyeZ = camera.z;
  chromatiq.uniforms.gCameraTargetX = target.x;
  chromatiq.uniforms.gCameraTargetY = target.y;
  chromatiq.uniforms.gCameraTargetZ = target.z;
};
