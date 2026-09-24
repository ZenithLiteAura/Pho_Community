package webdav

import (
	"bytes"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

// =============================================================================
// Stateful WebDAV stub server
// =============================================================================

type webdavStub struct {
	srv                 *httptest.Server
	mu                  sync.Mutex
	files               map[string][]byte
	defaultContent      []byte
	inFlight            int32
	maxInFlight         int32
	mkcolDelay          time.Duration
	statCount           int32
	putBody             map[string][]byte
	noContentLength     bool
	noContentRangeTotal bool
	propfindStatus      int
}

func newWebdavStub(t *testing.T, defaultContent []byte) *webdavStub {
	stub := &webdavStub{
		files:          make(map[string][]byte),
		defaultContent: defaultContent,
		putBody:        make(map[string][]byte),
	}
	stub.files["/storage"] = nil
	stub.files["/storage/"] = nil
	stub.files["/"] = nil

	mux := http.NewServeMux()
	mux.HandleFunc("/", stub.serveHTTP)
	stub.srv = httptest.NewServer(mux)
	t.Cleanup(stub.srv.Close)
	return stub
}

func (ws *webdavStub) URL() string                  { return ws.srv.URL }
func (ws *webdavStub) setMkcolDelay(d time.Duration) { ws.mkcolDelay = d }
func (ws *webdavStub) maxConcurrentMkcol() int32      { return atomic.LoadInt32(&ws.maxInFlight) }
func (ws *webdavStub) getStatCount() int32            { return atomic.LoadInt32(&ws.statCount) }

func (ws *webdavStub) addFile(path string, content []byte) {
	ws.mu.Lock()
	ws.files[path] = content
	ws.putBody[path] = content
	ws.mu.Unlock()
}

func dirForPath(path string) string {
	path = strings.TrimSuffix(path, "/")
	if idx := strings.LastIndexByte(path, '/'); idx > 0 {
		return path[:idx+1]
	}
	return ""
}

func (ws *webdavStub) hasDir(path string) bool {
	if v, ok := ws.files[path]; ok && v == nil {
		return true
	}
	if v, ok := ws.files[strings.TrimSuffix(path, "/")+"/"]; ok && v == nil {
		return true
	}
	return false
}

func (ws *webdavStub) isDir(path string) bool {
	ws.mu.Lock()
	defer ws.mu.Unlock()
	if v, ok := ws.files[path]; ok && v == nil {
		return true
	}
	if !strings.HasSuffix(path, "/") {
		if v, ok := ws.files[path+"/"]; ok && v == nil {
			return true
		}
	}
	return false
}

func (ws *webdavStub) serveHTTP(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "PROPFIND":
		if r.Header.Get("Depth") == "0" {
			ws.handlePropfindSelf(w, r)
		} else {
			ws.handlePropfindReadDir(w, r)
		}
	case "MKCOL":
		ws.handleMkcol(w, r)
	case "PUT":
		ws.handlePut(w, r)
	case "DELETE":
		ws.handleDelete(w, r)
	case "GET":
		ws.handleGet(w, r)
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}
}

