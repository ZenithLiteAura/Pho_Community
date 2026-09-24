package smb

import (
	"bytes"
	"fmt"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/fregie/img_syncer/test/static"
	"github.com/fregie/img_syncer/test/testutil"
)

const (
	testSMBAddr  = "127.0.0.1:445"
	testSMBUser  = "fregie"
	testSMBPass  = "password"
	testSMBShare = "photos"
	testSMBRoot  = "storage"
)

// initSmbReconnect 初始化 SMB 连接（SetShare + SetRootPath），
// 返回已连接的 Smb 实例。需要 Docker SMB 容器运行。
func initSmbReconnect(t *testing.T) *Smb {
	t.Helper()
	// 初始化远端共享：清理 + 创建 root dir
	share, err := testutil.InitSmbShare(testSMBAddr, testSMBUser, testSMBPass, testSMBShare)
	if err != nil {
		t.Fatalf("init smb share failed: %v", err)
	}
	if err := testutil.CleanSmb(share); err != nil {
		t.Fatalf("clean smb failed: %v", err)
	}
	if err := testutil.InitSmbDir(share, testSMBRoot); err != nil {
		t.Fatalf("init smb dir failed: %v", err)
	}
	// 构造被测实例
	s := NewSmbDrive(testSMBAddr, testSMBUser, testSMBPass)
	if err := s.SetShare(testSMBShare); err != nil {
		t.Fatalf("SetShare failed: %v", err)
	}
	if err := s.SetRootPath(testSMBRoot); err != nil {
		t.Fatalf("SetRootPath failed: %v", err)
	}
	return s
}

// TestSmbCheckConnExpiredAutoReconnect 验证 TTL 过期后 checkConn 自动重连并完成 Upload。
// 流程：cleanLastConnTime → Upload → 断言成功（内部走完 Umount + Connect 重新 Dial/Mount）。
func TestSmbCheckConnExpiredAutoReconnect(t *testing.T) {
	s := initSmbReconnect(t)

	// 将 lastConnTimestamp 置 0，模拟 TTL 过期
	s.cleanLastConnTime()

	// 执行 Upload — 内部 checkConn 应自动重连
	reader := bytes.NewReader(static.Pic1)
	testPath := "reconnect_test.jpg"
	err := s.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	if err != nil {
		t.Fatalf("Upload after reconnect should succeed, got: %v", err)
	}

	// 验证文件确实上传成功（通过 Download 回读）
	rc, length, err := s.Download(testPath)
	if err != nil {
		t.Fatalf("Download after reconnect upload failed: %v", err)
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
	_ = s.Delete(testPath)
	_ = s.Close()
}

// TestSmbCheckConnFreshNoReconnect 验证 TTL 未过期时 checkConn 短路返回，不触发重连。
// 通过比较 fs 指针证明没有重新 Dial/Mount。
func TestSmbCheckConnFreshNoReconnect(t *testing.T) {
	s := initSmbReconnect(t)

	// 更新 lastConnTime 确保在 TTL 内
	s.updateLastConnTime()

	// 记录当前 fs 指针
	fsBefore := fmt.Sprintf("%p", s.fs)

	// 执行一次 Upload
	reader := bytes.NewReader(static.Pic1)
	testPath := "fresh_test.jpg"
	err := s.Upload(testPath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	if err != nil {
		t.Fatalf("Upload should succeed, got: %v", err)
	}

	// 记录 Upload 后的 fs 指针
	fsAfter := fmt.Sprintf("%p", s.fs)
	if fsBefore != fsAfter {
		t.Fatalf("fs pointer changed after fresh Upload: %s → %s (should NOT reconnect)", fsBefore, fsAfter)
	}

	// verify the file is actually there
	ok, err := s.IsExist(testPath)
	if err != nil {
		t.Fatalf("IsExist failed: %v", err)
	}
	if !ok {
		t.Fatal("uploaded file should exist")
	}

	// 清理
	_ = s.Delete(testPath)
	_ = s.Close()
}

// TestSmbCheckConnExpiredWithoutShare 验证过期重连时如果 shareName 为空会返回错误（冒烟）。
func TestSmbCheckConnExpiredWithoutShare(t *testing.T) {
	s := &Smb{
		addr:              "127.0.0.1:1",
		username:          "x",
		password:          "x",
		shareName:         "",
		lastConnTimestamp: 0, // 过期
	}
	err := s.Upload("x.jpg", io.NopCloser(strings.NewReader("x")), 1, time.Now())
	if err == nil || !strings.Contains(err.Error(), "smb share name is empty") {
		t.Fatalf("expected 'smb share name is empty', got: %v", err)
	}
}

// TestSmbCheckConnExpiredWithBadAddr 验证过期重连时地址不可达会返回 dial 错误。
func TestSmbCheckConnExpiredWithBadAddr(t *testing.T) {
	s := &Smb{
		addr:              "127.0.0.1:1",
		username:          "x",
		password:          "x",
		shareName:         "photos",
		lastConnTimestamp: 0, // 过期
	}
	err := s.Upload("x.jpg", io.NopCloser(strings.NewReader("x")), 1, time.Now())
	if err == nil {
		t.Fatal("expected dial error, got nil")
	}
}
