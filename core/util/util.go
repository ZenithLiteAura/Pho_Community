package util

import (
	"mime"
	"path/filepath"
	"strings"
)

func IsVideo(name string) bool {
	ext := filepath.Ext(name)
	switch strings.ToLower(ext) {
	case ".mp4", ".avi", ".rmvb", ".rm", ".flv", ".wmv", ".mkv", ".mov", ".mpg", ".mpeg", ".3gp", ".3g2", ".asf", ".asx", ".vob", ".m2ts", ".mts", ".ts":
		return true
	}
	return false
}

func ContentTypeByExtension(ext string) string {
	var t string
	var ok bool
	t = mime.TypeByExtension(strings.ToLower(ext))
	if t != "" {
		return t
	}
	t, ok = defaultMimeMap[strings.ToLower(ext)]
	if ok {
		return t
	}
	return ""
}

var defaultMimeMap = map[string]string{
	".bmp":  "image/bmp",
	".gif":  "image/gif",
	".jpeg": "image/jpeg",
	".jpg":  "image/jpeg",
	".png":  "image/png",
	".tif":  "image/tiff",
	".tiff": "image/tiff",
	".webp": "image/webp",
	".ico":  "image/x-icon",
	".svg":  "image/svg+xml",

	".avi":  "video/x-msvideo",
	".mkv":  "video/x-matroska",
	".mov":  "video/quicktime",
	".mp4":  "video/mp4",
	".mpeg": "video/mpeg",
	".ogv":  "video/ogg",
	".webm": "video/webm",
	".3gp":  "video/3gpp",
	".3g2":  "video/3gpp2",
}
