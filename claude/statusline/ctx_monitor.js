#!/usr/bin/env node
"use strict";

const fs = require("fs");
const { execSync } = require("child_process");

// --- input ---
const input = readJSON(0); // stdin
const transcript = input.transcript_path;
const model = input.model || {};
const name = `\x1b[95m${String(model.display_name ?? "")}\x1b[0m`.trim();
const modelId = String(model.model_id ?? model.id ?? "").toLowerCase();
const CONTEXT_WINDOW = modelId.includes("1m") ? 1_000_000 : 200_000;
const cwd = String(input.workspace?.current_dir ?? input.cwd ?? "");

// --- git info ---
function getGitBranch(dir) {
  try {
    return execSync("git -C " + JSON.stringify(dir) + " rev-parse --abbrev-ref HEAD 2>/dev/null", {
      encoding: "utf8",
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
  } catch {
    return null;
  }
}

function isWorktree(dir) {
  try {
    // .git is a file (not a directory) in a worktree
    const gitPath = dir + "/.git";
    const stat = fs.statSync(gitPath);
    return stat.isFile();
  } catch {
    return false;
  }
}

const gitBranch = cwd ? getGitBranch(cwd) : null;
const worktree = cwd ? isWorktree(cwd) : false;

// --- helpers ---
function readJSON(fd) {
  try {
    return JSON.parse(fs.readFileSync(fd, "utf8"));
  } catch {
    return {};
  }
}
function color(p) {
  if (p >= 90) return "\x1b[31m"; // red
  if (p >= 70) return "\x1b[33m"; // yellow
  return "\x1b[32m"; // green
}
const comma = (n) =>
  new Intl.NumberFormat("en-US").format(
    Math.max(0, Math.floor(Number(n) || 0))
  );

function usedTotal(u) {
  return (
    (u?.input_tokens ?? 0) +
    (u?.output_tokens ?? 0) +
    (u?.cache_read_input_tokens ?? 0) +
    (u?.cache_creation_input_tokens ?? 0)
  );
}

function syntheticModel(j) {
  const m = String(j?.message?.model ?? "").toLowerCase();
  return m === "<synthetic>" || m.includes("synthetic");
}

function assistantMessage(j) {
  return j?.message?.role === "assistant";
}

function subContext(j) {
  return j?.isSidechain === true;
}

function contentNoResponse(j) {
  const c = j?.message?.content;
  return (
    Array.isArray(c) &&
    c.some(
      (x) =>
        x &&
        x.type === "text" &&
        /no\s+response\s+requested/i.test(String(x.text))
    )
  );
}

function parseTs(j) {
  const t = j?.timestamp;
  const n = Date.parse(t);
  return Number.isFinite(n) ? n : -Infinity;
}

// Find the newest main-context entry by timestamp (not file order)
function newestMainUsageByTimestamp() {
  if (!transcript) return null;
  let latestTs = -Infinity;
  let latestUsage = null;

  let lines;
  try {
    lines = fs.readFileSync(transcript, "utf8").split(/\r?\n/);
  } catch {
    return null;
  }

  for (let i = lines.length - 1; i >= 0; i--) {
    const line = lines[i].trim();
    if (!line) continue;

    let j;
    try {
      j = JSON.parse(line);
    } catch {
      continue;
    }
    const u = j.message?.usage;
    if (
      subContext(j) ||
      syntheticModel(j) ||
      j.isApiErrorMessage === true ||
      usedTotal(u) === 0 ||
      contentNoResponse(j) ||
      !assistantMessage(j)
    )
      continue;

    const ts = parseTs(j);
    if (ts > latestTs) {
      latestTs = ts;
      latestUsage = u;
    }
    else if (ts == latestTs && usedTotal(u) > usedTotal(latestUsage)) {
      latestUsage = u;
    }
  }
  return latestUsage;
}

// --- git line ---
function buildGitLine() {
  if (!gitBranch) return null;
  const branchLabel = `\x1b[36m${gitBranch}\x1b[0m`;
  const worktreeLabel = worktree ? " \x1b[33m[worktree]\x1b[0m" : "";
  return `git: ${branchLabel}${worktreeLabel}`;
}

const gitLine = buildGitLine();

// --- compute/print ---
const usage = newestMainUsageByTimestamp();
if (!usage) {
  const lines = [
    `${name} | \x1b[36mcontext window usage starts after your first question.\x1b[0m`,
  ];
  if (gitLine) lines.push(gitLine);
  console.log(lines.join("\n"));
  process.exit(0);
}

const used = usedTotal(usage);
const pct = CONTEXT_WINDOW > 0 ? Math.round((used * 1000) / CONTEXT_WINDOW) / 10 : 0;

const usagePercentLabel = `${color(pct)}context used ${pct.toFixed(1)}%\x1b[0m`;
const usageCountLabel = `\x1b[33m(${comma(used)}/${comma(
  CONTEXT_WINDOW
)})\x1b[0m`;

const lines = [
  `${name} | ${usagePercentLabel} - ${usageCountLabel}`,
];
if (gitLine) lines.push(gitLine);
console.log(lines.join("\n"));
