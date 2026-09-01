package drive_test

import (
	"bytes"
	"io"
	"io/fs"
	"testing"
	"time"

	nfsdrive "github.com/fregie/img_syncer/server/drive/nfs"
	"github.com/fregie/img_syncer/server/drive/smb"
	"github.com/fregie/img_syncer/server/drive/webdav"
	"github.com/fregie/img_syncer/server/imgmanager"
	"github.com/fregie/img_syncer/test/static"
	"github.com/fregie/img_syncer/test/testutil"
	"github.com/stretchr/testify/suite"
)

const (
	smbAddr    = "127.0.0.1:445"
	smbUser    = "fregie"
	smbPass    = "password"
	smbShare   = "photos"
	smbRootDir = "storage"

	webdavUrl      = "http://127.0.0.1:8080"
	webdavUser     = "fregie"
	webdavPass     = "password"
	webdavRootPath = "storage"

	nfsUrl      = "192.168.23.10:/nfs"
	nfsRootPath = "storage"
)

type DriveTest struct {
	suite.Suite
}

func TestDriveSuite(t *testing.T) {
	suite.Run(t, new(DriveTest))
}

func (d *DriveTest) TestAllDrives() {
	tests := []struct {
		name     string
		newDrive func(d *DriveTest) (imgmanager.StorageDrive, func())
	}{
		{
			"SMB", func(d *DriveTest) (imgmanager.StorageDrive, func()) {
				share, err := testutil.InitSmbShare(smbAddr, smbUser, smbPass, smbShare)
				d.Require().Nilf(err, "init smb share failed: %v", err)
				err = testutil.CleanSmb(share)
				d.Require().Nilf(err, "clean smb failed: %v", err)
				err = testutil.InitSmbDir(share, smbRootDir)
				d.Require().Nilf(err, "init smb dir failed: %v", err)
				dri := smb.NewSmbDrive(smbAddr, smbUser, smbPass)
				err = dri.SetShare(smbShare)
				d.Require().Nilf(err, "set share failed: %v", err)
				err = dri.SetRootPath(smbRootDir)
				d.Require().Nilf(err, "set root path failed: %v", err)
				return dri, func() { dri.Close() }
			},
		},
		{
			"WebDAV", func(d *DriveTest) (imgmanager.StorageDrive, func()) {
				err := testutil.InitWebdav(webdavUrl, webdavUser, webdavPass, webdavRootPath)
				d.Require().Nilf(err, "init webdav failed: %v", err)
				dri := webdav.NewWebdavDrive(webdavUrl, webdavUser, webdavPass, false)
				err = dri.SetRootPath(webdavRootPath)
				d.Require().Nilf(err, "set root path failed: %v", err)
				return dri, func() { dri.Close() }
			},
		},
		{
			"NFS", func(d *DriveTest) (imgmanager.StorageDrive, func()) {
				cli, err := testutil.GetNFSTarget(nfsUrl)
				d.Require().Nilf(err, "get nfs target failed: %v", err)
				err = testutil.CleanNFS(cli)
				d.Require().Nilf(err, "clean nfs failed: %v", err)
				err = testutil.InitNFSDir(cli, nfsRootPath)
				d.Require().Nilf(err, "init nfs dir failed: %v", err)
				dri, err := nfsdrive.NewNfsDrive(nfsUrl)
				d.Require().Nilf(err, "new nfs drive failed: %v", err)
				err = dri.SetRootPath(nfsRootPath)
				d.Require().Nilf(err, "set root path failed: %v", err)
				return dri, func() { dri.Close() }
			},
		},
	}
	for _, tt := range tests {
		d.Run(tt.name, func() {
			dri, cleanup := tt.newDrive(d)
			defer cleanup()
			d.Run("Upload_Download_Delete_Range_IsExist", func() { d.testDrive(dri) })
			d.Run("DownloadWithOffset", func() { d.testDownloadOffset(dri) })
			d.Run("DownloadWithOffset_OutOfRange", func() { d.testDownloadWithOffsetOutOfRange(dri) })
			d.Run("Delete_NonExistent", func() { d.testDeleteNonExistent(dri) })
			d.Run("Upload_OverwriteExisting", func() { d.testUploadOverwriteExisting(dri) })
			d.Run("Range_SortedDescendingByModTime", func() { d.testRangeSortedDescendingByModTime(dri) })
			d.Run("Range_EarlyStop", func() { d.testRangeEarlyStop(dri) })
		})
	}
}

