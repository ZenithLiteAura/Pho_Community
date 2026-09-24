package api_test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"testing"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/test/static"
	"github.com/stretchr/testify/suite"
	"google.golang.org/grpc"
)

type ImageTestSuite struct {
	suite.Suite
	srv pb.ImgSyncerClient
}

func TestImageTestSuite(t *testing.T) {
	suite.Run(t, new(ImageTestSuite))
}

func (s *ImageTestSuite) SetupTest() {
	err := cleanSmb()
	s.Nilf(err, "failed to clean smb share: %s", err)
	err = initSmbDir()
	s.Nilf(err, "failed to init smb dir: %s", err)
	grpcConn, err := grpc.Dial(grpcAddr, grpc.WithInsecure())
	s.Nil(err)
	s.srv = pb.NewImgSyncerClient(grpcConn)
	s.setupSmbDrive()
}

func (s *ImageTestSuite) setupSmbDrive() {
	rsp1, err := s.srv.SetDriveSMB(context.Background(), &pb.SetDriveSMBRequest{
		Addr:     smbSrvAddr,
		Username: smbUser,
		Password: smbPass,
		Share:    smbShare,
		Root:     smbRootDir,
	})
	s.Nil(err)
	s.True(rsp1.Success)
}

func (s *ImageTestSuite) TestUploadGet() {
	ctx := context.Background()
	err := s.uploadPic1(ctx)
	s.Nil(err)
	s.Nil(waitfile(s.srv, pic1ShouldPath, 5*time.Second))
	data, err := s.get(ctx, pic1ShouldPath)
	s.Nilf(err, "get pic failed: %v", err)
	s.Equal(len(static.Pic1), len(data))
}

func (s *ImageTestSuite) TestGetThumnail() {
	ctx := context.Background()
	err := s.uploadPic1(ctx)
	s.Nil(err)
	s.Nil(waitfile(s.srv, pic1ShouldPath, 5*time.Second))
	data, err := s.get(ctx, pic1ShouldPath)
	s.Nilf(err, "get pic failed: %v", err)
	s.Equal(static.Pic1, data)
	resp, err := http.Get(fmt.Sprintf("http://%s/thumbnail/%s", httpAddr, pic1ShouldPath))
	s.Nilf(err, "get thumbnail failed: %v", err)
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	s.Nilf(err, "read thumbnail failed: %v", err)
	s.Equalf(http.StatusOK, resp.StatusCode, "body: %s", body)
	s.Truef(len(body) > 0, "thumbnail is empty")
}

func (s *ImageTestSuite) TestList() {
	ctx := context.Background()
	rsp1, err := s.srv.ListByDate(ctx, &pb.ListByDateRequest{})
	s.Nilf(err, "list failed: %v", err)
	s.Truef(rsp1.Success, "list failed: %s", rsp1.Message)
	s.Equal(0, len(rsp1.Infos))
	err = s.uploadPic1(ctx)
	s.Nil(err)
	s.Nil(waitfile(s.srv, pic1ShouldPath, 5*time.Second))
	rsp2, err := s.srv.ListByDate(ctx, &pb.ListByDateRequest{})
	s.Nilf(err, "list failed: %v", err)
	s.Truef(rsp2.Success, "list failed: %s", rsp2.Message)
	s.Equal(1, len(rsp2.Infos))
	s.Equalf(pic1ShouldPath, rsp2.Infos[0].Path, "path: %s", rsp2.Infos[0].Path)
}

func (s *ImageTestSuite) TestDelete() {
	ctx := context.Background()
	err := s.uploadPic1(ctx)
	s.Nil(err)
	s.Nil(waitfile(s.srv, pic1ShouldPath, 5*time.Second))
	rsp2, err := s.srv.ListByDate(ctx, &pb.ListByDateRequest{})
	s.Nilf(err, "list failed: %v", err)
	s.Truef(rsp2.Success, "list failed: %s", rsp2.Message)
	s.Equal(1, len(rsp2.Infos))
	rsp3, err := s.srv.Delete(ctx, &pb.DeleteRequest{
		Paths: []string{pic1ShouldPath},
	})
	s.Nilf(err, "delete failed: %v", err)
	s.Truef(rsp3.Success, "delete: %s", rsp3.Message)
	rsp4, err := s.srv.ListByDate(ctx, &pb.ListByDateRequest{})
	s.Nilf(err, "list failed: %v", err)
	s.Equal(0, len(rsp4.Infos))
}

