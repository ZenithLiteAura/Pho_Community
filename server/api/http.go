package api

import (
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/fregie/img_syncer/server/imgmanager"
)

const (
	rangeBufferSize       = 64 * 1024
	HeaderDate            = "Image-Date"
	HeaderEncryptType     = "Image-Encrypt-Type"
	HeaderEncryptPassword = "Image-Encrypt-Password"
	HeaderIsLivePhoto     = "Image-Is-Live-Photo"
	maxUploadSize         = 500 << 20 // 500MB
)

func getEncryptType(t string) imgmanager.EncryptType {
	switch t {
	case "AES_128_CFB":
		return imgmanager.AES_128_CFB
	case "AES_256_GCM":
		return imgmanager.AES_256_GCM
	}
	return imgmanager.None
}

func (a *api) SetHttpPort(port int) {
	a.httpPort = port
}

func (a *api) HttpHandler() http.Handler {
	return http.HandlerFunc(a.httpHandler)
}

func (a *api) httpHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		a.httpDownload(w, r)
	case http.MethodPost:
		if strings.HasPrefix(r.URL.Path, "/thumbnail/") {
			a.httpUploadThumbnail(w, r)
		} else if strings.HasPrefix(r.URL.Path, "/live/") {
			a.httpUploadLiveVideo(w, r)
		} else {
			a.httpUpload(w, r)
		}
	}
}