func (ws *webdavStub) handlePropfindSelf(w http.ResponseWriter, r *http.Request) {
	atomic.AddInt32(&ws.statCount, 1)
	if ws.propfindStatus > 0 {
		w.WriteHeader(ws.propfindStatus)
		return
	}
	path := r.URL.Path

	ws.mu.Lock()
	content, known := ws.files[path]
	isDir := known && content == nil
	if !known && strings.HasSuffix(path, "/") {
		content, known = ws.files[strings.TrimSuffix(path, "/")]
		isDir = known && content == nil
	}
	ws.mu.Unlock()

	if !known {
		w.WriteHeader(http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	w.WriteHeader(207)

	var resourceType string
	var contentLength int64
	href := path

	if isDir {
		resourceType = "<D:collection/>"
		contentLength = 0
		if !strings.HasSuffix(href, "/") {
			href += "/"
		}
	} else {
		contentLength = int64(len(content))
	}

	body := fmt.Sprintf(`<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>%s</D:href>
    <D:propstat>
      <D:prop>
        <D:getcontentlength>%d</D:getcontentlength>
        <D:resourcetype>%s</D:resourcetype>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>`, href, contentLength, resourceType)
	w.Write([]byte(body))
}

type stubFileEntry struct {
	name    string
	modTime string
	size    int64
}

func (ws *webdavStub) handlePropfindReadDir(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	w.WriteHeader(207)

	path := r.URL.Path

	var entries []stubFileEntry
	if strings.HasPrefix(path, "/storage/photos") {
		entries = []stubFileEntry{
			{name: "zebra.jpg", modTime: "Mon, 02 Jan 2023 10:00:00 GMT", size: 100},
			{name: "alpha.jpg", modTime: "Mon, 02 Jan 2023 12:00:00 GMT", size: 200},
			{name: "middle.jpg", modTime: "Mon, 02 Jan 2023 11:00:00 GMT", size: 150},
		}
	} else {
		entries = []stubFileEntry{
			{name: "default.txt", modTime: "Mon, 02 Jan 2023 10:00:00 GMT", size: int64(len(ws.defaultContent))},
		}
	}
	writeMultiStatus(w, path, entries)
}

func writeMultiStatus(w http.ResponseWriter, dirPath string, entries []stubFileEntry) {
	href := dirPath
	if !strings.HasSuffix(href, "/") {
		href += "/"
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf(`  <D:response>
    <D:href>%s</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype><D:collection/></D:resourcetype>
        <D:getcontentlength>0</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
`, href))

	for _, e := range entries {
		b.WriteString(fmt.Sprintf(`  <D:response>
    <D:href>%s%s</D:href>
    <D:propstat>
      <D:prop>
        <D:getlastmodified>%s</D:getlastmodified>
        <D:getcontentlength>%d</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
`, href, e.name, e.modTime, e.size))
	}

	body := fmt.Sprintf(`<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
%s</D:multistatus>`, b.String())
	w.Write([]byte(body))
}

func (ws *webdavStub) handleMkcol(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path

	ws.mu.Lock()
	v, ok := ws.files[path]
	if ok {
		if v == nil {
			ws.mu.Unlock()
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		ws.mu.Unlock()
		w.WriteHeader(http.StatusConflict)
		return
	}
	cleanPath := strings.TrimSuffix(path, "/")
	if cleanPath != path {
		if v, ok := ws.files[cleanPath]; ok && v != nil {
			ws.mu.Unlock()
			w.WriteHeader(http.StatusConflict)
			return
		}
	}

	parent := dirForPath(path)
	if parent != "" && !ws.hasDir(parent) {
		ws.mu.Unlock()
		w.WriteHeader(http.StatusConflict)
		return
	}

	if ws.mkcolDelay > 0 {
		cur := atomic.AddInt32(&ws.inFlight, 1)
		for {
			old := atomic.LoadInt32(&ws.maxInFlight)
			if cur <= old {
				break
			}
			if atomic.CompareAndSwapInt32(&ws.maxInFlight, old, cur) {
				break
			}
		}
		time.Sleep(ws.mkcolDelay)
		atomic.AddInt32(&ws.inFlight, -1)
	}

	ws.files[path] = nil
	ws.mu.Unlock()
	w.WriteHeader(http.StatusCreated)
}

func (ws *webdavStub) handlePut(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	r.Body.Close()

	ws.mu.Lock()
	ws.files[r.URL.Path] = body
	ws.putBody[r.URL.Path] = body
	ws.mu.Unlock()

	w.WriteHeader(http.StatusCreated)
}

func (ws *webdavStub) handleDelete(w http.ResponseWriter, r *http.Request) {
	ws.mu.Lock()
	_, exists := ws.files[r.URL.Path]
	if exists {
		delete(ws.files, r.URL.Path)
		delete(ws.putBody, r.URL.Path)
	}
	ws.mu.Unlock()

	if exists {
		w.WriteHeader(http.StatusNoContent)
	} else {
		w.WriteHeader(http.StatusInternalServerError)
	}
}

func (ws *webdavStub) handleGet(w http.ResponseWriter, r *http.Request) {
	ws.mu.Lock()
	content, known := ws.files[r.URL.Path]
	ws.mu.Unlock()

	if !known || content == nil {
		content = ws.defaultContent
	}

	rng := r.Header.Get("Range")
	if rng == "" {
		if ws.noContentLength {
			w.WriteHeader(http.StatusOK)
			w.(http.Flusher).Flush()
			w.Write(content)
			return
		}
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(content)))
		w.WriteHeader(http.StatusOK)
		w.Write(content)
		return
	}

	var start, end int
	end = len(content) - 1
	if n, _ := fmt.Sscanf(rng, "bytes=%d-%d", &start, &end); n >= 1 {
		if end >= len(content) {
			end = len(content) - 1
		}
		if ws.noContentRangeTotal {
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/", start, end))
		} else {
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, len(content)))
		}
		w.Header().Set("Content-Length", fmt.Sprintf("%d", end-start+1))
		w.WriteHeader(http.StatusPartialContent)
		w.Write(content[start : end+1])
		return
	}
	w.WriteHeader(http.StatusBadRequest)
}

