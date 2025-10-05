// NOTE: Replace with your actual Azure Function/API Gateway URL after deployment
const API_URL = "https://<your-function-app-name>.azurewebsites.net/api/notes"; 

// --- GET ALL NOTES ---
async function loadNotes() {
    try {
        const response = await fetch(API_URL);
        const notes = await response.json();
        const list = document.getElementById('notes-list');
        list.innerHTML = ''; // Clear existing notes
        
        notes.forEach(note => {
            const li = document.createElement('li');
            li.innerHTML = `
                <strong>${note.title}</strong>
                <p>${note.content}</p>
                <button onclick="deleteNote('${note.id}')">Delete</button>
            `;
            list.appendChild(li);
        });
    } catch (error) {
        console.error('Error loading notes:', error);
        alert('Could not load notes. Check the API URL.');
    }
}

// --- SAVE NEW NOTE (POST) ---
async function saveNote() {
    const title = document.getElementById('note-title').value;
    const content = document.getElementById('note-content').value;

    if (!title || !content) {
        alert('Title and content cannot be empty.');
        return;
    }

    const newNote = { title, content };

    try {
        await fetch(API_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(newNote),
        });
        
        document.getElementById('note-title').value = '';
        document.getElementById('note-content').value = '';
        loadNotes(); // Refresh the list
    } catch (error) {
        console.error('Error saving note:', error);
        alert('Could not save note.');
    }
}

// --- DELETE NOTE ---
async function deleteNote(id) {
    try {
        // Assuming the API supports DELETE at /api/notes/{id}
        await fetch(`${API_URL}/${id}`, {
            method: 'DELETE',
        });
        loadNotes(); // Refresh the list
    } catch (error) {
        console.error('Error deleting note:', error);
        alert('Could not delete note.');
    }
}

// Load notes on page load
window.onload = loadNotes;