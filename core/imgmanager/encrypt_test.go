package imgmanager

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"fmt"
	"io"
	"testing"
)

func TestGcmEncryptDecryptRoundTrip(t *testing.T) {
	password := "test-password-123"
	plaintext := make([]byte, 2*1024*1024+500) // ~2MB+，跨多个 chunk
	for i := range plaintext {
		plaintext[i] = byte(i % 256)
	}

	// 加密
	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper failed: %v", err)
	}

	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted data: %v", err)
	}
	encReader.Close()

	// 验证 header
	if len(encrypted) < gcmHeaderLen {
		t.Fatalf("encrypted data too short: %d bytes", len(encrypted))
	}
	if string(encrypted[:gcmMagicLen]) != gcmMagic {
		t.Fatalf("magic mismatch: got %q", encrypted[:gcmMagicLen])
	}

	// 验证 EncryptedContentSize
	expectedSize := EncryptedContentSize(int64(len(plaintext)), AES_256_GCM)
	if int64(len(encrypted)) != expectedSize {
		t.Fatalf("EncryptedContentSize mismatch: got %d, want %d", len(encrypted), expectedSize)
	}

	// 解密
	decOpt := EncryptOption{Type: AES_256_GCM, Password: password}
	decReader, err := DecryptedReaderWraper(io.NopCloser(bytes.NewReader(encrypted)), decOpt)
	if err != nil {
		t.Fatalf("DecryptedReaderWraper failed: %v", err)
	}

	decrypted, err := io.ReadAll(decReader)
	if err != nil {
		t.Fatalf("read decrypted data: %v", err)
	}
	decReader.Close()

	if !bytes.Equal(decrypted, plaintext) {
		t.Fatalf("round-trip mismatch: decrypted %d bytes vs plaintext %d bytes", len(decrypted), len(plaintext))
	}

	// 验证 DecryptedContentSize
	decSize := DecryptedContentSize(int64(len(encrypted)), AES_256_GCM)
	if decSize != int64(len(plaintext)) {
		t.Fatalf("DecryptedContentSize mismatch: got %d, want %d", decSize, len(plaintext))
	}

	t.Logf("Round-trip success: %d bytes plain → %d bytes encrypted", len(plaintext), len(encrypted))
}

func TestLegacyCfbDecrypt(t *testing.T) {
	password := "legacy-pass"
	plaintext := []byte("Hello, legacy CFB encrypted world!")

	// 使用 legacy 代码加密
	key := legacyKDF(password, keyLen)
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatalf("aes cipher: %v", err)
	}
	encReader, err := legacyNewCfbEncrypter(io.NopCloser(bytes.NewReader(plaintext)), block)
	if err != nil {
		t.Fatalf("legacy encrypter: %v", err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	// CFB 前面应该有 IV
	if len(encrypted) != len(plaintext)+cfbIVLen {
		t.Fatalf("CFB encrypted size mismatch: got %d, want %d", len(encrypted), len(plaintext)+cfbIVLen)
	}

	// 用新 DecryptedReaderWraper 解密（自动检测 magic，fallback 到 CFB）
	decOpt := EncryptOption{Type: AES_128_CFB, Password: password}
	decReader, err := DecryptedReaderWraper(io.NopCloser(bytes.NewReader(encrypted)), decOpt)
	if err != nil {
		t.Fatalf("DecryptedReaderWraper (legacy): %v", err)
	}
	decrypted, err := io.ReadAll(decReader)
	if err != nil {
		t.Fatalf("read decrypted: %v", err)
	}
	decReader.Close()

	if !bytes.Equal(decrypted, plaintext) {
		t.Fatalf("legacy decrypt mismatch")
	}

	t.Logf("Legacy CFB decrypt success")
}

func TestWrongPassword(t *testing.T) {
	password := "correct-password"
	plaintext := []byte("secret data for password test")

	// 加密
	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	// 用错误密码解密
	wrongOpt := EncryptOption{Type: AES_256_GCM, Password: "wrong-password"}
	decReader, err := DecryptedReaderWraper(io.NopCloser(bytes.NewReader(encrypted)), wrongOpt)
	if err != nil {
		t.Fatalf("DecryptedReaderWraper creation should not fail: %v", err)
	}
	_, err = io.ReadAll(decReader)
	decReader.Close()
	if err == nil {
		t.Fatal("expected error with wrong password, got nil")
	}
	t.Logf("Wrong password correctly rejected: %v", err)
}

func TestMagicBytesDetection(t *testing.T) {
	password := "detect-pass"
	plaintext := []byte("magic detection test data")

	// 加密 GCM
	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}
	gcmEncrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read GCM encrypted: %v", err)
	}
	encReader.Close()

	// 验证 GCM 格式检测
	detectedType, _, err := DetectEncryptFormat(io.NopCloser(bytes.NewReader(gcmEncrypted)))
	if err != nil {
		t.Fatalf("DetectEncryptFormat GCM: %v", err)
	}
	if detectedType != AES_256_GCM {
		t.Fatalf("expected AES_256_GCM, got %v", detectedType)
	}

	// CFB 加密（legacy）
	key := legacyKDF(password, keyLen)
	block, _ := aes.NewCipher(key)
	cfbEncReader, _ := legacyNewCfbEncrypter(io.NopCloser(bytes.NewReader(plaintext)), block)
	cfbEncrypted, _ := io.ReadAll(cfbEncReader)
	cfbEncReader.Close()

	// 验证 CFB 格式检测（不以 PHO1 开头）
	detectedType, _, err = DetectEncryptFormat(io.NopCloser(bytes.NewReader(cfbEncrypted)))
	if err != nil {
		t.Fatalf("DetectEncryptFormat CFB: %v", err)
	}
	if detectedType != AES_128_CFB {
		t.Fatalf("expected AES_128_CFB, got %v", detectedType)
	}

	t.Logf("Magic bytes detection: GCM=%v, CFB=%v — both correct", AES_256_GCM, AES_128_CFB)
}

