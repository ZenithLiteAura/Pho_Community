# 构建阶段
FROM golang:1.25 AS builder
WORKDIR /src
COPY go.mod go.sum ./
COPY third_party/ ./third_party/
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /server ./server

# 运行阶段
FROM debian:stable-slim
RUN apt-get update && apt-get install -y ca-certificates && apt-get clean
COPY --from=builder /server /server
WORKDIR /
EXPOSE 50051 8000
CMD ["/server"]
