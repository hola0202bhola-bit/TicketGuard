# TicketGuard

Aplicación Android para fotografiar, organizar y recuperar comprobantes de compra y recibir recordatorios de garantía. Proyecto individual de modalidad A, con entrega académica el **23 de noviembre de 2026**.

- [Propuesta aprobada](docs/propuesta.md)
- [Análisis, historias de usuario, criterios y bocetos](docs/diseno.md)
- [Matriz de pruebas, incidencias y demostración](docs/validacion.md)
- [Repositorio privado TicketGuard](https://github.com/hola0202bhola-bit/TicketGuard)

## Instalar y usar

Instala el APK de distribución e inicia sesión con una cuenta confirmada del proyecto TicketGuard. El APK entregado apunta al proyecto Supabase dedicado. Para crear una cuenta con correo propio, usa **Crear una cuenta** y confirma el correo si el proyecto lo requiere. Con la configuración SMTP predeterminada, Supabase limita los destinatarios. Para presentar el MVP puede usarse una cuenta de demostración creada y confirmada por el propietario en Authentication. [Configuración SMTP de Supabase](https://supabase.com/docs/guides/auth/auth-smtp).

1. Toca **Nuevo ticket**, toma una foto o selecciónala en **Galería**.
2. Escribe producto, tienda e importe. La fecha inicial es la de hoy. Agrega garantía si corresponde.
3. Guarda y abre el comprobante. Busca por nombre del producto o tienda y usa **Por vencer** para ver garantías de los próximos 30 días.
4. Para un aviso, elige 7 o 1 día antes. Android solicita permiso si se requiere. El aviso usa las 09:00 como hora de referencia y puede demorarse por el ahorro de energía.
5. Para consultar una foto sin red, abre el ticket con conexión primero. La app conserva las fotos guardadas desde ese teléfono o abiertas previamente. Al cerrar sesión se retiran la copia local y los avisos de ese teléfono.

## Ejecutar desde el código

Entorno probado con Flutter 3.47.4, Dart 3.13.3, Android Studio, JDK 17 o compatible con Gradle 9.3.1 y Android SDK. Paquete Android `mx.ticketguard.ticketguard`.

1. Crea un proyecto Supabase dedicado. Ejecuta los archivos de [migraciones](supabase/migrations) en orden desde SQL Editor en una base nueva. Como alternativa, usa la [CLI oficial](https://supabase.com/docs/guides/local-development/overview) para levantar el entorno local y aplicar las migraciones. Usa en el emulador `10.0.2.2` para conectarte al host en depuración.
2. Copia `config/connection.example.json` a `config/connection.json` y completa URL y clave publicable o anon. También se pueden introducir en la pantalla inicial de una compilación sin parámetros. Mantén las claves administrativas fuera de la app.
3. Instala las dependencias y ejecuta.

```powershell
flutter pub get
flutter run --dart-define-from-file=config/connection.json
```

### Compilación de distribución

Crea una clave de firma con Android Studio o `keytool` y guarda el archivo fuera del repositorio. Usa `android/key.properties.example` como referencia para crear `android/key.properties`. Al indicar una ruta de Windows en las propiedades, usa barras `/`. Conserva la misma clave local para futuras actualizaciones de este APK. Consulta el [procedimiento de Flutter](https://docs.flutter.dev/deployment/android).

```powershell
flutter build apk --release --dart-define-from-file=config/connection.json
apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Pruebas

```powershell
flutter analyze
flutter test
# PowerShell 7. Definir previamente TICKETGUARD_TEST_EMAIL_A, TICKETGUARD_TEST_PASSWORD_A,
# TICKETGUARD_TEST_EMAIL_B y TICKETGUARD_TEST_PASSWORD_B con dos cuentas de ensayo confirmadas.
pwsh -NoProfile -File scripts/test-storage-access.ps1
```

El script de API utiliza un JPEG sintético, comprueba el aislamiento de tabla y Storage con dos cuentas y elimina su registro de prueba. La [matriz de pruebas](docs/validacion.md) indica qué se confirmó en Android y qué requiere validación presencial.

## Organización del código y contribuciones

- `lib/ui` contiene pantallas, estado de presentación y diseño.
- `lib/domain` contiene modelos, fechas, importes y búsqueda.
- `lib/data` integra Supabase, la copia local, la validación de imágenes y los avisos.
- `supabase/migrations` contiene esquema, políticas y restricciones reproducibles.

Las tareas e incidencias se registran en la [bitácora](docs/validacion.md). Para un cambio, crea una rama descriptiva, añade commits enfocados y documenta la revisión y los casos que ejecutaste antes de integrar. La entrega es individual. Confirma con el docente cómo aplicará el requisito de equipo y comparte el repositorio privado cuando indique su cuenta de GitHub.
