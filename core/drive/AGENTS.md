# DRIVE BACKENDS

## OVERVIEW
Three `StorageDrive` implementations (SMB, WebDAV, NFS) that read/write photos to remote filesystems. Each drive is constructed directly in `server/api/` handlers and injected via `im.SetDrive(d)`. Only one drive is active at a time.

## STRUCTURE
```
server/drive/
├── smb/smb.go           # go-smb2, NTLM auth, lazy connect with 5min TTL
├── webdav/webdav.go     # gowebdav fork, Basic Auth, InsecureSkipVerify
├── nfs/nfs.go           # go-nfs-client fork, AUTH_UNIX root, 2min idle reconnect

└── drive_test.go        # testify/suite, Docker-based integration tests
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add a new storage backend | Create `server/drive/<name>/<name>.go` + constructor in `server/api/<name>.go` | Must implement `StorageDrive` (see `server/imgmanager/interface.go`) |
| Debug SMB connection issues | `smb/smb.go:56 checkConn()` | 5min TTL, `downloadLock` serializes all downloads |
| Debug WebDAV auth/protocol | `webdav/webdav.go:34 SetTransport()` | TLS verification disabled, `mkdirLock` serializes MkdirAll |
| Debug NFS reconnection | `nfs/nfs.go:68 checkConn()` | Full remount on expiry (expensive), FSInfo() health probe |
| Add/change tests | `drive_test.go` `DriveTest` suite | `TestSMB()`/`TestWebdav()`/`TestNFS()` share `testDrive()` helper, needs Docker |
| Wire a new drive into the API | `server/api/<name>.go` | Construct drive, type-assert for extras (ListShare, Cli, SetRootPath), call `im.SetDrive(d)` |

## CONVENTIONS

- **No registry/factory**: each drive is constructed directly with a `New*` function. The `server/api/` handler holds the constructor call.
- **Hot-swap**: only ONE `StorageDrive` active at a time. `ImgManager.SetDrive()` replaces it.
- **Connection management**: SMB and NFS use lazy connect with TTL timestamps (5min/2min) via `checkConn()`; WebDAV is stateless HTTP.
- **Range direction**: all `Range()` methods sort `fs.FileInfo` descending by `ModTime()` (newest first).
- **Extra methods**: each drive exposes capabilities beyond the `StorageDrive` interface (e.g. `ListShare()` on SMB, `Cli()` on WebDAV/NFS). Handlers use type-assertion to access them.
- **Path handling**: SMB uses `filepath.Join` natively; WebDAV and NFS normalize to `/`-separated with trailing slash on root.
- **Thumbnails**: not drive-level concern. Thumbnail paths are built by `ImgManager` using the same directory structure under `.thumbnail/`.

## ANTI-PATTERNS

- **NFS: AUTH_UNIX root (uid 0, gid 0)**. No real authentication. Acceptable for local network only.
- **WebDAV: `InsecureSkipVerify: true`**. TLS certificate verification is globally disabled. Do NOT use over untrusted networks.
- **SMB: `downloadLock` mutex**. All downloads (including `Download` which delegates to `DownloadWithOffset`) are serialized. Parallel downloads WILL contend.
- **NFS: custom non-recursive `MkdirAll`**. The `MkdirAll()` method iterates path segments and calls `Mkdir` individually; errors are silently ignored (`continue`). This differs from standard library behavior.
