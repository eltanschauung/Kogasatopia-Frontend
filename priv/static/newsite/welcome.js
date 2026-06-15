// Check for the presence of a flag in local storage
if (!localStorage.getItem('hasVisited')) {
    // If the flag doesn't exist, greet the user
    alert('Welcome to our website! We hope you enjoy your stay.');

    // Set the flag to indicate the user has visited the site
    localStorage.setItem('hasVisited', 'true');
}
