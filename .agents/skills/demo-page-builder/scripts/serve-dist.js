const fs = require('fs');
const path = require('path');

const projectDir = path.resolve(process.argv[2] || process.cwd());
const distDir = path.join(projectDir, 'dist');
const indexFile = path.join(distDir, 'index.html');
const port = Number(process.env.PORT) || 8000;

if (!fs.existsSync(indexFile)) {
  console.error(`Missing build output: ${indexFile}`);
  console.error('Run npm run build before starting the static server.');
  process.exit(2);
}

let express;
try {
  express = require(require.resolve('express', { paths: [projectDir] }));
} catch {
  console.error(`Cannot resolve express from project: ${projectDir}`);
  console.error('Install the project dependencies before starting the static server.');
  process.exit(3);
}

const app = express();
app.use(express.static(distDir));
app.get('*', (_request, response) => response.sendFile(indexFile));
app.listen(port, () => console.log(`Serving ${distDir} at http://localhost:${port}`));
