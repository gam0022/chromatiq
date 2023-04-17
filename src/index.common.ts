import { Chromatiq } from "./chromatiq";
import { mix, clamp, saturate, Vector3, remap, remapFrom, remapTo, easeInOutCubic, easeInOutCubicVelocity } from "./math";

// for Webpack DefinePlugin
declare const PRODUCTION: boolean;

export const chromatiq = new Chromatiq(
  128, // デモの長さ（秒）
  require("./shaders/build-in/vertex.glsl").default,

  // Image Shaders
  require("./shaders/common-header.glsl").default,
  [
    // require("./shaders/raymarching-mandel.glsl").default,
    require("./shaders/raymarching-sessions2023.glsl").default,
    require("./shaders/post-effect.glsl").default,
    // require("./shaders/effects/debug-circle.glsl").default,
  ],

  // Bloom
  -1,// Disable Bloom
  5,
  require("./shaders/build-in/bloom-prefilter.glsl").default,
  require("./shaders/build-in/bloom-downsample.glsl").default,
  require("./shaders/build-in/bloom-upsample.glsl").default,
  require("./shaders/build-in/bloom-final.glsl").default,

  // Sound Shader
  require("./shaders/sound-sessions2023.glsl").default,

  // Text Texture
  (gl) => {
    const canvas = document.createElement("canvas");
    const textCtx = canvas.getContext("2d");
    // window.document.body.appendChild(canvas);

    // MAX: 4096 / 128 = 32
    const texts = [
      /* 0 */ "A 64K INTRO",
      /* 1 */ "GRAPHICS",
      /* 2 */ "gam0022",
      /* 3 */ "MUSIC",
      /* 4 */ "sadakkey",
      /* 5 */ "RE: SIMULATED",
      /* 6 */ "REALITY",

      // 7
      "MERCURY",

      // 8-12
      "RGBA & TBC",
      "Ctrl-Alt-Test",
      "Conspiracy",
      "Poo-Brain",
      "Fairlight",

      // 13
      "kaneta",

      // 14
      "FMS_Cat",

      // 15-20
      String.fromCharCode(0x00bd) + "-bit Cheese",
      "Prismbeings",
      "0x4015 & YET1",
      "LJ & Alcatraz",
      "logicoma",
      "Polarity",
    ];

    canvas.width = 2048;
    canvas.height = 4096;
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

    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, canvas);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
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

  then(length: number, event: (offset: number) => void): Timeline {
    if (this.done || this.input < this.begin) {
      return this;
    }

    if (this.input >= this.begin + length) {
      this.begin += length;
      return this;
    }

    event(this.input - this.begin);
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
  const bpm = 128;
  const beat = (time * bpm) / 60;

  let camera = new Vector3(0, 0, 10);
  let target = new Vector3(0, 0, 0);

  // reset values
  chromatiq.uniformArray.forEach((uniform) => {
    // debug時は値の毎フレームリセットをしない
    if (!PRODUCTION) {
      if (debugDisableReset) return;
      if (debugCamera && uniform.key.includes("gCamera")) return;
    }

    chromatiq.uniforms[uniform.key] = uniform.initValue;
  });

  /*
  new Timeline(beat % 128)
    .then(16 * 10000 , (t) => {
      camera = new Vector3(-6.21139322717302, 6.010495939159999, 22.503220238985616).add(Vector3.fbm(t).scale(0.01));
      target = new Vector3(5.343769275887814, -3.8719316266245003, -21.2988108700382).add(camera);
      chromatiq.uniforms.gCameraFov = 90 + 10 * Math.sin(t);

      // chromatiq.uniforms.gMandelboxScale = 2.88621239103946;
    })
    .over(() => {
      // デモ終了後
      // chromatiq.uniforms.gBlend = -1;
    });
  */

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
