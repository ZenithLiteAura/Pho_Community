package nfs

import (
	"io/fs"
	"strings"
	"testing"
	"time"

	"github.com/vmware/go-nfs-client/nfs"
)

func TestNormalizeRootPath(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"storage", "/storage/"},
		{"storage/", "/storage/"},
		{"/storage", "/storage/"},
		{"/storage/", "/storage/"},
	}
	for _, tt := range tests {
		got := normalizeRootPath(tt.input)
		if got != tt.want {
			t.Errorf("normalizeRootPath(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}

func TestNormalizeRootPathDeep(t *testing.T) {
	got := normalizeRootPath("a/b/c")
	want := "/a/b/c/"
	if got != want {
		t.Errorf("normalizeRootPath(%q) = %q, want %q", "a/b/c", got, want)
	}
}

func TestNewNfsDriveBadURLFormat(t *testing.T) {
	_, err := NewNfsDrive("no-colon-host")
	if err == nil || !strings.Contains(err.Error(), "url format error") {
		t.Errorf("NewNfsDrive(%q) error = %v, want 'url format error'", "no-colon-host", err)
	}
	_, err = NewNfsDrive("a:b:c")
	if err == nil || !strings.Contains(err.Error(), "url format error") {
		t.Errorf("NewNfsDrive(%q) error = %v, want 'url format error'", "a:b:c", err)
	}
}

func TestNewNfsDriveBadHost(t *testing.T) {
	_, err := NewNfsDrive("nonexistent:share")
	if err == nil {
		t.Errorf("NewNfsDrive(%q) should fail on DialMount to nonexistent host", "nonexistent:share")
	}
}

func TestSetRootPathEmptyReturnsError(t *testing.T) {
	d := &Nfs{cli: nil, mount: nil}
	err := d.SetRootPath("")
	if err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("SetRootPath empty: error = %v, want 'root path is empty'", err)
	}
}

func TestSetRootPathWithNilCliPanicsOnReadDirPlus(t *testing.T) {
	d := &Nfs{cli: nil}
	panicked := false
	func() {
		defer func() {
			if r := recover(); r != nil {
				panicked = true
			}
		}()
		d.SetRootPath("storage")
	}()
	if !panicked {
		t.Errorf("SetRootPath with nil cli should panic on ReadDirPlus call, but no panic occurred — ReadDirPlus may have been removed")
	}
}

func TestIsRootPathSet(t *testing.T) {
	d := &Nfs{}
	if d.IsRootPathSet() {
		t.Errorf("fresh Nfs: IsRootPathSet should be false")
	}
	d.rootPath = "/x/"
	if !d.IsRootPathSet() {
		t.Errorf("after setting rootPath: IsRootPathSet should be true")
	}
}

func TestCheckConnFreshWithinTTL(t *testing.T) {
	d := &Nfs{
		host:              "127.0.0.1",
		target:            "share",
		lastConnTimestamp: time.Now().Unix(),
	}
	err := d.checkConn()
	if err != nil {
		t.Errorf("checkConn with fresh timestamp: expected nil, got %v", err)
	}
}

func TestCheckConnExpiredWithNilCli(t *testing.T) {
	d := &Nfs{
		host:              "",     // empty causes DialMount to fail
		target:            "share",
		lastConnTimestamp: 0,      // expired
	}
	err := d.checkConn()
	if err == nil {
		t.Errorf("checkConn with expired timestamp + nil cli + empty host: expected error from DialMount, got nil")
	}
}

func TestCloseNilSafe(t *testing.T) {
	d := &Nfs{}
	if err := d.Close(); err != nil {
		t.Errorf("Close on zero Nfs: expected nil, got %v", err)
	}
}

func TestCli(t *testing.T) {
	d := &Nfs{}
	if d.Cli() != nil {
		t.Errorf("Cli on zero Nfs: expected nil")
	}
}

func TestLastConnTimeMethods(t *testing.T) {
	d := &Nfs{}

	epochZero := d.lastConnTime()
	if !epochZero.Equal(time.Unix(0, 0)) {
		t.Errorf("lastConnTime on zero Nfs: expected epoch zero, got %v", epochZero)
	}

	d.updateLastConnTime()
	recent := d.lastConnTime()
	if recent.Before(time.Now().Add(-5 * time.Second)) {
		t.Errorf("lastConnTime after update: expected recent, got %v", recent)
	}

	d.cleanLastConnTime()
	afterClean := d.lastConnTime()
	if !afterClean.Equal(time.Unix(0, 0)) {
		t.Errorf("lastConnTime after clean: expected epoch zero, got %v", afterClean)
	}
}

func TestDescSortInterface(t *testing.T) {
	now := time.Now()
	mkEntry := func(name string, seconds uint32) *nfs.EntryPlus {
		return &nfs.EntryPlus{
			FileName: name,
			Attr: nfs.PostOpAttr{
				IsSet: true,
				Attr: nfs.Fattr{
					Mtime: nfs.NFS3Time{Seconds: seconds},
				},
			},
		}
	}
	a := mkEntry("a", uint32(now.Add(-1*time.Hour).Unix()))
	b := mkEntry("b", uint32(now.Unix()))
	c := mkEntry("c", uint32(now.Add(-2*time.Hour).Unix()))
	d := desc([]*nfs.EntryPlus{a, b, c})
	if d.Len() != 3 {
		t.Errorf("desc.Len: expected 3, got %d", d.Len())
	}
	if !d.Less(1, 0) {
		t.Errorf("desc.Less(1,0): entry at 1 is newer than 0, expected true")
	}
	d.Swap(0, 2)
	if d[0].Name() != "c" || d[2].Name() != "a" {
		t.Errorf("desc.Swap(0,2): expected [c,b,a], got [%s,%s,%s]",
			d[0].Name(), d[1].Name(), d[2].Name())
	}
}

func TestIsExistEmptyRootPath(t *testing.T) {
	d := &Nfs{lastConnTimestamp: time.Now().Unix()}
	ok, err := d.IsExist("test.jpg")
	if ok || err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("IsExist with empty rootPath: expected (false, 'root path is empty'), got (%v, %v)", ok, err)
	}
}

func TestDownloadEmptyRootPath(t *testing.T) {
	d := &Nfs{lastConnTimestamp: time.Now().Unix()}
	rc, size, err := d.Download("test.jpg")
	if rc != nil || size != 0 || err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("Download with empty rootPath: expected (nil, 0, 'root path is empty'), got (%v, %v, %v)", rc, size, err)
	}
}

