# IMGMANAGER -- CORE ENGINE

## OVERVIEW
`ImgManager` is the central orchestrator: it owns the active `StorageDrive`, routes all I/O through it, handles encryption/decryption transparently, and runs a worker queue for async delete operations. The remote filesystem IS the database -- `RangeByDate()` walks date-based directory trees directly.

## STRUCTURE
```
imgmanager/
├── imgmanager.go   # ImgManager struct, upload/download/delete, RangeByDate, genPath, worker queue
├── interface.go    # StorageDrive interface, Image struct, UnimplementedDrive (null-object), suffix constants
├── encrypt.go      # Dual-scheme: AES-128-CFB (legacy) + AES-256-GCM (PHO1 magic header), custom MD5-based KDF, .aes path suffix
└── metadata.go     # EXIF extraction via go-exif/v3, ImageMetadata struct embedded in Image
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Change file path layout | `imgmanager.go:188` `genPath()` | Single function controls YYYY/MM/DD vs YYYYMMDD, live_ prefix, .aes suffix |
| Add a storage backend | `server/drive/<name>/` impl `StorageDrive` (defined in `interface.go:10`) | 5 methods: Upload, Download, DownloadWithOffset, Delete, Range |
| Change upload flow | `imgmanager.go:215` `Upload()` | Encrypt if configured -> genPath -> dri.Upload |
| Change download flow | `imgmanager.go:291` `GetImg()` | dri.Download -> decrypt -> set ContentType |
| Streaming/offset reads | `imgmanager.go:320` `GetOffset()` | For video streaming; REJECTS encrypted paths |
| Directory listing ("file-as-DB") | `imgmanager.go:469` `RangeByDate()` | Walks both dir formats descending by date, no database |
| Encryption | `encrypt.go` | AES-128-CFB with random IV, `kdf()` key derivation, `cfbReader` streaming wrapper |
| Get current drive | `imgmanager.go:73` `Drive()` | Returns `StorageDrive` interface (callers type-assert to concrete drive for extended methods) |
| Worker queue | `imgmanager.go:92` `runWorker()` | Processes `actDelete` async; upload/thumbnail gen are commented out |

## CONVENTIONS
- **Single active drive**: `SetDrive(d)` hot-swaps. No multi-cloud. Before configured, `UnimplementedDrive` returns "no available drive" for all ops.
- **genPath centralization**: Every file operation routes path construction through `genPath(name, date, options)`. Two directory layouts: `YYYY/MM/DD/` (Type 01, default) or `YYYYMMDD/` (Type 02). Live Photos nested under `live_<name>/`. Encrypted files append `.aes`.
- **EncryptOption pattern**: `Options` struct + `OptionFunc` functional options (`WithEncrypt()`, `IsLivePhoto()`). Upload methods accept variadic `...OptionFunc`.
- **EncryptType enum**: `None | AES_128_CFB | AES_256_GCM`. GCM uses `PHO1` magic header; CFB uses random IV. GCM supports `GetOffset()` for HTTP Range / video streaming; CFB does not. Key derivation via iterative MD5 (not PBKDF2/Argon2). Encryption is transparent at the ImgManager layer -- callers just pass `WithEncrypt(...)`. Scheme auto-detected from file header on read.
- **Image struct**: Universal file handle combining `Content` (io.ReadCloser stream), `Path`, `Size`, `ContentType`, and embedded `ImageMetadata`. Returned by GetImg/GetThumbnail/GetOffset/GetLiveVideoOffset.
- **Thumbnail mirror**: `.thumbnail/` directory mirrors the source tree. `UploadThumbnail` prepends this prefix; `GetThumbnail` reads from it. Thumbnail gen code is commented out (was done client-side).
- **Worker queue**: 2 workers (`defaultWorkerNum`) started in `NewImgManager`. Currently only `actDelete` is active; `actUpload` and `actGenerateThumbnail` are commented out.
- **IsExist OUTSIDE interface**: `IsExist` is implemented on `UnimplementedDrive` and individual drives but is NOT in the `StorageDrive` interface (line 12 is commented out). Different drives define it as a private/unexported convention.

## ANTI-PATTERNS
- **Custom KDF**: `kdf()` uses iterative MD5 instead of PBKDF2, bcrypt, or Argon2. Weak against brute force.
- **Encrypted CFB files break streaming**: `GetOffset()` rejects CFB-encrypted paths (non-zero offset). GCM-encrypted files (PHO1 header) support streaming. Video streaming silently fails with CFB encryption.
- **IsExist not in interface**: Drives implement it privately, but there's no contract. Callers must type-assert to check existence -- fragile across drive implementations.
- **Worker count is fixed at construction**: No runtime tuning of `WorkerNum`. Commented-out upload/thumbnail workers can't be re-enabled without code changes.
- **RangeByDate walks entire tree every call**: No caching. Every invocation re-lists all year/month/day directories, descending to find photos before the given date.
