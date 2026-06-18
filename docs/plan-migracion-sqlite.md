# Plan de migración: SQL Server Express → SQLite

> Alcance: `parqueRM-backend/` y `parqueRM-root/`.  
> `parqueRM-frontend/` no se modifica salvo incompatibilidad real e inevitable.

---

## 1. Resumen ejecutivo de viabilidad

**Viabilidad: ALTA.**

- `parqueRM-root` ya está migrado a SQLite: `docker-compose.yml` eliminó SQL Server, usa `db-init` con `sqlite3`, monta el volumen `sqlite_data` y pasa `DB_TYPE=sqlite` / `DB_PATH=/app/data/parquerm.db` al backend.
- Los scripts de `parqueRM-root/db/init/` ya están adaptados a SQLite (`INTEGER PRIMARY KEY AUTOINCREMENT`, `TEXT`, `CURRENT_TIMESTAMP`, `WAL`, etc.) y los originales de SQL Server están respaldados en `parqueRM-root/db/SQL-Server/`.
- El backend aún está configurado para SQL Server (`type: 'mssql'`, `mssql` en `package.json`, entidades con `nvarchar`/`datetime2`/`bit` y defaults `SYSDATETIME()`).
- **No se encontraron queries nativas de SQL Server** (`GETDATE`, `TOP`, `OUTPUT INSERTED`, `MERGE`, `NOLOCK`, etc.). Todo el acceso a datos usa el DSL de TypeORM (`Repository`, `createQueryBuilder`).
- El frontend consume endpoints/DTOs estándar; no debería verse afectado.

**Trabajo principal pendiente:**
1. Reconfigurar TypeORM para SQLite.
2. Ajustar los tipos de columna y defaults en las 27 entidades.
3. Actualizar validación de variables de entorno.
4. Compilar/empaquetar el driver de SQLite en el Docker del backend.
5. Agregar healthchecks, backups y documentación.

**Escenario de carga:** máximo 10 usuarios en un solo sistema local. SQLite con WAL es suficiente; el cuello de botella será la escritura secuencial, por lo que se recomiendan transacciones cortas y `busy_timeout`.

---

## 2. Archivos a revisar / modificar

### Backend (`parqueRM-backend/`)

| Archivo | Motivo |
|---------|--------|
| `package.json` | Agregar driver SQLite (`better-sqlite3` recomendado, `sqlite3` como alternativa). Opcionalmente retirar `mssql`. |
| `Dockerfile` | Instalar herramientas de compilación nativas para `better-sqlite3` en `node:22-alpine`. |
| `src/database/database.module.ts` | Cambiar `type: 'mssql'` por SQLite, leer `DB_TYPE`/`DB_PATH`, quitar opciones MSSQL. |
| `src/config/configuration.ts` | Agregar `database.type`, `database.path`; hacer opcionales host/port/user/password/name. |
| `src/config/env.validation.ts` | Validar `DB_TYPE` (`sqlite`/`mssql`), `DB_PATH`; hacer variables MSSQL opcionales cuando no apliquen. |
| `src/database/entities/*.ts` (27 archivos) | Cambiar `nvarchar`→`varchar`/`text`, `datetime2`→`datetime`, `bit`→`boolean`/`integer`, defaults `SYSDATETIME()`→`CURRENT_TIMESTAMP`, PKs a autoincrement correcto. |
| `src/receipts/receipts.service.ts` | Envolver creación de recibo + líneas + movimiento en transacción (mínima). |
| `src/cash/cash.service.ts` | Transacciones en cierre de caja y movimientos. |
| `src/visitors/visitors.service.ts` | Transacción en creación de visitante + acompañantes + razones/actividades. |
| `src/vehicles/vehicles.service.ts` | Revisar asignaciones `exitEnabled = 1/0` (ya compatible con SQLite). |
| `src/common/utils/guatemala-time.ts` | Verificar que conversiones a ISO string funcionen con fechas devueltas por SQLite. |
| `test/app.e2e-spec.ts` | Configurar base SQLite en memoria o archivo temporal para pruebas. |

### Root / Docker / DB (`parqueRM-root/`)

