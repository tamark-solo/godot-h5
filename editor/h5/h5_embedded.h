/**************************************************************************/
/*  h5_embedded.h                                                         */
/**************************************************************************/
/* [H5 FORK] Single-EXE embedding of Web export templates + H5 template.  */
/* Based on Godot Engine (MIT). See LICENSE.txt / COPYRIGHT.txt.          */
/**************************************************************************/

#pragma once

#include "core/error/error_list.h"
#include "core/string/ustring.h"

// [H5 FORK] Access to data embedded at build time (h5_embed_dir).
class H5Embedded {
public:
	static bool has(const String &p_name);
	static String get_label();
	static String get_source_sha();

	// Writes the embedded Web template pair (+ h5_manifest.json, version.txt) into
	// <export_templates>/<GODOT_VERSION_FULL_CONFIG>/ when missing or different.
	// Existing different files are moved to _backup-<unix time>/ first. No-op for
	// a build without embedded templates.
	static Error install_web_templates();

	// Extracts the embedded H5 project template into p_dest.
	static Error extract_h5_template(const String &p_dest);
};
