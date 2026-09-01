package nfs

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/fregie/img_syncer/test/static"
	"github.com/fregie/img_syncer/test/testutil"
)

const (
	testNFSURL  = "192.168.23.10:/nfs"
	testNFSRoot = "storage"
)

// initNfsReconnect 初始化 NFS 连接。需要 Docker NFS 容器运行。
func initNfsReconnect(t *testing.T) *Nfs {
	t.Helper()
	// 清理远端 + 创建 root dir
	cli, err := testutil.GetNFSTarget(testNFSURL)
	if err != nil {
		t.Fatalf("GetNFSTarget failed: %v", err)
	}
	if err := testutil.CleanNFS(cli); err != nil {
		t.Fatalf("CleanNFS failed: %v", err)
	}
	if err := testutil.InitNFSDir(cli, testNFSRoot); err != nil {
		t.Fatalf("InitNFSDir failed: %v", err)
	}

	// 构造被测实例
	d, err := NewNfsDrive(testNFSURL)
	if err != nil {
		t.Fatalf("NewNfsDrive failed: %v", err)
	}
	if err := d.SetRootPath(testNFSRoot); err != nil {
		t.Fatalf("SetRootPath failed: %v", err)
	}
	return d
}

// TestNfsCheckConnExpiredAutoRemount 验证 TTL 过期 + cli 断开后 checkConn 自动重新挂载。
//
// 关键：必须先关闭 cli（否则 checkConn 中的 FSInfo() 会成功并短路返回），
// 再 cleanLastConnTime，然后 Upload 触发 checkConn 走完完整重挂载流程。
// 通过比较重挂前后的 cli 指针来证明 remount 确实发生了。
func TestNfsCheckConnExpiredAutoRemount(t *testing.T) {
	d := initNfsReconnect(t)

	// 记录当前 cli 指针
	cliBefore := fmt.Sprintf("%p", d.cli)

	// 销毁 cli 连接（模拟连接断开）
	d.cli.Close()

	// 将 lastConnTimestamp 置 0，模拟 TTL 过期
	d.cleanLastConnTime()

	// 执行 Upload — 内部 checkConn 应走完完整重挂载流程
	reader := bytes.NewReader(static.Pic1)
	testPath := "reconnect_test.jpg"
	err := d.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	if err != nil {
		t.Fatalf("Upload after remount should succeed, got: %v", err)
	}

	// BLOCKER 断言：cli 指针必须改变，证明 remount 确实发生了
	cliAfter := fmt.Sprintf("%p", d.cli)
	if cliBefore == cliAfter {
		t.Fatalf("cli pointer did NOT change after remount: %s → %s (remount should create new cli)", cliBefore, cliAfter)
	}

	// 验证文件确实上传成功
	rc, length, err := d.Download(testPath)
	if err != nil {
		t.Fatalf("Download after remount upload failed: %v", err)
	}
	defer rc.Close()
	data, err := io.ReadAll(rc)
	if err != nil {
		t.Fatalf("ReadAll failed: %v", err)
	}
	if length != int64(len(static.Pic1)) || len(data) != len(static.Pic1) {
		t.Fatalf("downloaded data length mismatch: got %d/%d, want %d", len(data), length, len(static.Pic1))
	}

	// 清理
	_ = d.Delete(testPath)
	_ = d.Close()
}