| Archivo | Motivo |
|---------|--------|
| `docker-compose.yml` | Agregar `healthcheck` en `backend`; opcionalmente agregar servicio `backup`. |
| `.env` / `.env.example` | Documentar `DB_TYPE=sqlite`, `DB_PATH=/app/data/parquerm.db`; marcar variables MSSQL como obsoletas. |
| `scripts/start.bat` | Quitar mensaje obsoleto `SQL: localhost,1433`. |
| `docs/docker.md` | Actualizar arquitectura (sin SQL Server, puertos, volumen SQLite). |
| `README.md` | Actualizar descripción de servicios. |
| `DEMO_CHECKLIST.md` | Actualizar referencias a SQL Server. |
| `installer/` | Marcar como obsoleto para la versión Docker; reescribir si se mantiene instalador nativo. |
| `db/init/07_seed_demo_data.sql` | Confirmar idempotencia (ya la tiene con `WHERE NOT EXISTS`). |

---

## 3. Plan por fases

### Fase 0 — Línea base y respaldo

1. Hacer commit del estado actual en los tres repos.
2. Ejecutar el sistema actual con SQL Server (si aún corre) y exportar/respaldar la base de producción.
3. Verificar que `db/SQL-Server/` contenga todos los scripts originales.
4. Definir driver: **`better-sqlite3`** (recomendado) o `sqlite3`.

### Fase 1 — Entidades SQLite

1. Reemplazar en todas las entidades:
   - `type: 'nvarchar'` → `type: 'varchar'` (o dejar que TypeORM use `varchar`).
   - `type: 'datetime2'` → `type: 'datetime'` con `default: () => 'CURRENT_TIMESTAMP'`.
   - `type: 'bit'` → quitar `type` (TypeORM usa `boolean`) o `type: 'integer'`.
   - `type: 'decimal'` → mantener `type: 'decimal'` con `precision`/`scale` (SQLite lo almacena como `NUMERIC`).
   - `@PrimaryGeneratedColumn({ type: 'int' })` → `@PrimaryGeneratedColumn('increment')` o `{ type: 'integer' }`.
2. Usar `@CreateDateColumn` / `@UpdateDateColumn` donde sea posible para evitar defaults manuales.
3. No cambiar nombres de tablas, columnas ni relaciones.

### Fase 2 — Configuración TypeORM y variables de entorno

1. `configuration.ts`: leer `DB_TYPE`, `DB_PATH`.
2. `env.validation.ts`: validar condicionalmente (si `DB_TYPE === 'mssql'` requerir host/port/user/password/name; si `DB_TYPE === 'sqlite'` requerir `DB_PATH`).
3. `database.module.ts`: construir el objeto `TypeOrmModuleOptions` según `DB_TYPE`.
4. `package.json`: agregar `better-sqlite3` (y dependencias de build en `Dockerfile`).

### Fase 3 — Docker y persistencia

1. Actualizar `Dockerfile` del backend para compilar `better-sqlite3`:
   ```dockerfile
   RUN apk add --no-cache python3 make g++
   ```
2. En `docker-compose.yml` agregar `healthcheck` al backend:
   ```yaml
   healthcheck:
     test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/api/health"]
     interval: 30s
     timeout: 10s
     retries: 3
     start_period: 10s
   ```
3. Mantener `db-init` con `condition: service_completed_successfully`.
4. Asegurar volumen `sqlite_data` persistente.

### Fase 4 — Validación local sin Docker

1. Crear un `.env` local con `DB_TYPE=sqlite` y `DB_PATH=./data/parquerm-dev.db`.
2. Ejecutar `npm run start:dev` y verificar que el backend arranque y las entidades se mapeen.
3. Probar login con el seed `admin`.

### Fase 5 — Validación Docker completa

1. `docker compose up -d --build` desde `parqueRM-root/`.
2. Ejecutar la checklist de pruebas (sección 7).
3. `docker compose down && docker compose up -d` y confirmar persistencia.

### Fase 6 — Documentación, backups y limpieza

1. Actualizar `docs/docker.md`, `README.md`, `DEMO_CHECKLIST.md`.
2. Limpiar `.env.example` de variables MSSQL.
3. Implementar estrategia de backup del archivo `.db`.
4. Opcionalmente retirar `mssql` de `package.json` una vez validado todo.

---

## 4. Cambios esperados en backend

### 4.1 Driver recomendado

- **Recomendado: `better-sqlite3`.**
  - Más rápido para operaciones síncronas/transaccionales.
  - API síncrona; TypeORM lo soporta como `type: 'better-sqlite3'`.
  - Requiere compilación nativa (python3, make, g++ en Alpine).
- **Alternativa: `sqlite3`.**
  - API asíncrona, más tradicional con TypeORM.
  - También puede requerir compilación en Alpine.
  - Elegir si `better-sqlite3` presenta problemas de build.

