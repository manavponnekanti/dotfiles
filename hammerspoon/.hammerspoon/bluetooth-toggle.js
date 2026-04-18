#!/usr/bin/env osascript -l JavaScript
ObjC.import("CoreBluetooth");
ObjC.import("IOBluetooth");

function json(value) {
	return JSON.stringify(value);
}

function normalizeAddress(address) {
	return String(address || "")
		.replace(/[^0-9A-Fa-f]/g, "")
		.toLowerCase();
}

function run(argv) {
	const target = normalizeAddress(argv[0]);
	if (!target) return json({ ok: false, error: "missing-address" });

	const { majorVersion: major, minorVersion: minor } =
		$.NSProcessInfo.processInfo.operatingSystemVersion;
	if ((Number(major) === 10 && Number(minor) < 15) || Number(major) < 10) {
		return json({ ok: false, error: "unsupported-macos" });
	}

	if ($.CBManager && $.CBManager.authorization !== $.CBManagerAuthorizationAllowedAlways) {
		return json({ ok: false, error: "bluetooth-permission" });
	}

	const devices = $.IOBluetoothDevice.pairedDevices.js;
	const device = devices.find((candidate) => normalizeAddress(candidate.addressString.js) === target);
	if (!device) return json({ ok: false, error: "not-found" });

	const wasConnected = Boolean(device.isConnected);
	const name = String(device.nameOrAddress.js || device.addressString.js);

	try {
		if (wasConnected) {
			device.closeConnection;
		} else {
			device.openConnection(null);
		}
	} catch (error) {
		return json({
			ok: false,
			error: "toggle-failed",
			name,
			detail: String(error),
		});
	}

	return json({
		ok: true,
		action: wasConnected ? "disconnect" : "connect",
		name,
		address: String(device.addressString.js),
	});
}