func TestStreamingGcm(t *testing.T) {
	// 测试 >1MB 流式数据，确保分块正确
	password := "stream-pass"

	// 生成 3.7MB 随机数据（跨 4 个 chunk）
	plaintext := make([]byte, 3*1024*1024+700*1024)
	if _, err := io.ReadFull(rand.Reader, plaintext); err != nil {
		t.Fatalf("generate random data: %v", err)
	}

	// 加密
	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}

	// 流式读取加密数据（模拟小 buffer）
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	// 验证头
	if string(encrypted[:gcmMagicLen]) != gcmMagic {
		t.Fatalf("magic mismatch")
	}

	// 验证 chunkSize 在 header 中
	chunkSize := binaryReadUint32(encrypted[gcmMagicLen+gcmSaltLen : gcmMagicLen+gcmSaltLen+4])
	if chunkSize != gcmChunkSize {
		t.Fatalf("chunkSize in header: got %d, want %d", chunkSize, gcmChunkSize)
	}

	// 解密（用 buffered reader 模拟小 buffer）
	decOpt := EncryptOption{Type: AES_256_GCM, Password: password}
	decReader, err := DecryptedReaderWraper(io.NopCloser(bytes.NewReader(encrypted)), decOpt)
	if err != nil {
		t.Fatalf("DecryptedReaderWraper: %v", err)
	}

	// 用小 buffer 读取解密数据，验证流式工作正常
	decrypted := make([]byte, 0, len(plaintext))
	buf := make([]byte, 100) // 小 buffer 模拟逐字节读取
	for {
		n, err := decReader.Read(buf)
		if n > 0 {
			decrypted = append(decrypted, buf[:n]...)
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("read decrypted (streaming): %v", err)
		}
	}
	decReader.Close()

	if !bytes.Equal(decrypted, plaintext) {
		t.Fatalf("streaming GCM mismatch: got %d bytes, want %d bytes", len(decrypted), len(plaintext))
	}

	t.Logf("Streaming GCM success: %d bytes with 100-byte buffer", len(plaintext))
}

func binaryReadUint32(b []byte) uint32 {
	return uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])
}

// =============================================================================
// Test helpers — 生成旧格式文件用于兼容性测试
// =============================================================================

// LegacyEncryptForTest 生成旧版 CFB 加密数据（仅测试使用）
func LegacyEncryptForTest(plaintext []byte, password string) ([]byte, error) {
	key := legacyKDF(password, keyLen)
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	// 随机 IV
	iv := make([]byte, block.BlockSize())
	if _, err := io.ReadFull(rand.Reader, iv); err != nil {
		return nil, err
	}
	stream := cipher.NewCFBEncrypter(block, iv)
	ciphertext := make([]byte, len(plaintext)+len(iv))
	copy(ciphertext, iv)
	stream.XORKeyStream(ciphertext[len(iv):], plaintext)
	return ciphertext, nil
}

// =============================================================================
// 加密策略验证 & pipe 错误传播
// =============================================================================

func TestEncryptNewFilesUseGCM(t *testing.T) {
	password := "gcm-test-pass"
	plaintext := []byte("new files must use GCM encryption")

	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper(GCM): %v", err)
	}

	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	if len(encrypted) == 0 {
		t.Fatal("encrypted data is empty")
	}
	if bytes.Equal(encrypted, plaintext) {
		t.Fatal("encrypted output equals plaintext — encryption did not transform data")
	}

	if len(encrypted) < 4 || string(encrypted[:4]) != gcmMagic {
		t.Fatalf("not a valid GCM stream: missing PHO1 magic")
	}

	t.Logf("GCM encrypt: %d bytes plain → %d bytes encrypted", len(plaintext), len(encrypted))
}

