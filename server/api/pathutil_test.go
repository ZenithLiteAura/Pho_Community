package api

import "testing"

func TestSanitizePath_Valid(t *testing.T) {
	tests := []string{
		"foo/bar",
		"2023/01/01/photo.jpg",
		"foo",
		"a/b/c/d",
		"photo.png",
	}
	for _, tt := range tests {
		cleaned, err := sanitizePath(tt)
		if err != nil {
			t.Errorf("sanitizePath(%q) unexpected error: %v", tt, err)
		}
		if cleaned != tt {
			t.Errorf("sanitizePath(%q) = %q, want %q", tt, cleaned, tt)
		}
	}
}

func TestSanitizePath_TraversalRejected(t *testing.T) {
	tests := []string{
		"",
		"../foo",
		"/foo",
		"foo/../../bar",
		"..\\foo",
		".",
		"./foo",
		"/",
		"..",
		"foo/bar/../../..",
		"\\windows\\path",
	}
	for _, tt := range tests {
		_, err := sanitizePath(tt)
		if err == nil {
			t.Errorf("sanitizePath(%q) expected error, got nil", tt)
		}
	}
}
