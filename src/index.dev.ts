import { chromatiq, animateUniforms, initBpm } from "./index.common";

import { FolderApi, Pane } from 'tweakpane';
import { saveAs } from "file-saver";
import { bufferToWave } from "./buffer-to-wave";

import * as three from "three";
const THREE = require("three");
import "imports-loader?THREE=three!../node_modules/three/examples/js/controls/OrbitControls.js";

import Stats from "three/examples/jsm/libs/stats.module";

window.addEventListener(
  "load",
  () => {
    chromatiq.init();

    // CSS用のスタイルを追加
    chromatiq.canvas.setAttribute("id", "setAttribute");

    // play
    chromatiq.play();

    // config
    const config = {
      forceRender: false,
      debugCamera: false,
      debugParams: false,
      debugDisableReset: false,
      resolution: "1920x1080",
      timeMode: "time",
      bpm: initBpm,
    };

    // HTMLElements
    const fpsSpan = document.getElementById("fps-span");
    const stopButton = document.getElementById("stop-button") as HTMLInputElement;
    const playPauseButton = document.getElementById("play-pause-button") as HTMLInputElement;
    const frameDecButton = document.getElementById("frame-dec-button") as HTMLInputElement;
    const frameIncButton = document.getElementById("frame-inc-button") as HTMLInputElement;
    const timeInput = document.getElementById("time-input") as HTMLInputElement;
    const beatInput = document.getElementById("beat-input") as HTMLInputElement;
    const timeBar = document.getElementById("time-bar") as HTMLInputElement;
    const beatBar = document.getElementById("beat-bar") as HTMLInputElement;
    const timeLengthInput = document.getElementById("time-length-input") as HTMLInputElement;
    const beatLengthInput = document.getElementById("beat-length-input") as HTMLInputElement;
    const timeTickmarks = document.getElementById("time-tickmarks") as HTMLDataListElement;
    const beatTickmarks = document.getElementById("beat-tickmarks") as HTMLDataListElement;

    // consts
    const pauseChar = "\uf04c";
    const playChar = "\uf04b";

    // Common Functions
    const timeToBeat = (time: number): number => {
      return (time * config.bpm) / 60;
    };

    const beatToTime = (beat: number): number => {
      return (beat / config.bpm) * 60;
    };

    // OnUpdates
    const onResolutionCange = (): void => {
      const ret = config.resolution.match(/(\d+)x(\d+)/);
      if (ret) {
        // Fixed Resolution
        chromatiq.setSize(parseInt(ret[1]), parseInt(ret[2]));
      } else {
        // Scaled Resolution
        const resolutionScale = parseFloat(config.resolution);
        chromatiq.setSize(window.innerWidth * resolutionScale, window.innerHeight * resolutionScale);
      }

      chromatiq.needsUpdate = true;
    };

    const onTimeModeChange = (): void => {
      const isTimeMode = config.timeMode === "time";

      const timeDisplay = isTimeMode ? "block" : "none";
      timeInput.style.display = timeDisplay;
      timeLengthInput.style.display = timeDisplay;
      timeBar.style.display = timeDisplay;

      const beatDisplay = isTimeMode ? "none" : "block";
      beatInput.style.display = beatDisplay;
      beatLengthInput.style.display = beatDisplay;
      beatBar.style.display = beatDisplay;
    };

    const onTimeLengthUpdate = (): void => {
      timeBar.max = timeLengthInput.value;

      // tickmarksの子要素を全て削除します
      for (let i = timeTickmarks.childNodes.length - 1; i >= 0; i--) {
        timeTickmarks.removeChild(timeTickmarks.childNodes[i]);
      }

      // 1秒刻みにラベルを置きます
      for (let i = 0; i < timeLengthInput.valueAsNumber; i++) {
        const option = document.createElement("option");
        option.value = i.toString();
        option.label = i.toString();
        timeTickmarks.appendChild(option);
      }
    };

    const onBeatLengthUpdate = (): void => {
      beatBar.max = beatLengthInput.value;

      // tickmarksの子要素を全て削除します
      for (let i = beatTickmarks.childNodes.length - 1; i >= 0; i--) {
        beatTickmarks.removeChild(beatTickmarks.childNodes[i]);
      }

      // 4ビート刻みにラベルを置きます
      for (let i = 0; i < beatLengthInput.valueAsNumber; i += 4) {
        const option = document.createElement("option");
        option.value = i.toString();
        option.label = i.toString();
        beatTickmarks.appendChild(option);
      }
    };

    // THREE.OrbitControls
    const camera = new three.PerspectiveCamera(75, 1.0, 1, 1000);
    const controls = new THREE.OrbitControls(camera, chromatiq.canvas);

    // stats.js
    const stats = Stats();
    stats.showPanel(0); // 0: fps, 1: ms, 2: mb, 3+: custom
    document.body.appendChild(stats.dom);

    // dat.GUI
    // const gui = new GUI({ width: 400 });
    const pane = new Pane({
      title: 'Parameters',
    });
    //gui.useLocalStorage = true;

    const debugFolder = pane.addFolder({ title: "debug" });
    debugFolder.addBinding(config, "debugCamera").on("change", ev => {
      if (ev.value) {
        camera.position.x = chromatiq.uniforms.gCameraEyeX;
        camera.position.y = chromatiq.uniforms.gCameraEyeY;
        camera.position.z = chromatiq.uniforms.gCameraEyeZ;
        controls.target.x = chromatiq.uniforms.gCameraTargetX;
        controls.target.y = chromatiq.uniforms.gCameraTargetY;
        controls.target.z = chromatiq.uniforms.gCameraTargetZ;
      }

      chromatiq.needsUpdate = true;
    });
    debugFolder.addBinding(config, "debugParams").on("change", () => {
      chromatiq.needsUpdate = true;
    });
    debugFolder.addBinding(config, "debugDisableReset").on("change", () => {
      chromatiq.needsUpdate = true;
    });

    const arrayToKeyValueMap = (array: string[]) => {
      return array.reduce((acc: { [key: string]: string }, current) => {
        acc[current] = current;
        return acc;
      }, {});
    };

    const miscFolder = pane.addFolder({ title: "misc" });
    miscFolder.addBinding(config, "forceRender");
    miscFolder.addBinding(config, "resolution", {
      options: arrayToKeyValueMap(["0.5", "0.75", "1.0", "3840x2160", "2560x1440", "1920x1080", "1600x900", "1280x720", "512x512", "2160x2160", "2560x1280", "800x600"])
    }).on("change", () => {
      onResolutionCange();
    });
    miscFolder.addBinding(config, "timeMode", {
      options: arrayToKeyValueMap(["time", "beat"])
    }).on("change", () => {
      onTimeModeChange();
    });
    miscFolder.addBinding(config, "bpm", { min: 50, max: 300, step: 1 }).on("change", () => {
      beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
      onBeatLengthUpdate();
    });
    // NOTE: 使用頻度が低いのでmisc送りに
    miscFolder.addBinding(chromatiq, "debugFrameNumber", { min: -1, max: 30, step: 1 }).on("change", () => {
      chromatiq.needsUpdate = true;
    });

    const saveFunctions = {
      saveImage: (): void => {
        chromatiq.canvas.toBlob((blob) => {
          saveAs(blob, "chromatiq.png");
        });
      },
      saveImageSequence: (): void => {
        if (chromatiq.isPlaying) {
          chromatiq.stopSound();
        }

        chromatiq.isPlaying = false;
        chromatiq.needsUpdate = false;
        playPauseButton.value = playChar;

        const fps = 60;
        let frame = 0; // 途中からレンダリングする場合はここを書き換える
        const update = (): void => {
          const time = frame / fps;
          timeBar.valueAsNumber = time;
          timeInput.valueAsNumber = time;
          chromatiq.time = time;
          chromatiq.frame = frame;

          animateUniforms(time, config.debugCamera, config.debugDisableReset);
          chromatiq.render();

          const filename = `chromatiq${frame.toString().padStart(4, "0")}.png`;
          chromatiq.canvas.toBlob((blob) => {
            saveAs(blob, filename);

            if (frame <= Math.ceil(fps * timeLengthInput.valueAsNumber)) {
              requestAnimationFrame(update);
            }
          });

          frame++;
        };

        requestAnimationFrame(update);
      },
      saveSound: (): void => {
        const sampleLength = Math.ceil(chromatiq.audioContext.sampleRate * chromatiq.timeLength);
        const waveBlob = bufferToWave(chromatiq.audioSource.buffer, sampleLength);
        saveAs(waveBlob, "chromatiq.wav");
      },
      copyCamera: (): void => {
        const text = `camera = new Vector3(${camera.position.x}, ${camera.position.y}, ${camera.position.z}).add(Vector3.fbm(t).scale(0.001));
target = new Vector3(${controls.target.x}, ${controls.target.y}, ${controls.target.z});
chromatiq.uniforms.gCameraFov = ${chromatiq.uniforms.gCameraFov};`;
        navigator.clipboard.writeText(text).then(
          function () {
            console.log("copied to clipboard");
          },
          function () {
            console.log("failed to copy");
          }
        );
      },
      copyCamera2: (): void => {
        const text = `camera = new Vector3(${camera.position.x}, ${camera.position.y}, ${camera.position.z}).add(Vector3.fbm(t).scale(0.001));
target = new Vector3(${controls.target.x - camera.position.x}, ${controls.target.y - camera.position.y}, ${controls.target.z - camera.position.z}).add(camera);
chromatiq.uniforms.gCameraFov = ${chromatiq.uniforms.gCameraFov};`;
        navigator.clipboard.writeText(text).then(
          function () {
            console.log("copied to clipboard");
          },
          function () {
            console.log("failed to copy");
          }
        );
      },
      copyCameraGLSL: (): void => {
        const text = `ro = vec3(${camera.position.x}, ${camera.position.y}, ${camera.position.z});
target = vec3(${controls.target.x}, ${controls.target.y}, ${controls.target.z});
fov = ${chromatiq.uniforms.gCameraFov};`;
        navigator.clipboard.writeText(text).then(
          function () {
            console.log("copied to clipboard");
          },
          function () {
            console.log("failed to copy");
          }
        );
      },
    };

    debugFolder.addButton({ title: "copyCamera" }).on("click", saveFunctions.copyCamera);
    debugFolder.addButton({ title: "copyCamera2" }).on("click", saveFunctions.copyCamera2);
    debugFolder.addButton({ title: "copyCameraGLSL" }).on("click", saveFunctions.copyCameraGLSL);
    debugFolder.addButton({ title: "saveImage" }).on("click", saveFunctions.saveImage);
    debugFolder.addButton({ title: "saveImageSequence" }).on("click", saveFunctions.saveImageSequence);
    debugFolder.addButton({ title: "saveSound" }).on("click", saveFunctions.saveSound);

    const defaultFolders: { [index: string]: FolderApi } = {};
    defaultFolders["debug"] = debugFolder;
    defaultFolders["misc"] = miscFolder;

    const groupFolders: { [index: string]: FolderApi } = {};

    chromatiq.uniformArray.forEach((unifrom) => {
      let groupFolder = groupFolders[unifrom.group];
      if (!groupFolder) {
        groupFolder = pane.addFolder({ title: unifrom.group });
        groupFolders[unifrom.group] = groupFolder;
      }

      if (typeof unifrom.initValue === "number") {
        let option: any = {};

        if (unifrom.min != -1 || unifrom.max != -1) {
          option = { min: unifrom.min, max: unifrom.max };
        }

        groupFolder.addBinding(chromatiq.uniforms, unifrom.key, option).on("change", ev => {
          if (config.debugCamera) {
            switch (unifrom.key) {
              case "gCameraEyeX":
                camera.position.x = ev.value;
                break;
              case "gCameraEyeY":
                camera.position.y = ev.value;
                break;
              case "gCameraEyeZ":
                camera.position.z = ev.value;
                break;
              case "gCameraTargetX":
                controls.target.x = ev.value;
                break;
              case "gCameraTargetY":
                controls.target.y = ev.value;
                break;
              case "gCameraTargetZ":
                controls.target.z = ev.value;
                break;
            }
          }

          chromatiq.needsUpdate = true;
        });
      } else {
        let option: any = {};

        if (typeof unifrom.initValue === "object" && "r" in unifrom.initValue) {
          option.color = { type: 'float' };
        }

        groupFolder.addBinding(chromatiq.uniforms, unifrom.key, option).on("change", () => {
          chromatiq.needsUpdate = true;
        });
      }
    });

    // SessionStorage
    const saveToSessionStorage = (): void => {
      sessionStorage.setItem("gui", JSON.stringify(pane.exportState()));
      sessionStorage.setItem("forceRender", config.forceRender.toString());
      sessionStorage.setItem("debugCamera", config.debugCamera.toString());
      sessionStorage.setItem("debugParams", config.debugParams.toString());
      sessionStorage.setItem("debugDisableReset", config.debugDisableReset.toString());
      sessionStorage.setItem("resolution", config.resolution);
      sessionStorage.setItem("timeMode", config.timeMode);
      sessionStorage.setItem("bpm", config.bpm.toString());
      sessionStorage.setItem("debugFrameNumber", chromatiq.debugFrameNumber.toString());

      sessionStorage.setItem("time", chromatiq.time.toString());
      sessionStorage.setItem("isPlaying", chromatiq.isPlaying.toString());
      sessionStorage.setItem("timeLength", timeLengthInput.value);

      for (const [key, uniform] of Object.entries(chromatiq.uniforms)) {
        sessionStorage.setItem(key, JSON.stringify(uniform));
      }

      sessionStorage.setItem("paneExpanded", pane.expanded.toString());

      for (const [key, folder] of Object.entries(defaultFolders)) {
        sessionStorage.setItem("folderExpanded_" + key, folder.expanded.toString());
      }

      for (const [key, folder] of Object.entries(groupFolders)) {
        sessionStorage.setItem("folderExpanded_" + key, folder.expanded.toString());
      }
    };

    const loadFromSessionStorage = (): void => {
      const parseBool = (value: string): boolean => {
        return value === "true";
      };

      const guiStr = sessionStorage.getItem("gui");
      if (guiStr) {
        // pane.importState(JSON.parse(guiStr));
      }

      const resolutionStr = sessionStorage.getItem("resolution");
      if (resolutionStr) {
        config.resolution = resolutionStr;
      }
      onResolutionCange();

      const forceRenderStr = sessionStorage.getItem("forceRender");
      if (forceRenderStr) {
        config.forceRender = parseBool(forceRenderStr);
      }

      const debugCameraStr = sessionStorage.getItem("debugCamera");
      if (debugCameraStr) {
        config.debugCamera = parseBool(debugCameraStr);
      }

      const debugParamsStr = sessionStorage.getItem("debugParams");
      if (debugParamsStr) {
        config.debugParams = parseBool(debugParamsStr);
      }

      const debugDisableResetStr = sessionStorage.getItem("debugDisableReset");
      if (debugDisableResetStr) {
        config.debugDisableReset = parseBool(debugDisableResetStr);
      }

      const timeModeStr = sessionStorage.getItem("timeMode");
      if (timeModeStr) {
        config.timeMode = timeModeStr;
      }
      onTimeModeChange();

      const bpmStr = sessionStorage.getItem("bpm");
      if (bpmStr) {
        config.bpm = parseFloat(bpmStr);
      }

      const debugFrameNumberStr = sessionStorage.getItem("debugFrameNumber");
      if (debugFrameNumberStr) {
        chromatiq.debugFrameNumber = parseFloat(debugFrameNumberStr);
      }

      const timeStr = sessionStorage.getItem("time");
      if (timeStr) {
        chromatiq.time = parseFloat(timeStr);
      }

      const isPlayingStr = sessionStorage.getItem("isPlaying");
      if (isPlayingStr) {
        chromatiq.isPlaying = parseBool(isPlayingStr);
        playPauseButton.value = chromatiq.isPlaying ? pauseChar : playChar;
      }

      const timeLengthStr = sessionStorage.getItem("timeLength");
      if (timeLengthStr) {
        timeLengthInput.valueAsNumber = parseFloat(timeLengthStr);
      } else {
        timeLengthInput.valueAsNumber = chromatiq.timeLength;
      }

      beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
      onTimeLengthUpdate();
      onBeatLengthUpdate();

      for (const [key] of Object.entries(chromatiq.uniforms)) {
        const unifromStr = sessionStorage.getItem(key);
        if (unifromStr) {
          chromatiq.uniforms[key] = JSON.parse(unifromStr);
        }
      }

      const paneExpandedStr = sessionStorage.getItem("paneExpanded");
      if (paneExpandedStr) {
        pane.expanded = parseBool(paneExpandedStr);
      }

      for (const [key, folder] of Object.entries(defaultFolders)) {
        folder.expanded = parseBool(sessionStorage.getItem("folderExpanded_" + key));
      }

      for (const [key, folder] of Object.entries(groupFolders)) {
        folder.expanded = parseBool(sessionStorage.getItem("folderExpanded_" + key));
      }
    };

    loadFromSessionStorage();

    window.addEventListener("beforeunload", () => {
      saveToSessionStorage();
    });

    if (config.debugCamera) {
      camera.position.set(chromatiq.uniforms.gCameraEyeX, chromatiq.uniforms.gCameraEyeY, chromatiq.uniforms.gCameraEyeZ);
      camera.lookAt(chromatiq.uniforms.gCameraTargetX, chromatiq.uniforms.gCameraTargetY, chromatiq.uniforms.gCameraTargetZ);
    }

    controls.target = new three.Vector3(chromatiq.uniforms.gCameraTargetX, chromatiq.uniforms.gCameraTargetY, chromatiq.uniforms.gCameraTargetZ);
    controls.zoomSpeed = 3.0;
    controls.screenSpacePanning = true;
    controls.mouseButtons = {
      LEFT: THREE.MOUSE.ROTATE,
      MIDDLE: THREE.MOUSE.PAN,
      RIGHT: THREE.MOUSE.DOLLY,
    };

    const prevCameraPosotion = camera.position.clone();
    const prevCameraTarget: three.Vector3 = controls.target.clone();

    // Player
    chromatiq.onRender = (time, timeDelta): void => {
      timeInput.valueAsNumber = time;
      beatInput.valueAsNumber = timeToBeat(time);
      timeBar.valueAsNumber = time;
      beatBar.valueAsNumber = timeToBeat(time);

      const fps = 1.0 / timeDelta;
      fpsSpan.innerText = `${fps.toFixed(2)} FPS`;

      stats.begin();

      if (!config.debugParams) {
        animateUniforms(time, config.debugCamera, config.debugDisableReset);
      }
    };

    chromatiq.onPostRender = (): void => {
      stats.end();
      stats.update();
      pane.refresh();
    };

    chromatiq.onUpdate = (): void => {
      if (config.debugCamera) {
        controls.update();

        if (!camera.position.equals(prevCameraPosotion) || !controls.target.equals(prevCameraTarget)) {
          chromatiq.uniforms.gCameraEyeX = camera.position.x;
          chromatiq.uniforms.gCameraEyeY = camera.position.y;
          chromatiq.uniforms.gCameraEyeZ = camera.position.z;
          chromatiq.uniforms.gCameraTargetX = controls.target.x;
          chromatiq.uniforms.gCameraTargetY = controls.target.y;
          chromatiq.uniforms.gCameraTargetZ = controls.target.z;
          chromatiq.uniforms.gCameraDebug = config.debugCamera ? 1 : 0;

          pane.refresh();
          chromatiq.needsUpdate = true;
        }

        prevCameraPosotion.copy(camera.position);
        prevCameraTarget.copy(controls.target);
      }

      if (config.forceRender) {
        chromatiq.needsUpdate = true;
      }
    };

    if (chromatiq.isPlaying) {
      chromatiq.playSound();
    }

    // UI Events
    window.addEventListener("resize", onResolutionCange);

    stopButton.addEventListener("click", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
      chromatiq.time = 0;
      playPauseButton.value = playChar;
    });

    playPauseButton.addEventListener("click", () => {
      chromatiq.isPlaying = !chromatiq.isPlaying;
      playPauseButton.value = chromatiq.isPlaying ? pauseChar : playChar;

      if (chromatiq.isPlaying) {
        chromatiq.playSound();
      } else {
        chromatiq.stopSound();
      }
    });

    frameDecButton.addEventListener("click", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
      chromatiq.time -= 1 / 60;
    });

    frameIncButton.addEventListener("click", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
      chromatiq.time += 1 / 60;
    });

    timeInput.addEventListener("input", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.time = timeInput.valueAsNumber;
      playPauseButton.value = playChar;
      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
    });

    beatInput.addEventListener("input", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.time = beatToTime(beatInput.valueAsNumber);
      playPauseButton.value = playChar;
      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
    });

    timeBar.addEventListener("input", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.time = timeBar.valueAsNumber;
      playPauseButton.value = playChar;
      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
    });

    beatBar.addEventListener("input", () => {
      if (chromatiq.isPlaying) {
        chromatiq.stopSound();
      }

      chromatiq.time = beatToTime(beatBar.valueAsNumber);
      playPauseButton.value = playChar;
      chromatiq.isPlaying = false;
      chromatiq.needsUpdate = true;
    });

    timeLengthInput.addEventListener("input", () => {
      beatLengthInput.valueAsNumber = timeToBeat(timeLengthInput.valueAsNumber);
      onTimeLengthUpdate();
      onBeatLengthUpdate();
    });

    beatLengthInput.addEventListener("input", () => {
      timeLengthInput.valueAsNumber = beatToTime(beatLengthInput.valueAsNumber);
      onTimeLengthUpdate();
      onBeatLengthUpdate();
    });
  },
  false
);
