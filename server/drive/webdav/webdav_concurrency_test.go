// 并发测试：WebDAV 并发下载字节级正确性验证
// 使用 httptest 模拟 WebDAV 服务器，无需 Docker
// 运行: go test ./server/drive/webdav/ -run "TestWebdavConcurrent" -v
package webdav

import (
	"bytes"
	"io"
	"sync"
	"testing"
	"time"
)

// TestWebdavConcurrentDownloadWithOffset 验证 5 个 goroutine 并发下载不同偏移量段的字节级正确性
// WebDAV 无下载锁，并发下载应该正常工作
func TestWebdavConcurrentDownloadWithOffset(t *testing.T) {
	fileSize := 1 << 20 // 1MB
	sourceData := make([]byte, fileSize)
	for i := range sourceData {
		sourceData[i] = byte(i & 0xFF)
	}

	stub := newWebdavStub(t, nil)
	d := driveWithRoot(t, stub, "storage")

	// 通过 PUT 添加测试文件到 stub（绕过 Upload 的 MkdirAll）
	stub.addFile("/storage/testfile.bin", sourceData)

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
			reader, _, err := d.DownloadWithOffset("testfile.bin", offset)
			if err != nil {
				results[idx] = result{idx: idx, err: err, elapsed: time.Since(t0)}
				return
			}
				buf := make([]byte, segmentSize)
				_, readErr := io.ReadFull(reader, buf)
				reader.Close()
				results[idx] = result{idx: idx, readData: buf, err: readErr, elapsed: time.Since(t0)}
		}(i)
	}
	wg.Wait()
	totalElapsed := time.Since(start)

	for _, r := range results {
		if r.err != nil {
			t.Fatalf("goroutine %d 下载失败: %v", r.idx, r.err)
		}
		offset := int64(r.idx * segmentSize)
		expected := sourceData[offset : offset+int64(segmentSize)]
		if !bytes.Equal(r.readData, expected) {
			t.Errorf("goroutine %d 数据不匹配 (offset=%d): got %d bytes, expected %d bytes, elapsed=%v",
				r.idx, offset, len(r.readData), len(expected), r.elapsed)
		}
	}
	t.Logf("WebDAV 并发下载 (%d goroutines × %d bytes): 总耗时 %v", numGoroutines, segmentSize, totalElapsed)
}

// TestWebdavConcurrentDownloadNoDataRace 重复多次并发下载，配合 -race 检测竞态
func TestWebdavConcurrentDownloadNoDataRace(t *testing.T) {
	fileSize := 1 << 17 // 128KB，足够小以快速迭代
	sourceData := make([]byte, fileSize)
	for i := range sourceData {
		sourceData[i] = byte(i & 0xFF)
	}

	stub := newWebdavStub(t, nil)
	d := driveWithRoot(t, stub, "storage")
	stub.addFile("/storage/race.bin", sourceData)

	const iterations = 10
	const numGoroutines = 4
	segmentSize := fileSize / numGoroutines

	for iter := 0; iter < iterations; iter++ {
		var wg sync.WaitGroup
		wg.Add(numGoroutines)

		for i := 0; i < numGoroutines; i++ {
			go func(idx int) {
				defer wg.Done()
				offset := int64(idx * segmentSize)
				reader, _, err := d.DownloadWithOffset("race.bin", offset)
				if err != nil {
					t.Errorf("迭代 %d, goroutine %d: %v", iter, idx, err)
					return
				}
					data := make([]byte, segmentSize)
					_, readErr := io.ReadFull(reader, data)
					reader.Close()
					if readErr != nil {
						t.Errorf("迭代 %d, goroutine %d: ReadFull: %v", iter, idx, readErr)
						return
					}
					expected := sourceData[offset : offset+int64(segmentSize)]
					if !bytes.Equal(data, expected) {
					t.Errorf("迭代 %d, goroutine %d: 数据不匹配 (offset=%d)", iter, idx, offset)
				}
			}(i)
		}
		wg.Wait()
	}
}

// TestWebdavConcurrentOverlappingOffsets 验证重叠偏移量的并发下载
// 不同 goroutine 请求相同偏移量也应该各自获取正确数据
func TestWebdavConcurrentOverlappingOffsets(t *testing.T) {
	fileSize := 1 << 16 // 64KB
	sourceData := make([]byte, fileSize)
	for i := range sourceData {
		sourceData[i] = byte(i & 0xFF)
	}

	stub := newWebdavStub(t, nil)
	d := driveWithRoot(t, stub, "storage")
	stub.addFile("/storage/overlap.bin", sourceData)

	const numGoroutines = 5
	// 完全相同的偏移量（0），所有 goroutine 下载整个文件
	var wg sync.WaitGroup
	wg.Add(numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		go func(idx int) {
			defer wg.Done()
			reader, _, err := d.DownloadWithOffset("overlap.bin", 0)
			if err != nil {
				t.Errorf("goroutine %d: %v", idx, err)
				return
			}
			data, readErr := io.ReadAll(reader)
			reader.Close()
			if readErr != nil {
				t.Errorf("goroutine %d: ReadAll: %v", idx, readErr)
				return
			}
			if !bytes.Equal(data, sourceData) {
				t.Errorf("goroutine %d: 数据不匹配 (offset=0), got %d bytes, expected %d bytes",
					idx, len(data), len(sourceData))
			}
		}(i)
	}
	wg.Wait()
}

// driveWithRoot 创建 WebDAV drive 连接到 stub 并设置 root path
func driveWithRoot(t *testing.T, stub *webdavStub, root string) *Webdav {
	t.Helper()
	d := newDriveOnStub(t, stub)
	if err := d.SetRootPath(root); err != nil {
		t.Fatalf("SetRootPath(%q): %v", root, err)
	}
	return d
}
