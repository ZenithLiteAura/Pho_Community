# API PACKAGE KNOWLEDGE BASE

## OVERVIEW
Package `api` -- the gRPC+HTTP boundary of the Go backend. One `api` struct (`img.go:14`) embeds `pb.UnimplementedImgSyncerServer`, wraps an `*imgmanager.ImgManager`, and doubles as the HTTP handler. 14 gRPC RPCs split across 4 handler files (img core + 3 drive types) + 1 HTTP transport file. Tests are integration-only (Docker containers, testify/suite, sequential execution).

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Core RPCs: SetDirectoryType, ListByDate, Delete, FilterNotUploaded (bidir stream) | `img.go` | `SetDirectoryType` just forwards to `im.SetDirectoryType`; `ListByDate` defaults MaxReturn=100, Offset=0, calls `im.RangeByDate` with callback |
| HTTP dispatch, upload (3 variants), download (full + range) | `http.go` | `httpHandler()` dispatches GET/POST + path prefix; `downloadType` enum (Normal/Thumbnail/LiveVideo) resolved by prefix strip |
| Custom HTTP headers | `http.go:15-19` | `Image-Date`, `Image-Encrypt-Type` (`AES_128_CFB` / `AES_256_GCM` / empty→`None`), `Image-Encrypt-Password`, `Image-Is-Live-Photo` |
| File name encode/decode | `http.go:319-334` | `encodeName`: `"YYYYMMDDhhmmss_name"`; `decodeName` reverses. Used by `FilterNotUploaded` to match local vs remote |
| SMB drive wiring: SetDriveSMB, ListDriveSMBShares, ListDriveSMBDir, SetDriveSMBShare | `smb.go` | Type-asserts `a.im.Drive()` to `*smb.Smb` for share browsing |
| WebDAV drive wiring: SetDriveWebdav, ListDriveWebdavDir | `webdav.go` | Type-asserts to `*webdav.Webdav` |
| NFS drive wiring: SetDriveNFS, ListDriveNFSDir | `nfs.go` | Type-asserts to `*nfs.Nfs`, calls `cli.ReadDirPlus` |
| Test constants + SMB helpers | `util_test.go` | `grpcAddr`, `httpAddr`, `smbSrvAddr`, `pic1ShouldPath`; `initSmbShare`, `cleanSmb`, `initSmbDir`, `getNFSTarget`, `waitfile` (200ms polling, 5s timeout) |
| Integration tests (gRPC + HTTP) | `img_test.go`, `smb_test.go`, `webdav_test.go`, `nfs_test.go` | testify/suite; sequential (`-p 1 -failfast`); require Docker SMB/WebDAV/NFS containers |
| Embedded test JPEG fixture | `../test/static/static.go` | `//go:embed test_pic_01.jpg` → `var Pic1 []byte` |

## CONVENTIONS
- **Response envelope**: Every gRPC response carries `bool Success` + `string Message`. Handlers construct `&pb.XxxResponse{Success: true}` upfront, then set fields. On error: set `Success = false`, set `Message`, return `nil` error.
- **HTTP dispatch**: Single `http.HandlerFunc` in `httpHandler()` (`http.go:38`). Routes: GET → `httpDownload`, POST + `/thumbnail/` prefix → `httpUploadThumbnail`, POST + `/live/` prefix → `httpUploadLiveVideo`, POST + other → `httpUpload`. No third-party router.
- **Custom HTTP headers**: `Image-Date` (timestamp `"2006:01:02 15:04:05"`), `Image-Encrypt-Type` (`"AES_128_CFB"` or empty → `imgmanager.None`), `Image-Encrypt-Password`, `Image-Is-Live-Photo` (bool string parsed by `strconv.ParseBool`). Used by all upload and download handlers.
- **File naming**: `encodeName(time, name)` → `"YYYYMMDDhhmmss_name"`; `decodeName()` splits on index 14. `FilterNotUploaded` uses `encodeName` to match local photo names against the remote filesystem listing built by `RangeByDate`.

- **Drive setup pattern**: Each `SetDrive*` handler (smb/webdav/nfs) constructs the drive via its package constructor, calls `a.im.SetDrive(d)`, then applies optional config (share, root, tmp dir). No factory or registry. Only one active drive.
- **Drive type-assertion**: `ListDrive*Dir` and `ListDriveSMBShares` handlers call `a.im.Drive()`, type-assert to the concrete struct (e.g. `dri.(*smb.Smb)`), then call driver-specific methods. The `StorageDrive` interface has no `ListDir` or `ListShare` method.

- **Range downloads (http.go:188-286)**: Thumbnails reject Range with `400 Bad Request`. Normal and live video parse `Range: bytes=start-end`, call `GetOffset`/`GetLiveVideoOffset`, respond `206 Partial Content` with `Content-Range` header. Handles both `bytes=start-` and `bytes=start-end` forms. GCM-encrypted files support Range; CFB-encrypted files reject offset>0.
- **Test execution**: All tests (`img_test.go`, `smb_test.go`, `webdav_test.go`, `nfs_test.go`) are in `package api_test` (black-box) and use testify/suite. Require Docker containers from `test/docker-compose.yml`. Run sequentially: `go test -v ./server/api/ -p 1 -failfast`.

## ANTI-PATTERNS
- **No unit tests**: Everything is integration. No mock `StorageDrive` or `ImgManager`. Must have Docker running.
- **`goto` in test helpers**: `util_test.go` `cleanSmb` and `waitfile` use `goto` + labels (`Retry`, `CONTINUE`) for retry logic instead of `for` loops.
- **Polling-based assertions**: `waitfile` polls HTTP GET every 200ms with a timeout (default 5s). Flaky under load; no exponential backoff.
- **Dead assignment**: `waitfile` line 142 -- `rsp := string(data)` followed by `rsp = rsp`.


- **`SetDriveSMB` silently swallows dial result**: Lines 23-25 check `err != nil` but the dial result `e` is only used in the error message. The nil-error branch should check `e` for connection failures.
- **`FilterNotUploaded` walks entire remote directory on every call**: `RangeByDate(time.Now(), ...)` with no early termination builds a full `map[string]bool` of all uploaded files before checking any client names. Scales poorly with large photo sets.
