/* ─────────────────────────────────────────────────────────────────
   Prism Music — State-of-the-Art Interactive Client Logic
   Web Audio API Synthesis, Live Visualizer, Interactive Bento & Showcase
   ───────────────────────────────────────────────────────────────── */
(function () {
  "use strict";

  const REPO = "Jeswanth-009/Prism-Music";
  const RELEASES_URL = `https://github.com/${REPO}/releases`;
  const API_RELEASES = `https://api.github.com/repos/${REPO}/releases/latest`;
  const API_REPO = `https://api.github.com/repos/${REPO}`;

  /* ── 1. Theme Management ─────────────────────────────────────── */
  const root = document.documentElement;
  const themeToggle = document.getElementById("themeToggle");
  let savedTheme = null;
  try { savedTheme = localStorage.getItem("prism-theme"); } catch (e) {}

  const initialTheme = savedTheme || (window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
  root.setAttribute("data-theme", initialTheme);

  if (themeToggle) {
    themeToggle.addEventListener("click", () => {
      const current = root.getAttribute("data-theme");
      const next = current === "light" ? "dark" : "light";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("prism-theme", next); } catch (e) {}
    });
  }

  /* ── 2. Mobile Navigation Drawer ─────────────────────────────── */
  const navBurger = document.getElementById("navBurger");
  const navLinks = document.getElementById("navLinks");
  if (navBurger && navLinks) {
    navBurger.addEventListener("click", () => {
      const isOpen = navLinks.classList.toggle("open");
      navBurger.setAttribute("aria-expanded", isOpen ? "true" : "false");
    });
    navLinks.querySelectorAll("a").forEach(link => {
      link.addEventListener("click", () => {
        navLinks.classList.remove("open");
        navBurger.setAttribute("aria-expanded", "false");
      });
    });
  }

  /* ── 3. Web Audio API Procedural Synthesizer & Visualizer ────── */
  let audioCtx = null;
  let isPlaying = false;
  let playbackTimer = null;
  let currentTime = 0;
  const duration = 88; // 1m 28s demo loop

  const playBtn = document.getElementById("livePlayBtn");
  const playIcon = document.getElementById("playIcon");
  const pauseIcon = document.getElementById("pauseIcon");
  const widgetArt = document.getElementById("widgetArt");
  const widgetProgress = document.getElementById("widgetProgress");
  const currentTimeLabel = document.getElementById("currentTimeLabel");
  const visualizerContainer = document.getElementById("widgetVisualizer");

  // Create 16 visualizer bars
  const numBars = 16;
  const bars = [];
  if (visualizerContainer) {
    visualizerContainer.innerHTML = "";
    for (let i = 0; i < numBars; i++) {
      const bar = document.createElement("div");
      bar.className = "viz-bar";
      visualizerContainer.appendChild(bar);
      bars.push(bar);
    }
  }

  // Demo karaoke lyrics sync timing (seconds)
  const lyricsData = [
    { time: 0, text: "The light bends through the prism" },
    { time: 14, text: "Every color finds its wavelength" },
    { time: 32, text: "High fidelity, direct to your soul" },
    { time: 54, text: "No accounts, no limits, just music" }
  ];

  let synthInterval = null;
  const chords = [
    [174.61, 220.00, 261.63, 329.63], // Fmaj7
    [196.00, 246.94, 293.66, 349.23], // G7
    [164.81, 196.00, 246.94, 293.66], // Em7
    [220.00, 261.63, 329.63, 392.00]  // Am7
  ];
  let chordIdx = 0;

  function initAudio() {
    if (!audioCtx) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      audioCtx = new AudioContext();
    }
    if (audioCtx.state === "suspended") {
      audioCtx.resume();
    }
  }

  function playLoFiChord(notes) {
    if (!audioCtx || audioCtx.state !== "running") return;
    const now = audioCtx.currentTime;
    notes.forEach(freq => {
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      const filter = audioCtx.createBiquadFilter();

      osc.type = "sine";
      osc.frequency.setValueAtTime(freq, now);

      filter.type = "lowpass";
      filter.frequency.setValueAtTime(800, now);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.exponentialRampToValueAtTime(0.04, now + 0.3);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + 3.8);

      osc.connect(filter);
      filter.connect(gain);
      gain.connect(audioCtx.destination);

      osc.start(now);
      osc.stop(now + 4);
    });
  }

  function updateVisualizer() {
    if (!isPlaying) {
      bars.forEach(bar => { bar.style.height = "12%"; });
      return;
    }
    bars.forEach((bar, idx) => {
      const noise = Math.sin(Date.now() / 150 + idx * 0.8) * 0.5 + 0.5;
      const height = Math.floor(20 + noise * 75);
      bar.style.height = `${height}%`;
    });
    requestAnimationFrame(updateVisualizer);
  }

  function updateLyricsHighlight(time) {
    const lyricElements = document.querySelectorAll(".lyric-item");
    if (!lyricElements.length) return;
    let activeIdx = 0;
    for (let i = 0; i < lyricsData.length; i++) {
      if (time >= lyricsData[i].time) activeIdx = i;
    }
    lyricElements.forEach((el, i) => {
      el.classList.toggle("active", i === activeIdx);
    });
  }

  function togglePlay() {
    initAudio();
    isPlaying = !isPlaying;

    if (isPlaying) {
      if (playIcon) playIcon.style.display = "none";
      if (pauseIcon) pauseIcon.style.display = "block";
      if (widgetArt) widgetArt.classList.add("playing");

      playLoFiChord(chords[chordIdx]);
      synthInterval = setInterval(() => {
        chordIdx = (chordIdx + 1) % chords.length;
        playLoFiChord(chords[chordIdx]);
      }, 4000);

      playbackTimer = setInterval(() => {
        currentTime = (currentTime + 1) % duration;
        const progressPct = (currentTime / duration) * 100;
        if (widgetProgress) widgetProgress.style.width = `${progressPct}%`;
        if (currentTimeLabel) {
          const mins = Math.floor(currentTime / 60);
          const secs = String(currentTime % 60).padStart(2, "0");
          currentTimeLabel.textContent = `${mins}:${secs}`;
        }
        updateLyricsHighlight(currentTime);
      }, 1000);

      requestAnimationFrame(updateVisualizer);
    } else {
      if (playIcon) playIcon.style.display = "block";
      if (pauseIcon) pauseIcon.style.display = "none";
      if (widgetArt) widgetArt.classList.remove("playing");
      clearInterval(synthInterval);
      clearInterval(playbackTimer);
      updateVisualizer();
    }
  }

  if (playBtn) {
    playBtn.addEventListener("click", togglePlay);
  }

  // Scrubber interactive seek
  const scrubberWrap = document.getElementById("widgetScrubber");
  if (scrubberWrap) {
    scrubberWrap.addEventListener("click", (e) => {
      const rect = scrubberWrap.getBoundingClientRect();
      const pos = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
      currentTime = Math.floor(pos * duration);
      if (widgetProgress) widgetProgress.style.width = `${pos * 100}%`;
      updateLyricsHighlight(currentTime);
    });
  }

  // Interactive Lyrics click-to-seek
  document.querySelectorAll(".lyric-item").forEach(item => {
    item.addEventListener("click", () => {
      const seekSec = parseInt(item.getAttribute("data-time") || "0", 10);
      currentTime = seekSec;
      const progressPct = (currentTime / duration) * 100;
      if (widgetProgress) widgetProgress.style.width = `${progressPct}%`;
      updateLyricsHighlight(currentTime);
      if (!isPlaying) togglePlay();
    });
  });

  /* ── 4. Interactive Equalizer Presets ────────────────────────── */
  const eqPresets = {
    normal: [50, 50, 50, 50, 50],
    bass: [90, 80, 55, 42, 38],
    rock: [75, 60, 40, 68, 85],
    vocal: [35, 60, 80, 70, 50],
    electronic: [85, 65, 40, 75, 90]
  };

  const eqFills = document.querySelectorAll(".eq-bar-fill");
  const eqPills = document.querySelectorAll(".eq-pill");

  function setEqPreset(presetKey) {
    const vals = eqPresets[presetKey] || eqPresets.normal;
    eqFills.forEach((fill, idx) => {
      fill.style.height = `${vals[idx]}%`;
    });
    eqPills.forEach(pill => {
      pill.classList.toggle("active", pill.getAttribute("data-preset") === presetKey);
    });
  }

  eqPills.forEach(pill => {
    pill.addEventListener("click", () => {
      setEqPreset(pill.getAttribute("data-preset"));
    });
  });

  // Enable click/drag on individual EQ bar tracks
  document.querySelectorAll(".eq-bar-track").forEach((track, i) => {
    track.addEventListener("click", (e) => {
      const rect = track.getBoundingClientRect();
      const heightPct = Math.round(Math.max(10, Math.min(100, ((rect.bottom - e.clientY) / rect.height) * 100)));
      if (eqFills[i]) eqFills[i].style.height = `${heightPct}%`;
      eqPills.forEach(pill => pill.classList.remove("active"));
    });
  });

  /* ── 5. Interactive Device Screenshot Showcase ───────────────── */
  const showcaseImg = document.getElementById("showcaseImg");
  const showcaseTabs = document.querySelectorAll(".showcase-tab");
  const hotspotTitle = document.getElementById("hotspotTitle");
  const hotspotDesc = document.getElementById("hotspotDesc");

  const screenshotData = {
    home: {
      src: "assets/framed-home.png",
      alt: "Home Screen with docked navigation and editorial recommendations",
      pinTop: "72%",
      pinLeft: "50%",
      title: "Docked Navigation",
      desc: "Reserved bottom clearance with instant tab switching and persistent mini player."
    },
    player: {
      src: "assets/framed-player.png",
      alt: "Now Playing Screen with live bitrate badge and dynamic palette tinting",
      pinTop: "56%",
      pinLeft: "50%",
      title: "Live Bitrate & Lyrics",
      desc: "Shows OPUS/AAC streaming rate, line-synced LRCLIB lyrics, and album palette tint."
    },
    search: {
      src: "assets/framed-search.png",
      alt: "Search Screen with instant radio recommendation seed",
      pinTop: "42%",
      pinLeft: "50%",
      title: "Infinite Radio from Search",
      desc: "Tap any searched track to immediately seed playback and stream endless recommendations."
    },
    charts: {
      src: "assets/framed-charts.png",
      alt: "Charts Hub with YouTube and Billboard verified sources",
      pinTop: "35%",
      pinLeft: "50%",
      title: "Verified Global Charts",
      desc: "Billboard Hot 100, TikTok Trends, and YouTube Global Top Music with country chips."
    },
    stats: {
      src: "assets/framed-stats.png",
      alt: "Listening Stats Screen with 14-day plays history chart",
      pinTop: "45%",
      pinLeft: "50%",
      title: "14-Day Play Analytics",
      desc: "Computed 100% on-device with zero cloud telemetry or data sharing."
    }
  };

  showcaseTabs.forEach(tab => {
    tab.addEventListener("click", () => {
      showcaseTabs.forEach(t => t.classList.remove("active"));
      tab.classList.add("active");
      const key = tab.getAttribute("data-screen");
      const data = screenshotData[key];
      if (data && showcaseImg) {
        showcaseImg.style.opacity = "0.4";
        showcaseImg.src = data.src;
        showcaseImg.alt = data.alt;
        setTimeout(() => { showcaseImg.style.opacity = "1"; }, 150);

        const pin = document.getElementById("showcaseHotspot");
        if (pin) {
          pin.style.top = data.pinTop;
          pin.style.left = data.pinLeft;
        }
        if (hotspotTitle) hotspotTitle.textContent = data.title;
        if (hotspotDesc) hotspotDesc.textContent = data.desc;
      }
    });
  });

  /* ── 6. Simulated Offline Download ───────────────────────────── */
  const dlSimBtn = document.getElementById("dlSimBtn");
  const dlRingFill = document.getElementById("dlRingFill");
  const dlRingText = document.getElementById("dlRingText");

  if (dlSimBtn && dlRingFill && dlRingText) {
    let dlInterval = null;
    dlSimBtn.addEventListener("click", () => {
      dlSimBtn.disabled = true;
      let progress = 0;
      dlRingText.textContent = "0%";
      clearInterval(dlInterval);

      dlInterval = setInterval(() => {
        progress += 4;
        if (progress > 100) {
          progress = 100;
          clearInterval(dlInterval);
          dlRingText.textContent = "✓ Saved";
          dlSimBtn.textContent = "Downloaded (Offline Ready)";
          dlSimBtn.disabled = false;
        } else {
          dlRingText.textContent = `${progress}%`;
          const offset = 251.2 - (251.2 * progress) / 100;
          dlRingFill.style.strokeDashoffset = offset;
        }
      }, 50);
    });
  }

  /* ── 7. Interactive Multi-Source Fallback Simulator ──────────── */
  const simFailoverBtn = document.getElementById("simFailoverBtn");
  const simLog = document.getElementById("simLog");
  const stepYt = document.getElementById("stepYt");
  const stepJio = document.getElementById("stepJio");
  const stepPipe = document.getElementById("stepPipe");

  if (simFailoverBtn && simLog) {
    simFailoverBtn.addEventListener("click", () => {
      simFailoverBtn.disabled = true;
      simLog.textContent = "[1/3] Resolving stream from YouTube Explode...";
      if (stepYt) stepYt.className = "pipe-step active";
      if (stepJio) stepJio.className = "pipe-step";
      if (stepPipe) stepPipe.className = "pipe-step";

      setTimeout(() => {
        if (stepYt) stepYt.className = "pipe-step failed";
        simLog.textContent = "[2/3] YouTube 403 Forbidden. Circuit breaker failing over to JioSaavn...";
        if (stepJio) stepJio.className = "pipe-step active";

        setTimeout(() => {
          simLog.textContent = "[3/3] JioSaavn resolved 320 kbps stream in 180ms. Audio playback uninterrupted!";
          if (stepJio) stepJio.className = "pipe-step active";
          simFailoverBtn.disabled = false;
        }, 1200);
      }, 1000);
    });
  }

  /* ── 8. Live GitHub Releases API & Changelog Integration ─────── */
  const mRelease = document.getElementById("mRelease");
  const mAsset = document.getElementById("mAsset");
  const mSize = document.getElementById("mSize");
  const mDate = document.getElementById("mDate");
  const mNote = document.getElementById("mNote");
  const versionLabel = document.getElementById("versionLabel");
  const buildLabel = document.getElementById("buildLabel");
  const ossStars = document.getElementById("ossStars");
  const ossReleases = document.getElementById("ossReleases");
  const ossDownloads = document.getElementById("ossDownloads");
  const starsVal = document.getElementById("starsVal");
  const forksVal = document.getElementById("forksVal");
  const heroChips = document.getElementById("heroChips");
  const feedList = document.getElementById("feedList");
  const downloadLinks = document.querySelectorAll("[data-download-link]");

  function fmt(n) {
    if (typeof n !== "number" || isNaN(n)) return "—";
    return n.toLocaleString("en-US");
  }

  function parseTag(tag) {
    const m = /v?(\d+)\.(\d+)\.(\d+)(?:-build(\d+))?/i.exec(tag || "");
    return m ? [+m[1], +m[2], +m[3], m[4] ? +m[4] : 0] : null;
  }

  function compareTags(a, b) {
    for (let i = 0; i < 4; i++) {
      if (a[i] !== b[i]) return a[i] - b[i];
    }
    return 0;
  }

  function firstReleaseNote(body) {
    if (!body) return "";
    const lines = body.split(/\r?\n/);
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
        .replace(/^#+\s*/, "")
        .replace(/^[-*]\s*/, "")
        .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
        .replace(/`/g, "")
        .trim();
      if (line && !/^automated/i.test(line)) return line;
    }
    return "";
  }

  function parseChangelogNotes(md) {
    const notes = {};
    if (!md) return notes;
    const sections = md.split(/^## /m);
    for (let i = 1; i < sections.length; i++) {
      const m = /^\[([\d.]+)\]/.exec(sections[i]);
      if (!m) continue;
      const lines = sections[i].split(/\r?\n/);
      for (let j = 1; j < lines.length; j++) {
        const line = lines[j].replace(/^[-*]\s*/, "").trim();
        if (line && !/^###/.test(lines[j])) {
          notes[m[1]] = line;
          break;
        }
      }
    }
    return notes;
  }

  function noteForRelease(release) {
    const parsed = parseTag(release.tag_name || "");
    if (parsed && window.__prismNotes) {
      const key = `${parsed[0]}.${parsed[1]}.${parsed[2]}`;
      if (window.__prismNotes[key]) return window.__prismNotes[key];
    }
    const note = firstReleaseNote(release.body);
    if (!note || /automated alpha release/i.test(note)) return "maintenance & stability release";
    return note;
  }

  function pickApkAsset(assets) {
    const apks = (assets || []).filter(a => /\.apk$/i.test(a.name));
    const device = apks.filter(a => !/x86|emulator/i.test(a.name));
    return device[0] || apks[0] || null;
  }

  function updateDownloadLinks(url, tagName) {
    downloadLinks.forEach(link => {
      link.href = url;
      if (tagName && link.classList.contains("btn-primary")) {
        link.title = `Download Prism Music ${tagName}`;
      }
    });
  }

  function applyRelease(release, apkAsset) {
    if (apkAsset && apkAsset.browser_download_url) {
      updateDownloadLinks(apkAsset.browser_download_url, release.tag_name);
    }

    const tag = release.tag_name || "alpha-v0.2.36";
    const parsed = parseTag(tag);
    const version = parsed ? `v${parsed[0]}.${parsed[1]}.${parsed[2]}` : tag;
    const build = parsed && parsed[3] ? ` · build ${parsed[3]}` : "";

    if (versionLabel) versionLabel.textContent = version;
    if (buildLabel) buildLabel.textContent = build;
    if (mRelease) mRelease.textContent = tag;
    if (mAsset && apkAsset) mAsset.textContent = apkAsset.name;
    if (mSize && apkAsset && apkAsset.size) {
      mSize.textContent = `${(apkAsset.size / (1024 * 1024)).toFixed(1)} MB`;
    }
    if (mDate && release.published_at) {
      try {
        mDate.textContent = new Date(release.published_at).toLocaleDateString("en-US", {
          year: "numeric", month: "short", day: "numeric",
        });
      } catch (e) {}
    }
    if (mNote) {
      const note = noteForRelease(release);
      if (note) {
        mNote.textContent = `what changed: ${note}`;
        mNote.hidden = false;
      }
    }
  }

  function renderFeed(releases) {
    if (!feedList) return;
    feedList.innerHTML = "";
    releases.slice(0, 5).forEach(r => {
      const parsed = parseTag(r.tag_name);
      const li = document.createElement("li");

      const ver = document.createElement("span");
      ver.className = "f-ver mono";
      ver.textContent = parsed
        ? `v${parsed[0]}.${parsed[1]}.${parsed[2]}`
        : (r.tag_name || "");

      const msg = document.createElement("span");
      msg.className = "f-msg";
      msg.textContent = noteForRelease(r);

      const date = document.createElement("span");
      date.className = "f-date mono";
      if (r.published_at) {
        try {
          date.textContent = new Date(r.published_at).toLocaleDateString("en-US", {
            month: "short", day: "numeric",
          });
        } catch (e) {}
      }

      li.appendChild(ver);
      li.appendChild(msg);
      li.appendChild(date);
      feedList.appendChild(li);
    });
  }

  if (window.fetch) {
    // 1. Repo info (stars + forks)
    fetch(API_REPO)
      .then(res => res.ok ? res.json() : null)
      .then(repo => {
        if (!repo || typeof repo.stargazers_count !== "number") return;
        if (starsVal) starsVal.textContent = fmt(repo.stargazers_count);
        if (forksVal) forksVal.textContent = fmt(repo.forks_count);
        if (heroChips) heroChips.hidden = false;
        if (ossStars) ossStars.textContent = fmt(repo.stargazers_count);
      })
      .catch(() => {});

    // 2. Releases list + CHANGELOG.md parsing
    fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`)
      .then(res => res.ok ? res.json() : Promise.reject(res.status))
      .then(releases => {
        if (!Array.isArray(releases)) return;

        let totalDownloads = 0;
        releases.forEach(r => {
          (r.assets || []).forEach(a => {
            if (/\.apk$/i.test(a.name)) totalDownloads += (a.download_count || 0);
          });
        });
        if (ossDownloads) ossDownloads.textContent = fmt(totalDownloads);
        if (ossReleases) ossReleases.textContent = String(releases.length);

        renderFeed(releases);

        const candidates = releases
          .filter(r => !r.draft)
          .map(r => {
            const apk = pickApkAsset(r.assets);
            const key = parseTag(r.tag_name);
            return apk && key ? { release: r, apk, key } : null;
          })
          .filter(Boolean);

        if (candidates.length) {
          candidates.sort((a, b) => compareTags(b.key, a.key));
          applyRelease(candidates[0].release, candidates[0].apk);
        }

        // Fetch CHANGELOG.md to enrich release headlines
        fetch(`https://raw.githubusercontent.com/${REPO}/main/CHANGELOG.md`)
          .then(res => res.ok ? res.text() : Promise.reject(res.status))
          .then(md => {
            window.__prismNotes = parseChangelogNotes(md);
            renderFeed(releases);
            if (candidates.length) {
              applyRelease(candidates[0].release, candidates[0].apk);
            }
          })
          .catch(() => {});
      })
      .catch(() => {
        // Fallback to latest endpoint if releases?per_page=100 is rate-limited
        fetch(API_RELEASES)
          .then(res => res.ok ? res.json() : null)
          .then(latest => {
            if (!latest) return;
            const apk = pickApkAsset(latest.assets);
            applyRelease(latest, apk);
          })
          .catch(() => {});
      });
  }

})();
