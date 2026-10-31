import { spawn } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const server = process.argv[2];
const envPath = resolve(import.meta.dirname, '..', '.env');

if (!existsSync(envPath)) {
  throw new Error('Create .agents/.env from .agents/.env.example first.');
}

for (const rawLine of readFileSync(envPath, 'utf8').split(/\r?\n/u)) {
  const line = rawLine.trim();
  if (!line || line.startsWith('#')) continue;
  const separator = line.indexOf('=');
  if (separator < 1) throw new Error('Invalid .agents/.env line. Use KEY=value.');
  process.env[line.slice(0, separator).trim()] = line.slice(separator + 1).trim();
}

const commands = {
  context7: ['@upstash/context7-mcp@4.0.4'],
  'postgres-readonly': ['mcp-postgres-server@0.3.1'],
};
const args = commands[server];

if (!args) throw new Error(`Unknown MCP server: ${server}`);
if (server === 'context7' && !process.env.CONTEXT7_API_KEY) {
  throw new Error('CONTEXT7_API_KEY is required.');
}
if (server === 'postgres-readonly') {
  if (!process.env.SWANSPORT_READONLY_DATABASE_URL) {
    throw new Error('SWANSPORT_READONLY_DATABASE_URL is required.');
  }
  process.env.DATABASE_URL = process.env.SWANSPORT_READONLY_DATABASE_URL;
  process.env.PG_ALLOW_WRITE = 'false';
}

const isWin = process.platform === 'win32';
const command = isWin ? 'cmd.exe' : 'npx';
const commandArgs = isWin ? ['/d', '/s', '/c', 'npx.cmd', '-y', ...args] : ['-y', ...args];
const child = spawn(command, commandArgs, { env: process.env, stdio: 'inherit' });
child.on('exit', (code) => process.exit(code ?? 1));