### 4.2 Configuración TypeORM (`database.module.ts`)

```typescript
const dbType = config.get<'sqlite' | 'better-sqlite3' | 'mssql'>('database.type') ?? 'better-sqlite3';

if (dbType === 'mssql') {
  return { /* configuración MSSQL actual */ };
}

return {
  type: dbType,
  database: config.get<string>('database.path')!,
  synchronize: false,
  autoLoadEntities: true,
  entities: [ /* lista actual */ ],
  // Opciones recomendadas de SQLite
  extra: {
    pragma: [
      'journal_mode=WAL',
      'busy_timeout=5000',
      'foreign_keys=ON',
      'synchronous=NORMAL',
    ],
  },
};
```

> Nota: TypeORM aplica `extra.pragma` de forma limitada según el driver. Si no se aplican, usar un `QueryRunner` al inicio o confiar en los `PRAGMA` de `db/init/01_create_database.sql`.

### 4.3 Variables de entorno (`configuration.ts`)

```typescript
database: {
  type: (process.env.DB_TYPE as any) ?? 'better-sqlite3',
  path: process.env.DB_PATH,
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT ?? '1433', 10),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  name: process.env.DB_NAME,
  encrypt: process.env.DB_ENCRYPT === 'true',
  trustServerCert: process.env.DB_TRUST_SERVER_CERT !== 'false',
},
```

### 4.4 Validación de entorno (`env.validation.ts`)

- `DB_TYPE: 'sqlite' | 'better-sqlite3' | 'mssql'`.
- `DB_PATH` requerido cuando `DB_TYPE !== 'mssql'`.
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` requeridos solo cuando `DB_TYPE === 'mssql'`.
- Se puede implementar con validación condicional manual o con grupos de class-validator.

### 4.5 Ajustes en entidades

| SQL Server actual | SQLite propuesto |
|-------------------|------------------|
| `type: 'nvarchar'` | `type: 'varchar'` (misma `length`) |
| `type: 'datetime2'` | `type: 'datetime'` + `default: () => 'CURRENT_TIMESTAMP'` |
| `type: 'bit'` | quitar `type` o `type: 'boolean'` |
| `type: 'decimal'` | mantener `type: 'decimal'` con `precision`/`scale` |
| `type: 'date'` | mantener `type: 'date'` |
| `@PrimaryGeneratedColumn({ type: 'int' })` | `@PrimaryGeneratedColumn('increment')` |

**Ejemplo transformado:**

```typescript
@PrimaryGeneratedColumn('increment', { name: 'id' })
id!: number;

@Column({ name: 'username', type: 'varchar', length: 80, unique: true })
username!: string;

@Column({ name: 'is_active', default: true })
isActive!: boolean;

