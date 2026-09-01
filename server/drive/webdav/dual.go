package webdav

import (
	"io"
	"io/fs"
	"os"
	"time"

	"github.com/studio-b12/gowebdav"
)

// DualWebdav 双 WebDAV 目标：主目标写失败时自动回退到备份目标。
// 满足 StorageDrive 接口，可作为 ImgManager 的活动驱动器。
//
// 写路径（Upload）：
//   将请求体先落盘到临时文件，然后依次尝试主/备份目标，
//   避免「主目标写一半失败后流已被消费、无法重放」的问题。
// 读路径（Download / DownloadWithOffset / Delete / Range / IsExist）：
//   优先主目标，失败回退备份目标（浏览/下载在主目标异常时仍可用）。
type DualWebdav struct {
	primary *Webdav
	backup  *Webdav // 可为 nil（等效单目标）
}

// NewDualWebdav 构造双目标驱动器；backup 可为 nil。
func NewDualWebdav(primary, backup *Webdav) *DualWebdav {
	return &DualWebdav{primary: primary, backup: backup}
}

// PrimaryCli 暴露主目标客户端（供目录浏览等扩展能力使用）。
func (d *DualWebdav) PrimaryCli() *gowebdav.Client {
	if d.primary == nil {
		return nil
	}
	return d.primary.Cli()
}

// Primary 返回主目标（供 ListDriveWebdavDir 等 type-assert 使用）。
func (d *DualWebdav) Primary() *Webdav { return d.primary }

// IsRootPathSet 委托主目标。
func (d *DualWebdav) IsRootPathSet() bool {
	return d.primary != nil && d.primary.IsRootPathSet()
}

// SetRootPath 同时设置主/备份目标根路径。
func (d *DualWebdav) SetRootPath(rootPath string) error {
	if d.primary == nil {
		return os.ErrNotExist
	}
	if err := d.primary.SetRootPath(rootPath); err != nil {
		return err
	}
	if d.backup != nil {
		if err := d.backup.SetRootPath(rootPath); err != nil {
			return err
		}
	}
	return nil
}

// Upload 主目标优先，失败回退备份目标。
func (d *DualWebdav) Upload(path string, reader io.ReadCloser, size int64, lastModified time.Time) error {
	defer reader.Close()
	if d.primary == nil {
		return os.ErrNotExist
	}
	// 将流落盘到临时文件，保证可向多个目标重放。
	tmp, err := os.CreateTemp("", "pho-dual-webdav-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	defer tmp.Close()
	if _, err := io.Copy(tmp, reader); err != nil {
		return err
	}
	actualSize, err := tmp.Seek(0, io.SeekEnd)
	if err != nil {
		return err
	}
	// 主目标
	if err := d.primary.Upload(path, io.NopCloser(io.NewSectionReader(tmp, 0, actualSize)), actualSize, lastModified); err == nil {
		return nil
	} else if d.backup == nil {
		return err
	} else {
		// 主目标失败：回退备份目标
		return d.backup.Upload(path, io.NopCloser(io.NewSectionReader(tmp, 0, actualSize)), actualSize, lastModified)
	}
}

// IsExist 主目标优先，失败回退备份。
func (d *DualWebdav) IsExist(path string) (bool, error) {
	if d.primary == nil {
		return false, os.ErrNotExist
	}
	ok, err := d.primary.IsExist(path)
	if err == nil && ok {
		return true, nil
	}
	if d.backup == nil {
		return ok, err
	}
	return d.backup.IsExist(path)
}

// Download 主目标优先，失败回退备份。
func (d *DualWebdav) Download(path string) (io.ReadCloser, int64, error) {
	if d.primary == nil {
		return nil, 0, os.ErrNotExist
	}
	r, s, err := d.primary.Download(path)
	if err == nil {
		return r, s, nil
	}
	if d.backup == nil {
		return nil, 0, err
	}
	return d.backup.Download(path)
}

// DownloadWithOffset 主目标优先，失败回退备份。
func (d *DualWebdav) DownloadWithOffset(path string, offset int64) (io.ReadCloser, int64, error) {
	if d.primary == nil {
		return nil, 0, os.ErrNotExist
	}
	r, s, err := d.primary.DownloadWithOffset(path, offset)
	if err == nil {
		return r, s, nil
	}
	if d.backup == nil {
		return nil, 0, err
	}
	return d.backup.DownloadWithOffset(path, offset)
}

// Delete 主目标优先，失败回退备份。
func (d *DualWebdav) Delete(path string) error {
	if d.primary == nil {
		return os.ErrNotExist
	}
	err := d.primary.Delete(path)
	if err == nil {
		return nil
	}
	if d.backup == nil {
		return err
	}
	return d.backup.Delete(path)
}

// Range 主目标优先，失败回退备份。
func (d *DualWebdav) Range(dir string, deal func(fs.FileInfo) bool) error {
	if d.primary == nil {
		return os.ErrNotExist
	}
	err := d.primary.Range(dir, deal)
	if err == nil {
		return nil
	}
	if d.backup == nil {
		return err
	}
	return d.backup.Range(dir, deal)
}

// Close 关闭两个目标。
func (d *DualWebdav) Close() error {
	if d.primary != nil {
		_ = d.primary.Close()
	}
	if d.backup != nil {
		_ = d.backup.Close()
	}
	return nil
}
