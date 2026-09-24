package imgmanager

import (
	"bytes"
	"crypto/aes"
	"fmt"
	"io"
	"io/fs"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	pb "github.com/fregie/img_syncer/proto"
)

// mockDrive 是一个基于内存的 StorageDrive 实现，用于加密集成单元测试。
type mockDrive struct {
	mu          sync.Mutex
	files       map[string][]byte
	deleteCalls []string          // 记录所有 Delete 调用
	rangeFiles  map[string][]mockDirEntry // 自定义目录结构（用于 RangeByDate 测试）
}

type mockDirEntry struct {
	name  string
	size  int64
	isDir bool
}

func (m mockDirEntry) Name() string       { return m.name }
func (m mockDirEntry) Size() int64        { return m.size }
func (m mockDirEntry) Mode() fs.FileMode  { return 0 }
func (m mockDirEntry) ModTime() time.Time { return time.Time{} }
func (m mockDirEntry) IsDir() bool        { return m.isDir }
func (m mockDirEntry) Sys() interface{}   { return nil }

func newMockDrive() *mockDrive {
	return &mockDrive{
		files:       make(map[string][]byte),
		deleteCalls: make([]string, 0),
		rangeFiles:  make(map[string][]mockDirEntry),
	}
}

func (m *mockDrive) IsExist(path string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, ok := m.files[path]
	return ok, nil
}

func (m *mockDrive) Upload(path string, reader io.ReadCloser, size int64, lastModified time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, err := io.ReadAll(reader)
	if err != nil {
		return err
	}
	m.files[path] = data
	return nil
}

func (m *mockDrive) Download(path string) (io.ReadCloser, int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, ok := m.files[path]
	if !ok {
		return nil, 0, fmt.Errorf("file not found: %s", path)
	}
	return io.NopCloser(bytes.NewReader(data)), int64(len(data)), nil
}

func (m *mockDrive) DownloadWithOffset(path string, offset int64) (io.ReadCloser, int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, ok := m.files[path]
	if !ok {
		return nil, 0, fmt.Errorf("file not found: %s", path)
	}
	if offset >= int64(len(data)) {
		return io.NopCloser(bytes.NewReader(nil)), int64(len(data)), nil
	}
	return io.NopCloser(bytes.NewReader(data[offset:])), int64(len(data)), nil
}

func (m *mockDrive) Delete(path string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.files, path)
	m.deleteCalls = append(m.deleteCalls, path)
	return nil
}

func (m *mockDrive) Range(dir string, deal func(fs.FileInfo) bool) error {
	m.mu.Lock()

	// 优先使用 rangeFiles 自定义目录结构
	if entries, ok := m.rangeFiles[dir]; ok {
		copied := make([]mockDirEntry, len(entries))
		copy(copied, entries)
		m.mu.Unlock()
		for _, e := range copied {
			if !deal(e) {
				break
			}
		}
		return nil
	}
	defer m.mu.Unlock()

	prefix := dir
	if prefix != "" && !strings.HasSuffix(prefix, "/") {
		prefix += "/"
	}

	var infos []memFileInfo
	seen := make(map[string]bool)
	for path, data := range m.files {
		if prefix == "" || strings.HasPrefix(path, prefix) {
			name := strings.TrimPrefix(path, prefix)
			if !strings.Contains(name, "/") && !seen[name] {
				seen[name] = true
				infos = append(infos, memFileInfo{
					name:    name,
					size:    int64(len(data)),
					modTime: time.Now(),
				})
			}
		}
	}

	// 按文件名降序排列（与 RangeByDate 的遍历顺序一致）
	sort.Slice(infos, func(i, j int) bool {
		return infos[i].name > infos[j].name
	})

	for _, info := range infos {
		if !deal(&info) {
			break
		}
	}
	return nil
}

func (m *mockDrive) Close() error {
	return nil
}

// memFileInfo 实现 fs.FileInfo 接口，供 mockDrive.Range 使用。
type memFileInfo struct {
	name    string
	size    int64
	modTime time.Time
}

func (f *memFileInfo) Name() string       { return f.name }
func (f *memFileInfo) Size() int64        { return f.size }
func (f *memFileInfo) Mode() fs.FileMode  { return 0644 }
func (f *memFileInfo) ModTime() time.Time { return f.modTime }
func (f *memFileInfo) IsDir() bool        { return false }
func (f *memFileInfo) Sys() interface{}   { return nil }

// =============================================================================
// 测试用例
// =============================================================================

