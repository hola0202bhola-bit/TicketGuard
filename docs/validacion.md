# Validación y demostración

## Registro del proceso real

La investigación documental del requisito §5 usa el [procedimiento de reclamación de Profeco](https://www.gob.mx/profeco/documentos/tuviste-algun-problema-de-consumo?state=published) y su [guía de conservación de tickets](https://www.gob.mx/profeco/prensa/profeco-recuerda-a-las-y-los-consumidores-la-importancia-de-pedir-y-guardar-tickets-de-compra). El paso de acreditar la compra motivó registrar la foto y buscar por producto o tienda. La compra de audífonos usada en pruebas es ficticia. Para una validación adicional con alguien del público objetivo, registra fecha, contexto, cómo conservó el ticket, resultado al usar TicketGuard y un cambio derivado, cuando aplique.


## Bitácora individual

| Etapa | Responsabilidad | Evidencia |
| --- | --- | --- |
| Alcance y UX | Autor individual · análisis, flujo, requisitos, estilo y bocetos | [Diseño](diseno.md) y commit inicial |
| Desarrollo | Autor individual · Flutter, Android, Supabase y seguridad | Rama `feature/mvp-android`, migraciones, código |
| Validación | Autor individual · revisión y pruebas | Pruebas Flutter, script de dos cuentas, capturas, firma |
| Presentación | Estudiante · demostración y decisión técnica | Guion de este documento y APK firmado |

## Incidencias y correcciones

| Incidencia observada | Reproducción | Corrección y verificación |
| --- | --- | --- |
| La compra sin garantía no podía crearse | Insertar una fila con `lead_days` y garantía vacíos | Segunda migración permite ambos valores nulos y mantiene el requisito de fecha si se programa aviso. El alta real devolvió HTTP 201. |
| Una foto con bytes demasiado cortos causaba una excepción genérica | Intentar procesar tres bytes inválidos | Detección por firma JPEG/PNG y rechazo explícito. Prueba Flutter de foto y metadatos aprobada. |
| El título de la barra podía desbordarse en el ancho de prueba | Abrir la lista con tamaño de 393 × 852 en prueba de interfaz | El título ahora cede espacio a los controles. Prueba de interfaz aprobada. |
| La primera compilación de distribución referenciaba un complemento de integración ausente | Compilar release con la dependencia de integración sin usar | Se retiró esa dependencia. Las verificaciones de interfaz quedaron en Flutter Test y el APK de distribución compiló, se firmó y se instaló. |
| Una consulta inmediata repetía una imagen sintética tras borrarla | Descargar, borrar y consultar la misma URL | La verificación de borrado usa una consulta nueva con `cacheNonce` y comprueba que desapareció la fila y que Storage devuelve un error al recuperar el objeto. Las respuestas previamente cacheadas pueden persistir brevemente. |

## Matriz de pruebas ejecutadas

Fecha local de las pruebas: 13 de noviembre de 2026, Ciudad de México. El emulador estaba en UTC y algunas capturas muestran el 14 de noviembre. El APK de entrega es 1.0.0 (3). Las capturas 02 a 06 se hicieron con una compilación temporal de ensayo 1.0.0 (4) que reconocía la autoridad de certificados de Norton en la red del equipo. El APK de entrega conserva la validación HTTPS habitual y se reinstaló después de las pruebas.

| ID | Escenario | Resultado y evidencia |
| --- | --- | --- |
| P01 | Verificar firma, instalar y abrir el APK exacto de entrega | APK Signature Scheme v2 verificado. Instalación y pantalla inicial correctas en Pixel 7, API 37. [Registro](evidencias/android-distribucion.txt) · [Acceso](evidencias/01-acceso.png) |
| P02 | Iniciar sesión A, usar cámara, guardar y recuperar el comprobante | La cámara virtual devolvió la foto al formulario. El guardado real en Supabase abrió el detalle con la foto y la compra. [Cámara](evidencias/02-camara-ensayo.png) · [Formulario](evidencias/03-formulario-ensayo.png) · [Detalle](evidencias/04-detalle-ensayo.png) |
| P03 | Validar campos, precio y foto | Flutter rechazó importe cero y archivo inválido. Supabase rechazó un importe negativo, MIME incorrecto, tamaño mayor a 5 MiB y finalización sin objeto. [Flutter](evidencias/flutter-pruebas.txt) · [API](evidencias/supabase-dos-cuentas.txt) |
| P04 | Buscar, reiniciar y consultar en modo avión | Buscar «centro» devolvió la compra. Tras forzar el cierre y reiniciar en modo avión, se leyó el mismo detalle con su foto. [Búsqueda](evidencias/05-busqueda-ensayo.png) · [Modo avión](evidencias/06-sin-conexion-ensayo.png) |
| P05 | Aislamiento entre dos cuentas y sin sesión | A consultó la fila y descargó el JPEG íntegro. B obtuvo cero filas al leer, editar o intentar eliminar; fallaron la escritura en la ruta de A, la descarga y el acceso público. [Registro](evidencias/supabase-dos-cuentas.txt) |
| P06 | Falla de red al guardar y reintento | La prueba Flutter simula la falla y confirma que la app conserva el formulario y reintenta con el mismo identificador. El emulador validó el acceso sin red al reiniciar. El corte en mitad de una carga real quedó pendiente. [Registro](evidencias/flutter-pruebas.txt) |
| P07 | Programar, editar y borrar | Android pidió permiso y registró la alarma de garantía. Tras editar se mostró la tienda actualizada. Al confirmar el borrado desapareció el ticket y no quedó alarma pendiente. La entrega visible del aviso y el reinicio del sistema con un aviso pendiente quedan por comprobar. [Registro](evidencias/android-recordatorio.txt) |
| P08 | Correo de alta y uso en teléfono físico | Inicio de sesión probado con dos cuentas confirmadas desde el panel. La confirmación de alta por correo propio y el recorrido con el APK entregado en un teléfono físico y una red habitual quedan pendientes. |

Las capturas contienen una escena virtual y datos ficticios. La prueba de API limpia su comprobante y la prueba Android eliminó su ticket. Las cuentas sintéticas quedan en Authentication para reproducir las verificaciones.

## Guion

1. Explicar el problema de poder mostrar un ticket cuando se necesita una garantía.
2. Entrar en la cuenta de demostración. Registrar una compra, elegir una foto ficticia y mostrar la validación con un importe cero.
3. Usar un importe correcto, elegir una garantía a futuro y activar el aviso. Guardar, buscar por tienda y abrir la imagen ampliable.
4. Mostrar la consulta de la copia local en modo avión y volver a conectar.
5. Explicar el aislamiento por propietario y mostrar la evidencia con dos cuentas.
6. Explicar el estado provisional de un ticket mientras se sube su foto y cómo permite reintentar.
7. Mostrar APK, firma y repositorio. Indicar que el proyecto se realizó de forma individual y presentar la indicación del docente sobre cómo se evaluará el requisito de equipo cuando esté disponible.
