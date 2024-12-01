package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "slices"
    "strconv"
    "sync"

    "github.com/gorilla/mux"
    "github.com/rs/cors"
)

// Use the new range key feature in Go 1.23
type Todo struct {
    ID   int    `json:"id"`
    Text string `json:"text"`
    Done bool   `json:"done"`
}

var (
    todos   = []Todo{}
    todosMu sync.Mutex
    nextID  = 1
)

// Utilize Go 1.23's improved error handling and slices package
func getTodos(w http.ResponseWriter, r *http.Request) {
    todosMu.Lock()
    defer todosMu.Unlock()

    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(todos); err != nil {
        http.Error(w, fmt.Sprintf("Error encoding todos: %v", err), http.StatusInternalServerError)
    }
}

func createTodo(w http.ResponseWriter, r *http.Request) {
    todosMu.Lock()
    defer todosMu.Unlock()

    var newTodo Todo
    if err := json.NewDecoder(r.Body).Decode(&newTodo); err != nil {
        http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
        return
    }

    // Use Go 1.23 slices package for cleaner slice operations
    newTodo.ID = nextID
    todos = slices.Insert(todos, len(todos), newTodo)
    nextID++

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    if err := json.NewEncoder(w).Encode(newTodo); err != nil {
        http.Error(w, fmt.Sprintf("Error encoding new todo: %v", err), http.StatusInternalServerError)
    }
}

func updateTodoStatus(w http.ResponseWriter, r *http.Request) {
    todosMu.Lock()
    defer todosMu.Unlock()

    vars := mux.Vars(r)
    id, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid todo ID", http.StatusBadRequest)
        return
    }

    // Use Go 1.23 slices.IndexFunc for finding todo
    index := slices.IndexFunc(todos, func(t Todo) bool { return t.ID == id })
    if index == -1 {
        http.Error(w, "Todo not found", http.StatusNotFound)
        return
    }

    // Toggle done status
    todos[index].Done = !todos[index].Done

    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(todos[index]); err != nil {
        http.Error(w, fmt.Sprintf("Error encoding updated todo: %v", err), http.StatusInternalServerError)
    }
}

func deleteTodo(w http.ResponseWriter, r *http.Request) {
    todosMu.Lock()
    defer todosMu.Unlock()

    vars := mux.Vars(r)
    id, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid todo ID", http.StatusBadRequest)
        return
    }

    // Use Go 1.23 slices.IndexFunc and slices.Delete
    index := slices.IndexFunc(todos, func(t Todo) bool { return t.ID == id })
    if index == -1 {
        http.Error(w, "Todo not found", http.StatusNotFound)
        return
    }

    todos = slices.Delete(todos, index, index+1)

    w.WriteHeader(http.StatusOK)
}

func main() {
    r := mux.NewRouter()
    
    // Add routes for different operations
    r.HandleFunc("/todos", getTodos).Methods("GET")
    r.HandleFunc("/todos", createTodo).Methods("POST")
    r.HandleFunc("/todos/{id}", updateTodoStatus).Methods("PATCH")
    r.HandleFunc("/todos/{id}", deleteTodo).Methods("DELETE")

    handler := cors.Default().Handler(r)
    
    // Use more descriptive startup log
    serverAddr := ":8080"
    log.Printf("Starting server on %s", serverAddr)
    log.Fatal(http.ListenAndServe(serverAddr, handler))
}