// 白盒并发测试：SMB 并发下载字节级正确性验证
// 需要 Docker（SMB 容器运行时）
// 运行: go test ./server/drive/smb/ -run "TestConcurrentDownload|TestSerialDownload" -v
package smb

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/fregie/img_syncer/test/testutil"
)

const (
	smbConcurrencyAddr  = "127.0.0.1:445"
	smbConcurrencyUser  = "fregie"
	smbConcurrencyPass  = "password"
	smbConcurrencyShare = "photos"
	smbConcurrencyRoot  = "storage"
	smbTestFileName     = "concurrency_test.bin"
)

// uploadTestFile 上传测试文件到 SMB 并返回原始数据
func uploadTestFile(t *testing.T, s *Smb, size int) []byte {
	t.Helper()
	sourceData := make([]byte, size)
	for i := range sourceData {
		sourceData[i] = byte(i & 0xFF)
	}
	err := s.Upload(smbTestFileName, io.NopCloser(bytes.NewReader(sourceData)), int64(size), time.Now())
	if err != nil {
		t.Fatalf("上传测试文件失败: %v", err)
	}
	return sourceData
}

// TestConcurrentDownloadWithOffset 验证 5 个 goroutine 并发下载不同偏移量段的字节级正确性
func TestConcurrentDownloadWithOffset(t *testing.T) {
	share, err := testutil.InitSmbShare(smbConcurrencyAddr, smbConcurrencyUser, smbConcurrencyPass, smbConcurrencyShare)
	if err != nil {
		t.Skipf("跳过 SMB 并发测试：无法连接到 SMB 服务器: %v", err)
	}
	defer share.Umount()
	if err := testutil.CleanSmb(share); err != nil {
		t.Fatalf("CleanSmb: %v", err)
	}
	if err := testutil.InitSmbDir(share, smbConcurrencyRoot); err != nil {
		t.Fatalf("InitSmbDir: %v", err)
	}

	s := NewSmbDrive(smbConcurrencyAddr, smbConcurrencyUser, smbConcurrencyPass)
	s.fs = share
	s.shareName = smbConcurrencyShare
	s.rootPath = smbConcurrencyRoot

	fileSize := 1 << 20 // 1MB
	sourceData := uploadTestFile(t, s, fileSize)

	const numGoroutines = 5
	segmentSize := fileSize / numGoroutines

	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	type result struct {
		idx      int
		readData []byte
		err      error
		elapsed  time.Duration
	}
	results := make([]result, numGoroutines)

	start := time.Now()
	for i := 0; i < numGoroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			t0 := time.Now()
			offset := int64(idx * segmentSize)
			reader, _, err := s.DownloadWithOffset(smbTestFileName, offset)
			if err != nil {
				results[idx] = result{idx: idx, err: err, elapsed: time.Since(t0)}
				return
			}
			data := make([]byte, segmentSize)
			_, readErr := io.ReadFull(reader, data)
			reader.Close()
			results[idx] = result{idx: idx, readData: data, err: readErr, elapsed: time.Since(t0)}
		}(i)
	}
	wg.Wait()
	concurrentElapsed := time.Since(start)

	for _, r := range results {
		if r.err != nil {
			t.Fatalf("goroutine %d 下载失败: %v", r.idx, r.err)
		}
		offset := int64(r.idx * segmentSize)
		expected := sourceData[offset : offset+int64(segmentSize)]
		if !bytes.Equal(r.readData, expected) {
			t.Errorf("goroutine %d 数据不匹配: offset=%d, got %d bytes, expected %d bytes",
				r.idx, offset, len(r.readData), len(expected))
		}
	}

	// 记录耗时（非 pass/fail 条件）
	t.Logf("并发下载 (%d goroutines × %d bytes): 总耗时 %v", numGoroutines, segmentSize, concurrentElapsed)
}