@Column({ name: 'created_at', type: 'datetime', default: () => 'CURRENT_TIMESTAMP' })
createdAt!: Date;
```

### 4.6 Manejo de fechas

- SQLite almacena fechas como `TEXT` (ISO-8601).
- TypeORM con `better-sqlite3`/`sqlite3` generalmente devuelve objetos `Date` para columnas `datetime`.
- `guatemala-time.ts` ya trabaja con ISO strings y objetos `Date`; se debe validar que los rangos de consulta sigan funcionando.
- Riesgo: si el driver devuelve `string`, las comparaciones `>= :from` con objetos `Date` fallarán. Se puede agregar un `ValueTransformer` o normalizar en el servicio.

### 4.7 Booleanos

- SQLite no tiene tipo booleano nativo; usa `0`/`1`.
- TypeORM convierte automáticamente `boolean` ↔ `INTEGER`.
- Asignaciones como `exitEnabled = 1` seguirán funcionando, pero se recomienda usar `true`/`false` en código para claridad.

### 4.8 IDs / autoincrement

- El schema SQLite usa `INTEGER PRIMARY KEY AUTOINCREMENT`.
- `@PrimaryGeneratedColumn('increment')` genera exactamente eso.
- Importante: no usar `type: 'int'` porque TypeORM podría generar `INTEGER` sin `AUTOINCREMENT`.

### 4.9 Transacciones

Actualmente no hay transacciones explícitas. Para SQLite es recomendable envolver operaciones críticas:

- Creación de recibo + líneas + movimiento financiero.
- Cancelación de recibo + cancelación de movimiento.
- Cierre de caja + detalles + asociación de movimientos.
- Creación de visitante + acompañantes + razones/actividades.

Se propone usar `dataSource.transaction(async (manager) => { ... })` o `queryRunner` sin cambiar los DTOs ni endpoints.

### 4.10 Concurrencia (máx. 10 usuarios)

- SQLite con WAL permite múltiples lectores concurrentes y un escritor.
- `busy_timeout=5000` hace que los escritores esperen en lugar de fallar inmediatamente.
- Con 10 usuarios y operaciones de venta intermitentes, no debería haber bloqueos severos si las transacciones son cortas.
- Si se observan errores `SQLITE_BUSY`, aumentar `busy_timeout` a 10000-20000 ms y revisar transacciones largas.

---

## 5. Cambios esperados en root / docker / db

### 5.1 `docker-compose.yml`

- Agregar `healthcheck` al backend (sección 4.2).
- Considerar agregar un contenedor `backup` con cron que copie `/data/parquerm.db` a una carpeta del host o a otro volumen.
- Mantener `db-init` como `restart: "no"` para que solo ejecute scripts cuando se recrea.

### 5.2 `db/init/01_create_database.sql`

Ya configura los pragmas esenciales:

```sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;
```

Esto es correcto. No se debe cambiar salvo ajuste de `busy_timeout`.

### 5.3 Montaje persistente

- Volumen Docker `sqlite_data` montado en `/data` (`db-init`) y `/app/data` (`backend`).
- Para producción on-premise se recomienda mapear el volumen a una ruta del host para facilitar backups fuera de Docker:
  ```yaml
  volumes:
    - /ruta/host/parquerm-data:/app/data
  ```

### 5.4 Runner/init de DB

- El contenedor `db-init` ya ejecuta los scripts en orden.
- Los scripts son idempotentes (`CREATE TABLE IF NOT EXISTS`, `INSERT OR IGNORE`, `WHERE NOT EXISTS`).
- `07_seed_demo_data.sql` ya usa `WHERE NOT EXISTS`, por lo que no duplicará datos si se reejecuta.
- Recomendación: agregar una tabla `schema_migrations` (ya existe script en `db/migrations/001_create_schema_migrations.sql`) para futuras migraciones controladas.

### 5.5 Variables de entorno en `.env`

Ejemplo propuesto:

```env
# SQLite
DB_TYPE=better-sqlite3
DB_PATH=/app/data/parquerm.db