func (d *DriveTest) testDrive(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	filePath := "/dir/pic1.jpg"

	// IsExist: false before upload
	exist, err := dri.IsExist(filePath)
	d.Nilf(err, "check exist failed: %v", err)
	d.False(exist, "file should not exist before upload")

	// Upload
	reader := bytes.NewReader(static.Pic1)
	err = dri.Upload(filePath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "upload failed: %v", err)

	// IsExist: true after upload
	exist, err = dri.IsExist(filePath)
	d.Nilf(err, "check exist after upload failed: %v", err)
	d.True(exist, "file should exist after upload")

	// Download + byte-level comparison
	downloadCheck(d, dri, filePath)

	// Delete
	err = dri.Delete(filePath)
	d.Nilf(err, "delete failed: %v", err)

	// IsExist: false after delete
	exist, err = dri.IsExist(filePath)
	d.Nilf(err, "check exist after delete failed: %v", err)
	d.False(exist, "file should not exist after delete")

	// Range: upload /dir/pic1.jpg and /dir/pic2.jpg
	filePath2 := "/dir/pic2.jpg"
	reader.Seek(0, io.SeekStart)
	err = dri.Upload(filePath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "re-upload pic1 failed: %v", err)
	reader.Seek(0, io.SeekStart)
	err = dri.Upload(filePath2, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "upload pic2 failed: %v", err)

	// IsExist: both true
	exist, err = dri.IsExist(filePath)
	d.Nilf(err, "check exist pic1 failed: %v", err)
	d.True(exist, "pic1 should exist before range")
	exist, err = dri.IsExist(filePath2)
	d.Nilf(err, "check exist pic2 failed: %v", err)
	d.True(exist, "pic2 should exist before range")

	// Range
	files := make([]string, 0)
	err = dri.Range("/dir", func(fi fs.FileInfo) bool {
		files = append(files, fi.Name())
		return true
	})
	d.Nilf(err, "range failed: %v", err)
	d.Containsf(files, "pic1.jpg", "range missing pic1: %v", files)
	d.Containsf(files, "pic2.jpg", "range missing pic2: %v", files)
}

// downloadCheck downloads the file at path and compares content byte-for-byte with static.Pic1.
func downloadCheck(d *DriveTest, dri imgmanager.StorageDrive, path string) {
	reader, length, err := dri.Download(path)
	d.Nilf(err, "download failed: %v", err)
	data, err := io.ReadAll(reader)
	reader.Close()
	d.Nilf(err, "read data failed: %v", err)
	d.True(bytes.Equal(static.Pic1, data), "downloaded content byte mismatch")
	d.Equal(int64(len(static.Pic1)), length)
}

func (d *DriveTest) testDownloadOffset(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	filePath := "/offset/pic1.jpg"

	reader := bytes.NewReader(static.Pic1)
	err := dri.Upload(filePath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "upload failed: %v", err)

	exist, err := dri.IsExist(filePath)
	d.Nilf(err, "check exist failed: %v", err)
	d.True(exist, "file should exist before offset download")

	reader2, length, err := dri.DownloadWithOffset(filePath, 256)
	d.Nilf(err, "download with offset failed: %v", err)
	buf1 := make([]byte, 256)
	_, err = io.ReadFull(reader2, buf1)
	reader2.Close()
	d.Nilf(err, "read offset data failed: %v", err)
	d.True(bytes.Equal(static.Pic1[256:256+256], buf1), "offset content byte mismatch")
	d.Equal(int64(len(static.Pic1)), length)
}

func (d *DriveTest) testDownloadWithOffsetOutOfRange(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	filePath := "/edge/outofrange.jpg"

	reader := bytes.NewReader(static.Pic1)
	err := dri.Upload(filePath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "upload failed: %v", err)

	_, _, err = dri.DownloadWithOffset(filePath, int64(len(static.Pic1))+1024)
	d.NotNilf(err, "expected error for offset beyond file size")
}

func (d *DriveTest) testDeleteNonExistent(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	path := "/nonexistent/file.jpg"
	// Delete on non-existent path must not panic.
	_ = dri.Delete(path)
	// File should still not exist after delete.
	exist, err := dri.IsExist(path)
	d.Nilf(err, "isExist on non-existent should not fail: %v", err)
	d.Falsef(exist, "non-existent file should still not exist after delete")
}

func (d *DriveTest) testUploadOverwriteExisting(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	filePath := "/overwrite/pic.jpg"

	reader := bytes.NewReader(static.Pic1)
	err := dri.Upload(filePath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "first upload failed: %v", err)

	reader.Seek(0, io.SeekStart)
	err = dri.Upload(filePath, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
	d.Nilf(err, "overwrite upload failed: %v", err)

	downloadCheck(d, dri, filePath)
}

func (d *DriveTest) testRangeSortedDescendingByModTime(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	baseDir := "/timerange"

	for _, name := range []string{"old.jpg", "mid.jpg", "new.jpg"} {
		reader := bytes.NewReader(static.Pic1)
		err := dri.Upload(baseDir+"/"+name, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
		d.Nilf(err, "upload %s failed: %v", name, err)
		time.Sleep(1100 * time.Millisecond)
	}

	var files []string
	err := dri.Range(baseDir, func(fi fs.FileInfo) bool {
		files = append(files, fi.Name())
		return true
	})
	d.Nilf(err, "range failed: %v", err)
	d.Require().Equalf(3, len(files), "expected 3 files, got %d: %v", len(files), files)
	d.Equal("new.jpg", files[0], "newest file should be first")
	d.Equal("mid.jpg", files[1], "middle file should be second")
	d.Equal("old.jpg", files[2], "oldest file should be last")
}

func (d *DriveTest) testRangeEarlyStop(dri imgmanager.StorageDrive) {
	d.Require().NotNil(dri)
	baseDir := "/earlystop"

	for _, name := range []string{"a.jpg", "b.jpg", "c.jpg"} {
		reader := bytes.NewReader(static.Pic1)
		err := dri.Upload(baseDir+"/"+name, io.NopCloser(reader), int64(len(static.Pic1)), time.Now())
		d.Nilf(err, "upload %s failed: %v", name, err)
	}

	count := 0
	err := dri.Range(baseDir, func(fi fs.FileInfo) bool {
		count++
		return count < 2
	})
	d.Nilf(err, "range early stop failed: %v", err)
	d.Equal(2, count, "expected 2 files collected before early stop, got %d", count)
}
