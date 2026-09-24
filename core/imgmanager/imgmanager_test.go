package imgmanager

import (
	"testing"
	"time"

	pb "github.com/fregie/img_syncer/proto"
)

// TestWorkerNum 验证 NewImgManager 正确解析 WorkerNum
func TestWorkerNum(t *testing.T) {
	t.Run("explicit 4", func(t *testing.T) {
		im := NewImgManager(Option{WorkerNum: 4})
		defer im.Close()
		if im.opt.WorkerNum != 4 {
			t.Fatalf("WorkerNum = %d, want 4", im.opt.WorkerNum)
		}
	})
	t.Run("default 2 when zero", func(t *testing.T) {
		im := NewImgManager(Option{})
		defer im.Close()
		if im.opt.WorkerNum != defaultWorkerNum {
			t.Fatalf("WorkerNum = %d, want default %d", im.opt.WorkerNum, defaultWorkerNum)
		}
	})
	t.Run("default 2 when negative", func(t *testing.T) {
		im := NewImgManager(Option{WorkerNum: -1})
		defer im.Close()
		if im.opt.WorkerNum != defaultWorkerNum {
			t.Fatalf("WorkerNum = %d, want default %d", im.opt.WorkerNum, defaultWorkerNum)
		}
	})
}

// TestDeleteSingleImg_LivePhotoCleanup 验证删除 live_ 目录中的文件时会删除整个
// live_ 目录（包含 live video 等所有内容）
func TestDeleteSingleImg_LivePhotoCleanup(t *testing.T) {
	md := newMockDrive()

	// 模拟 live_ 目录结构:
	// 2023/01/01/
	//   live_IMG_0001/
	//     IMG_0001.jpg        ← 要删除的文件
	//     IMG_0001_live_video.mp4
	liveDir := "2023/01/01/live_IMG_0001"
	md.rangeFiles[liveDir] = []mockDirEntry{
		{name: "IMG_0001.jpg", size: 1000, isDir: false},
		{name: "IMG_0001_live_video.mp4", size: 5000, isDir: false},
	}

	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.dri = md

	path := "2023/01/01/live_IMG_0001/IMG_0001.jpg"
	err := im.DeleteSingleImg(path)
	if err != nil {
		t.Fatalf("DeleteSingleImg returned error: %v", err)
	}

	// 预期: 缩略图删除 + Range遍历文件删除 + 目录删除 + 最终删除
	if len(md.deleteCalls) < 5 {
		t.Fatalf("expected at least 5 delete calls, got %d: %v", len(md.deleteCalls), md.deleteCalls)
	}

	// 验证包含了视频文件删除（live video 也被清理）
	foundVideo := false
	foundDir := false
	for _, call := range md.deleteCalls {
		if call == liveDir {
			foundDir = true
		}
		if call == "2023/01/01/live_IMG_0001/IMG_0001_live_video.mp4" {
			foundVideo = true
		}
	}
	if !foundVideo {
		t.Errorf("expected live video file to be deleted too, but it wasn't. calls=%v", md.deleteCalls)
	}
	if !foundDir {
		t.Errorf("expected live photo directory to be deleted, but it wasn't. calls=%v", md.deleteCalls)
	}
}

// TestDeleteSingleImg_RegularPhotoNamedLiveNotMassDeleted 验证删除普通目录中
// 名为 live_xxx 的文件时不会误删除同目录的其他文件
func TestDeleteSingleImg_RegularPhotoNamedLiveNotMassDeleted(t *testing.T) {
	md := newMockDrive()

	// 模拟普通目录结构:
	// 2023/01/01/
	//   live_dog.jpg          ← 要删除的文件
	//   other_photo.jpg       ← 同目录其他文件，不应被删除
	md.rangeFiles["2023/01/01"] = []mockDirEntry{
		{name: "live_dog.jpg", size: 1000, isDir: false},
		{name: "other_photo.jpg", size: 2000, isDir: false},
	}

	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.dri = md

	path := "2023/01/01/live_dog.jpg"
	err := im.DeleteSingleImg(path)
	if err != nil {
		t.Fatalf("DeleteSingleImg returned error: %v", err)
	}

	// parentDir = "01"，不是 "live_xxx"，不会进 Range 分支
	if len(md.deleteCalls) != 2 {
		t.Fatalf("expected exactly 2 delete calls (thumbnail + main), got %d: %v", len(md.deleteCalls), md.deleteCalls)
	}

	for _, call := range md.deleteCalls {
		if call == "2023/01/01/other_photo.jpg" {
			t.Errorf("other_photo.jpg should NOT have been deleted, but it was. calls=%v", md.deleteCalls)
		}
	}
}

// TestRangeByDate_IncludesRequestedDay 验证 RangeByDate 对 DIRECTORY_TYPE_02
// 模式包含请求日期的文件
func TestRangeByDate_IncludesRequestedDay(t *testing.T) {
	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_02)

	md := newMockDrive()

	// 根目录下有三个日期目录
	md.rangeFiles["."] = []mockDirEntry{
		{name: "20260718", size: 0, isDir: true},
		{name: "20260719", size: 0, isDir: true},
		{name: "20260720", size: 0, isDir: true},
	}
	// 每个日期目录下有一个文件
	md.rangeFiles["20260718"] = []mockDirEntry{
		{name: "photo_0718.jpg", size: 100, isDir: false},
	}
	md.rangeFiles["20260719"] = []mockDirEntry{
		{name: "photo_0719.jpg", size: 100, isDir: false},
	}
	md.rangeFiles["20260720"] = []mockDirEntry{
		{name: "photo_0720.jpg", size: 100, isDir: false},
	}

	im.dri = md

	// 查询 2026-07-19 之前（含当日）的照片
	date := time.Date(2026, 7, 19, 0, 0, 0, 0, time.Local)
	var paths []string
	err := im.RangeByDate(date, func(info ImgInfo) bool {
		paths = append(paths, info.Path)
		return true
	})
	if err != nil {
		t.Fatalf("RangeByDate error: %v", err)
	}

	// 应该包含 0718 和 0719 的照片，但不包含 0720
	if len(paths) != 2 {
		t.Fatalf("expected 2 files, got %d: %v", len(paths), paths)
	}
}

// TestImgManagerCloseStopsWorkers 验证 Close() 能优雅停止 worker goroutine
func TestImgManagerCloseStopsWorkers(t *testing.T) {
	im := NewImgManager(Option{WorkerNum: 3})

	err := im.Close()
	if err != nil {
		t.Fatalf("Close returned error: %v", err)
	}
}
