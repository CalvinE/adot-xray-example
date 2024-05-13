package main

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
)

func validateOp(ctx context.Context, op string) (int, error) {
	return strconv.Atoi(op)
}

func addHandler(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	ctx := r.Context()
	op1, err := validateOp(ctx, query.Get("op1"))
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}
	if op1 < 0 {
		// Throw error on negative op1
	}
	op2, err := validateOp(ctx, query.Get("op2"))
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte("bad request"))
		return
	}

	result := op1 + op2

	w.Write([]byte(strconv.Itoa(result)))
}

// A simple health check handler
func healthCheckHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Println("healthcheck hit")
	w.WriteHeader(http.StatusOK)
}

func main() {
	fmt.Println("starting up mathservice")
	mux := http.NewServeMux()
	mux.HandleFunc("GET /add", addHandler)
	mux.HandleFunc("GET /health", healthCheckHandler)
	if err := http.ListenAndServe(":8080", mux); err != nil {
		fmt.Printf("HTTP server errored... %v", err)
	}
}
