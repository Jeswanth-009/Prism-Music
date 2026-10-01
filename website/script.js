/* Prism Music landing page — no frameworks, no build step. */
(function () {
  "use strict";

  var REPO = "Jeswanth-009/Prism-Music";
  var FALLBACK_RELEASES = "https://github.com/" + REPO + "/releases";

  function fmt(n) {
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, "") + "M";
    if (n >= 1000) return (n / 1000).toFixed(1).replace(/\.0$/, "") + "k";
    return String(n);
  }

  /* ── Theme toggle ──────────────────────────────────────────────
     Dark is the brand default; the choice persists and first-time
     visitors get whatever their OS prefers. */
  var root = document.documentElement;
  var toggle = document.getElementById("themeToggle");
  var stored = null;
  try { stored = localStorage.getItem("prism-theme"); } catch (e) { /* private mode */ }

  var initial = stored || (window.matchMedia &&
    window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark");
  root.setAttribute("data-theme", initial);

  if (toggle) {
    toggle.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "light" ? "dark" : "light";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("prism-theme", next); } catch (e) { /* ignore */ }
    });
  }

  /* ── Mobile nav ──────────────────────────────────────────────── */
  var burger = document.getElementById("navBurger");
  var links = document.getElementById("navLinks");
  if (burger && links) {
    burger.addEventListener("click", function () {
      var open = links.classList.toggle("open");
      burger.setAttribute("aria-expanded", open ? "true" : "false");
    });
    links.addEventListener("click", function (e) {
      if (e.target.tagName === "A") {
        links.classList.remove("open");
        burger.setAttribute("aria-expanded", "false");
      }
    });
  }

  /* ── Reveal on scroll (also drives tile vignettes) ───────────── */
  var revealed = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("in");
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });
    revealed.forEach(function (el) { io.observe(el); });
  } else {
    revealed.forEach(function (el) { el.classList.add("in"); });
  }

  /* ── Equalizer vignette: morph through the app's real presets ── */
  var PRESETS = [
    { name: "normal",      v: [50, 50, 50, 50, 50] },
    { name: "bass boost",  v: [92, 78, 52, 40, 38] },
    { name: "treble boost",v: [36, 40, 50, 72, 90] },
    { name: "rock",        v: [78, 58, 36, 62, 80] },
    { name: "pop",         v: [40, 66, 74, 60, 44] },
    { name: "classical",   v: [46, 40, 34, 60, 70] },
    { name: "jazz",        v: [64, 46, 58, 52, 64] },
    { name: "electronic",  v: [88, 60, 42, 68, 84] }
  ];
  var eqName = document.getElementById("eqPresetName");
  var eqBands = document.querySelectorAll(".eq-bands .band i");
  var reducedMotion = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function applyPreset(p) {
    if (eqName) eqName.textContent = p.name;
    eqBands.forEach(function (band, i) {
      band.style.setProperty("--v", p.v[i] + "%");
    });
  }

  if (eqName && eqBands.length && !reducedMotion) {
    var presetIdx = 3; /* start on rock, matching the markup */
    applyPreset(PRESETS[presetIdx]);
    setInterval(function () {
      presetIdx = (presetIdx + 1) % PRESETS.length;
      applyPreset(PRESETS[presetIdx]);
    }, 2600);
  }

  /* ── Screenshot gallery lightbox ─────────────────────────────── */
  var shots = Array.prototype.slice.call(document.querySelectorAll(".shot"));
  var lightbox = document.getElementById("lightbox");
  var lbImg = document.getElementById("lbImg");
  var lbCap = document.getElementById("lbCap");
  var lbCurrent = 0;

  function openLightbox(i) {
    if (!lightbox || !shots.length) return;
    lbCurrent = (i + shots.length) % shots.length;
    var img = shots[lbCurrent].querySelector("img");
    var cap = shots[lbCurrent].querySelector(".shot-cap");
    lbImg.src = img.getAttribute("src");
    lbImg.alt = img.alt;
    lbCap.textContent = cap ? cap.textContent : "";
    if (typeof lightbox.showModal === "function") lightbox.showModal();
    else lightbox.setAttribute("open", "");
  }

  function stepLightbox(delta) { openLightbox(lbCurrent + delta); }

  shots.forEach(function (shot) {
    shot.addEventListener("click", function () {
      openLightbox(parseInt(shot.getAttribute("data-index"), 10) || 0);
    });
  });

  if (lightbox) {
    document.getElementById("lbClose").addEventListener("click", function () {
      lightbox.close();
    });
    document.getElementById("lbPrev").addEventListener("click", function () { stepLightbox(-1); });
    document.getElementById("lbNext").addEventListener("click", function () { stepLightbox(1); });
    /* click on the backdrop (outside the stage) closes */
    lightbox.addEventListener("click", function (e) {
      if (e.target === lightbox) lightbox.close();
    });
    lightbox.addEventListener("keydown", function (e) {
      if (e.key === "ArrowLeft") stepLightbox(-1);
      if (e.key === "ArrowRight") stepLightbox(1);
    });
  }

  /* ── Smart download link ───────────────────────────────────────
     GitHub's /releases/latest 404s for prereleases, AND the list
     endpoint is not reliably newest-first (a later-created release can
     sort after an older one). So: fetch a page of releases, keep the
     ones with an .apk asset, and pick the one with the highest
     alpha-vX.Y.Z-buildN(-runM) tag. */
  function parseTag(tag) {
    var m = /v(\d+)\.(\d+)\.(\d+)-build(\d+)/i.exec(tag || "");
    return m ? [+m[1], +m[2], +m[3], +m[4]] : null;
  }

  function compareTags(a, b) {
    for (var i = 0; i < 4; i++) {
      if (a[i] !== b[i]) return a[i] - b[i];
    }
    return 0;
  }

  function firstReleaseNote(body) {
    if (!body) return "";
    var lines = body.split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
        .replace(/^#+\s*/, "")                 /* headings */
        .replace(/^[-*]\s*/, "")               /* bullets */
        .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1") /* links -> text */
        .replace(/`/g, "")
        .trim();
      if (line) return line;
    }
    return "";
  }

  /* Parse CHANGELOG.md into { "X.Y.Z": "first change bullet" } so release
     feeds can show real headlines instead of the boilerplate release title. */
  function parseChangelogNotes(md) {
    var notes = {};
    if (!md) return notes;
    var sections = md.split(/^## /m);
    for (var i = 1; i < sections.length; i++) {
      var m = /^\[([\d.]+)\]/.exec(sections[i]);
      if (!m) continue;
      var lines = sections[i].split(/\r?\n/);
      for (var j = 1; j < lines.length; j++) {
        var line = lines[j].replace(/^[-*]\s*/, "").trim();
        if (line && !/^###/.test(lines[j])) { notes[m[1]] = line; break; }
      }
    }
    return notes;
  }

  function noteForRelease(release) {
    var parsed = parseTag(release.tag_name || "");
    if (parsed && window.__prismNotes) {
      var key = parsed[0] + "." + parsed[1] + "." + parsed[2];
      if (window.__prismNotes[key]) return window.__prismNotes[key];
    }
    var note = firstReleaseNote(release.body);
    if (!note || /automated alpha release/i.test(note)) return "maintenance release";
    return note;
  }

  function pickApkAsset(assets) {
    var apks = (assets || []).filter(function (a) { return /\.apk$/i.test(a.name); });
    /* prefer the device APK over the x86_64 emulator build */
    var device = apks.filter(function (a) { return !/x86|emulator/i.test(a.name); });
    return device[0] || apks[0] || null;
  }

  function applyRelease(release, apkAsset) {
    var url = apkAsset.browser_download_url;
    document.querySelectorAll("[data-download-link]").forEach(function (a) {
      a.setAttribute("href", url);
    });

    var tag = release.tag_name || "";
    var parsed = parseTag(tag);
    var version = parsed ? "v" + parsed[0] + "." + parsed[1] + "." + parsed[2] : tag;
    var build = parsed ? "· build " + parsed[3] : "";

    var versionEl = document.getElementById("versionLabel");
    if (versionEl) versionEl.textContent = version;
    var buildEl = document.getElementById("buildLabel");
    if (buildEl) buildEl.textContent = build;

    var mRelease = document.getElementById("mRelease");
    if (mRelease) mRelease.textContent = tag;
    var mAsset = document.getElementById("mAsset");
    if (mAsset) mAsset.textContent = apkAsset.name;
    var mSize = document.getElementById("mSize");
    if (mSize && apkAsset.size) mSize.textContent = (apkAsset.size / 1e6).toFixed(1) + " MB";
    var mDate = document.getElementById("mDate");
    if (mDate && release.published_at) {
      try {
        mDate.textContent = new Date(release.published_at).toLocaleDateString(undefined, {
          year: "numeric", month: "short", day: "numeric",
        });
      } catch (e) { /* keep placeholder */ }
    }
    var mNote = document.getElementById("mNote");
    if (mNote) {
      var note = noteForRelease(release);
      if (note) {
        mNote.textContent = "what changed: " + note;
        mNote.hidden = false;
      }
    }
  }

  function renderFeed(releases) {
    var feed = document.getElementById("feedList");
    if (!feed) return;
    feed.innerHTML = "";
    releases.slice(0, 5).forEach(function (r) {
      var parsed = parseTag(r.tag_name);
      var li = document.createElement("li");

      var ver = document.createElement("span");
      ver.className = "f-ver mono";
      ver.textContent = parsed
        ? "v" + parsed[0] + "." + parsed[1] + "." + parsed[2]
        : (r.tag_name || "");

      var msg = document.createElement("span");
      msg.className = "f-msg";
      msg.textContent = noteForRelease(r);

      var date = document.createElement("span");
      date.className = "f-date mono";
      if (r.published_at) {
        try {
          date.textContent = new Date(r.published_at).toLocaleDateString(undefined, {
            month: "short", day: "numeric",
          });
        } catch (e) { /* omit */ }
      }

      li.appendChild(ver);
      li.appendChild(msg);
      li.appendChild(date);
      feed.appendChild(li);
    });
  }

  if (window.fetch) {
    /* repo metadata: stars + forks for the hero chips and stats band */
    fetch("https://api.github.com/repos/" + REPO)
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (repo) {
        if (!repo || typeof repo.stargazers_count !== "number") return;
        var starsVal = document.getElementById("starsVal");
        var forksVal = document.getElementById("forksVal");
        if (starsVal) starsVal.textContent = fmt(repo.stargazers_count);
        if (forksVal) forksVal.textContent = fmt(repo.forks_count);
        var chips = document.getElementById("heroChips");
        if (chips) chips.hidden = false;
        var ossStars = document.getElementById("ossStars");
        if (ossStars) ossStars.textContent = fmt(repo.stargazers_count);
      })
      .catch(function () { /* hero chips stay hidden */ });

    fetch("https://api.github.com/repos/" + REPO + "/releases?per_page=100")
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (releases) {
        if (!Array.isArray(releases)) return;

        var total = 0;
        releases.forEach(function (r) {
          (r.assets || []).forEach(function (a) {
            if (/\.apk$/i.test(a.name)) total += a.download_count || 0;
          });
        });
        var ossDownloads = document.getElementById("ossDownloads");
        if (ossDownloads) ossDownloads.textContent = fmt(total);

        var ossReleases = document.getElementById("ossReleases");
        if (ossReleases) ossReleases.textContent = String(releases.length);

        renderFeed(releases);

        var candidates = releases
          .filter(function (r) { return !r.draft; })
          .map(function (r) {
            var apk = pickApkAsset(r.assets);
            var key = parseTag(r.tag_name);
            return apk && key ? { release: r, apk: apk, key: key } : null;
          })
          .filter(Boolean);

        if (!candidates.length) return;
        candidates.sort(function (a, b) { return compareTags(b.key, a.key); });
        applyRelease(candidates[0].release, candidates[0].apk);

        /* The automated releases carry boilerplate bodies, so real headlines
           come from CHANGELOG.md in the repo (kept fresh on every release). */
        fetch("https://raw.githubusercontent.com/" + REPO + "/main/CHANGELOG.md")
          .then(function (r) { return r.ok ? r.text() : Promise.reject(r.status); })
          .then(function (md) {
            window.__prismNotes = parseChangelogNotes(md);
            renderFeed(releases);
            if (candidates.length) applyRelease(candidates[0].release, candidates[0].apk);
          })
          .catch(function () { /* feed keeps release titles */ });
      })
      .catch(function () {
        // Markup already points every download link at the releases page.
      });
  }

  // Never dead-end: if the API hasn't rewritten a link, fall through to the
  // releases page it already points at in the markup.
  document.querySelectorAll("[data-download-link]").forEach(function (a) {
    a.addEventListener("click", function () {
      var href = a.getAttribute("href");
      if (!href || href === "#") {
        a.setAttribute("href", a.getAttribute("href-fallback") || FALLBACK_RELEASES);
      }
    });
  });
})();
