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

function normalizeRewriteCandidate(candidate, owner = null) {
  if (typeof candidate !== "function") return null;
  if (!owner) return candidate;
  return candidate.bind(owner);
}

function findRewriteFunctionFromGlobals() {
  const candidates = [
    [window.__scramjet$rewriteUrl, null],
    [window.$scramjet?.rewriteUrl, window.$scramjet],
    [window.scramjet?.rewriteUrl, window.scramjet],
    [window.ScramjetController?.rewriteUrl, window.ScramjetController],
  ];

  for (const [fn, owner] of candidates) {
    const normalized = normalizeRewriteCandidate(fn, owner);
    if (normalized) return normalized;
  }

  return null;
}

function findRewriteFunctionFromModule(moduleNs) {
  if (!moduleNs) return null;

  const candidates = [
    [moduleNs.__scramjet$rewriteUrl, moduleNs],
    [moduleNs.rewriteUrl, moduleNs],
    [moduleNs.default?.rewriteUrl, moduleNs.default],
    [moduleNs.default, null],
  ];

  for (const [fn, owner] of candidates) {
    const normalized = normalizeRewriteCandidate(fn, owner);
    if (normalized) return normalized;
  }

  return null;
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
  const moduleNs = await import(src).then(
    (moduleNamespace) => moduleNamespace,
    () => null,
  );

  if (moduleNs) {
    return findRewriteFunctionFromModule(moduleNs) ?? findRewriteFunctionFromGlobals();
  }

  await loadClassicScript(src);
  return findRewriteFunctionFromGlobals();
}

async function ensureScramjetClient() {
  const existing = findRewriteFunctionFromGlobals();
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
      console.debug?.(`[scramjet-loader] Failed to load candidate: ${src}`);
    }
  }

  return null;
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

  let proxied;
  try {
    proxied = rewriteUrl(DEFAULT_URL);
  } catch {
    setStatus("Scramjet loaded but rewrite failed. Rebuild/publish scramjet.client.js and retry.", "warn");
    startBtn.disabled = false;
    return;
  }

  document.body.classList.add("playing");
  frame.src = proxied;
}

startBtn.addEventListener("click", () => {
  start();
});
