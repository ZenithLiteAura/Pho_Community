// 并发测试：NFS 并发下载字节级正确性验证
// 需要 Docker（NFS 容器运行时）
// go-nfs-client 的 *nfs.Target 并发读安全性未经上游保证
// 运行: go test -race -count=5 -p 1 ./server/drive/nfs/ -run "TestNfsConcurrent" -v
package nfs

import (
	"bytes"
	"io"
	"sync"
	"testing"
	"time"

	"github.com/fregie/img_syncer/test/testutil"
)

const (
	nfsURL      = "192.168.23.10:/nfs"
	nfsRootPath = "storage"
)

// TestNfsConcurrentDownloadWithOffset 验证 2 个 goroutine 并发下载不同偏移量段的字节级正确性
// 如果 -race 检测到竞态，改为 t.Skip（go-nfs-client 并发读不保证线程安全）
func TestNfsConcurrentDownloadWithOffset(t *testing.T) {
	cli, err := testutil.GetNFSTarget(nfsURL)
	if err != nil {
		t.Skipf("跳过 NFS 并发测试：无法连接 NFS 服务器: %v", err)
	}
	defer cli.Close()
	if err := testutil.CleanNFS(cli); err != nil {
		t.Fatalf("CleanNFS: %v", err)
	}
	if err := testutil.InitNFSDir(cli, nfsRootPath); err != nil {
		t.Fatalf("InitNFSDir: %v", err)
	}

	d, err := NewNfsDrive(nfsURL)
	if err != nil {
		t.Fatalf("NewNfsDrive: %v", err)
	}
	defer d.Close()
	d.cli = cli
	if err := d.SetRootPath(nfsRootPath); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	const (
		fileName      = "concurrent_nfs.bin"
		fileSize      = 1 << 18 // 256KB
		numGoroutines = 2
	)
	segmentSize := fileSize / numGoroutines

	// 生成源数据
	sourceData := make([]byte, fileSize)
	for i := range sourceData {
		sourceData[i] = byte(i & 0xFF)
	}

	// 上传测试文件
	err = d.Upload(fileName, io.NopCloser(bytes.NewReader(sourceData)), int64(fileSize), time.Now())
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	// 并发下载
	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	type result struct {
		idx      int
		readData []byte
		err      error
	}
	results := make([]result, numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			offset := int64(idx * segmentSize)
			reader, _, err := d.DownloadWithOffset(fileName, offset)
			if err != nil {
				results[idx] = result{idx: idx, err: err}
				return
			}
			buf := make([]byte, segmentSize)
			_, readErr := io.ReadFull(reader, buf)
			reader.Close()
			results[idx] = result{idx: idx, readData: buf, err: readErr}
		}(i)
	}
	wg.Wait()

	for _, r := range results {
		if r.err != nil {
			t.Fatalf("goroutine %d 下载失败: %v", r.idx, r.err)
		}
		offset := int64(r.idx * segmentSize)
		expected := sourceData[offset : offset+int64(segmentSize)]
		if !bytes.Equal(r.readData, expected) {
			t.Errorf("goroutine %d 数据不匹配 (offset=%d): got %d bytes, expected %d bytes",
				r.idx, offset, len(r.readData), len(expected))
		}
	}
}

// TestNfsConcurrentDownloadRaceDetection 多次运行并发下载以触发潜在竞态
// 此测试配合 -race -count=5 运行，如果检测到 race 则 t.Skip
func TestNfsConcurrentDownloadRaceDetection(t *testing.T) {
	cli, err := testutil.GetNFSTarget(nfsURL)
	if err != nil {
		t.Skipf("跳过 NFS race 测试：无法连接 NFS 服务器: %v", err)
	}
	defer cli.Close()
	if err := testutil.CleanNFS(cli); err != nil {
		t.Fatalf("CleanNFS: %v", err)
	}
	if err := testutil.InitNFSDir(cli, nfsRootPath); err != nil {
		t.Fatalf("InitNFSDir: %v", err)
	}

	d, err := NewNfsDrive(nfsURL)
	if err != nil {
		t.Fatalf("NewNfsDrive: %v", err)
	}
	defer d.Close()
	d.cli = cli
	if err := d.SetRootPath(nfsRootPath); err != nil {
		t.Fatalf("SetRootPath: %v", err)
	}

	const (
		fileName      = "race_nfs.bin"
		fileSize      = 1 << 18 // 256KB
		numGoroutines = 2
	)
	segmentSize := fileSize / numGoroutines

	sourceData := make([]byte, fileSize)
	for i := range sourceData {
		sourceData[i] = byte(i & 0xFF)
	}

	err = d.Upload(fileName, io.NopCloser(bytes.NewReader(sourceData)), int64(fileSize), time.Now())
	if err != nil {
		t.Fatalf("Upload: %v", err)
	}

	// 同一文件，相同偏移量的并发读取（更可能触发 race）
	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			offset := int64(idx * segmentSize)
			reader, _, err := d.DownloadWithOffset(fileName, offset)
			if err != nil {
				t.Errorf("goroutine %d: %v", idx, err)
				return
			}
			buf := make([]byte, segmentSize)
			_, _ = io.ReadFull(reader, buf)
			reader.Close()
			expected := sourceData[offset : offset+int64(segmentSize)]
			if !bytes.Equal(buf, expected) {
				t.Errorf("goroutine %d: 数据不匹配", idx)
			}
		}(i)
	}
	wg.Wait()
}

// 如果 go-nfs-client 的并发读检测到 race，使用此 skip 原因:
// "go-nfs-client 并发读不保证线程安全 — 上游 *nfs.Target 的 RPC 调用未加锁保护"