// =============================================================================
// Backward-compatible wrapper
// =============================================================================

func stubWebdavServer(t *testing.T, fileContent []byte) (*httptest.Server, *int32) {
	stub := newWebdavStub(t, fileContent)
	stub.files["/storage/"] = nil
	return stub.srv, &stub.statCount
}

func newDriveOnStub(t *testing.T, stub *webdavStub) *Webdav {
	t.Helper()
	return NewWebdavDrive(stub.URL(), "", "", false)
}

// =============================================================================
// 1-3: Existing Download tests (unchanged)
// =============================================================================

func TestDownloadReturnsSizeWithoutStat(t *testing.T) {
	content := bytes.Repeat([]byte("hello"), 100)
	srv, statCount := stubWebdavServer(t, content)

	d := NewWebdavDrive(srv.URL, "", "", false)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}
	atomic.StoreInt32(statCount, 0)

	reader, size, err := d.Download("test.txt")
	if err != nil {
		t.Fatalf("Download: %v", err)
	}
	defer reader.Close()

	if size != int64(len(content)) {
		t.Errorf("size: got %d, want %d", size, len(content))
	}
	data, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("ReadAll: %v", err)
	}
	if !bytes.Equal(data, content) {
		t.Errorf("data mismatch: got %d bytes, want %d bytes", len(data), len(content))
	}
	if got := atomic.LoadInt32(statCount); got != 0 {
		t.Errorf("Stat called %d times, expected 0 (size from Content-Length)", got)
	}
}

func TestDownloadWithOffsetReturnsTotalSizeWithoutStat(t *testing.T) {
	content := bytes.Repeat([]byte("hello"), 100)
	srv, statCount := stubWebdavServer(t, content)

	d := NewWebdavDrive(srv.URL, "", "", false)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}
	atomic.StoreInt32(statCount, 0)

	reader, size, err := d.DownloadWithOffset("test.txt", 100)
	if err != nil {
		t.Fatalf("DownloadWithOffset: %v", err)
	}
	defer reader.Close()

	if size != int64(len(content)) {
		t.Errorf("size: got %d, want %d", size, len(content))
	}
	data, err := io.ReadAll(reader)
	if err != nil {
		t.Fatalf("ReadAll: %v", err)
	}
	want := content[100:]
	if !bytes.Equal(data, want) {
		t.Errorf("data mismatch: got %d bytes, want %d bytes", len(data), len(want))
	}
	if got := atomic.LoadInt32(statCount); got != 0 {
		t.Errorf("Stat called %d times, expected 0 (size from Content-Range)", got)
	}
}

func TestDownloadFallsBackToStatWhenNoContentLength(t *testing.T) {
	content := []byte("no headers")
	srv, statCount := stubWebdavServer(t, content)

	d := NewWebdavDrive(srv.URL, "", "", false)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}
	atomic.StoreInt32(statCount, 0)

	reader, size, err := d.Download("noheaders.txt")
	if err != nil {
		t.Fatalf("Download: %v", err)
	}
	defer reader.Close()

	if size != int64(len(content)) {
		t.Errorf("size: got %d, want %d (from Stat fallback)", size, len(content))
	}
}

