# Validación y demostración

## Registro del proceso real

La propuesta aprobada por el docente según el estudiante describe el problema de recuperar comprobantes en una reclamación. Se usó como entrada un caso ilustrativo de compra de audífonos. Falta validar con una persona usuaria el proceso real, como requiere el §5 del PDF. Para documentarlo, registra fecha, contexto sin datos identificativos, cómo conservó el ticket, qué necesitó al buscarlo, resultado al usar TicketGuard y un cambio derivado si aplica.

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

## Guion

1. Explicar el problema de poder mostrar un ticket cuando se necesita una garantía.
2. Entrar en la cuenta de demostración. Registrar una compra, elegir una foto ficticia y mostrar la validación con un importe cero.
3. Usar un importe correcto, elegir una garantía a futuro y activar el aviso. Guardar, buscar por tienda y abrir la imagen ampliable.
4. Mostrar la consulta de la copia local en modo avión y volver a conectar.
5. Explicar el aislamiento por propietario y mostrar la evidencia con dos cuentas.
6. Explicar el estado provisional de un ticket mientras se sube su foto y cómo permite reintentar.
7. Mostrar APK, firma y repositorio. Indicar que el proyecto se realizó de forma individual y cómo resolvió el docente el requisito de equipo.