// TestSerialDownloadWithOffset 串行下载作为对比基准
func TestSerialDownloadWithOffset(t *testing.T) {
	share, err := testutil.InitSmbShare(smbConcurrencyAddr, smbConcurrencyUser, smbConcurrencyPass, smbConcurrencyShare)
	if err != nil {
		t.Skipf("跳过 SMB 串行测试：无法连接到 SMB 服务器: %v", err)
	}
	defer share.Umount()
	if err := testutil.CleanSmb(share); err != nil {
		t.Fatalf("CleanSmb: %v", err)
	}
	if err := testutil.InitSmbDir(share, smbConcurrencyRoot); err != nil {
		t.Fatalf("InitSmbDir: %v", err)
	}

	s := NewSmbDrive(smbConcurrencyAddr, smbConcurrencyUser, smbConcurrencyPass)
	s.fs = share
	s.shareName = smbConcurrencyShare
	s.rootPath = smbConcurrencyRoot

	fileSize := 1 << 20
	sourceData := uploadTestFile(t, s, fileSize)

	const numGoroutines = 5
	segmentSize := fileSize / numGoroutines

	start := time.Now()
	for i := 0; i < numGoroutines; i++ {
		offset := int64(i * segmentSize)
		reader, _, err := s.DownloadWithOffset(smbTestFileName, offset)
		if err != nil {
			t.Fatalf("串行下载 %d 失败: %v", i, err)
		}
	dat := make([]byte, segmentSize)
		_, readErr := io.ReadFull(reader, dat)
		reader.Close()
		if readErr != nil {
			t.Fatalf("串行下载 %d 读取失败: %v", i, readErr)
		}
		expected := sourceData[offset : offset+int64(segmentSize)]
		if !bytes.Equal(dat, expected) {
			t.Errorf("串行下载 %d 数据不匹配: offset=%d", i, offset)
		}
	}
	serialElapsed := time.Since(start)
	t.Logf("串行下载 (%d 次 × %d bytes): 总耗时 %v", numGoroutines, segmentSize, serialElapsed)
}

// TestWriteTimingData 将并发 vs 串行的耗时数据写入 test/results/T08-timing.txt
func TestWriteTimingData(t *testing.T) {
	share, err := testutil.InitSmbShare(smbConcurrencyAddr, smbConcurrencyUser, smbConcurrencyPass, smbConcurrencyShare)
	if err != nil {
		t.Skipf("跳过耗时数据写入：无法连接到 SMB 服务器: %v", err)
	}
	defer share.Umount()
	if err := testutil.CleanSmb(share); err != nil {
		t.Fatalf("CleanSmb: %v", err)
	}
	if err := testutil.InitSmbDir(share, smbConcurrencyRoot); err != nil {
		t.Fatalf("InitSmbDir: %v", err)
	}

	s := NewSmbDrive(smbConcurrencyAddr, smbConcurrencyUser, smbConcurrencyPass)
	s.fs = share
	s.shareName = smbConcurrencyShare
	s.rootPath = smbConcurrencyRoot

	fileSize := 1 << 20
	uploadTestFile(t, s, fileSize)

	const numGoroutines = 5
	segmentSize := fileSize / numGoroutines

	// 并发
	var wg sync.WaitGroup
	concStart := time.Now()
	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			reader, _, _ := s.DownloadWithOffset(smbTestFileName, int64(idx*segmentSize))
			if reader != nil {
				io.ReadAll(reader)
				reader.Close()
			}
		}(i)
	}
	wg.Wait()
	concElapsed := time.Since(concStart)

	// 串行
	serStart := time.Now()
	for i := 0; i < numGoroutines; i++ {
		reader, _, _ := s.DownloadWithOffset(smbTestFileName, int64(i*segmentSize))
		if reader != nil {
			io.ReadAll(reader)
			reader.Close()
		}
	}
	serElapsed := time.Since(serStart)

	// 写入结果文件
	resultsDir := "test/results"
	if err := os.MkdirAll(resultsDir, 0755); err != nil {
		t.Fatalf("创建 test/results 目录失败: %v", err)
	}

	content := fmt.Sprintf(`SMB 并发下载耗时报告 (T08)
协议: SMB
文件大小: %d bytes (%d MB)
并发数: %d
每段大小: %d bytes

并发下载总耗时: %v
串行下载总耗时: %v
串行/并发比: %.2fx
下载锁导致并发 ≈ 串行: %v
`, fileSize, fileSize>>20, numGoroutines, segmentSize,
		concElapsed, serElapsed,
		float64(serElapsed)/float64(concElapsed),
		float64(concElapsed) >= float64(serElapsed)*0.8)

	filePath := fmt.Sprintf("%s/T08-timing.txt", resultsDir)
	if err := os.WriteFile(filePath, []byte(content), 0644); err != nil {
		t.Fatalf("写入耗时数据文件失败: %v", err)
	}
	t.Logf("耗时数据已写入 %s", filePath)
}