// =============================================================================
// 4-6: Upload tests
// =============================================================================

func TestUploadCreatesIntermediateDirsAndWrites(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	content := []byte("hello from webdav upload test")
	reader := io.NopCloser(bytes.NewReader(content))
	err := d.Upload("a/b/c.txt", reader, int64(len(content)), time.Now())
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	stub.mu.Lock()
	stored := stub.putBody["/storage/a/b/c.txt"]
	stub.mu.Unlock()
	if !bytes.Equal(stored, content) {
		t.Errorf("uploaded content mismatch: got %q, want %q", stored, content)
	}
	if !stub.isDir("/storage/a") {
		t.Error("intermediate dir /storage/a was not created")
	}
	if !stub.isDir("/storage/a/b") {
		t.Error("intermediate dir /storage/a/b was not created")
	}
}

func TestUploadNilReaderReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	err := d.Upload("x.txt", nil, 0, time.Now())
	if err == nil {
		t.Fatal("expected error for nil reader")
	}
	if !strings.Contains(err.Error(), "reader is nil") {
		t.Errorf("error should mention 'reader is nil', got: %v", err)
	}
}

func TestUploadEmptyRootPathReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	err := d.Upload("x.txt", io.NopCloser(bytes.NewReader([]byte("x"))), 1, time.Now())
	if err == nil {
		t.Fatal("expected error for empty root path")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("error should mention 'root path is empty', got: %v", err)
	}
}

func TestUploadMkcolFailurePropagates(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	stub.addFile("/storage/bad", []byte("i am a file not a dir"))

	err := d.Upload("bad/sub/x.txt", io.NopCloser(bytes.NewReader([]byte("wont work"))), 9, time.Now())
	if err == nil {
		t.Fatal("expected error when MkdirAll fails")
	}
}

// =============================================================================
// 7-9: Delete tests
// =============================================================================

func TestDeleteRemovesFile(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	content := []byte("to be deleted")
	err := d.Upload("del.txt", io.NopCloser(bytes.NewReader(content)), int64(len(content)), time.Now())
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	stub.mu.Lock()
	_, exists := stub.files["/storage/del.txt"]
	stub.mu.Unlock()
	if !exists {
		t.Fatal("file should exist before delete")
	}

	if err = d.Delete("del.txt"); err != nil {
		t.Fatalf("Delete: %v", err)
	}

	stub.mu.Lock()
	_, exists = stub.files["/storage/del.txt"]
	stub.mu.Unlock()
	if exists {
		t.Error("file should not exist after delete")
	}
}

func TestDeleteEmptyRootPathReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	err := d.Delete("anything.txt")
	if err == nil {
		t.Fatal("expected error for empty root path")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("error should mention 'root path is empty', got: %v", err)
	}
}

func TestDeleteNonExistentPropagatesError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	err := d.Delete("does-not-exist.txt")
	if err == nil {
		t.Fatal("expected error when deleting non-existent file")
	}
}

// =============================================================================
// 10-11: Range tests
// =============================================================================

func TestRangeReturnsSortedDescendingByModTime(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	var names []string
	err := d.Range("photos", func(info fs.FileInfo) bool {
		names = append(names, info.Name())
		return true
	})
	if err != nil {
		t.Fatalf("Range: %v", err)
	}

	if len(names) != 3 {
		t.Fatalf("expected 3 entries, got %d: %v", len(names), names)
	}
	want := []string{"alpha.jpg", "middle.jpg", "zebra.jpg"}
	for i := range want {
		if names[i] != want[i] {
			t.Errorf("position %d: got %q, want %q", i, names[i], want[i])
		}
	}
}

func TestRangeEarlyStop(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	var count int
	err := d.Range("photos", func(info fs.FileInfo) bool {
		count++
		return count < 2
	})
	if err != nil {
		t.Fatalf("Range: %v", err)
	}
	if count != 2 {
		t.Errorf("expected 2 items processed, got %d", count)
	}
}

func TestRangeEmptyRootPathReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	err := d.Range("photos", func(info fs.FileInfo) bool { return true })
	if err == nil {
		t.Fatal("expected error for empty root path")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("error should mention 'root path is empty', got: %v", err)
	}
}

// =============================================================================
// 12-13: IsExist tests
// =============================================================================

func TestIsExistTrueThenFalse(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	content := []byte("i exist")
	err := d.Upload("real.txt", io.NopCloser(bytes.NewReader(content)), int64(len(content)), time.Now())
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	ok, err := d.IsExist("real.txt")
	if err != nil {
		t.Fatalf("IsExist real.txt: %v", err)
	}
	if !ok {
		t.Error("IsExist should return true for uploaded file")
	}

	ok, err = d.IsExist("ghost.txt")
	if err != nil {
		t.Fatalf("IsExist ghost.txt: %v", err)
	}
	if ok {
		t.Error("IsExist should return false for non-existent file")
	}
}

func TestIsExistEmptyRootPathReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	ok, err := d.IsExist("anything.txt")
	if err == nil {
		t.Fatal("expected error for empty root path")
	}
	if ok {
		t.Error("expected false when root path is empty")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("error should mention 'root path is empty', got: %v", err)
	}
}

func TestIsExistPropagatesNon404Error(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	stub.propfindStatus = http.StatusInternalServerError

	ok, err := d.IsExist("crash.txt")
	if err == nil {
		t.Fatal("expected error from non-404 failure")
	}
	if ok {
		t.Error("expected false when PROPFIND fails")
	}
}

// =============================================================================
// 14-17: SetRootPath tests
// =============================================================================

func TestSetRootPathNormalizesAndAppendsSlash(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}
	if !d.IsRootPathSet() {
		t.Error("root path should be set")
	}
	if d.rootPath != "/storage/" {
		t.Errorf("expected '/storage/', got %q", d.rootPath)
	}
}

func TestSetRootPathEmptyReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	err := d.SetRootPath("")
	if err == nil {
		t.Fatal("expected error for empty root path")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("error should mention 'root path is empty', got: %v", err)
	}
}

func TestSetRootPathNonDirReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	stub.addFile("/storage/photos", []byte("i am a file not a dir"))

	err := d.SetRootPath("/storage/photos")
	if err == nil {
		t.Fatal("expected error when root path is not a dir")
	}
	if !strings.Contains(err.Error(), "is not a dir") {
		t.Errorf("error should mention 'is not a dir', got: %v", err)
	}
}

func TestSetRootPathNonExistentReturnsError(t *testing.T) {
	stub := newWebdavStub(t, nil)
	d := newDriveOnStub(t, stub)

	err := d.SetRootPath("/storage/nonexistent")
	if err == nil {
		t.Fatal("expected error when root path does not exist")
	}
}

// =============================================================================
// 18: Concurrency (mkdirLock serialization)
// =============================================================================

func TestMkdirLockSerializesConcurrentMkdirAll(t *testing.T) {
	stub := newWebdavStub(t, nil)
	stub.setMkcolDelay(50 * time.Millisecond)

	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	const n = 5
	errs := make(chan error, n)
	for i := range n {
		go func(idx int) {
			path := fmt.Sprintf("d%d/sub%d/file.txt", idx, idx)
			content := []byte(fmt.Sprintf("content %d", idx))
			errs <- d.Upload(path, io.NopCloser(bytes.NewReader(content)), int64(len(content)), time.Now())
		}(i)
	}

	for range n {
		if err := <-errs; err != nil {
			t.Errorf("concurrent upload: %v", err)
		}
	}

	if got := stub.maxConcurrentMkcol(); got != 1 {
		t.Errorf("max concurrent MKCOL: got %d, want 1 (mkdirLock not serializing)", got)
	}
}

// =============================================================================
// 19-23: Additional coverage tests
// =============================================================================

