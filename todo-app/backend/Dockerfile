# Start from the official Golang 1.23 image
FROM golang:1.23.3-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy the source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o todo-backend

# Start a new stage from scratch
FROM alpine:latest  

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the pre-built binary file from the previous stage
COPY --from=builder /app/todo-backend .

# Expose port 8080
EXPOSE 8080

# Command to run the executable
CMD ["./todo-backend"]