func TestUploadWithEncryptAppendsAesSuffix(t *testing.T) {
	mock := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.SetDrive(mock)
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_01)

	content := []byte("hello encrypted world")
	date := time.Date(2022, 11, 8, 12, 34, 36, 0, time.UTC)
	pw := "test-encrypt-password"

	err := im.Upload(bytes.NewReader(content), int64(len(content)), "pic1.jpg", date,
		WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: pw}))
	if err != nil {
		t.Fatalf("Upload failed: %v", err)
	}

	options := Options{EncyptOption: EncryptOption{Type: AES_256_GCM, Password: pw}}
	expectedPath := im.genPath("pic1.jpg", date, options)

	mock.mu.Lock()
	data, ok := mock.files[expectedPath]
	mock.mu.Unlock()

	if !ok {
		t.Fatalf("expected file at path %q, not found in mockDrive", expectedPath)
	}
	if !strings.HasSuffix(expectedPath, ".aes") {
		t.Fatalf("expected path to end with .aes, got %q", expectedPath)
	}
	// 加密后的内容应该比原始内容大（至少包含 IV）
	if int64(len(data)) <= int64(len(content)) {
		t.Fatalf("encrypted size (%d) should be larger than plaintext (%d)", len(data), len(content))
	}
	t.Logf("encrypted file at %q: %d bytes (plaintext was %d)", expectedPath, len(data), len(content))
}

func TestDownloadDecryptsAndMatchesOriginal(t *testing.T) {
	mock := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.SetDrive(mock)
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_01)

	content := []byte("hello encrypted world, this is a round-trip test")
	date := time.Date(2022, 11, 8, 12, 34, 36, 0, time.UTC)
	pw := "secret-download-pw"

	// 加密上传
	err := im.Upload(bytes.NewReader(content), int64(len(content)), "pic1.jpg", date,
		WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: pw}))
	if err != nil {
		t.Fatalf("Upload failed: %v", err)
	}

	options := Options{EncyptOption: EncryptOption{Type: AES_256_GCM, Password: pw}}
	storedPath := im.genPath("pic1.jpg", date, options)

	img, err := im.GetImg(storedPath, WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: pw}))
	if err != nil {
		t.Fatalf("GetImg failed: %v", err)
	}
	defer img.Content.Close()

	result, err := io.ReadAll(img.Content)
	if err != nil {
		t.Fatalf("read decrypted content failed: %v", err)
	}

	if !bytes.Equal(result, content) {
		t.Fatalf("decrypted content does not match original: got %d bytes, want %d bytes", len(result), len(content))
	}

	// 验证解密后的大小
	if img.Size != int64(len(content)) {
		t.Fatalf("decrypted img.Size mismatch: got %d, want %d", img.Size, len(content))
	}

	t.Logf("round-trip success: %d bytes plaintext → encrypted → decrypted → %d bytes", len(content), len(result))
}

func TestGetOffsetEncryptedBehavesByFormat(t *testing.T) {
	mock := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.SetDrive(mock)
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_01)

	gcmPw := "gcm-behavior-pw"
	gcmPlaintext := make([]byte, 2500)
	for i := range gcmPlaintext {
		gcmPlaintext[i] = byte(i % 251)
	}
	date := time.Date(2022, 11, 8, 12, 34, 36, 0, time.UTC)

	err := im.Upload(bytes.NewReader(gcmPlaintext), int64(len(gcmPlaintext)), "video.mp4", date,
		WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: gcmPw}))
	if err != nil {
		t.Fatalf("GCM Upload failed: %v", err)
	}

	gcmOpts := Options{EncyptOption: EncryptOption{Type: AES_256_GCM, Password: gcmPw}}
	gcmPath := im.genPath("video.mp4", date, gcmOpts)

	img, err := im.GetOffset(gcmPath, 1, WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: gcmPw}))
	if err != nil {
		t.Fatalf("GCM GetOffset offset=1 should succeed after GCM seek support: %v", err)
	}
	body, err := io.ReadAll(img.Content)
	img.Content.Close()
	if err != nil {
		t.Fatalf("GCM read body failed: %v", err)
	}
	want := gcmPlaintext[1:]
	if !bytes.Equal(body, want) {
		t.Fatalf("GCM GetOffset(offset=1) body mismatch: got %d bytes, want %d bytes", len(body), len(want))
	}

	img0, err := im.GetOffset(gcmPath, 0, WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: gcmPw}))
	if err != nil {
		t.Fatalf("GCM GetOffset offset=0 should succeed: %v", err)
	}
	body0, err := io.ReadAll(img0.Content)
	img0.Content.Close()
	if err != nil {
		t.Fatalf("GCM read body0 failed: %v", err)
	}
	if !bytes.Equal(body0, gcmPlaintext) {
		t.Fatalf("GCM GetOffset(offset=0) body mismatch: got %d bytes, want %d bytes", len(body0), len(gcmPlaintext))
	}
	t.Logf("GCM GetOffset: offset=1 OK (%d bytes), offset=0 OK (%d bytes)", len(body), len(body0))

	// CFB 子用例：EncryptedReaderWraper 已弃用 CFB 加密，故直接构造 legacy CFB 密文存入 mockDrive.files。
	cfbPw := "cfb-behavior-pw"
	cfbPlaintext := []byte("this is legacy CFB encrypted content for GetOffset test")
	cfbPath := "2022/11/08/123436_legacy.mp4.aes"

	key := legacyKDF(cfbPw, keyLen)
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatalf("aes.NewCipher failed: %v", err)
	}
	encReader, err := legacyNewCfbEncrypter(io.NopCloser(bytes.NewReader(cfbPlaintext)), block)
	if err != nil {
		t.Fatalf("legacyNewCfbEncrypter failed: %v", err)
	}
	cfbCipher, err := io.ReadAll(encReader)
	encReader.Close()
	if err != nil {
		t.Fatalf("read CFB cipher failed: %v", err)
	}

	mock.mu.Lock()
	mock.files[cfbPath] = cfbCipher
	mock.mu.Unlock()

	_, err = im.GetOffset(cfbPath, 1, WithEncrypt(EncryptOption{Type: AES_128_CFB, Password: cfbPw}))
	if err == nil {
		t.Fatal("CFB GetOffset offset=1 should be rejected (legacy format has no seek support)")
	}
	t.Logf("CFB GetOffset(offset=1) correctly rejected: %v", err)

	img2, err := im.GetOffset(cfbPath, 0, WithEncrypt(EncryptOption{Type: AES_128_CFB, Password: cfbPw}))
	if err != nil {
		t.Fatalf("CFB GetOffset offset=0 should succeed via GetImg fallback: %v", err)
	}
	body2, err := io.ReadAll(img2.Content)
	img2.Content.Close()
	if err != nil {
		t.Fatalf("CFB read body failed: %v", err)
	}
	if !bytes.Equal(body2, cfbPlaintext) {
		t.Fatalf("CFB GetOffset(offset=0) body mismatch: got %d bytes, want %d bytes", len(body2), len(cfbPlaintext))
	}
	t.Logf("CFB GetOffset: offset=1 rejected, offset=0 OK (%d bytes via GetImg fallback)", len(body2))
}

