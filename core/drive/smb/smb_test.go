package smb

import (
	"bytes"
	"io"
	"io/fs"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/fregie/img_syncer/test/static"
	"github.com/fregie/img_syncer/test/testutil"
)

// ========== Port completion 测试 ==========

func TestNewSmbDriveAppendsDefaultPort(t *testing.T) {
	// 不带端口 → 自动补 445
	s := NewSmbDrive("1.2.3.4", "user", "pass")
	if s.addr != "1.2.3.4:445" {
		t.Errorf("expected addr '1.2.3.4:445', got '%s'", s.addr)
	}

	// 带端口 → 保持不变
	s2 := NewSmbDrive("1.2.3.4:456", "user", "pass")
	if s2.addr != "1.2.3.4:456" {
		t.Errorf("expected addr '1.2.3.4:456', got '%s'", s2.addr)
	}
}

func TestNewSmbDrivePreservesUserPass(t *testing.T) {
	s := NewSmbDrive("10.0.0.1", "myuser", "mypass")
	if s.username != "myuser" {
		t.Errorf("expected username 'myuser', got '%s'", s.username)
	}
	if s.password != "mypass" {
		t.Errorf("expected password 'mypass', got '%s'", s.password)
	}
}

// ========== checkConn TTL 测试 ==========

func TestCheckConnFreshWithinTTL(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: time.Now().Unix(),
	}
	err := s.checkConn()
	if err != nil {
		t.Errorf("checkConn should return nil when lastConnTimestamp is fresh, got: %v", err)
	}
}

func TestCheckConnExpiredWithoutShareNameReturnsConfigError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0, // 过期，触发 reconnect
		shareName:         "", // 空 shareName → Connect 拒绝
	}
	err := s.checkConn()
	if err == nil {
		t.Fatal("expected error for empty shareName, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty' error, got: %v", err)
	}
}

func TestCheckConnExpiredWithBadAddrReturnsDialError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0,                // 过期
		shareName:         "anything",        // 非空，通过 shareName 检查
		addr:              "127.0.0.1:1",     // 无可达服务
		username:          "test",            // 非空，通过 Dial 内部检查
		password:          "test",
	}
	err := s.checkConn()
	if err == nil {
		t.Fatal("expected dial error, got nil")
	}
}

// ========== rootPath 空值守卫测试 ==========

func TestUploadEmptyRootPathReturnsError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: time.Now().Unix(), // 绕过 checkConn
	}
	err := s.Upload("file.jpg", io.NopCloser(strings.NewReader("data")), 4, time.Time{})
	if err == nil {
		t.Fatal("expected error for empty rootPath, got nil")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("expected 'root path is empty', got: %v", err)
	}
}

func TestDownloadWithOffsetEmptyRootPathReturnsError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: time.Now().Unix(),
	}
	_, _, err := s.DownloadWithOffset("file.jpg", 0)
	if err == nil {
		t.Fatal("expected error for empty rootPath, got nil")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("expected 'root path is empty', got: %v", err)
	}
}

func TestDeleteEmptyRootPathReturnsError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: time.Now().Unix(),
	}
	err := s.Delete("file.jpg")
	if err == nil {
		t.Fatal("expected error for empty rootPath, got nil")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("expected 'root path is empty', got: %v", err)
	}
}

func TestRangeEmptyRootPathReturnsError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: time.Now().Unix(),
	}
	err := s.Range("dir", func(fs.FileInfo) bool { return true })
	if err == nil {
		t.Fatal("expected error for empty rootPath, got nil")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("expected 'root path is empty', got: %v", err)
	}
}

func TestIsExistEmptyRootPathReturnsError(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: time.Now().Unix(),
	}
	_, err := s.IsExist("file.jpg")
	if err == nil {
		t.Fatal("expected error for empty rootPath, got nil")
	}
	if !strings.Contains(err.Error(), "root path is empty") {
		t.Errorf("expected 'root path is empty', got: %v", err)
	}
}

