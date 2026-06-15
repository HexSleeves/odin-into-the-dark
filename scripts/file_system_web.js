// JS half of the engine's web (localStorage) file system backend.
// Bound to the foreign "itd_storage" module declared in
// src/engine/file_system_web.odin. Save blobs are base64-encoded and stored in
// localStorage under their path string as the key.
//
// Wiring (mirrors karl2d's audio backend):
//   imports = { ...imports, ...itdStorageJsImports };
//   setItdStorageWasmMemory(exports.memory);
// See scripts/build_karl2d_web.sh, which injects both lines into index.html.

let itdStorageWasmMemory = null;

function setItdStorageWasmMemory(memory) {
	itdStorageWasmMemory = memory;
}

// Namespaced key prefix so save data never collides with unrelated localStorage
// entries on the same origin.
const ITD_LS_PREFIX = "itd:";

function itdLoadString(ptr, len) {
	const bytes = new Uint8Array(itdStorageWasmMemory.buffer, ptr, len);
	return new TextDecoder().decode(bytes);
}

function itdLsKey(ptr, len) {
	return ITD_LS_PREFIX + itdLoadString(ptr, len);
}

// base64 helpers that round-trip arbitrary bytes (binary save blobs), avoiding
// btoa/atob's Latin-1 pitfalls.
function itdBytesToBase64(bytes) {
	let binary = "";
	const chunk = 0x8000;
	for (let i = 0; i < bytes.length; i += chunk) {
		binary += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
	}
	return btoa(binary);
}

function itdBase64ToBytes(b64) {
	const binary = atob(b64);
	const out = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i++) {
		out[i] = binary.charCodeAt(i);
	}
	return out;
}

function itdLsDecode(key) {
	let b64;
	try {
		b64 = window.localStorage.getItem(key);
	} catch (e) {
		return null;
	}
	if (b64 === null) {
		return null;
	}
	try {
		return itdBase64ToBytes(b64);
	} catch (e) {
		return null;
	}
}

const itdStorageJsImports = {
	itd_storage: {
		itd_ls_read_len: function (path_ptr, path_len) {
			const decoded = itdLsDecode(itdLsKey(path_ptr, path_len));
			return decoded === null ? -1 : decoded.length;
		},

		itd_ls_read_into: function (path_ptr, path_len, buf_ptr, buf_len) {
			const decoded = itdLsDecode(itdLsKey(path_ptr, path_len));
			if (decoded === null || decoded.length > buf_len) {
				return -1;
			}
			const dst = new Uint8Array(itdStorageWasmMemory.buffer, buf_ptr, buf_len);
			dst.set(decoded);
			return decoded.length;
		},

		itd_ls_write: function (path_ptr, path_len, data_ptr, data_len) {
			const key = itdLsKey(path_ptr, path_len);
			// Copy out of WASM memory before encoding; the view is invalidated if
			// the heap grows mid-call.
			const src = new Uint8Array(
				itdStorageWasmMemory.buffer.slice(data_ptr, data_ptr + data_len),
			);
			try {
				window.localStorage.setItem(key, itdBytesToBase64(src));
				return true;
			} catch (e) {
				// Quota exceeded, private-mode storage disabled, etc.
				console.error("itd_ls_write failed:", e);
				return false;
			}
		},

		itd_ls_exists: function (path_ptr, path_len) {
			try {
				return window.localStorage.getItem(itdLsKey(path_ptr, path_len)) !== null;
			} catch (e) {
				return false;
			}
		},

		itd_ls_remove: function (path_ptr, path_len) {
			try {
				window.localStorage.removeItem(itdLsKey(path_ptr, path_len));
				return true;
			} catch (e) {
				return false;
			}
		},

		itd_ls_rename: function (old_ptr, old_len, new_ptr, new_len) {
			const oldKey = itdLsKey(old_ptr, old_len);
			const newKey = itdLsKey(new_ptr, new_len);
			try {
				const value = window.localStorage.getItem(oldKey);
				if (value === null) {
					return false;
				}
				window.localStorage.setItem(newKey, value);
				window.localStorage.removeItem(oldKey);
				return true;
			} catch (e) {
				console.error("itd_ls_rename failed:", e);
				return false;
			}
		},
	},
};

window.setItdStorageWasmMemory = setItdStorageWasmMemory;