// TestNfsCheckConnFreshNoRemount 验证 TTL 未过期时 checkConn 短路返回，不触发重挂载。
//
// 场景：updateLastConnTime 使 lastConnTimestamp 仍在 90s TTL 内，
// checkConn 在第 81-82 行直接 return nil，cli 指针不应改变。
func TestNfsCheckConnFreshNoRemount(t *testing.T) {
	d := initNfsReconnect(t)

	// 更新 lastConnTime 确保在 TTL 内
	d.updateLastConnTime()

	// 记录当前 cli 指针
	cliBefore := fmt.Sprintf("%p", d.cli)

	// 执行一次 Upload — checkConn 应在 TTL 检查处短路
	reader := bytes.NewReader(static.Pic1)
	testPath := "fresh_test.jpg"
	err := d.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	if err != nil {
		t.Fatalf("Upload should succeed, got: %v", err)
	}

	// 验证 cli 指针未改变（90s TTL 短路路径，不应重连）
	cliAfter := fmt.Sprintf("%p", d.cli)
	if cliBefore != cliAfter {
		t.Fatalf("cli pointer changed after fresh Upload: %s → %s (should NOT reconnect)", cliBefore, cliAfter)
	}

	// 验证文件存在
	ok, err := d.IsExist(testPath)
	if err != nil {
		t.Fatalf("IsExist failed: %v", err)
	}
	if !ok {
		t.Fatal("uploaded file should exist")
	}

	// 清理
	_ = d.Delete(testPath)
	_ = d.Close()
}

// TestNfsCheckConnExpiredWithBadHost 验证过期重挂载时 host 不可达返回错误。
func TestNfsCheckConnExpiredWithBadHost(t *testing.T) {
	d := &Nfs{
		host:              "nonexistent.local",
		target:            "/nfs",
		lastConnTimestamp: 0, // 过期
	}
	err := d.Upload("x.jpg", io.NopCloser(bytes.NewReader(static.Pic1)), int64(len(static.Pic1)), time.Now())
	if err == nil {
		t.Fatal("expected error from DialMount to nonexistent host, got nil")
	}
}

// TestNfsReconnectSerialized 验证 connMu 序列化重连：多个 goroutine 同时触发重连,
// 所有 Upload 调用都应成功（不会因竞态条件导致 nil pointer 或重复 unmount）。
func TestNfsReconnectSerialized(t *testing.T) {
	d := initNfsReconnect(t)
	defer d.Close()

	// 使 TTL 过期 + 关闭 cli, 触发完整重连路径
	d.cli.Close()
	d.cleanLastConnTime()

	const numGoroutines = 10
	errCh := make(chan error, numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		go func(idx int) {
			reader := bytes.NewReader(static.Pic1)
			testPath := fmt.Sprintf("reconnect_serialized_%d.jpg", idx)
			err := d.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
			errCh <- err
		}(i)
	}

	// 收集结果
	var failures int
	for i := 0; i < numGoroutines; i++ {
		if err := <-errCh; err != nil {
			t.Logf("goroutine %d 失败: %v", i, err)
			failures++
		}
	}

	if failures > 0 {
		t.Fatalf("concurrent reconnect: %d/%d goroutines failed", failures, numGoroutines)
	}

	// 断言 cli 有效（上传的文件存在）
	for i := 0; i < numGoroutines; i++ {
		testPath := fmt.Sprintf("reconnect_serialized_%d.jpg", i)
		ok, err := d.IsExist(testPath)
		if err != nil {
			t.Fatalf("IsExist(%s): %v", testPath, err)
		}
		if !ok {
			t.Fatalf("file %s should exist after reconnect+upload", testPath)
		}
		_ = d.Delete(testPath)
	}
}

// TestNfsFSInfoUpdatesTTL 验证 FSInfo 健康探测成功后刷新 TTL：
// TTL 过期但 cli 仍存活时，FSInfo 成功后 lastConnTime 应更新为当前时间。
func TestNfsFSInfoUpdatesTTL(t *testing.T) {
	d := initNfsReconnect(t)
	defer d.Close()

	// 强制 TTL 过期（使用远超 90s 的时间）
	atomic.StoreInt64(&d.lastConnTimestamp, time.Now().Add(-2*time.Minute).Unix())

	// 调用 checkConn（通过 IsExist）— FSInfo 应成功并刷新 TTL
	ok, err := d.IsExist("fsinfo_ttl_test.jpg")
	if err != nil {
		t.Fatalf("IsExist failed: %v", err)
	}
	_ = ok // 预期 false（文件不存在）

	// 验证 TTL 已刷新（lastConnTime 距现在应 < 5s）
	elapsed := time.Since(d.lastConnTime())
	if elapsed > 5*time.Second {
		t.Fatalf("lastConnTime not refreshed after FSInfo: elapsed=%v", elapsed)
	}
}

