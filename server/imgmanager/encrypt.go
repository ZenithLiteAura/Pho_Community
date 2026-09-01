package imgmanager

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/md5"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"io"
	"path/filepath"

	"golang.org/x/crypto/pbkdf2"
)

// EncryptType 加密类型枚举
type EncryptType int

const (
	None EncryptType = iota
	AES_128_CFB
	AES_256_GCM
)

const (
	// GCM 新格式常量
	gcmMagic     = "PHO1"
	gcmMagicLen  = 4
	gcmSaltLen   = 16
	gcmChunkSize = 1024 * 1024 // 1MB 分块
	gcmKeyLen    = 32          // AES-256
	gcmNonceSize = 12
	gcmTagSize   = 16
	gcmHeaderLen = gcmMagicLen + gcmSaltLen + 4 // magic + salt + chunkSize(uint32)

	// CFB 旧格式常量
	cfbIVLen = 16
	keyLen   = 16 // legacy AES-128 key length
	bufSize  = 32 * 1024

	// PBKDF2 迭代次数
	pbkdf2Iter = 100000
)

// fixPath 根据加密类型追加文件后缀
func fixPath(path string, encType EncryptType) string {
	switch encType {
	case None:
		return path
	case AES_128_CFB, AES_256_GCM:
		return path + ".aes"
	}
	return path
}

// getPathEncType 从文件路径判断加密类型。
// .aes 后缀统一返回 AES_128_CFB 作为"已加密"标记，
// 实际解密方式由 DecryptedReaderWraper 根据 magic bytes 自动检测。
func getPathEncType(path string) EncryptType {
	ext := filepath.Ext(path)
	switch ext {
	case ".aes":
		return AES_128_CFB
	}
	return None
}

// encryptedSizeDelta 根据格式计算加密开销（存储大小 - 明文大小）。
// storedSize 为已加密存储的总大小（包含所有头部和 IV/nonce/tag）。
func gcmSizeDelta(storedSize int64) int64 {
	if storedSize <= gcmHeaderLen {
		return storedSize
	}
	dataSize := storedSize - gcmHeaderLen
	chunkOverhead := int64(gcmNonceSize + gcmTagSize)
	chunkTotal := int64(gcmChunkSize) + chunkOverhead
	numChunks := dataSize / chunkTotal
	if dataSize%chunkTotal > 0 {
		numChunks++
	}
	return gcmHeaderLen + numChunks*chunkOverhead
}

// cfbSizeDelta CFB 格式加密开销 = IV 长度 16 字节
func cfbSizeDelta() int64 {
	return cfbIVLen
}

// EncryptedReaderWraper 对 reader 进行加密包装。
// AES_256_GCM: 使用 io.Pipe 桥接，在 goroutine 中加密写入 pipe。
func EncryptedReaderWraper(reader io.ReadCloser, opt EncryptOption) (io.ReadCloser, error) {
	if opt.Password == "" && opt.Type != None {
		return nil, fmt.Errorf("password is empty")
	}

	// CFB 加密已弃用，仅在运行时拒绝加密（解密仍支持旧格式）
	if opt.Type == AES_128_CFB {
		return nil, fmt.Errorf("CFB encryption is deprecated, use GCM")
	}

	switch opt.Type {
	case None:
		return reader, nil
	case AES_128_CFB:
		key := legacyKDF(opt.Password, keyLen)
		block, err := aes.NewCipher(key)
		if err != nil {
			return nil, err
		}
		return legacyNewCfbEncrypter(reader, block)
	case AES_256_GCM:
		pr, pw := io.Pipe()
		go func() {
			var pipeErr error
			defer func() {
				reader.Close()
				pw.CloseWithError(pipeErr)
			}()

			// 生成随机 salt
			salt := make([]byte, gcmSaltLen)
			if _, err := io.ReadFull(rand.Reader, salt); err != nil {
				pipeErr = fmt.Errorf("generate salt: %w", err)
				return
			}

			// PBKDF2 派生密钥
			key := pbkdf2.Key([]byte(opt.Password), salt, pbkdf2Iter, gcmKeyLen, sha256.New)
			block, err := aes.NewCipher(key)
			if err != nil {
				pipeErr = fmt.Errorf("aes cipher: %w", err)
				return
			}
			gcm, err := cipher.NewGCM(block)
			if err != nil {
				pipeErr = fmt.Errorf("gcm: %w", err)
				return
			}

			// 写入 header: magic + salt + chunkSize
			header := make([]byte, gcmHeaderLen)
			copy(header[0:gcmMagicLen], []byte(gcmMagic))
			copy(header[gcmMagicLen:gcmMagicLen+gcmSaltLen], salt)
			binary.BigEndian.PutUint32(header[gcmMagicLen+gcmSaltLen:], gcmChunkSize)
			if _, err := pw.Write(header); err != nil {
				pipeErr = fmt.Errorf("write header: %w", err)
				return
			}

			// 分块加密
			buf := make([]byte, gcmChunkSize)
			for {
				n, readErr := io.ReadFull(reader, buf)
				if readErr != nil && readErr != io.ErrUnexpectedEOF && readErr != io.EOF {
					pipeErr = readErr
					return
				}
				if n == 0 {
					break
				}

				nonce := make([]byte, gcmNonceSize)
				if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
					pipeErr = fmt.Errorf("generate nonce: %w", err)
					return
				}

				encrypted := gcm.Seal(nil, nonce, buf[:n], nil)
				// 写入 nonce + ciphertext+tag
				if _, err := pw.Write(nonce); err != nil {
					pipeErr = fmt.Errorf("write nonce: %w", err)
					return
				}
				if _, err := pw.Write(encrypted); err != nil {
					pipeErr = fmt.Errorf("write encrypted: %w", err)
					return
				}

				if readErr == io.EOF || readErr == io.ErrUnexpectedEOF {
					break
				}
			}
		}()
		return pr, nil
	}
	return reader, nil
}

