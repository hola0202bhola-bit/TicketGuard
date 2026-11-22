# TicketGuard 1.0.0 - Actualización de validación en Android real

**Fecha del reporte:** 22 de noviembre de 2026  
**Versión:** 1.0.0 (3) / `1.0.0+3`  
**Origen de evidencia:** comprobaciones manuales confirmadas por el estudiante. No son pruebas reproducidas por este informe.

## Resultados de la comprobación en el teléfono físico

| ID | Comprobación | Resultado informado |
| --- | --- | --- |
| F01 | Instalación y apertura sin cierres inesperados | Satisfactorio |
| F02 | Inicio de sesión mediante Supabase | Satisfactorio |
| F03 | Captura de foto y registro de compra | Satisfactorio |
| F04 | Guardado y aparición del ticket en la lista | Satisfactorio |
| F05 | Persistencia al cerrar y reabrir la aplicación | Satisfactorio |
| F06 | Consulta de foto previamente disponible en modo avión | Satisfactorio |
| F07 | Búsqueda y edición de un ticket | Satisfactorio |
| F08 | Programación y aparición visible de recordatorio | Satisfactorio |
| F09 | Eliminación y ausencia del ticket en la lista | Satisfactorio |

**Resultado:** 9/9 comprobaciones funcionales confirmadas por el estudiante.

El estudiante indicó además que **ya grabó un video de demostración**. El video aún no está adjunto a este archivo y deberá entregarse a través del medio que acepte el docente. El APK y el video no se revisaron directamente para redactar esta actualización.

## Relación con las evidencias históricas

Este registro complementa la [matriz original](https://github.com/hola0202bhola-bit/TicketGuard/blob/main/docs/validacion.md), que refleja pruebas efectuadas los días 13-14 de noviembre en emulador y con cuentas de prueba.

- **P07:** el registro previo consideraba pendiente la entrega visible de la notificación. El estudiante confirmó posteriormente que el aviso apareció en su teléfono. Sigue sin constancia separada una prueba de reinicio completo de Android con aviso pendiente.
- **P08:** el registro previo consideraba pendiente el flujo en un teléfono físico. El estudiante confirmó posteriormente que completó el flujo en su dispositivo. No se ha afirmado que se haya probado el registro y confirmación de un correo nuevo.

## Autorización de modalidad individual

El estudiante confirmó que el profesor **sí autorizó trabajar individualmente**. Esto modifica la condición que había quedado pendiente en la documentación inicial. La rúbrica escrita destina 10 % a colaboración con GitHub; no consta una instrucción escrita particular sobre cómo ponderará el docente ese rubro para los proyectos individuales. La bitácora, los commits y la revisión #1 permiten mostrar trabajo verificable.

## Límites de la revisión

El código Flutter y las reglas de Supabase se inspeccionaron en el repositorio público; en esta actualización no se recompiló el APK, no se ejecutaron nuevamente las ocho pruebas Flutter y no se inspeccionó la grabación. Se recomienda guardar capturas o el video como evidencia de la ejecución en teléfono real.
