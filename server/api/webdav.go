package api

import (
	"context"
	"fmt"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/drive/webdav"
	"github.com/studio-b12/gowebdav"
)

func (a *api) SetDriveWebdav(ctx context.Context, req *pb.SetDriveWebdavRequest) (rsp *pb.SetDriveWebdavResponse, e error) {
	rsp = &pb.SetDriveWebdavResponse{Success: true}
	if req.Addr == "" {
		rsp.Success, rsp.Message = false, "param error: url is empty"
		return
	}
	d := webdav.NewWebdavDrive(req.Addr, req.Username, req.Password, req.Insecure)
	// Verify server is reachable with credentials by stat-ing root.
	_, err := d.Cli().Stat("/")
	if err != nil {
		rsp.Success, rsp.Message = false, fmt.Sprintf("connect to %s failed: %s", req.Addr, err.Error())
		return
	}
	a.im.SetDrive(d)
	if req.Root != "" {
		err := d.SetRootPath(req.Root)
		if err != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("set root path failed: %s", err.Error())
			return
		}
	}
	return
}

func (a *api) ListDriveWebdavDir(ctx context.Context, req *pb.ListDriveWebdavDirRequest) (rsp *pb.ListDriveWebdavDirResponse, e error) {
	rsp = &pb.ListDriveWebdavDirResponse{Success: true}
	dri := a.im.Drive()
	if dri == nil {
		rsp.Success, rsp.Message = false, "drive is not set"
		return
	}
	var cli *gowebdav.Client
	switch d := dri.(type) {
	case *webdav.Webdav:
		cli = d.Cli()
	case *webdav.DualWebdav:
		cli = d.PrimaryCli()
	default:
		rsp.Success, rsp.Message = false, "drive is not webdav"
		return
	}
	if req.Dir == "" {
		req.Dir = "/"
	}
	rsp.Dirs = make([]string, 0)
	if cli == nil {
		rsp.Success, rsp.Message = false, "webdav client is not set"
		return
	}
	infos, err := cli.ReadDir(req.Dir)
	if err != nil {
		rsp.Success, rsp.Message = false, fmt.Sprintf("list dir failed: %s", err.Error())
		return
	}
	for _, info := range infos {
		if info.IsDir() {
			rsp.Dirs = append(rsp.Dirs, info.Name())
		}
	}

	return
}

// SetDriveWebdavDual 配置双 WebDAV 目标（主 + 备份），写失败自动回退。
func (a *api) SetDriveWebdavDual(ctx context.Context, req *pb.SetDriveWebdavDualRequest) (rsp *pb.SetDriveWebdavResponse, e error) {
	rsp = &pb.SetDriveWebdavResponse{Success: true}
	if req.Primary == nil || req.Primary.Addr == "" {
		rsp.Success, rsp.Message = false, "param error: primary url is empty"
		return
	}
	primary := webdav.NewWebdavDrive(req.Primary.Addr, req.Primary.Username, req.Primary.Password, req.Primary.Insecure)
	if _, err := primary.Cli().Stat("/"); err != nil {
		rsp.Success, rsp.Message = false, fmt.Sprintf("connect primary %s failed: %s", req.Primary.Addr, err.Error())
		return
	}
	var backup *webdav.Webdav
	if req.Backup != nil && req.Backup.Addr != "" {
		backup = webdav.NewWebdavDrive(req.Backup.Addr, req.Backup.Username, req.Backup.Password, req.Backup.Insecure)
		if _, err := backup.Cli().Stat("/"); err != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("connect backup %s failed: %s", req.Backup.Addr, err.Error())
			return
		}
	}
	d := webdav.NewDualWebdav(primary, backup)
	if req.Primary.Root != "" {
		if err := primary.SetRootPath(req.Primary.Root); err != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("set root path failed: %s", err.Error())
			return
		}
	}
	if backup != nil && req.Backup.Root != "" {
		if err := backup.SetRootPath(req.Backup.Root); err != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("set backup root path failed: %s", err.Error())
			return
		}
	}
	a.im.SetDrive(d)
	return
}