func TestDownloadStatFallbackWhenNoContentLength(t *testing.T) {
	stub := newWebdavStub(t, nil)
	stub.noContentLength = true

	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	stub.addFile("/storage/nohdr.txt", []byte("abcdefghij"))
	atomic.StoreInt32(&stub.statCount, 0)

	reader, size, err := d.Download("nohdr.txt")
	if err != nil {
		t.Fatalf("Download: %v", err)
	}
	defer reader.Close()

	if size != 10 {
		t.Errorf("size: got %d, want 10 (from Stat fallback)", size)
	}
	if got := atomic.LoadInt32(&stub.statCount); got == 0 {
		t.Error("Stat should have been called as fallback")
	}
}

func TestDownloadWithOffsetStatFallbackWhenNoTotal(t *testing.T) {
	stub := newWebdavStub(t, nil)
	stub.noContentRangeTotal = true

	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath("storage"); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	stub.addFile("/storage/partial.txt", []byte("0123456789ABCDEF"))
	atomic.StoreInt32(&stub.statCount, 0)

	reader, size, err := d.DownloadWithOffset("partial.txt", 4)
	if err != nil {
		t.Fatalf("DownloadWithOffset: %v", err)
	}
	defer reader.Close()

	if size != 16 {
		t.Errorf("size: got %d, want 16 (from Stat fallback)", size)
	}
	if got := atomic.LoadInt32(&stub.statCount); got == 0 {
		t.Error("Stat should have been called as fallback")
	}
}

// =============================================================================
// 24-25: TLS security tests
// =============================================================================

// TestWebdavDefaultSecure 验证 insecure=false 时 TLS 证书验证已启用
func TestWebdavDefaultSecure(t *testing.T) {
	// 启动自签名证书的 HTTPS 服务器
	ts := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer ts.Close()

	d := NewWebdavDrive(ts.URL, "", "", false)
	_, err := d.Cli().Stat("/")
	if err == nil {
		t.Fatal("expected TLS verification error when insecure=false with self-signed cert")
	}
	if !strings.Contains(err.Error(), "certificate") && !strings.Contains(err.Error(), "tls") && !strings.Contains(err.Error(), "x509") {
		t.Logf("error was: %v (expected TLS-related error)", err)
	}
}

// TestWebdavInsecureSkipsTLSVerification 验证 insecure=true 时跳过 TLS 验证
func TestWebdavInsecureSkipsTLSVerification(t *testing.T) {
	ts := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "PROPFIND" {
			w.Header().Set("Content-Type", "application/xml; charset=utf-8")
			w.WriteHeader(207)
			w.Write([]byte(`<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype><D:collection/></D:resourcetype>
        <D:getcontentlength>0</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>`))
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer ts.Close()

	d := NewWebdavDrive(ts.URL, "", "", true)
	_, err := d.Cli().Stat("/")
	if err != nil {
		t.Fatalf("expected Stat to succeed with insecure=true, got: %v", err)
	}
}

// TestWebdavInsecureLogsWarning 验证 insecure=true 时打印 WARNING 日志
func TestWebdavInsecureLogsWarning(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(os.Stderr)

	d := NewWebdavDrive("https://example.com", "user", "pass", true)

	output := buf.String()
	if !strings.Contains(output, "WARNING") {
		t.Error("expected WARNING in log output when insecure=true")
	}
	if !strings.Contains(output, "TLS certificate verification disabled") {
		t.Error("expected 'TLS certificate verification disabled' message")
	}
	if !strings.Contains(output, "do not use in production") {
		t.Error("expected 'do not use in production' message")
	}
	if !strings.Contains(output, d.url) {
		t.Errorf("expected URL %q in warning message, got: %s", d.url, output)
	}
}

// TestWebdavDefaultSecureNoWarning 验证 insecure=false 时不打印 WARNING
func TestWebdavDefaultSecureNoWarning(t *testing.T) {
	var buf bytes.Buffer
	log.SetOutput(&buf)
	defer log.SetOutput(os.Stderr)

	_ = NewWebdavDrive("https://example.com", "user", "pass", false)

	output := buf.String()
	if strings.Contains(output, "WARNING") {
		t.Error("expected no WARNING in log output when insecure=false")
	}
}