func (a *api) httpUpload(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	if path == "" {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	if r.ContentLength == 0 {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	date := r.Header.Get(HeaderDate)
	enctype := getEncryptType(r.Header.Get(HeaderEncryptType))
	encPassword := r.Header.Get(HeaderEncryptPassword)
	isLivePhotoStr := r.Header.Get(HeaderIsLivePhoto)
	isLivePhoto, err := strconv.ParseBool(isLivePhotoStr)
	if err != nil {
		isLivePhoto = false
	}
	length := r.ContentLength
	dateTime, err := time.Parse("2006:01:02 15:04:05", date)
	if err != nil {
		dateTime = time.Now()
	}
	name := strings.TrimPrefix(path, "/")
		name, err = sanitizePath(name)
		if err != nil {
			http.Error(w, "invalid path", http.StatusBadRequest)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
		err = a.im.Upload(r.Body, length, encodeName(dateTime, name), dateTime, imgmanager.WithEncrypt(imgmanager.EncryptOption{
		Type:     enctype,
		Password: encPassword,
	}), imgmanager.IsLivePhoto(isLivePhoto))

	if err != nil {
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) {
			w.WriteHeader(http.StatusRequestEntityTooLarge)
		} else {
			w.WriteHeader(http.StatusBadRequest)
		}
		w.Write([]byte(err.Error()))
		return
	}
	r.Body.Close()
	w.WriteHeader(http.StatusOK)
}

func (a *api) httpUploadThumbnail(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	if path == "" {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	if r.ContentLength == 0 {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	name := strings.TrimPrefix(path, "/thumbnail/")
		name, err := sanitizePath(name)
		if err != nil {
			http.Error(w, "invalid path", http.StatusBadRequest)
			return
		}
		date := r.Header.Get(HeaderDate)
	enctype := getEncryptType(r.Header.Get(HeaderEncryptType))
	encPassword := r.Header.Get(HeaderEncryptPassword)
	isLivePhotoStr := r.Header.Get(HeaderIsLivePhoto)
	isLivePhoto, err := strconv.ParseBool(isLivePhotoStr)
	if err != nil {
		isLivePhoto = false
	}
	length := r.ContentLength
	dateTime, err := time.Parse("2006:01:02 15:04:05", date)
	if err != nil {
		dateTime = time.Now()
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	err = a.im.UploadThumbnail(r.Body, length, encodeName(dateTime, name), dateTime, imgmanager.WithEncrypt(imgmanager.EncryptOption{
		Type:     enctype,
		Password: encPassword,
	}), imgmanager.IsLivePhoto(isLivePhoto))
	if err != nil {
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) {
			w.WriteHeader(http.StatusRequestEntityTooLarge)
		} else {
			w.WriteHeader(http.StatusBadRequest)
		}
		w.Write([]byte(err.Error()))
		return
	}
	r.Body.Close()
	w.WriteHeader(http.StatusOK)
}

func (a *api) httpUploadLiveVideo(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	if path == "" {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	if r.ContentLength == 0 {
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	name := strings.TrimPrefix(path, "/live/")
		name, err := sanitizePath(name)
		if err != nil {
			http.Error(w, "invalid path", http.StatusBadRequest)
			return
		}
		date := r.Header.Get(HeaderDate)
	enctype := getEncryptType(r.Header.Get(HeaderEncryptType))
	encPassword := r.Header.Get(HeaderEncryptPassword)
	length := r.ContentLength
	dateTime, err := time.Parse("2006:01:02 15:04:05", date)
	if err != nil {
		dateTime = time.Now()
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize)
	err = a.im.UploadLiveVideo(r.Body, length, encodeName(dateTime, name), dateTime, imgmanager.WithEncrypt(imgmanager.EncryptOption{
		Type:     enctype,
		Password: encPassword,
	}), imgmanager.IsLivePhoto(true))
	if err != nil {
		var maxBytesErr *http.MaxBytesError
		if errors.As(err, &maxBytesErr) {
			w.WriteHeader(http.StatusRequestEntityTooLarge)
		} else {
			w.WriteHeader(http.StatusBadRequest)
		}
		w.Write([]byte(err.Error()))
		return
	}
	r.Body.Close()
	w.WriteHeader(http.StatusOK)
}

type downloadType int

const (
	downloadTypeNormal downloadType = iota
	downloadTypeThumbnail
	downloadTypeLiveVideo
)

func (a *api) httpDownload(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	if path == "" {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	downloadType := downloadTypeNormal
	if strings.HasPrefix(path, "/thumbnail") {
		downloadType = downloadTypeThumbnail
		path = strings.TrimPrefix(path, "/thumbnail")
	} else if strings.HasPrefix(path, "/live") {
		downloadType = downloadTypeLiveVideo
		path = strings.TrimPrefix(path, "/live")
	}
	path = strings.TrimPrefix(path, "/")
		cleaned, err := sanitizePath(path)
		if err != nil {
			http.Error(w, "invalid path", http.StatusBadRequest)
			return
		}
		path = cleaned
		enctype := getEncryptType(r.Header.Get(HeaderEncryptType))
	encPassword := r.Header.Get(HeaderEncryptPassword)
	rangeHeader := r.Header.Get("Range")
	if rangeHeader != "" {
		rangeHeader = strings.TrimSpace(rangeHeader)
		kv := strings.Split(rangeHeader, "=")
		if len(kv) != 2 || kv[0] != "bytes" {
			http.Error(w, "bad range", http.StatusBadRequest)
			return
		}
		parts := strings.Split(kv[1], "-")
		if len(parts) == 0 {
			http.Error(w, "bad range", http.StatusBadRequest)
			return
		}
		if parts[0] == "" {
			http.Error(w, "suffix byte range not supported", http.StatusBadRequest)
			return
		}
		start, err := strconv.ParseInt(parts[0], 10, 64)
		if err != nil {
			http.Error(w, "bad range", http.StatusBadRequest)
			return
		}
		if start < 0 {
			http.Error(w, "invalid range start", http.StatusBadRequest)
			return
		}
		var img *imgmanager.Image
		switch downloadType {
		case downloadTypeNormal:
			img, err = a.im.GetOffset(path, start, imgmanager.WithEncrypt(imgmanager.EncryptOption{
				Type:     enctype,
				Password: encPassword,
			}))
		case downloadTypeLiveVideo:
			img, err = a.im.GetLiveVideoOffset(path, start, imgmanager.WithEncrypt(imgmanager.EncryptOption{
				Type:     enctype,
				Password: encPassword,
			}))
		case downloadTypeThumbnail:
			http.Error(w, "Not support Range", http.StatusBadRequest)
			return
		}
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		defer img.Content.Close()
		var readLen int64 = img.Size - start
		end := img.Size - 1
		if len(parts) > 1 && parts[1] != "" {
			end, err = strconv.ParseInt(parts[1], 10, 64) // 解析 end 部分
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			if end < 0 {
				http.Error(w, "invalid range end", http.StatusBadRequest)
				return
			}
			if end > img.Size-1 {
				end = img.Size - 1
			}
			readLen = end - start + 1
		}
		w.Header().Add("Content-Type", img.ContentType)
		w.Header().Add("Content-Length", strconv.FormatInt(readLen, 10))
		w.Header().Add("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, img.Size))
		// for k, v := range w.Header() {
		// 	log.Printf("Header: %s: %s", k, v)
		// }
		w.WriteHeader(http.StatusPartialContent)
		_, err = io.CopyBuffer(w, io.LimitReader(img.Content, readLen), make([]byte, rangeBufferSize))
		if err != nil {
			log.Printf("Error copying image content: %v", err)
			return
		}
		return
	}
	var img *imgmanager.Image
	switch downloadType {
	case downloadTypeNormal:
		img, err = a.im.GetImg(path, imgmanager.WithEncrypt(imgmanager.EncryptOption{
			Type:     enctype,
			Password: encPassword,
		}))
	case downloadTypeThumbnail:
		img, err = a.im.GetThumbnail(path, imgmanager.WithEncrypt(imgmanager.EncryptOption{
			Type:     enctype,
			Password: encPassword,
		}))
	case downloadTypeLiveVideo:
		img, err = a.im.GetLiveVideoOffset(path, 0, imgmanager.WithEncrypt(imgmanager.EncryptOption{
			Type:     enctype,
			Password: encPassword,
		}))
	}
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(err.Error()))
		return
	}
	defer img.Content.Close()
	w.Header().Add("Content-Length", strconv.FormatInt(img.Size, 10))
	w.Header().Add("Content-Type", img.ContentType)
	w.WriteHeader(http.StatusOK)
	_, err = io.Copy(w, img.Content)
	if err != nil {
		w.Write([]byte(err.Error()))
		return
	}
}

// func (a *api) httpDownloadThumbnail(w http.ResponseWriter, r *http.Request) {
// 	path := r.URL.Path
// 	if path == "" {
// 		w.WriteHeader(http.StatusNotFound)
// 		return
// 	}
// 	enctype := getEncryptType(r.Header.Get(HeaderEncryptType))
// 	encPassword := r.Header.Get(HeaderEncryptPassword)
// 	realPath := strings.TrimPrefix(path, "/thumbnail")
// 	img, err := a.im.GetThumbnail(realPath, imgmanager.WithEncrypt(imgmanager.EncryptOption{
// 		Type:     enctype,
// 		Password: encPassword,
// 	}))
// 	if err != nil {
// 		w.WriteHeader(http.StatusInternalServerError)
// 		w.Write([]byte(err.Error()))
// 		return
// 	}
// 	contentType := mime.TypeByExtension(filepath.Ext(realPath))
// 	defer img.Content.Close()
// 	w.Header().Add("Content-Length", strconv.FormatInt(img.Size, 10))
// 	w.Header().Add("Content-Type", contentType)
// 	w.WriteHeader(http.StatusOK)
// 	_, err = io.Copy(w, img.Content)
// 	if err != nil {
// 		w.Write([]byte(err.Error()))
// 		return
// 	}
// }

func encodeName(time time.Time, name string) string {
	return fmt.Sprintf("%s_%s", time.Format("20060102030405"), name)
}

func decodeName(encoded string) (time.Time, string, error) {
	if len(encoded) < 15 {
		return time.Time{}, "", fmt.Errorf("invalid encoded name")
	}
	timeStr := encoded[:14]
	name := encoded[15:]
	t, err := time.Parse("20060102030405", timeStr)
	if err != nil {
		return time.Time{}, "", err
	}
	return t, name, nil
}
