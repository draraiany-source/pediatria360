// Trecho a MESCLAR em android/build.gradle.kts depois de rodar
// `flutter create --platforms=android,ios,web .`
//
// O `flutter create` não adiciona o plugin do Google Services — sem ele o
// google-services.json é ignorado e o Firebase falha ao inicializar com um
// erro pouco descritivo.

plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
