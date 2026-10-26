/**************************************************************************/
/*  h5_embedded.cpp                                                       */
/**************************************************************************/
/* [H5 FORK] Single-EXE embedding of Web export templates + H5 template.  */
/* Based on Godot Engine (MIT). See LICENSE.txt / COPYRIGHT.txt.          */
/**************************************************************************/

#include "h5_embedded.h"

#include "core/io/dir_access.h"
#include "core/io/file_access.h"
#include "core/io/zip_io.h"
#include "core/os/time.h"
#include "core/version.h"
#include "editor/file_system/editor_paths.h"
#include "editor/h5/h5_embed_data.gen.h"

static const H5EmbeddedBlob *_h5_find(const String &p_name) {
	for (int i = 0; i < h5_embedded_blob_count; i++) {
		if (p_name == h5_embedded_blobs[i].name) {
			return &h5_embedded_blobs[i];
		}
	}
	return nullptr;
}

// Write to <path>.h5tmp, verify SHA256 against the build-time hash, then rename.
static Error _h5_write_verified(const String &p_path, const H5EmbeddedBlob *p_blob) {
	const String tmp = p_path + ".h5tmp";
	bool ok = false;
	{
		Error err = OK;
		Ref<FileAccess> f = FileAccess::open(tmp, FileAccess::WRITE, &err);
		if (f.is_null()) {
			return err != OK ? err : ERR_CANT_CREATE;
		}
		ok = p_blob->size == 0 || f->store_buffer((const uint8_t *)p_blob->data, p_blob->size);
	}
	if (!ok) {
		DirAccess::remove_absolute(tmp);
		return ERR_FILE_CANT_WRITE;
	}
	if (FileAccess::get_sha256(tmp) != String(p_blob->sha256)) {
		DirAccess::remove_absolute(tmp);
		return ERR_FILE_CORRUPT;
	}
	if (FileAccess::exists(p_path)) {
		Error rm = DirAccess::remove_absolute(p_path);
		if (rm != OK) {
			DirAccess::remove_absolute(tmp);
			return rm;
		}
	}
	return DirAccess::rename_absolute(tmp, p_path);
}

bool H5Embedded::has(const String &p_name) {
	return _h5_find(p_name) != nullptr;
}

String H5Embedded::get_label() {
	return String::utf8(h5_embedded_label);
}

String H5Embedded::get_source_sha() {
	return String(h5_embedded_source_sha);
}

Error H5Embedded::install_web_templates() {
	const H5EmbeddedBlob *items[3] = { _h5_find("web_nothreads_debug.zip"), _h5_find("web_nothreads_release.zip"), _h5_find("h5_manifest.json") };
	if (items[0] == nullptr || items[1] == nullptr || items[2] == nullptr) {
		return OK; // Not an embedded build.
	}
	ERR_FAIL_NULL_V(EditorPaths::get_singleton(), ERR_UNCONFIGURED);

	const String dir = EditorPaths::get_singleton()->get_export_templates_dir().path_join(GODOT_VERSION_FULL_CONFIG);
	Error err = DirAccess::make_dir_recursive_absolute(dir);
	ERR_FAIL_COND_V_MSG(err != OK, err, vformat("[H5] Cannot create export templates directory '%s'.", dir));

	String backup_dir;
	int written = 0;
	for (const H5EmbeddedBlob *b : items) {
		const String target = dir.path_join(b->name);
		if (FileAccess::exists(target)) {
			if (FileAccess::get_sha256(target) == String(b->sha256)) {
				continue;
			}
			if (backup_dir.is_empty()) {
				backup_dir = dir.path_join(vformat("_backup-%d", (int64_t)Time::get_singleton()->get_unix_time_from_system()));
				DirAccess::make_dir_recursive_absolute(backup_dir);
			}
			err = DirAccess::rename_absolute(target, backup_dir.path_join(b->name));
			ERR_FAIL_COND_V_MSG(err != OK, err, vformat("[H5] Cannot back up '%s' before replacing it.", target));
		}
		err = _h5_write_verified(target, b);
		ERR_FAIL_COND_V_MSG(err != OK, err, vformat("[H5] Cannot install embedded '%s' into '%s' (error %d).", b->name, dir, err));
		written++;
	}

	const String version_file = dir.path_join("version.txt");
	if (!FileAccess::exists(version_file) || FileAccess::get_file_as_string(version_file).strip_edges() != GODOT_VERSION_FULL_CONFIG) {
		Ref<FileAccess> vf = FileAccess::open(version_file, FileAccess::WRITE);
		if (vf.is_valid()) {
			vf->store_string(GODOT_VERSION_FULL_CONFIG);
		}
	}

	if (written > 0) {
		print_line(vformat("[H5] Installed embedded Web templates '%s' @ %s into '%s'%s.", get_label(), get_source_sha().left(10), dir,
				backup_dir.is_empty() ? String() : vformat(" (previous files moved to '%s')", backup_dir)));
	}
	return OK;
}