# Obsoletas (SQL Server), conservar solo si se mantiene compatibilidad dual
# DB_HOST=sqlserver
# DB_PORT=1433
# DB_NAME=ParqueRM
# DB_USER=sa
# DB_PASSWORD=...
```

### 5.6 Documentación y scripts

- `docs/docker.md`: reescribir sección de servicios, puertos y volumen.
- `scripts/start.bat`: eliminar línea `SQL: localhost,1433`.
- `README.md` y `DEMO_CHECKLIST.md`: reemplazar referencias a SQL Server por SQLite.
- `installer/`: documentar como obsoleto para Docker; si se mantiene instalador nativo, reescribir para SQLite.

---

## 6. Riesgos

| Riesgo | Impacto | Probabilidad | Mitigación |
|--------|---------|--------------|------------|
| **Corrupción por apagón brusco** | Pérdida/corruptción del archivo `.db` | Media | WAL + `synchronous=NORMAL` + UPS obligatorio + backups periódicos. |
| **`SQLITE_BUSY` con varios usuarios** | Errores 500 en operaciones concurrentes | Media-Alta | `busy_timeout` alto (5-20 s), transacciones cortas, limitar operaciones de escritura masiva. |
| **Mapeo de fechas incorrecto** | Filtros por rango devuelven datos erróneos | Media | Validar que TypeORM devuelva `Date`; si no, usar `ValueTransformer` o normalizar a ISO. |
| **Precisión decimal** | Diferencias de centavos en montos | Baja | SQLite `NUMERIC`/`DECIMAL` preserva exactitud si se insertan como texto; validar redondeo en backend. |
| **Build nativo de `better-sqlite3` falla** | Imagen Docker no compila | Media | Instalar `python3 make g++` en Alpine; tener `sqlite3` como plan B. |
| **Defaults `CURRENT_TIMESTAMP` en UTC** | Horas desfasadas respecto a Guatemala | Media | Asegurar que el contenedor/Docker Host use la zona horaria correcta (`TZ=America/Guatemala`) o usar `datetime('now','localtime')` en SQL. |
| **Re-ejecutar `db-init` duplica datos** | Datos demo repetidos | Baja | Scripts ya son idempotentes; validar en pruebas. |
| **Entidades no coinciden con schema SQLite** | Errores de mapeo al arrancar | Media | Ajustar todos los tipos de columna y PKs; probar con `synchronize: false`. |
| **Tests E2E sin base de datos** | No se puede correr `npm run test:e2e` | Media | Configurar SQLite in-memory o archivo temporal para tests. |
| **Healthcheck no verifica DB inicializada** | Backend podría arrancar antes de que `db-init` termine o con DB corrupta | Baja | `depends_on condition: service_completed_successfully` ya lo evita; agregar healthcheck que haga ping a la DB. |

---

## 7. Pruebas de validación mínimas

### 7.1 Arranque e infraestructura

1. `docker compose up -d --build` en `parqueRM-root/` termina sin errores.
2. `docker compose ps` muestra `backend` y `frontend` healthy.
3. `docker compose logs db-init` muestra `Base SQLite inicializada correctamente`.
4. El archivo `parquerm.db` existe en el volumen.

### 7.2 Funcionales

| Módulo | Prueba |
|--------|--------|
| **Login** | Autenticarse con `admin` / contraseña seed. Refrescar token. Cambiar contraseña. |
| **Usuarios / roles / permisos** | Listar roles, asignar permisos, crear usuario, activar/desactivar. |
| **Catálogos** | CRUD de países, departamentos, municipios, categorías, tipos de vehículo/hospedaje. |
| **Tarifas** | Crear/editar tarifas, vigencia por fechas, cambio de tarifa activa. |
| **Configuración del parque** | Actualizar nombre, color sidebar, RUV, URL LAN; persiste reinicio. |
| **Ventas / tickets** | Crear recibo de visitante, vehículo, hospedaje y servicio general; ver numeración `REC-YYYYMMDD-XXXXX`; imprimir ticket. |
| **Visitantes** | Registrar visitante nacional y extranjero, acompañantes, razones y actividades. |
| **Servicios** | Crear servicio general, cobrarlo, reflejar en movimientos. |
| **Caja** | Abrir caja, registrar ingreso/egreso manual, cerrar caja, revisar detalles. |
| **Reportes** | Reportes diarios, por rango de fechas, por método de pago, exportar si aplica. |
| **Demo data** | Confirmar que los datos demo existen y no se duplican. |

### 7.3 Persistencia y recuperación

1. Crear un recibo nuevo.
2. `docker compose down && docker compose up -d`.
3. Verificar que el recibo creado siga existiendo.
4. Verificar que el login funcione con el mismo usuario.

### 7.4 Backups

1. Ejecutar backup manual del `.db` mientras el sistema corre (WAL permite copiar archivo consistente con checkpoint).
2. Restaurar copia en entorno aparte y confirmar datos.

---

## 8. Recomendación final para implementar con el menor cambio posible

1. **Usar `better-sqlite3`** como driver. Es el mejor equilibrio entre rendimiento y simplicidad para esta carga.
2. **No mantener compatibilidad dual MSSQL/SQLite** en código. Eliminar `mssql` del `package.json` y de la configuración una vez validado todo. Esto reduce complejidad y deuda técnica.
3. **Hacer los cambios en este orden:**
   1. Entidades (tipos y defaults).
   2. Configuración TypeORM + env.
   3. `Dockerfile` + `docker-compose.yml`.
   4. Transacciones en operaciones críticas (solo después de que el sistema funcione).
   5. Tests y documentación.
4. **No tocar lógica de negocio ni endpoints.** La única excepción justificada es agregar transacciones para mantener integridad, que no cambia contratos.
5. **Priorizar la validación de fechas y decimales** en las primeras pruebas; son los puntos más propensos a comportamientos inesperados al cambiar de motor.
6. **Configurar el host con UPS** y backups automáticos diarios del archivo `.db`; SQLite es robusto pero sensible a cortes de energía.
7. **Mantener `db/SQL-Server/` como respaldo histórico**, pero no referenciarlo en la ejecución.

---

## Anexo: recomendaciones SQLite a aplicar

- `PRAGMA journal_mode = WAL;`
- `PRAGMA foreign_keys = ON;`
- `PRAGMA busy_timeout = 5000;` (o mayor si hay bloqueos)
- `PRAGMA synchronous = NORMAL;`
- No usar `synchronous = OFF` en producción (riesgo de corrupción).
- Checkpoint automático de WAL es el default; monitorear tamaño de `-wal` y `-shm`.
