# Permisos y roles — ParqueRM

## Objetivo

Este documento explica cómo se manejan los permisos del sistema ParqueRM.

La seguridad real debe estar en el backend. El frontend puede ocultar botones o pantallas, pero cada endpoint del backend debe validar permisos antes de ejecutar una acción.

---

## Modelo usado

ParqueRM usa RBAC:

```txt
RBAC = Role Based Access Control
```

La relación principal es:

```txt
Usuario → Rol → Permisos
```

Ejemplo:

```txt
Usuario: Juan García
Rol: Administrador
Permisos:
  - VISITANTES_CREATE
  - CAJA_CLOSE
  - USERS_MANAGE
```

---

## Tablas principales

### `users`

Guarda los usuarios del sistema.

Campos importantes:

```txt
username
password_hash
full_name
email
role_id
is_active
last_login_at
```

Cada usuario tiene un rol.

---

### `roles`

Guarda los roles disponibles.

Roles iniciales:

```txt
Administrador
Operador de caja
Consulta
```

---

### `permissions`

Guarda acciones específicas que el sistema permite.

Ejemplos:

```txt
VISITANTES_CREATE
CAJA_CLOSE
REPORTES_EXPORT
USERS_MANAGE
```

---

### `role_permissions`

Relaciona roles con permisos.

Ejemplo:

```txt
Operador de caja → VISITANTES_CREATE
Operador de caja → RECEIPTS_CREATE
Operador de caja → CAJA_READ
```

---

## Roles iniciales

## Administrador

Tiene acceso total.

Puede:

```txt
- Configurar el sistema.
- Crear y editar usuarios.
- Administrar roles y permisos.
- Cambiar tarifas.
- Administrar catálogos.
- Registrar visitantes.
- Registrar vehículos.
- Registrar hospedaje.
- Procesar cobros.
- Emitir recibos.
- Anular recibos.
- Registrar ingresos y egresos.
- Cerrar caja.
- Ver reportes.
- Exportar reportes.
- Consultar auditoría.
```

Permisos:

```txt
Todos los permisos del sistema
```

---

## Operador de caja

Rol operativo para el personal que atiende al visitante.

Puede:

```txt
- Registrar visitantes.
- Consultar visitantes.
- Registrar salida de visitantes.
- Registrar vehículos.
- Consultar vehículos.
- Habilitar salida de vehículos.
- Registrar hospedaje.
- Consultar hospedaje.
- Crear recibos.
- Consultar recibos.
- Imprimir recibos.
- Crear movimientos de caja.
- Consultar caja.
- Ver reportes.
- Leer configuración.
- Leer catálogos.
```

No puede:

```txt
- Crear usuarios.
- Editar usuarios.
- Cambiar roles.
- Cambiar permisos.
- Editar configuración sensible.
- Cambiar tarifas.
- Administrar catálogos.
- Cerrar caja.
- Anular recibos.
- Anular movimientos.
- Exportar reportes.
- Ver auditoría.
```

Permisos asignados:

```txt
VISITANTES_CREATE
VISITANTES_READ
VISITANTES_CHECKOUT

VEHICULOS_CREATE
VEHICULOS_READ
VEHICULOS_ENABLE_EXIT

HOSPEDAJE_CREATE
HOSPEDAJE_READ

RECEIPTS_CREATE
RECEIPTS_READ
RECEIPTS_PRINT

CAJA_CREATE_MOVEMENT
CAJA_READ

REPORTES_READ

CONFIG_READ
CATALOGS_READ
```

---

## Consulta

Rol de solo lectura.

Puede:

```txt
- Ver visitantes.
- Ver vehículos.
- Ver hospedaje.
- Ver recibos.
- Ver caja.
- Ver reportes.
- Ver configuración.
- Ver catálogos.
```

No puede:

```txt
- Crear registros.
- Editar registros.
- Anular recibos.
- Registrar cobros.
- Cerrar caja.
- Cambiar configuración.
- Administrar usuarios.
- Administrar roles.
- Exportar reportes.
```

Permisos asignados:

```txt
VISITANTES_READ
VEHICULOS_READ
HOSPEDAJE_READ
RECEIPTS_READ
CAJA_READ
REPORTES_READ
CONFIG_READ
CATALOGS_READ
```

---

## Lista de permisos

### Visitantes

```txt
VISITANTES_CREATE      → Registrar visitantes
VISITANTES_READ        → Consultar visitantes
VISITANTES_UPDATE      → Editar registros de visitantes
VISITANTES_CHECKOUT    → Registrar salida de visitantes
```

---

### Vehículos

```txt
VEHICULOS_CREATE       → Registrar vehículos
VEHICULOS_READ         → Consultar vehículos
VEHICULOS_UPDATE       → Editar registros de vehículos
VEHICULOS_ENABLE_EXIT  → Habilitar salida de vehículos
```

---

### Hospedaje

```txt
HOSPEDAJE_CREATE       → Registrar hospedaje
HOSPEDAJE_READ         → Consultar hospedaje
```

---

### Recibos

