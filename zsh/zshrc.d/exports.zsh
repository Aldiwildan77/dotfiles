# Golang
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"
export PATH=$PATH:/usr/local/go/bin

## Skip protobuf conflict namespace
export GOLANG_PROTOBUF_REGISTRATION_CONFLICT=warn