// errorReader 是一个在读取指定字节数后返回错误的 io.Reader。
type errorReader struct {
	data  []byte
	pos   int
	failAt int
}

func (r *errorReader) Read(p []byte) (int, error) {
	if r.pos >= r.failAt {
		return 0, fmt.Errorf("simulated read error")
	}
	n := copy(p, r.data[r.pos:r.failAt])
	r.pos += n
	if n == 0 {
		return 0, fmt.Errorf("simulated read error")
	}
	return n, nil
}

// TestNfsUploadCleansUpOnOpenFileFail 验证上传过程中 io.Copy 失败时,
// 已创建的 0 字节文件被清理（Remove），不留孤儿文件。
func TestNfsUploadCleansUpOnOpenFileFail(t *testing.T) {
	d := initNfsReconnect(t)
	defer d.Close()

	// 使用会在中途出错的 reader — Create + OpenFile 成功后 io.Copy 失败
	// 部分数据先写入文件, 然后 reader 报错, 触发 Remove 清理
	partialData := static.Pic1[:len(static.Pic1)/2]
	er := &errorReader{
		data:   partialData,
		failAt: len(partialData) / 2,
	}
	testPath := "upload_cleanup_test.jpg"
	fullPath := filepath.Join("/", testNFSRoot, testPath)

	// 先确保文件不存在
	_ = d.cli.Remove(fullPath)

	err := d.Upload(testPath, io.NopCloser(er), int64(len(static.Pic1)), time.Now())
	if err == nil {
		// 如果意外成功（部分写入后无错）, 清理
		d.cli.Remove(fullPath)
		t.Fatal("Upload with errorReader should fail")
	}

	// 验证孤儿文件已被清理
	_, _, lookupErr := d.cli.Lookup(fullPath)
	if lookupErr == nil {
		d.cli.Remove(fullPath)
		t.Fatal("orphan file should have been cleaned up after io.Copy failure")
	}
	if !errors.Is(lookupErr, os.ErrNotExist) {
		t.Logf("Lookup returned unexpected error (may indicate file exists): %v", lookupErr)
	}
}

// TestNfsMkdirAllIgnoresExist 验证 MkdirAll 在目录已存在时不返回错误，
// 包括 os.ErrExist 和 syscall.EEXIST 两种路径。
func TestNfsMkdirAllIgnoresExist(t *testing.T) {
	d := initNfsReconnect(t)
	defer d.Close()

	// 创建两层目录结构: /storage/mkdir_eexist/a/b
	basePath := "/" + testNFSRoot + "/mkdir_eexist"
	_, _ = d.cli.Mkdir(basePath, 0755)

	// 创建 a 目录
	dirA := basePath + "/a"
	_, err := d.cli.Mkdir(dirA, 0755)
	if err != nil && !errors.Is(err, os.ErrExist) && !errors.Is(err, syscall.EEXIST) {
		t.Fatalf("Mkdir a: %v", err)
	}

	// 第一次 MkdirAll: 创建 a + b (a 已存在应被忽略)
	err = d.MkdirAll(dirA+"/b", 0755)
	if err != nil {
		t.Fatalf("MkdirAll(a/b) 第一次: %v", err)
	}

	// 第二次 MkdirAll: a/b 已存在, 全部目录都应被忽略
	err = d.MkdirAll(dirA+"/b", 0755)
	if err != nil {
		t.Fatalf("MkdirAll(a/b) 第二次（目录已存在）: %v", err)
	}

	// 清理
	_ = d.cli.RemoveAll(basePath)
}
