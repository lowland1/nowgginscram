# nowgginscram

Small launcher page that opens `https://nowgg.fun` through a local Scramjet proxy path and keeps the live session in a full-page view.

## Local setup

1. Initialize the Scramjet dependency as a recursive submodule:

```bash
./scripts/setup-scramjet-submodule.sh
```

2. Extract/publish a stable client file at project root:

```bash
./scripts/prepare-scramjet-client.sh
```

3. Serve this repo as static files (example):

```bash
python3 -m http.server 4173
```

4. Open `http://localhost:4173` and click **Start**.

## Render deployment

`render.yaml` is included. Its build command:

1. Initializes submodules recursively.
2. Copies Scramjet's client bundle into `/scramjet.client.js` so the browser can load it.

That prevents the "Scramjet client not found" startup issue on deploys where submodules were not previously published.

## Behavior

- Clicking **Start** opens `https://nowgg.fun` in a fullscreen proxy iframe (no top bar UI).
- The app only allows `nowgg.fun` and `*.ip.nowgg.fun` destinations.
- If the Scramjet client bundle is missing, launch is cancelled with a status message (instead of navigating to a broken URI).
