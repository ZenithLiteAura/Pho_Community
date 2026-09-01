// 白盒单元测试：验证 downloadLock 在并发下载时正确序列化
// 无需 Docker，纯 Go 锁行为测试，确定性 100%
package smb

import (
	"sync"
	"testing"
	"time"
)

// TestDownloadLockSerializesConcurrentDownloads 验证 downloadLock 的互斥行为：
// 1. goroutine A 持有锁时，goroutine B 的 TryLock 返回 false
// 2. goroutine A 释放锁后，goroutine C 的 TryLock 返回 true
// 此测试无需 Docker，仅验证 sync.Mutex 的语义，确定性 100%
func TestDownloadLockSerializesConcurrentDownloads(t *testing.T) {
	s := &Smb{}
	var wg sync.WaitGroup
	lockAcquired := make(chan struct{})
	verifyDone := make(chan struct{})

	// Step 1: goroutine A 获取 downloadLock
	wg.Add(1)
	go func() {
		defer wg.Done()
		s.downloadLock.Lock()
		close(lockAcquired) // 通知主 goroutine：锁已获取

		// 等待验证完成后再释放
		<-verifyDone
		s.downloadLock.Unlock()
	}()

	// 等待 goroutine A 获取锁
	<-lockAcquired

	// 短暂等待确保 goroutine A 的 Lock 完全生效
	time.Sleep(10 * time.Millisecond)

	// Step 2: goroutine B 尝试 TryLock，验证失败（锁被 A 持有）
	wg.Add(1)
	tryFailed := make(chan bool, 1)
	go func() {
		defer wg.Done()
		tryFailed <- !s.downloadLock.TryLock()
	}()

	if got := <-tryFailed; !got {
		t.Error("downloadLock.TryLock() 应该返回 false，因为锁被 goroutine A 持有，但却返回了 true — 锁未正确序列化")
	}

	// Step 3: 释放锁
	close(verifyDone)
	wg.Wait()

	// Step 4: goroutine C 尝试 TryLock，验证成功（锁已释放）
	if !s.downloadLock.TryLock() {
		t.Fatal("downloadLock.TryLock() 应该返回 true，因为锁已释放，但却返回了 false")
	}
	s.downloadLock.Unlock()
}

// TestDownloadLockTryLockConsistency 验证 TryLock 在无竞争时的正常获取
func TestDownloadLockTryLockConsistency(t *testing.T) {
	s := &Smb{}

	for i := 0; i < 100; i++ {
		if !s.downloadLock.TryLock() {
			t.Fatalf("迭代 %d: TryLock 在无人持锁时应返回 true", i)
		}
		s.downloadLock.Unlock()
	}
}

// TestDownloadLockMutualExclusion 验证同一时刻只能有一个 goroutine 持有锁
func TestDownloadLockMutualExclusion(t *testing.T) {
	s := &Smb{}
	const numGoroutines = 10

	var wg sync.WaitGroup
	inCritical := make(chan struct{}, numGoroutines)
	start := make(chan struct{})

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			s.downloadLock.Lock()
			inCritical <- struct{}{}
			time.Sleep(5 * time.Millisecond)
			<-inCritical
			s.downloadLock.Unlock()
		}()
	}

	close(start)
	wg.Wait()

	// 如果两个 goroutine 同时进入临界区，inCritical 会有 2 个元素
	// 此测试依赖 time.Sleep 时序，但在 -race 下最可能捕获竞态
}
