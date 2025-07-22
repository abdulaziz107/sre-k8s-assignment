package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

type HealthResponse struct {
	Status    string `json:"status"`
	Service   string `json:"service"`
	Timestamp int64  `json:"timestamp"`
}

type Post struct {
	ID      int    `json:"id"`
	Title   string `json:"title"`
	Content string `json:"content"`
}

// Internal service URLs (Kubernetes DNS)
var authServiceURL = "http://auth-service.auth.svc.cluster.local:3001"
var imageServiceURL = "http://image-storage-service.image-storage.svc.cluster.local:3003"

func proxyToService(w http.ResponseWriter, r *http.Request, baseURL, path string) {
	url := fmt.Sprintf("%s%s", baseURL, path)
	body, _ := ioutil.ReadAll(r.Body)
	defer r.Body.Close()

	req, err := http.NewRequest(r.Method, url, bytes.NewReader(body))
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"error":"Failed to create request"}`))
		return
	}
	// Copy headers
	for k, v := range r.Header {
		req.Header[k] = v
	}
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		w.WriteHeader(http.StatusBadGateway)
		w.Write([]byte(`{"error":"Service unavailable"}`))
		return
	}
	defer resp.Body.Close()
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3002"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		response := map[string]interface{}{
			"message": "API Service is running",
			"version": "1.0.0",
			"endpoints": []string{
				"/health",
				"/api/posts",
				"/register",
				"/login",
				"/verify",
				"/upload",
				"/images",
				"/images/{filename}",
				"/stats",
			},
		}
		json.NewEncoder(w).Encode(response)
	})

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		response := HealthResponse{
			Status:    "healthy",
			Service:   "api-service",
			Timestamp: time.Now().Unix(),
		}
		json.NewEncoder(w).Encode(response)
	})

	http.HandleFunc("/api/posts", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		posts := []Post{
			{ID: 1, Title: "First Post", Content: "This is the first post"},
			{ID: 2, Title: "Second Post", Content: "This is the second post"},
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"posts": posts})
	})

	http.HandleFunc("/api/posts/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		id := r.URL.Path[len("/api/posts/") : ]
		post := Post{
			ID:      1,
			Title:   fmt.Sprintf("Post %s", id),
			Content: fmt.Sprintf("This is post number %s", id),
		}
		json.NewEncoder(w).Encode(post)
	})

	// Proxy /register, /login, /verify to auth service
	http.HandleFunc("/register", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, authServiceURL, "/register")
	})

	http.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, authServiceURL, "/login")
	})

	http.HandleFunc("/verify", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, authServiceURL, "/verify")
	})

	// Proxy /upload to image-storage-service
	http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, imageServiceURL, "/api/upload")
	})

	// Proxy /images (GET) to image-storage-service
	http.HandleFunc("/images", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, imageServiceURL, "/api/images")
	})

	// Proxy /images/{filename} (GET, DELETE) to image-storage-service
	http.HandleFunc("/images/", func(w http.ResponseWriter, r *http.Request) {
		filename := strings.TrimPrefix(r.URL.Path, "/images/")
		if filename == "" {
			w.WriteHeader(http.StatusBadRequest)
			w.Write([]byte(`{"error":"Filename required"}`))
			return
		}
		var methodPath string
		if r.Method == http.MethodGet {
			methodPath = "/api/images/" + filename
		} else if r.Method == http.MethodDelete {
			methodPath = "/api/images/" + filename
		} else {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, imageServiceURL, methodPath)
	})

	// Proxy /stats (GET) to image-storage-service
	http.HandleFunc("/stats", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			w.WriteHeader(http.StatusMethodNotAllowed)
			w.Write([]byte(`{"error":"Method not allowed"}`))
			return
		}
		proxyToService(w, r, imageServiceURL, "/api/stats")
	})

	log.Printf("Starting API service on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
} 