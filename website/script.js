/* Prism Music landing page — no frameworks, no build step. */
(function () {
  "use strict";

  var REPO = "Jeswanth-009/Prism-Music";
  var FALLBACK_RELEASES = "https://github.com/" + REPO + "/releases";

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

  /* ── Reveal on scroll ────────────────────────────────────────── */
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
    var mDate = document.getElementById("mDate");
    if (mDate && release.published_at) {
      try {
        mDate.textContent = new Date(release.published_at).toLocaleDateString(undefined, {
          year: "numeric", month: "short", day: "numeric",
        });
      } catch (e) { /* keep placeholder */ }
    }
  }

  if (window.fetch) {
    fetch("https://api.github.com/repos/" + REPO + "/releases?per_page=10")
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (releases) {
        if (!Array.isArray(releases)) return;
        var candidates = releases
          .filter(function (r) { return !r.draft; })
          .map(function (r) {
            var apk = (r.assets || []).filter(function (a) {
              return /\.apk$/i.test(a.name);
            })[0];
            var key = parseTag(r.tag_name);
            return apk && key ? { release: r, apk: apk, key: key } : null;
          })
          .filter(Boolean);

        if (!candidates.length) return;
        candidates.sort(function (a, b) { return compareTags(b.key, a.key); });
        applyRelease(candidates[0].release, candidates[0].apk);
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
