# ParqueRM — Demo Checklist y Guía de Presentación

**Preparado:** 2026-05-14 — QA final  
**Verificación final:** 2026-05-14 — Sprint 10 completado y E2E verificado (10/10 pasos OK)

---

## 1. URLs del sistema

| Servicio    | URL                              | Notas                            |
|-------------|----------------------------------|----------------------------------|
| Frontend    | http://localhost:8080            | Puerto 8080 en la máquina host   |
| Backend API | http://localhost:3000/api        | REST API                         |
| Swagger     | http://localhost:3000/api/docs   | Documentación interactiva        |
| SQL Server  | localhost,1433                   | Login: sa / ver .env             |
| Health      | http://localhost:3000/api/health | Verificación rápida del backend  |

> **Para despliegue en red local del parque:** cambiar `VITE_API_URL` en `.env` a la IP del servidor
> (ejemplo: `http://192.168.1.10:3000/api`) y reconstruir con `docker compose up -d --build`.

---

## 2. Credenciales de prueba

| Usuario  | Contraseña   | Rol              | Acceso              |
|----------|--------------|------------------|---------------------|
| `admin`  | `Admin2026!` | Administrador    | Total (29 permisos) |
| `esteban`| (desconocida)| (verificar)      | (verificar en DB)   |
| `david`  | (desconocida)| (verificar)      | (verificar en DB)   |

> **Nota:** El usuario `admin` fue restablecido a `Admin2026!` durante el QA del 2026-05-14.
> Los usuarios `esteban` y `david` son cuentas de prueba creadas durante el desarrollo.
> Para el demo usar **admin / Admin2026!**.

---

## 3. Comandos Docker

Todos se ejecutan desde `parqueRM-root/`:

```bash
# Verificar estado
docker compose ps

# Iniciar sistema completo (primera vez o tras reset)
docker compose up -d --build

# Apagar sin borrar datos
docker compose down

# RESET COMPLETO (borra todos los datos)
docker compose down -v
docker compose up -d --build

# Ver logs en tiempo real
docker compose logs -f backend
docker compose logs -f frontend
```

> **Importante:** `docker compose down -v` borra la base de datos. Usar sólo para
> resetear a estado limpio. Después de un reset, el sistema demora ~45s en estar listo.

---

## 4. Flujo recomendado de demo

### Flujo de 15-20 minutos

**1. Inicio de sesión y Dashboard** (~2 min)
- Abrir `http://localhost:8080`
- Ingresar con `admin / Admin2026!`
- Mostrar el Dashboard: tarjetas de resumen, barra de ocupación, últimos movimientos
- Destacar: roles y permisos controlan qué ve cada usuario

**2. Configuración del parque** (~2 min)
- Ir a **Configuración** → mostrar datos del parque (El Refugio del Quetzal, PRM-SM-001)
- Mostrar toggle de servicios
- Mencionar: configuración centralizada, no se hardcodea nada en el código

**3. Catálogos y Tarifas** (~2 min)
- Ir a **Catálogos** → mostrar tabs (países, departamentos, categorías de visitante, etc.)
- Ir a **Tarifas** → mostrar tarifas configuradas por tipo
- Destacar: todo es configurable por el administrador

**4. Registro de visitante** (~3 min)
- Ir a **Visitantes** → clic en "Nuevo visitante"
- Llenar el formulario SIGAP:
  - Categoría: Adulto nacional
  - Cantidad: 2
  - La tarifa se auto-resuelve
  - Geografía: Guatemala → San Marcos → San Rafael
  - Razones de visita: seleccionar chips
- Guardar → ver visitante en tabla con toast de confirmación

**5. Cobro y recibo** (~3 min)
- En la fila del visitante → clic en "Cobrar"
- CobroPage ya tiene las líneas pre-rellenas
- Seleccionar método de pago: Efectivo
- Ingresar monto recibido → se calcula el cambio
- Emitir recibo → número de recibo auto-generado
- Ir a **Recibos** → ver el recibo listado con estado ACTIVO

**6. Caja y cierre** (~2 min)
- Ir a **Caja** → crear movimiento manual de ingreso
- Mostrar resumen del día
- Ir a **Cierres** → mostrar preview del cierre (lista de movimientos pendientes)
- Realizar cierre de caja si aplica

