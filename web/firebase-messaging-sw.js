// Importez les scripts Firebase nécessaires
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialisation avec vos identifiants récupérés
firebase.initializeApp({
  apiKey: "AIzaSyBhm2zRZ3ZwpVepnQO8p_uu8ho4gU5g9d4",
  authDomain: "easylocation-be28b.firebaseapp.com",
  projectId: "easylocation-be28b",
  storageBucket: "easylocation-be28b.firebasestorage.app",
  messagingSenderId: "540611988411",
  appId: "1:540611988411:web:922ba2df8746edce5a529e"
});

const messaging = firebase.messaging();