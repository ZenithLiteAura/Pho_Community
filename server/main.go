package main

import (
	"context"
	"flag"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"net/http"
	_ "net/http/pprof"

	version "github.com/fregie/PrintVersion"
	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/api"
	"github.com/fregie/img_syncer/server/imgmanager"
	"google.golang.org/grpc"
	"google.golang.org/grpc/reflection"
)

var (
	grpcAddr    = flag.String("grpcAddr", "0.0.0.0:50051", "grpc addr example: 0.0.0.0:50051")
	httpAddr    = flag.String("httpAddr", "0.0.0.0:8000", "http addr example: 0.0.0.0:8000")
	showVersion = flag.Bool("version", false, "Displays version and exit.")
	debug       = flag.Bool("d", false, "debug mode")
)

var (
	imgManager *imgmanager.ImgManager
)

func main() {
	flag.Parse()
	if *showVersion {
		version.PrintVersion()
		return
	}
	if *debug {
		Debug.SetOutput(os.Stdout)
		Debug.Printf("pprof listen at 0.0.0.0:6060")
		go func() {
			if err := http.ListenAndServe("0.0.0.0:6060", nil); err != nil {
				Error.Fatalf("pprof server: %v", err)
			}
		}()
	}
	imgManager = imgmanager.NewImgManager(imgmanager.Option{})

	lis, err := net.Listen("tcp", *grpcAddr)
	if err != nil {
		Error.Fatalf("failed to listen: %v", err)
	}

	apiServer := api.NewApi(imgManager)
	httpServer := &http.Server{
		Addr:    *httpAddr,
		Handler: apiServer.HttpHandler(),
	}
	Info.Printf("Listening http on %s", *httpAddr)
	go func() {
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			Error.Fatalf("http server: %v", err)
		}
	}()

	grpcServer := grpc.NewServer()
	pb.RegisterImgSyncerServer(grpcServer, apiServer)
	reflection.Register(grpcServer)
	Info.Printf("Listening grpc on %s", lis.Addr().String())

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		Error.Fatal(grpcServer.Serve(lis))
	}()
	<-quit
	Info.Printf("Shutting down...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	grpcServer.GracefulStop()
	if err := httpServer.Shutdown(ctx); err != nil {
		Error.Printf("http server shutdown error: %v", err)
	}
}