// DecryptedReaderWraper 对 reader 进行解密包装。
// 自动检测 PHO1 magic bytes 区分新旧格式（GCM vs CFB）。
// opt.Type 被忽略，由实际流内容决定解密方式。
func DecryptedReaderWraper(reader io.ReadCloser, opt EncryptOption) (io.ReadCloser, error) {
	if opt.Password == "" {
		return reader, nil
	}

	// Peek 前 4 字节检测 magic
	magic := make([]byte, gcmMagicLen)
	n, err := io.ReadFull(reader, magic)
	if err != nil {
		reader.Close()
		return nil, fmt.Errorf("failed to read magic bytes: %w", err)
	}

	if n == gcmMagicLen && string(magic) == gcmMagic {
		// GCM 新格式
		rc := &restoreReadCloser{prefix: magic, reader: reader}
		return newChunkedGcmReader(rc, opt.Password)
	}

	// CFB 旧格式: peek 到的字节是 IV 的前缀，放回流中
	rc := &restoreReadCloser{prefix: magic[:n], reader: reader}
	key := legacyKDF(opt.Password, keyLen)
	block, err := aes.NewCipher(key)
	if err != nil {
		rc.Close()
		return nil, err
	}
	return legacyNewCfbDecrypter(rc, block)
}

// =============================================================================
// 分块 GCM 解密读取器
// =============================================================================

// chunkedGcmReader 实现分块 AES-256-GCM 解密读取。
type chunkedGcmReader struct {
	reader    io.ReadCloser
	salt      []byte
	chunkSize uint32
	gcm       cipher.AEAD
	buf       []byte // 当前块的解密明文
	bufIdx    int
	eof       bool
}

func newChunkedGcmReader(reader io.ReadCloser, password string) (*chunkedGcmReader, error) {
	r := &chunkedGcmReader{reader: reader}

	// 读取完整 header: magic(4) + salt(16) + chunkSize(4)
	header := make([]byte, gcmHeaderLen)
	if _, err := io.ReadFull(reader, header); err != nil {
		reader.Close()
		return nil, fmt.Errorf("failed to read GCM header: %w", err)
	}

	if string(header[0:gcmMagicLen]) != gcmMagic {
		reader.Close()
		return nil, fmt.Errorf("invalid GCM magic bytes")
	}

	r.salt = make([]byte, gcmSaltLen)
	copy(r.salt, header[gcmMagicLen:gcmMagicLen+gcmSaltLen])
	r.chunkSize = binary.BigEndian.Uint32(header[gcmMagicLen+gcmSaltLen:])

	// PBKDF2 派生密钥
	key := pbkdf2.Key([]byte(password), r.salt, pbkdf2Iter, gcmKeyLen, sha256.New)
	block, err := aes.NewCipher(key)
	if err != nil {
		reader.Close()
		return nil, err
	}
	r.gcm, err = cipher.NewGCM(block)
	if err != nil {
		reader.Close()
		return nil, err
	}

	return r, nil
}

