// Command gohelper is the Go side of the cross-language session tests. It is
// built against the jennah-sdk-go tree that verify just tested (see run.sh), so
// the Go half of every test is the code being released.
//
//	gohelper call <endpoint>        one authenticated call, resolving the stored session
//	gohelper write <n>              rewrite the stored session n times
//	gohelper read <seconds>         load the stored session repeatedly, report partial reads
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	jennah "github.com/alphauslabs/jennah-sdk-go"
	"github.com/alphauslabs/jennah-sdk-go/credentials"
)

func main() {
	if len(os.Args) < 3 {
		fail("usage: gohelper call <endpoint> | write <n> | read <seconds>")
	}
	switch os.Args[1] {
	case "call":
		call(os.Args[2])
	case "write":
		n, _ := strconv.Atoi(os.Args[2])
		write(n)
	case "read":
		secs, _ := strconv.ParseFloat(os.Args[2], 64)
		read(time.Duration(secs * float64(time.Second)))
	default:
		fail("unknown command " + os.Args[1])
	}
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}

func call(endpoint string) {
	jc, err := jennah.NewClient(jennah.Config{Endpoint: endpoint, Insecure: true})
	if err != nil {
		fail("construct: " + err.Error())
	}
	defer jc.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if _, err := jc.List(ctx, jennah.ListInput{}); err != nil {
		fail("call: " + err.Error())
	}
	fmt.Println("ok")
}

// Token spells a writer's n-th session. The run of x's is n%37 long, so a reader
// can tell a whole token from a torn one without knowing what was written.
func token(lang string, n int) string {
	return fmt.Sprintf("%s_%d_%s", lang, n, strings.Repeat("x", n%37))
}

var tokenShape = regexp.MustCompile(`^(go|py)_(\d+)_(x*)$`)

func wholeToken(t string) bool {
	m := tokenShape.FindStringSubmatch(t)
	if m == nil {
		return false
	}
	n, _ := strconv.Atoi(m[2])
	return len(m[3]) == n%37
}

func write(n int) {
	for i := range n {
		if err := credentials.Save(&credentials.Session{
			Endpoint: "https://jennah.alphaus.cloud", AccessToken: token("go", i),
			RefreshToken: "rt", TokenType: "Bearer",
		}); err != nil {
			fail("save: " + err.Error())
		}
	}
	fmt.Println("ok")
}

func read(d time.Duration) {
	var reads, partial int
	for end := time.Now().Add(d); time.Now().Before(end); {
		s, err := credentials.Load()
		if errors.Is(err, credentials.ErrNoSession) {
			continue
		}
		reads++
		if err != nil || !wholeToken(s.AccessToken) {
			partial++
		}
	}
	fmt.Printf("%d %d\n", reads, partial)
}