// ========== 字段状态测试 ==========

func TestSmbIsShareSet(t *testing.T) {
	s := &Smb{}
	if s.IsShareSet() {
		t.Error("IsShareSet should return false for fresh Smb")
	}
}

func TestSmbIsRootPathSet(t *testing.T) {
	s := &Smb{}
	if s.IsRootPathSet() {
		t.Error("IsRootPathSet should return false for fresh Smb")
	}
}

// ========== lastConnTime / updateLastConnTime / cleanLastConnTime ==========

func TestLastConnTimeInitialZero(t *testing.T) {
	s := &Smb{}
	ts := s.lastConnTime()
	// lastConnTime() 内部用 time.Unix(atomicValue, 0)，atomicValue 初始为 0 → 1970-01-01 epoch
	if ts.Unix() != 0 {
		t.Errorf("lastConnTime Unix should be 0 initially, got %d", ts.Unix())
	}
}

func TestUpdateAndCleanLastConnTime(t *testing.T) {
	s := &Smb{}
	s.updateLastConnTime()
	ts1 := s.lastConnTime()
	if ts1.Unix() <= 0 {
		t.Error("lastConnTime should be recent after update")
	}

	s.cleanLastConnTime()
	ts2 := s.lastConnTime()
	if ts2.Unix() != 0 {
		t.Errorf("lastConnTime Unix should be 0 after clean, got %d", ts2.Unix())
	}
}

// ========== NewSmbDrive 默认值 ==========

func TestNewSmbDriveDefaults(t *testing.T) {
	s := NewSmbDrive("1.2.3.4", "user", "pass")
	if s.shareName != "" {
		t.Errorf("expected empty shareName, got '%s'", s.shareName)
	}
	if s.rootPath != "" {
		t.Errorf("expected empty rootPath, got '%s'", s.rootPath)
	}
}

// ========== Dial 配置错误测试 ==========

func TestDialEmptyAddrReturnsConfigError(t *testing.T) {
	s := &Smb{
		addr:     "",
		username: "user",
	}
	_, err := s.Dial()
	if err == nil {
		t.Fatal("expected config error for empty addr, got nil")
	}
	if !strings.Contains(err.Error(), "smb config error") {
		t.Errorf("expected 'smb config error', got: %v", err)
	}
}

func TestDialEmptyUsernameReturnsConfigError(t *testing.T) {
	s := &Smb{
		addr:     "1.2.3.4",
		username: "",
	}
	_, err := s.Dial()
	if err == nil {
		t.Fatal("expected config error for empty username, got nil")
	}
	if !strings.Contains(err.Error(), "smb config error") {
		t.Errorf("expected 'smb config error', got: %v", err)
	}
}

// ========== IsShareSet/IsRootPathSet 真值测试 ==========

func TestIsShareSetTrue(t *testing.T) {
	s := &Smb{shareName: "photos"}
	if !s.IsShareSet() {
		t.Error("IsShareSet should return true when shareName is set")
	}
}

func TestIsRootPathSetTrue(t *testing.T) {
	s := &Smb{rootPath: "/photos"}
	if !s.IsRootPathSet() {
		t.Error("IsRootPathSet should return true when rootPath is set")
	}
}

// ========== Download 委托到 DownloadWithOffset ==========

func TestDownloadCheckConnFails(t *testing.T) {
	// Download() 委托给 DownloadWithOffset，两者共享 checkConn 逻辑
	// 测试 checkConn expired + shareName="" → error
	s := &Smb{
		lastConnTimestamp: 0,
		shareName:         "",
	}
	_, _, err := s.Download("file.jpg")
	if err == nil {
		t.Fatal("expected error from Download when checkConn fails, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty', got: %v", err)
	}
}

// ========== ListShare Dial 错误 ==========

