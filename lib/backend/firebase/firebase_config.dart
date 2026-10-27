import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBTSb_W8R4dV7oTRLvcR7GSZI6vUZhD3pc",
            authDomain: "kitunga-xtvpe4.firebaseapp.com",
            projectId: "kitunga-xtvpe4",
            storageBucket: "kitunga-xtvpe4.firebasestorage.app",
            messagingSenderId: "44272206573",
            appId: "1:44272206573:web:2ca918ed50da1e8c5b02e4"));
  } else {
    await Firebase.initializeApp();
  }
}
