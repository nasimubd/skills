#!/usr/bin/env node
// Health probe: can the configured n8n API be read with the configured key? Prints the HTTP
// status only. The key is read and decoded by template/scripts/lib/platform.js, the same code
// a scaffolded repository uses, and never printed. Exit 0 on HTTP 200.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const P = require('../template/scripts/lib/platform');

const file = path.join(process.env.AUTOMATION_SCAFFOLD_CONFIG_DIR || path.join(os.homedir(), '.config', 'automation-scaffold'), 'config.json');
const config = JSON.parse(fs.readFileSync(file, 'utf8'));

(async () => {
  const res = await fetch(`${P.n8nBase(config)}/api/v1/workflows?limit=1`, { headers: P.n8nAuth(config) });
  console.log(`n8n API: HTTP ${res.status}`);
  process.exitCode = res.status === 200 ? 0 : 1;
})().catch((e) => { console.error(`n8n API: ${e.message}`); process.exitCode = 1; });