func TestEncryptRejectsCFB(t *testing.T) {
	plaintext := []byte("this should be rejected")

	opt := EncryptOption{Type: AES_128_CFB, Password: "test-pass"}
	_, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err == nil {
		t.Fatal("expected error when encrypting with deprecated CFB, got nil")
	}
	if err.Error() != "CFB encryption is deprecated, use GCM" {
		t.Fatalf("unexpected error message: %v", err)
	}
	t.Logf("CFB encryption correctly rejected: %v", err)
}

func TestDecryptStillHandlesLegacyCFB(t *testing.T) {
	password := "legacy-decrypt-pass"
	original := []byte("hello world test data for legacy CFB decrypt")

	key := legacyKDF(password, keyLen)
	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatalf("aes.NewCipher: %v", err)
	}
	encReader, err := legacyNewCfbEncrypter(io.NopCloser(bytes.NewReader(original)), block)
	if err != nil {
		t.Fatalf("legacyNewCfbEncrypter: %v", err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read CFB encrypted: %v", err)
	}
	encReader.Close()

	if len(encrypted) >= 4 && string(encrypted[:4]) == gcmMagic {
		t.Fatal("legacy CFB data unexpectedly starts with GCM magic")
	}

	decReader, err := DecryptedReaderWraper(
		io.NopCloser(bytes.NewReader(encrypted)),
		EncryptOption{Password: password, Type: AES_128_CFB},
	)
	if err != nil {
		t.Fatalf("DecryptedReaderWraper (legacy CFB): %v", err)
	}
	decrypted, err := io.ReadAll(decReader)
	if err != nil {
		t.Fatalf("read decrypted: %v", err)
	}
	decReader.Close()

	if !bytes.Equal(decrypted, original) {
		t.Fatalf("decrypted data mismatch: got %q, want %q", string(decrypted), string(original))
	}

	t.Logf("Legacy CFB decrypt success: %q", string(decrypted))
}

func TestGCMEncryptPropagatesPipeError(t *testing.T) {
	password := "pipe-err-pass"
	plaintext := []byte("data for pipe error propagation test")

	pr, err := EncryptedReaderWraper(
		io.NopCloser(bytes.NewReader(plaintext)),
		EncryptOption{Type: AES_256_GCM, Password: password},
	)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}

	pr.Close()

	buf := make([]byte, 64)
	_, err = pr.Read(buf)
	if err == nil || err == io.EOF {
		t.Fatalf("expected error from broken pipe propagation, got: %v (EOF=nil pipeErr=silent data loss)", err)
	}

	t.Logf("Pipe error correctly surfaced: %v", err)
}

func TestGCMEncryptNormalPath(t *testing.T) {
	password := "normal-gcm-pass"
	original := []byte("normal GCM encrypt-decrypt round trip works fine")

	// 加密
	encReader, err := EncryptedReaderWraper(
		io.NopCloser(bytes.NewReader(original)),
		EncryptOption{Type: AES_256_GCM, Password: password},
	)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	// 解密
	decReader, err := DecryptedReaderWraper(
		io.NopCloser(bytes.NewReader(encrypted)),
		EncryptOption{Password: password, Type: AES_256_GCM},
	)
	if err != nil {
		t.Fatalf("DecryptedReaderWraper: %v", err)
	}
	decrypted, err := io.ReadAll(decReader)
	if err != nil {
		t.Fatalf("read decrypted: %v", err)
	}
	decReader.Close()

	if !bytes.Equal(decrypted, original) {
		t.Fatalf("round-trip mismatch: got %q, want %q", string(decrypted), string(original))
	}

	t.Logf("GCM normal path success: %q → %d bytes encrypted → %q", string(original), len(encrypted), string(decrypted))
}

// =============================================================================
// GcmSeekReader 测试
// =============================================================================

// gcmSeekReaderCiphertextStart 计算从 plaintext 偏移 offset 开始解密所需的
// ciphertextStart(文件内字节偏移)、chunkIndex、withinChunk。公式必须与加密 writer 一致。
func gcmSeekReaderCiphertextStart(offset int64) (ciphertextStart, chunkIndex, withinChunk int64) {
	chunkIndex = offset / int64(gcmChunkSize)
	withinChunk = offset % int64(gcmChunkSize)
	ciphertextStart = gcmHeaderLen + chunkIndex*int64(gcmChunkSize+gcmNonceSize+gcmTagSize)
	return
}

