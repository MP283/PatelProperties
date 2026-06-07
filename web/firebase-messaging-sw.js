// ✅ Check if messaging is supported before loading
try {
  importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
  importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

  // ✅ Initialize Firebase in service worker
  firebase.initializeApp({
    apiKey: "AIzaSyDuN1ZaGKn3HaUK9F6EY2lUnQfUIJqKhwo",
    authDomain: "patelproperties-8db21.firebaseapp.com",
    projectId: "patelproperties-8db21",
    storageBucket: "patelproperties-8db21.firebasestorage.app",
    messagingSenderId: "94676098605",
    appId: "1:94676098605:web:0847aca8921cafd6a562a4",
    measurementId: "G-H662KCN3Y4"
  });

  // ✅ Only initialize messaging if supported
  if (firebase.messaging.isSupported()) {
    const messaging = firebase.messaging();

    // ✅ Handle background notifications
    messaging.onBackgroundMessage(function(payload) {
      console.log("Background message received:", payload);

      const notificationTitle = payload.notification?.title || "New Notification";
      const notificationOptions = {
        body: payload.notification?.body || "",
        icon: "/icons/Icon-192.png",
      };

      self.registration.showNotification(notificationTitle, notificationOptions);
    });
  } else {
    console.log("Firebase Messaging not supported in this browser — skipping.");
  }

} catch (e) {
  console.error("Firebase SW error (safe to ignore on iOS):", e);
}