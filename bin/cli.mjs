#!/usr/bin/env node
// @linkrunner/skills - install Linkrunner Agent Skills into a customer project.
// Zero-dependency Node ESM so `npx @linkrunner/skills ...` runs anywhere (Node 18+).
//
//   npx @linkrunner/skills list
//   npx @linkrunner/skills add <skill> [--agent claude-code|cursor|windsurf|copilot|agents-md]
//                                      [--dir .] [--dry-run]
//
// One canonical skill folder is compiled to the target agent's native format.
// Claude Code gets the folder verbatim. Single-file agents get the body with
// Markdown references inlined, while all supporting resources are copied under
// .linkrunner/<name>/ so assets, templates, and validators remain available.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const REGISTRY = JSON.parse(fs.readFileSync(path.join(ROOT, 'registry.json'), 'utf8'));

const c = process.stdout.isTTY
  ? { g: '\x1b[32m', r: '\x1b[31m', y: '\x1b[33m', b: '\x1b[1m', d: '\x1b[2m', n: '\x1b[0m' }
  : { g: '', r: '', y: '', b: '', d: '', n: '' };
const ok = (m) => console.log(`${c.g}✓${c.n} ${m}`);
const info = (m) => console.log(`  ${m}`);
const die = (m) => { console.error(`${c.r}error:${c.n} ${m}`); process.exit(1); };

const AGENTS = {
  'claude-code': { marker: '.claude', label: 'Claude Code' },
  cursor: { marker: '.cursor', label: 'Cursor' },
  windsurf: { marker: '.windsurf', label: 'Windsurf' },
  copilot: { marker: '.github/copilot-instructions.md', label: 'GitHub Copilot' },
  'agents-md': { marker: 'AGENTS.md', label: 'AGENTS.md (generic)' },
};

function resolveSkill(query) {
  const q = query.toLowerCase();
  return REGISTRY.skills.find(
    (s) => s.id === q || s.slug === q || s.platform === q || (s.aliases || []).includes(q),
  );
}

function detectAgents(dir) {
  const found = [];
  for (const [key, { marker }] of Object.entries(AGENTS)) {
    if (key === 'agents-md') continue;
    if (fs.existsSync(path.join(dir, marker))) found.push(key);
  }
  return found;
}

function stripFrontmatter(md) {
  const m = md.match(/^---\n[\s\S]*?\n---\n?/);
  return m ? md.slice(m[0].length).trimStart() : md;
}

function readSupportFiles(base) {
  const files = [];
  function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true })
      .sort((a, b) => a.name.localeCompare(b.name));
    for (const entry of entries) {
      const absolute = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(absolute);
      } else if (entry.isFile()) {
        const name = path.relative(base, absolute).split(path.sep).join('/');
        if (name === 'SKILL.md') continue;
        files.push({
          name,
          content: fs.readFileSync(absolute),
          exec: name.startsWith('scripts/') && name.endsWith('.sh'),
        });
      }
    }
  }
  walk(base);
  return files;
}

function readSkill(skill) {
  const base = path.join(ROOT, skill.path);
  const skillMd = fs.readFileSync(path.join(base, 'SKILL.md'), 'utf8');
  const supportFiles = readSupportFiles(base);
  const references = supportFiles
    .filter((f) => f.name.startsWith('references/') && f.name.endsWith('.md'))
    .map((f) => ({ name: path.basename(f.name), content: f.content.toString('utf8') }));
  const scripts = supportFiles
    .filter((f) => f.name.startsWith('scripts/'))
    .map((f) => ({ name: path.basename(f.name), content: f.content }));
  return { base, skillMd, references, scripts, supportFiles };
}

// Body used by single-file targets: SKILL.md minus frontmatter, references inlined.
function inlinedBody(skill, s) {
  let body = stripFrontmatter(s.skillMd);
  for (const ref of s.references) {
    body += `\n\n---\n\n<!-- reference: ${ref.name} -->\n\n${ref.content.trim()}\n`;
  }
  if (s.supportFiles.length) {
    body += `\n\n---\n\nSupporting references, assets, templates, and scripts were installed under \`.linkrunner/${skill.id}/\`. Resolve any relative \`references/...\`, \`assets/...\`, \`templates/...\`, or \`scripts/...\` path from that directory.\n`;
  }
  if (s.scripts.length) {
    body += `\nValidator scripts can be run from the project root, e.g. \`bash .linkrunner/${skill.id}/scripts/${s.scripts[0].name}\`.\n`;
  }
  return body;
}

function writeFile(target, content, plan, exec = false) {
  const bytes = Buffer.isBuffer(content) ? content.length : Buffer.byteLength(content);
  plan.push({ target, bytes, exec });
  if (!plan.dryRun) {
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.writeFileSync(target, content, { mode: exec ? 0o755 : 0o644 });
  }
}

function copySupportFiles(dir, skill, s, plan) {
  const dest = path.join(dir, '.linkrunner', skill.id);
  for (const file of s.supportFiles) {
    writeFile(path.join(dest, file.name), file.content, plan, file.exec);
  }
}

function fm(obj) {
  const lines = Object.entries(obj).map(([k, v]) =>
    typeof v === 'string' && (v.includes('\n') || v.length > 80)
      ? `${k}: >-\n  ${v.replace(/\n/g, '\n  ')}`
      : `${k}: ${v}`,
  );
  return `---\n${lines.join('\n')}\n---\n`;
}

