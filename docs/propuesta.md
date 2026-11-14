# Propuesta aprobada de TicketGuard

**Modalidad A · Proyecto nuevo · Desarrollo individual**

Reconstrucción de la propuesta de «Idea de aplicación móvil». El estudiante informó que el docente aprobó la propuesta. La confirmación específica de la excepción de equipo queda pendiente.

| Aspecto | Propuesta |
| --- | --- |
| Proyecto | TicketGuard, gestor de tickets de compra y garantías. |
| Problema | Los comprobantes físicos se pierden, se deterioran o son difíciles de encontrar justo cuando se necesita hacer una devolución o reclamar una garantía. |
| Usuario | Personas que realizan compras y quieren organizar comprobantes y vencimientos desde el teléfono. |
| Solución | Fotografiar el ticket, registrar producto, tienda, fecha e importe, encontrar compras y recibir avisos antes del vencimiento de la garantía. |
| Prioridades | Captura con cámara, registro de datos, organización y búsqueda, fecha de garantía, avisos locales y consulta sin conexión. |
| Propuesta de datos original | Fotografías y datos de compra en el dispositivo. Pedir los permisos móviles solo al usarlos. |
| Valor móvil | Captura en el momento de compra, consulta en la tienda sin red y avisos del sistema sin abrir la app. |
| Alcance | MVP Android con captura, búsqueda y garantías. OCR y verificación con comercios quedan fuera del alcance. |
| Responsabilidades | Una persona cubre análisis, interfaz, lógica, datos, pruebas y documentación. |

Durante el desarrollo se incorporó Supabase por indicación del encargo actual. El diseño implementado conserva la consulta local después de sincronizar y protege las fotos con almacenamiento privado. [Análisis y decisiones de diseño](diseno.md).