func (s *ImageTestSuite) get(ctx context.Context, path string) ([]byte, error) {
	resp, err := http.Get(fmt.Sprintf("http://%s/%s", httpAddr, path))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("http status: %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

func (s *ImageTestSuite) uploadPhoto(name string, dateLayout string) error {
	req, err := http.NewRequest(http.MethodPost, fmt.Sprintf("http://%s/%s", httpAddr, name), bytes.NewReader(static.Pic1))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "image/jpeg")
	req.Header.Set("Image-Date", dateLayout)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http status: %d", resp.StatusCode)
	}
	io.Copy(io.Discard, resp.Body)
	return nil
}

func (s *ImageTestSuite) TestFilterNotUploadedEarlyStop() {
	ctx := context.Background()

	err := s.uploadPhoto("photo1.jpg", "2023:01:15 10:30:00")
	s.Nil(err)
	err = s.uploadPhoto("photo2.jpg", "2023:01:15 11:00:00")
	s.Nil(err)
	s.Nil(waitfile(s.srv, "2023/01/15/20230115103000_photo1.jpg", 5*time.Second))
	s.Nil(waitfile(s.srv, "2023/01/15/20230115110000_photo2.jpg", 5*time.Second))

	stream, err := s.srv.FilterNotUploaded(ctx)
	s.Nil(err)

	err = stream.Send(&pb.FilterNotUploadedRequest{
		Photos: []*pb.FilterNotUploadedRequestInfo{
			{Name: "photo1.jpg", Date: "2023:01:15 10:30:00", Id: "id1"},
			{Name: "photo2.jpg", Date: "2023:01:15 11:00:00", Id: "id2"},
			{Name: "new1.jpg", Date: "2023:01:15 12:00:00", Id: "id3"},
			{Name: "new2.jpg", Date: "2023:01:15 13:00:00", Id: "id4"},
		},
		IsFinished: true,
	})
	s.Nil(err)

	rsp, err := stream.Recv()
	s.Nil(err)
	s.True(rsp.Success)
	s.True(rsp.IsFinished)

	uploaded := make(map[string]bool)
	for _, id := range rsp.UploadedIDs {
		uploaded[id] = true
	}
	notUploaded := make(map[string]bool)
	for _, id := range rsp.NotUploaedIDs {
		notUploaded[id] = true
	}

	s.True(uploaded["id1"], "photo1 should be uploaded")
	s.True(uploaded["id2"], "photo2 should be uploaded")
	s.False(uploaded["id3"], "new1 should NOT be uploaded")
	s.False(uploaded["id4"], "new2 should NOT be uploaded")
	s.True(notUploaded["id3"], "new1 should be not uploaded")
	s.True(notUploaded["id4"], "new2 should be not uploaded")
	s.False(notUploaded["id1"], "photo1 should NOT be in notUploaded")
	s.False(notUploaded["id2"], "photo2 should NOT be in notUploaded")
}

func (s *ImageTestSuite) TestFilterNotUploadedAllNew() {
	ctx := context.Background()

	stream, err := s.srv.FilterNotUploaded(ctx)
	s.Nil(err)

	err = stream.Send(&pb.FilterNotUploadedRequest{
		Photos: []*pb.FilterNotUploadedRequestInfo{
			{Name: "new1.jpg", Date: "2023:02:20 14:00:00", Id: "id1"},
			{Name: "new2.jpg", Date: "2023:02:20 15:00:00", Id: "id2"},
		},
		IsFinished: true,
	})
	s.Nil(err)

	rsp, err := stream.Recv()
	s.Nil(err)
	s.True(rsp.Success)
	s.True(rsp.IsFinished)
	s.Equal(0, len(rsp.UploadedIDs))
	s.Equal(2, len(rsp.NotUploaedIDs))

	notUploaded := make(map[string]bool)
	for _, id := range rsp.NotUploaedIDs {
		notUploaded[id] = true
	}
	s.True(notUploaded["id1"], "new1 should be not uploaded")
	s.True(notUploaded["id2"], "new2 should be not uploaded")
}

func (s *ImageTestSuite) TestFilterNotUploadedEmptyRequest() {
	ctx := context.Background()

	stream, err := s.srv.FilterNotUploaded(ctx)
	s.Nil(err)

	err = stream.Send(&pb.FilterNotUploadedRequest{
		IsFinished: true,
	})
	s.Nil(err)

	rsp, err := stream.Recv()
	s.Nil(err)
	s.True(rsp.Success)
	s.True(rsp.IsFinished)
	s.Equal(0, len(rsp.UploadedIDs))
	s.Equal(0, len(rsp.NotUploaedIDs))
}

