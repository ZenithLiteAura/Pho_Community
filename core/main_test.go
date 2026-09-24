package main

import (
	"context"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"testing"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
)

type pingServer struct {
	pb.UnimplementedImgSyncerServer
}

func (m *pingServer) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingResponse, error) {
	return &pb.PingResponse{}, nil
}

// TestMainPortConflictFails 验证端口冲突时 net.Listen 返回 "address already in use" 错误。
func TestMainPortConflictFails(t *testing.T) {
	// 占用一个端口
	l1, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to listen on first port: %v", err)
	}
	defer l1.Close()

	addr := l1.Addr().String()

	// 尝试在同一端口上再次 Listen
	l2, err := net.Listen("tcp", addr)
	if err == nil {
		l2.Close()
		t.Fatal("expected error when listening on occupied port, got nil")
	}
	t.Logf("port conflict error (expected): %v", err)
}

// TestMainGracefulShutdown 验证优雅关闭模式：发送 SIGINT 后 HTTP 和 gRPC 服务停止接受新连接。
func TestMainGracefulShutdown(t *testing.T) {
	// 启动 gRPC server
	grpcLis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to listen for grpc: %v", err)
	}
	grpcAddr := grpcLis.Addr().String()

	grpcServer := grpc.NewServer()
	pb.RegisterImgSyncerServer(grpcServer, &pingServer{})
	go grpcServer.Serve(grpcLis)

	// 启动 HTTP server
	httpLis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("failed to listen for http: %v", err)
	}
	httpAddr := httpLis.Addr().String()

	httpServer := &http.Server{Handler: http.NotFoundHandler()}
	go httpServer.Serve(httpLis)

	// 确认服务正常响应
	httpResp, err := http.Get("http://" + httpAddr + "/")
	if err != nil {
		t.Fatalf("http server not reachable: %v", err)
	}
	httpResp.Body.Close()

	// gRPC Ping 确认服务正常
	conn, err := grpc.Dial(grpcAddr, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		t.Fatalf("failed to dial grpc: %v", err)
	}
	client := pb.NewImgSyncerClient(conn)
	_, err = client.Ping(context.Background(), &pb.PingRequest{})
	if err != nil {
		t.Fatalf("ping failed before shutdown: %v", err)
	}

	// 发送 SIGINT 触发优雅关闭
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT)
	go func() {
		syscall.Kill(syscall.Getpid(), syscall.SIGINT)
	}()
	<-quit
	signal.Stop(quit)

	// 执行关闭
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	grpcServer.GracefulStop()
	httpServer.Shutdown(ctx)

	// 等待关闭完成
	time.Sleep(200 * time.Millisecond)

	// 验证 HTTP 不再接受新连接
	_, err = http.Get("http://" + httpAddr + "/")
	if err == nil {
		t.Error("http server should not accept connections after shutdown")
	}
	t.Logf("http after shutdown error (expected): %v", err)

	// 验证 gRPC 返回 Unavailable
	_, err = client.Ping(context.Background(), &pb.PingRequest{})
	if err == nil {
		t.Error("grpc Ping should fail after shutdown")
	} else {
		st, ok := status.FromError(err)
		if ok {
			t.Logf("grpc status after shutdown: %v (code=%v)", err, st.Code())
			if st.Code() != codes.Unavailable {
				t.Errorf("expected Unavailable, got %v", st.Code())
			}
		} else {
			t.Logf("grpc after shutdown error: %v", err)
		}
	}

	conn.Close()
}