func (r *chunkedGcmReader) Read(p []byte) (n int, err error) {
	if r.bufIdx < len(r.buf) {
		n = copy(p, r.buf[r.bufIdx:])
		r.bufIdx += n
		return n, nil
	}

	if r.eof {
		return 0, io.EOF
	}

	// 读取下一块: nonce(12) + ciphertext+tag(chunkSize+tagSize)
	nonce := make([]byte, gcmNonceSize)
	if _, err := io.ReadFull(r.reader, nonce); err != nil {
		if err == io.EOF || err == io.ErrUnexpectedEOF {
			r.eof = true
			return 0, io.EOF
		}
		return 0, fmt.Errorf("read nonce: %w", err)
	}

	encryptedBuf := make([]byte, int(r.chunkSize)+gcmTagSize)
	encN, err := io.ReadFull(r.reader, encryptedBuf)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return 0, fmt.Errorf("read encrypted chunk: %w", err)
	}

	if err == io.EOF || err == io.ErrUnexpectedEOF {
		r.eof = true
	}

	// GCM 解密
	plaintext, aerr := r.gcm.Open(nil, nonce, encryptedBuf[:encN], nil)
	if aerr != nil {
		return 0, fmt.Errorf("gcm decrypt: %w (wrong password or corrupted data)", aerr)
	}

	r.buf = plaintext
	r.bufIdx = 0

	n = copy(p, r.buf)
	r.bufIdx = n
	return n, nil
}

func (r *chunkedGcmReader) Close() error {
	return r.reader.Close()
}

// =============================================================================
// 分块 GCM 反向 seek 解密读取器
// =============================================================================

// GcmSeekOpts 配置 GCM seek reader 的起始位置。
// 调用方负责从文件 header 读出 chunkSize 和 salt，并算好从哪一块开始、块内偏移。
type GcmSeekOpts struct {
	ChunkSize         uint32 // 从文件 header 读出的分块大小（通常为 1MB）
	Salt              []byte // 从文件 header 读出的盐（16 字节）
	TotalStoredSize   int64  // 完整 .aes 文件的密文总字节数（含 header）
	StartChunkIndex   int64  // 从哪块开始（已由调用方算好）
	WithinChunkOffset int64  // 块内的明文起始偏移（仅首块有效）
}

// gcmSeekReader 实现分块 AES-256-GCM 反向 seek 解密。
// 传入的 reader 已通过 drive.DownloadWithOffset 跳到目标 chunk ciphertext 起始（24B header 之后），
// 因此本 reader 不处理 header，直接从第一块 nonce 开始读。
type gcmSeekReader struct {
	reader            io.ReadCloser
	gcm               cipher.AEAD
	chunkSize         uint32
	salt              []byte
	totalStoredSize   int64
	startChunkIndex   int64
	withinChunkOffset int64
	chunksCompleted   int64
	buf               []byte // 当前块的解密明文
	bufIdx            int
	eof               bool
}

// NewGcmSeekReader 创建一个分块 GCM 反向 seek 解密 reader。
// 调用方传入的 reader 已通过 drive.DownloadWithOffset(path, ciphertextStart) 跳到目标 chunk ciphertext
// 起始（24B header 之后），seek reader 不再处理 header。
// chunkSize must come from the file header; the constant in DecryptedContentSize only matches today's writer.
func NewGcmSeekReader(reader io.ReadCloser, password string, opts GcmSeekOpts) (io.ReadCloser, error) {
	if len(opts.Salt) != gcmSaltLen {
		return nil, fmt.Errorf("invalid salt length: got %d, want %d", len(opts.Salt), gcmSaltLen)
	}
	if opts.ChunkSize == 0 {
		return nil, fmt.Errorf("chunkSize must not be zero")
	}

	r := &gcmSeekReader{
		reader:            reader,
		chunkSize:         opts.ChunkSize,
		salt:              append([]byte(nil), opts.Salt...),
		totalStoredSize:   opts.TotalStoredSize,
		startChunkIndex:   opts.StartChunkIndex,
		withinChunkOffset: opts.WithinChunkOffset,
	}

	// PBKDF2 派生密钥（与 newChunkedGcmReader 一致）
	key := pbkdf2.Key([]byte(password), r.salt, pbkdf2Iter, gcmKeyLen, sha256.New)
	block, err := aes.NewCipher(key)
	if err != nil {
		reader.Close()
		return nil, fmt.Errorf("aes cipher: %w", err)
	}
	r.gcm, err = cipher.NewGCM(block)
	if err != nil {
		reader.Close()
		return nil, fmt.Errorf("gcm: %w", err)
	}
	return r, nil
}