```txt
RECEIPTS_CREATE        → Crear recibos
RECEIPTS_READ          → Consultar recibos
RECEIPTS_CANCEL        → Anular recibos
RECEIPTS_PRINT         → Imprimir recibos
```

---

### Caja

```txt
CAJA_CREATE_MOVEMENT   → Crear ingresos o egresos
CAJA_READ              → Consultar caja
CAJA_CLOSE             → Cerrar caja
CAJA_CANCEL_MOVEMENT   → Anular movimientos de caja
```

---

### Reportes

```txt
REPORTES_READ          → Ver reportes
REPORTES_EXPORT        → Exportar reportes
```

---

### Configuración

```txt
CONFIG_READ            → Ver configuración
CONFIG_UPDATE          → Editar configuración
```

---

### Catálogos

```txt
CATALOGS_READ          → Ver catálogos
CATALOGS_MANAGE        → Administrar catálogos
```

---

### Usuarios

```txt
USERS_READ             → Ver usuarios
USERS_MANAGE           → Crear, editar o desactivar usuarios
```

---

### Roles

```txt
ROLES_READ             → Ver roles y permisos
ROLES_MANAGE           → Administrar roles y permisos
```

---

### Auditoría

```txt
AUDIT_READ             → Ver bitácora de auditoría
```

---

## Validación en backend

Cada endpoint sensible debe protegerse con JWT y permisos.

Ejemplo conceptual en NestJS:

```ts
@UseGuards(JwtAuthGuard, PermissionsGuard)
@RequirePermissions('VISITANTES_CREATE')
@Post()
createVisitor() {
  // registrar visitante
}
```

Otro ejemplo:

```ts
@UseGuards(JwtAuthGuard, PermissionsGuard)
@RequirePermissions('CAJA_CLOSE')
@Post('close')
closeCash() {
  // cerrar caja
}
```

---

## Mapeo recomendado por endpoint

```txt
POST   /visitors                    → VISITANTES_CREATE
GET    /visitors                    → VISITANTES_READ
PATCH  /visitors/:id                → VISITANTES_UPDATE
POST   /visitors/:id/check-out      → VISITANTES_CHECKOUT

POST   /vehicles                    → VEHICULOS_CREATE
GET    /vehicles                    → VEHICULOS_READ
PATCH  /vehicles/:id                → VEHICULOS_UPDATE
PATCH  /vehicles/:id/enable-exit    → VEHICULOS_ENABLE_EXIT

POST   /lodging                     → HOSPEDAJE_CREATE
GET    /lodging                     → HOSPEDAJE_READ

POST   /receipts                    → RECEIPTS_CREATE
GET    /receipts                    → RECEIPTS_READ
PATCH  /receipts/:id/cancel         → RECEIPTS_CANCEL
GET    /receipts/:id/print          → RECEIPTS_PRINT

POST   /cash/movements              → CAJA_CREATE_MOVEMENT
GET    /cash/movements              → CAJA_READ
GET    /cash/summary                → CAJA_READ
POST   /cash/closures               → CAJA_CLOSE
PATCH  /cash/movements/:id/cancel   → CAJA_CANCEL_MOVEMENT

GET    /reports/general             → REPORTES_READ
GET    /reports/export/excel        → REPORTES_EXPORT
GET    /reports/export/pdf          → REPORTES_EXPORT

GET    /park-config                 → CONFIG_READ
PATCH  /park-config                 → CONFIG_UPDATE

GET    /catalogs                    → CATALOGS_READ
POST   /catalogs                    → CATALOGS_MANAGE
PATCH  /catalogs/:id                → CATALOGS_MANAGE

GET    /users                       → USERS_READ
POST   /users                       → USERS_MANAGE
PATCH  /users/:id                   → USERS_MANAGE

GET    /roles                       → ROLES_READ
PATCH  /roles/:id/permissions       → ROLES_MANAGE

GET    /audit-logs                  → AUDIT_READ
```

---

## Validación en frontend

El frontend puede usar permisos para ocultar opciones.

Ejemplo:

```tsx
{hasPermission('VISITANTES_CREATE') && (
  <Button>Nuevo visitante</Button>
)}
```

También puede proteger rutas:

```tsx
<ProtectedRoute permission="REPORTES_READ">
  <ReportsPage />
</ProtectedRoute>
```

Pero esto no reemplaza la seguridad del backend.

---

## Reglas importantes

1. No confiar en el frontend.
2. Todo endpoint sensible debe validar permisos en backend.
3. No usar solo roles para autorizar acciones.
4. Los roles organizan usuarios, pero los permisos autorizan acciones.
5. Caja cerrada no debe modificarse sin auditoría.
6. Recibos anulados deben guardar usuario, fecha y motivo.
7. Cambios sensibles deben guardarse en `audit_logs`.

---

## Resumen

El sistema de permisos de ParqueRM se basa en:

```txt
JWT + Roles + Permisos + Guards de NestJS
```

La lógica correcta es:

```txt
Usuario inicia sesión
↓
Backend genera JWT
↓
JWT incluye usuario, rol y permisos
↓
Cada endpoint valida si el usuario tiene el permiso requerido
↓
Frontend solo muestra lo que el usuario puede usar
```

La seguridad real siempre queda en el backend.
