// Package testutil provides shared test helper functions for integration tests.
package testutil

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/hirochachacha/go-smb2"
	"github.com/studio-b12/gowebdav"
	"github.com/vmware/go-nfs-client/nfs"
	"github.com/vmware/go-nfs-client/nfs/rpc"
)

const maxRetry = 3

// InitSmbShare dials the SMB server at addr, authenticates with user/pass,
// mounts the named share, and returns the mounted *smb2.Share.
func InitSmbShare(addr, user, pass, mountShare string) (*smb2.Share, error) {
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		return nil, err
	}
	d := &smb2.Dialer{
		Initiator: &smb2.NTLMInitiator{
			User:     user,
			Password: pass,
		},
	}
	s, err := d.Dial(conn)
	if err != nil {
		return nil, err
	}
	share, err := s.Mount(mountShare)
	if err != nil {
		return nil, err
	}
	return share, nil
}

// CleanSmb removes all files and directories at the SMB share root.
// Retries up to maxRetry times on removal failures.
func CleanSmb(share *smb2.Share) error {
	for retry := 0; retry <= maxRetry; {
		dirs, err := share.ReadDir(".")
		if err != nil {
			return err
		}
		ok := true
		for _, dir := range dirs {
			var rmErr error
			if dir.IsDir() {
				rmErr = share.RemoveAll(dir.Name())
			} else {
				rmErr = share.Remove(dir.Name())
			}
			if rmErr != nil {
				ok = false
				if retry >= maxRetry {
					fmt.Printf("remove %s error: %v\n", dir.Name(), rmErr)
				}
			}
		}
		if ok {
			return nil
		}
		retry++
		if retry > maxRetry {
			return nil
		}
		time.Sleep(300 * time.Microsecond)
	}
	return nil
}

// InitSmbDir creates the rootDir on the SMB share.
func InitSmbDir(share *smb2.Share, rootDir string) error {
	return share.Mkdir(rootDir, os.ModePerm)
}

// InitWebdav cleans all contents then creates rootPath on the WebDAV server.
func InitWebdav(url, user, pass, rootPath string) error {
	if err := CleanWebdav(url, user, pass); err != nil {
		return err
	}
	return InitWebdavDir(url, user, pass, rootPath)
}

// CleanWebdav removes all directories at the WebDAV server root.
func CleanWebdav(url, user, pass string) error {
	cli := gowebdav.NewClient(url, user, pass)
	dirs, err := cli.ReadDir("/")
	if err != nil {
		return err
	}
	for _, dir := range dirs {
		if err := cli.RemoveAll("/" + dir.Name() + "/"); err != nil {
			return err
		}
	}
	return nil
}

// InitWebdavDir creates rootPath on the WebDAV server.
func InitWebdavDir(url, user, pass, rootPath string) error {
	cli := gowebdav.NewClient(url, user, pass)
	return cli.Mkdir(rootPath, os.ModePerm)
}

// GetNFSTarget dials the NFS server at url (format: "host:/path"),
// mounts it, and returns the *nfs.Target.
func GetNFSTarget(url string) (*nfs.Target, error) {
	parts := strings.Split(url, ":")
	if len(parts) != 2 {
		return nil, fmt.Errorf("url format error")
	}
	host := parts[0]
	targetStr := parts[1]
	mount, err := nfs.DialMount(host)
	if err != nil {
		return nil, fmt.Errorf("failed to dial mount: %s", err)
	}
	auth := rpc.NewAuthUnix("root", 0, 0)
	target, err := mount.Mount(targetStr, auth.Auth())
	if err != nil {
		return nil, fmt.Errorf("failed to mount: %s", err)
	}
	return target, nil
}

// CleanNFS removes all directories at the NFS target root.
func CleanNFS(cli *nfs.Target) error {
	entries, err := cli.ReadDirPlus("/")
	if err != nil {
		return fmt.Errorf("failed to read dir: %s", err)
	}
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		if entry.Name() == "." || entry.Name() == ".." {
			continue
		}
		if err := cli.RemoveAll(filepath.Join("/", entry.Name())); err != nil {
			return fmt.Errorf("failed to remove dir: %s", err)
		}
	}
	return nil
}

// InitNFSDir creates rootPath on the NFS target.
func InitNFSDir(cli *nfs.Target, rootPath string) error {
	_, err := cli.Mkdir(rootPath, 0755)
	return err
}

// WaitFileHTTP polls the HTTP server at httpAddr for path until the file
// is available or timeout is reached. Uses a polling loop with no goto.
func WaitFileHTTP(httpAddr, path string, timeout time.Duration) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	if path[0] != '/' {
		path = "/" + path
	}
	url := fmt.Sprintf("http://%s%s", httpAddr, path)
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			resp, err := http.Get(url)
			if err != nil {
				time.Sleep(200 * time.Millisecond)
				continue
			}
			data, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil || resp.StatusCode != http.StatusOK {
				time.Sleep(200 * time.Millisecond)
				continue
			}
			_ = data
			return nil
		}
	}
}
