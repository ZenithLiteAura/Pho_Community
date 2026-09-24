package api_test

import (
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/test/testutil"
	"github.com/hirochachacha/go-smb2"
)

const (
	grpcAddr   = "127.0.0.1:50051"
	httpAddr   = "127.0.0.1:8000"
	smbSrvAddr = "smb"
	smbAddr    = "127.0.0.1:445"
	smbUser    = "fregie"
	smbPass    = "password"
	smbShare   = "photos"
	smbRootDir = "storage"

	pic1ShouldPath = "2022/11/08/20221108123436_pic1.jpg"
)

func initSmbShare() (*smb2.Share, error) {
	return testutil.InitSmbShare(smbAddr, smbUser, smbPass, smbShare)
}

func cleanSmb() error {
	share, err := testutil.InitSmbShare(smbAddr, smbUser, smbPass, smbShare)
	if err != nil {
		return err
	}
	return testutil.CleanSmb(share)
}

func initSmbDir() error {
	share, err := testutil.InitSmbShare(smbAddr, smbUser, smbPass, smbShare)
	if err != nil {
		return err
	}
	return testutil.InitSmbDir(share, smbRootDir)
}

func waitfile(srv pb.ImgSyncerClient, path string, timeout time.Duration) error {
	return testutil.WaitFileHTTP(httpAddr, path, timeout)
}