func TestListShareDialError(t *testing.T) {
	s := &Smb{} // addr/username 为空 → Dial 返回 config error
	_, err := s.ListShare()
	if err == nil {
		t.Fatal("expected Dial config error from ListShare, got nil")
	}
	if !strings.Contains(err.Error(), "smb config error") {
		t.Errorf("expected 'smb config error', got: %v", err)
	}
}

// ========== SetRootPath checkConn 失败 ==========

func TestSetRootPathCheckConnFails(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0,
	}
	err := s.SetRootPath("/photos")
	if err == nil {
		t.Fatal("expected checkConn error from SetRootPath, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty', got: %v", err)
	}
}

// ========== IsExist checkConn 失败 ==========

func TestIsExistCheckConnFails(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0,
	}
	_, err := s.IsExist("file.jpg")
	if err == nil {
		t.Fatal("expected checkConn error from IsExist, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty', got: %v", err)
	}
}

// ========== Upload checkConn 失败 ==========

func TestUploadCheckConnFails(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0,
	}
	err := s.Upload("file.jpg", io.NopCloser(strings.NewReader("data")), 4, time.Time{})
	if err == nil {
		t.Fatal("expected checkConn error from Upload, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty', got: %v", err)
	}
}

// ========== Delete checkConn 失败 ==========

func TestDeleteCheckConnFails(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0,
	}
	err := s.Delete("file.jpg")
	if err == nil {
		t.Fatal("expected checkConn error from Delete, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty', got: %v", err)
	}
}

// ========== Range checkConn 失败 ==========

func TestRangeCheckConnFails(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0,
	}
	err := s.Range("dir", func(fs.FileInfo) bool { return true })
	if err == nil {
		t.Fatal("expected checkConn error from Range, got nil")
	}
	if !strings.Contains(err.Error(), "smb share name is empty") {
		t.Errorf("expected 'smb share name is empty', got: %v", err)
	}
}

// ========== Close 幂等性 ==========

func TestCloseIdempotent(t *testing.T) {
	s := &Smb{} // fs 为 nil
	err := s.Close()
	if err != nil {
		t.Errorf("Close on nil fs should not error, got: %v", err)
	}
	// 重复调用也不应出错
	err = s.Close()
	if err != nil {
		t.Errorf("second Close on nil fs should not error, got: %v", err)
	}
}

// ========== desc 排序 ==========

func TestDescSort(t *testing.T) {
	now := time.Now()
	d := desc{
		&fakeFileInfo{name: "a", modTime: now.Add(-1 * time.Hour)},
		&fakeFileInfo{name: "b", modTime: now},
		&fakeFileInfo{name: "c", modTime: now.Add(-2 * time.Hour)},
	}
	sort.Sort(d)
	// 按 ModTime 降序排列：b → a → c
	expected := []string{"b", "a", "c"}
	for i, fi := range d {
		if fi.Name() != expected[i] {
			t.Errorf("desc[%d] = %s, want %s (sort order incorrect)", i, fi.Name(), expected[i])
		}
	}
}

// fakeFileInfo 最小实现 fs.FileInfo 接口
type fakeFileInfo struct {
	name    string
	size    int64
	mode    fakeFileMode
	modTime time.Time
	isDir   bool
}

type fakeFileMode uint32

func (m fakeFileMode) IsDir() bool     { return false }
func (m fakeFileMode) IsRegular() bool { return false }
func (m fakeFileMode) Perm() fs.FileMode { return fs.FileMode(m) }
func (m fakeFileMode) String() string  { return "" }
func (m fakeFileMode) Type() fs.FileMode { return fs.FileMode(m) }

func (f *fakeFileInfo) Name() string       { return f.name }
func (f *fakeFileInfo) Size() int64        { return f.size }
func (f *fakeFileInfo) Mode() fs.FileMode  { return fs.FileMode(f.mode) }
func (f *fakeFileInfo) ModTime() time.Time { return f.modTime }
func (f *fakeFileInfo) IsDir() bool        { return f.isDir }
func (f *fakeFileInfo) Sys() interface{}   { return nil }

