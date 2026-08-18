package main

import (
    "bufio"
    "fmt"
    "io"
    "log"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "sync"
)

type allowDB struct {
    mu sync.RWMutex
    files map[string]bool
}

func loadAllow(path string) (*allowDB, error) {
    f, err := os.Open(path)
    if err != nil { return nil, err }
    defer f.Close()
    db := &allowDB{files: map[string]bool{}}
    s := bufio.NewScanner(f)
    for s.Scan() { if v := strings.TrimSpace(s.Text()); v != "" { db.files[v] = true } }
    return db, s.Err()
}

func main() {
    root := getenv("REPO_ROOT", "./repo")
    listen := getenv("LISTEN", ":8081")
    release := getenv("ALPINE_RELEASE", "3.24")
    arch := getenv("ARCH", "x86_64")
    allow, err := loadAllow(filepath.Join(root, arch, "packages.list"))
    if err != nil { log.Fatal(err) }
    client := &http.Client{Timeout: 0}
    upstream := []string{
        "https://dl-cdn.alpinelinux.org/alpine/v"+release+"/main/"+arch+"/",
        "https://dl-cdn.alpinelinux.org/alpine/v"+release+"/community/"+arch+"/",
        "https://dl-cdn.alpinelinux.org/alpine/edge/testing/"+arch+"/",
    }
    http.HandleFunc("/v"+release+"/"+arch+"/", func(w http.ResponseWriter, r *http.Request) {
        name := filepath.Base(r.URL.Path)
        if name == "APKINDEX.tar.gz" || name == "packages.list" || name == "requirements.txt" {
            http.ServeFile(w, r, filepath.Join(root, arch, name)); return
        }
        allow.mu.RLock(); ok := allow.files[name]; allow.mu.RUnlock()
        if !ok || !strings.HasSuffix(name, ".apk") { http.NotFound(w, r); return }
        for _, base := range upstream {
            resp, err := client.Get(base + name)
            if err != nil { continue }
            if resp.StatusCode == http.StatusOK {
                defer resp.Body.Close()
                for k, vals := range resp.Header { for _, v := range vals { w.Header().Add(k, v) } }
                w.WriteHeader(http.StatusOK)
                _, _ = io.Copy(w, resp.Body)
                return
            }
            resp.Body.Close()
        }
        http.Error(w, fmt.Sprintf("approved APK not found upstream: %s", name), http.StatusBadGateway)
    })
    log.Printf("ArozOS APK gateway listening on %s", listen)
    log.Fatal(http.ListenAndServe(listen, nil))
}

func getenv(k, d string) string { if v := os.Getenv(k); v != "" { return v }; return d }
