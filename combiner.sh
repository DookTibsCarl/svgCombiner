#!/usr/local/bin/node

/**
 * Utility script that takes individual svg files and combines them into a single file. viewBox is moved from
 * top-level svg element into the symbol definition. Alternate symbols also generated (for IE6-8).
 *
 * "npm install" should install all dependencies.
 * 
 * dependencies:
 *		Node.js
 * 		xmldoc (https://github.com/nfarina/xmldoc); "npm install xmldoc" to install
 *		optimist (https://github.com/substack/node-optimist); "npm install optimist" to install
 */
console.log("Carleton SVG Combiner v0.1a");

// pull in external libraries
try {
	var argv = require('optimist')
		// .usage('Usage: $0 -dir [DIRECTORY_CONTAINING_SVGS] -output [OUTPUT_FILEBASE] -c')
		.describe('dir', 'directory containing svg files')
		.describe('output', 'base filename that will be used to generate both svg and html example files')
		.describe('c', 'if present, \'fill="currentColor"\' will be added to all svg nodes')
		.demand(['dir', 'output'])
		.argv;
	var fs = require('fs');
	var xmldoc = require('xmldoc');
} catch (e) {
	console.log("Error loading dependencies; did you run 'npm install'?");
	return;
}

String.prototype.endsWith = function(suffix) { return this.indexOf(suffix, this.length - suffix.length) !== -1; };

var manualXml = "<?xml version=\"1.0\"?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\">\n\t<defs>\n";
var manualHtml = "";

var dirToCheck = argv.dir;
var outputSvgFile = argv.output + ".svg";
var outputHtmlFile = argv.output + ".html";

function writeFile(filename, contents) {
	console.log("Generating output file '" + filename + "'...");
	try {
		fs.writeFileSync(filename, contents);
	} catch (e) {
		console.log("Error writing output file '" + filename + "': " + e);
	}
}

function pad(s, num) {
	var rv = "";
	for (var i = 0 ; i < num ; i++) {
		rv += s;
	}
	return rv;
}

function processNodeForSvg(n, depth) {
	var rv = "";
	var padder = pad("\t", depth+1);
	var goingDeeper = n.children.length > 0;

	if (depth > 1) {
		// console.log("looking at [" + n.name + "]/[" + depth + "]/[" + n.val + "]...[" + n.children.length + "] kids");

		var props = "";
		var fillExists = false;
		for (var prop in n.attr) {
			var propVal = n.attr[prop];
			if (prop == "fill") {
				fillExists = true;
				propVal = "currentColor";
			}

			props += " " + prop + "=\"" + propVal + "\"";
		}

		// if -c passed in on command line, insert a "fill=currentColor" if it was missing
		if (!fillExists && argv.c) {
			props += " fill=\"currentColor\"";
		}

		rv = padder + "<" + n.name + props;
	}

	if (n.val.trim() != "") {
		rv += ">" + n.val + "</" + n.name + ">\n";
	} else {
		rv += (goingDeeper ? ">" : "/>") + "\n";

		if (goingDeeper) {
			var children = n.children;
			for (var i = 0 ; i < children.length ; i++) {
				rv += processNodeForSvg(children[i], depth+1);
			}

			if (depth > 1) {
				rv += padder + "</" + n.name + ">\n";
			}
		}
	}

	return rv;
}

try {
	var files = fs.readdirSync(dirToCheck);

	for (var index in files) {
		var f = files[index];

		if (f.endsWith(".svg")) {
			console.log("processing " + f + "...");
			var symbolName = f.substring(0, f.indexOf(".svg"));

			try {
				fileData = fs.readFileSync(dirToCheck + "/" + f);

				if (fileData) {
					var document = new xmldoc.XmlDocument(fileData.toString('utf8'));

					manualXml += "\t\t<symbol id=\"" + symbolName + "\" role=\"img\" viewBox=\"" + document.attr.viewBox + "\">\n";
					manualXml += "\t\t\t<title>" + symbolName + " icon</title>\n";

					manualXml += processNodeForSvg(document, 1);

					var usage = "<svg title=\"" + symbolName + " icon\"><use xlink:href=\"" + outputSvgFile + "#" + symbolName + "\"/>";
					var usageAlt = "<svg title=\"" + symbolName + " icon\"><use xlink:href=\"" + outputSvgFile + "#" + symbolName + "Alt\"/>";
					manualHtml += "<tr><td>" + symbolName + "</td><td>" + usage + "</td><td style='color:purple'>" + usage + "</td><td>" + usageAlt + "</td></tr>";

					manualXml += "\t\t</symbol>\n";
					manualXml += "\t\t<symbol id=\"" + symbolName + "Alt\"><svg><use xlink:href=\"" + outputSvgFile + "#" + symbolName + "\"/></svg></symbol>\n";
				}
			} catch (e) {
				throw err;
			}

			// console.log(manualXml);
			// return;
		}
	}
} catch (e) {
	console.log("Unable to read directory '" + dirToCheck + "'");
}

manualXml += "\t</defs>\n</svg>";

// console.log("--- OUTPUT ---");
// console.log(manualXml);

manualHtml = "<html>\n<head>\n<meta http-equiv=\"X-UA-Compatible\" content=\"UE=Edge\">\n<script src=\"svg4everybody.ie8.min.js\"></script>\n</head>\n<body>\n<H2>Sample Usage</H2><table border=1 width=100%><tr><th>symbol name</th><th>basic</th><th>styled with color=purple<br>(try running again with -c if not getting colors you expect)</th><th>alternate</th></tr>" + manualHtml + "\n</table></body>\n</html>";

writeFile(outputSvgFile, manualXml);
writeFile(outputHtmlFile, manualHtml);