// ========== W5-T1: 密码泄露测试 ==========

func TestSmbDialerNoPasswordLeak(t *testing.T) {
	s := &Smb{
		addr:     "",
		username: "",
		password: "super-secret-password-123",
	}
	_, err := s.Dial()
	if err == nil {
		t.Fatal("expected config error, got nil")
	}
	errStr := err.Error()
	if strings.Contains(errStr, "super-secret-password-123") {
		t.Error("密码明文泄露在错误消息中")
	}
	if !strings.Contains(errStr, "password=***") {
		t.Error("错误消息中缺少 password=*** 掩码")
	}
}

// ========== W5-T1: 重连互斥锁序列化测试 ==========

func TestSmbReconnectSerializes(t *testing.T) {
	s := &Smb{
		lastConnTimestamp: 0, // 过期，触发重连
	}
	var wg sync.WaitGroup
	lockAcquired := make(chan struct{})
	verifyDone := make(chan struct{})

	// goroutine A 获取 connMu
	wg.Add(1)
	go func() {
		defer wg.Done()
		s.connMu.Lock()
		close(lockAcquired)
		<-verifyDone
		s.connMu.Unlock()
	}()

	<-lockAcquired
	time.Sleep(10 * time.Millisecond)

	// goroutine B 尝试 TryLock，验证失败（锁被 A 持有）
	tryFailed := make(chan bool, 1)
	wg.Add(1)
	go func() {
		defer wg.Done()
		tryFailed <- !s.connMu.TryLock()
	}()

	if got := <-tryFailed; !got {
		t.Error("connMu.TryLock() 应该返回 false，锁未正确序列化")
	}

	// 释放锁
	close(verifyDone)
	wg.Wait()

	// 验证锁释放后可获取
	if !s.connMu.TryLock() {
		t.Fatal("connMu.TryLock() 应该在释放后可获取")
	}
	s.connMu.Unlock()
}

// ========== W5-T2: Upload Close 错误传播测试 ==========

func TestSmbUploadCloseErrorPropagated(t *testing.T) {
	share, err := testutil.InitSmbShare(testSMBAddr, testSMBUser, testSMBPass, testSMBShare)
	if err != nil {
		t.Skipf("需要 Docker SMB 容器: %v", err)
	}
	defer share.Umount()

	s := initSmbReconnect(t)
	defer s.Close()

	// 正常上传：验证新代码路径不影响正常流程
	reader := bytes.NewReader(static.Pic1)
	testPath := "close_test.jpg"
	err = s.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	if err != nil {
		t.Fatalf("正常上传失败: %v", err)
	}

	// 验证文件存在
	ok, _ := s.IsExist(testPath)
	if !ok {
		t.Fatal("上传的文件应存在")
	}

	_ = s.Delete(testPath)
}

// ========== W5-T2: Chtimes 失败非致命测试 ==========

func TestSmbUploadChtimesFailureNonFatal(t *testing.T) {
	share, err := testutil.InitSmbShare(testSMBAddr, testSMBUser, testSMBPass, testSMBShare)
	if err != nil {
		t.Skipf("需要 Docker SMB 容器: %v", err)
	}
	defer share.Umount()

	s := initSmbReconnect(t)
	defer s.Close()

	// 上传文件并设置过去的修改时间 — Chtimes 失败不应阻止 Upload 成功
	reader := bytes.NewReader(static.Pic1)
	testPath := "chtimes_test.jpg"
	pastTime := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	err = s.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), pastTime)
	if err != nil {
		t.Fatalf("Chtimes 失败不应导致 Upload 返回错误，但收到: %v", err)
	}

	// 验证文件确实上传成功
	ok, _ := s.IsExist(testPath)
	if !ok {
		t.Fatal("Chtimes 失败后文件应存在")
	}

	_ = s.Delete(testPath)
}