// Read 实现分块解密。先消耗当前 buffer，再读下一块 nonce+ciphertext+tag 解密填充 buffer。
func (r *gcmSeekReader) Read(p []byte) (n int, err error) {
	if r.bufIdx < len(r.buf) {
		n = copy(p, r.buf[r.bufIdx:])
		r.bufIdx += n
		return n, nil
	}

	if r.eof {
		return 0, io.EOF
	}

	// 计算总块数
	chunkOverhead := int64(gcmNonceSize + gcmTagSize)
	chunkTotal := int64(r.chunkSize) + chunkOverhead
	dataSize := r.totalStoredSize - gcmHeaderLen
	if dataSize < 0 {
		return 0, fmt.Errorf("invalid totalStoredSize: %d < headerLen", r.totalStoredSize)
	}
	totalChunks := dataSize / chunkTotal
	if dataSize%chunkTotal > 0 {
		totalChunks++
	}

	curChunk := r.startChunkIndex + r.chunksCompleted
	// 读取 nonce（12B）
	nonce := make([]byte, gcmNonceSize)
	if _, err := io.ReadFull(r.reader, nonce); err != nil {
		if err == io.EOF || err == io.ErrUnexpectedEOF {
			r.eof = true
			return 0, io.EOF
		}
		return 0, fmt.Errorf("read nonce: %w", err)
	}

	// 计算本块 ciphertext+tag 长度（不含 nonce）
	isLast := curChunk == totalChunks-1
	var cipherWithTagLen int64
	if isLast {
		blockTotalInStorage := dataSize - curChunk*chunkTotal
		cipherWithTagLen = blockTotalInStorage - gcmNonceSize
	} else {
		cipherWithTagLen = int64(r.chunkSize) + gcmTagSize
	}
	if cipherWithTagLen <= 0 || cipherWithTagLen > int64(r.chunkSize)+gcmTagSize {
		return 0, fmt.Errorf("invalid cipherWithTagLen %d for chunk %d", cipherWithTagLen, curChunk)
	}

	// 读取 ciphertext+tag
	cipherBuf := make([]byte, cipherWithTagLen)
	if _, err := io.ReadFull(r.reader, cipherBuf); err != nil {
		if err == io.ErrUnexpectedEOF || err == io.EOF {
			// 末块数据不足：被截断
			return 0, fmt.Errorf("read encrypted chunk %d: %w (truncated data)", curChunk, err)
		}
		return 0, fmt.Errorf("read encrypted chunk %d: %w", curChunk, err)
	}

	// GCM 解密
	plaintext, aerr := r.gcm.Open(nil, nonce, cipherBuf, nil)
	if aerr != nil {
		return 0, fmt.Errorf("gcm decrypt chunk %d: %w", curChunk, aerr)
	}

	r.buf = plaintext
	// 首块：丢弃 WithinChunkOffset 字节，从目标明文偏移开始
	if r.chunksCompleted == 0 && r.withinChunkOffset > 0 {
		if int(r.withinChunkOffset) > len(r.buf) {
			return 0, fmt.Errorf("withinChunkOffset %d exceeds chunk plaintext %d", r.withinChunkOffset, len(r.buf))
		}
		r.bufIdx = int(r.withinChunkOffset)
	} else {
		r.bufIdx = 0
	}
	r.chunksCompleted++

	n = copy(p, r.buf[r.bufIdx:])
	r.bufIdx += n
	return n, nil
}

func (r *gcmSeekReader) Close() error {
	return r.reader.Close()
}

// =============================================================================
// restoreReadCloser 将 peek 的字节放回流开头
// =============================================================================

type restoreReadCloser struct {
	prefix []byte
	reader io.ReadCloser
	idx    int
}

func (r *restoreReadCloser) Read(p []byte) (int, error) {
	if r.idx < len(r.prefix) {
		n := copy(p, r.prefix[r.idx:])
		r.idx += n
		return n, nil
	}
	return r.reader.Read(p)
}

func (r *restoreReadCloser) Close() error {
	return r.reader.Close()
}

// =============================================================================
// Legacy 代码：AES-128-CFB + 迭代 MD5 KDF（保留以兼容旧文件）
// =============================================================================

// legacyKDF 迭代 MD5 密钥派生（旧版，已弃用，仅用于解密旧格式文件）
func legacyKDF(password string, keyLen int) []byte {
	var b, prev []byte
	h := md5.New()
	for len(b) < keyLen {
		h.Write(prev)
		h.Write([]byte(password))
		b = h.Sum(b)
		prev = b[len(b)-h.Size():]
		h.Reset()
	}
	return b[:keyLen]
}