**7. Vehículos y hospedaje** (~2 min, opcional)
- Ir a **Vehículos** → mostrar vehículo existente (P-299BQV)
- Mostrar flujo: registrar entrada → habilitar salida → registrar salida
- Ir a **Hospedaje** → mostrar registro de cabaña existente

**8. Reportes** (~1 min)
- Ir a **Reportes** → mostrar tab General (totales del período)
- Mostrar tab Visitantes (tabla filtrable)
- Exportar a Excel (.xlsx nativo) y PDF
- Mencionar: PDF no disponible desde servidor (pendiente backend)

**9. Usuarios y roles** (~1 min)
- Ir a **Usuarios** → mostrar lista de usuarios, badge de rol
- Ir a **Roles** → mostrar checkboxes de permisos por módulo
- Destacar: administración de accesos granular

**10. Auditoría** (~1 min)
- Ir a **Auditoría** → mostrar bitácora de acciones
- Abrir modal de alguna acción → ver diff JSON de valores anterior/nuevo

---

## 5. Módulos seguros para presentar

Todos los módulos están funcionales. Los siguientes son los más estables para demo:

- ✅ **Login / Auth** — JWT, refresh token automático
- ✅ **Dashboard** — estadísticas del día y semana
- ✅ **Visitantes** — CRUD completo + SIGAP + checkout
- ✅ **Vehículos** — CRUD + enable/disable exit + checkout
- ✅ **Hospedaje** — CRUD completo
- ✅ **Cobro (CobroPage)** — formulario con líneas + calculadora de cambio
- ✅ **Recibos** — lista, filtros, anulación
- ✅ **Caja** — movimientos, resumen, filtros
- ✅ **Cierres** — preview en tiempo real + historial
- ✅ **Reportes** — 3 tabs + export Excel (.xlsx nativo) + export PDF
- ✅ **Configuración** — datos del parque + servicios
- ✅ **Catálogos** — 11 catálogos con CRUD completo
- ✅ **Tarifas** — CRUD con filtros
- ✅ **Usuarios** — CRUD + toggle + cambio contraseña
- ✅ **Roles** — CRUD + asignación de permisos por módulo
- ✅ **Auditoría** — lista filtrable + modal con diff JSON

---

## 6. Módulos a mostrar con cuidado

| Módulo | Razón | Cómo manejarlo |
|--------|-------|----------------|
| **Reportes → tab Ingresos** | Solo muestra `financial_movements` de Caja | Ahora los recibos crean movimientos automáticamente — el tab Ingresos los verá al instante |
| **Configuración** | La dirección dice "Dirección pendiente de configurar" | Actualizar manualmente antes del demo vía la misma pantalla |
| ~~**Export PDF**~~ | **RESUELTO** | jsPDF client-side — botón "Descargar PDF" en CobroPage y ReportsPage |
| **Impresión de recibos** | Requiere impresora en red local configurada | Omitir o mencionar como feature de producción |

---

## 7. Botones/flujos a evitar durante demo

- ❌ **Imprimir recibo** — llama al endpoint pero sin impresora configurada no hace nada visible
- ❌ **Reset de base de datos** (`docker compose down -v`) — elimina todos los datos de demo
- ⚠️  **Login repetido rápido** — rate limiter de auth: máximo 5 intentos / 60 segundos

---

## 8. Puntos fuertes del sistema

1. **Arquitectura limpia**: NestJS + React + SQL Server, totalmente dockerizado
2. **RBAC completo**: 29 permisos granulares, 3 roles por defecto, administración desde UI
3. **Formulario SIGAP**: campos de geografía en cascada, razones/actividades como chips
4. **Auditoría completa**: toda acción sensible queda registrada con usuario, IP, diff JSON
5. **Flujo financiero**: recibo con líneas dinámicas, calculadora de cambio, cierre de caja
6. **Error handling robusto**: mensajes en español, toasts, empty states, ErrorPage global
7. **Datos numéricos seguros**: `toNum()` previene NaN en cálculos de tarifas
8. **API documentada**: Swagger en `/api/docs` con todos los endpoints
9. **Sin hardcode**: IPs, nombres de parque y configuración vienen de DB/env
10. **Red local**: diseñado para LAN, funciona sin internet

---

## 9. Áreas de mejora (honestas)

