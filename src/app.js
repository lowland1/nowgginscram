const DEFAULT_URL = "https://nowgg.fun";
const ALLOWED_HOST_SUFFIXES = ["nowgg.fun", ".ip.nowgg.fun"];

const statusEl = document.querySelector("#status");
const frame = document.querySelector("#proxy-frame");
const startBtn = document.querySelector("#start-btn");

function setStatus(text, level = "warn") {
  statusEl.textContent = text;
  statusEl.className = level;
}

function isAllowedDomain(rawUrl) {
  try {
    const { hostname, protocol } = new URL(rawUrl);
    if (protocol !== "https:") return false;
    return ALLOWED_HOST_SUFFIXES.some((suffix) =>
      suffix.startsWith(".") ? hostname.endsWith(suffix) : hostname === suffix,
    );
  } catch {
    return false;
  }
}

function findRewriteFunction() {
  const candidates = [
    window.__scramjet$rewriteUrl,
    window.$scramjet?.rewriteUrl,
    window.scramjet?.rewriteUrl,
    window.ScramjetController?.rewriteUrl,
  ];
  return candidates.find((candidate) => typeof candidate === "function") ?? null;
}

function findRewriteFunctionFromModule(moduleNs) {
  if (!moduleNs) return null;
  const candidates = [
    moduleNs.__scramjet$rewriteUrl,
    moduleNs.rewriteUrl,
    moduleNs.default?.rewriteUrl,
    moduleNs.default,
  ];
  return candidates.find((candidate) => typeof candidate === "function") ?? null;
}

function getBasePathPrefix() {
  const parts = window.location.pathname.split("/").filter(Boolean);
  if (window.location.hostname.endsWith("github.io") && parts.length > 0) {
    return `/${parts[0]}/`;
  }
  return "/";
}

function loadClassicScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.onload = () => resolve(true);
    script.onerror = () => reject(new Error(`Failed to load ${src}`));
    document.head.appendChild(script);
  });
}

async function loadClientCandidate(src) {
  // Try ES module first (often used in CI-produced modern bundles).
  const moduleNs = await import(src).then(
    (moduleNamespace) => moduleNamespace,
    () => null,
  );

  if (moduleNs) {
    return findRewriteFunctionFromModule(moduleNs) ?? findRewriteFunction();
  }

  // Fallback for UMD/IIFE bundles.
  await loadClassicScript(src);
  return findRewriteFunction();
}

async function ensureScramjetClient() {
  const existing = findRewriteFunction();
  if (existing) return existing;

  const base = getBasePathPrefix();
  const candidates = [
    `${base}scramjet.client.js`,
    `${base}vendor/scramjet/dist/scramjet.client.js`,
    `${base}vendor/scramjet/static/scramjet.client.js`,
    `${base}vendor/scramjet/scramjet.client.js`,
  ];

  for (const src of candidates) {
    try {
      const rewrite = await loadClientCandidate(src);
      if (rewrite) return rewrite;
    } catch {
      // Try next path.
      console.debug?.(`[scramjet-loader] Failed to load candidate: ${src}`);
    }
  }

  return null;
}

async function enterFullscreen() {
  const node = document.documentElement;
  if (!document.fullscreenElement && node.requestFullscreen) {
    try {
      await node.requestFullscreen();
    } catch {
      // Non-fatal; continue with viewport fill fallback.
    }
  }
}

async function start() {
  startBtn.disabled = true;
  setStatus("Loading Scramjet client…", "warn");

  if (!isAllowedDomain(DEFAULT_URL)) {
    setStatus("Configured URL is not in the allowed nowgg.fun domain list.", "warn");
    startBtn.disabled = false;
    return;
  }

  const rewriteUrl = await ensureScramjetClient();
  if (!rewriteUrl) {
    setStatus(
      "Scramjet client not found. If using GitHub Pages, enable the included Pages workflow so scramjet.client.js is published. For local/other hosts, run ./scripts/prepare-scramjet-client.sh.",
      "warn",
    );
    startBtn.disabled = false;
    return;
  }

  document.body.classList.add("playing");
  await enterFullscreen();
  frame.src = rewriteUrl(DEFAULT_URL);
}

startBtn.addEventListener("click", () => {
  start();
});
