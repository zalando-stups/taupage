package main

import (
        "fmt"
        "net/http"
        "os/exec"
        "io/ioutil"
        "math/rand"
        "encoding/json"
)

type Response struct {
        Version string `json:"dockerVersion,omitempty"`
        Success string `json:"success"`
        Output  string `json:"output"`
}

func check(e error) {
        if e != nil {
                panic(e)
        }
}

func buildRandomImage() (*map[string]string, error) {
        fmt.Println("Creating random file..")
        size := 32
        rb := make([]byte, size)
        _, err := rand.Read(rb)
        check(err)
        err = ioutil.WriteFile("./resources/random", rb, 0644)
        check(err)
        out, err := exec.Command("docker", "build", "--no-cache", "./resources").Output()
        result := make(map[string]string)
        result["output"] = string(out)
        return &result, err
}

func checkDockerVersion() (*map[string]string, error) {
        out, err := exec.Command("docker", "-v").Output()
        result := make(map[string]string)
        if err != nil {
                result["output"] = string(out)
                return &result, err
        }
        result["version"] = string(out)
        return &result, nil
}

func handler(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        fmt.Printf("Handling %s request for %s from %s..\n", r.Method, r.URL, r.RemoteAddr)
        dockerVersionResult, err := checkDockerVersion()
        if err != nil {
                response := &Response{Success:"false", Output:(*dockerVersionResult)["output"]}
                json, err := json.Marshal(response)
                check(err)
                w.WriteHeader(http.StatusNotFound)
                w.Write(json)
                return
        }
        fmt.Println("Using docker client", (*dockerVersionResult)["version"])
        imgCreationResult, err := buildRandomImage()
        if err != nil {
                response := &Response{Success:"false", Output:(*imgCreationResult)["output"]}
                json, err := json.Marshal(response)
                check(err)
                w.WriteHeader(http.StatusNotFound)
                w.Write(json)
                return
        }
        response := &Response{
                Success:"true",
                Output:(*imgCreationResult)["output"],
                Version:(*dockerVersionResult)["version"]}
        json, err := json.Marshal(response)
        check(err)
        w.Write(json)
}

func main() {
        http.HandleFunc("/", handler)
        fmt.Println("Listening on port 8080..")
        http.ListenAndServe(":8080", nil)
}