function install(skill, agent, dir, dryRun) {
  const s = readSkill(skill);
  const plan = []; plan.dryRun = dryRun;

  if (agent === 'claude-code') {
    // Verbatim folder: Claude Code supports the complete skill structure.
    const dest = path.join(dir, '.claude', 'skills', skill.id);
    writeFile(path.join(dest, 'SKILL.md'), s.skillMd, plan);
    for (const file of s.supportFiles) writeFile(path.join(dest, file.name), file.content, plan, file.exec);
  } else if (agent === 'cursor') {
    const body = fm({ description: skill.description, globs: '', alwaysApply: false }) + '\n' + inlinedBody(skill, s);
    writeFile(path.join(dir, '.cursor', 'rules', `${skill.id}.mdc`), body, plan);
    copySupportFiles(dir, skill, s, plan);
  } else if (agent === 'windsurf') {
    const body = fm({ trigger: 'model_decision', description: skill.description }) + '\n' + inlinedBody(skill, s);
    writeFile(path.join(dir, '.windsurf', 'rules', `${skill.id}.md`), body, plan);
    copySupportFiles(dir, skill, s, plan);
  } else if (agent === 'copilot') {
    const body = fm({ applyTo: '**', description: skill.description }) + '\n' + inlinedBody(skill, s);
    writeFile(path.join(dir, '.github', 'instructions', `${skill.id}.instructions.md`), body, plan);
    copySupportFiles(dir, skill, s, plan);
  } else if (agent === 'agents-md') {
    const start = `<!-- linkrunner:${skill.id}:start -->`;
    const end = `<!-- linkrunner:${skill.id}:end -->`;
    const section = `${start}\n## ${skill.title}\n\n${inlinedBody(skill, s)}\n${end}`;
    const file = path.join(dir, 'AGENTS.md');
    let existing = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
    const re = new RegExp(`${start}[\\s\\S]*?${end}`);
    existing = re.test(existing) ? existing.replace(re, section) : `${existing.trimEnd()}\n\n${section}\n`;
    writeFile(file, existing.trimStart(), plan);
    copySupportFiles(dir, skill, s, plan);
  }
  return plan;
}

// ---- telemetry (opt-out via LINKRUNNER_SKILLS_NO_TELEMETRY=1) ----
// Fire-and-forget so we can see which platform/agent/channel converts. No PII;
// never blocks or fails the install. Endpoint wiring is a TODO (LIN-2064).
function ping(_skill, _agent) { /* intentionally no-op until endpoint is live */ }

function cmdList() {
  console.log(`${c.b}Linkrunner Agent Skills${c.n} ${c.d}(registry v${REGISTRY.version})${c.n}\n`);
  const byCat = {};
  for (const s of REGISTRY.skills) (byCat[s.category] ||= []).push(s);
  for (const [cat, skills] of Object.entries(byCat)) {
    console.log(`${c.b}${cat}${c.n}`);
    for (const s of skills) console.log(`  ${c.g}${(s.slug || s.platform).padEnd(14)}${c.n} ${s.description.split(':')[0]}`);
    console.log('');
  }
  console.log(`${c.d}install: npx @linkrunner/skills add <name> [--agent <agent>]${c.n}`);
}

function cmdAdd(args) {
  const query = args._[0];
  if (!query) die('specify a skill, e.g. `add flutter` or `add branding`. Run `list` to see options.');
  const skill = resolveSkill(query);
  if (!skill) die(`unknown skill "${query}". Run \`npx @linkrunner/skills list\`.`);

  const dir = path.resolve(args.dir || '.');
  let agents = args.agent ? [args.agent] : detectAgents(dir);
  if (args.agent && !AGENTS[args.agent]) die(`unknown agent "${args.agent}". One of: ${Object.keys(AGENTS).join(', ')}`);
  if (!agents.length) { agents = ['agents-md']; info(`${c.y}no agent config detected - writing generic AGENTS.md${c.n}`); }

  console.log(`${c.b}${skill.title}${c.n}${args['dry-run'] ? c.d + ' (dry run)' + c.n : ''}`);
  for (const agent of agents) {
    const plan = install(skill, agent, dir, !!args['dry-run']);
    ok(`${AGENTS[agent].label}`);
    for (const f of plan) info(`${c.d}${path.relative(dir, f.target)}${f.exec ? ' (exec)' : ''}${c.n}`);
    if (!args['dry-run']) ping(skill, agent);
  }
  console.log(`\n${c.d}docs: ${skill.docs}${c.n}`);
}

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') out['dry-run'] = true;
    else if (a === '--agent') out.agent = argv[++i];
    else if (a === '--dir') out.dir = argv[++i];
    else if (a.startsWith('--')) out[a.slice(2)] = true;
    else out._.push(a);
  }
  return out;
}

const [cmd, ...rest] = process.argv.slice(2);
const args = parseArgs(rest);
if (cmd === 'list' || cmd === 'ls') cmdList();
else if (cmd === 'add' || cmd === 'install') cmdAdd(args);
else {
  console.log(`${c.b}@linkrunner/skills${c.n}\n\n  npx @linkrunner/skills list\n  npx @linkrunner/skills add <skill> [--agent <agent>] [--dir <path>] [--dry-run]\n\nagents: ${Object.keys(AGENTS).join(', ')}`);
  if (cmd && cmd !== 'help' && cmd !== '--help' && cmd !== '-h') process.exit(1);
}
