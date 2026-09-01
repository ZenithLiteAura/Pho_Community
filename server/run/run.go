package run

import (
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"

	"github.com/fregie/img_syncer/server/api"
	"github.com/fregie/img_syncer/server/imgmanager"
	_ "golang.org/x/mobile/bind"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"

	pb "github.com/fregie/img_syncer/proto"
)

var (
	imgManager  *imgmanager.ImgManager
	grpcServer  *grpc.Server
	grpcLis     net.Listener
	httpLis     net.Listener
)

func RunGrpcServer() (string, error) {
	imgManager = imgmanager.NewImgManager(imgmanager.Option{})
	var err error
	var grpcPort, httpPort int
	for start := 10000; start < 20000; start++ {
		grpcLis, err = net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", start))
		if err != nil {
			Info.Printf("Listen on %d failed, try next port", start)
			continue
		} else {
			grpcPort = start
			break
		}
	}
	if err != nil {
		Error.Printf("Listen on all port failed, err: %v", err)
		return "", err
	}

	for start := 10000; start < 20000; start++ {
		httpLis, err = net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", start))
		if err != nil {
			Info.Printf("Listen on %d failed, try next port", start)
			continue
		} else {
			httpPort = start
			break
		}
	}
	if err != nil {
		Error.Printf("Listen on all port failed, err: %v", err)
		return "", err
	}

	api := api.NewApi(imgManager)
	api.SetHttpPort(httpPort)
	grpcServer = grpc.NewServer()
	pb.RegisterImgSyncerServer(grpcServer, api)
	reflection.Register(grpcServer)

	Info.Printf("Listening grpc on %s", grpcLis.Addr().String())
	go grpcServer.Serve(grpcLis)
	Info.Printf("Listening http on %s", httpLis.Addr().String())
	go http.Serve(httpLis, api.HttpHandler())

	return fmt.Sprintf("%d,%d", grpcPort, httpPort), nil
}

func Shutdown() {
	if grpcServer != nil {
		grpcServer.GracefulStop()
	}
	if grpcLis != nil {
		grpcLis.Close()
	}
	if httpLis != nil {
		httpLis.Close()
	}
}

var (
	//Debug print debug informantion
	Debug *log.Logger
	//Info print Info informantion
	Info *log.Logger
	//Error print Error informantion
	Error *log.Logger
)

func init() {
	Info = log.New(os.Stdout, "[INFO] ", log.Ldate|log.Ltime)
	Error = log.New(os.Stderr, "[ERROR] ", log.Ldate|log.Ltime|log.Lshortfile)
	Debug = log.New(io.Discard, "[DEBUG] ", log.Ldate|log.Ltime|log.Lshortfile)
}
