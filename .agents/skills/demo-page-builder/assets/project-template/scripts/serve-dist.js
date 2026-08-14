const fs = require('fs');
const express = require('express');
const path = require('path');

const app = express();
const port = Number(process.env.PORT) || 8000;
const projectDir = path.join(__dirname, '..');
const distDir = path.join(projectDir, 'dist');
const mockDir = path.join(projectDir, 'mock');

// Mock API parity for static serving: mock/<name>.json => GET /api/<name>.
// Umi mock only runs in dev mode; without these routes the SPA fallback below
// would answer /api/* with index.html and pages crash parsing HTML as JSON
// (white screen after the skeleton flashes).
let mockApiCount = 0;
if (fs.existsSync(mockDir)) {
  for (const entry of fs.readdirSync(mockDir, { withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.json')) continue;
    const routePath = '/api/' + entry.name.slice(0, -'.json'.length);
    const dataFile = path.join(mockDir, entry.name);
    // Routes register at startup (new JSON files need a restart), but file
    // contents are read per request so mock data edits apply without restart.
    app.get(routePath, (_request, response) => {
      fs.readFile(dataFile, 'utf8', (error, content) => {
        if (error) {
          response.status(500).json({ error: `mock data file unreadable: ${entry.name}` });
          return;
        }
        response.type('application/json').send(content);
      });
    });
    mockApiCount += 1;
    console.log(`Mock API: ${routePath} -> ${path.relative(projectDir, dataFile)}`);
  }
}

// Unknown /api/* must 404 as JSON, never fall through to the SPA fallback.
app.use('/api', (_request, response) => {
  response.status(404).json({ error: 'API not found. Add mock/<name>.json and restart serve-dist.js.' });
});

app.use(express.static(distDir));
app.get('*', (_request, response) => {
  response.sendFile(path.join(distDir, 'index.html'));
});

app.listen(port, () => {
  console.log(`Serving dist at http://localhost:${port} (${mockApiCount} mock API route(s))`);
});
