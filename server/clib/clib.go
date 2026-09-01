package main

import "C"
import (
	"strconv"
	"strings"

	"github.com/fregie/img_syncer/server/run"
)

//export RunGrpcServer
func RunGrpcServer() (int, int) {
	ports, err := run.RunGrpcServer()
	if err != nil {
		return -1, -1
	}
	re := strings.Split(ports, ",")
	if len(re) != 2 {
		return -1, -1
	}
	grpcPort, err := strconv.Atoi(re[0])
	if err != nil {
		return -1, -1
	}
	httpPort, err := strconv.Atoi(re[1])
	if err != nil {
		return -1, -1
	}
	return grpcPort, httpPort
}

func main() {}