func TestDownloadWithOffsetEmptyRootPath(t *testing.T) {
	d := &Nfs{lastConnTimestamp: time.Now().Unix()}
	rc, size, err := d.DownloadWithOffset("test.jpg", 0)
	if rc != nil || size != 0 || err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("DownloadWithOffset with empty rootPath: expected (nil, 0, 'root path is empty'), got (%v, %v, %v)", rc, size, err)
	}
}

func TestDeleteEmptyRootPath(t *testing.T) {
	d := &Nfs{lastConnTimestamp: time.Now().Unix()}
	err := d.Delete("test.jpg")
	if err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("Delete with empty rootPath: expected 'root path is empty', got %v", err)
	}
}

func TestRangeEmptyRootPath(t *testing.T) {
	d := &Nfs{lastConnTimestamp: time.Now().Unix()}
	err := d.Range("2023", func(fs.FileInfo) bool { return true })
	if err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("Range with empty rootPath: expected 'root path is empty', got %v", err)
	}
}

func TestUploadNilReader(t *testing.T) {
	d := &Nfs{lastConnTimestamp: time.Now().Unix()}
	err := d.Upload("test.jpg", nil, 100, time.Now())
	if err == nil || !strings.Contains(err.Error(), "reader is nil") {
		t.Errorf("Upload with nil reader: expected 'reader is nil', got %v", err)
	}
}

func TestMkdirAllEmptyRootPath(t *testing.T) {
	d := &Nfs{}
	err := d.MkdirAll("/some/dir", 0755)
	if err == nil || !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("MkdirAll with empty rootPath: expected 'root path is empty', got %v", err)
	}
}