func (s *ImageTestSuite) TestFilterNotUploadedNewFieldName() {
	ctx := context.Background()

	stream, err := s.srv.FilterNotUploaded(ctx)
	s.Nil(err)

	err = stream.Send(&pb.FilterNotUploadedRequest{
		Photos: []*pb.FilterNotUploadedRequestInfo{
			{Name: "new1.jpg", Date: "2023:02:20 14:00:00", Id: "id1"},
			{Name: "new2.jpg", Date: "2023:02:20 15:00:00", Id: "id2"},
		},
		IsFinished: true,
	})
	s.Nil(err)

	rsp, err := stream.Recv()
	s.Nil(err)
	s.True(rsp.Success)
	// 新字段 NotUploadedIDs 应与旧字段 NotUploaedIDs 相同
	s.Equal(len(rsp.NotUploaedIDs), len(rsp.NotUploadedIDs),
		"notUploadedIDs length should match notUploaedIDs length")
	s.Equal(rsp.NotUploaedIDs, rsp.NotUploadedIDs,
		"notUploadedIDs should match notUploaedIDs")
}

func (s *ImageTestSuite) TestFilterNotUploadedLegacyFieldStillWorks() {
	ctx := context.Background()

	stream, err := s.srv.FilterNotUploaded(ctx)
	s.Nil(err)

	err = stream.Send(&pb.FilterNotUploadedRequest{
		Photos: []*pb.FilterNotUploadedRequestInfo{
			{Name: "new1.jpg", Date: "2023:02:20 14:00:00", Id: "id1"},
			{Name: "new2.jpg", Date: "2023:02:20 15:00:00", Id: "id2"},
		},
		IsFinished: true,
	})
	s.Nil(err)

	rsp, err := stream.Recv()
	s.Nil(err)
	s.True(rsp.Success)
	// 旧字段 NotUploaedIDs 仍然正常工作
	s.Equal(2, len(rsp.NotUploaedIDs), "legacy notUploaedIDs should still work")
	s.Equal(2, len(rsp.NotUploadedIDs), "new notUploadedIDs should also work")
}

func (s *ImageTestSuite) TestFilterNotUploadedReportsInvalidDate() {
	ctx := context.Background()

	stream, err := s.srv.FilterNotUploaded(ctx)
	s.Nil(err)

	err = stream.Send(&pb.FilterNotUploadedRequest{
		Photos: []*pb.FilterNotUploadedRequestInfo{
			{Name: "valid.jpg", Date: "2023:03:15 10:00:00", Id: "id_valid"},
			{Name: "bad.jpg", Date: "not-a-date", Id: "id_bad"},
			{Name: "also_bad.jpg", Date: "", Id: "id_empty"},
		},
		IsFinished: true,
	})
	s.Nil(err)

	rsp, err := stream.Recv()
	s.Nil(err)
	s.True(rsp.Success)
	s.True(rsp.IsFinished)

	// valid photos should be in notUploaded (since nothing was uploaded)
	s.Equal(1, len(rsp.NotUploaedIDs))
	s.Equal("id_valid", rsp.NotUploaedIDs[0])

	// invalid date photos should be reported
	s.Equal(2, len(rsp.InvalidIds))
	invalid := make(map[string]bool)
	for _, id := range rsp.InvalidIds {
		invalid[id] = true
	}
	s.True(invalid["id_bad"], "bad date should be reported as invalid")
	s.True(invalid["id_empty"], "empty date should be reported as invalid")
}

func (s *ImageTestSuite) uploadPic1(ctx context.Context) error {
	name := "pic1.jpg"
	req, err := http.NewRequest(http.MethodPost, fmt.Sprintf("http://%s/%s", httpAddr, name), bytes.NewReader(static.Pic1))
	req.Header.Set("Content-Type", "image/jpeg")
	req.Header.Set("Image-Date", "2022:11:08 12:34:36")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http status: %d", resp.StatusCode)
	}
	io.Copy(io.Discard, resp.Body)

	req, err = http.NewRequest(http.MethodPost, fmt.Sprintf("http://%s/thumbnail/%s", httpAddr, name), bytes.NewReader(static.Pic1))
	req.Header.Set("Content-Type", "image/jpeg")
	req.Header.Set("Image-Date", "2022:11:08 12:34:36")
	resp, err = http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http status: %d", resp.StatusCode)
	}
	io.Copy(io.Discard, resp.Body)
	return nil
}
