# Docker — ParqueRM

## Objetivo

Este documento explica cómo se usa Docker en ParqueRM.

El proyecto se divide en tres repositorios:

```txt
parqueRM/
  parqueRM-root/
  parqueRM-frontend/
  parqueRM-backend/
```

El repositorio `parqueRM-root` es el encargado de levantar todo el sistema con Docker Compose.

---

## ¿Qué levanta Docker?

Docker levanta el sistema en contenedores separados:

```txt
frontend   → React compilado y servido con Nginx
backend    → NestJS API
sqlserver  → SQL Server local
db-init    → contenedor temporal que ejecuta los scripts SQL iniciales
```

La idea es que la computadora del parque funcione como servidor local. Las demás computadoras se conectan desde el navegador usando la IP local del servidor.

Ejemplo:

```txt
Servidor: 192.168.1.10

Frontend:
http://192.168.1.10

Backend:
http://192.168.1.10:3000/api

SQL Server:
192.168.1.10,1433
```

---

## Estructura del repo root

```txt
parqueRM-root/
  docker-compose.yml
  .env

  db/
    init/
      01_create_database.sql
      02_schema.sql
      03_seed_security.sql
      04_seed_catalogs.sql
      05_seed_tariffs.sql
      06_seed_park_config.sql

  scripts/
    start.bat
    stop.bat
    reset-db.bat

  docs/
    docker.md
    permissions.md
    mermaid/
      architecture.mmd
      database-er.mmd
```

---

## Archivo `.env`

El archivo `.env` define variables usadas por Docker Compose.

Ejemplo:

```env
SQLSERVER_SA_PASSWORD=ParqueRM_2026_StrongPass!
JWT_SECRET=parque_rm_super_secret_local_2026

VITE_API_URL=http://localhost:3000/api
BACKEND_PORT=3000
FRONTEND_PORT=80
```

Para instalación en el parque, `VITE_API_URL` debe apuntar a la IP local del servidor:

```env
VITE_API_URL=http://192.168.1.10:3000/api
```

Dentro de Docker, el backend debe conectarse a SQL Server usando el nombre del servicio:

```env
DB_HOST=sqlserver
```

No debe usar `localhost`, porque dentro del contenedor `localhost` sería el mismo contenedor del backend, no SQL Server.

---

## Servicios del `docker-compose.yml`

### `sqlserver`

Levanta SQL Server en un contenedor.

Responsabilidades:

```txt
- Crear el servicio de base de datos.
- Exponer el puerto 1433.
- Mantener los datos usando un volumen Docker.
```

El volumen importante es:

```txt
sqlserver_data:/var/opt/mssql
```

Esto evita que la base se pierda al apagar los contenedores.

---

### `db-init`

Este contenedor ejecuta los scripts SQL iniciales.

Responsabilidades:

```txt
- Esperar a que SQL Server esté listo.
- Crear la base de datos ParqueRM.
- Crear tablas.
- Insertar roles, permisos, catálogos, tarifas y configuración inicial.
```

Este contenedor no permanece encendido. Corre los scripts y termina.

Orden de ejecución:

```txt
01_create_database.sql
02_schema.sql
03_seed_security.sql
04_seed_catalogs.sql
05_seed_tariffs.sql
06_seed_park_config.sql
```

---

### `backend`

Levanta el backend NestJS.

Responsabilidades:

```txt
- Exponer la API en el puerto 3000.
- Conectarse a SQL Server.
- Validar JWT.
- Validar permisos.
- Ejecutar la lógica del sistema.
```

El backend debe escuchar en:

```ts
await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
```

Esto es necesario para que funcione dentro de Docker y desde otras computadoras de la red.

---

### `frontend`

Levanta el frontend React.

Responsabilidades:

```txt
- Compilar React.
- Servir la aplicación usando Nginx.
- Consumir el backend usando VITE_API_URL.
```

El frontend no debe tener IPs quemadas en componentes. La URL del backend debe venir desde configuración o variable de entorno.

---

## Comandos principales

Todos estos comandos se ejecutan desde `parqueRM-root`.

### Levantar sistema

```bash
docker compose up -d --build
```

### Ver contenedores activos

```bash
docker ps
```

### Ver logs de todo

```bash
docker compose logs -f
```

### Ver logs del backend

```bash
docker compose logs -f backend
```

### Ver logs de SQL Server

```bash
docker compose logs -f sqlserver
```

### Apagar sistema

```bash
docker compose down
```

### Apagar y borrar la base de datos local

```bash
docker compose down -v
```

Después se puede levantar otra vez:

```bash
docker compose up -d --build
```

---

## Scripts `.bat`

Los scripts `.bat` son para facilitar el uso en Windows.

### `start.bat`

Levanta todo el sistema:

```bat
docker compose up -d --build
```

### `stop.bat`

Detiene los contenedores:

```bat
docker compose down
```

### `reset-db.bat`

Borra el volumen de SQL Server y vuelve a crear la base desde cero:

```bat
docker compose down -v
docker compose up -d --build
```

Este script debe usarse con cuidado, porque elimina los datos locales.

---

## Flujo recomendado de instalación local

1. Instalar Docker Desktop.
2. Clonar o copiar los tres repositorios:

```txt
parqueRM-root
parqueRM-frontend
parqueRM-backend
```

3. Configurar `.env` en `parqueRM-root`.
4. Ejecutar:

```bash
docker compose up -d --build
```

5. Verificar:

```txt
Frontend: http://localhost
Backend: http://localhost:3000/api
SQL Server: localhost,1433
```

6. Desde otra computadora de la red:

```txt
Frontend: http://IP_DEL_SERVIDOR
Backend: http://IP_DEL_SERVIDOR:3000/api
```

---

## Conexión con SSMS

Desde la computadora servidor:

```txt
Server name: localhost,1433
Authentication: SQL Server Authentication
Login: sa
Password: valor de SQLSERVER_SA_PASSWORD
```

Desde otra computadora en la red:

```txt
Server name: 192.168.1.10,1433
Authentication: SQL Server Authentication
Login: sa
Password: valor de SQLSERVER_SA_PASSWORD
```

---

## Notas importantes

- No quemar IPs dentro del frontend.
- El backend debe escuchar en `0.0.0.0`.
- El backend dentro de Docker debe conectarse a SQL Server usando `sqlserver`, no `localhost`.
- Los scripts SQL deben ser re-ejecutables usando `IF OBJECT_ID` e `IF NOT EXISTS`.
- Para producción local, evitar usar contraseñas débiles.
- El contenedor `db-init` no debe crear el usuario admin con contraseña plana. Eso debe hacerlo el backend usando `bcrypt`.

---

## Resumen

Docker permite levantar ParqueRM como un sistema local completo:

```txt
React + NestJS + SQL Server
```

Todo queda empaquetado y repetible para instalarse en este parque o en otros parques municipales.
