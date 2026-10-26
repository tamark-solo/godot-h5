"""[H5 FORK] Embed the Web export template pair and the H5 project template
into the editor binary, so a single EXE is enough on a clean machine.

Input directory (SCons option h5_embed_dir) has the portable-package layout:
    web-templates-manifest.json
    web_templates/debug/<file>.zip
    web_templates/release/<file>.zip
    h5_template/...

The build FAILS (instead of embedding a wrong pair) when:
    - a ZIP's SHA256 does not match the manifest,
    - debug and release are the same bytes,
    - the manifest source SHA is not the engine HEAD being built,
    - the manifest says the templates were built from a dirty tree,
    - h5_template/ has no addons/h5/plugin.cfg.
With h5_embed_dir empty nothing is embedded (plain fork build, folder fallback).
"""

import hashlib
import io
import json
import os
import struct
import subprocess
import zipfile

import methods

FIXED_DATE = (1980, 1, 1, 0, 0, 0)


class H5EmbedError(Exception):
    pass


def git_head(engine_root):
    try:
        return subprocess.check_output(["git", "-C", engine_root, "rev-parse", "HEAD"], text=True).strip()
    except Exception:
        return ""


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def _u64_array(data):
    # Little-endian uint64 words: ~2.5 source chars per byte (vs ~5 for decimal bytes).
    # Windows x64 and macOS (x86_64/arm64) are little-endian; size is stored separately.
    if not data:
        return "\t0,"
    padded = data + b"\0" * ((-len(data)) % 8)
    vals = struct.unpack("<%dQ" % (len(padded) // 8), padded)
    lines = []
    for i in range(0, len(vals), 8):
        lines.append("\t" + ", ".join("0x%016x" % v for v in vals[i : i + 8]) + ",")
    return "\n".join(lines)


def _zip_tree(root):
    # Deterministic ZIP (sorted entries, fixed timestamps): same input -> same bytes -> same hash.
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(d for d in dirnames if d != ".godot")
            for name in sorted(filenames):
                full = os.path.join(dirpath, name)
                rel = os.path.relpath(full, root).replace(os.sep, "/")
                info = zipfile.ZipInfo(rel, FIXED_DATE)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o644 << 16
                with open(full, "rb") as f:
                    zf.writestr(info, f.read())
    return buf.getvalue()


def _collect(embed_dir, engine_root):
    if not embed_dir:
        return [], "", ""
    embed_dir = os.path.abspath(embed_dir)
    with open(os.path.join(embed_dir, "web-templates-manifest.json"), "rb") as f:
        mf_raw = f.read()
    mf = json.loads(mf_raw.decode("utf-8-sig"))

    data = {}
    for flavor in ("debug", "release"):
        t = mf["templates"][flavor]
        if t.get("flavor") != flavor:
            raise H5EmbedError("manifest templates.%s declares flavor '%s'" % (flavor, t.get("flavor")))
        path = os.path.join(embed_dir, "web_templates", flavor, t["file"])
        with open(path, "rb") as f:
            data[flavor] = f.read()
        if _sha256(data[flavor]) != str(t["sha256"]).lower():
            raise H5EmbedError("%s: SHA256 does not match the manifest" % path)
    if data["debug"] == data["release"]:
        raise H5EmbedError("debug and release templates are identical")

    src = str(mf["source"]["upstreamSha"])
    head = git_head(engine_root)
    if not head or src != head:
        raise H5EmbedError("templates were built from %s but the engine HEAD is %s" % (src, head or "?"))
    if int(mf["source"].get("dirtyFiles", 0)) != 0:
        raise H5EmbedError("templates were built from a dirty tree")

    tpl_root = os.path.join(embed_dir, "h5_template")
    if not os.path.isfile(os.path.join(tpl_root, "addons", "h5", "plugin.cfg")):
        raise H5EmbedError("%s has no addons/h5/plugin.cfg" % tpl_root)

    blobs = [
        ("web_nothreads_debug.zip", "h5_blob_web_debug", data["debug"]),
        ("web_nothreads_release.zip", "h5_blob_web_release", data["release"]),
        ("h5_manifest.json", "h5_blob_manifest", mf_raw),
        ("h5_template.zip", "h5_blob_template", _zip_tree(tpl_root)),
    ]
    return blobs, str(mf.get("label", "")), src


def make_h5_embed(target, source, env):
    embed_dir = source[0].read()
    try:
        blobs, label, src = _collect(embed_dir, env.Dir("#").abspath)
    except (OSError, KeyError, ValueError, H5EmbedError) as e:
        print("[H5] ERROR: cannot embed h5_embed_dir='%s': %s" % (embed_dir, e))
        return 1

    by_var = {b[1]: b for b in blobs}
    h_path, dbg_path, rel_path, misc_path = [str(t) for t in target]

    with methods.generated_wrapper(h_path) as f:
        f.write("""\
#include <cstdint>

struct H5EmbeddedBlob {
\tconst char *name;
\tconst uint64_t *data;
\tuint64_t size;
\tconst char *sha256;
};

extern const H5EmbeddedBlob h5_embedded_blobs[];
extern const int h5_embedded_blob_count;
extern const char *const h5_embedded_label;
extern const char *const h5_embedded_source_sha;
""")

    def blob_def(var):
        payload = by_var[var][2] if var in by_var else b""
        return "extern const uint64_t %s[] = {\n%s\n};\n" % (var, _u64_array(payload))

    for path, var in ((dbg_path, "h5_blob_web_debug"), (rel_path, "h5_blob_web_release")):
        with methods.generated_wrapper(path) as f:
            f.write('#include "editor/h5/h5_embed_data.gen.h"\n\n' + blob_def(var))

    with methods.generated_wrapper(misc_path) as f:
        f.write('#include "editor/h5/h5_embed_data.gen.h"\n\n')
        f.write("extern const uint64_t h5_blob_web_debug[];\nextern const uint64_t h5_blob_web_release[];\n\n")
        f.write(blob_def("h5_blob_manifest") + "\n" + blob_def("h5_blob_template") + "\n")
        rows = ['\t{ "%s", %s, %dULL, "%s" },' % (name, var, len(payload), _sha256(payload)) for name, var, payload in blobs]
        if not rows:
            rows = ["\t{ nullptr, nullptr, 0ULL, nullptr },"]
        f.write("extern const H5EmbeddedBlob h5_embedded_blobs[] = {\n%s\n};\n" % "\n".join(rows))
        f.write("extern const int h5_embedded_blob_count = %d;\n" % len(blobs))
        f.write('extern const char *const h5_embedded_label = "%s";\n' % label.replace('"', ""))
        f.write('extern const char *const h5_embedded_source_sha = "%s";\n' % src)

    if blobs:
        print("[H5] Embedded '%s' @ %s: %s" % (label, src[:10], ", ".join("%s %.1f MB" % (b[0], len(b[2]) / 1048576.0) for b in blobs)))
    else:
        print("[H5] h5_embed_dir not set: nothing embedded (h5_template folder next to the EXE is required).")
    return 0
