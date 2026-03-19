#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const INKSCAPE_NS = 'http://www.inkscape.org/namespaces/inkscape';
const DEFAULT_SYSTEM_STYLE_NAMES = new Map([
	['s0', '#references'],
	['s1', 'active_group'],
	['s2', 'inactive_group'],
	['s6', 'dimensions']
]);

function usage() {
	console.log('Usage: node convert-format-5.js <inputBase> <outputBase>');
	console.log('Example: node convert-format-5.js 3604_0 3604_0.layered');
	console.log('  reads : <inputBase>.svg and <inputBase>.slvs');
	console.log('  writes: <outputBase>.svg');
}

function stripKnownExtension(fileOrBase) {
	const value = String(fileOrBase || '').trim();
	return value.replace(/\.(svg|slvs)$/i, '');
}

function ensureInkscapeNamespace(svgText) {
	return svgText.replace(/<svg\b([^>]*)>/i, (full, attrs) => {
		if (/\bxmlns:inkscape\s*=/.test(attrs)) return full;
		return `<svg${attrs} xmlns:inkscape="${INKSCAPE_NS}">`;
	});
}

function normalizeStyleHandle(styleHex) {
	const cleaned = String(styleHex || '').trim().replace(/^0+/, '').toLowerCase();
	return cleaned.length ? cleaned : '0';
}

function parseSlvsStyles(slvsText) {
	const lines = slvsText.split(/\r?\n/);
	const styleMap = new Map();

	let current = null;

	const finalize = () => {
		if (!current || !current.id) return;
		const name = (current.name || '').trim();
		if (!name) return;

		const normalized = normalizeStyleHandle(current.id);
		const className = `s${normalized}`;
		styleMap.set(className, name);
	};

	for (const line of lines) {
		const idMatch = line.match(/^Style\.h\.v=([0-9a-fA-F]+)\s*$/);
		if (idMatch) {
			finalize();
			current = { id: idMatch[1], name: '' };
			continue;
		}

		if (current) {
			const nameMatch = line.match(/^Style\.name=(.*)$/);
			if (nameMatch) {
				current.name = nameMatch[1];
				continue;
			}
			if (/^AddStyle\s*$/.test(line)) {
				finalize();
				current = null;
			}
		}
	}

	finalize();
	return styleMap;
}

function toLayerId(name, fallbackClassName) {
	const normalized = String(name || '')
		.replace(/[^A-Za-z0-9]/g, '_')
		.replace(/_+/g, '_');
	return normalized || `layer_${fallbackClassName}`;
}

function extractClassFromLine(line) {
	const match = line.match(/\bclass\s*=\s*(['"])([^'"]+)\1/);
	if (!match) return [];
	return match[2].split(/\s+/).filter(Boolean);
}

function buildLayerBlock({ className, layerName, lines }) {
	const layerId = toLayerId(layerName, className);
	const body = lines.map(l => `    ${l}`).join('\n');
	return [
		`  <g id="${layerId}" data-name="${layerName}" inkscape:label="${layerName}" inkscape:groupmode="layer">`,
		body,
		'  </g>'
	].join('\n');
}

function getSystemFallbackName(className) {
	if (!/^s[0-9a-f]+$/i.test(className)) return null;
	const key = className.toLowerCase();
	if (DEFAULT_SYSTEM_STYLE_NAMES.has(key)) {
		return DEFAULT_SYSTEM_STYLE_NAMES.get(key);
	}

	const hexPart = key.slice(1);
	const numeric = Number.parseInt(hexPart, 16);
	if (Number.isFinite(numeric) && numeric < 0x100) {
		return `system_${key}`;
	}

	return null;
}

function convertSvgWithSlvs(svgText, slvsText) {
	const styleMap = parseSlvsStyles(slvsText);
	let workingSvg = ensureInkscapeNamespace(svgText);

	const openTagMatch = workingSvg.match(/<svg\b[^>]*>/i);
	const closeTagIndex = workingSvg.lastIndexOf('</svg>');
	if (!openTagMatch || closeTagIndex < 0) {
		throw new Error('Input SVG is missing <svg> root tags.');
	}

	const openTag = openTagMatch[0];
	const contentStart = openTagMatch.index + openTag.length;
	const innerContent = workingSvg.slice(contentStart, closeTagIndex);

	const lines = innerContent.split(/\r?\n/);
	const layerBuckets = new Map();
	const discoveredClasses = new Set();
	const remaining = [];

	for (const line of lines) {
		const classes = extractClassFromLine(line);
		for (const c of classes) discoveredClasses.add(c);
		const matchClass = classes.find(c => styleMap.has(c));
		const fallbackClass = !matchClass ? classes.find(c => getSystemFallbackName(c)) : null;
		const bucketClass = matchClass || fallbackClass;

		if (!bucketClass) {
			remaining.push(line);
			continue;
		}

		if (!layerBuckets.has(bucketClass)) {
			layerBuckets.set(bucketClass, []);
		}
		layerBuckets.get(bucketClass).push(line);
	}

	for (const className of discoveredClasses) {
		if (styleMap.has(className)) continue;
		const fallbackName = getSystemFallbackName(className);
		if (fallbackName) {
			styleMap.set(className, fallbackName);
		}
	}

	const layerBlocks = [];
	for (const [className, styleName] of styleMap.entries()) {
		const bucket = layerBuckets.get(className);
		if (!bucket || bucket.length === 0) continue;
		layerBlocks.push(buildLayerBlock({ className, layerName: styleName, lines: bucket }));
	}

	const groupedSection = layerBlocks.length
		? ['  <!-- Layer groups recovered from SLVS Style.name -->', ...layerBlocks].join('\n')
		: '  <!-- No matching SVG class lines found for SLVS styles -->';

	const rebuiltInner = `${remaining.join('\n')}\n${groupedSection}\n`;
	return `${workingSvg.slice(0, contentStart)}${rebuiltInner}${workingSvg.slice(closeTagIndex)}`;
}

function resolvePaths(argv) {
	if (argv.length === 1) {
		const base = stripKnownExtension(argv[0]);
		if (!base) return null;
		return {
			svgPath: `${base}.svg`,
			slvsPath: `${base}.slvs`,
			outPath: `${base}.layered.svg`
		};
	}

	if (argv.length === 2) {
		const inputBase = stripKnownExtension(argv[0]);
		const outputBase = stripKnownExtension(argv[1]);
		if (!inputBase || !outputBase) return null;

		return {
			svgPath: `${inputBase}.svg`,
			slvsPath: `${inputBase}.slvs`,
			outPath: `${outputBase}.svg`
		};
	}

	return null;
}

function main() {
	const args = process.argv.slice(2);
	const resolved = resolvePaths(args);
	if (!resolved) {
		usage();
		process.exit(1);
	}

	const svgPath = path.resolve(resolved.svgPath);
	const slvsPath = path.resolve(resolved.slvsPath);
	const outPath = path.resolve(resolved.outPath);

	if (!fs.existsSync(svgPath)) {
		throw new Error(`SVG input not found: ${svgPath}`);
	}
	if (!fs.existsSync(slvsPath)) {
		throw new Error(`SLVS input not found: ${slvsPath}`);
	}

	const svgText = fs.readFileSync(svgPath, 'utf8');
	const slvsText = fs.readFileSync(slvsPath, 'utf8');

	const output = convertSvgWithSlvs(svgText, slvsText);
	fs.writeFileSync(outPath, output, 'utf8');

	console.log(`Wrote layered SVG: ${outPath}`);
}

try {
	main();
} catch (err) {
	console.error(`[convert-format-5] ${err.message}`);
	process.exit(1);
}

