# nowgginscram

Small launcher page that opens `https://nowgg.fun` through a local Scramjet proxy path and keeps the live session in a full-page view.

## Setup

1. Initialize the Scramjet dependency as a recursive submodule:

```bash
./scripts/setup-scramjet-submodule.sh
```

2. Serve this repo as static files (example):

```bash
python3 -m http.server 4173
```

3. Open `http://localhost:4173` and click **Start**.

## Behavior

- Clicking **Start** opens `https://nowgg.fun` in a fullscreen proxy iframe (no top bar UI).
- The app only allows `nowgg.fun` and `*.ip.nowgg.fun` destinations.
- If the Scramjet client bundle is missing, launch is cancelled with a status message (instead of navigating to a broken URI).
