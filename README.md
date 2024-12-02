# Projects

## Project5: SESSIONS 2024: GUARDI▲N

3rd place at Realtime Graphics in [SESSIONS 2024](https://sessions-party.com/events/sessions-2024/) :3rd_place_medal:

- [📝 Article](https://gam0022.net/blog/2024/12/02/sessions2024-guardian/)
- [:tv: YouTube](https://www.youtube.com/watch?v=T-V3mHlsgzQ)
- [:package: Pouet](https://t.co/nXZkIBYdnC)
- [:bird: X/Twitter](https://x.com/gam0022/status/1858308509856678328)
- [:earth_americas: Online version](https://gam0022.net/webgl/#demoscne_guardian)

![sessions2024-guardian.jpg](screenshots/sessions2024-guardian.jpg)

## Project4: TDF 16ms #0 (2023): Infinite Keys

3rd place at GLSL Graphics Compo in [TDF 16ms](https://16ms.tokyodemofest.jp/) #0 (2023) :3rd_place_medal:

- [📝 Article](https://gam0022.net/blog/2023/10/30/tdf16ms0/)
- [:tv: YouTube](https://youtu.be/B4ZirkFOdZg?si=2R6X8x_bMMbgQoK2)
- [:eye: Shadertoy](https://www.shadertoy.com/view/csKfzw)
- [:bird: Twitter](https://twitter.com/gam0022/status/1716107013154087009)
- [:package: Pouet](https://www.pouet.net/prod.php?which=95342)

![infinite-keys](screenshots/infinite-keys.jpg)

## Project3: SESSIONS 2023: Transcendental Cube

2nd place at GLSL Graphics Compo in [SESSIONS](https://sessions.frontl1ne.net/) 2023 :2nd_place_medal:

- [📝 Article](https://gam0022.net/blog/2023/05/31/sessions2023-glsl-compo/)
- [:tv: YouTube](https://youtu.be/194E3UWj870)
- [:eye: Shadertoy](https://www.shadertoy.com/view/dldGzj)
- [:bird: Twitter](https://twitter.com/gam0022/status/1653096277184503808)
- [:package: Pouet](https://www.pouet.net/prod.php?which=94339)

![sessions2023](screenshots/sessions2023.jpg)

## Project2: WebGL Volumetric Fog (UE76)

A WebGL 64KB Intro for [#S1C002](https://neort.io/tag/bqr6ous3p9f48fkis91g), [#Shader1weekCompo](https://neort.io/tag/br0go2s3p9f194rkgmj0)

Imspired by [Ray Marching Fog With Blue Noise](https://blog.demofox.org/2020/05/10/ray-marching-fog-with-blue-noise/) by @Atrix256

- [NEORT version](https://neort.io/art/br0go2k3p9f194rkgmgg)
- [:tv: YouTube](https://youtu.be/8BEFyZzk6jI)
- [:bird: Twitter](https://twitter.com/gam0022/status/1261967964955279360/)

![volumetric-fog](screenshots/volumetric-fog.jpg)

## Project1: RE: SIMULATED

https://github.com/gam0022/resimulated


## Development

### 0: Required

- [node.js v12.14.1](https://nodejs.org/ja/) or higher
- [ruby 2.x](https://www.ruby-lang.org/ja/downloads/) or higher

### 1: Get Started

```sh
git clone git@github.com:gam0022/volumetric-fog.git
cd volumetric-fog

# init
npm install

# Start Web server with hot-reload / UI for debug
npm run start

# Generate a dist\volumetric-fog.html
npm run build
```

## Chromatiq

A WebGL engine developed for PC 64K Intro aimed at minimizing the file size.

Originally made it for [RE: SIMULATED by gam0022 & sadakkey](https://github.com/gam0022/resimulated).

Written in a single TypeScript, but it's still in development. ([source code](https://github.com/gam0022/resimulated/blob/master/src/chromatiq.ts))

### Features

It has only simple functions so that it does not depend on the work.

- Rendering multi-pass image shaders (as viewport square)
- Build-in bloom post-effect
- Interface to animate uniforms from a TypeScript
- GLSL Sound (Shadertoy compatible)
- Play an Audio file (mp3 / ogg)

### How to Capture Movie

1. `npm run start`
2. misc/saveImageSequence
3. misc/saveSound
4. `ffmpeg.exe -r 60 -i chromatiq%04d.png -i chromatiq.wav -c:v libx264 -preset slow -profile:v high -coder 1 -pix_fmt yuv420p -movflags +faststart -g 30 -bf 2 -c:a aac -b:a 384k -profile:a aac_low -b:v 68M chromatiq_68M.mp4`

#### Links

- [アップロードする動画におすすめのエンコード設定](https://support.google.com/youtube/answer/1722171?hl=ja)
    - 映像ビットレート 2160p（4k）53～68 Mbps
- [YouTube recommended encoding settings on ffmpeg (+ libx264)](https://gist.github.com/mikoim/27e4e0dc64e384adbcb91ff10a2d3678)
- [超有益情報 by sasaki_0222](https://twitter.com/sasaki_0222/status/1248910333835530241)

## Thanks

- [FMS-Cat/until](https://github.com/FMS-Cat/until)
- [gasman/pnginator.rb](https://gist.github.com/gasman/2560551)
- [VEDA 2.4: GLSLで音楽を演奏できるようになったぞ！！！ - マルシテイア by amagitakayosi](https://blog.amagi.dev/entry/veda-sound)
- [[webgl2]example for webgl2 (with glsl3) by bellbind](https://gist.github.com/bellbind/8c98bb86cfd064d944312b09b98af1b9)
- [How to Convert an AudioBuffer to an Audio File with JavaScript by Russell Good](https://www.russellgood.com/how-to-convert-audiobuffer-to-audio-file/)
- [wgld.org by h_doxas](https://wgld.org/)

## License

[MIT](LICENSE)
