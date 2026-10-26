#!/usr/bin/env node
// Keeps every copy of the package version in agreement:
//
//   package.json, package-lock.json   npm version (the podspec reads package.json)
//   ios/AppstackBridge.swift          wrapperVersion = "react-native-<version>"
//   android/.../ModuleImpl.kt         WRAPPER_VERSION = "react-native-<version>"
//   CHANGELOG.md                      first section below Unreleased: ## [<version>] - YYYY-MM-DD
//
// Usage:
//   node scripts/set-version.mjs 3.6.0                  stamp all files and cut the changelog section
//   node scripts/set-version.mjs 3.6.0-rc.1 --no-changelog
//                                                       stamp the files only (build.yml, for RCs)
//   node scripts/set-version.mjs --check [3.6.0]        fail unless every copy agrees (and equals 3.6.0)
//
// A stable release is published byte-for-byte from the reviewed commit, so
// build.yml only runs --check for it. RCs are stamped at publish time because
// their version is a dispatch input, not a commit.

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const files = {
  manifest: path.join(root, 'package.json'),
  lock: path.join(root, 'package-lock.json'),
  swift: path.join(root, 'ios', 'AppstackBridge.swift'),
  kotlin: path.join(
    root,
    'android/src/main/kotlin/com/appstack/reactnative/AppstackReactNativeModuleImpl.kt'
  ),
  changelog: path.join(root, 'CHANGELOG.md'),
};

const stablePattern = /^\d+\.\d+\.\d+$/;
const anyPattern = /^\d+\.\d+\.\d+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$/;
const swiftPattern = /(private static let wrapperVersion = "react-native-)([^"]*)(")/;
const kotlinPattern = /(private const val WRAPPER_VERSION = "react-native-)([^"]*)(")/;
const releasedHeader = /^## \[([^\]]+)\] - (\d{4}-\d{2}-\d{2})$/;

function fail(message) {
  console.error(`::error::${message}`);
  process.exit(1);
}

const read = (file) => fs.readFileSync(file, 'utf8');
const rel = (file) => path.relative(root, file);

function readJson(file) {
  return JSON.parse(read(file));
}

// First "## [" header that isn't [Unreleased], with its line index.
function latestSection(lines) {
  const index = lines.findIndex((line) => line.startsWith('## [') && line !== '## [Unreleased]');
  return { index, header: index === -1 ? '' : lines[index] };
}

function readWrapper(file, pattern) {
  const match = read(file).match(pattern);
  if (!match) fail(`Could not find the wrapper version constant in ${rel(file)}.`);
  return match[2];
}

function stampWrapper(file, pattern, version) {
  const source = read(file);
  if (!pattern.test(source)) fail(`Could not find the wrapper version constant in ${rel(file)}.`);
  return source.replace(pattern, `$1${version}$3`);
}

// Returns the changelog with a new section cut from Unreleased, or null when
// that section already exists.
function cutChangelog(version) {
  const lines = read(files.changelog).split('\n');
  const unreleased = lines.indexOf('## [Unreleased]');
  if (unreleased === -1) fail('CHANGELOG.md has no "## [Unreleased]" heading.');

  const { header } = latestSection(lines);
  if (header.startsWith(`## [${version}]`)) {
    console.log(`CHANGELOG.md already has a ${version} section; leaving it.`);
    return null;
  }

  const next = lines.findIndex((line, i) => i > unreleased && line.trim() !== '');
  if (next === -1 || lines[next].startsWith('## [')) {
    fail('Nothing under "## [Unreleased]" to release. Add the changes to CHANGELOG.md first.');
  }

  const date = new Date().toISOString().slice(0, 10);
  lines.splice(unreleased + 1, 0, '', `## [${version}] - ${date}`);
  return lines.join('\n');
}

function set(version, { changelog }) {
  if (!anyPattern.test(version)) fail(`"${version}" is not a valid version.`);
  if (changelog && !stablePattern.test(version)) {
    fail(`Changelog sections are for stable versions; pass --no-changelog for "${version}".`);
  }

  const manifest = readJson(files.manifest);
  manifest.version = version;
  const lock = readJson(files.lock);
  lock.version = version;
  lock.packages[''].version = version;

  // Everything is computed before anything is written, so a failure (say, an
  // empty Unreleased section) leaves every file as it was.
  const writes = [
    [files.manifest, `${JSON.stringify(manifest, null, 2)}\n`],
    [files.lock, `${JSON.stringify(lock, null, 2)}\n`],
    [files.swift, stampWrapper(files.swift, swiftPattern, version)],
    [files.kotlin, stampWrapper(files.kotlin, kotlinPattern, version)],
  ];
  const cut = changelog ? cutChangelog(version) : null;
  if (cut !== null) writes.push([files.changelog, cut]);

  for (const [file, content] of writes) fs.writeFileSync(file, content);
  console.log(`Set version ${version}.`);
}

function check(expected) {
  const version = readJson(files.manifest).version;
  const lock = readJson(files.lock);
  const { header } = latestSection(read(files.changelog).split('\n'));
  const section = header.match(releasedHeader);

  const copies = [
    ['package.json', version],
    ['package-lock.json', lock.version],
    ['package-lock.json packages[""]', lock.packages[''].version],
    [rel(files.swift), readWrapper(files.swift, swiftPattern)],
    [rel(files.kotlin), readWrapper(files.kotlin, kotlinPattern)],
    ['CHANGELOG.md latest section', section ? section[1] : `(malformed: "${header}")`],
  ];

  const problems = [];
  if (!stablePattern.test(version))
    problems.push(`package.json version "${version}" is not X.Y.Z.`);
  if (expected !== undefined && version !== expected) {
    problems.push(`package.json is at ${version}, expected ${expected}.`);
  }
  for (const [where, value] of copies) {
    if (value !== version) problems.push(`${where} has "${value}", package.json has "${version}".`);
  }

  const width = Math.max(...copies.map(([where]) => where.length));
  for (const [where, value] of copies) console.log(`${where.padEnd(width)}  ${value}`);
  if (problems.length > 0) {
    for (const problem of problems) console.error(`::error::${problem}`);
    console.error(`Run: node scripts/set-version.mjs ${expected ?? version}`);
    process.exit(1);
  }
  console.log(`All copies agree on ${version}.`);
}

const args = process.argv.slice(2);
if (args[0] === '--check') {
  if (args.length > 2) fail('Usage: set-version.mjs --check [<version>]');
  check(args[1]);
} else if (args.length >= 1 && args.length <= 2 && !args[0].startsWith('--')) {
  const flags = args.slice(1);
  if (flags.some((flag) => flag !== '--no-changelog')) fail(`Unknown option: ${flags.join(' ')}`);
  set(args[0], { changelog: !flags.includes('--no-changelog') });
} else {
  fail('Usage: set-version.mjs <version> [--no-changelog] | --check [<version>]');
}