Error H5Embedded::extract_h5_template(const String &p_dest) {
	const H5EmbeddedBlob *b = _h5_find("h5_template.zip");
	if (b == nullptr) {
		return ERR_FILE_NOT_FOUND;
	}
	ERR_FAIL_NULL_V(EditorPaths::get_singleton(), ERR_UNCONFIGURED);

	const String tmp_dir = EditorPaths::get_singleton()->get_temp_dir();
	DirAccess::make_dir_recursive_absolute(tmp_dir);
	const String tmp = tmp_dir.path_join("h5_template_embedded.zip");
	Error err = _h5_write_verified(tmp, b);
	ERR_FAIL_COND_V_MSG(err != OK, err, vformat("[H5] Cannot write embedded H5 template to '%s'.", tmp));

	Ref<FileAccess> io_fa;
	zlib_filefunc_def io = zipio_create_io(&io_fa);
	unzFile pkg = unzOpen2(tmp.utf8().get_data(), &io);
	if (!pkg) {
		DirAccess::remove_absolute(tmp);
		ERR_FAIL_V_MSG(ERR_FILE_CORRUPT, "[H5] Embedded H5 template is not a valid ZIP.");
	}

	Error result = OK;
	int ret = unzGoToFirstFile(pkg);
	while (ret == UNZ_OK) {
		unz_file_info info;
		char fname[16384];
		if (unzGetCurrentFileInfo(pkg, &info, fname, 16384, nullptr, 0, nullptr, 0) != UNZ_OK) {
			result = ERR_FILE_CORRUPT;
			break;
		}
		const String rel = String::utf8(fname);
		// Only plain relative paths: never write outside p_dest.
		if (rel.is_empty() || rel.begins_with("/") || rel.contains("..") || rel.contains(":") || rel.contains("\\")) {
			ERR_PRINT(vformat("[H5] Rejected template entry '%s'.", rel));
			result = ERR_FILE_CORRUPT;
			break;
		}
		const String dst = p_dest.path_join(rel);
		if (rel.ends_with("/")) {
			DirAccess::make_dir_recursive_absolute(dst);
		} else {
			DirAccess::make_dir_recursive_absolute(dst.get_base_dir());
			Vector<uint8_t> data;
			data.resize(info.uncompressed_size);
			int rd = 0;
			if (unzOpenCurrentFile(pkg) == UNZ_OK) {
				rd = data.is_empty() ? 0 : unzReadCurrentFile(pkg, data.ptrw(), (unsigned int)data.size());
				unzCloseCurrentFile(pkg);
			} else {
				rd = -1;
			}
			if (rd != data.size()) {
				result = ERR_FILE_CORRUPT;
				break;
			}
			Ref<FileAccess> f = FileAccess::open(dst, FileAccess::WRITE);
			if (f.is_null() || (!data.is_empty() && !f->store_buffer(data.ptr(), data.size()))) {
				ERR_PRINT(vformat("[H5] Cannot write '%s'.", dst));
				result = ERR_FILE_CANT_WRITE;
				break;
			}
		}
		ret = unzGoToNextFile(pkg);
	}
	unzClose(pkg);
	DirAccess::remove_absolute(tmp);
	return result;
}