func TestGcmSeekReader(t *testing.T) {
	password := "seek-pass-123"
	plaintext := make([]byte, 2*1024*1024+500*1024) // ~2.5MB，跨至少 3 个 chunk（块 0、1、2）
	for i := range plaintext {
		plaintext[i] = byte(i % 251)
	}

	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	// 从 header 读出 salt 与 chunkSize —— 生产调用方（ImgManager）会做同样的事
	salt := make([]byte, gcmSaltLen)
	copy(salt, encrypted[gcmMagicLen:gcmMagicLen+gcmSaltLen])
	headerChunkSize := binaryReadUint32(encrypted[gcmMagicLen+gcmSaltLen : gcmMagicLen+gcmSaltLen+4])
	if headerChunkSize != gcmChunkSize {
		t.Fatalf("header chunkSize %d != gcmChunkSize %d", headerChunkSize, gcmChunkSize)
	}
	totalStoredSize := int64(len(encrypted))

	offsets := []int64{0, 123, 1000000, 2400000}
	for _, offset := range offsets {
		offset := offset
		t.Run(fmt.Sprintf("offset_%d", offset), func(t *testing.T) {
			ciphertextStart, chunkIndex, withinChunk := gcmSeekReaderCiphertextStart(offset)

			// 模拟 drive.DownloadWithOffset(path, ciphertextStart)：reader 从目标 chunk nonce 起始读取
			startReader := bytes.NewReader(encrypted[ciphertextStart:])

			seekReader, err := NewGcmSeekReader(
				io.NopCloser(startReader),
				password,
				GcmSeekOpts{
					ChunkSize:         headerChunkSize,
					Salt:              salt,
					TotalStoredSize:   totalStoredSize,
					StartChunkIndex:   chunkIndex,
					WithinChunkOffset: withinChunk,
				},
			)
			if err != nil {
				t.Fatalf("NewGcmSeekReader offset=%d: %v", offset, err)
			}

			decrypted, err := io.ReadAll(seekReader)
			seekReader.Close()
			if err != nil {
				t.Fatalf("offset=%d io.ReadAll failed: %v", offset, err)
			}

			expected := plaintext[offset:]
			if !bytes.Equal(decrypted, expected) {
				t.Fatalf("offset=%d mismatch: got %d bytes, want %d bytes", offset, len(decrypted), len(expected))
			}
			t.Logf("offset=%d OK: %d bytes (chunkIndex=%d withinChunk=%d ciphertextStart=%d)",
				offset, len(decrypted), chunkIndex, withinChunk, ciphertextStart)
		})
	}
}

func TestGcmSeekReaderTruncatedFails(t *testing.T) {
	password := "seek-trunc-pass"
	plaintext := make([]byte, 2*1024*1024+500*1024)
	for i := range plaintext {
		plaintext[i] = byte(i % 251)
	}

	opt := EncryptOption{Type: AES_256_GCM, Password: password}
	encReader, err := EncryptedReaderWraper(io.NopCloser(bytes.NewReader(plaintext)), opt)
	if err != nil {
		t.Fatalf("EncryptedReaderWraper: %v", err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		t.Fatalf("read encrypted: %v", err)
	}
	encReader.Close()

	salt := make([]byte, gcmSaltLen)
	copy(salt, encrypted[gcmMagicLen:gcmMagicLen+gcmSaltLen])
	headerChunkSize := binaryReadUint32(encrypted[gcmMagicLen+gcmSaltLen : gcmMagicLen+gcmSaltLen+4])

	// 故意少报 1000B：末块 ciphertext 读取时 io.ReadFull 会 truncated
	const offset int64 = 0
	ciphertextStart, chunkIndex, withinChunk := gcmSeekReaderCiphertextStart(offset)
	liedTotalStoredSize := int64(len(encrypted)) - 1000

	seekReader, err := NewGcmSeekReader(
		io.NopCloser(bytes.NewReader(encrypted[ciphertextStart:])),
		password,
		GcmSeekOpts{
			ChunkSize:         headerChunkSize,
			Salt:              salt,
			TotalStoredSize:   liedTotalStoredSize,
			StartChunkIndex:   chunkIndex,
			WithinChunkOffset: withinChunk,
		},
	)
	if err != nil {
		t.Fatalf("NewGcmSeekReader creation should succeed, got: %v", err)
	}
	_, readErr := io.ReadAll(seekReader)
	seekReader.Close()
	if readErr == nil {
		t.Fatal("expected non-nil error from io.ReadAll when TotalStoredSize is wrong, got nil")
	}
	t.Logf("truncated read correctly failed: %v", readErr)
}
