package api

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/imgmanager"
)

type api struct {
	im                *imgmanager.ImgManager
	httpPort          int
	startTime         time.Time

	pb.UnimplementedImgSyncerServer
}

func NewApi(im *imgmanager.ImgManager) *api {
	a := &api{
		im:        im,
		startTime: time.Now(),
	}
	return a
}

func (a *api) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingResponse, error) {
	return &pb.PingResponse{
		ServerStartTime: a.startTime.Unix(),
		UptimeSeconds:   int64(time.Since(a.startTime).Seconds()),
	}, nil
}

func (a *api) SetDirectoryType(ctx context.Context, req *pb.SetDirectoryTypeRequest) (rsp *pb.SetDirectoryTypeResponse, err error) {
	rsp = &pb.SetDirectoryTypeResponse{Success: true}
	a.im.SetDirectoryType(req.DirectoryType)
	return
}

func (a *api) ListByDate(ctx context.Context, req *pb.ListByDateRequest) (rsp *pb.ListByDateResponse, err error) {
	rsp = &pb.ListByDateResponse{Success: true}
	if req.MaxReturn <= 0 {
		req.MaxReturn = 100
	}
	if req.Offset <= 0 {
		req.Offset = 0
	}
	var e error
	start := time.Now()
	if req.Date != "" {
		start, e = time.Parse("2006:01:02", req.Date)
		if e != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("param error: date format error: %s", req.Date)
			return
		}
	}
	rsp.Infos = make([]*pb.FileInfo, 0, req.MaxReturn)
	offset := req.Offset
	needReturn := req.MaxReturn
	e = a.im.RangeByDate(start, func(info imgmanager.ImgInfo) bool {
		if offset > 0 {
			offset--
			return true
		}
		rsp.Infos = append(rsp.Infos, &pb.FileInfo{
			Path:        info.Path,
			Size:        info.Size,
			IsLivePhoto: info.IsLivePhoto,
		})
		needReturn--
		return needReturn > 0
	})
	if e != nil {
		rsp.Success, rsp.Message = false, e.Error()
		return
	}
	return
}

func (a *api) Delete(ctx context.Context, req *pb.DeleteRequest) (rsp *pb.DeleteResponse, err error) {
	rsp = &pb.DeleteResponse{Success: true}
	for i, p := range req.Paths {
		cleaned, err := sanitizePath(p)
		if err != nil {
			rsp.Success = false
			rsp.Message = fmt.Sprintf("invalid path at index %d: %s", i, err.Error())
			return rsp, nil
		}
		req.Paths[i] = cleaned
	}
	a.im.DeleteImg(req.Paths)
	return
}

func (a *api) FilterNotUploaded(stream pb.ImgSyncer_FilterNotUploadedServer) error {
	nameToID := make(map[string]string)
	targetIDs := make(map[string]bool)
	invalidIDs := make([]string, 0)

	for {
		r, err := stream.Recv()
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
		for _, info := range r.Photos {
			t, err := time.Parse("2006:01:02 15:04:05", info.Date)
			if err != nil {
				invalidIDs = append(invalidIDs, info.Id)
				continue
			}
			encoded := encodeName(t, info.Name)
			nameToID[encoded] = info.Id
			nameToID[encoded+".aes"] = info.Id
			targetIDs[info.Id] = true
		}
		if r.IsFinished {
			break
		}
	}

	if len(targetIDs) == 0 {
		return stream.Send(&pb.FilterNotUploadedResponse{
			Success:    true,
			IsFinished: true,
			InvalidIds: invalidIDs,
		})
	}

	uploadedIDs := make([]string, 0)
	unmatchedCount := len(targetIDs)

	a.im.RangeByDate(time.Now(), func(info imgmanager.ImgInfo) bool {
		name := filepath.Base(info.Path)
		if id, ok := nameToID[name]; ok {
			if targetIDs[id] {
				targetIDs[id] = false
				unmatchedCount--
				uploadedIDs = append(uploadedIDs, id)
			}
		}
		return unmatchedCount > 0
	})

	notUploadedIDs := make([]string, 0, unmatchedCount)
	for id, unmatched := range targetIDs {
		if unmatched {
			notUploadedIDs = append(notUploadedIDs, id)
		}
	}

	return stream.Send(&pb.FilterNotUploadedResponse{
		Success:        true,
		IsFinished:     true,
		NotUploaedIDs:  notUploadedIDs,
		NotUploadedIDs: notUploadedIDs,
		UploadedIDs:    uploadedIDs,
		InvalidIds:     invalidIDs,
	})
}

// func (a *api) FilterNotUploaded(ctx context.Context, req *pb.FilterNotUploadedRequest) (rsp *pb.FilterNotUploadedResponse, err error) {
// 	rsp = &pb.FilterNotUploadedResponse{Success: true}
// 	if len(req.Photos) == 0 {
// 		rsp.Success, rsp.Message = false, "param error: names is empty"
// 		return
// 	}
// 	all := make(map[string]bool)
// 	a.im.RangeByDate(time.Now(), func(path string, size int64) bool {
// 		name := filepath.Base(path)
// 		all[name] = true
// 		return true
// 	})
// 	rsp.NotUploaedIDs = make([]string, 0, 100)
// 	for _, info := range req.Photos {
// 		t, err := time.Parse("2006:01:02 15:04:05", info.Date)
// 		if err != nil {
// 			continue
// 		}
// 		if !all[encodeName(t, info.Name)] {
// 			rsp.NotUploaedIDs = append(rsp.NotUploaedIDs, info.Id)
// 		}
// 	}
// 	return
// }
