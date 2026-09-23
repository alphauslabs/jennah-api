// Its own module so jennah-api's `go build ./...` leaves it alone. run.sh
// replaces this file in a scratch copy with one that points at the SDK tree
// under test.
module crosslang/gohelper

go 1.26.4
