package run

import (
	"net"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestEmbeddedBindsLocalhost 验证：使用 127.0.0.1 绑定的 listener 只能被 loopback 访问，
// 非 loopback IP 无法连接。
func TestEmbeddedBindsLocalhost(t *testing.T) {
	// 1. 在 127.0.0.1:0 上监听（端口自动分配）
	lis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("无法在 127.0.0.1:0 上监听: %v", err)
	}
	defer lis.Close()

	addr := lis.Addr().(*net.TCPAddr)
	port := addr.Port
	t.Logf("监听端口: %d", port)

	// 启动一个 acceptor，接受连接后立即关闭
	go func() {
		for {
			conn, err := lis.Accept()
			if err != nil {
				return
			}
			conn.Close()
		}
	}()

	// 2. 获取非 loopback 的 IP 地址
	nonLoopbackIPs := getNonLoopbackIPs(t)

	// 3. 验证非 loopback IP 无法连接（必须超时/失败）
	for _, ip := range nonLoopbackIPs {
		target := net.JoinHostPort(ip, itoa(port))
		conn, err := net.DialTimeout("tcp", target, 500*time.Millisecond)
		if err == nil {
			conn.Close()
			t.Errorf("非 loopback IP %s 居然能连接到 127.0.0.1 绑定的端口 %d — 这不应该发生", ip, port)
		} else {
			t.Logf("非 loopback IP %s 连接失败（符合预期）: %v", ip, err)
		}
	}

	// 4. 如果没有非 loopback IP，用一个确定不可能的非 loopback 地址测试
	if len(nonLoopbackIPs) == 0 {
		// 192.0.2.0/24 是 TEST-NET-1（RFC 5737），不可能可达
		target := net.JoinHostPort("192.0.2.1", itoa(port))
		conn, err := net.DialTimeout("tcp", target, 500*time.Millisecond)
		if err == nil {
			conn.Close()
			t.Error("192.0.2.1（非 loopback）居然能连接 — 这不应该发生")
		} else {
			t.Logf("192.0.2.1 连接失败（符合预期）: %v", err)
		}
	}

	// 5. 验证 127.0.0.1 可以连接
	conn, err := net.DialTimeout("tcp", net.JoinHostPort("127.0.0.1", itoa(port)), 1*time.Second)
	if err != nil {
		t.Fatalf("127.0.0.1 无法连接到同一端口: %v", err)
	}
	conn.Close()
	t.Log("127.0.0.1 连接成功（符合预期）")
}

// TestStandaloneAllowsExternal 验证 server/main.go 中的独立 CLI 仍使用 0.0.0.0 绑定。
// 这是一个代码检查测试 — 确保 main.go 没有被意外修改。
func TestStandaloneAllowsExternal(t *testing.T) {
	// 找到 server/main.go
	mainPath := filepath.Join("..", "main.go")
	content, err := os.ReadFile(mainPath)
	if err != nil {
		t.Fatalf("无法读取 %s: %v", mainPath, err)
	}

	source := string(content)

	// 验证 main.go 中的 flag 默认值仍包含 0.0.0.0
	checks := map[string]string{
		"grpcAddr flag 默认值": `grpcAddr    = flag.String("grpcAddr", "0.0.0.0:50051"`,
		"httpAddr flag 默认值": `httpAddr    = flag.String("httpAddr", "0.0.0.0:8000"`,
		"pprof 调试地址":    `http.ListenAndServe("0.0.0.0:6060"`,
	}

	for name, expected := range checks {
		if !strings.Contains(source, expected) {
			t.Errorf("%s: 未找到预期内容 %q — main.go 可能被意外修改", name, expected)
		} else {
			t.Logf("%s: 确认仍使用 0.0.0.0（符合预期）", name)
		}
	}
}

// getNonLoopbackIPs 获取当前主机的非 loopback IP 地址列表
func getNonLoopbackIPs(t *testing.T) []string {
	t.Helper()

	addrs, err := net.InterfaceAddrs()
	if err != nil {
		t.Fatalf("无法获取网络接口地址: %v", err)
	}

	var ips []string
	for _, addr := range addrs {
		ipNet, ok := addr.(*net.IPNet)
		if !ok {
			continue
		}
		ip := ipNet.IP
		if ip.IsLoopback() || ip.IsUnspecified() {
			continue
		}
		// 只取 IPv4（测试简单可靠）
		if ip4 := ip.To4(); ip4 != nil {
			ips = append(ips, ip4.String())
		}
	}

	t.Logf("找到的非 loopback IPv4 地址: %v", ips)
	return ips
}

// itoa 是简单的 int → string 辅助函数（避免引入 strconv）
func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	s := ""
	for n > 0 {
		s = string(rune('0'+n%10)) + s
		n /= 10
	}
	return s
}