// legacyCfbReader CFB 流式加解密读取器（旧版保留）
type legacyCfbReader struct {
	reader io.ReadCloser
	stream cipher.Stream
	toRead []byte
	iv     []byte
}

func legacyNewCfbEncrypter(reader io.ReadCloser, block cipher.Block) (*legacyCfbReader, error) {
	r := &legacyCfbReader{
		reader: reader,
	}
	r.iv = make([]byte, block.BlockSize())
	if _, err := io.ReadFull(rand.Reader, r.iv); err != nil {
		return nil, err
	}
	r.toRead = make([]byte, len(r.iv))
	copy(r.toRead, r.iv)
	r.stream = cipher.NewCFBEncrypter(block, r.iv)
	return r, nil
}

func legacyNewCfbDecrypter(reader io.ReadCloser, block cipher.Block) (*legacyCfbReader, error) {
	r := &legacyCfbReader{
		reader: reader,
	}
	r.iv = make([]byte, block.BlockSize())
	if _, err := io.ReadFull(r.reader, r.iv); err != nil {
		return nil, err
	}
	r.stream = cipher.NewCFBDecrypter(block, r.iv)
	return r, nil
}

func (r *legacyCfbReader) Read(p []byte) (n int, err error) {
	if len(r.toRead) > 0 {
		n = copy(p, r.toRead)
		r.toRead = r.toRead[n:]
		return n, nil
	}
	n, err = r.reader.Read(p)
	if err != nil {
		if n > 0 {
			r.stream.XORKeyStream(p[:n], p[:n])
			return n, err
		}
		return 0, err
	}
	r.stream.XORKeyStream(p[:n], p[:n])
	return n, nil
}

func (r *legacyCfbReader) Close() error {
	return r.reader.Close()
}

// 保留旧函数名作为别名，确保向后兼容
// (这些函数在 encrypt.go 内部不再使用，但保留以防外部引用)

// NewCfbEncrypter 旧版 CFB 加密器（保留兼容）
func NewCfbEncrypter(reader io.ReadCloser, block cipher.Block) (*legacyCfbReader, error) {
	return legacyNewCfbEncrypter(reader, block)
}

// NewCfbDecrypter 旧版 CFB 解密器（保留兼容）
func NewCfbDecrypter(reader io.ReadCloser, block cipher.Block) (*legacyCfbReader, error) {
	return legacyNewCfbDecrypter(reader, block)
}

// =============================================================================
// 格式检测和尺寸计算
// =============================================================================

// DetectEncryptFormat 从流中 peek magic bytes 检测加密格式。
// 返回检测到的类型和恢复了 magic bytes 的 reader。
// 如果 reader 未以 PHO1 开头，视作旧 CFB 格式。
func DetectEncryptFormat(reader io.ReadCloser) (EncryptType, io.ReadCloser, error) {
	magic := make([]byte, gcmMagicLen)
	n, err := io.ReadFull(reader, magic)
	if err != nil {
		reader.Close()
		return None, nil, fmt.Errorf("failed to read magic bytes: %w", err)
	}
	rc := &restoreReadCloser{prefix: magic[:n], reader: reader}
	if n == gcmMagicLen && string(magic) == gcmMagic {
		return AES_256_GCM, rc, nil
	}
	return AES_128_CFB, rc, nil
}

// EncryptedContentSize 给定明文大小和加密类型，返回加密后的存储大小。
func EncryptedContentSize(plainSize int64, encType EncryptType) int64 {
	switch encType {
	case AES_128_CFB:
		return plainSize + cfbIVLen
	case AES_256_GCM:
		numChunks := (plainSize + int64(gcmChunkSize) - 1) / int64(gcmChunkSize)
		return plainSize + gcmHeaderLen + numChunks*int64(gcmNonceSize+gcmTagSize)
	}
	return plainSize
}

// DecryptedContentSize 给定加密后的存储大小和加密类型，返回明文大小。
func DecryptedContentSize(encryptedSize int64, encType EncryptType) int64 {
	switch encType {
	case AES_128_CFB:
		return encryptedSize - cfbIVLen
	case AES_256_GCM:
		overhead := int64(gcmHeaderLen)
		dataSize := encryptedSize - int64(gcmHeaderLen)
		chunkTotal := int64(gcmChunkSize + gcmNonceSize + gcmTagSize)
		numChunks := dataSize / chunkTotal
		if dataSize%chunkTotal > 0 {
			numChunks++
		}
		overhead += numChunks * int64(gcmNonceSize+gcmTagSize)
		return encryptedSize - overhead
	}
	return encryptedSize
}

// 确保未使用的 import 被使用
var _ = bytes.NewReader
