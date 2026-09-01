# server/ — Go Backend Knowledge Base

**Module:** github.com/fregie/img_syncer (Go 1.25)
**Generated:** 2026-07-13
**Updated:** 2026-07-24 (Go 1.25, 15 RPCs, GCM encryption)

## OVERVIEW
Go gRPC backend implementing ImgSyncerServer (15 RPCs) with a companion HTTP file handler, orchestrating upload/download/thumbnail generation across 3 storage backends.

## STRUCTURE
```
server/
├── main.go            # Standalone entry: flags grpcAddr :50051, httpAddr :8000, -d (pprof :6060), -version
├── log.go             # Package-level loggers: Info(stdout), Error(stderr+Lshortfile), Debug(ioutil.Discard unless -d)
├── api/               # gRPC service impl + HTTP handler (11 files)
│   ├── img.go         # api struct embeds pb.UnimplementedImgSyncerServer; core RPCs + FilterNotUploaded bidir stream
│   ├── http.go        # net/http single-handler mux by method+path; custom Image-* headers; encodeName/decodeName
│   ├── {smb,webdav,nfs}.go  # Per-drive config/setup/login RPCs
│   └── *_test.go      # testify/suite integration tests
├── imgmanager/        # Core orchestrator (4 files)
│   ├── imgmanager.go  # ImgManager: StorageDrive holder, Workiva action queue, worker pool (default 2)
│   ├── interface.go   # StorageDrive interface (Upload/Download/DownloadWithOffset/Delete/Range), Image struct, UnimplementedDrive
│   ├── encrypt.go     # AES-128-CFB streaming (cfbReader), kdf via iterative MD5, .aes suffix
│   └── metadata.go    # EXIF via go-exif/v3 (Model, Datetime, CreateDate, DateTimeOriginal, ModifyDate)
├── drive/             # 3 StorageDrive impls (smb/webdav/nfs) + drive_test.go integration test
├── run/run.go         # Embedded entry for gomobile: auto-port scan 10000-20000, returns "grpcPort,httpPort"
├── clib/clib.go       # CGo //export RunGrpcServer wrapping run.RunGrpcServer for c-shared .so/.dll builds
└── util/util.go       # IsVideo(ext) 16 formats, ContentTypeByExtension MIME map with fallback
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add a gRPC RPC | `proto/img_syncer.proto` → `make protobuf` → impl in `server/api/` | api embeds pb.UnimplementedImgSyncerServer |
| Add an HTTP endpoint | `server/api/http.go` `httpHandler()` | Dispatch by method + path prefix; no router lib |
| Add a storage backend | `server/drive/<name>/` impl StorageDrive + `server/api/<name>.go` | Construct directly, call im.SetDrive(d) |
| Change upload logic | `server/imgmanager/imgmanager.go` `Upload()` | Worker queue handles async thumbnail generation |
| Change file path format | `server/imgmanager/imgmanager.go` `genPath()` | Builds {year}/{month}/{day}/{timestamp}_{name}[.aes] |
| Add encryption scheme | `server/imgmanager/encrypt.go` | Wrap readers via EncryptedReaderWraper/DecryptedReaderWraper |
| Change sync filtering | `server/api/img.go` `FilterNotUploaded()` | Bidir stream; walks remote via RangeByDate |
| Add MIME type mapping | `server/util/util.go` `ContentTypeByExtension` | mime.TypeByExtension primary, defaultMimeMap fallback |

## CONVENTIONS
- **Dual-entry wiring**: Both main.go and run/run.go wire `api.NewApi(imgManager)` + `pb.RegisterImgSyncerServer` identically.
- **HTTP routing**: Single `http.HandlerFunc` in api/http.go. Dispatch by `r.Method` (GET/POST) and `strings.HasPrefix(r.URL.Path, ...)`. No gin/echo/chi. Custom headers: `Image-Date`, `Image-Encrypt-Type`, `Image-Encrypt-Password`, `Image-Is-Live-Photo`.
- **Logging**: Custom `log.Logger` instances (Info/Error/Debug). Debug → `ioutil.Discard` unless `-d` enables pprof on :6060 (standalone only). run/run.go duplicates its own logger init(). No slog/logrus/zap.
- **Worker pattern**: ImgManager holds a `Workiva/go-datastructures` queue. Uploads enqueue actions; worker goroutines (default 2) process thumbnail generation and upload asynchronously.
- **Drive hot-swap**: Single `StorageDrive` field (`dri`) on ImgManager. `SetDrive()` replaces it. Default is `UnimplementedDrive` (returns "no available drive").
- **Name encoding**: `encodeName(time, name)` produces `"20060102030405_name"`. `decodeName` reverses it. Used in FilterNotUploaded and HTTP upload handlers.
- **Encryption**: Dual-scheme — AES-128-CFB (legacy) + AES-256-GCM (`PHO1` magic header). GCM supports `GetOffset()` for HTTP Range / video streaming; CFB does not. Encryption type detected from magic header in `encrypt.go`.
- **Testing**: testify/suite; requires Docker containers (SMB/WebDAV/NFS) via `make test`.
- **Build modes**: `CGO_ENABLED=0` for gomobile binds (run/run.go imports `golang.org/x/mobile/bind`). `CGO_ENABLED=1` for c-shared .so/.dll (clib/clib.go uses `//export RunGrpcServer`).
- **Forked deps**: `go.mod` has replace directives for `fregie/gowebdav` and `fregie/go-nfs-client`.

## ANTI-PATTERNS
- `goto` used for retry loops in `server/api/util_test.go`, `server/drive/drive_test.go`.
- NFS drive uses AUTH_UNIX root (uid 0): no real authentication.
- WebDAV drive uses `InsecureSkipVerify: true` (TLS verification disabled).

- Encrypted `.aes` files with CFB scheme reject range download: `GetOffset()` returns error. GCM scheme (PHO1 header) supports it. Video streaming works with GCM encryption only.
- Windows c-shared build requires manual `sed`/`dlltool` post-processing (documented in `build.md`).
- CI test/lint/analyze steps have `continue-on-error: true` (non-blocking).
