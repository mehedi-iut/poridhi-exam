document.addEventListener('DOMContentLoaded', () => {
    const todoForm = document.getElementById('todo-form');
    const todoInput = document.getElementById('todo-input');
    const todoList = document.getElementById('todo-list');

    // Fetch todos from backend
    async function fetchTodos() {
        try {
            const response = await fetch('/api/todos');
            const todos = await response.json();
            todoList.innerHTML = '';
            todos.forEach(todo => {
                const li = document.createElement('li');
                li.innerHTML = `
                    ${todo.text}
                    <button onclick="deleteTodo(${todo.id})">Delete</button>
                `;
                todoList.appendChild(li);
            });
        } catch (error) {
            console.error('Error fetching todos:', error);
        }
    }

    // Add new todo
    todoForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const text = todoInput.value.trim();
        if (text) {
            try {
                await fetch('/api/todos', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ text })
                });
                todoInput.value = '';
                fetchTodos();
            } catch (error) {
                console.error('Error adding todo:', error);
            }
        }
    });

    // Delete todo
    window.deleteTodo = async (id) => {
        try {
            await fetch(`/api/todos/${id}`, {
                method: 'DELETE'
            });
            fetchTodos();
        } catch (error) {
            console.error('Error deleting todo:', error);
        }
    };

    // Initial fetch
    fetchTodos();
});