1. ~~**Recibos ↔ Caja desconectados**~~ — **RESUELTO** (2026-05-14): al crear un recibo se genera automáticamente un movimiento INGRESO en Caja; al anular el recibo se anula el movimiento si no está en un cierre cerrado
2. ~~**Export PDF**~~ — **RESUELTO** (2026-05-14): jsPDF client-side en CobroPage (tras emitir recibo) y ReportsPage (todos los tabs)
3. ~~**Export Excel como CSV**~~ — **RESUELTO** (2026-05-14): SheetJS genera .xlsx nativo en ReportsPage (todos los tabs)
4. **Impresión**: requiere configuración de impresora en red local
5. **Paginación en catálogos**: carga todos los registros sin paginar
6. **Tarifa en edición**: no se auto-actualiza al cambiar el tipo en modo edición (requiere ajuste manual)
7. **Hospedaje**: no tiene permiso `HOSPEDAJE_UPDATE` en seed (edición funciona pero permiso no está guardado)

---

## 10. Pendientes técnicos honestos

| Item | Impacto | Alcance |
|------|---------|---------|
| ~~Integración Receipt → FinancialMovement~~ | ~~Medio~~ | **HECHO** (2026-05-14) — `autoCreateMovement` / `autoCancelMovement` en `ReceiptsService` |
| ~~Export PDF real~~ | ~~Bajo~~ | **HECHO** (2026-05-14) — jsPDF client-side en `src/utils/pdf.ts` |
| ~~Export XLSX real~~ | ~~Bajo~~ | **HECHO** (2026-05-14) — SheetJS client-side en ReportsPage, lazy-loaded |
| Seed admin con contraseña desde env | Bajo | Backend: usar `ADMIN_BOOTSTRAP=true` en lugar de hash hardcodeado en SQL |
| Test suite | Medio | Backend y frontend: tests unitarios e integración |
| Rate limiter visible en UI | Bajo | Frontend: mostrar mensaje cuando se bloquea por throttle |

---

## 11. Plan B si algo falla en demo

| Problema | Solución inmediata |
|----------|-------------------|
| Contenedor caído | `docker compose up -d` desde `parqueRM-root/` |
| Login falla | Verificar: `admin / Admin2026!`. Si rate limiter activo, esperar 60s |
| Pantalla en blanco | Presionar F5, o abrir DevTools para ver error |
| API no responde | Verificar `http://localhost:3000/api/health` — si falla, `docker compose restart backend` |
| DB no responde | `docker compose restart sqlserver`, esperar 30s |
| Error en formulario | Mostrar el mensaje de error en pantalla como feature (validación funciona) |
| Reset completo | `docker compose down -v && docker compose up -d --build` (demora ~3 min) |

---

## 12. Datos de demo en la base de datos actual

Estado al 2026-05-14 (sin reset):

| Tabla              | Registros | Notas                          |
|--------------------|-----------|--------------------------------|
| park_config        | 1         | El Refugio del Quetzal         |
| roles              | 3         | Administrador, Operador, Consulta |
| permissions        | 29        | Todos los permisos del sistema |
| users              | 3         | admin, esteban, david          |
| visitor_categories | 7         | Adulto, Niño, Estudiante, etc. |
| vehicle_types      | 6         | Automóvil, Moto, Bus, etc.     |
| tariffs            | 16        | Visitantes, vehículos, hospedaje |
| payment_methods    | 4         | Efectivo, tarjeta, etc.        |
| visitors           | 3         | TKT-DEMO-001 (activo, sin cobro — para demo en vivo), TKT-DEMO-002 (completado ayer), TKT-DEMO-003 (activo, cobrado) |
| vehicles           | 2         | P-299BQV (activo, salida pendiente), BUS-0392 microbús (completado ayer) |
| lodging            | 2         | Cabaña 3 noches, Dormitorio 2 noches (grupo investigación) |
| receipts           | 6         | REC-DEMO-001..004 + 2 de prueba de integración Phase 1 |
| financial_movements| 7         | 5 INGRESO ACTIVO, 1 INGRESO ANULADO, 1 EGRESO (limpieza) |
| audit_logs         | (actuales)| Historial de acciones del sistema |

---

*Documento generado durante QA final — ParqueRM 2026-05-14*