func TestUploadWithoutEncryptNoAesSuffix(t *testing.T) {
	mock := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.SetDrive(mock)
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_01)

	content := []byte("plain content without encryption")
	date := time.Date(2022, 11, 8, 12, 34, 36, 0, time.UTC)

	err := im.Upload(bytes.NewReader(content), int64(len(content)), "plain.jpg", date)
	if err != nil {
		t.Fatalf("Upload failed: %v", err)
	}

	// 不应出现 .aes 后缀
	mock.mu.Lock()
	hasAes := false
	for path := range mock.files {
		if strings.HasSuffix(path, ".aes") {
			hasAes = true
			break
		}
	}
	count := len(mock.files)
	mock.mu.Unlock()

	if hasAes {
		t.Fatal("expected NO .aes file when uploading without encryption")
	}
	if count != 1 {
		t.Fatalf("expected 1 file, got %d", count)
	}

	// 验证文件路径不包含 .aes
	options := Options{}
	expectedPath := im.genPath("plain.jpg", date, options)
	if strings.HasSuffix(expectedPath, ".aes") {
		t.Fatalf("unexpected .aes suffix on non-encrypted path: %q", expectedPath)
	}
	t.Logf("non-encrypted file stored at %q", expectedPath)
}

func TestRoundTripWrongPasswordFailsOrCorrupts(t *testing.T) {
	mock := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.SetDrive(mock)
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_01)

	content := []byte("sensitive data that should be encrypted")
	date := time.Date(2022, 11, 8, 12, 34, 36, 0, time.UTC)
	correctPw := "correct-password"

	err := im.Upload(bytes.NewReader(content), int64(len(content)), "secret.jpg", date,
		WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: correctPw}))
	if err != nil {
		t.Fatalf("Upload failed: %v", err)
	}

	options := Options{EncyptOption: EncryptOption{Type: AES_256_GCM, Password: correctPw}}
	storedPath := im.genPath("secret.jpg", date, options)

	img, err := im.GetImg(storedPath, WithEncrypt(EncryptOption{Type: AES_256_GCM, Password: "wrong-password!"}))
	if err != nil {
		t.Logf("GetImg with wrong password returned error (expected for GCM): %v", err)
		return
	}
	defer img.Content.Close()

	result, err := io.ReadAll(img.Content)
	if err != nil {
		t.Logf("read with wrong password failed: %v", err)
		return
	}

	if bytes.Equal(result, content) {
		t.Fatal("WRONG PASSWORD decrypted to CORRECT content — encryption is broken!")
	}
	t.Logf("wrong password produced %d bytes of data (original: %d bytes)", len(result), len(content))
}
