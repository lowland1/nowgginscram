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

function loadScript(src) {
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.onload = () => resolve(true);
    script.onerror = () => reject(new Error(`Failed to load ${src}`));
    document.head.appendChild(script);
  });
}

async function ensureScramjetClient() {
  const existing = findRewriteFunction();
  if (existing) return existing;

  const candidates = [
    "/scramjet.client.js",
    "/vendor/scramjet/dist/scramjet.client.js",
    "/vendor/scramjet/static/scramjet.client.js",
    "/vendor/scramjet/scramjet.client.js",
  ];

  for (const src of candidates) {
    try {
      await loadScript(src);
      const rewrite = findRewriteFunction();
      if (rewrite) return rewrite;
    } catch {
      // Try next path.
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
      "Scramjet client not found. If deploying on Render, make sure build runs git submodule update --init --recursive and ./scripts/prepare-scramjet-client.sh.",
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
