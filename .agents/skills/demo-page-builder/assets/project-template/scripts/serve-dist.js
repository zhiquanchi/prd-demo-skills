const express = require('express');
const path = require('path');

const app = express();
const port = Number(process.env.PORT) || 8000;
const distDir = path.join(__dirname, '..', 'dist');

app.use(express.static(distDir));
app.get('*', (_request, response) => {
  response.sendFile(path.join(distDir, 'index.html'));
});

app.listen(port, () => {
  console.log(`Serving dist at http://localhost:${port}`);
});
