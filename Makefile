BUILD_VERSION   := $(shell git describe --tags)
GIT_COMMIT_SHA1 := $(shell git rev-parse HEAD)
BUILD_TIME      := $(shell date "+%F %T")
BUILD_NAME      := img_syncer_server
VERSION_PACKAGE_NAME := github.com/fregie/PrintVersion

DESCRIBE := img_syncer grpc server

prebuild:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.27.1
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.1.0
	dart pub global activate protoc_plugin 21.1.2

protobuf:
	protoc -I. --go_out . --go_opt paths=source_relative \
		--go-grpc_out . --go-grpc_opt paths=source_relative \
		--dart_out=grpc:lib \
		proto/*.proto

.PHONY: server
server:
	CGO_ENABLED=0 go build -ldflags "\
		-X '${VERSION_PACKAGE_NAME}.Version=${BUILD_VERSION}' \
		-X '${VERSION_PACKAGE_NAME}.BuildTime=${BUILD_TIME}' \
		-X '${VERSION_PACKAGE_NAME}.GitCommitSHA1=${GIT_COMMIT_SHA1}' \
		-X '${VERSION_PACKAGE_NAME}.Describe=${DESCRIBE}' \
		-X '${VERSION_PACKAGE_NAME}.Name=${BUILD_NAME}' \
		" \
    -o core/output/${BUILD_NAME} ./core

server-aar: protobuf
	CGO_ENABLED=0 gomobile bind -target=android -androidapi 21 -ldflags "-s -w" -o android/app/libs/server.aar ./core/run

server-ios: protobuf
	CGO_ENABLED=0 gomobile bind -target=ios -ldflags "-s -w" -o ios/Frameworks/RUN.xcframework ./core/run

server-linux: protobuf
	CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build -o linux/lib/run.so -buildmode=c-shared ./core/clib

server-windows:
	# CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build -o windows/lib/run.lib -buildmode=c-shared ./core/clib
	go build -o windows/lib/run.dll -buildmode=c-shared ./core/clib
	sed -i '/#include <complex.h>/d' windows\lib\run.h
	sed -i '/typedef _Fcomplex GoComplex64;/d' windows\lib\run.h
	sed -i '/typedef _Dcomplex GoComplex128;/d' windows\lib\run.h
	dlltool -d windows/lib/run.def -l windows/lib/run.lib

server-macos: protobuf
	CGO_ENABLED=0 gomobile bind -target=macos -ldflags "-s -w" -o macos/Frameworks/RUN.xcframework ./core/run


apk:
	flutter build apk --release --obfuscate --split-debug-info=./debug-info

ipa:
	flutter build ipa --no-tree-shake-icons --obfuscate --split-debug-info=./debug-info

.PHONY: test
test:
	docker compose -f test/docker-compose.yml up -d --build --wait
	go test -v ./core/api -p 1 -failfast
	go test -v ./core/drive -p 1 -failfast
	docker compose -f test/docker-compose.yml down
	